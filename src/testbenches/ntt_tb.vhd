----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.09.2024 08:38:39
-- Design Name: 
-- Module Name: ntt_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
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
     use work.math_utils.all;
     use work.ntt_utils.all;
     use work.tb_utils.all;

entity ntt_tb is
     --  Port ( );
end entity;

architecture Behavioral of ntt_tb is

     component ntt is
          generic (
               throughput                : integer;
               ntt_params                : ntt_params_with_precomputed_values;
               invers                    : boolean;
               intt_no_final_reduction   : boolean;
               no_first_last_stage_logic : boolean
          );
          port (
               i_clk               : in  std_ulogic;
               i_reset             : in  std_ulogic; -- reset must be 1 for at least ram_retiming_latency tics to set up the twiddle factors!
               i_sub_polym         : in  sub_polynom(0 to throughput - 1);
               o_result            : out sub_polynom(0 to throughput - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     constant TIME_DELTA : time := 10 ns;
     constant clk_period : time := TIME_DELTA * 2;

     constant log2_throughput : integer := log2_ntt_throughput;

     constant ntt_mixed_format : boolean := true;

     constant ntt_params_short : ntt_params_with_precomputed_values_short := chose_ntt_params(ntt_params, false);

     constant throughput                           : integer := 2 ** log2_throughput;
     constant log2_throughput_num_blocks_per_polym : integer := log2_num_coefficients - log2_throughput;
     constant throughput_num_blocks_per_polym      : integer := 2 ** log2_throughput_num_blocks_per_polym;
     constant next_sample_time                     : time    := throughput_num_blocks_per_polym * clk_period;

     signal ntt_result_buffer     : sub_polynom(0 to throughput - 1);
     signal intt_result_buffer    : sub_polynom(0 to throughput - 1);
     signal ntt_input_coeff_cnt   : idx_int := to_unsigned(0, log2_num_coefficients);
     signal ntt_output_coeff_cnt  : idx_int := to_unsigned(0, log2_num_coefficients);
     signal intt_input_coeff_cnt  : idx_int := to_unsigned(0, log2_num_coefficients);
     signal intt_output_coeff_cnt : idx_int := to_unsigned(0, log2_num_coefficients);

     signal ntt_input_tb                   : polynom;
     signal ntt_input                      : sub_polynom(0 to throughput - 1);
     signal intt_input_tb                  : polynom;
     signal intt_input                     : sub_polynom(0 to throughput - 1);
     signal clk                            : std_ulogic := '1';
     signal ntt_result_buffer_polym        : polynom;
     signal intt_result_buffer_polym       : polynom;
     signal result_ntt_tb                  : polynom; -- v4p ignore w-303
     signal result_intt_tb                 : polynom; -- v4p ignore w-303
     signal ntt_firstoutput_not_ready      : std_ulogic_vector(0 to counter_buffer_len+ntt_cnts_early_reset - 1);
     signal ntt_new_complete_output_ready  : std_ulogic := '0';
     signal intt_new_complete_output_ready : std_ulogic := '0';
     signal intt_firstoutput_not_ready     : std_ulogic_vector(0 to counter_buffer_len+ntt_cnts_early_reset - 1);
     signal finished                       : std_ulogic := '0';

     signal zero_polym           : polynom;
     signal test0_input          : polynom;
     signal test1_input          : polynom;
     signal test2_input          : polynom;
     signal correct_result0      : polynom;
     signal correct_result1      : polynom;
     signal correct_result2      : polynom;
     signal ntt_reset            : std_ulogic := '1';
     signal ntt_ready_for_input  : std_ulogic;
     signal intt_ready_for_input : std_ulogic;
     signal intt_reset           : std_ulogic := '1';

     signal ntt_tests_done    : std_ulogic := '0';
     signal intt_tests_done   : std_ulogic := '0';
     signal tests_done        : std_ulogic := '0';
     signal ntt_tests_passed  : boolean; -- v4p ignore w-303
     signal intt_tests_passed : boolean; -- v4p ignore w-303

     signal ntt_clk_cnt  : integer := 0;
     signal intt_clk_cnt : integer := 0;

     -- constant twiddle_table: tw_table := twiddle_factor_table;
     -- constant twiddle_idx_table: tw_index_table := twiddle_factor_index_table;
     -- constant invers_twiddle_table: tw_table := invers_twiddle_factor_table;
     -- constant invers_twiddle_idx_table: tw_index_table := invers_twiddle_factor_index_table;
     -- constant test_clks_per_bf: integer := clks_per_butterfly;
     -- constant test_fully_parallel_stage_delay: integer := clks_per_butterfly;
     -- constant test_ab_mod_p: integer := clks_per_ab_mod_p;

     -- constant test_ntt_num_stages_fully_parallel          : integer := log2_throughput;
     -- constant test_ntt_num_single_stages                  : integer := log2_num_coefficients - test_ntt_num_stages_fully_parallel;
     -- constant test_ntt_num_blocks_per_polym               : integer := 2 ** log2_num_coefficients / 2 ** log2_throughput;                                                                                                                                                                                                 -- is a power of 2
     -- constant test_ntt_sequential_stages_pipeline_latency : integer := initial_clks_per_sequential_block * (test_ntt_num_single_stages - 1) + boolean'pos(negacyclic) * sequential_stage_clks_till_first_butterfly_result + boolean'pos(not negacyclic) * sequential_stage_clks_till_first_butterfly_result_no_mult + (ntt_stage_logic_out_bufs - 0); -- one stage has no ab_mod_p as the twiddles are 1
     -- constant test_ntt_parallel_stages_pipeline_latency   : integer := clks_per_butterfly * test_ntt_num_stages_fully_parallel;                                                                                                                                                                                          -- ntt_sequential_stages_pipeline_latency contains the delay reduction in case of non-negacyclic intt
     -- constant test_ntt_stages_pipeline_latency            : integer := test_ntt_sequential_stages_pipeline_latency + test_ntt_parallel_stages_pipeline_latency;
     -- constant test_intt_rescaling_latency                 : integer := clks_per_ab_mod_p;
     -- constant test_sequential_stage_clks_till_first_butterfly_result                 : integer := sequential_stage_clks_till_first_butterfly_result;
     constant test_ntt_delay : integer := get_ntt_latency(ntt_params.log2_num_coeffs, log2_throughput, ntt_params.negacyclic, false, true, false); -- v4p ignore w-303
     -- constant test_overflow_reduced_num: unsigned(0 to overflow_reduced_num'length-1) := overflow_reduced_num;

begin
     clk <= not clk after TIME_DELTA when finished /= '1' else '0';

     do_sim: if not dead_simulation generate
          dut: ntt
               generic map (
                    throughput                => throughput,
                    ntt_params                => ntt_params,
                    invers                    => false,
                    intt_no_final_reduction   => false,
                    no_first_last_stage_logic => ntt_mixed_format
               )
               port map (
                    i_clk               => clk,
                    i_reset             => ntt_reset,
                    i_sub_polym         => ntt_input,
                    o_result            => ntt_result_buffer,
                    o_next_module_reset => ntt_firstoutput_not_ready(0)
               );

          idut: ntt
               generic map (
                    throughput                => throughput,
                    ntt_params                => ntt_params,
                    invers                    => true,
                    intt_no_final_reduction   => false,
                    no_first_last_stage_logic => ntt_mixed_format
               )
               port map (
                    i_clk               => clk,
                    i_reset             => intt_reset,
                    i_sub_polym         => intt_input,
                    o_result            => intt_result_buffer,
                    o_next_module_reset => intt_firstoutput_not_ready(0)
               );
     end generate;

     ntt_new_complete_output_ready  <= '1' when ntt_output_coeff_cnt = to_unsigned(0, ntt_output_coeff_cnt'length) and ntt_firstoutput_not_ready(ntt_firstoutput_not_ready'length - 1) = '0' and ntt_reset = '0' else '0';
     intt_new_complete_output_ready <= '1' when intt_output_coeff_cnt = to_unsigned(0, intt_output_coeff_cnt'length) and intt_firstoutput_not_ready(intt_firstoutput_not_ready'length - 1) = '0' and intt_reset = '0' else '0';

     process (clk)
     begin
          if rising_edge(clk) then
               if ntt_tests_done = '1' and intt_tests_done = '1' then
                    tests_done <= '1';
               else
                    tests_done <= '0';
               end if;
               ntt_firstoutput_not_ready(1 to ntt_firstoutput_not_ready'length - 1) <= ntt_firstoutput_not_ready(0 to ntt_firstoutput_not_ready'length - 2);
               intt_firstoutput_not_ready(1 to intt_firstoutput_not_ready'length - 1) <= intt_firstoutput_not_ready(0 to intt_firstoutput_not_ready'length - 2);

               if ntt_ready_for_input = '0' then
                    ntt_input_coeff_cnt <= to_unsigned(0, ntt_input_coeff_cnt'length);
                    ntt_clk_cnt <= 0;
               else
                    ntt_clk_cnt <= ntt_clk_cnt + 1;

                    ntt_input_coeff_cnt <= ntt_input_coeff_cnt + to_unsigned(throughput, ntt_input_coeff_cnt'length);
                    ntt_input <= ntt_input_tb(to_integer(ntt_input_coeff_cnt) to to_integer(ntt_input_coeff_cnt) + throughput - 1);

                    if ntt_firstoutput_not_ready(ntt_firstoutput_not_ready'length - 1) = '0' then
                         ntt_output_coeff_cnt <= ntt_output_coeff_cnt + to_unsigned(throughput, ntt_output_coeff_cnt'length);
                         ntt_result_buffer_polym(to_integer(ntt_output_coeff_cnt) to to_integer(ntt_output_coeff_cnt) + throughput - 1) <= ntt_result_buffer;

                         if ntt_output_coeff_cnt = to_unsigned(0, ntt_output_coeff_cnt'length) then
                              result_ntt_tb <= ntt_result_buffer_polym;
                         end if;
                    else
                         ntt_output_coeff_cnt <= to_unsigned(0, ntt_output_coeff_cnt'length);
                    end if;
               end if;

               if intt_ready_for_input = '0' then
                    intt_input_coeff_cnt <= to_unsigned(0, intt_input_coeff_cnt'length);
                    intt_clk_cnt <= 0;
               else
                    intt_clk_cnt <= intt_clk_cnt + 1;
                    intt_input_coeff_cnt <= intt_input_coeff_cnt + to_unsigned(throughput, intt_input_coeff_cnt'length);
                    intt_input <= intt_input_tb(to_integer(intt_input_coeff_cnt) to to_integer(intt_input_coeff_cnt) + throughput - 1);

                    if intt_firstoutput_not_ready(intt_firstoutput_not_ready'length - 1) = '0' then
                         intt_output_coeff_cnt <= intt_output_coeff_cnt + to_unsigned(throughput, intt_output_coeff_cnt'length);
                         intt_result_buffer_polym(to_integer(intt_output_coeff_cnt) to to_integer(intt_output_coeff_cnt) + throughput - 1) <= intt_result_buffer;

                         if intt_output_coeff_cnt = to_unsigned(0, intt_output_coeff_cnt'length) then
                              result_intt_tb <= intt_result_buffer_polym;
                         end if;
                    else
                         intt_output_coeff_cnt <= to_unsigned(0, intt_output_coeff_cnt'length);
                    end if;
               end if;
          end if;
     end process;

     simulation_start_tests: process
          constant const_sig0 : integer := 2;
          constant const_sig1 : integer := 4;
     begin
          ntt_ready_for_input <= '0';
          intt_ready_for_input <= '0';
          ntt_reset <= '1';
          intt_reset <= '1';

          zero_polym <= get_test_sub_polym(zero_polym'length, 0, 0);
          wait for TIME_DELTA;

          correct_result0 <= zero_polym;
          correct_result1 <= zero_polym;

          -- ntt_input_tb <= zero_polym;
          -- intt_input_tb <= zero_polym;

          -- prepare signal 0
          test0_input <= get_test_sub_polym(zero_polym'length, const_sig0, 0);
          -- prepare signal 1
          test1_input <= get_test_sub_polym(zero_polym'length, const_sig1, 0);
          -- prepare signal 2
          test2_input <= get_test_sub_polym(zero_polym'length, 1, 1);

          wait for TIME_DELTA;

          -- calculate correct result for third input
          if negacyclic then
               correct_result0 <= calc_ntt_res(ntt_params_short, test0_input, false, true);
               correct_result1 <= calc_ntt_res(ntt_params_short, test1_input, false, true);
          else
               -- not calc_ntt_res because of performance
               correct_result0(0) <= to_synth_uint(num_coefficients * const_sig0);
               correct_result1(0) <= to_synth_uint(num_coefficients * const_sig1);
               -- the other coefficients remain 0
          end if;
          correct_result2 <= calc_ntt_res(ntt_params_short, test2_input, false, true);
          wait for TIME_DELTA;
          if ntt_mixed_format then
               test0_input <= to_ntt_mixed_format(test0_input, true, throughput);
               test1_input <= to_ntt_mixed_format(test1_input, true, throughput);
               test2_input <= to_ntt_mixed_format(test2_input, true, throughput);
               -- no need to de-mix the result: intt handles that automatically
               -- correct_result0 <= to_ntt_mixed_format(correct_result0, false, throughput);
               -- correct_result1 <= to_ntt_mixed_format(correct_result1, false, throughput);
               -- correct_result2 <= to_ntt_mixed_format(correct_result2, false, throughput);
          end if;

          -- it takes a few cycles for the reset to propagate through the ntt and intt
          wait until intt_firstoutput_not_ready(0) = '1';

          ntt_reset <= '0';
          -- drop ntt reset early
          for i in 0 to ntt_num_clks_reset_early - 2 loop
               wait for clk_period;
          end loop;
          ntt_ready_for_input <= '1';
          -- test 0, constant signal
          ntt_input_tb <= test0_input;
          wait for next_sample_time;

          -- test 1, constant signal
          ntt_input_tb <= test1_input;
          wait for next_sample_time;
          -- test 2, ascending signal
          ntt_input_tb <= test2_input;
          wait for next_sample_time;

          -- zero out ntt
          ntt_input_tb <= zero_polym;

          -- now intt
          wait until rising_edge(clk);
          wait for clk_period;

          intt_reset <= '0';
          -- drop intt reset early
          for i in 0 to ntt_num_clks_reset_early - 2 loop
               wait for clk_period;
          end loop;
          intt_ready_for_input <= '1';
          -- test 0, constant signal
          intt_input_tb <= correct_result0;
          wait for next_sample_time;

          intt_input_tb <= correct_result1;
          wait for next_sample_time;

          intt_input_tb <= correct_result2;
          wait for next_sample_time;

          -- zero out intt
          intt_input_tb <= zero_polym;
          wait; -- without wait this process executes in a loop
     end process;

     simulation_check_ntt_results: process
          variable pass : boolean := false;
     begin
          wait until rising_edge(ntt_new_complete_output_ready);
          if (log2_ntt_throughput=log2_num_coefficients) then
               wait for clk_period;
          end if;
          if not (log2_ntt_throughput=log2_num_coefficients) then
               wait until ntt_new_complete_output_ready = '0';
               wait until rising_edge(ntt_new_complete_output_ready);
          end if;

          wait for TIME_DELTA;
          pass := (compare_polyms(ntt_result_buffer_polym, correct_result0, "ntt of test signal 0"));
          wait for clk_period;
          if ntt_new_complete_output_ready = '0' then
               wait until ntt_new_complete_output_ready = '1';
               wait for TIME_DELTA;
          end if;
          pass := (compare_polyms(ntt_result_buffer_polym, correct_result1, "ntt of test signal 1") and pass);
          wait for clk_period;
          if ntt_new_complete_output_ready = '0' then
               wait until ntt_new_complete_output_ready = '1';
               wait for TIME_DELTA;
          end if;
          pass := (compare_polyms(ntt_result_buffer_polym, correct_result2, "ntt of test signal 2") and pass);

          ntt_tests_passed <= pass;
          ntt_tests_done <= '1';
          wait;
     end process;

     simulation_check_intt_results: process
          variable pass : boolean := false;
     begin
          wait until rising_edge(intt_new_complete_output_ready);
          if (log2_ntt_throughput=log2_num_coefficients) then
               wait for clk_period;
          end if;
          if not (log2_ntt_throughput=log2_num_coefficients) then
               wait until intt_new_complete_output_ready = '0';
               wait until rising_edge(intt_new_complete_output_ready);
          end if;

          wait for TIME_DELTA;
          pass := (compare_polyms(intt_result_buffer_polym, test0_input, "intt of test signal 0"));
          wait for clk_period;
          if intt_new_complete_output_ready = '0' then
               wait until intt_new_complete_output_ready = '1';
               wait for TIME_DELTA;
          end if;
          pass := (compare_polyms(intt_result_buffer_polym, test1_input, "intt of test signal 1") and pass);
          wait for clk_period;
          if intt_new_complete_output_ready = '0' then
               wait until intt_new_complete_output_ready = '1';
               wait for TIME_DELTA;
          end if;
          pass := (compare_polyms(intt_result_buffer_polym, test2_input, "intt of test signal 2") and pass);

          intt_tests_passed <= pass;
          intt_tests_done <= '1';
          wait;
     end process;

     resumee: process
     begin
          wait until tests_done = '1';

          assert ntt_tests_passed report "Testbench found errors in ntt" severity error;
          assert intt_tests_passed report "Testbench found errors in intt" severity error;

          assert not (ntt_tests_passed and intt_tests_passed) report "All ntt tests passed" severity note;
          finished <= '1';
          wait;
     end process;

end architecture;
