----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: basic_decomposition
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: does a decomposition a shown in the TFHE deep dive
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
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.tfhe_utils.all;
     use work.tfhe_constants.all;

entity basic_decomposition is
     generic (
          throughput           : integer;
          decomposition_length : integer;
          num_LSBs_to_round    : integer;
          bits_per_slice       : integer
     );
     port (
          i_clk       : in  std_ulogic;
          i_sub_polym : in  sub_polynom(0 to throughput - 1);
          o_result    : out synth_L_int_vector(0 to throughput * decomposition_length - 1) -- by using this simpler datatype this module only really depends on the generics
     );
end entity;

architecture Behavioral of basic_decomposition is

     component add_reduce is
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
     end component;

     subtype coeff_rounded is unsigned(0 to synthesiseable_uint'length - num_LSBs_to_round - 1);
     type sub_polym_rounded is array (natural range <>) of coeff_rounded;
     signal input_round_bits_zeroed     : sub_polynom(0 to i_sub_polym'length - 1);
     signal input_rounded_reduced       : sub_polynom(0 to input_round_bits_zeroed'length - 1);
     signal input_rounded_wo_round_bits : sub_polym_rounded(0 to input_round_bits_zeroed'length - 1);

     type slice is array (natural range <>) of unsigned(0 to bits_per_slice - 1);
     type slice_arr is array (natural range <>) of slice(0 to throughput - 1);
     type slice_mat is array (natural range <>) of slice_arr(0 to decomposition_length - 1);

     signal stages_slices : slice_mat(0 to decomposition_length - 1);

     attribute dont_touch                                : string;
     attribute dont_touch of input_rounded_wo_round_bits : signal is "true";

     signal round_bit_as_value : sub_polynom(0 to i_sub_polym'length - 1) := get_test_sub_polym(i_sub_polym'length, 0, 0);

begin

     round_input: for coeff_idx in 0 to i_sub_polym'length - 1 generate
          -- MSB is at 0. Set lower bits of i_sub_polym to 0, the others to what they were
          input_round_bits_zeroed(coeff_idx)(input_round_bits_zeroed(0)'length - num_LSBs_to_round to input_round_bits_zeroed(0)'length - 1) <= (others => '0');
          input_round_bits_zeroed(coeff_idx)(0 to input_round_bits_zeroed(0)'length - num_LSBs_to_round - 1)                                 <= i_sub_polym(coeff_idx)(0 to i_sub_polym(0)'length - num_LSBs_to_round - 1);
          -- make round-bit to the corresponding number
          round_bit_as_value(coeff_idx)(i_sub_polym(0)'length - (num_LSBs_to_round + 1)) <= i_sub_polym(coeff_idx)(i_sub_polym(0)'length - num_LSBs_to_round);
          -- ignore the last bits of the reduced result
          input_rounded_wo_round_bits(coeff_idx) <= input_rounded_reduced(coeff_idx)(0 to input_rounded_reduced(0)'length - 1 - num_LSBs_to_round);
     end generate;

     add_round_bit: for coeff_idx in 0 to i_sub_polym'length - 1 generate
          vector_add: add_reduce
               generic map (
                    substraction => false,
                    modulus      => tfhe_modulus
               )
               port map (
                    i_clk    => i_clk,
                    i_num0   => input_round_bits_zeroed(coeff_idx),
                    i_num1   => round_bit_as_value(coeff_idx),
                    o_result => input_rounded_reduced(coeff_idx)
               );
     end generate;

     -- we store the input as multiple slices instead of one and thus avoid defining individual datatypes for the input of each stage
     temp_input_to_slice_mapping: for coeff_idx in 0 to input_rounded_wo_round_bits'length - 1 generate
          slice_mapping: for slice_idx in 0 to stages_slices'length - 1 generate
               -- slice 0 are the LSB coefficients, the ones to process first so we put them at index 0
               -- remember: on bit level index 0 is the MSB
               stages_slices(slice_idx)(0)(coeff_idx) <= input_rounded_wo_round_bits(coeff_idx)(coeff_rounded'length - (slice_idx + 1) * bits_per_slice to coeff_rounded'length - slice_idx * bits_per_slice - 1);
          end generate;
     end generate;

     end_mapping: if decomposition_length > 0 generate
          stages_map: for decomp_idx in 0 to stages_slices'length - 1 generate
               coeff_map: for i in 0 to stages_slices(0)(0)'length - 1 generate
                    o_result(i + decomp_idx * throughput) <= resize(signed(stages_slices(decomp_idx)(stages_slices(0)'length - 1)(i)), o_result(0)'length);
               end generate;
          end generate;
     end generate;

     roll_bufferchain: if stages_slices'length > 0 generate -- if bufferchain long enough
          -- roll bufferchain
          -- first one is special as nothing will be added to it
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    stages_slices(0)(1 to stages_slices(0)'length - 1) <= stages_slices(0)(0 to stages_slices(0)'length - 2);
               end if;
          end process;

          slice_mapping: for decomp_idx in 1 to stages_slices'length - 1 generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         -- add MSBs of previous stage coefficients
                         for i in 0 to i_sub_polym'length - 1 loop
                              stages_slices(decomp_idx)(decomp_idx)(i) <= stages_slices(decomp_idx)(decomp_idx - 1)(i) + stages_slices(decomp_idx - 1)(decomp_idx - 1)(i)(0 to 0);
                         end loop;
                    end if;
               end process;
               -- roll bufferchain
               roll_before_add: if decomp_idx > 1 generate
                    process (i_clk)
                    begin
                         if rising_edge(i_clk) then
                              stages_slices(decomp_idx)(1 to decomp_idx - 1) <= stages_slices(decomp_idx)(0 to decomp_idx - 2);
                         end if;
                    end process;
               end generate;
               roll_after_add: if decomp_idx < decomposition_length - 1 generate
                    process (i_clk)
                    begin
                         if rising_edge(i_clk) then
                              stages_slices(decomp_idx)(decomp_idx + 1 to decomposition_length - 1) <= stages_slices(decomp_idx)(decomp_idx to decomposition_length - 2);
                         end if;
                    end process;
               end generate;
          end generate;
     end generate;

end architecture;
