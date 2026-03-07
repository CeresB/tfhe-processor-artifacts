----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: op_pbs_pingpongbuffer.vhd
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: takes batchsize-many operations for the pbs and relays the data for the other buffers.
--             Moreover, the module keeps the return-address and sample_extract_idx in a ping-pong buffer to
--             return them just when they are needed. A ping-pong buffer is needed since when a new batch starts
--             there is a brief window where the new values must be stored but the old values are still needed.
--             The module requests data from hbm and uses that to fill the buffers.
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
     use work.datatypes_utils.all;
     use work.tfhe_constants.all;
     use work.ip_cores_constants.all;
     use work.math_utils.all;
     use work.processor_utils.all;

entity op_pbs_pingpongbuffer is
     port (
          i_clk                : in  std_ulogic;
          i_reset_n            : in  std_ulogic;
          i_pbs_reset          : in  std_ulogic;
          i_hbm_read_out       : in  hbm_ps_out_read_pkg;
          o_hbm_read_in        : out hbm_ps_in_read_pkg;

          -- outputs for other modules
          o_lut_start_addr     : out hbm_ps_port_memory_address;
          o_b_addr             : out hbm_ps_port_memory_address;
          o_a_addr             : out hbm_ps_port_memory_address;
          o_a_addr_valid       : out std_ulogic;
          -- o_return_address     : out hbm_ps_port_memory_address;
          -- o_return_address_valid          : out std_ulogic;
          -- o_sample_extract_idx : out idx_int;
          o_new_batch          : out std_ulogic
     );
end entity;

