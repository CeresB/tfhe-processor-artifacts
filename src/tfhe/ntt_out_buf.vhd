----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ntt_out_buf
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This is the output buffer for the NTT-results in a blind rotation iteration.
--              It requires its own file due to the complexity involved to make Vivado
--             implement this in memory.
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
     use work.math_utils.all;
     use work.tfhe_utils.all;
     use work.tfhe_constants.all;

entity ntt_out_buf is
     generic (
          throughput            : integer;
          num_ntts              : integer;
          polyms_per_ciphertext : integer;
          ram_retiming_latency  : integer
     );
     port (
          i_clk               : in  std_ulogic;
          i_reset             : in  std_ulogic;                                  -- must be 1 clock tic earlier than i_result_ntt for computation of the addresses
          i_result_ntt        : in  sub_polynom(0 to throughput * num_ntts - 1); -- no buffer! you read it from memory anyway and it does not change during the computation
          o_result            : out sub_polynom(0 to throughput * num_ntts * polyms_per_ciphertext - 1);
          o_next_module_reset : out std_ulogic
     );
end entity;

architecture Behavioral of ntt_out_buf is

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

     -- ram_unit has at max 1 read and 1 write per clock tic
     -- we work with a ping-pong buffer
     constant ping_buffer_length : integer := ntt_num_blocks_per_polym;
     constant ram_size           : integer := 2 * ping_buffer_length;
     --constant num_ram_blocks     : integer := polyms_per_ciphertext * i_result_ntt'length;

     signal internal_reset_chain : std_ulogic_vector(0 to ntt_out_buf_reset_buf_len-1-1*boolean'pos(not use_ntt_out_buf_input_buffer)-1); -- -1 because 1 clk tic to compute full address
     signal internal_reset : std_ulogic;
     signal input_buf      : sub_polynom(0 to i_result_ntt'length - 1);

     type coeff_spread_bits is array(natural range <>) of std_ulogic_vector(0 to polyms_per_ciphertext-1);
     signal coeff_write_enable: coeff_spread_bits(0 to i_result_ntt'length-1);

     signal ram_rd_wr_addr_all        : unsigned(0 to get_bit_length(ping_buffer_length - 1) - 1);
     signal ram_polym_cnt_all        : unsigned(0 to get_bit_length(polyms_per_ciphertext - 1) - 1);
     signal ram_rd_addr_offset_all : std_ulogic;
     signal ram_wr_addr_offset_all : std_ulogic;
     signal ram_rd_addr_full_all   : unsigned(0 to ram_rd_wr_addr_all'length+1 - 1);
     signal ram_wr_addr_full_all   : unsigned(0 to ram_rd_wr_addr_all'length+1 - 1);

begin

     with_in_buf: if use_ntt_out_buf_input_buffer generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               input_buf <= i_result_ntt;
          end if;
          end process;
     end generate;
     no_in_buf: if not use_ntt_out_buf_input_buffer generate
          input_buf <= i_result_ntt;
     end generate;
     process (i_clk) is
     begin
          if rising_edge(i_clk) then
               internal_reset_chain(0) <= i_reset;
               internal_reset_chain(1 to internal_reset_chain'length-1) <= internal_reset_chain(0 to internal_reset_chain'length-2);
          end if;
     end process;
     internal_reset <= internal_reset_chain(internal_reset_chain'length-1);

     ram_rd_addr_offset_all <= not ram_wr_addr_offset_all;
     process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if internal_reset = '1' then
                    for L_coeff_idx in 0 to input_buf'length - 1 loop
                         coeff_write_enable(L_coeff_idx) <= std_ulogic_vector(to_unsigned(2**(polyms_per_ciphertext-1),polyms_per_ciphertext));
                    end loop;
                    ram_rd_wr_addr_all <= to_unsigned(ping_buffer_length - 1, ram_rd_wr_addr_all'length);
                    ram_wr_addr_offset_all <= '0';
                    ram_polym_cnt_all <= to_unsigned(polyms_per_ciphertext-1, ram_polym_cnt_all'length);
               else
                    ram_rd_wr_addr_all <= ram_rd_wr_addr_all - to_unsigned(1, ram_rd_wr_addr_all'length); -- its a pow2 cnt, can just roll over
                    if ram_rd_wr_addr_all = 0 then
                         -- roll write enable
                         for L_coeff_idx in 0 to input_buf'length - 1 loop
                              coeff_write_enable(L_coeff_idx) <= coeff_write_enable(L_coeff_idx)(coeff_write_enable(0)'length-1) & coeff_write_enable(L_coeff_idx)(0 to coeff_write_enable(0)'length-2);
                         end loop;
                         -- keep track when to switch the offset
                         if ram_polym_cnt_all = 0 then
                              ram_polym_cnt_all <= to_unsigned(polyms_per_ciphertext-1, ram_polym_cnt_all'length);
                              -- switch rd/wr offsets
                              ram_wr_addr_offset_all <= not ram_wr_addr_offset_all;
                         else
                              ram_polym_cnt_all <= ram_polym_cnt_all - to_unsigned(1, ram_polym_cnt_all'length);
                         end if;
                    end if;
               end if;
               ram_rd_addr_full_all <= unsigned(ram_rd_addr_offset_all & ram_rd_wr_addr_all);
               ram_wr_addr_full_all <= unsigned(ram_wr_addr_offset_all & ram_rd_wr_addr_all);
          end if;
     end process;
     
     -- all buffers get the same input and we just toggle the write enable
     logic_per_coeff: for L_coeff_idx in 0 to input_buf'length - 1 generate
          -- spread each input to (k+1) buffer inputs
          brams_per_coeff: for k_idx in 0 to polyms_per_ciphertext-1 generate
               ram_elem: manual_bram
                    generic map (
                         addr_length         => ram_wr_addr_full_all'length,
                         ram_length          => ram_size,
                         ram_out_bufs_length => ram_retiming_latency,
                         ram_type            => ntt_big_out_buffer_ram_type,
                         coeff_bit_width     => input_buf(0)'length
                    )
                    port map (
                         i_clk     => i_clk,
                         i_wr_en   => coeff_write_enable(L_coeff_idx)(k_idx),
                         i_wr_data => input_buf(L_coeff_idx),
                         i_wr_addr => ram_wr_addr_full_all,
                         i_rd_addr => ram_rd_addr_full_all,
                         o_data    => o_result(L_coeff_idx + k_idx*throughput*num_ntts)
                    );
          end generate;
     end generate;

     initial_latency_counter: one_time_counter
          generic map (
               tripping_value     => num_polyms_per_rlwe_ciphertext * ntt_num_blocks_per_polym + ram_retiming_latency + 1 * boolean'pos(use_ntt_out_buf_input_buffer),
               out_negated        => true,
               bufferchain_length => trailing_reset_buffer_len
          )
          port map (
               i_clk     => i_clk,
               i_reset   => internal_reset,
               o_tripped => o_next_module_reset
          );

end architecture;
