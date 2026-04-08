----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: datatypes_utils - package
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Contains datatypes and functions that work with these types,
--             which are used in NTT and TFHE modules.
--             Here are only types that are used across multiple files.
--             Focus on low effort: no resize of signed values during runtime as that requires logic!
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

package datatypes_utils is
     -- own datatypes needed because integers do not support shift-operations and are only 32-bit in Vivado
     subtype synthesiseable_uint is unsigned(0 to unsigned_polym_coefficient_bit_width - 1);
     subtype synthesiseable_uint_extended is unsigned(0 to unsigned_polym_coefficient_bit_width); -- 1 more bit to prevent overflows during additions
     subtype synthesiseable_udouble is unsigned(0 to (2 * unsigned_polym_coefficient_bit_width) - 1); -- needed to store multiplication results
     type wait_registers_uint is array (natural range <>) of synthesiseable_uint; -- same as sub-polym but has a different function as the name suggests
     type wait_registers_uint_extended is array (natural range <>) of synthesiseable_uint_extended;

     subtype synthesiseable_int is signed(0 to synthesiseable_uint'length + 1 - 1);
     subtype synthesiseable_int_extended is signed(0 to synthesiseable_uint_extended'length + 1 - 1); -- 1 more bit to prevent overflows during additions
     subtype synthesiseable_double is signed(0 to synthesiseable_udouble'length + 2 - 1); -- needed to store multiplication results. +2 because sign bit doubles
     type wait_register_int is array (natural range <>) of synthesiseable_int;
     type wait_registers_int_extended is array (natural range <>) of synthesiseable_int_extended;
     type wait_registers_double is array (natural range <>) of synthesiseable_double;

     subtype binary_vector is std_ulogic_vector(0 to unsigned_polym_coefficient_bit_width - 1);

     type sub_polynom is array (natural range <>) of synthesiseable_uint;
     subtype polynom is sub_polynom(0 to num_coefficients - 1);

     type polynom_array is array (natural range <>) of polynom;
     type sub_polynom_double is array (natural range <>) of synthesiseable_udouble;
     type sub_polynom_int_extended is array (natural range <>) of synthesiseable_uint_extended;

     type index_2d is record -- needed for indexing "tables" e.g. 2d arrays
          col : integer;
          row : integer;
     end record;
     type index_2d_array is array (natural range <>) of index_2d;

     subtype idx_int is unsigned(0 to log2_num_coefficients - 1);
     subtype rotate_idx is unsigned(0 to log2_num_coefficients + 1 - 1);
     type rotate_idx_array is array (natural range <>) of rotate_idx;

     subtype idx_double is unsigned(0 to 2 * log2_num_coefficients - 1);
     type idx_int_array is array (natural range <>) of idx_int;
     type idx_double_array is array (natural range <>) of idx_double;

     type int_array is array (natural range <>) of integer;

     type ntt_nums is record
          n_invers     : synthesiseable_uint;
          omega        : synthesiseable_uint;
          omega_invers : synthesiseable_uint;
     end record;

     type ntt_params_list is array (1 to ntt_params_list_length) of ntt_nums; -- n = 1 makes no sense: our butterflys need 2 values to operate. That is why this list starts from 1
     type prime_list_pair is record
          prime : synthesiseable_uint;
          list  : ntt_params_list;
     end record;

     -- we distiguish between vector and polynom to avoid confusion
     type synth_uint_vector is array (natural range <>) of synthesiseable_uint;
     --type synth_double_vector is array (natural range <>) of synthesiseable_double;
     type synth_uint_extended_vector is array (natural range <>) of synthesiseable_uint_extended;

     type lwe_n_a_dtype is array (natural range <>) of polynom;

     -- type conversion functions
     function to_synth_uint(
          num : in integer
     ) return synthesiseable_uint;

     function to_synth_uint(
          num : in signed
     ) return synthesiseable_uint;

     function to_synth_uint(
          num : in unsigned
     ) return synthesiseable_uint;

     function to_synth_uint(
          num : in std_ulogic_vector
     ) return synthesiseable_uint;

     function to_synth_int(
          num : in signed
     ) return synthesiseable_int;

     function to_synth_double(
          num : in signed
     ) return synthesiseable_double;

     function to_synth_double(
          num : in unsigned
     ) return synthesiseable_double;

     function to_synth_int(
          num : in synthesiseable_uint
     ) return synthesiseable_int;

     function to_synth_udouble(
          num : in synthesiseable_double
     ) return synthesiseable_udouble;

     function to_synth_udouble(
          num : in synthesiseable_uint
     ) return synthesiseable_udouble;

     function to_synth_int_extended(
          num : in synthesiseable_uint
     ) return synthesiseable_int_extended;

     function to_synth_int_extended(
          num : in synthesiseable_int
     ) return synthesiseable_int_extended;

     function signed_to_synth_int_extended(
          num : in signed
     ) return synthesiseable_int_extended;

     function to_synth_uint_extended(
          num : in synthesiseable_uint
     ) return synthesiseable_uint_extended;

     function to_idx_int(
          num : in integer
     ) return idx_int;

     function to_rotate_idx(
          num : in integer
     ) return rotate_idx;

     function to_rotate_idx(
          num : in synthesiseable_uint
     ) return rotate_idx;

     -- function to_idx_double(
     --      num : in unsigned
     -- ) return idx_double;
     function get_test_sub_polym(
          sub_polym_length : integer;
          start_num        : integer;
          step_size        : integer
     ) return sub_polynom;

     function to_ntt_mixed_format(
          polym            : polynom;
          blocks_per_polym : integer;
          throughput       : integer
     ) return polynom;

     function to_ntt_normal_format(
          polym            : polynom;
          blocks_per_polym : integer;
          throughput       : integer
     ) return polynom;

     function get_test_polym(
          start_num            : integer;
          step_size            : integer;
          mixed_format         : boolean;
          throughput           : integer;
          num_blocks_per_polym : integer
     ) return polynom;

     function to_synth_int_vector(
          sub_polym : sub_polynom
     ) return synth_uint_vector;

     function get_random_test_sub_polym(
          sub_polym_length: integer;
          seed: integer
     ) return sub_polynom;

end package;

package body datatypes_utils is

     function to_synth_int(-- add a sign bit
               num : in synthesiseable_uint
          ) return synthesiseable_int is
          variable res : synthesiseable_int;
     begin
          res := signed('0' & num);
          return res;
     end function;

     function to_synth_int(
               num : in signed
          ) return synthesiseable_int is
          variable res : synthesiseable_int;
     begin
          res := resize(num, synthesiseable_int'length);
          return res;
     end function;

     function to_synth_uint(-- ATTENTION: does not work with negative integers! Only used during preprocessing.
               num : in integer
          ) return synthesiseable_uint is
          variable res : synthesiseable_uint;
     begin
          res := to_unsigned(num, synthesiseable_uint'length);
          return res;
     end function;

     function to_synth_uint(-- just to interpret it differently
               num : in signed
          ) return synthesiseable_uint is
          variable res : synthesiseable_uint;
     begin
          res := unsigned(to_synth_int(num)(1 to synthesiseable_int'length - 1)); -- discard sign bit
          return res;
     end function;

     function to_synth_uint(-- just to interpret it differently
               num : in std_ulogic_vector
          ) return synthesiseable_uint is
          variable res : synthesiseable_uint;
     begin
          res := resize(unsigned(num), synthesiseable_uint'length);
          return res;
     end function;

     function to_synth_uint(-- bit length padding
               num : in unsigned
          ) return synthesiseable_uint is
          variable res : synthesiseable_uint;
     begin
          res := resize(num, synthesiseable_uint'length); -- resizing unsigned just padds zeros to the front, so it is no effort
          return res;
     end function;

     function to_synth_double(-- only used during preprocessing
               num : in signed
          ) return synthesiseable_double is
          variable res : synthesiseable_double;
     begin
          res := resize(num, synthesiseable_double'length);
          return res;
     end function;

     function to_synth_double(-- only used during preprocessing
               num : in unsigned
          ) return synthesiseable_double is
          variable res : synthesiseable_double;
     begin
          res := to_synth_double(signed('0' & num));
          return res;
     end function;

     function to_synth_udouble(-- discard sign bit(s)
               num : in synthesiseable_double
          ) return synthesiseable_udouble is
          variable res : synthesiseable_udouble;
     begin
          -- a synthesiseable_double happends when two synthesiseable_ints are multiplied
          -- this doubles their sign
          res := unsigned(num(2 to num'length - 1));
          return res;
     end function;

     function to_synth_udouble(-- only used during preprocessing
               num : in synthesiseable_uint
          ) return synthesiseable_udouble is
          variable res : synthesiseable_udouble;
     begin
          res := resize(num, synthesiseable_udouble'length);
          return res;
     end function;

     function to_synth_int_extended(-- add another bit
               num : in synthesiseable_int
          ) return synthesiseable_int_extended is
          variable res : synthesiseable_int_extended;
     begin
          res := signed('0' & num);
          return res;
     end function;

     function to_synth_int_extended(-- add one bit for the sign and one for the extension
               num : in synthesiseable_uint
          ) return synthesiseable_int_extended is
          variable res : synthesiseable_int_extended;
     begin
          res := signed('0' & to_synth_int(num));
          return res;
     end function;

     function signed_to_synth_int_extended(
               num : in signed
          ) return synthesiseable_int_extended is
          variable res : synthesiseable_int_extended;
     begin
          res := resize(num, synthesiseable_int_extended'length);
          return res;
     end function;

     function to_synth_uint_extended(-- add another bit
               num : in synthesiseable_uint
          ) return synthesiseable_uint_extended is
          variable res : synthesiseable_uint_extended;
     begin
          res := unsigned('0' & num);
          return res;
     end function;

     function to_idx_int(
               num : in integer
          ) return idx_int is
          variable res : idx_int;
     begin
          res := to_unsigned(num, idx_int'length);
          return res;
     end function;

     function to_rotate_idx(
               num : in integer
          ) return rotate_idx is
          variable res : rotate_idx;
     begin
          res := to_unsigned(num, rotate_idx'length);
          return res;
     end function;

     function to_rotate_idx(
               num : in synthesiseable_uint
          ) return rotate_idx is
          variable res : rotate_idx;
     begin
          res := num(num'length - res'length to num'length - 1);
          return res;
     end function;

     function get_test_sub_polym(-- only used during preprocessing
               sub_polym_length : integer;
               start_num        : integer;
               step_size        : integer
          ) return sub_polynom is
          variable res : sub_polynom(0 to sub_polym_length - 1);
     begin
          for i in 0 to res'length - 1 loop
               res(i) := to_synth_uint(start_num + step_size * i);
          end loop;
          return res;
     end function;

     function to_ntt_mixed_format(
               polym            : polynom;
               blocks_per_polym : integer;
               throughput       : integer
          ) return polynom is
          variable res : polynom;
     begin
          -- ntt-mixed format: every throughput-sized block is half ntt-upper part, other half ntt-lower part
          -- where the blocks size throughput are interweaved
          for j in 0 to (blocks_per_polym) - 1 loop
               -- half a block from first half, half a block from second polynom half
               for coeff_idx in 0 to throughput / 2 - 1 loop
                    res(j * throughput + coeff_idx) := polym(j * (throughput / 2) + coeff_idx);
                    res(j * throughput + coeff_idx + (throughput / 2)) := polym((num_coefficients / 2) + j * (throughput / 2) + coeff_idx);
               end loop;
          end loop;
          return res;
     end function;

     function to_ntt_normal_format(
               polym            : polynom;
               blocks_per_polym : integer;
               throughput       : integer
          ) return polynom is
          variable res : polynom;
     begin
          -- undo mixing
          for j in 0 to (blocks_per_polym) - 1 loop
               -- half a block to the first half, half a block to the second polynom half
               for coeff_idx in 0 to throughput / 2 - 1 loop
                    res(j * (throughput / 2) + coeff_idx) := polym(j * throughput + coeff_idx);
                    res((num_coefficients / 2) + j * (throughput / 2) + coeff_idx) := polym(j * throughput + coeff_idx + (throughput / 2));
               end loop;
          end loop;
          return res;
     end function;

     function get_test_polym(
               start_num            : integer;
               step_size            : integer;
               mixed_format         : boolean;
               throughput           : integer;
               num_blocks_per_polym : integer
          ) return polynom is
          variable res : polynom;
     begin
          if mixed_format then
               res := to_ntt_mixed_format(get_test_sub_polym(res'length, start_num, step_size), num_blocks_per_polym, throughput);
          else
               res := get_test_sub_polym(res'length, start_num, step_size);
          end if;
          return res;
     end function;

     function get_random_test_sub_polym(
          sub_polym_length: integer;
          seed: integer
     )
          return sub_polynom is
          variable res   : sub_polynom(0 to sub_polym_length-1);
          variable seed1 : positive;
          variable seed2 : positive;
          variable x     : real;
          constant integer_precision : integer := 30;
          constant remaining_length  : integer := synthesiseable_uint'length - 2 * integer_precision;
          constant max_int_val       : real    := real(2 ** 30);
     begin
          seed1 := seed + 1;
          seed2 := seed + 2;
          for i in 0 to res'length - 1 loop
               -- vivado can only do 32-bit-signed numbers, meaning 31-bit unsigned
               -- so we generate the a random 64-bit number in 3 parts
               uniform(seed1, seed2, x);
               res(i)(0 to integer_precision - 1) := to_unsigned(integer(floor(x * max_int_val)), integer_precision);
               seed1 := seed1+1;
               seed2 := seed1+1;
               uniform(seed1, seed2, x);
               seed1 := seed1+1;
               seed2 := seed1+1;
               res(i)(integer_precision to 2 * integer_precision - 1) := to_unsigned(integer(floor(x * max_int_val)), integer_precision);
               uniform(seed1, seed2, x);
               res(i)(2 * integer_precision to synthesiseable_uint'length - 1) := to_unsigned(integer(floor(x * max_int_val)), remaining_length);
               seed1 := seed1 + 1000;
               seed2 := seed2 + 1000;
          end loop;
          return res;
     end function;

     function to_synth_int_vector(
               sub_polym : sub_polynom
          ) return synth_uint_vector is
          variable res : synth_uint_vector(0 to sub_polym'length - 1);
     begin
          for i in 0 to sub_polym'length - 1 loop
               res(i) := sub_polym(i);
          end loop;
          return res;
     end function;

end package body;
