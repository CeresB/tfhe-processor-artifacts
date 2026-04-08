----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: manual_bram
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: component that vivado implements using bram
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

entity manual_bram is
     generic (
          addr_length         : integer;
          ram_length          : integer;
          ram_out_bufs_length : integer;
          ram_type            : string;
          coeff_bit_width     : integer := unsigned_polym_coefficient_bit_width
     );
     port (
          i_clk     : in  std_ulogic;
          i_wr_en   : in  std_ulogic;
          i_wr_data : in  unsigned(0 to coeff_bit_width - 1);
          i_wr_addr : in  unsigned(0 to addr_length - 1);
          i_rd_addr : in  unsigned(0 to addr_length - 1);
          o_data    : out unsigned(0 to coeff_bit_width - 1)
     );
end entity;

architecture Behavioral of manual_bram is

     type coeff_array is array (natural range <>) of unsigned(0 to coeff_bit_width - 1);
     signal ram_buf  : coeff_array(0 to ram_length - 1);
     signal out_bufs : coeff_array(0 to ram_out_bufs_length - 1);

     attribute ram_style            : string; -- options: block, distributed, registers, ultra
     attribute ram_style of ram_buf : signal is ram_type;

begin

     write_logic: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if i_wr_en = '1' then
                    ram_buf(to_integer(i_wr_addr)) <= i_wr_data;
               end if;
          end if;
     end process;

     read_logic: if not (out_bufs'length-1 > 0) generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    out_bufs(0) <= ram_buf(to_integer(i_rd_addr));
               end if;
          end process;
     end generate;

     read_logic_with_buf: if out_bufs'length-1 > 0 generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    out_bufs(0) <= ram_buf(to_integer(i_rd_addr));
                    out_bufs(1 to out_bufs'length - 1) <= out_bufs(0 to out_bufs'length - 2);
               end if;
          end process;
     end generate;

     o_data <= out_bufs(out_bufs'length - 1);

end architecture;
