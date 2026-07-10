----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ntt_params
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Defines the prime-number-related values for the NTT.
--             You can use the functions in ntt_correctness_check.ipynb
--             to calculate these values for your own primes.
--             Prime 7681 is used for easier step-by-step testing and checking of
--             the results.
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

package ntt_prime_list_pair is

     -- binary nums are only used here because Vivado does not support 64-bit integers
     type ntt_nums_binary is record
          --n               : binary_vector;
          n_invers     : binary_vector;
          omega        : binary_vector;
          omega_invers : binary_vector;
     end record;

     type ntt_params_binary_list is array (1 to ntt_params_list_length) of ntt_nums_binary; -- n = 1 makes no sense: our butterflys need 2 values to operate. That is why this list starts from 1

     constant ntt_params_prime7681 : ntt_params_list := (
          -- info: this list starts from 1
          -- n is set by the index of the element in this list
          (
               --n               => 2 ** 1,
               n_invers     => to_synth_uint(3841),
               omega        => to_synth_uint(7680),
               omega_invers => to_synth_uint(7680)),
          (
               --n               => 2 ** 2,
               n_invers     => to_synth_uint(5761),
               omega        => to_synth_uint(3383),
               omega_invers => to_synth_uint(4298)),
          (
               --n               => 2 ** 3,
               n_invers     => to_synth_uint(6721),
               omega        => to_synth_uint(1213),
               omega_invers => to_synth_uint(1925)),
          (
               --n               => 2 ** 4,
               n_invers     => to_synth_uint(7201),
               omega        => to_synth_uint(527),
               omega_invers => to_synth_uint(583)),
          (
               --n               => 2 ** 5,
               n_invers     => to_synth_uint(7441),
               omega        => to_synth_uint(97),
               omega_invers => to_synth_uint(5543)),
          (
               --n               => 2 ** 6,
               n_invers     => to_synth_uint(7561),
               omega        => to_synth_uint(330),
               omega_invers => to_synth_uint(675)),
          (
               --n               => 2 ** 7,
               n_invers     => to_synth_uint(7621),
               omega        => to_synth_uint(202),
               omega_invers => to_synth_uint(4601)),
          (
               --n               => 2 ** 8,
               n_invers     => to_synth_uint(7651),
               omega        => to_synth_uint(198),
               omega_invers => to_synth_uint(1125)),
          -- for higher n there exist no more valid params for this prime
          -- for syntax purposes we fill with zeros
          (
               --n               => 2 ** 9,
               -- NO PARAMS FOUND
               n_invers     => to_synth_uint(0),
               omega        => to_synth_uint(0),
               omega_invers => to_synth_uint(0)),
          (
               -- NO PARAMS FOUND
               --n               => 2 ** 10,
               n_invers     => to_synth_uint(0),
               omega        => to_synth_uint(0),
               omega_invers => to_synth_uint(0)),
          (
               -- NO PARAMS FOUND
               --n               => 2 ** 11,
               n_invers     => to_synth_uint(0),
               omega        => to_synth_uint(0),
               omega_invers => to_synth_uint(0)),
          (
               -- NO PARAMS FOUND
               --n               => 2 ** 12,
               n_invers     => to_synth_uint(0),
               omega        => to_synth_uint(0),
               omega_invers => to_synth_uint(0)),
          (
               -- NO PARAMS FOUND
               --n               => 2 ** 13,
               n_invers     => to_synth_uint(0),
               omega        => to_synth_uint(0),
               omega_invers => to_synth_uint(0)),
          (
               -- NO PARAMS FOUND
               --n               => 2 ** 14,
               n_invers     => to_synth_uint(0),
               omega        => to_synth_uint(0),
               omega_invers => to_synth_uint(0)),
          (
               -- NO PARAMS FOUND
               --n               => 2 ** 15,
               n_invers     => to_synth_uint(0),
               omega        => to_synth_uint(0),
               omega_invers => to_synth_uint(0)),
          (
               -- NO PARAMS FOUND
               --n               => 2 ** 16,
               n_invers     => to_synth_uint(0),
               omega        => to_synth_uint(0),
               omega_invers => to_synth_uint(0)),
          (
               -- NO PARAMS FOUND
               --n               => 2 ** 17,
               n_invers     => to_synth_uint(0),
               omega        => to_synth_uint(0),
               omega_invers => to_synth_uint(0))
     );
     constant params_prime7681 : prime_list_pair := (
          prime => to_synth_uint(7681),
          list  => ntt_params_prime7681);

     constant ntt_params_solinas_binary : ntt_params_binary_list := (
          -- info: this list starts from 1
          -- n is set by the index of the element in this list
          (
               --n               => 2 ** 1,
               n_invers     => x"7fffffff80000001",
               omega        => x"ffffffff00000000",
               omega_invers => x"ffffffff00000000"),
          (
               --n               => 2 ** 2,
               n_invers     => x"bfffffff40000001",
               omega        => x"0001000000000000",
               omega_invers => x"fffeffff00000001"),
          (
               --n               => 2 ** 3,
               n_invers     => x"dfffffff20000001",
               omega        => x"0000000001000000",
               omega_invers => x"fffffeff00000101"),
          (
               --n               => 2 ** 4,
               n_invers     => x"efffffff10000001",
               omega        => x"0000000000001000",
               omega_invers => x"ffefffff00100001"),
          (
               --n               => 2 ** 5,
               n_invers     => x"f7ffffff08000001",
               omega        => x"0000000000000040",
               omega_invers => x"fbffffff04000001"),
          (
               --n               => 2 ** 6,
               n_invers     => x"fbffffff04000001",
               omega        => x"0000000000000008",
               omega_invers => x"dfffffff20000001"),
          (
               --n               => 2 ** 7,
               n_invers     => x"fdffffff02000001",
               omega        => x"00000000fffeffff",
               omega_invers => x"00007fff7fff8000"),
          (
               --n               => 2 ** 8,
               n_invers     => x"feffffff01000001",
               omega        => x"03ac5c61f4949dd6",
               omega_invers => x"fbc8a1ec30654b2b"),
          (
               --n               => 2 ** 9,
               n_invers     => x"ff7fffff00800001",
               omega        => x"034ac1b6f08798e6",
               omega_invers => x"8efb82c7d51bbde2"),
          (
               --n               => 2 ** 10,
               n_invers     => x"ffbfffff00400001",
               omega        => x"0043e67baa27f08f",
               omega_invers => x"03943b16d74c24d6"),
          (
               --n               => 2 ** 11,
               n_invers     => x"ffdfffff00200001",
               omega        => x"0045923223a51f27",
               omega_invers => x"98354f5ee169ba9b"),
          (
               --n               => 2 ** 12,
               n_invers     => x"ffefffff00100001",
               omega        => x"003c0cc70d1e41c2",
               omega_invers => x"ea74c41e10f3b6bd"),
          (
               --n               => 2 ** 13,
               n_invers     => x"fff7ffff00080001",
               omega        => x"000dbb0a56f9a1aa",
               omega_invers => x"450fab8268fb6217"),
          (
               --n               => 2 ** 14,
               n_invers     => x"fffbffff00040001",
               omega        => x"00136c567d8ba8d4",
               omega_invers => x"626e2479cecaa8d4"),
          (
               --n               => 2 ** 15,
               n_invers     => x"fffdffff00020001",
               omega        => x"0002006090c1554f",
               omega_invers => x"b8fc774ddcbf6d78"),
          (
               --n               => 2 ** 16,
               n_invers     => x"fffeffff00010001",
               omega        => x"0002401e7e09d2c9",
               omega_invers => x"425e7179e087e0e1"),
          (
               --n               => 2 ** 17,
               n_invers     => x"ffff7fff00008001",
               omega        => x"0001403cd7fb865d",
               omega_invers => x"4dc246e77ddb705a")
     );

     function ntt_params_binary_list_to_synthesisable_int(
          params_binary_list : ntt_params_binary_list
     ) return ntt_params_list;

     constant ntt_params_solinas : ntt_params_list := ntt_params_binary_list_to_synthesisable_int(ntt_params_solinas_binary);
     constant solinas_prime      : binary_vector   := x"FFFFFFFF00000001";

     constant params_solinas_prime : prime_list_pair := (
          prime => to_synth_uint(unsigned(solinas_prime)),
          list  => ntt_params_solinas);

end package;

package body ntt_prime_list_pair is

     function ntt_params_binary_list_to_synthesisable_int(
               params_binary_list : ntt_params_binary_list
          ) return ntt_params_list is
          variable temp : ntt_params_list;
     begin
          for i in 1 to temp'length loop
               temp(i).n_invers := to_synth_uint(unsigned(params_binary_list(i).n_invers));
               temp(i).omega := to_synth_uint(unsigned(params_binary_list(i).omega));
               temp(i).omega_invers := to_synth_uint(unsigned(params_binary_list(i).omega_invers));
          end loop;

          return temp;
     end function;

end package body;
