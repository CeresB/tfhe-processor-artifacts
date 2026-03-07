----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: math_utils - package
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Some general-purpose basic functions. All of those are only used during preprocessing.
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
     use work.datatypes_utils.all;
     use IEEE.math_real.all;

package math_utils is

     function get_bit_length(
          num : in integer
     ) return integer;

     function get_bit_length(
          num : in synthesiseable_uint
     ) return integer;

     function reverse_vector(a : in std_ulogic_vector)
          return std_ulogic_vector;

     function reverse_idx(
          num     : integer;
          max_idx : integer;
          reverse : boolean
     ) return integer;

     function a_b_mod_p(
          num0 : synthesiseable_uint;
          num1 : synthesiseable_uint;
          p    : synthesiseable_uint
     ) return synthesiseable_uint;

     function anti_overflow_exp_mod_p(
          base_num : in synthesiseable_uint;
          exponent : in integer;
          p        : in synthesiseable_uint
     ) return synthesiseable_uint;

end package;

package body math_utils is

     function get_bit_length(
               num : in integer
          ) return integer is
          variable bit_length : integer := 0;
     begin
          bit_length := integer(ceil(log2(real(num + 1)))); -- +1 because otherwise if num=1 then bit_length=0
          return bit_length;
     end function;

     function reverse_idx(
               num     : integer;
               max_idx : integer;
               reverse : boolean
          ) return integer is
          variable res : integer;
     begin
          if reverse then
               res := max_idx - num;
          else
               res := num;
          end if;
          return res;
     end function;

     function get_bit_length(
               num : in synthesiseable_uint
          ) return integer is
          variable bit_length : integer := 0;
     begin
          for i in synthesiseable_uint'length - 1 downto 0 loop
               if num(i) = '1' then
                    bit_length := i;
                    exit;
               end if;
          end loop;
          return bit_length;
     end function;

     function reverse_vector(a : in std_ulogic_vector)
          return std_ulogic_vector is
          variable result : std_ulogic_vector(a'RANGE);
          alias aa : std_ulogic_vector(a'REVERSE_RANGE) is a;
     begin
          for i in aa'RANGE loop
               result(i) := aa(i);
          end loop;
          return result;
     end function;

     function a_b_mod_p(
               num0 : synthesiseable_uint;
               num1 : synthesiseable_uint;
               p    : synthesiseable_uint
          ) return synthesiseable_uint is
          variable res      : synthesiseable_uint;
          variable temp_a_b : synthesiseable_double;
     begin
          temp_a_b := to_synth_int(num0) * to_synth_int(num1);
          res := to_synth_uint(temp_a_b mod to_synth_double(p));
          return res;
     end function;

     function anti_overflow_exp_mod_p(
               base_num : in synthesiseable_uint;
               exponent : in integer;
               p        : in synthesiseable_uint
          ) return synthesiseable_uint is
          variable res : synthesiseable_uint;
          variable y   : unsigned(0 to get_bit_length(exponent) - 1);
          variable x   : synthesiseable_uint;
     begin
          if exponent < 0 then
               report "Negative exponantiation not implemented!";
          else
               -- this function is a bottleneck if used a lot
               -- that is why we use the repeated squaring algorithm
               res := to_synth_uint(1);
               if exponent /= 0 then
                    y := to_unsigned(exponent, y'length);
                    x := base_num;
                    while y /= to_unsigned(0, y'length) loop
                         if (y(y'length - 1)) = '1' then
                              res := a_b_mod_p(res, x, p);
                         end if;
                         y := shift_right(y, 1);
                         x := a_b_mod_p(x, x, p);
                    end loop;
               end if;
          end if;
          return res;
     end function;

end package body;
