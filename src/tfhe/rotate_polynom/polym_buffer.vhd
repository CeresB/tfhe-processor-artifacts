----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: polym_buffer
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This module prepares the input for the rotate-polynom module and
--             handles the necessary polynom-sized buffer.
--             It assumes that the input is in ntt-mixed-format.
-- Dependencies: see imports
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.NUMERIC_STD.all;
library work;
     use work.datatypes_utils.all;
     use work.constants_utils.all;
     use work.tfhe_constants.all;
     use work.math_utils.all;

entity polym_buffer is
     generic (
          throughput     : integer;
          store_reversed : boolean -- if true the polynom is stored reversed --> the reversed coefficients to i_request_idx are returned
     );
     port (
          i_clk               : in  std_ulogic;
          i_reset             : in  std_ulogic;
          i_sub_polym         : in  sub_polynom(0 to throughput - 1);
          i_ram_coeff_idx     : in  unsigned(0 to get_bit_length((num_coefficients / throughput) - 1) * throughput / 2 - 1);
          o_result            : out sub_polynom(0 to throughput - 1);
          o_next_module_reset : out std_ulogic
     );
end entity;

architecture Behavioral of polym_buffer is

     component manual_bram is
          generic (
               addr_length         : integer;
               ram_length          : integer;
               ram_out_bufs_length : integer;
               ram_type            : string;
               coeff_bit_width     : integer
          );
          port (
               i_clk     : in  std_ulogic;
               i_wr_en   : in  std_ulogic;
               i_wr_data : in  unsigned(0 to coeff_bit_width - 1);
               i_wr_addr : in  unsigned(0 to addr_length - 1);
               i_rd_addr : in  unsigned(0 to addr_length - 1);
               o_data    : out unsigned(0 to coeff_bit_width - 1)
          );
     end component;

     component one_time_counter is
          generic (
               tripping_value     : integer;
               out_negated        : boolean;
               bufferchain_length : integer
          );
          port (
               i_clk     : in  std_ulogic;
               i_reset   : in  std_ulogic;
               o_tripped : out std_ulogic
          );
     end component;

     constant ping_buffer_length              : integer := num_coefficients / throughput;
     constant coeffs_per_ram_block            : integer := 2 * ping_buffer_length;
     constant coeffs_per_ram_block_bit_length : integer := get_bit_length(coeffs_per_ram_block - 1);
     constant throughput_half                 : integer := throughput / 2;

     type polym_half_ram is array (0 to throughput_half - 1) of sub_polynom(0 to coeffs_per_ram_block - 1);
     -- signal polym_buffer_0_lower : polym_half_ram;
     -- signal polym_buffer_0_upper : polym_half_ram;
     -- signal polym_buffer_1_lower : polym_half_ram;
     -- signal polym_buffer_1_upper : polym_half_ram;
     -- signal polym_buffer_choice  : std_ulogic;
     signal internal_input : sub_polynom(0 to throughput - 1);

     signal in_coeff_cnt         : unsigned(0 to coeffs_per_ram_block_bit_length - 1 - 1);
     signal in_coeff_cnt_tripped : std_ulogic;

     signal in_coeff_cnt_full : unsigned(0 to coeffs_per_ram_block_bit_length - 1);
     signal in_coeff_offset   : std_ulogic;

     type ping_indices is array (natural range <>) of unsigned(0 to coeffs_per_ram_block_bit_length - 1 - 1);
     type coeff_indices is array (natural range <>) of unsigned(0 to coeffs_per_ram_block_bit_length - 1);
     signal rq_coeff_indices : coeff_indices(0 to throughput / 2 - 1);
     signal rq_coeff_offset  : std_ulogic;

     signal rq_ping_indices : ping_indices(0 to throughput / 2 - 1);

     signal internal_input_upper  : sub_polynom(0 to throughput_half - 1);
     signal internal_input_lower  : sub_polynom(0 to throughput_half - 1);
     signal internal_output_upper : sub_polynom(0 to throughput_half - 1);
     signal internal_output_lower : sub_polynom(0 to throughput_half - 1);

     -- constant log2_throughput : integer := get_bit_length(throughput - 1);
     signal input_buffer : sub_polynom(0 to i_sub_polym'length - 1);

     constant cnt_start_val         : integer := 0 * boolean'pos(not store_reversed) + (coeffs_per_ram_block - 1) * boolean'pos(store_reversed);
     constant cnt_step_val          : integer := 1 * boolean'pos(not store_reversed) - 1 * boolean'pos(store_reversed);
     constant cnt_step_val_positive : integer := 1 * boolean'pos(not store_reversed) + (2 ** coeffs_per_ram_block_bit_length - 1) * boolean'pos(store_reversed); -- (2 ** coeffs_per_ram_block_bit_length - 1) expresses -1
     constant cnt_tripping_val      : integer := (ping_buffer_length - 1) * boolean'pos(not store_reversed) + (ping_buffer_length) * boolean'pos(store_reversed) - cnt_step_val;

begin

     process (i_clk)
     begin
          if rising_edge(i_clk) then
               if i_reset = '1' then
                    in_coeff_cnt <= to_unsigned(cnt_start_val, in_coeff_cnt'length);
               else
                    in_coeff_cnt <= in_coeff_cnt + to_unsigned(cnt_step_val_positive, in_coeff_cnt'length);
                    if in_coeff_cnt = to_unsigned(cnt_tripping_val, in_coeff_cnt'length) then
                         in_coeff_cnt_tripped <= '1';
                    else
                         in_coeff_cnt_tripped <= '0';
                    end if;
               end if;
          end if;
     end process;

     non_reversed: if not store_reversed generate
          internal_input <= i_sub_polym;
     end generate;

     is_reversed: if store_reversed generate
          reverse_input: for i in 0 to i_sub_polym'length - 1 generate
               internal_input(internal_input'length - 1 - i) <= i_sub_polym(i);
          end generate;
     end generate;

     idx_bit_map: for i in 0 to rq_ping_indices'length - 1 generate
          rq_ping_indices(i) <= i_ram_coeff_idx(i * rq_ping_indices(0)'length to (i + 1) * rq_ping_indices(0)'length - 1);
     end generate;

     brams_per_polym: for coeff_half_idx in 0 to internal_input_upper'length - 1 generate
          ram_upper: manual_bram
               generic map (
                    addr_length         => in_coeff_cnt_full'length,
                    ram_length          => coeffs_per_ram_block,
                    ram_out_bufs_length => pingpong_ram_retiming_latency,
                    ram_type            => rotate_buffer_ram_type,
                    coeff_bit_width     => internal_input_upper(0)'length
               )
               port map (
                    i_clk     => i_clk,
                    i_wr_en   => '1',
                    i_wr_data => internal_input_upper(coeff_half_idx),
                    i_wr_addr => in_coeff_cnt_full,
                    i_rd_addr => rq_coeff_indices(coeff_half_idx),
                    o_data    => internal_output_upper(coeff_half_idx)
               );
          ram_lower: manual_bram
               generic map (
                    addr_length         => in_coeff_cnt_full'length,
                    ram_length          => coeffs_per_ram_block,
                    ram_out_bufs_length => pingpong_ram_retiming_latency,
                    ram_type            => rotate_buffer_ram_type,
                    coeff_bit_width     => internal_input_upper(0)'length
               )
               port map (
                    i_clk     => i_clk,
                    i_wr_en   => '1',
                    i_wr_data => internal_input_lower(coeff_half_idx),
                    i_wr_addr => in_coeff_cnt_full,
                    i_rd_addr => rq_coeff_indices(coeff_half_idx),
                    o_data    => internal_output_lower(coeff_half_idx)
               );
     end generate;

     initial_latency_counter: one_time_counter
          generic map (
               tripping_value     => ping_buffer_length - rotate_polym_reset_clks_ahead, -- rotate reset must be dropped x tics earlier so that we have the request indices when ping buffer is full
               out_negated        => true,
               bufferchain_length => trailing_reset_buffer_len
          )
          port map (
               i_clk     => i_clk,
               i_reset   => i_reset,
               o_tripped => o_next_module_reset
          );

     buffer_logic: process (i_clk)
     begin
          if rising_edge(i_clk) then
               if i_reset = '1' then
                    rq_coeff_offset <= '1';
                    in_coeff_offset <= '0';
               else
                    if in_coeff_cnt_tripped = '1' then
                         rq_coeff_offset <= not rq_coeff_offset;
                         in_coeff_offset <= not in_coeff_offset;
                    end if;
               end if;
               input_buffer <= internal_input;
               in_coeff_cnt_full <= unsigned(in_coeff_offset & std_ulogic_vector(in_coeff_cnt));

               for i in 0 to rq_coeff_indices'length - 1 loop
                    rq_coeff_indices(i) <= unsigned(rq_coeff_offset & std_ulogic_vector(rq_ping_indices(i)));
               end loop;
          end if;
     end process;

     internal_input_upper                                          <= input_buffer(0 to internal_input_upper'length - 1);
     internal_input_lower                                          <= input_buffer(internal_input_upper'length to input_buffer'length - 1);
     o_result <= internal_output_upper & internal_output_lower;

end architecture;
