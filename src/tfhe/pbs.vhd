----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: pbs
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This module does the programmable bootstrapping operation by combining pbs_init, external product and sample extract.
--             It does not do any memory communication and expects the inputs to arrive at the correct time.
--             This module trusts that the input i_lwe_b stay stable for num_coeffs/throughput clock tics
--             and that i_lwe_ai & i_sample_extract_idx stay stable for at least the same time.
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
     use work.tfhe_utils.all;
     use work.tfhe_constants.all;
     use work.math_utils.all;
     use work.processor_utils.all;

entity pbs is
     generic (
          throughput                     : integer;
          decomposition_length           : integer; -- for the external product
          num_LSBs_to_round              : integer; -- for the external product
          bits_per_slice                 : integer; -- for the external product
          polyms_per_ciphertext          : integer; -- for the external product
          min_latency_till_monomial_mult : integer; -- for the external product
          num_iterations                 : integer  -- for the blind rotation
     );
     port (
          i_clk                : in  std_ulogic;
          i_reset              : in  std_ulogic;
          i_lookup_table_part  : in  sub_polynom(0 to throughput - 1); -- for the programmable bootstrapping, only a part of an RLWE ciphertext
          i_lwe_b              : in  rotate_idx;
          i_lwe_ai             : in  rotate_idx;
          i_BSK_i_part         : in  sub_polynom(0 to throughput * decomposition_length * polyms_per_ciphertext - 1);
          -- i_sample_extract_idx : in  idx_int;
          -- o_sample_extract_idx : out idx_int;
          o_result             : out sub_polynom(0 to throughput - 1);
          o_next_module_reset  : out std_ulogic
     );
end entity;

