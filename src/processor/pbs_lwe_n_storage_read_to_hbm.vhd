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
  use work.ip_cores_constants.all;
  use work.datatypes_utils.all;
  use work.tfhe_constants.all;
  use work.math_utils.all;
  use work.processor_utils.all;

entity pbs_lwe_n_storage_read_to_hbm is
  port (
    i_clk               : in  std_ulogic;
    i_coeffs            : in  sub_polynom(0 to pbs_throughput - 1);
    i_coeffs_valid      : in  std_ulogic;
    i_reset             : in  std_ulogic;
    i_hbm_write_out     : in  hbm_ps_out_write_pkg;
    o_hbm_write_in      : out hbm_ps_in_write_pkg;
    o_ram_coeff_idx     : out unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
    o_done              : out std_ulogic
  );
end entity;

architecture Behavioral of pbs_lwe_n_storage_read_to_hbm is

  -- counters to acces an individual coefficient in lwe_n storage
  signal out_cnt_pbs_throughput           : unsigned(0 to log2_pbs_throughput - 1); -- modulos itself
  signal out_cnt_pbs_write_blocks_per_lwe : unsigned(0 to get_bit_length(write_blocks_per_lwe - 1) - 1);
  signal out_write_blocks_offset          : unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);

  signal out_pkg       : sub_polynom(0 to hbm_coeffs_per_clock_per_ps_port - 1);
  signal out_piece_cnt : unsigned(0 to get_bit_length(pbs_throughput - 1) - 1);
  signal out_pkg_full  : std_ulogic;

  signal hbm_write_address : hbm_ps_port_memory_address;
  constant max_hbm_write_addr_offset : integer := write_blocks_in_lwe_n_ram - 1;

  -- signal done_reg : std_ulogic;
  signal wlast_int : std_ulogic;

