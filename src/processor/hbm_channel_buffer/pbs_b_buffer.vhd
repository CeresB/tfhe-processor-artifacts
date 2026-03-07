----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: pbs_b_buffer
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: The module requests data from hbm and uses that to fill its buffer.
--             The b values are only needed at the beginning of the pbs, so one blind_rotation_interation,
--             but we still output them the whole time.
--             This module has time until all the other blind_rotation_iterations finish to receive the new b values from hbm.
--             A single b is valid for a whole ciphertext. We have to wait accordingly many clock cycles before
--             we provide b for the next ciphertext.
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

entity pbs_b_buffer is
     port (
          i_clk             : in  std_ulogic;
          i_new_batch       : in  std_ulogic;
          i_lwe_addr        : in  hbm_ps_port_memory_address;
          i_reset_n         : in  std_ulogic;
          i_pbs_reset       : in  std_ulogic; -- it takes ram_retiming_latency until values can follow after pbs_reset drops
          i_hbm_read_out    : in  hbm_ps_out_read_pkg;
          o_hbm_read_in     : out hbm_ps_in_read_pkg;
          o_b               : out rotate_idx;
          o_ready_to_output : out std_ulogic
     );
end entity;

architecture Behavioral of pbs_b_buffer is

     signal b_storage : rotate_idx_array(0 to pbs_batchsize - 1);

     signal b_in_block_cnt  : unsigned(0 to get_bit_length(pbs_batchsize - 1) - 1);
     signal b_out_block_cnt : unsigned(0 to b_in_block_cnt'length - 1);
     signal b_val_valid_cnt : unsigned(0 to get_bit_length(clks_b_valid - 1) - 1);

     -- use ram retiming registers
     signal b_storage_end : rotate_idx_array(0 to b_buffer_output_buffer-1 - 1);

     signal b_addresses    : hbm_ps_port_memory_address_arr(0 to pbs_batchsize - 1);
     signal b_addr_ram_in_cnt  : unsigned(0 to get_bit_length(b_addresses'length) - 1);
     signal b_addr_ram_out_cnt : unsigned(0 to b_addr_ram_in_cnt'length - 1);

     signal hbm_part          : sub_polynom(0 to hbm_coeffs_per_clock_per_ps_port - 1);
     signal hbm_data_stripped : rotate_idx_array(0 to hbm_coeffs_per_clock_per_ps_port - 1);

     signal ready_to_output_buf: std_ulogic_vector(0 to b_buffer_output_buffer-1);

begin

     o_hbm_read_in.rready <= '1';
     o_hbm_read_in.arlen  <= std_logic_vector(to_unsigned(0, o_hbm_read_in.arlen'length));
     o_hbm_read_in.arid   <= std_logic_vector(to_unsigned(0, o_hbm_read_in.arid'length)); -- should not be important for this module

     o_ready_to_output <= ready_to_output_buf(ready_to_output_buf'length-1);

     read_write_logic: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if i_reset_n = '0' then
                    o_hbm_read_in.arvalid <= '0';
                    ready_to_output_buf(0) <= '0';
                    b_in_block_cnt <= to_unsigned(pbs_batchsize - 1, b_in_block_cnt'length);
               else
                    -- input from hbm
                    if i_hbm_read_out.rvalid = '1' then
                         b_storage(to_integer(b_in_block_cnt)) <= hbm_data_stripped(0);
                         if b_in_block_cnt > 0 then
                              b_in_block_cnt <= b_in_block_cnt - to_unsigned(1, b_in_block_cnt'length);
                         else
                              ready_to_output_buf(0) <= '1';
                              b_in_block_cnt <= to_unsigned(pbs_batchsize - 1, b_in_block_cnt'length);
                         end if;
                    end if;
               end if;
               ready_to_output_buf(1 to ready_to_output_buf'length - 1) <= ready_to_output_buf(0 to ready_to_output_buf'length - 2);

               -- input from op buffer
               if i_new_batch = '1' then
                    -- technically we should wait one br-iteration so that everything in b buffer was used, but that only counts for the data, not the addresses
                    -- but since the hbm is slower than this buffer we are not overwriting any unused data in the buffer
                    b_addr_ram_in_cnt <= to_unsigned(pbs_batchsize-1, b_addr_ram_in_cnt'length);
                    b_addr_ram_out_cnt <= to_unsigned(pbs_batchsize-1, b_addr_ram_out_cnt'length);
               else
                    -- we expect that after new_batch='1' the op buffer provides batchsize-many b addresses and then stops until new_batch is triggered again
                    if b_addr_ram_in_cnt > 0 then
                         b_addr_ram_in_cnt <= b_addr_ram_in_cnt - to_unsigned(1, b_addr_ram_in_cnt'length);
                         b_addresses(to_integer(b_addr_ram_in_cnt)) <= i_lwe_addr;
                    else
                         -- we have all b addresses and can start requesting
                         -- wait one br-iteration before doing this, so that we don't overwrite the values that are used in the current iteration
                         -- is respected by i_new_batch being one br-iteration late
                         if i_hbm_read_out.arready = '1' and b_addr_ram_out_cnt > 0 then
                              -- request next b-coeff
                              b_addr_ram_out_cnt <= b_addr_ram_out_cnt - to_unsigned(1, b_addr_ram_out_cnt'length);
                              o_hbm_read_in.arvalid <= '1';
                              o_hbm_read_in.araddr <= b_addresses(to_integer(b_addr_ram_out_cnt));
                              -- no need to increment address, b-part is always just one coefficient
                         else
                              o_hbm_read_in.arvalid <= '0';
                         end if;
                    end if;
               end if;

               -- output to pbs module
               if i_pbs_reset = '0' then
                    -- b is valid for a whole ciphertext, never change it during the time it is valid for
                    if b_val_valid_cnt > 0 then
                         b_val_valid_cnt <= b_val_valid_cnt - to_unsigned(1, b_val_valid_cnt'length);
                    else
                         b_val_valid_cnt <= to_unsigned(clks_b_valid - 1, b_val_valid_cnt'length);
                         if b_out_block_cnt > 0 then
                              b_out_block_cnt <= b_out_block_cnt - to_unsigned(1, b_out_block_cnt'length);
                         else
                              b_out_block_cnt <= to_unsigned(pbs_batchsize - 1, b_out_block_cnt'length);                                   
                         end if;
                    end if;
               else
                    b_out_block_cnt <= to_unsigned(pbs_batchsize - 1, b_out_block_cnt'length);
                    b_val_valid_cnt <= to_unsigned(clks_b_valid - 1, b_val_valid_cnt'length);
               end if;

               b_storage_end <= b_storage(to_integer(b_out_block_cnt)) & b_storage_end(0 to b_storage_end'length - 2);
          end if;
     end process;

     o_b <= b_storage_end(b_storage_end'length - 1);

     bits2coeffs: for coeff_idx in 0 to hbm_part'length - 1 generate
          bits2bits: for bit_idx in 0 to hbm_part(0)'length - 1 generate
               hbm_part(coeff_idx)(bit_idx) <= i_hbm_read_out.rdata(coeff_idx * hbm_part(0)'length + bit_idx);
          end generate;
          hbm_data_stripped(coeff_idx) <= hbm_part(coeff_idx)(hbm_part(0)'length - hbm_data_stripped(0)'length to hbm_part(0)'length - 1);
     end generate;

end architecture;
