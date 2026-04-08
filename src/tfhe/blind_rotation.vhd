----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: blind_rotation
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This module does the programmable bootstrapping operation through accumulation.
--             It does not do any memory communication and expects the inputs to arrive at the correct time.
--             This module trusts that the inputs i_lwe_ai and i_acc_part stay stable for num_coeffs/throughput clock tics.
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
     use work.tfhe_constants.all;
     use work.math_utils.all;

entity blind_rotation is
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
end entity;

architecture Behavioral of blind_rotation is

     component blind_rotation_iteration is
          generic (
               throughput                     : integer;
               decomposition_length           : integer;
               num_LSBs_to_round              : integer;
               bits_per_slice                 : integer;
               polyms_per_ciphertext          : integer;
               min_latency_till_monomial_mult : integer -- the necessary latency calculations for this are needed in many modules so we source this value from a global source
          );
          port (
               i_clk               : in  std_ulogic;
               i_reset             : in  std_ulogic;
               i_ai                : in  rotate_idx;                                                                      -- no buffer! you read it from memory anyway and it does not change during the computation
               i_acc_part          : in  sub_polynom(0 to throughput - 1);
               i_BSK_i_part        : in  sub_polynom(0 to throughput * decomposition_length * polyms_per_ciphertext - 1); -- no buffer! you read it from memory anyway and it does not change during the computation
               o_result            : out sub_polynom(0 to throughput - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     constant ciphertexts_per_blind_rotation : integer := num_iterations * blind_rot_iter_num_ciphertexts_in_pipeline;

     constant blocks_per_ciphertext : integer := (num_coefficients / throughput) * num_polyms_per_rlwe_ciphertext;
     signal ciphertext_block_cnt  : unsigned(0 to get_bit_length(blocks_per_ciphertext - 1) - 1);
     signal ciphertext_cnt        : unsigned(0 to get_bit_length(ciphertexts_per_blind_rotation - 1) - 1);
     signal blind_rot_iter_input  : sub_polynom(0 to throughput - 1);
     signal blind_rot_iter_input_buf  : sub_polynom(0 to throughput - 1);
     signal blind_rot_iter_output : sub_polynom(0 to throughput - 1);
     signal blind_rot_iter_output_buf : sub_polynom(0 to throughput - 1);
     signal blind_rot_iter_reset  : std_ulogic;
     signal blind_rot_iter_reset_buf  : std_ulogic;

     type input_arr is array (natural range <>) of sub_polynom(0 to (blind_rot_iter_input'length) * boolean'pos(use_pbs_fake) - 1);
     signal fake_input_storage : input_arr(0 to (blind_rot_iter_latency - 1) * boolean'pos(use_pbs_fake) - 1);

     constant ciphertext_cnt_early_trigger : integer := 2*log2_pbs_throughput;
     signal mode_change_bufferchain : std_ulogic_vector(0 to ciphertext_cnt_early_trigger - 1);
     signal next_module_reset_chain : std_ulogic_vector(0 to mode_change_bufferchain'length+2-1); -- +2 because mode_change takes 2 clk tics before it steers the outputs

begin

     big_compute_module: if not use_pbs_fake generate
          blind_rot_iter: blind_rotation_iteration
               generic map (
                    throughput                     => throughput,
                    decomposition_length           => decomposition_length,
                    num_LSBs_to_round              => num_LSBs_to_round,
                    bits_per_slice                 => bits_per_slice,
                    polyms_per_ciphertext          => num_polyms_per_rlwe_ciphertext,
                    min_latency_till_monomial_mult => min_latency_till_monomial_mult
               )
               port map (
                    i_clk               => i_clk,
                    i_reset             => blind_rot_iter_reset_buf,
                    i_ai                => i_lwe_ai,
                    i_acc_part          => blind_rot_iter_input_buf,
                    i_BSK_i_part        => i_BSK_i_part,
                    o_result            => blind_rot_iter_output_buf,
                    o_next_module_reset => open
               );
     end generate;

     fake_compute_module: if use_pbs_fake generate
          -- for faster simulation just behave the same latency-wise but nothing more
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    if blind_rot_iter_reset_buf = '0' then
                         fake_input_storage(0) <= blind_rot_iter_input_buf;
                         fake_input_storage(1 to fake_input_storage'length - 1) <= fake_input_storage(0 to fake_input_storage'length - 2);
                         blind_rot_iter_output_buf <= fake_input_storage(fake_input_storage'length - 1);
                    end if;
               end if;
          end process;
     end generate;

     o_next_module_reset <= next_module_reset_chain(next_module_reset_chain'length-1);
     process (i_clk)
     begin
          if rising_edge(i_clk) then
               next_module_reset_chain(1 to next_module_reset_chain'length-1) <= next_module_reset_chain(0 to next_module_reset_chain'length-2);
               if i_reset = '1' then
                    ciphertext_block_cnt <= to_unsigned(blocks_per_ciphertext - 1 - ciphertext_cnt_early_trigger, ciphertext_block_cnt'length);
                    ciphertext_cnt <= to_unsigned(ciphertexts_per_blind_rotation - 1, ciphertext_cnt'length);
                    blind_rot_iter_reset <= '1';
                    next_module_reset_chain(0) <= '1';
               else
                    -- input of external product has one delay so reset also needs a delay
                    blind_rot_iter_reset <= '0';
                    -- output of this module has one delay so reset for next module also needs a delay

                    if ciphertext_cnt = 0 and ciphertext_block_cnt = 0 then
                         next_module_reset_chain(0) <= '0';
                    end if;

                    if ciphertext_block_cnt = 0 then
                         ciphertext_block_cnt <= to_unsigned(blocks_per_ciphertext - 1, ciphertext_block_cnt'length);
                         -- new ciphertext starts
                         if ciphertext_cnt = 0 then
                              ciphertext_cnt <= to_unsigned(ciphertexts_per_blind_rotation - 1, ciphertext_cnt'length);
                         else
                              ciphertext_cnt <= ciphertext_cnt - to_unsigned(1, ciphertext_cnt'length);
                         end if;
                    else
                         ciphertext_block_cnt <= ciphertext_block_cnt - to_unsigned(1, ciphertext_block_cnt'length);
                    end if;
               end if;

               -- blind_rot_iter_input and blind_rot_iter_output change every clock tic
               -- because of high fanout trigger this early and use bufferchain
               if ciphertext_cnt > to_unsigned(ciphertexts_per_blind_rotation-blind_rot_iter_num_ciphertexts_in_pipeline-1, ciphertext_cnt'length) then
                    -- input-output phase
                    mode_change_bufferchain(0) <= '0';
               else
                    -- loop phase
                    mode_change_bufferchain(0) <= '1';
               end if;
               mode_change_bufferchain(1 to mode_change_bufferchain'length - 1) <= mode_change_bufferchain(0 to mode_change_bufferchain'length - 2);

               -- blind_rot_iter_input and blind_rot_iter_output change every clock tic
               if mode_change_bufferchain(mode_change_bufferchain'length - 1) = '0' then
                    -- input-output phase
                    blind_rot_iter_input <= i_acc_part;
                    o_result <= blind_rot_iter_output;
               else
                    -- loop phase
                    blind_rot_iter_input <= blind_rot_iter_output;
               end if;

          end if;
     end process;

     out_buf: if buffer_blind_rot_output generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               blind_rot_iter_output <= blind_rot_iter_output_buf;
          end if;
          end process;
     end generate;
     no_out_buf: if not buffer_blind_rot_output generate
          blind_rot_iter_output <= blind_rot_iter_output_buf;
     end generate;

     in_buf: if buffer_blind_rot_input generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               blind_rot_iter_input_buf <= blind_rot_iter_input;
               blind_rot_iter_reset_buf <= blind_rot_iter_reset;
          end if;
          end process;
     end generate;
     no_in_buf: if not buffer_blind_rot_input generate
          blind_rot_iter_input_buf <= blind_rot_iter_input;
          blind_rot_iter_reset_buf <= blind_rot_iter_reset;
     end generate;

end architecture;