architecture Behavioral of op_pbs_pingpongbuffer is

     -- well before the output of the pbs is ready the next input can be accepted
     -- but we still need the old addresses! Therefore we use a ping-pong buffer here
     -- do the same for sample-extract & the return address
     -- signal sample_extract_idx_bufferchain : idx_int_array(0 to 2*pbs_batchsize - 1);

     -- signal batchsize_in_cnt    : unsigned(0 to get_bit_length(2*pbs_batchsize-1) - 1);
     constant reset_control_cnt_max_val : integer := pbs_return_addr_delay;
     signal control_cnt                       : unsigned(0 to get_bit_length(reset_control_cnt_max_val) - 1);
     signal batchsize_in_rq_cnt : unsigned(0 to get_bit_length(2*pbs_batchsize-1) - 1);
     signal batchsize_in_cnt_offset : unsigned(0 to batchsize_in_rq_cnt'length - 1);

     -- signal sample_extract_idx_batchsize_cnt : unsigned(0 to batchsize_in_cnt'length - 1);
     -- signal sample_extract_idx_batchsize_cnt_offset : unsigned(0 to batchsize_in_cnt'length - 1);

     -- signal reset_for_sample_extract_idx_crtl : std_ulogic;
     -- signal ready_to_output                       : std_ulogic;
     -- constant update_every : integer := (k + 1) * num_coefficients / pbs_throughput;
     -- signal update_cnt : unsigned(0 to get_bit_length(update_every - 1) - 1);

     signal hbm_rq_addr       : unsigned(0 to hbm_ps_port_addr_width-1);
     signal op                : pbs_operation;
     signal new_batch         : std_ulogic;

     signal lut_start_addr_buf       : hbm_ps_port_memory_address_arr(0 to op_buffer_output_buffer-1);
     signal lwe_addr_buf       : hbm_ps_port_memory_address_arr(0 to op_buffer_output_buffer-1);
     signal lwe_addr_valid_buf       : std_ulogic_vector(0 to op_buffer_output_buffer-1);
     signal new_batch_buf       : std_ulogic_vector(0 to op_buffer_output_buffer+1-1); -- +1 as new-batch signal must be delayed

     -- signal enough_rqs_to_fill_buf : std_ulogic; -- no need, we do it directly via address valid

begin

     op.lwe_addr_in        <= unsigned(i_hbm_read_out.rdata(op.lwe_addr_in'length - 1 downto 0));
     op.lut_start_addr     <= unsigned(i_hbm_read_out.rdata(op.lwe_addr_in'length + op.lut_start_addr'length - 1 downto op.lwe_addr_in'length));
     -- op.lwe_addr_out       <= unsigned(i_hbm_read_out.rdata(op.lwe_addr_in'length + op.lwe_addr_out'length - 1 downto op.lwe_addr_in'length));
     -- op.sample_extract_idx <= unsigned(i_hbm_read_out.rdata(op.lwe_addr_in'length + op.lwe_addr_out'length + op.lut_start_addr'length + op.sample_extract_idx'length - 1 downto op.lwe_addr_in'length + op.lwe_addr_out'length + op.lut_start_addr'length));

     o_hbm_read_in.rready <= '1';
     o_hbm_read_in.arlen  <= std_logic_vector(to_unsigned(0, o_hbm_read_in.arlen'length));
     o_hbm_read_in.arid   <= std_logic_vector(to_unsigned(0, o_hbm_read_in.arid'length)); -- should not be important for this module

     other_buffers_passthrough: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               -- respect op-buffer output-buffers
               lut_start_addr_buf <= op.lut_start_addr & lut_start_addr_buf(0 to lut_start_addr_buf'length - 2);
               lwe_addr_buf <= op.lwe_addr_in & lwe_addr_buf(0 to lwe_addr_buf'length - 2);
               lwe_addr_valid_buf <= i_hbm_read_out.rvalid & lwe_addr_valid_buf(0 to lwe_addr_valid_buf'length - 2);
               new_batch_buf <= new_batch & new_batch_buf(0 to new_batch_buf'length - 2);
          end if;
     end process;
     o_lut_start_addr <= lut_start_addr_buf(lwe_addr_buf'length-1);
     o_a_addr <= lwe_addr_buf(lwe_addr_buf'length-1);
     o_b_addr <= lwe_addr_buf(lwe_addr_buf'length-1);
     o_new_batch <= new_batch_buf(new_batch_buf'length-1);
     o_a_addr_valid <= lwe_addr_valid_buf(lwe_addr_valid_buf'length-1);

     -- sample extract idx is given for the input of sample_extract for the rotation
     -- However, we also need it after sample-extract to extract the .b part
     -- --> there is a delay between these two cases
     crtl: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if control_cnt = to_unsigned(blind_rot_iter_latency - 1, control_cnt'length) then
                    new_batch <= '1';
               else
                    new_batch <= '0';
               end if;

               if i_reset_n = '0' then
                    control_cnt <= to_unsigned(0, control_cnt'length);
                    batchsize_in_rq_cnt <= to_unsigned(pbs_batchsize-1, batchsize_in_rq_cnt'length);
                    -- reset_for_sample_extract_idx_crtl <= '1';
                    o_hbm_read_in.arvalid <= '0';
                    -- ready_to_output <= '0';
                    -- enough_rqs_to_fill_buf <= '0';
               else
                    if i_pbs_reset = '0' then
                         if control_cnt < to_unsigned(reset_control_cnt_max_val, control_cnt'length) then
                              control_cnt <= control_cnt + to_unsigned(1, control_cnt'length);
                         else
                              control_cnt <= to_unsigned(0, control_cnt'length);
                         end if;
                    end if;

                    -- fetch new OPs from hbm
                    if batchsize_in_rq_cnt > 0 then
                         if i_hbm_read_out.arready = '1' then
                              batchsize_in_rq_cnt <= batchsize_in_rq_cnt - to_unsigned(1, batchsize_in_rq_cnt'length);
                              hbm_rq_addr <= hbm_rq_addr + to_unsigned(hbm_bytes_per_ps_port, hbm_rq_addr'length); -- modulos itself
                              o_hbm_read_in.araddr <= op_base_addr + hbm_rq_addr;
                         end if;
                         o_hbm_read_in.arvalid <= i_hbm_read_out.arready;
                    else
                         if new_batch = '1' then
                              batchsize_in_rq_cnt <= to_unsigned(pbs_batchsize-1, batchsize_in_rq_cnt'length);
                              if batchsize_in_cnt_offset = to_unsigned(0,batchsize_in_cnt_offset'length) then
                                   batchsize_in_cnt_offset <= to_unsigned(pbs_batchsize, batchsize_in_cnt_offset'length);
                              else
                                   batchsize_in_cnt_offset <= to_unsigned(0, batchsize_in_cnt_offset'length);
                              end if;
                         end if;
                         -- ready_to_output <= '1';
                         o_hbm_read_in.arvalid <= '0';
                    end if;

                    -- -- drop the resets at the right time and register the switch at the right time
                    -- if control_cnt = to_unsigned(sample_extract_idx_delay, control_cnt'length) then
                    --      reset_for_sample_extract_idx_crtl <= '0';
                    --      if sample_extract_idx_batchsize_cnt_offset = to_unsigned(0,sample_extract_idx_batchsize_cnt_offset'length) then
                    --           sample_extract_idx_batchsize_cnt_offset <= to_unsigned(pbs_batchsize, sample_extract_idx_batchsize_cnt_offset'length);
                    --      else
                    --           sample_extract_idx_batchsize_cnt_offset <= to_unsigned(0, sample_extract_idx_batchsize_cnt_offset'length);
                    --      end if;
                    -- end if;
               end if;
          end if;
     end process;

     -- ping_pong_OP_buffer_write: process (i_clk) is
     -- begin
     --      if rising_edge(i_clk) then
     --           if i_reset_n = '0' then
     --                batchsize_in_cnt <= to_unsigned(0, batchsize_in_cnt'length);
     --           else
     --                -- buffer return address and sample_extract_idx
     --                if control_cnt = to_unsigned(reset_control_cnt_max_val, control_cnt'length) then
     --                     batchsize_in_cnt <= to_unsigned(pbs_batchsize - 1, batchsize_in_cnt'length);
     --                else
     --                     if i_hbm_read_out.rvalid = '1' then
     --                          if batchsize_in_cnt > 0 then
     --                               batchsize_in_cnt <= batchsize_in_cnt - to_unsigned(1, batchsize_in_cnt'length);
     --                          else
     --                               -- reset the counter once a new batch comes in
     --                          end if;
     --                          sample_extract_idx_bufferchain(to_integer(batchsize_in_cnt+batchsize_in_cnt_offset)) <= op.sample_extract_idx;
     --                     end if;
     --                end if;
     --           end if;
     --      end if;
     -- end process;

     -- ping_pong_OP_buffer_read: process (i_clk) is
     -- begin
     --      if rising_edge(i_clk) then
     --           if i_reset_n = '0' or ready_to_output = '0' or i_pbs_reset = '1' then
     --                sample_extract_idx_batchsize_cnt <= to_unsigned(pbs_batchsize - 1, sample_extract_idx_batchsize_cnt'length);
     --                update_cnt <= to_unsigned(update_every - 1, update_cnt'length);
     --           else
     --                -- other signals are valid for the whole ciphertext, so we only update them when the ciphertext had enough time to be processed
     --                if update_cnt > 0 then
     --                     update_cnt <= update_cnt - to_unsigned(1, update_cnt'length);
     --                else
     --                     update_cnt <= to_unsigned(update_every - 1, update_cnt'length);
     --                end if;

     --                if update_cnt = to_unsigned(update_every - 1, update_cnt'length) then
     --                     -- sample_extract_idx
     --                     if reset_for_sample_extract_idx_crtl = '0' then
     --                          if sample_extract_idx_batchsize_cnt > 0 then
     --                               sample_extract_idx_batchsize_cnt <= sample_extract_idx_batchsize_cnt - to_unsigned(1, sample_extract_idx_batchsize_cnt'length);
     --                          else
     --                               sample_extract_idx_batchsize_cnt <= to_unsigned(pbs_batchsize - 1, sample_extract_idx_batchsize_cnt'length);
     --                          end if;
     --                     end if;
     --                     o_sample_extract_idx <= sample_extract_idx_bufferchain(to_integer(sample_extract_idx_batchsize_cnt+sample_extract_idx_batchsize_cnt_offset));
     --                end if;
     --           end if;
     --      end if;
     -- end process;

end architecture;
