----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: add_reduce
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Does add/sub including an easy modulo reduction
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
     use IEEE.math_real.all;
library work;
     use work.datatypes_utils.all;
     use work.constants_utils.all;
     use work.ntt_utils.overflow_reduced_num;

entity add_reduce is
     generic (
          substraction : boolean;
          modulus      : synthesiseable_uint
     );
     port (
          i_clk    : in  std_ulogic;
          i_num0   : in  synthesiseable_uint;
          i_num1   : in  synthesiseable_uint;
          o_result : out synthesiseable_uint
     );
end entity;

architecture Behavioral of add_reduce is

     signal temp_res     : synthesiseable_uint_extended;
     signal result_buffer: synthesiseable_uint;
     signal num0_buf: synthesiseable_uint;
     signal num1_buf: synthesiseable_uint;

begin

     do_out_buf: if use_easy_red_out_buffer generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    o_result <= result_buffer;
               end if;
          end process;
     end generate;
     no_out_buf: if not use_easy_red_out_buffer generate
          o_result <= result_buffer;
     end generate;
     do_in_buf: if use_easy_red_in_buffer generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    num0_buf <= i_num0;
                    num1_buf <= i_num1;
               end if;
          end process;
     end generate;
     no_in_buf: if not use_easy_red_in_buffer generate
          num0_buf <= i_num0;
          num1_buf <= i_num1;
     end generate;

     sub: if substraction generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    temp_res <= ('0' & num0_buf) - num1_buf; -- extend for the sign bit
               end if;
          end process;
     end generate;
     add: if not substraction generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    temp_res <= ('0' & num0_buf) + num1_buf; -- extend for the carry bit
               end if;
          end process;
     end generate;

     partial: if use_partial_reduction generate
          sub: if substraction generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         if temp_res(0) = '1' then
                              result_buffer <= temp_res(1 to temp_res'length-1) + modulus;
                         else
                              result_buffer <= temp_res(1 to temp_res'length-1);
                         end if;
                    end if;
               end process;
          end generate;
          add: if not substraction generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         if temp_res(0) = '1' then
                              -- result_buffer <= temp_res(1 to temp_res'length-1) - modulus;
                              result_buffer <= temp_res(1 to temp_res'length-1) + overflow_reduced_num;
                         else
                              result_buffer <= temp_res(1 to temp_res'length-1);
                         end if;
                    end if;
               end process;
          end generate;
     end generate;

     complete: if not use_partial_reduction generate
          sub: if substraction generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         if temp_res(0) = '1' then
                              result_buffer <= temp_res(1 to temp_res'length-1) + modulus;
                         else
                              result_buffer <= temp_res(1 to temp_res'length-1);
                         end if;
                    end if;
               end process;
          end generate;
          add: if not substraction generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         if temp_res > to_synth_uint_extended(modulus) then
                              -- result_buffer <= temp_res(1 to temp_res'length-1) - modulus;
                              result_buffer <= temp_res(1 to temp_res'length-1) + overflow_reduced_num;
                         else
                              result_buffer <= temp_res(1 to temp_res'length-1);
                         end if;
                    end if;
               end process;
          end generate;
     end generate;

end architecture;
