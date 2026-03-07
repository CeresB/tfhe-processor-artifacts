----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: pbs_lut_buffer
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: The module requests data from hbm and uses that to fill its buffer.
--             For each ciphertext in the pbs pipeline the corresponsing lut is requested.
--             Meaning that if all ciphertexts start with the same lut, that one lut is requested batchsize-many times.
--             The module outputs the lookup-tables for the start of the pbs, so one blind_rotation_interation,
--             but we still output them the whole time.
--             This module has time until all the other blind_rotation_iterations finish to receive the new luts from hbm.
--             In total: like pbs_b_buffer but here whole ciphertexts instead of coefficients are buffered.
--              consequently, the output changes every clock cycle and an adidtional counter (lut_block_coeff_cnt) is needed
--              to organize what is coming from HBM.
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
library work;
     use work.constants_utils.all;
     use work.ip_cores_constants.all;
     use work.datatypes_utils.all;
     use work.tfhe_constants.all;
     use work.math_utils.all;
     use work.processor_utils.all;

entity pbs_lut_buffer is
     port (
          i_clk             : in  std_ulogic;
          i_new_batch       : in  std_ulogic;
          i_lut_start_addr  : in  hbm_ps_port_memory_address;
          i_reset_n         : in  std_ulogic;
          i_pbs_reset       : in  std_ulogic; -- it takes ram_retiming_latency until values can follow after pbs_reset drops
          i_hbm_read_out    : in  hbm_ps_out_read_pkg;
          o_hbm_read_in     : out hbm_ps_in_read_pkg;
          o_lut_part        : out sub_polynom(0 to pbs_throughput - 1);
          o_ready_to_output : out std_ulogic
     );
end entity;