architecture Behavioral of pbs is

     component rotate_polym_with_buffer is
          generic (
               throughput    : integer;
               rotate_right  : boolean;
               rotate_offset : integer;
               negate_polym  : boolean;
               reverse_polym : boolean
          );
          port (
               i_clk               : in  std_ulogic;
               i_reset             : in  std_ulogic;
               i_sub_polym         : in  sub_polynom(0 to throughput - 1);
               i_rotate_by         : in  rotate_idx;
               o_result            : out sub_polynom(0 to throughput - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     component blind_rotation is
          generic (
               throughput                     : integer;
               decomposition_length           : integer; -- for the external product
               num_LSBs_to_round              : integer; -- for the external product
               bits_per_slice                 : integer; -- for the external product
               polyms_per_ciphertext          : integer; -- for the external product
               min_latency_till_monomial_mult : integer; -- for the external product
               num_iterations                 : integer  -- aka k_lwe
          );
          port (
               i_clk               : in  std_ulogic;
               i_reset             : in  std_ulogic;
               i_lwe_ai            : in  rotate_idx;
               i_acc_part          : in  sub_polynom(0 to throughput - 1);
               i_BSK_i_part        : in  sub_polynom(0 to throughput * decomposition_length * polyms_per_ciphertext - 1);
               o_result            : out sub_polynom(0 to throughput - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     signal pbs_acc_init_not_ready : std_ulogic;
     signal pbs_acc_init_not_ready_buf : std_ulogic;
     signal blind_rotate_input     : sub_polynom(0 to throughput - 1);
     signal blind_rotate_input_buf     : sub_polynom(0 to throughput - 1);
     signal blind_rotate_output    : sub_polynom(0 to throughput - 1);
     signal blind_rotate_output_buf    : sub_polynom(0 to throughput - 1);
     signal sample_extract_reset   : std_ulogic;
     signal sample_extract_reset_buf   : std_ulogic;

     -- signal samp_extract_idx : rotate_idx;
     -- signal samp_extract_idx_buf : rotate_idx;

     -- signal b_extract_idx_bufferchain : idx_int_array(0 to rotate_polym_first_block_initial_delay - output_writing_latency - 1);

begin

     init: rotate_polym_with_buffer
          generic map (
               throughput    => throughput,
               rotate_right  => true, -- b <= X^(-b) so we rotate by b but reversed
               rotate_offset => 0,
               negate_polym  => false,
               reverse_polym => false
          )
          port map (
               i_clk               => i_clk,
               i_reset             => i_reset,
               i_sub_polym         => i_lookup_table_part,
               i_rotate_by         => i_lwe_b,
               o_result            => blind_rotate_input,
               o_next_module_reset => pbs_acc_init_not_ready
          );

     init_output_buf: if buffer_init_output generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               blind_rotate_input_buf <= blind_rotate_input;
               pbs_acc_init_not_ready_buf <= pbs_acc_init_not_ready;
          end if;
          end process;
     end generate;
     no_init_output_buf: if not buffer_init_output generate
          blind_rotate_input_buf <= blind_rotate_input;
          pbs_acc_init_not_ready_buf <= pbs_acc_init_not_ready;
     end generate;

     blind_rotate: blind_rotation
          generic map (
               throughput                     => throughput,
               decomposition_length           => decomposition_length,
               num_LSBs_to_round              => num_LSBs_to_round,
               bits_per_slice                 => bits_per_slice,
               polyms_per_ciphertext          => polyms_per_ciphertext,
               min_latency_till_monomial_mult => min_latency_till_monomial_mult,
               num_iterations                 => num_iterations
          )
          port map (
               i_clk               => i_clk,
               i_reset             => pbs_acc_init_not_ready_buf,
               i_lwe_ai            => i_lwe_ai,
               i_acc_part          => blind_rotate_input_buf,
               i_BSK_i_part        => i_BSK_i_part,
               o_result            => blind_rotate_output,
               o_next_module_reset => sample_extract_reset
          );

     samp_extract_input_buf: if buffer_samp_extract_input generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               sample_extract_reset_buf <= sample_extract_reset;
               blind_rotate_output_buf <= blind_rotate_output;
               -- samp_extract_idx_buf <= samp_extract_idx;
          end if;
          end process;
     end generate;
     no_samp_extract_input_buf: if not buffer_samp_extract_input generate
          sample_extract_reset_buf <= sample_extract_reset;
          blind_rotate_output_buf <= blind_rotate_output;
          -- samp_extract_idx_buf <= samp_extract_idx;
     end generate;

     -- one way to do the sample extract is to read the .a-part coefficients in reverse
     -- then negate them all
     -- then do a right-rotation by 1
     -- (this will make a factor go over bounds, which will change its sign to be positive again)
     -- and in the end mash it together with the unchangedfirst coefficient of the .b part
     sample_extract: rotate_polym_with_buffer
          generic map (
               throughput    => throughput,
               rotate_right  => true,
               rotate_offset => 1, -- +1 because 0'th idx is rotated by 1
               negate_polym  => true,
               reverse_polym => true
          )
          port map (
               i_clk               => i_clk,
               i_reset             => sample_extract_reset_buf,
               i_sub_polym         => blind_rotate_output_buf,
               i_rotate_by         => sample_extract_idx,
               o_result            => o_result,
               o_next_module_reset => o_next_module_reset
          );

     -- process (i_clk)
     -- begin
     --      if rising_edge(i_clk) then
     --           -- required for lwe_n_buffer
     --           b_extract_idx_bufferchain <= i_sample_extract_idx & b_extract_idx_bufferchain(0 to b_extract_idx_bufferchain'length - 2);
     --      end if;
     -- end process;
     -- o_sample_extract_idx <= b_extract_idx_bufferchain(b_extract_idx_bufferchain'length - 1);

     -- samp_extract_idx(samp_extract_idx'length - i_sample_extract_idx'length to samp_extract_idx'length - 1) <= i_sample_extract_idx;
     -- samp_extract_idx(0 to samp_extract_idx'length - i_sample_extract_idx'length - 1)                       <= (others => '0');

end architecture;