begin

    coeffs2bits: for coeff_idx in 0 to out_pkg'length - 1 generate
    bits2bits: for bit_idx in 0 to out_pkg(0)'length - 1 generate
      o_hbm_write_in.wdata(coeff_idx * out_pkg(0)'length + bit_idx) <= out_pkg(coeff_idx)(bit_idx);
    end generate;
  end generate;

  o_hbm_write_in.bready <= '1';
  o_hbm_write_in.awlen <= std_logic_vector(to_unsigned(0, o_hbm_write_in.awlen'length));
  o_hbm_write_in.awid <= std_logic_vector(resize(hbm_write_address, o_hbm_write_in.awid'length));
  o_hbm_write_in.wdata_parity <= (others => '0');

  o_done <= i_hbm_write_out.bvalid and wlast_int; -- signal done when last write of a full lwe_n batch was written to HBM

  pbs_result_to_ram: process (i_clk) is
  begin
    if rising_edge(i_clk) then
      o_hbm_write_in.awaddr <= hbm_write_address;

      if i_reset = '1' then
        out_cnt_pbs_throughput <= to_unsigned(0, out_cnt_pbs_throughput'length);
        out_cnt_pbs_write_blocks_per_lwe <= to_unsigned(0, out_cnt_pbs_write_blocks_per_lwe'length);
        out_write_blocks_offset <= to_unsigned(0, out_write_blocks_offset'length);
        out_piece_cnt <= to_unsigned(0, out_piece_cnt'length);
        out_pkg_full <= '0';
        hbm_write_address <= res_base_addr;
        o_hbm_write_in.awvalid <= '0';
        o_hbm_write_in.wvalid <= '0';
        o_hbm_write_in.wlast <= '0';
        wlast_int <= '0';
      else

        if out_pkg_full='0' then
          -- data is requested and the buffer is immediately full again
          out_pkg_full <= '1';
        else
          if i_hbm_write_out.bvalid = '1' then
            -- hbm fetched the result
            out_pkg_full <= '0';
          end if;
        end if;

        if out_pkg_full='0' then
          -- fetch coeffs from buffer
          -- when it comes to the b-block only output b, that saves time
          -- b is in the last block of a ciphertext
          -- if we are at the block before and about to switch throughput cnt must stay put
          if out_cnt_pbs_write_blocks_per_lwe = to_unsigned(write_blocks_per_lwe - 2, out_cnt_pbs_write_blocks_per_lwe'length) and out_cnt_pbs_throughput = to_unsigned(pbs_throughput - 1, out_cnt_pbs_throughput'length) then
            -- do not change throughput cnt. This will leave it at pbs_throughput-1 and subsequently increase
            -- out_cnt_pbs_write_blocks_per_lwe again, skipping all but one coefficients in the b-block.
            -- This is why we need to write the b-value in the last position of its block.
          else
            out_cnt_pbs_throughput <= out_cnt_pbs_throughput + to_unsigned(1, out_cnt_pbs_throughput'length);
          end if;

          if out_cnt_pbs_throughput = to_unsigned(pbs_throughput - 1, out_cnt_pbs_throughput'length) then
            if out_cnt_pbs_write_blocks_per_lwe < to_unsigned(write_blocks_per_lwe - 1, out_cnt_pbs_write_blocks_per_lwe'length) then
              out_cnt_pbs_write_blocks_per_lwe <= out_cnt_pbs_write_blocks_per_lwe + to_unsigned(1, out_cnt_pbs_write_blocks_per_lwe'length);
            else
              out_cnt_pbs_write_blocks_per_lwe <= to_unsigned(0, out_cnt_pbs_write_blocks_per_lwe'length);
              -- this offset avoids multiplying batchsize_cnt with write_blocks_per_lwe
              if out_write_blocks_offset < to_unsigned(write_blocks_in_lwe_n_ram - write_blocks_per_lwe, out_write_blocks_offset'length) then
                out_write_blocks_offset <= out_write_blocks_offset + to_unsigned(write_blocks_per_lwe, out_write_blocks_offset'length);
              else
                out_write_blocks_offset <= to_unsigned(0, out_write_blocks_offset'length);
              end if;
            end if;
          end if;
        end if;

        if i_hbm_write_out.wready = '1' and i_coeffs_valid='1' then
          -- result-part was received, send next part
          for i in 0 to out_pkg'length - 1 loop
            out_pkg(i) <= i_coeffs(i + to_integer(out_piece_cnt));
          end loop;
          if out_piece_cnt < to_unsigned(pbs_throughput - hbm_coeffs_per_clock_per_ps_port, out_piece_cnt'length) then
            out_piece_cnt <= out_piece_cnt + to_unsigned(hbm_coeffs_per_clock_per_ps_port, out_piece_cnt'length);
          else
            out_piece_cnt <= to_unsigned(0, out_piece_cnt'length);
            if hbm_write_address < res_base_addr+to_unsigned(max_hbm_write_addr_offset, hbm_write_address'length) then
              hbm_write_address <= hbm_write_address + to_unsigned(1, hbm_write_address'length);
              o_hbm_write_in.wlast <= '0';
              wlast_int <= '0';
            else
              hbm_write_address <= res_base_addr;
              o_hbm_write_in.wlast <= '1';
              wlast_int <= '1';
            end if;
          end if;
          o_hbm_write_in.awvalid <= '1';
          o_hbm_write_in.wvalid <= '1';
        else
          o_hbm_write_in.awvalid <= '0';
          o_hbm_write_in.wvalid <= '0';
          o_hbm_write_in.wlast <= '0';
          wlast_int <= '0';
        end if;
      end if;

      o_ram_coeff_idx <= out_write_blocks_offset + out_cnt_pbs_write_blocks_per_lwe;
    end if;

    
  end process;

  -- process(i_clk)
  -- begin
  --   if rising_edge(i_clk) then
  --     if i_reset = '1' then
  --       done_reg <= '0';
  --     elsif i_hbm_write_out.bvalid = '1' and wlast_int = '1' then
  --       done_reg <= '1';
  --     end if;
  --   end if;
  -- end process;

  -- o_done <= done_reg;

end architecture;
