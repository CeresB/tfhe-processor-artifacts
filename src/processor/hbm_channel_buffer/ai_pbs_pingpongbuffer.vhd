----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ai_pbs_pingpongbuffer.vhd
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: takes ai for the pbs and buffers it in a way that it provides the signals at the correct time for the pbs.
--             A ping-pong buffer is used. The module requests data from hbm and uses that to fill the buffers.
--             The ping buffer is written to in the beginning. After that it is ready for the pbs. While one buffer provides
--             a_i for the pbs the other buffer is filled by a_(i+1).
--             Every blind rotation iteration the buffers switch function.
--             A single a_i is valid for a whole ciphertext. We have to wait accordingly many clock cycles before
--             we provide a_i for the next ciphertext. Only after all ciphertexts got their a_i value can we go on to a_(i+1).
--             Since a_i is a single coefficient but we read ai_hbm_coeffs_per_clk-many coefficients at once from HBM
--             there is plenty of time to request and receive the values for the buffers.
--             Since k_lwe is always a multiple of ai_hbm_coeffs_per_clk in our design, this works neatly.
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
     use work.ip_cores_constants.all;
     use work.datatypes_utils.all;
     use work.tfhe_constants.all;
     use work.math_utils.all;
     use work.processor_utils.all;

entity ai_pbs_pingpongbuffer is
     port (
          i_clk                    : in  std_ulogic;
          i_lwe_addr               : in  hbm_ps_port_memory_address;
          i_lwe_addr_valid         : in  std_ulogic;
          i_pbs_reset              : in  std_ulogic;
          i_reset_n                : in  std_ulogic;
          i_hbm_ps_in_read_out_pkg : in  hbm_ps_out_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
          o_hbm_ps_in_read_in_pkg  : out hbm_ps_in_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
          o_ai_coeff               : out rotate_idx;
          o_ready_to_output        : out std_ulogic
     );
end entity;

