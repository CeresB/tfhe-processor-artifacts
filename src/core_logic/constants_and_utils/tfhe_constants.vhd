----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: tfhe_constants - package
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: TFHE related constants that are not required by the NTT.
--             The delay calculations here are not used by the PBS or keyswitch modules.
--             They are made for an outside module, so that it knows when to expect values.
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
  use work.datatypes_utils.all;
  use work.ip_cores_constants.all;
  use work.ntt_utils.all;
  use work.math_utils.all;

package tfhe_constants is

  constant use_pbs_fake : boolean := false;--debug_mode; -- then blind-rotation output is just the input delayed. Useful when just checking synchronization.

  constant use_end_step_input_buffer : boolean := false; -- experimental
  constant extra_latency_buf_extra_output_buffer : boolean := true; -- experimental, better for timing?
  constant use_elem_mult_res_output_buffer       : boolean := false; -- experimental, apparently leads to much worse timing if set to true
  constant use_ntt_out_buf_input_buffer     : boolean := true; -- set to true for better timing
  constant rotate_polym_out_buffer   : boolean := false; -- did not improve timing
  constant lwe_n_buf_out_buffer      : boolean := false;
  constant use_intt_input_buffer     : boolean := false; -- experimental
  constant acc_buf_extra_output_buffer : boolean := true;  -- set to true for better timing
  constant buffer_samp_extract_output   : boolean := false;  -- good against congestion
  constant buffer_samp_extract_input   : boolean := true;  -- good against congestion
  constant buffer_init_output          : boolean := true;  -- good against congestion
  constant buffer_blind_rot_output     : boolean := false; -- not good for congestion
  constant use_hbm_output_buffer                 : boolean := true; -- leads to worse timing, around HBM just too much congestion
  constant x_ai_minus_1_sub_buf_output_buffer : boolean := false; -- experimental, apparently worse for congestion
  constant buffer_blind_rot_input             : boolean := false; -- experimental, apparently worse for congestion
  constant use_decomp_res_output_buffer       : boolean := false; -- serves as the input buffer for the ntt
  constant use_decomp_res_temp_buffer         : boolean := false; -- leads to worse congestion
  constant use_intt_res_output_buffer         : boolean := false; -- experimental, apparently leads to worse timing if set to true

  constant ntt_out_buf_ram_retiming_latency : integer := pingpong_ram_retiming_latency + 1;
  constant bski_buffer_output_buffer        : integer := default_ram_retiming_latency;
  constant lut_buf_ram_retiming_latency : integer := default_ram_retiming_latency; -- * boolean'pos((pbs_batchsize * num_polyms_per_rlwe_ciphertext * num_coefficients / pbs_throughput) > (2 ** log2_coeffs_per_bram));
  constant ai_buffer_output_buffer : integer := default_ram_retiming_latency + 1; -- must be bigger than 0
  constant x_ai_minus_1_sub_buf_ram_retiming_latency : integer := minimum_ram_retiming_latency + 1 * boolean'pos(x_ai_minus_1_sub_buf_output_buffer);
  constant b_buffer_output_buffer  : integer := 2;                                -- must be bigger than 1
  constant op_buffer_output_buffer : integer := 2;                                -- must be bigger than 1

  constant ntt_out_buf_reset_buf_len : integer := 3; --2*log2_ntt_throughput; -- must be bigger than 0

  -- INFO: you find additional configuration in...
  --                                           ... for coefficient- and polynom-size and modulus solution: constants_utils.vhd
  --                                           ... for ntt-prime selection: ntt_utils

  -- values you may change
  constant log2_pbs_throughput      : integer := log2_ntt_throughput; --get_max(log2_ntt_throughput, get_bit_length(ai_hbm_coeffs_per_clk - 1)); -- must be between 2 and log2_maximum_sequential_ntt_throughput (including the border values)
  constant log2_decomp_base         : integer := 10;                  -- also known as log2(beta), 2**log2_decomp_base must be power of 2 for the decomposition to work
  constant decomp_length            : integer := 2;                   -- also known as L
  constant decomp_num_LSBs_to_round : integer := log2_decomp_base;
  -- design decision: k_lwe is always a multiple of ai_hbm_coeffs_per_clk, so that it fits into the storage neatly.
  constant k_lwe        : integer             := integer(ceil(real(boolean'pos(not debug_mode) * 500 + 2 * boolean'pos(debug_mode)) / real(ai_hbm_coeffs_per_clk))) * ai_hbm_coeffs_per_clk; -- must be a multiple of ai_hbm_coeffs_per_clk
  constant k            : integer             := 1;                                                                                                                                          -- k_rlwe. use a power of 2 for decomp_length and k for best performance of our adder trees
  constant tfhe_modulus : synthesiseable_uint := ntt_prime;                                                                                                                                  -- you cannot easily seperate ntt and tfhe modulus since the whole architecture is build with it in mind
  constant sample_extract_idx: rotate_idx := to_rotate_idx(1);

  constant ksk_throughput    : integer := 2; -- blocksize processed by keyswitch module. After k*N+1 interations the keyswitch module returns a block of this size as the partial keyswitch result
  constant decomp_length_ksk : integer := 2;

  constant acc_buffer_ram_type           : string := ram_style_auto;
  constant acc_old_buffer_ram_type       : string := ram_style_auto;
  constant extra_latency_buffer_ram_type : string := ram_style_auto;
  constant ntt_big_out_buffer_ram_type   : string := ram_style_auto;
  constant rotate_buffer_ram_type        : string := ram_style_auto;

  -- values that are inferred - do not change anything in the following block
  -- general
  constant ai_pkgs_per_lwe: integer := k_lwe/ai_hbm_coeffs_per_clk;
  constant num_polyms_per_rlwe_ciphertext               : integer := (1 + k);
  constant pbs_throughput                               : integer := 2 ** log2_pbs_throughput;
  constant log2_overall_throughput_num_blocks_per_polym : integer := log2_num_coefficients - log2_pbs_throughput;
  constant overall_throughput_num_blocks_per_polym      : integer := 2 ** log2_overall_throughput_num_blocks_per_polym;
  constant clks_till_mult_mod_done                      : integer := clks_per_mod;
  constant elem_wise_mult_latency                       : integer := clks_per_mult_mod;

  --
  -- Delay calculations. Changing these requires to change the underlying code and architecture
  -- Only changing the values here is futile: some are seperately calculated in blind_rotation_iteration
  -- such that you need to change them here and there
  --
  constant ex_prod_num_ntts  : integer := decomp_length;
  constant ex_prod_num_intts : integer := 1;

  -- ntt
  constant ntt_throughput                  : integer := (decomp_length / ex_prod_num_ntts) * pbs_throughput;
  constant pbs_log2_ntt_throughput         : integer := integer((log2(real(ntt_throughput))));
  constant ntt_clks_till_first_block_ready : integer := get_ntt_latency(log2_num_coefficients, pbs_log2_ntt_throughput, ntt_params.negacyclic, false, false, false);
  constant ntt_num_blocks_per_polym        : integer := num_coefficients / ntt_throughput;

  -- intt
  constant intt_throughput                             : integer := pbs_throughput;
  constant intt_num_blocks_per_polym                   : integer := num_coefficients / intt_throughput;
  constant intt_wo_rescaling_clks_till_first_res_ready : integer := get_ntt_latency(log2_num_coefficients, pbs_log2_ntt_throughput, ntt_params.negacyclic, true, false, false) + 1 * boolean'pos(use_intt_res_output_buffer);

  -- decomposition
  constant initial_decomp_delay_without_end_reduction : integer := clks_per_64_bit_add_mod + (decomp_length - 1);
  constant initial_decomp_delay_first_block           : integer := initial_decomp_delay_without_end_reduction + 1 + 1 * boolean'pos(use_decomp_res_output_buffer) + 1 * boolean'pos(use_decomp_res_temp_buffer); -- +1 for conditional add at the end

  -- rotate polym
  constant rotate_polym_first_block_initial_delay : integer := 1 + rotate_polym_reorder_delay + buffer_answer_delay + rotate_polym_reset_clks_ahead; -- +1 because of stage 0
  constant rotate_with_buffer_latency             : integer := rotate_polym_first_block_initial_delay + ntt_num_blocks_per_polym - rotate_polym_reset_clks_ahead;

  -- ACC*(X^a_i -1)+ACC_old
  constant blind_rot_iter_end_step_initial_delay : integer := rotate_with_buffer_latency + clks_per_64_bit_add_mod;

  -- adder tree
  constant adder_tree_clks_per_stage            : integer := clks_per_64_bit_add_mod;
  constant blind_rot_iter_adder_tree_num_stages : integer := get_bit_length(num_polyms_per_rlwe_ciphertext * decomp_length - 1);
  constant blind_rot_iter_adder_tree_latency    : integer := blind_rot_iter_adder_tree_num_stages * adder_tree_clks_per_stage;

  -- ntt_out_buf
  constant clks_till_ntt_out_buffer_ready : integer := ntt_clks_till_first_block_ready + num_polyms_per_rlwe_ciphertext * ntt_num_blocks_per_polym + ntt_out_buf_ram_retiming_latency + 1 * boolean'pos(use_ntt_out_buf_input_buffer);

  -- blind rotation
  constant blind_rotation_decision_delay : integer := 1; -- is like an extra clock cycle of latency for the external product

  -- blind rotation iteration
  constant blind_rot_iter_decomp_latency                  : integer := initial_decomp_delay_first_block;
  constant blind_rot_iter_min_latency_till_elem_wise_mult : integer := blind_rot_iter_decomp_latency + clks_till_ntt_out_buffer_ready;
  constant blind_rot_iter_min_latency_till_monomial_mult  : integer := blind_rot_iter_min_latency_till_elem_wise_mult + elem_wise_mult_latency + 1 * boolean'pos(use_elem_mult_res_output_buffer) + blind_rot_iter_adder_tree_latency + intt_wo_rescaling_clks_till_first_res_ready + 1 * boolean'pos(use_intt_input_buffer) + 1 * boolean'pos(use_end_step_input_buffer);
  constant blind_rot_iter_minimum_latency                 : integer := blind_rot_iter_min_latency_till_monomial_mult + blind_rot_iter_end_step_initial_delay + 1 * boolean'pos(buffer_blind_rot_input) + 1 * boolean'pos(buffer_blind_rot_output);
  -- we don't want unused pipeline stages when latency is not divisible by num_polyms_per_rlwe_ciphertext*num_blocks_per_polynom
  -- that is why we add extra stages and recompute all delays from there.
  constant blind_rot_iter_pipeline_steps_per_ciphertext   : integer := overall_throughput_num_blocks_per_polym * num_polyms_per_rlwe_ciphertext;
  constant blind_rot_iter_min_num_ciphertexts_in_pipeline : integer := integer(floor(real(blind_rot_iter_minimum_latency) / real(blind_rot_iter_pipeline_steps_per_ciphertext)));
  constant blind_rot_iter_extra_latency_raw               : integer := (blind_rot_iter_pipeline_steps_per_ciphertext - (blind_rot_iter_minimum_latency - blind_rot_iter_min_num_ciphertexts_in_pipeline * blind_rot_iter_pipeline_steps_per_ciphertext) - blind_rotation_decision_delay) mod blind_rot_iter_pipeline_steps_per_ciphertext;
  constant blind_rot_iter_extra_latency                   : integer := blind_rot_iter_extra_latency_raw + blind_rot_iter_pipeline_steps_per_ciphertext*boolean'pos(blind_rot_iter_extra_latency_raw + initial_decomp_delay_first_block < ntt_num_clks_reset_early); -- need to ensure that the values do not arrive before the real reset
  constant blind_rot_iter_latency_till_elem_wise_mult     : integer := blind_rot_iter_min_latency_till_elem_wise_mult + blind_rot_iter_extra_latency;
  constant blind_rot_iter_latency_till_monomial_mult      : integer := blind_rot_iter_min_latency_till_monomial_mult + blind_rot_iter_extra_latency;
  constant blind_rot_iter_latency_till_ready_for_ai       : integer := blind_rot_iter_latency_till_monomial_mult;
  constant blind_rot_iter_latency                         : integer := blind_rot_iter_minimum_latency + blind_rot_iter_extra_latency;

  constant blind_rot_iter_num_ciphertexts_in_pipeline : integer := (blind_rot_iter_latency + blind_rotation_decision_delay) / blind_rot_iter_pipeline_steps_per_ciphertext;
  constant pbs_batchsize                              : integer := blind_rot_iter_num_ciphertexts_in_pipeline;

  constant extra_latency_buf_uses_ram         : boolean := blind_rot_iter_extra_latency > (2 ** log2coeffs_per_lutram);
  constant extra_latency_ram_retiming_latency : integer := default_ram_retiming_latency + 1 * boolean'pos(extra_latency_buf_extra_output_buffer) - 1 * boolean'pos(not extra_latency_buf_uses_ram);
  constant acc_buf_ram_retiming_latency       : integer := default_ram_retiming_latency + 1 * boolean'pos(blind_rot_iter_min_latency_till_monomial_mult > (2 ** log2_coeffs_per_bram)) + 1 * boolean'pos(acc_buf_extra_output_buffer);

  -- blind rotation
  constant blind_rotation_latency : integer := k_lwe * blind_rot_iter_latency;

  -- bootstrapping init
  constant bs_init_latency : integer := rotate_with_buffer_latency + output_writing_latency;

  -- sample extract
  constant sample_extract_latency : integer := rotate_with_buffer_latency;

  -- bootstrapping
  constant bs_clks_till_first_result_block   : integer := bs_init_latency + blind_rotation_latency + sample_extract_latency;
  constant bs_clks_till_ciphertext_batch_out : integer := bs_clks_till_first_result_block + (num_coefficients / pbs_throughput) * num_polyms_per_rlwe_ciphertext * blind_rot_iter_num_ciphertexts_in_pipeline - 1; -- -1 because the first block is included in bs_clks_till_first_result_block

  -- -- keyswitch     
  -- constant initial_decomp_delay_without_end_reduction_ksk : integer := clks_per_64_bit_add_mod + (decomp_length_ksk - 1);
  -- constant initial_decomp_delay_first_block_ksk           : integer := initial_decomp_delay_without_end_reduction_ksk + easy_reduction_latency;
  -- constant ksk_num_adder_tree_stages                      : integer := get_bit_length(decomp_length_ksk - 1);
  -- constant ksk_clks_till_mult                             : integer := initial_decomp_delay_first_block;
  -- constant ksk_clks_till_lwe_add                          : integer := initial_decomp_delay_first_block + clks_per_mult_mod + ksk_num_adder_tree_stages * adder_tree_clks_per_stage;
  -- constant muladd_latency                                 : integer := ksk_clks_till_lwe_add + clks_per_64_bit_add_mod + output_writing_latency;
  -- constant muladd_batchsize: integer := ksk_clks_till_lwe_add + clks_per_64_bit_add_mod;
  -- -- keyswitch has as much time as the bootstrapping to process a similar amount of data
  -- -- considering the written out formular for the keyswitch, our keyswitch module only computes the keyswitch for ksk_throughput-many rows at a time
  -- -- for a complete keyswitch this must be repeated num_ksk_blocks-many times
  -- constant num_ksk_throughput_blocks_per_lwe : integer := integer(ceil(real(k_lwe) / real(ksk_throughput))) + 1; -- +1 for the block that contains the b-value
  -- -- because of pipelining we compute the "row" incremental in ksk_num_rlwe_coeffs_in_pipeline-sized steps
  -- constant ksk_num_rlwe_coeffs_in_pipeline   : integer := muladd_latency - output_writing_latency - 1;           -- -1 because first value is non-buffered input
  -- -- number of clock tics to compute a whole row
  -- constant num_muladds_per_keyswitch_block   : integer := k * num_coefficients + 1;                              -- +1 for the block that contains the b-value
  -- -- clks_per_64_bit_add_mod dictates the latency of the accumulator loop
  -- constant clks_per_keyswitch                : integer := num_muladds_per_keyswitch_block * num_ksk_throughput_blocks_per_lwe;
  -- constant ksk_remaning_time                 : integer := bs_clks_till_ciphertext_batch_out - clks_per_keyswitch * blind_rot_iter_num_ciphertexts_in_pipeline + muladd_latency;

  -- -- -- a compiler can use the following values to ensure that values do not overwrite each other. For our purposes we simply don't exceed them.
  -- -- constant bs_max_num_ciphertexts_in_pipeline : integer := blind_rot_iter_num_ciphertexts_in_pipeline; -- Compiler needs to know this value
  -- -- constant bs_max_num_blocks_in_pipeline      : integer := blind_rot_iter_num_ciphertexts_in_pipeline * blind_rot_iter_pipeline_steps_per_ciphertext;
  -- -- constant num_decomp_length_muladds          : integer := integer(floor(real(ksk_remaning_time * ksk_throughput) / real(num_ksk_throughput_blocks_per_lwe)));
end package;

package body tfhe_constants is

end package body;