architecture Behavioral of pbs_lut_buffer is

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

     constant num_lut_blocks     : integer := coeffs_per_pbs_lut / pbs_throughput;
     constant storage_num_blocks : integer := num_lut_blocks * pbs_batchsize;

     signal lut_block_coeff_cnt : unsigned(0 to log2_pbs_throughput - 1);

     signal lut_in_block_cnt  : unsigned(0 to get_bit_length(storage_num_blocks - 1) - 1);
     signal lut_out_block_cnt : unsigned(0 to lut_in_block_cnt'length - 1);

     signal lut_addresses    : hbm_ps_port_memory_address_arr(0 to pbs_batchsize - 1);
     signal rq_addr_offset: hbm_ps_port_memory_address;
     signal lut_addr_in_cnt  : unsigned(0 to get_bit_length(lut_addresses'length) - 1);
     signal lut_addr_out_cnt : unsigned(0 to lut_addr_in_cnt'length - 1);
     -- signal lut_coeff_in_cnt : unsigned(0 to get_bit_length(num_lut_blocks - 1) - 1);

     signal write_en_vec : std_ulogic_vector(0 to o_lut_part'length - 1);
     signal hbm_part     : sub_polynom(0 to hbm_coeffs_per_clock_per_ps_port - 1);

begin

     o_hbm_read_in.rready <= '1'; -- we immediately read the value
     o_hbm_read_in.arlen  <= std_logic_vector(to_unsigned(0, o_hbm_read_in.arlen'length));

     o_hbm_read_in.arid <= std_logic_vector(to_unsigned(0, o_hbm_read_in.arid'length)); -- should not be important for this module

     read_write_logic: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if i_reset_n = '0' then
                    o_hbm_read_in.arvalid <= '0';
                    o_ready_to_output <= '0';
                    lut_in_block_cnt <= to_unsigned(storage_num_blocks - 1, lut_in_block_cnt'length);
                    lut_block_coeff_cnt <= to_unsigned(0, lut_block_coeff_cnt'length);
               else
                    -- input from hbm
                    if i_hbm_read_out.rvalid = '1' then -- we expect that rvalid is only active one clock tic
                         lut_block_coeff_cnt <= lut_block_coeff_cnt + to_unsigned(hbm_coeffs_per_clock_per_ps_port, lut_block_coeff_cnt'length); -- modulos itself
                         if lut_block_coeff_cnt = to_unsigned(pbs_throughput-hbm_coeffs_per_clock_per_ps_port,lut_block_coeff_cnt'length) then
                              if lut_in_block_cnt > 0 then
                                   lut_in_block_cnt <= lut_in_block_cnt - to_unsigned(1, lut_in_block_cnt'length);
                              else
                                   lut_in_block_cnt <= to_unsigned(storage_num_blocks - 1, lut_in_block_cnt'length);
                                   o_ready_to_output <= '1';
                              end if;
                         end if;
                    end if;
               end if;

               -- input from op buffer
               if i_new_batch = '1' then
                    -- technically we should wait one br-iteration so that everything in lut buffer was used
                    -- but since the hbm is slower than this buffer we are not overwriting any unused data in the buffer
                    lut_addr_in_cnt <= to_unsigned(pbs_batchsize-1, lut_addr_in_cnt'length);
                    lut_addr_out_cnt <= to_unsigned(pbs_batchsize-1, lut_addr_out_cnt'length);
                    rq_addr_offset <= to_unsigned(coeffs_per_pbs_lut-hbm_bytes_per_ps_port,rq_addr_offset'length);
               else
                    -- we expect that after new_batch='1' the op buffer provides batchsize-many lut addresses and then stops until new_batch is triggered again
                    if lut_addr_in_cnt > 0 then
                         lut_addr_in_cnt <= lut_addr_in_cnt - to_unsigned(1, lut_addr_in_cnt'length);
                         lut_addresses(to_integer(lut_addr_in_cnt)) <= i_lut_start_addr;
                    else
                         -- we have all lut addresses and can start requesting
                         -- wait one br-iteration before doing this, so that we don't overwrite the values that are used in the current iteration
                         -- is respected by i_new_batch being one br-iteration late
                         if i_hbm_read_out.arready = '1' and lut_addr_out_cnt > 0 then
                              o_hbm_read_in.arvalid <= '1';
                              o_hbm_read_in.araddr <= lut_addresses(to_integer(lut_addr_out_cnt)) + rq_addr_offset;
                              if rq_addr_offset > 0 then
                                   rq_addr_offset <= rq_addr_offset - to_unsigned(hbm_bytes_per_ps_port,rq_addr_offset'length);
                              else
                                   rq_addr_offset <= to_unsigned(coeffs_per_pbs_lut-hbm_bytes_per_ps_port,rq_addr_offset'length);
                                   -- if lut complete, request next lut
                                   lut_addr_out_cnt <= lut_addr_out_cnt - to_unsigned(1, lut_addr_out_cnt'length);
                              end if;
                         else
                              o_hbm_read_in.arvalid <= '0';
                         end if;
                    end if;
               end if;

               -- output to pbs module
               if i_pbs_reset = '1' then
                    lut_out_block_cnt <= to_unsigned(storage_num_blocks - 1, lut_out_block_cnt'length);
               else
                    if lut_out_block_cnt > 0 then
                         lut_out_block_cnt <= lut_out_block_cnt - to_unsigned(1, lut_out_block_cnt'length);
                    else
                         lut_out_block_cnt <= to_unsigned(storage_num_blocks - 1, lut_out_block_cnt'length);
                    end if;
               end if;

          end if;
     end process;

     bits2coeffs: for coeff_idx in 0 to hbm_part'length - 1 generate
          bits2bits: for bit_idx in 0 to hbm_part(0)'length - 1 generate
               hbm_part(coeff_idx)(bit_idx) <= i_hbm_read_out.rdata(coeff_idx * hbm_part(0)'length + bit_idx);
          end generate;
     end generate;

     brams_per_throughput: for coeff_idx in 0 to o_lut_part'length - 1 generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    if lut_block_coeff_cnt = to_unsigned(coeff_idx - coeff_idx mod hbm_coeffs_per_clock_per_ps_port, lut_block_coeff_cnt'length) then
                         write_en_vec(coeff_idx) <= '1';
                    else
                         write_en_vec(coeff_idx) <= '0';
                    end if;
               end if;
          end process;
          ram_elem: manual_bram
               generic map (
                    addr_length         => lut_out_block_cnt'length,
                    ram_length          => storage_num_blocks,
                    ram_out_bufs_length => lut_buf_ram_retiming_latency,
                    ram_type            => ram_style_auto,
                    coeff_bit_width     => hbm_part(0)'length
               )
               port map (
                    i_clk     => i_clk,
                    i_wr_en   => write_en_vec(coeff_idx),
                    i_wr_data => hbm_part(coeff_idx mod hbm_part'length),
                    i_wr_addr => lut_in_block_cnt,
                    i_rd_addr => lut_out_block_cnt,
                    o_data    => o_lut_part(coeff_idx)
               );
     end generate;

end architecture;