architecture Behavioral of ai_pbs_pingpongbuffer is

     -- memory pattern: receive input-blocks pbs_batchsize-times and store them
     -- return sequentially the first coefficient of each block, then the second, then the third and so on after a delay of clks_ai_valid
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

     signal lwe_in_addr_ram : hbm_ps_port_memory_address_arr(0 to 2*pbs_batchsize - 1);
     signal rq_addr_offset: hbm_ps_port_memory_address;
     signal addr_buf_batchsize_in_cnt : unsigned(0 to get_bit_length(pbs_batchsize - 1) - 1);

     signal ready_to_rq               : std_ulogic;
     signal enough_rqs_to_fill_ai_buf : std_ulogic;
     constant ping_buf_length : integer := pbs_batchsize;
     constant ram_len : integer := 2 * ping_buf_length;
     signal receive_cnt : unsigned(0 to get_bit_length(ram_len - 1) - 1);
     signal rq_cnt      : unsigned(0 to get_bit_length(pbs_batchsize - 1) - 1);

     -- ai_values are next to each other in memory, such that we get multiple at once
     signal ai_out_buf : rotate_idx_array(0 to ai_hbm_coeffs_per_clk - 1);

     signal out_batchsize_cnt        : unsigned(0 to receive_cnt'length - 1);
     signal out_batchsize_cnt_offset : unsigned(0 to out_batchsize_cnt'length - 1);
     signal out_batchsize_cnt_to_use : unsigned(0 to out_batchsize_cnt'length - 1);
     signal out_part_cnt             : unsigned(0 to get_bit_length(ai_hbm_coeffs_per_clk - 1) - 1);
     signal ai_val_valid_cnt         : unsigned(0 to get_bit_length(clks_ai_valid - 1) - 1);

     signal start_outputting : std_ulogic;
     signal init_done        : std_ulogic;
     signal do_request       : std_ulogic;

     signal hbm_data_stripped : rotate_idx_array(0 to ai_hbm_coeffs_per_clk - 1);
     signal hbm_part          : sub_polynom(0 to ai_hbm_coeffs_per_clk - 1);
     signal read_pkg          : hbm_ps_in_read_pkg;

     constant num_sub_blocks_coeffs : integer := ai_burstlen;
     signal receive_sub_block_coeff_cnt : unsigned(0 to get_bit_length(num_sub_blocks_coeffs) - 1);

     type out_cnt_arr is array(natural range <>) of unsigned(0 to out_part_cnt'length-1);
     signal out_part_cnt_buf_chain: out_cnt_arr(0 to default_ram_retiming_latency-1);

     signal ready_to_output_buf: std_ulogic_vector(0 to ai_buffer_output_buffer-1);

begin

     do_request <= '1' when (ready_to_rq = '1') and (i_hbm_ps_in_read_out_pkg(0).arready = '1') and (enough_rqs_to_fill_ai_buf = '0') else '0';
     o_ready_to_output <= ready_to_output_buf(ready_to_output_buf'length-1);

     -- we assume that the HBM is more than fast enough to write to the buffer, so it will never be too late but can be too early
     crtl_logic: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if i_reset_n = '0' then
                    addr_buf_batchsize_in_cnt <= to_unsigned(2*pbs_batchsize - 1, addr_buf_batchsize_in_cnt'length);
                    ready_to_rq <= '0';
                    enough_rqs_to_fill_ai_buf <= '0';

                    rq_cnt <= to_unsigned(pbs_batchsize - 1, rq_cnt'length);
                    init_done <= '0';
                    rq_addr_offset <= to_unsigned(0,rq_addr_offset'length);
               else

                    -- handle request addresses
                    -- input from op buffer, we expect i_lwe_addr_valid = '1' for batchsize-many clock tics
                    if i_lwe_addr_valid = '1' then
                         lwe_in_addr_ram(to_integer(addr_buf_batchsize_in_cnt)) <= i_lwe_addr;
                         if addr_buf_batchsize_in_cnt > 0 then
                              addr_buf_batchsize_in_cnt <= addr_buf_batchsize_in_cnt - to_unsigned(1, addr_buf_batchsize_in_cnt'length);
                         else
                              addr_buf_batchsize_in_cnt <= to_unsigned(2*pbs_batchsize - 1, addr_buf_batchsize_in_cnt'length);
                              ready_to_rq <= '1';
                         end if;
                    end if;

                    read_pkg.arvalid <= do_request;
                    read_pkg.araddr <= lwe_in_addr_ram(to_integer(rq_cnt)) + rq_addr_offset;
                    if do_request = '1' then
                         if rq_cnt > to_unsigned(0, rq_cnt'length) then
                              rq_cnt <= rq_cnt - to_unsigned(1, rq_cnt'length);
                         else
                              rq_cnt <= to_unsigned(pbs_batchsize - 1, rq_cnt'length);
                              init_done <= '1';
                              enough_rqs_to_fill_ai_buf <= init_done;
                              if rq_addr_offset < to_unsigned(ai_pkgs_per_lwe,rq_addr_offset'length) then
                                   rq_addr_offset <= rq_addr_offset + to_unsigned(ai_hbm_bytes_per_clk, rq_addr_offset'length);
                              else
                                   rq_addr_offset <= rq_addr_offset + to_unsigned(0, rq_addr_offset'length);
                              end if;
                         end if;
                    else
                         if out_part_cnt = to_unsigned(ai_hbm_coeffs_per_clk - 1, out_part_cnt'length) and out_batchsize_cnt=to_unsigned(pbs_batchsize-1,out_batchsize_cnt'length) then
                              -- whole ping buffer processed --> allow requests again
                              enough_rqs_to_fill_ai_buf <= '0';
                         end if;
                    end if;
               end if;

               if start_outputting = '1' then
                    -- ai is valid for a whole ciphertext, never change it during the time it is valid for
                    if ai_val_valid_cnt > 0 then
                         ai_val_valid_cnt <= ai_val_valid_cnt - to_unsigned(1, ai_val_valid_cnt'length);
                    else
                         ai_val_valid_cnt <= to_unsigned(clks_ai_valid - 1, ai_val_valid_cnt'length);
                         -- new ciphertext --> provide new ai-value --> out_batchsize_cnt enables that
                         if out_batchsize_cnt > 0 then
                              out_batchsize_cnt <= out_batchsize_cnt - to_unsigned(1, out_batchsize_cnt'length);
                         else
                              out_batchsize_cnt <= to_unsigned(pbs_batchsize - 1, out_batchsize_cnt'length);
                              if out_part_cnt > 0 then
                                   out_part_cnt <= out_part_cnt - to_unsigned(1, out_part_cnt'length);
                              else
                                   out_part_cnt <= to_unsigned(ai_hbm_coeffs_per_clk - 1, out_part_cnt'length);
                                   -- whole ai buffer was processed - switch the buffer
                                   if out_batchsize_cnt_offset = to_unsigned(0, out_batchsize_cnt_offset'length) then
                                        out_batchsize_cnt_offset <= to_unsigned(ping_buf_length, out_batchsize_cnt_offset'length);
                                   else
                                        out_batchsize_cnt_offset <= to_unsigned(0, out_batchsize_cnt_offset'length);
                                   end if;
                              end if;
                         end if;
                    end if;
               else
                    ai_val_valid_cnt <= to_unsigned(clks_ai_valid - 1, ai_val_valid_cnt'length);
                    out_batchsize_cnt <= to_unsigned(pbs_batchsize - 1, out_batchsize_cnt'length);
                    out_part_cnt <= to_unsigned(ai_hbm_coeffs_per_clk - 1, out_part_cnt'length);
                    out_batchsize_cnt_offset <= to_unsigned(0, out_batchsize_cnt_offset'length);
               end if;
               -- out_part_cnt is synchronous to out_batchsize_cnt
               -- out_part_cnt_buf_chain(0) is synchronous to out_batchsize_cnt_to_use
               -- and then it takes ram_retiming_latency until the values arrive from which we read o_ai_coeff
               out_part_cnt_buf_chain <= out_part_cnt & out_part_cnt_buf_chain(0 to out_part_cnt_buf_chain'length-2);
               o_ai_coeff <= ai_out_buf(to_integer(out_part_cnt_buf_chain(out_part_cnt_buf_chain'length-1)));

               out_batchsize_cnt_to_use <= out_batchsize_cnt + out_batchsize_cnt_offset;
          end if;
     end process;

     -- we expect that the requests are handled in the same order as we send them. We dont check the ids.
     read_pkg.rready <= '1';
     read_pkg.arid   <= std_logic_vector(to_unsigned(0, read_pkg.arid'length));  -- should not be important for this module
     read_pkg.arlen  <= std_logic_vector(to_unsigned(ai_burstlen, read_pkg.arlen'length));

     receive_cnt_logic: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if i_reset_n = '0' then
                    receive_cnt <= to_unsigned(2 * ping_buf_length - 1, receive_cnt'length);
                    receive_sub_block_coeff_cnt <= to_unsigned(num_sub_blocks_coeffs - 1, receive_sub_block_coeff_cnt'length);
                    ready_to_output_buf(0) <= '0';
               else
                    -- receive logic
                    if i_hbm_ps_in_read_out_pkg(0).rvalid = '1' then
                         if receive_sub_block_coeff_cnt > to_unsigned(num_sub_blocks_coeffs - 1, receive_sub_block_coeff_cnt'length) then
                              receive_sub_block_coeff_cnt <= receive_sub_block_coeff_cnt + to_unsigned(ai_hbm_coeffs_per_clk, receive_sub_block_coeff_cnt'length);
                         else
                              receive_sub_block_coeff_cnt <= to_unsigned(0, receive_sub_block_coeff_cnt'length);
                              if receive_cnt > 0 then
                                   receive_cnt <= receive_cnt - to_unsigned(1, receive_cnt'length);
                              else
                                   receive_cnt <= to_unsigned(2 * ping_buf_length - 1, receive_cnt'length);
                                   ready_to_output_buf(0) <= '1';
                              end if;
                         end if;
                    end if;
               end if;
               ready_to_output_buf(1 to ready_to_output_buf'length - 1) <= ready_to_output_buf(0 to ready_to_output_buf'length - 2);
          end if;
     end process;

     initial_latency_counter: one_time_counter
          generic map (
               tripping_value     => blind_rot_iter_latency_till_ready_for_ai - ai_buffer_output_buffer - 1,
               out_negated        => false,
               bufferchain_length => log2_pbs_throughput
          )
          port map (
               i_clk     => i_clk,
               i_reset   => i_pbs_reset,
               o_tripped => start_outputting
          );

     bits2coeffs: for coeff_idx in 0 to hbm_part'length - 1 generate
          bits2bits: for bit_idx in 0 to hbm_part(0)'length - 1 generate
               hbm_part(coeff_idx)(bit_idx) <= i_hbm_ps_in_read_out_pkg(coeff_idx / hbm_coeffs_per_clock_per_ps_port).rdata((coeff_idx mod hbm_coeffs_per_clock_per_ps_port) * hbm_part(0)'length + bit_idx);
          end generate;
     end generate;

     -- ai buffer treats its hbm channels as one. Need to replicate the signal correctly with the addresses
     one_port_to_many: for port_idx in 0 to o_hbm_ps_in_read_in_pkg'length - 1 generate
          o_hbm_ps_in_read_in_pkg(port_idx).arid    <= read_pkg.arid;
          o_hbm_ps_in_read_in_pkg(port_idx).arlen   <= read_pkg.arlen;
          o_hbm_ps_in_read_in_pkg(port_idx).arvalid <= read_pkg.arvalid;
          o_hbm_ps_in_read_in_pkg(port_idx).rready  <= read_pkg.rready;
          -- set the addr-bits that lead to the channel, keep the channel addr-bits
          o_hbm_ps_in_read_in_pkg(port_idx).araddr(hbm_port_and_stack_addr_width - 1 downto 0)                                        <= ai_base_addr(hbm_port_and_stack_addr_width - 1 downto 0) + to_unsigned(port_idx, hbm_port_and_stack_addr_width);
          o_hbm_ps_in_read_in_pkg(port_idx).araddr(o_hbm_ps_in_read_in_pkg(0).araddr'length - 1 downto hbm_port_and_stack_addr_width) <= read_pkg.araddr(o_hbm_ps_in_read_in_pkg(0).araddr'length - 1 downto hbm_port_and_stack_addr_width);
     end generate;

     ai_brams: for coeff_idx in 0 to ai_out_buf'length - 1 generate
          hbm_data_stripped(coeff_idx) <= hbm_part(coeff_idx)(hbm_part(0)'length - hbm_data_stripped(0)'length to hbm_part(0)'length - 1);
          ram_elem: manual_bram
               generic map (
                    addr_length         => out_batchsize_cnt_to_use'length,
                    ram_length          => ram_len,
                    ram_out_bufs_length => ai_buffer_output_buffer,
                    ram_type            => ram_style_auto,
                    coeff_bit_width     => o_ai_coeff'length
               )
               port map (
                    i_clk     => i_clk,
                    i_wr_en   => i_hbm_ps_in_read_out_pkg(0).rvalid,
                    i_wr_data => hbm_data_stripped(coeff_idx),
                    i_wr_addr => receive_cnt,
                    i_rd_addr => out_batchsize_cnt_to_use,
                    o_data    => ai_out_buf(coeff_idx)
               );
     end generate;

end architecture;
