----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: constants_utils - package
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This is the root of our import-dependency tree, these constants that are not based on other files.
--             The values here concern the modulo solution and to calculate delays in this context it also
--             contains some NTT-specific constants.
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

package constants_utils is

     constant debug_mode                  : boolean := false; -- set to true for default modulo solution and the simpler parameter set
     constant dead_simulation             : boolean := false; -- if you only want to evaluate constants from the constants files set this to true. It skips twiddle-computations and other things that take long
     -- these are just IDs - no need to change them as long as they are unique
     constant ntt_modulo_solution_default : integer := 0;     -- useful for faster simulation and to check if there is an error in a non-default modulo solution
     constant ntt_modulo_solution_solinas : integer := 1;
     -- inherent constants that you should not change
     constant log2_coeffs_per_bram : integer := 9; -- 1 bram holds 512=2**9 values
     constant ram_style_uram       : string  := "ultra";
     constant ram_style_bram       : string  := "block";
     constant ram_style_auto       : string  := "auto";

     -- values you may change
     constant log2_num_coefficients                : integer := 10; --8
     constant log2_ntt_throughput                  : integer := 4; --5;
     constant ntt_modulo_solution                  : integer := ntt_modulo_solution_default * boolean'pos(debug_mode) + ntt_modulo_solution_solinas * boolean'pos(not debug_mode); -- ntt_modulo_solution_solinas, ntt_modulo_solution_default
     constant use_karazuba                         : boolean := not debug_mode;                                                                                                    -- karazuba is only implemented for unsigned_polym_coefficient_bit_width=64. If false, default mult is used, which works for any bit width.
     constant karazuba_depth_2                     : boolean := true;                                                                                                              -- only valid if use_karazuba=true
     constant negacyclic                           : boolean := not debug_mode;                                                                                                    -- this parameter determines if you want get a negacyclic ntt or intt. Alternatively you can make a normal ntt negacyclic by using twisting.
     constant unsigned_polym_coefficient_bit_width : integer := 64;                                                                                                                -- must be a power of 2 (not for the ntt but for tfhe)

     -- experimental values that may lead to a better sythesis result
     constant default_cascaded_bram             : boolean := log2_num_coefficients - log2_ntt_throughput > log2_coeffs_per_bram;
     constant ntt_cascaded_twiddle_bram         : boolean := (log2_num_coefficients - 1) - log2_ntt_throughput > log2_coeffs_per_bram; -- only half as many twiddles as coefficients
     constant minimum_ram_retiming_latency      : integer := 2;                                                                        -- in practice one less than set here
     constant default_ram_retiming_latency      : integer := minimum_ram_retiming_latency + 1 * boolean'pos(default_cascaded_bram);    -- for the processor-buffers
     constant ntt_twiddle_rams_retiming_latency : integer := minimum_ram_retiming_latency + 1 * boolean'pos(ntt_cascaded_twiddle_bram);
     constant twiddle_ram_type                  : string  := ram_style_auto;
     constant ntt_butterfly_in_bufs             : boolean := false;                                                                    -- if true improves timing but more LUTRAM consumption
     constant ntt_butterfly_out_bufs            : boolean := false;                                                                    -- if true improves timing but slightly more FF consumption
     constant ntt_stage_logic_out_bufs          : integer := ntt_twiddle_rams_retiming_latency;                                        -- must be the same as ntt_twiddle_rams_retiming_latency but could be distinguished in the future
     constant rolling_butterfly_buffers         : boolean := false;                                                                    -- if true leads to worse results
     constant big_add_in_buf                    : boolean := false;                                                                    -- if true leads to worse results
     constant trailing_reset_buffer_len         : integer := 2 ** log2_ntt_throughput;
     constant counter_buffer_len                : integer := 1;                                                                        -- Experimental, leave at 1 to not use this feature. Buffers the output of large counters. Must be at minimum 1 and at maximum clks_per_64_bit_add_mod because of mult_xai_minus_1_plus_acc
     constant ntt_num_clks_reset_early          : integer := ntt_twiddle_rams_retiming_latency + (counter_buffer_len - 1);

     -- The butterflys expect that mult-latency is bigger than add latency - which should naturally be the case
     constant default_32_bit_mult_latency           : integer := 6;                        -- below 6 you get DRC violations. Depending on DSP register-optimization you may also get DRC violations with 6 but very few
     constant dsp_mult_latency                      : integer := 4;                        -- including pre- and post-adders
     constant karazuba_32_bit_mult_latency          : integer := 2 + dsp_mult_latency + 1; -- 1 after-dsp-adder stage, 2 before
     constant karazuba_64_mult_latency              : integer := 3 + boolean'pos(karazuba_depth_2) * (karazuba_32_bit_mult_latency) + boolean'pos(not karazuba_depth_2) * default_32_bit_mult_latency;
     constant mult_64_default_retiming_registers    : integer := 2;                        --18; -- if not Karazuba: set to 2 for debugging, set to 10 for least ressource usage, set to 18 for happy DRC report. Has no effect if karazuba-mult is used.
     constant karazuba_dsp_level_retiming_registers : integer := boolean'pos(karazuba_depth_2) * dsp_mult_latency + boolean'pos(not karazuba_depth_2) * default_32_bit_mult_latency;
     constant dsp_level_retiming_registers          : integer := boolean'pos(use_karazuba) * karazuba_dsp_level_retiming_registers + boolean'pos(not use_karazuba) * (mult_64_default_retiming_registers);

     constant clks_per_64_bit_add : integer := 1 + 1 * boolean'pos(big_add_in_buf); -- in our testing, 1 is the optimal value here
     constant clks_per_34_bit_add : integer := 1;                                   -- only relevant for solinas modulo solution

     constant clks_per_64_bit_mult : integer := boolean'pos(not use_karazuba) * mult_64_default_retiming_registers + boolean'pos(use_karazuba) * karazuba_64_mult_latency; -- mult of two 64-bit values = 16 18-bit-multiplications (and 16 carry additions) + adder tree (3 36-bit adds per 36-output-bits. Have 128-bit result --> 12 adds + 4 carry adds = 32 DSP "calls". Computung depth: 1+16+4

     -- values you may change if you did the underlying changes to the HDL code
     constant ntt_params_list_length                 : integer := 16;
     constant log2_num_samples_per_butterfly         : integer := 1;                                                 -- since the architecture only supports one twiddle factor per butterfly there is a lot to do if you want to change this value
     -- latency-related constants
     -- latency is measured from the clock tic where the module has the first valid input
     constant input_reading_latency                  : integer := 1;
     constant reg_chain_input_writing_latency        : integer := 1;
     constant output_writing_latency                 : integer := 1;
     constant solinas_modulo_latency                 : integer := clks_per_34_bit_add + 2 * clks_per_64_bit_add + 1; -- +1 to decide which of the 3 options to take
     constant default_modulo_latency                 : integer := output_writing_latency;
     constant solinas_ab_mod_p_latency               : integer := solinas_modulo_latency + clks_per_64_bit_mult;
     constant default_ab_mod_p_latency               : integer := default_modulo_latency + clks_per_64_bit_mult;     -- no in_out_latency here
     constant easy_reduction_latency                 : integer := clks_per_64_bit_add + 1;                           -- +1 to decide which of the 2 values to take
     constant clks_per_64_bit_add_mod                : integer := clks_per_64_bit_add + easy_reduction_latency;
     constant clks_per_butterfly_without_mult_modulo : integer := clks_per_64_bit_add_mod + 1 * boolean'pos(ntt_butterfly_in_bufs) + 1 * boolean'pos(ntt_butterfly_out_bufs);

     constant rotate_polym_reset_clks_ahead : integer := 3 + (counter_buffer_len - 1); -- 3 clks after reset drops rotate module has computed the first valid coeff-indices to request
     constant rotate_polym_reorder_delay    : integer := 2;

     -- values that are inferred - DO NOT CHANGE ANYTHING BELOW THIS LINE
     constant num_coefficients : integer := 2 ** log2_num_coefficients;

     function init_clks_per_ab_mod_p
          return integer;

     function init_clks_per_mod
          return integer;

     constant clks_per_ab_mod_p : integer := init_clks_per_ab_mod_p;
     constant clks_per_mod      : integer := init_clks_per_mod;
     constant clks_per_mult_mod : integer := clks_per_mod + clks_per_64_bit_mult;

     -- ntt related but non-generic constants
     constant samples_per_butterfly : integer := 2 ** log2_num_samples_per_butterfly;
     -- timing related constants that depend on the modulus solution
     constant gentleman_sande_twiddle_offset                            : integer := clks_per_64_bit_add_mod; -- mult modulo happends at the end of gentleman-sande butterfly
     constant clks_per_butterfly                                        : integer := clks_per_butterfly_without_mult_modulo + clks_per_ab_mod_p;
     constant sequential_stage_clks_till_first_butterfly_result         : integer := clks_per_butterfly;
     constant sequential_stage_clks_till_first_butterfly_result_no_mult : integer := sequential_stage_clks_till_first_butterfly_result - clks_per_ab_mod_p;
     constant initial_clks_per_sequential_block                         : integer := sequential_stage_clks_till_first_butterfly_result;

end package;

package body constants_utils is

     function init_clks_per_ab_mod_p
          return integer is
          variable res : integer;
     begin
          case ntt_modulo_solution is
               when ntt_modulo_solution_default =>
                    res := default_ab_mod_p_latency;
               when ntt_modulo_solution_solinas =>
                    res := solinas_ab_mod_p_latency;
               when others =>
                    res := default_ab_mod_p_latency;
                    assert false report "Invalid ntt-solution specifier" severity error;
          end case;
          return res;
     end function;

     function init_clks_per_mod
          return integer is
          variable res : integer;
     begin
          case ntt_modulo_solution is
               when ntt_modulo_solution_default =>
                    res := default_modulo_latency;
               when ntt_modulo_solution_solinas =>
                    res := solinas_modulo_latency;
               when others =>
                    res := default_modulo_latency;
                    assert false report "Invalid ntt-solution specifier" severity error;
          end case;
          return res;
     end function;

end package body;
