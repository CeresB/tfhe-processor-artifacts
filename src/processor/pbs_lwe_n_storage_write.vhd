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
     use work.math_utils.all;
     use work.tfhe_constants.all;
     use work.processor_utils.all;

entity pbs_lwe_n_storage_write is
     port (
          i_clk                : in  std_ulogic;
          i_pbs_result         : in  sub_polynom(0 to pbs_throughput - 1);
          -- i_sample_extract_idx : in  idx_int;
          i_ram_coeff_idx      : in  unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
          i_reset              : in  std_ulogic;

          o_coeffs             : out sub_polynom(0 to pbs_throughput - 1);
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

     constant ciphertext_out_blocks: integer := ((num_polyms_per_rlwe_ciphertext * num_coefficients) / pbs_throughput);
     signal ciphertext_out_cnt  : unsigned(0 to get_bit_length(ciphertext_out_blocks-1) - 1);
     signal pbs_res_cnt         : unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);

     signal cnt_till_next_batch : unsigned(0 to get_bit_length(blind_rotation_latency - 1) - 1);

     signal write_en                       : std_ulogic;

     signal pbs_res_reordered : sub_polynom(0 to i_pbs_result'length - 1);

begin

     pbs_result_to_ram: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if i_reset = '1' then
                    pbs_res_cnt <= to_unsigned(0, pbs_res_cnt'length);
                    next_module_reset_bufferchain(0) <= '1';
                    -- cnt_till_next_batch steers write enable. write_en must be set one in advance but not here since we reorder the input
                    cnt_till_next_batch <= to_unsigned(blind_rotation_latency-1, cnt_till_next_batch'length);

                    write_en <= '0';
                    ciphertext_out_cnt <= to_unsigned(0, ciphertext_out_cnt'length);
               else
                    if cnt_till_next_batch = 0 then
                         cnt_till_next_batch <= to_unsigned(blind_rotation_latency-1, cnt_till_next_batch'length);
                    else
                         cnt_till_next_batch <= cnt_till_next_batch - to_unsigned(1, cnt_till_next_batch'length);
                    end if;
                    ciphertext_out_cnt <= ciphertext_out_cnt + to_unsigned(1, ciphertext_out_cnt'length); -- modolus itself

                    if cnt_till_next_batch > to_unsigned(blind_rotation_latency-1-num_pbs_out_write_cycles,cnt_till_next_batch'length) then
                         -- catch pbs output, but of the b-polynom only the first block
                         if ciphertext_out_cnt < to_unsigned(write_blocks_in_lwe_n_ram-1, ciphertext_out_cnt'length) then
                              write_en <= '1';
                              if pbs_res_cnt < to_unsigned(write_blocks_in_lwe_n_ram - 1, pbs_res_cnt'length) then
                                   pbs_res_cnt <= pbs_res_cnt + to_unsigned(1, pbs_res_cnt'length);
                              else
                                   pbs_res_cnt <= to_unsigned(0, pbs_res_cnt'length);
                              end if;
                         else
                              -- ignore the other b coefficients
                              write_en <= '0';
                         end if;
                    else
                         next_module_reset_bufferchain(0) <= '0';
                    end if;
                    pbs_res_reordered <= i_pbs_result; -- no reordering, sample-extract-index 0
               end if;
               next_module_reset_bufferchain(1 to next_module_reset_bufferchain'length - 1) <= next_module_reset_bufferchain(0 to next_module_reset_bufferchain'length - 2);
          end if;
     end process;

     o_next_module_reset <= next_module_reset_bufferchain(next_module_reset_bufferchain'length - 1);

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
                    i_wr_addr => pbs_res_cnt,
                    i_rd_addr => i_ram_coeff_idx,
                    o_data    => o_coeffs(coeff_idx)
               );
     end generate;

end architecture;
