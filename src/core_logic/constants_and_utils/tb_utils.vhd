----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: tb_utils - package
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Compare functions for the testbench.
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
     use work.ntt_utils.all;
     use work.math_utils.all;

package tb_utils is

     function compare_synth_ints(
          test_int    : in synthesiseable_uint;
          correct_int : in synthesiseable_uint
     ) return boolean;

     function compare_polyms(
          polym         : in sub_polynom;
          correct_polym : in sub_polynom;
          case_name     : in string
     ) return boolean;

     function sign_switch_tb(
          num     : in synthesiseable_uint;
          max_num : in synthesiseable_uint
     ) return synthesiseable_uint;

     function calc_ntt_res(-- the inefficient but straight-forward way. Be aware that this increases simulation time a lot
          params            :    ntt_params_with_precomputed_values_short;
          ntt_input         : in sub_polynom;
          no_rescaling      : in boolean;
          bit_reverse_order : in boolean
     ) return sub_polynom;

     function to_ntt_mixed_format(
          polym        : in polynom;
          is_ntt_input :    boolean;
          throughput   :    integer
     ) return polynom;

end package;

package body tb_utils is

     function compare_synth_ints(
               test_int    : in synthesiseable_uint;
               correct_int : in synthesiseable_uint
          ) return boolean is
          variable is_equal : boolean := true;
     begin
          if correct_int /= test_int then
               report integer'image(to_integer(test_int)) & " != " & integer'image(to_integer(correct_int));
               is_equal := false;
          end if;
          if is_x(std_logic_vector(test_int)) or is_x(std_logic_vector(correct_int)) then
               report "non-number signal type comparison -- cannot be correct";
               is_equal := false;
          end if;
          return is_equal;
     end function;

     function compare_polyms(
               polym         : in sub_polynom;
               correct_polym : in sub_polynom;
               case_name     : in string -- v4p ignore w-303
          ) return boolean is
          variable is_equal : boolean := true;
     begin
          if use_partial_reduction then
               for i in 0 to polym'length - 1 loop
                    is_equal := is_equal and compare_synth_ints(polym(i) mod ntt_params.prime, correct_polym(i) mod ntt_params.prime);
               end loop;
          else
               for i in 0 to polym'length - 1 loop
                    is_equal := is_equal and compare_synth_ints(polym(i), correct_polym(i));
               end loop;
          end if;
          assert is_equal report "DUT did not pass " & case_name severity error;
          return is_equal;
     end function;

     function sign_switch_tb(
               num     : in synthesiseable_uint;
               max_num : in synthesiseable_uint
          ) return synthesiseable_uint is
          variable temp : synthesiseable_int;
          variable res  : synthesiseable_uint;
     begin
          temp := to_synth_int(to_synth_uint(0)) - to_synth_int(num);
          if temp < to_synth_int(to_synth_uint(0)) then
               temp := temp + to_synth_int(max_num);
          end if;
          res := to_synth_uint(temp);
          return res;
     end function;

     function calc_ntt_res(-- the inefficient but straight-forward way. Be aware that this increases simulation time a lot
               params            : in ntt_params_with_precomputed_values_short;
               ntt_input         : in sub_polynom;
               no_rescaling      : in boolean;
               bit_reverse_order : in boolean
          ) return sub_polynom is
          variable res           : sub_polynom(0 to ntt_input'length - 1);
          variable w_ij          : synthesiseable_uint;
          variable ij            : integer;
          variable temp          : synthesiseable_uint_extended;
          variable idx_of_choice : integer;
     begin
          for j in 0 to polynom'length - 1 loop
               temp := to_synth_uint_extended(to_synth_uint(0));
               for i in 0 to polynom'length - 1 loop
                    if params.negacyclic then
                         -- because this is a template for ntt and intt we need to respect the different
                         -- coefficient index. This is ot required in the hardware implementation as the
                         -- coefficient and stage order handles that
                         if not params.invers then
                              ij := (i * (2 * j + 1));
                         else
                              ij := (j * (2 * i + 1));
                         end if;
                    else
                         -- invers does not make a difference here
                         ij := i * j;
                    end if;
                    w_ij := anti_overflow_exp_mod_p(params.omega, ij, params.prime);
                    temp := (temp + a_b_mod_p(w_ij, ntt_input(i), params.prime)) mod to_synth_uint_extended(params.prime);
               end loop;

               if bit_reverse_order then
                    -- bit reverse order
                    idx_of_choice := to_integer(unsigned(reverse_vector(std_ulogic_vector(to_idx_int(j)))));
               else
                    idx_of_choice := j;
               end if;

               if params.invers and not no_rescaling then
                    res(idx_of_choice) := a_b_mod_p(params.n_invers, to_synth_uint(temp), params.prime);
               else
                    res(idx_of_choice) := to_synth_uint(temp);
               end if;
          end loop;
          return res;
     end function;

     function to_ntt_mixed_format(
               polym        : in polynom;
               is_ntt_input :    boolean;
               throughput   :    integer
          ) return polynom is
          variable res : polynom;
          constant thr_half : integer := throughput / 2;
     begin
          if not is_ntt_input then
               -- is intt_output
               for i in 0 to polym'length / 2 / thr_half - 1 loop
                    for j in 0 to thr_half - 1 loop
                         res(i * thr_half + j) := polym(2 * i * thr_half + j);
                         res(i * thr_half + polym'length / 2 + j) := polym((2 * i + 1) * thr_half + j);
                    end loop;
               end loop;
          else
               for i in 0 to polym'length / 2 / thr_half - 1 loop
                    for j in 0 to thr_half - 1 loop
                         res(2 * i * thr_half + j) := polym(i * thr_half + j);
                         res((2 * i + 1) * thr_half + j) := polym(i * thr_half + polym'length / 2 + j);
                    end loop;
               end loop;
          end if;
          return res;
     end function;

end package body;
