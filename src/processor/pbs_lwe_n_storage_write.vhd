----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: pbs_lwe_n_storage_write
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: handles read and write calls to the BRAM that stores the output of the pbs.
--             This module extracts the b-value from the pbs result.
--             This module can be called to access the contents of the BRAM. However, don't call
--             in random order, call from the beginning linearly.
-- Dependencies: see imports
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.numeric_std.all;
     use IEEE.math_real.all;
library work;
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.tfhe_constants.all;
     use work.math_utils.all;
     use work.processor_utils.all;

entity pbs_lwe_n_storage_write is
     port (
          i_clk                : in  std_ulogic;
          i_pbs_result         : in  sub_polynom(0 to pbs_throughput - 1);
          -- i_sample_extract_idx : in  idx_int;
          i_ram_coeff_idx      : in  unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
          i_reset              : in  std_ulogic;

          o_coeffs             : out sub_polynom(0 to pbs_throughput - 1);
          o_coeffs_valid       : out std_ulogic;
          o_next_module_reset  : out std_ulogic
     );
end entity;

architecture Behavioral of pbs_lwe_n_storage_write is

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

     signal next_module_reset_bufferchain : std_ulogic_vector(0 to default_ram_retiming_latency + 2 - 1); -- +2 because first compute idx, then read block from buffer, then extract coefficient
     signal coeff_valid_bufferchain       : std_ulogic_vector(0 to next_module_reset_bufferchain'length - 1);

     signal pbs_res_cnt         : unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
     signal pbs_res_cnt_delayed : unsigned(0 to pbs_res_cnt'length - 1);
     signal pbs_res_block_cnt   : unsigned(0 to log2_num_coefficients - log2_pbs_throughput - 1);
     signal pbs_res_polym_cnt   : unsigned(0 to get_bit_length(num_polyms_per_rlwe_ciphertext - 1) - 1);

     signal cnt_till_next_batch : unsigned(0 to get_bit_length(blind_rotation_latency - 1) - 1);

     signal all_values_in_buffer_processed : std_ulogic;
     signal write_en                       : std_ulogic;

     signal pbs_res_reordered : sub_polynom(0 to i_pbs_result'length - 1);

begin

     pbs_result_to_ram: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if i_reset = '1' then
                    pbs_res_cnt <= to_unsigned(0, pbs_res_cnt'length);
                    pbs_res_block_cnt <= to_unsigned(0, pbs_res_block_cnt'length);
                    pbs_res_polym_cnt <= to_unsigned(0, pbs_res_polym_cnt'length);
                    next_module_reset_bufferchain(0) <= '1';
                    cnt_till_next_batch <= to_unsigned(0, cnt_till_next_batch'length);

                    all_values_in_buffer_processed <= '0';
                    write_en <= '1';
               else

                    if cnt_till_next_batch < blind_rotation_latency - 1 then
                         cnt_till_next_batch <= cnt_till_next_batch + to_unsigned(1, cnt_till_next_batch'length);
                         if cnt_till_next_batch = num_pbs_out_write_cycles - 1 then
                              write_en <= '0';
                         end if;
                    else
                         cnt_till_next_batch <= to_unsigned(0, cnt_till_next_batch'length);
                         all_values_in_buffer_processed <= '0';
                         write_en <= '1';
                    end if;

                    if cnt_till_next_batch < num_pbs_out_write_cycles - 1 then
                         -- catch pbs output
                         pbs_res_block_cnt <= pbs_res_block_cnt + to_unsigned(1, pbs_res_block_cnt'length); -- modulos itself
                         if pbs_res_block_cnt = to_unsigned(2 ** pbs_res_block_cnt'length - 1, pbs_res_block_cnt'length) then
                              if pbs_res_polym_cnt < to_unsigned(num_polyms_per_rlwe_ciphertext - 1, pbs_res_polym_cnt'length) then
                                   pbs_res_polym_cnt <= pbs_res_polym_cnt + to_unsigned(1, pbs_res_polym_cnt'length);
                              else
                                   pbs_res_polym_cnt <= to_unsigned(0, pbs_res_polym_cnt'length);
                              end if;
                         end if;

                         if pbs_res_polym_cnt < to_unsigned(num_polyms_per_rlwe_ciphertext - 1, pbs_res_polym_cnt'length) then
                              if pbs_res_cnt < to_unsigned(write_blocks_in_lwe_n_ram - 1, pbs_res_cnt'length) then
                                   pbs_res_cnt <= pbs_res_cnt + to_unsigned(1, pbs_res_cnt'length);
                              else
                                   pbs_res_cnt <= to_unsigned(0, pbs_res_cnt'length);
                              end if;
                              pbs_res_reordered <= i_pbs_result;
                         else
                              -- catch b-value with extract-idx
                              -- pbs_throughput is a power of 2 --> first log2_throughput-bits are coefficient idx, the others are block idx
                              if (pbs_res_block_cnt = sample_extract_idx(0 to sample_extract_idx'length - log2_pbs_throughput - 1)) then
                                   -- we can write the b-value anywhere in its block but for later convinience we write it at the last position.
                                   pbs_res_reordered(pbs_res_reordered'length - 1) <= i_pbs_result(to_integer(sample_extract_idx(sample_extract_idx'length - log2_pbs_throughput - 1 to sample_extract_idx'length - 1)));
                                   -- ignore the other values in that block
                                   if pbs_res_cnt < to_unsigned(write_blocks_in_lwe_n_ram - 1, pbs_res_cnt'length) then
                                        pbs_res_cnt <= pbs_res_cnt + to_unsigned(1, pbs_res_cnt'length);
                                   else
                                        pbs_res_cnt <= to_unsigned(0, pbs_res_cnt'length);
                                   end if;
                              end if;
                         end if;
                    end if;
               end if;

               pbs_res_cnt_delayed <= pbs_res_cnt;
               next_module_reset_bufferchain(1 to next_module_reset_bufferchain'length - 1) <= next_module_reset_bufferchain(0 to next_module_reset_bufferchain'length - 2);
               coeff_valid_bufferchain(0) <= not all_values_in_buffer_processed;
               coeff_valid_bufferchain(1 to coeff_valid_bufferchain'length - 1) <= coeff_valid_bufferchain(0 to coeff_valid_bufferchain'length - 2);
          end if;
     end process;

     o_next_module_reset <= next_module_reset_bufferchain(next_module_reset_bufferchain'length - 1);
     o_coeffs_valid      <= coeff_valid_bufferchain(coeff_valid_bufferchain'length - 1);

     brams_per_throughput: for coeff_idx in 0 to i_pbs_result'length - 1 generate
          ram_elem: manual_bram
               generic map (
                    addr_length         => i_ram_coeff_idx'length,
                    ram_length          => write_blocks_in_lwe_n_ram,
                    ram_out_bufs_length => default_ram_retiming_latency,
                    ram_type            => ram_style_auto,
                    coeff_bit_width     => pbs_res_reordered(0)'length
               )
               port map (
                    i_clk     => i_clk,
                    i_wr_en   => write_en,
                    i_wr_data => pbs_res_reordered(coeff_idx),
                    i_wr_addr => pbs_res_cnt_delayed,
                    i_rd_addr => i_ram_coeff_idx,
                    o_data    => o_coeffs(coeff_idx)
               );
     end generate;

end architecture;
