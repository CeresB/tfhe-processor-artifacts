----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: pbs_lwe_n_storage_read_to_hbm
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: handles read calls to the BRAM that stores the output of the pbs.
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
  use work.ip_cores_constants.all;

entity pbs_lwe_n_storage_read_to_hbm is
  port (
    i_clk           : in  std_ulogic;
    i_coeffs        : in  sub_polynom(0 to pbs_throughput - 1);
    i_reset         : in  std_ulogic;
    i_hbm_write_out : in  hbm_ps_out_write_pkg;
    o_hbm_write_in  : out hbm_ps_in_write_pkg;
    o_ram_coeff_idx : out unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
    o_done          : out std_ulogic
  );
end entity;

architecture Behavioral of pbs_lwe_n_storage_read_to_hbm is

  signal coeffs_valid_chain: std_ulogic_vector(0 to default_ram_retiming_latency+1-1); -- bram buffers answers ram retiming latency tics later
  signal wlast_int_chain   : std_ulogic_vector(0 to coeffs_valid_chain'length-1);
  type throu_cnt_chain is array (natural range <>) of unsigned(0 to log2_pbs_throughput - 1);
  signal out_cnt_pbs_throughput_chain: throu_cnt_chain(0 to coeffs_valid_chain'length - 1); -- modulos itself
  signal hbm_write_in_buf : hbm_ps_in_write_pkg;
  signal cnt_till_next_batch : unsigned(0 to get_bit_length(blind_rotation_latency - 1) - 1);
  signal out_write_blocks_offset          : unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);

  signal out_pkg       : sub_polynom(0 to hbm_coeffs_per_clock_per_ps_port - 1);

  signal hbm_write_address_offset : unsigned(0 to hbm_ps_port_addr_width - 1);


  -- -- if hbm busy when values arrive just request them again
  -- type addr_offset_chain is array(natural range <>) of unsigned(0 to hbm_write_address'length - 1);
  -- signal wr_addr_chain: addr_offset_chain(0 to coeffs_valid_chain'length-1);

begin

  out_buf: if lwe_n_buf_out_buffer generate
    process (i_clk) is
    begin
      if rising_edge(i_clk) then
        o_hbm_write_in <= hbm_write_in_buf;
      end if;
    end process;
  end generate;

  no_out_buf: if not lwe_n_buf_out_buffer generate
    o_hbm_write_in <= hbm_write_in_buf;
  end generate;

  coeffs2bits: for coeff_idx in 0 to out_pkg'length - 1 generate
    bits2bits: for bit_idx in 0 to out_pkg(0)'length - 1 generate
      hbm_write_in_buf.wdata(coeff_idx * out_pkg(0)'length + bit_idx) <= out_pkg(coeff_idx)(bit_idx);
    end generate;
  end generate;

  hbm_write_in_buf.bready       <= '1';
  hbm_write_in_buf.awlen        <= std_logic_vector(to_unsigned(0, hbm_write_in_buf.awlen'length));
  hbm_write_in_buf.awid         <= std_logic_vector(resize(hbm_write_address_offset, hbm_write_in_buf.awid'length));
  hbm_write_in_buf.wdata_parity <= (others => '0');

  o_done <= i_hbm_write_out.bvalid and wlast_int_chain(wlast_int_chain'length-1); -- signal done when last write of a full lwe_n batch was written to HBM

  pbs_result_to_ram: process (i_clk) is
  begin
    if rising_edge(i_clk) then
      if i_reset = '1' then
        coeffs_valid_chain(0) <= '0';
        wlast_int_chain(0) <= '0';
        out_cnt_pbs_throughput_chain(0) <= to_unsigned(0, out_cnt_pbs_throughput_chain(0)'length);
        out_write_blocks_offset <= to_unsigned(0, out_write_blocks_offset'length);
        hbm_write_address_offset <= to_unsigned(0, hbm_write_address_offset'length);
        cnt_till_next_batch <= to_unsigned(blind_rotation_latency-1, cnt_till_next_batch'length);
      else

        if cnt_till_next_batch = 0 then
          cnt_till_next_batch <= to_unsigned(blind_rotation_latency - 1, cnt_till_next_batch'length);
          out_write_blocks_offset <= to_unsigned(0, out_write_blocks_offset'length);
          wlast_int_chain(0) <= '0';
        else
          cnt_till_next_batch <= cnt_till_next_batch - to_unsigned(1, cnt_till_next_batch'length);
          if i_hbm_write_out.awready = '1' then
            -- send the next address-data pair
            -- first fetch it from the buffer
            if out_cnt_pbs_throughput_chain(0) = 0 then
              -- if last read block fully processed get a new one
              if out_write_blocks_offset < to_unsigned(write_blocks_in_lwe_n_ram - 1, out_write_blocks_offset'length) then
                out_write_blocks_offset <= out_write_blocks_offset + to_unsigned(1, out_write_blocks_offset'length);
                coeffs_valid_chain(0) <= '1';
              else
                -- done - whole buffer read to hbm
                -- continue when the next batch starts by resetting out_write_blocks_offset
                coeffs_valid_chain(0) <= '0';
                wlast_int_chain(0) <= '1';
              end if;
            else
              out_cnt_pbs_throughput_chain(0) <= out_cnt_pbs_throughput_chain(0) + to_unsigned(hbm_coeffs_per_clock_per_ps_port,out_cnt_pbs_throughput_chain(0)'length);
            end if;
          else
            if out_cnt_pbs_throughput_chain(0) = 0 then
              -- want to request a new block but couldnt
              coeffs_valid_chain(0) <= '0';
            end if;
          end if;
        end if;
        
        if coeffs_valid_chain(coeffs_valid_chain'length-1-1) = '1' then -- total address calculation takes another clk tic, so this happends one earlier
          -- increment address
          hbm_write_address_offset <= hbm_write_address_offset + to_unsigned(hbm_bytes_per_ps_port, hbm_write_address_offset'length);
        end if;
      end if;

      o_ram_coeff_idx <= out_write_blocks_offset;
      coeffs_valid_chain(1 to coeffs_valid_chain'length-1) <= coeffs_valid_chain(0 to coeffs_valid_chain'length-2);
      wlast_int_chain(1 to wlast_int_chain'length-1) <= wlast_int_chain(0 to wlast_int_chain'length-2);
      out_cnt_pbs_throughput_chain(1 to out_cnt_pbs_throughput_chain'length-1) <= out_cnt_pbs_throughput_chain(0 to out_cnt_pbs_throughput_chain'length-2);
      hbm_write_in_buf.awaddr <= hbm_write_address_offset + res_base_addr;

      -- set write package for hbm
      if coeffs_valid_chain(coeffs_valid_chain'length-1-1) = '1' then -- total address calculation takes another clk tic, so this happends one earlier
        -- set data
        for coeff_idx in 0 to out_pkg'length-1 loop
          out_pkg(coeff_idx) <= i_coeffs(coeff_idx + to_integer(out_cnt_pbs_throughput_chain(out_cnt_pbs_throughput_chain'length-1)));
        end loop;
      end if;
      hbm_write_in_buf.awvalid <= coeffs_valid_chain(coeffs_valid_chain'length-1);
      hbm_write_in_buf.wvalid <= coeffs_valid_chain(coeffs_valid_chain'length-1);
      hbm_write_in_buf.wlast <= wlast_int_chain(wlast_int_chain'length-1);
    end if;
  end process;

end architecture;
