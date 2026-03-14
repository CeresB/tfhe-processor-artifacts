----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: decomposition
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: A wrapper for decompose_basic.vhd which maps negative coefficients back into Zq.
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

entity decomposition is
     generic (
          throughput           : integer;
          decomposition_length : integer;
          num_LSBs_to_round    : integer;
          bits_per_slice       : integer
     );
     port (
          i_clk       : in  std_ulogic;
          i_sub_polym : in  sub_polynom(0 to throughput - 1);
          o_result    : out synth_uint_vector(0 to throughput * decomposition_length - 1) -- by using this simpler datatype this module only really depends on the generics
     );
end entity;

architecture Behavioral of decomposition is

     component easy_reduction is
          generic (
               modulus         : synthesiseable_uint;
               can_be_negative : boolean
          );
          port (
               i_clk     : in  std_ulogic;
               i_num     : in  synthesiseable_int_extended;
               o_mod_res : out synthesiseable_uint
          );
     end component;

     component basic_decomposition is
          generic (
               throughput           : integer;
               decomposition_length : integer;
               num_LSBs_to_round    : integer;
               bits_per_slice       : integer
          );
          port (
               i_clk       : in  std_ulogic;
               i_sub_polym : in  sub_polynom(0 to throughput - 1);
               o_result    : out synth_L_int_vector(0 to throughput * decomposition_length - 1)
          );
     end component;

     subtype coeff_rounded is unsigned(0 to synthesiseable_uint'length - num_LSBs_to_round - 1);
     type sub_polym_rounded is array (natural range <>) of coeff_rounded;
     type sub_polynom_slice_bits is array (natural range <>) of unsigned(0 to bits_per_slice - 1);
     type slices_length_throughput is array (natural range <>) of sub_polynom_slice_bits(0 to throughput - 1);

     signal temp_result : synth_L_int_vector(0 to throughput * decomposition_length - 1);
     signal temp_result_buf : synth_L_int_vector(0 to throughput * decomposition_length - 1);
     signal result_buf : synth_uint_vector(0 to throughput * decomposition_length - 1);

begin

     basic_part: basic_decomposition
          generic map (
               throughput           => throughput,
               decomposition_length => decomposition_length,
               num_LSBs_to_round    => num_LSBs_to_round,
               bits_per_slice       => bits_per_slice
          )
          port map (
               i_clk       => i_clk,
               i_sub_polym => i_sub_polym,
               o_result    => temp_result
          );
     
     temp_buf: if use_decomp_res_temp_buffer generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               temp_result_buf <= temp_result;
          end if;
          end process;
     end generate;
     no_temp_buf: if not use_decomp_res_temp_buffer generate
          temp_result_buf <= temp_result;
     end generate;
     out_buf: if use_decomp_res_output_buffer generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               o_result <= result_buf;
          end if;
          end process;
     end generate;
     no_out_buf: if not use_decomp_res_output_buffer generate
          o_result <= result_buf;
     end generate;

     red_modules: for i in 0 to result_buf'length - 1 generate
          -- the decomposed values must be reduced because they can be negative
          process (i_clk) is
          begin
            if rising_edge(i_clk) then
               if temp_result_buf(i)(0) = '1' then
                    -- result_buf(i) <= unsigned(std_ulogic_vector(to_unsigned(-1,result_buf(0)'length-temp_result_buf(0)'length)) & std_ulogic_vector(temp_result_buf(i))) + tfhe_modulus;
                    result_buf(i) <= unsigned(resize(temp_result_buf(i),tfhe_modulus'length)) + tfhe_modulus;
               else
                    -- result_buf(i) <= unsigned(std_ulogic_vector(to_unsigned(0,result_buf(0)'length-temp_result_buf(0)'length)) & std_ulogic_vector(temp_result_buf(i)));
                    result_buf(i) <= unsigned(resize(temp_result_buf(i),tfhe_modulus'length));
               end if;
            end if;
          end process;
          -- easy_red_module: easy_reduction
          --      generic map (
          --           modulus         => tfhe_modulus,
          --           can_be_negative => true
          --      )
          --      port map (
          --           i_clk     => i_clk,
          --           i_num     => signed_to_synth_int_extended(signed(temp_result_buf(i))),
          --           o_mod_res => result_buf(i)
          --      );
     end generate;

end architecture;
