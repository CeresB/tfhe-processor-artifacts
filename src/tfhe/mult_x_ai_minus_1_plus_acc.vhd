----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: mult_x_ai_minus_1_plus_acc
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Multiplies the input polynom by (X^a_i - 1).
--             Assumption: i_acc is just provided when reset drops but i_ai is
--             provided num_coefficients/throughput tics after reset drops.
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
     use work.tfhe_utils.all;
     use work.math_utils.all;

entity mult_x_ai_minus_1_plus_acc is
     generic (
          throughput : integer
     );
     port (
          i_clk               : in  std_ulogic;
          i_reset             : in  std_ulogic;
          i_sub_polym         : in  sub_polynom(0 to throughput - 1);
          i_ai                : in  rotate_idx;
          i_acc               : in  sub_polynom(0 to throughput - 1);
          o_result            : out sub_polynom(0 to throughput - 1);
          o_next_module_reset : out std_ulogic
     );
end entity;

architecture Behavioral of mult_x_ai_minus_1_plus_acc is

     component rotate_polym_with_buffer is
          generic (
               throughput    : integer;
               rotate_right  : boolean;
               rotate_offset : integer;
               negate_polym  : boolean;
               reverse_polym : boolean
          );
          port (
               i_clk               : in  std_ulogic;
               i_reset             : in  std_ulogic;
               i_sub_polym         : in  sub_polynom(0 to throughput - 1);
               i_rotate_by         : in  rotate_idx;
               o_result            : out sub_polynom(0 to throughput - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     component add_reduce is
          generic (
               substraction : boolean;
               modulus      : synthesiseable_uint
          );
          port (
               i_clk    : in  std_ulogic;
               i_num0   : in  synthesiseable_uint;
               i_num1   : in  synthesiseable_uint;
               o_result : out synthesiseable_uint
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

     constant acc_old_minus_acc_part_buffer_length : integer := rotate_with_buffer_latency - clks_per_64_bit_add_mod - x_ai_minus_1_sub_buf_ram_retiming_latency; -- -x_ai_minus_1_buf_ram_retiming_latency because end part is handled seperatly

     signal polym_part_rolled : sub_polynom(0 to throughput - 1);
     -- rotate_polynom does also a 64-bit add, so rotate polynom will never finish before our 64-bit sub
     signal acc_old_minus_acc_part                 : sub_polynom(0 to throughput - 1);
     signal acc_old_minus_acc_part_buffer_old_part : sub_polynom(0 to throughput - 1);
     
     type buffer_cnt_buf is array (natural range <>) of unsigned(0 to get_bit_length(acc_old_minus_acc_part_buffer_length - 1) - 1);
     signal buffer_cnt : unsigned(0 to get_bit_length(acc_old_minus_acc_part_buffer_length - 1)-1) := to_unsigned(0, get_bit_length(acc_old_minus_acc_part_buffer_length - 1));
     signal buffer_cnt_chain : buffer_cnt_buf(0 to counter_buffer_len-2); -- -2 since chain_end handled separately
     signal buffer_cnt_chain_end : unsigned(0 to buffer_cnt'length-1);

     signal latency_cnt_reset : std_ulogic;
     
     signal internal_reset_chain : std_ulogic_vector(0 to ntt_cnts_early_reset - 1);
     signal internal_reset       : std_ulogic;

     signal reset_buf: std_ulogic;
     signal sub_polym_buf: sub_polynom(0 to i_sub_polym'length-1);

begin

     input_buf: if use_end_step_input_buffer generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               sub_polym_buf <= i_sub_polym;
               reset_buf <= i_reset;
          end if;
          end process;
     end generate;
     no_input_buf: if not use_end_step_input_buffer generate
          sub_polym_buf <= i_sub_polym;
          reset_buf <= i_reset;
     end generate;

     reset_chain: if internal_reset_chain'length > 0 generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    internal_reset_chain <= reset_buf & internal_reset_chain(0 to internal_reset_chain'length - 2);
               end if;
          end process;
          internal_reset <= internal_reset_chain(internal_reset_chain'length - 1);
     end generate;
     no_reset_chain: if not (internal_reset_chain'length > 0) generate
          internal_reset <= reset_buf;
     end generate;

     rotate_with_buf: rotate_polym_with_buffer
          generic map (
               throughput    => throughput,
               rotate_right  => false,
               rotate_offset => 0,
               negate_polym  => false,
               reverse_polym => false
          )
          port map (
               i_clk               => i_clk,
               i_reset             => internal_reset,
               i_sub_polym         => sub_polym_buf,
               i_rotate_by         => i_ai,
               o_result            => polym_part_rolled,
               o_next_module_reset => latency_cnt_reset
          );

     acc_old_minus_acc: for i in 0 to o_result'length - 1 generate
          big_sub_module: add_reduce
               generic map (
                    substraction => true,
                    modulus      => tfhe_modulus
               )
               port map (
                    i_clk    => i_clk,
                    i_num0   => i_acc(i),
                    i_num1   => sub_polym_buf(i),
                    o_result => acc_old_minus_acc_part(i)
               );
     end generate;

     acc_x_ai_plus_acc_old_minus_acc: for i in 0 to o_result'length - 1 generate
          big_add_module: add_reduce
               generic map (
                    substraction => false,
                    modulus      => tfhe_modulus
               )
               port map (
                    i_clk    => i_clk,
                    i_num0   => polym_part_rolled(i),
                    i_num1   => acc_old_minus_acc_part_buffer_old_part(i),
                    o_result => o_result(i)
               );
     end generate;

     initial_latency_counter: one_time_counter
          generic map (
               tripping_value     => clks_per_64_bit_add_mod,
               out_negated        => true,
               bufferchain_length => trailing_reset_buffer_len
          )
          port map (
               i_clk     => i_clk,
               i_reset   => latency_cnt_reset,
               o_tripped => o_next_module_reset
          );

     process (i_clk)
     begin
          if rising_edge(i_clk) then
               if buffer_cnt = 0 then
                    buffer_cnt <= to_unsigned(acc_old_minus_acc_part_buffer_length - 1, buffer_cnt'length);
               else
                    buffer_cnt <= buffer_cnt - to_unsigned(1, buffer_cnt'length);
               end if;
          end if;
     end process;
     do_buffer_cnt_chain: if buffer_cnt_chain 'length > 0 generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    buffer_cnt_chain <= buffer_cnt & buffer_cnt_chain(0 to buffer_cnt_chain'length - 2);
               end if;
          end process;
          buffer_cnt_chain_end <= buffer_cnt_chain(buffer_cnt_chain'length-1);
     end generate;
     no_buffer_cnt_chain: if not (buffer_cnt_chain'length > 0) generate
          buffer_cnt_chain_end <= buffer_cnt;
     end generate;

     brams_per_coeff: for coeff_idx in 0 to acc_old_minus_acc_part'length - 1 generate
          ram_elem: manual_bram
               generic map (
                    addr_length         => buffer_cnt'length,
                    ram_length          => acc_old_minus_acc_part_buffer_length,
                    ram_out_bufs_length => x_ai_minus_1_sub_buf_ram_retiming_latency,
                    ram_type            => acc_old_buffer_ram_type,
                    coeff_bit_width     => acc_old_minus_acc_part(0)'length
               )
               port map (
                    i_clk     => i_clk,
                    i_wr_en   => '1',
                    i_wr_data => acc_old_minus_acc_part(coeff_idx),
                    i_wr_addr => buffer_cnt_chain_end,
                    i_rd_addr => buffer_cnt_chain_end,
                    o_data    => acc_old_minus_acc_part_buffer_old_part(coeff_idx)
               );
     end generate;

end architecture;
