----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: modulo_solinas
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Computes i_num mod 0xFFFFFFFF00000001
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
     use work.constants_utils.all;
     -- use work.ntt_utils.overflow_reduced_num;

     -- this computes: (a mod ntt_prime) via the solution presented in the Number Theoretic Transform (NTT) FPGA
     -- Accelerator paper by Austin Hartshorn et al. (HLW)
     -- However, the HLW paper has a mistake in their diagram: it does a substraction in stage 1, but there should be an addition
     -- the mistake was verified by going to the original source, Emmert et al.
     -- and we work between 0 and p, so we need to consider the case a != 0 and b,c,d=0, in which case we need to add p
     -- assumption: prime is solinas-prime for 64-bit numbers: 0xFFFFFFFF00000001

entity modulo_solinas is
     generic (
          p : synthesiseable_uint
     );
     port (
          i_clk    : in  std_ulogic;
          i_num    : in  synthesiseable_udouble;
          o_result : out synthesiseable_uint
     );
end entity;

architecture Behavioral of modulo_solinas is

     -- this modulo solution can only handle 128-bit inputs

     -- extra bit for the sign
     signal a : unsigned(0 to 32 - 1);
     signal b : unsigned(0 to 32 - 1);
     signal c : unsigned(0 to 32 - 1);
     signal d : unsigned(0 to 32 - 1);
     signal temp_d_a_b       : signed(0 to a'length + 2 - 1); -- +1 for sign, +1 for underflowavoidance.  is between -2*(2^32 -1) and +(2^32 -1)
     signal d_expanded       : signed(0 to temp_d_a_b'length - 1);
     signal temp_b_c         : unsigned(0 to a'length + 1 - 1); -- +1 for overflowavoidance
     signal temp_b_c_shifted : synthesiseable_uint_extended;
     signal temp_res         : synthesiseable_int_extended;
     signal res_buf : synthesiseable_uint;
     -- signal sign_bit: std_ulogic;
     -- signal overflow_bit: std_ulogic;
     signal temp_res_core: synthesiseable_uint;

begin

     d_expanded(0)                          <= '0';             -- sign bit
     d_expanded(1 to d_expanded'length - 1) <= signed('0' & d); -- carry placeholder

     temp_b_c_shifted(0 to temp_b_c'length - 1) <= temp_b_c(0 to temp_b_c'length - 1);
     -- fill with zeros
     temp_b_c_shifted(temp_b_c'length to temp_b_c_shifted'length - 1) <= to_unsigned(0, temp_b_c_shifted'length - temp_b_c'length);

     process (i_clk)
     begin
          if rising_edge(i_clk) then
               -- stage 0
               temp_d_a_b <= (d_expanded - signed('0' & a)) - signed('0' & b);
               temp_b_c <= ('0' & b) + c;
               -- stage 1
               temp_res <= signed('0' & temp_b_c_shifted) + temp_d_a_b; -- cannot have a carry but has 0 for the sign
               -- temp_res <= signed(shift_left(resize(b,temp_res'length),32) + shift_left(resize(c,temp_res'length),32) + resize(d,temp_res'length) - resize(a,temp_res'length) - resize(b,temp_res'length));

               -- -- stage 2
               -- if temp_res(0) = '1' then -- if negative
               --      res_buf <= to_synth_uint(temp_res(1 to temp_res'length-1) + to_synth_int(p));
               -- elsif temp_res > to_synth_int_extended(p) then
               --      res_buf <= to_synth_uint(temp_res(1 to temp_res'length-1) - to_synth_int(p));
               -- else
               --      res_buf <= to_synth_uint(temp_res(1 to temp_res'length-1));
               -- end if;
          end if;
     end process;

     -- sign_bit <= temp_res(0);
     -- overflow_bit <= temp_res(1);
     temp_res_core <= unsigned(temp_res(2 to temp_res'length-1));

     partial: if use_partial_reduction generate
          process (i_clk) is
          begin
            if rising_edge(i_clk) then
               -- stage 2
               if temp_res(0) = '1' then -- if negative
                    res_buf <= temp_res_core + p; -- we know the result is positive, so we can ignore the sign bit
               elsif temp_res(1) = '1' then
                    -- res_buf <= temp_res_core + overflow_reduced_num; -- is not an advantage here, Vivado cannot simply switch between addition and substraction of p
                    res_buf <= temp_res_core - p;
               else
                    res_buf <= temp_res_core;
               end if;
            end if;
          end process;
     end generate;
     
     not_partial: if not use_partial_reduction generate
          process (i_clk) is
          begin
            if rising_edge(i_clk) then
               -- stage 2
               if temp_res(0) = '1' then -- if negative
                    res_buf <= temp_res_core + p; -- we know the result is positive, so we can ignore the sign bit
               elsif temp_res > to_synth_int_extended(p) then
                    -- res_buf <= temp_res_core + overflow_reduced_num; -- is not an advantage here, Vivado cannot simply switch between addition and substraction of p
                    res_buf <= temp_res_core - p;
               else
                    res_buf <= temp_res_core;
               end if;
            end if;
          end process;     
     end generate;
     

     a <= i_num(0 to i_num'length - 96 - 1);
     b <= i_num(i_num'length - 96 to i_num'length - 64 - 1);
     c <= i_num(i_num'length - 64 to i_num'length - 32 - 1);
     d <= i_num(i_num'length - 32 to i_num'length - 1);

     do_out_buf: if use_solinas_red_out_buffer generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    o_result <= res_buf;
               end if;
          end process;
     end generate;
     no_out_buf: if not use_solinas_red_out_buffer generate
          o_result <= res_buf;
     end generate;

end architecture;
