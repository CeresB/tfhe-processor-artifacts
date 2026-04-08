----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.09.2024 08:38:39
-- Design Name: 
-- Module Name: blind_rotation_iteration_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Testing of the blind_rotation_iteration.
--              We assume, that NTT, INTT and the rotate module already work correctly.
--              So this is about timing values, the decomposition, the ntt_out_buffer and others.
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
     use IEEE.math_real.all;
library work;
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.tfhe_utils.all;
     use work.tfhe_constants.all;
     use work.tb_utils.all;
     use work.math_utils.all;

entity blind_rotation_iteration_tb is
     --  Port ( );
end entity;

architecture Behavioral of blind_rotation_iteration_tb is

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

     signal clk      : std_logic := '0';
     signal reset    : std_logic := '0';
     signal finished : std_logic := '0';
     constant mixed_format : boolean := true;

     signal ext_prod_output_not_ready         : std_logic := '0';
     signal ext_prod_first_result_polym_ready : std_logic := '0';
     signal ext_prod_next_tic_ready           : std_logic := '0';
     --signal input_rlwe             : ciphertext_RLWE;
     signal ext_prod_reset          : std_logic;
     signal ext_prod_reset_buf      : std_logic;
     signal input_bsk               : lwe_n_a_dtype(0 to num_polyms_per_rlwe_ciphertext * decomp_length - 1);
     signal input_rlwe_polyms0      : lwe_n_a_dtype(0 to num_polyms_per_rlwe_ciphertext - 1);
     signal input_rlwe_polyms1      : lwe_n_a_dtype(0 to num_polyms_per_rlwe_ciphertext - 1);
     signal input_rlwe_polyms0_base : lwe_n_a_dtype(0 to num_polyms_per_rlwe_ciphertext - 1);
     signal input_rlwe_polyms1_base : lwe_n_a_dtype(0 to num_polyms_per_rlwe_ciphertext - 1);
     signal correct_result_0        : lwe_n_a_dtype(0 to num_polyms_per_rlwe_ciphertext - 1);
     --signal correct_result_1 : polym_array(0 to num_polyms_per_rlwe_ciphertext - 1);
     signal input_choice : std_logic;
     signal clk_cnt      : integer := 0;

     constant TIME_DELTA       : time    := 10 ns;
     constant clk_period       : time    := TIME_DELTA * 2;
     constant throughput       : integer := pbs_throughput;
     constant next_sample_time : time    := overall_throughput_num_blocks_per_polym * clk_period;

     signal bsk_i_part          : sub_polynom(0 to throughput * decomp_length * num_polyms_per_rlwe_ciphertext - 1);
     signal acc_part            : sub_polynom(0 to throughput - 1);
     signal result_part         : sub_polynom(0 to throughput - 1);
     signal result_polym        : polynom;
     signal result_polym_buffer : polynom;
     signal ai                  : rotate_idx;
     signal ai_array            : polynom := get_test_polym(1, 1, false, pbs_throughput, ntt_num_blocks_per_polym);

     signal in_polym_cnt        : unsigned(0 to get_bit_length(k) - 1);
     signal bsk_polym_coeff_cnt : idx_int;
     signal ai_coeff_idx        : idx_int;
     signal in_coeff_cnt        : idx_int;
     signal ai_blocks_cnt       : integer;
     signal out_coeff_cnt       : idx_int;

     signal scale_factor_0 : integer := 1;
     signal scale_factor_1 : integer := 2;
     signal bsk_factor     : integer := 2;

     -- constant test_: integer := test;
     constant test_ext_prod_latency                            : integer := blind_rot_iter_latency;                      -- v4p ignore w-303
     constant test_ntt_clks_till_first_block_ready             : integer := ntt_clks_till_first_block_ready;             -- v4p ignore w-303
     constant test_ntt_clks_till_out_buffer_ready              : integer := clks_till_ntt_out_buffer_ready;              -- v4p ignore w-303
     constant test_ext_prod_adder_tree_latency                 : integer := blind_rot_iter_adder_tree_latency;           -- v4p ignore w-303
     --constant test_ntt_clks_till_complete_result_done: integer := ntt_clks_till_complete_result_ready;
     constant test_intt_wo_rescaling_clks_till_first_res_ready : integer := intt_wo_rescaling_clks_till_first_res_ready; -- v4p ignore w-303
     constant test_ext_prod_latency_till_elem_wise_mult        : integer := blind_rot_iter_latency_till_elem_wise_mult;  -- v4p ignore w-303
     constant test_ext_prod_latency_till_monomial_mult         : integer := blind_rot_iter_latency_till_monomial_mult;   -- v4p ignore w-303
     constant test_ext_prod_extra_latency                      : integer := blind_rot_iter_extra_latency;                -- v4p ignore w-303
     constant test_ext_prod_latency_till_ready_for_ai          : integer := blind_rot_iter_latency_till_ready_for_ai;    -- v4p ignore w-303
     constant test_rotate_with_buffer_latency                  : integer := rotate_with_buffer_latency;                  -- v4p ignore w-303
     constant test_initial_decomp_delay_first_block            : integer := initial_decomp_delay_first_block;            -- v4p ignore w-303

     constant test_pbs_batchsize      : integer := pbs_batchsize;                                 -- v4p ignore w-303
     constant test_pbs_latency        : integer := bs_clks_till_first_result_block;               -- v4p ignore w-303
     constant test_pbs_acc_buf_length : integer := blind_rot_iter_min_latency_till_monomial_mult; -- v4p ignore w-303
     constant test_pbs_br_latency     : integer := blind_rot_iter_minimum_latency;                -- v4p ignore w-303
     constant test_pbs_extra_latency  : integer := blind_rot_iter_extra_latency;                  -- v4p ignore w-303
     constant test_ntt_num_clks_reset_early: integer := ntt_num_clks_reset_early;                 -- v4p ignore w-303
     constant test_clks_till_ntt_out_buffer_ready: integer := clks_till_ntt_out_buffer_ready; -- v4p ignore w-303

begin
     clk <= not clk after TIME_DELTA when finished /= '1' else '0';

     do_sim: if not dead_simulation generate
          dut: blind_rotation_iteration
               generic map (
                    throughput                     => throughput,
                    decomposition_length           => decomp_length,
                    num_LSBs_to_round              => decomp_num_LSBs_to_round,
                    polyms_per_ciphertext          => num_polyms_per_rlwe_ciphertext,
                    bits_per_slice                 => log2_decomp_base,
                    min_latency_till_monomial_mult => blind_rot_iter_min_latency_till_monomial_mult
               )
               port map (
                    i_clk               => clk,
                    i_reset             => ext_prod_reset_buf,
                    i_ai                => ai,
                    i_acc_part          => acc_part,
                    i_BSK_i_part        => bsk_i_part,
                    o_result            => result_part,
                    o_next_module_reset => ext_prod_output_not_ready
               );
     end generate;

     process (clk)
     begin
          if rising_edge(clk) then
               ext_prod_reset_buf <= ext_prod_reset;

               if reset = '1' then
                    clk_cnt <= 0;
                    in_coeff_cnt <= to_unsigned(0, in_coeff_cnt'length);
                    bsk_polym_coeff_cnt <= to_unsigned(0, bsk_polym_coeff_cnt'length);
                    ai_coeff_idx <= to_unsigned(0, ai_coeff_idx'length);
                    out_coeff_cnt <= to_unsigned(0, out_coeff_cnt'length);
                    in_polym_cnt <= to_unsigned(0, in_polym_cnt'length);
                    input_choice <= '0';
                    ext_prod_first_result_polym_ready <= '0';
                    ext_prod_next_tic_ready <= '0';
                    ai_blocks_cnt <= 0;
               else
                    clk_cnt <= clk_cnt + 1;
                    for i in 0 to acc_part'length - 1 loop
                         if input_choice = '0' then
                              acc_part(i) <= input_rlwe_polyms0(to_integer(in_polym_cnt))(i + to_integer(in_coeff_cnt));
                         else
                              acc_part(i) <= input_rlwe_polyms1(to_integer(in_polym_cnt))(i + to_integer(in_coeff_cnt));
                         end if;
                    end loop;

                    if in_coeff_cnt = to_unsigned(num_coefficients - throughput, in_coeff_cnt'length) then
                         if in_polym_cnt < to_unsigned(k, in_polym_cnt'length) then
                              in_polym_cnt <= in_polym_cnt + to_unsigned(1, in_polym_cnt'length);
                         else
                              in_polym_cnt <= to_unsigned(0, in_polym_cnt'length);
                         end if;
                    end if;
                    in_coeff_cnt <= in_coeff_cnt + to_unsigned(throughput, in_coeff_cnt'length);

                    -- need to change input_choice one clock tic earlier so that acc_part is changed in time
                    if in_polym_cnt = to_unsigned(k, in_polym_cnt'length) and in_coeff_cnt = to_unsigned(num_coefficients - throughput, in_coeff_cnt'length) then
                         input_choice <= not input_choice;
                    end if;

                    if clk_cnt > blind_rot_iter_latency_till_elem_wise_mult - 1 then
                         bsk_polym_coeff_cnt <= bsk_polym_coeff_cnt + to_unsigned(throughput, bsk_polym_coeff_cnt'length);
                         for polym_idx in 0 to input_bsk'length - 1 loop
                              for coeff_idx in 0 to throughput - 1 loop
                                   bsk_i_part(polym_idx * throughput + coeff_idx) <= input_bsk(polym_idx)(coeff_idx + to_integer(bsk_polym_coeff_cnt));
                              end loop;
                         end loop;
                    end if;

                    if clk_cnt > blind_rot_iter_latency_till_ready_for_ai - 1 then
                         ai <= to_rotate_idx(ai_array(to_integer(ai_coeff_idx)));
                         -- ai is valid per input rlwe ciphertext, so change it only when a new ciphertext starts
                         if ai_blocks_cnt < num_polyms_per_rlwe_ciphertext * intt_num_blocks_per_polym - 1 then
                              ai_blocks_cnt <= ai_blocks_cnt + 1;
                         else
                              ai_blocks_cnt <= 0;
                              ai_coeff_idx <= ai_coeff_idx + to_unsigned(1, ai_coeff_idx'length);
                         end if;
                    end if;

                    if ext_prod_output_not_ready = '0' and clk_cnt >= blind_rot_iter_latency - 1 then
                         for i in 0 to result_part'length - 1 loop
                              result_polym(i + to_integer(out_coeff_cnt)) <= result_part(i);
                         end loop;
                         out_coeff_cnt <= out_coeff_cnt + to_unsigned(throughput, out_coeff_cnt'length);

                         if out_coeff_cnt = to_unsigned(num_coefficients - throughput, out_coeff_cnt'length) then
                              ext_prod_next_tic_ready <= '1';
                         else
                              ext_prod_next_tic_ready <= '0';
                         end if;

                         if ext_prod_next_tic_ready = '1' then
                              result_polym_buffer <= result_polym;
                              ext_prod_first_result_polym_ready <= '1';
                         end if;

                    else
                         out_coeff_cnt <= to_unsigned(0, out_coeff_cnt'length);
                         ext_prod_next_tic_ready <= '0';
                    end if;

               end if;

          end if;
     end process;

     simulation: process
          variable pass    : boolean;
          variable raw_val : integer;
     begin
          reset <= '1';
          ext_prod_reset <= '1';
          -- all scaled by (2 ** log2_decomp_base) so that the result of the decomposition is the actual number we want
          --input_rlwe.a(i);
          for i in 0 to k - 1 loop
               input_rlwe_polyms0_base(i) <= get_test_polym(scale_factor_0 * (2 ** log2_decomp_base), 0, mixed_format, pbs_throughput, ntt_num_blocks_per_polym);
               input_rlwe_polyms1_base(i) <= get_test_polym(i * scale_factor_1 * (2 ** log2_decomp_base),(2 ** log2_decomp_base), mixed_format, pbs_throughput, ntt_num_blocks_per_polym);
               correct_result_0(i) <= get_test_polym(0, 0, false, pbs_throughput, ntt_num_blocks_per_polym);
          end loop;
          --input_rlwe.b;
          input_rlwe_polyms0_base(input_rlwe_polyms0'length - 1) <= get_test_polym(scale_factor_0 * (2 ** log2_decomp_base), 0, mixed_format, pbs_throughput, ntt_num_blocks_per_polym);
          correct_result_0(correct_result_0'length - 1) <= get_test_polym(0, 0, false, pbs_throughput, ntt_num_blocks_per_polym);
          input_rlwe_polyms1_base(input_rlwe_polyms1'length - 1) <= get_test_polym(k * scale_factor_1 * (2 ** log2_decomp_base),(2 ** log2_decomp_base), mixed_format, pbs_throughput, ntt_num_blocks_per_polym);

          for i in 0 to input_bsk'length - 1 loop
               input_bsk(i)(0) <= to_synth_uint(bsk_factor);
               for j in 1 to input_bsk(0)'length - 1 loop
                    input_bsk(i)(j) <= to_synth_uint(0);
               end loop;
          end loop;

          wait for TIME_DELTA;

          -- signal with noise that the decomposition should round away
          for i in 0 to input_rlwe_polyms0'length - 1 loop
               for coeff_idx in 0 to input_rlwe_polyms0(0)'length - 1 loop
                    input_rlwe_polyms0(i)(coeff_idx) <= input_rlwe_polyms0_base(i)(coeff_idx);-- + to_synth_uint(2 ** (log2_decomp_base - 1) - 1); --input_rlwe.a(i), want no carry through rounding here
                    input_rlwe_polyms1(i)(coeff_idx) <= input_rlwe_polyms1_base(i)(coeff_idx);-- + to_synth_uint(2 ** log2_decomp_base - 1); --input_rlwe.a(i);
               end loop;
          end loop;

          -- input_rlwe_polyms0 consists of multiple polynoms where all coefficients have the same number
          -- after the decomposition only one of the l-polynoms has coefficients different from 0 and these coefficients are all 1
          -- the ntt result is then only zeros but the first coefficient which is the sum of the 1's = old_value
          -- HOWEVER THIS IS ONLY THE CASE FOR NON-NEGACYCLIC NTTs!
          -- since all coefficients in bki are 0 but one its like a multiplication of two constants
          -- accumulating the k+1 polynoms of this form yields a polynom with one coefficient different from 0 with the value old_value*(k+1)*constant_value
          -- the intt of that is a polynom where all coefficients have the value old_value*(k+1)*constant_value
          -- shifting this by a_i is easy to compute. Then substracting the polynom leaves only the value that was shifted over the border
          -- everything else is 0
          -- and then we add the original input polynom
          raw_val := to_integer(to_synth_uint(num_coefficients * (k + 1) * bsk_factor * scale_factor_0) mod tfhe_modulus); -- 32
          for k_idx in 0 to correct_result_0'length - 1 loop
               if (ai_array(0) mod to_synth_uint(2 * num_coefficients)) > to_synth_uint(num_coefficients) then
                    correct_result_0(k_idx)((num_coefficients - to_integer(ai_array(0))) mod num_coefficients) <= to_synth_uint(raw_val - 1 * raw_val) mod tfhe_modulus;
               elsif (ai_array(0) mod to_synth_uint(2 * num_coefficients)) < to_synth_uint(num_coefficients) then
                    correct_result_0(k_idx)((num_coefficients - to_integer(ai_array(0))) mod num_coefficients) <= tfhe_modulus - to_synth_uint(2 * raw_val); -- rewrite of -raw_val-1*raw_val mod tfhe_modulus
               end if;
          end loop;

          wait for TIME_DELTA;

          for k_idx in 0 to input_rlwe_polyms0_base'length - 1 loop
               for coeff_idx in 0 to input_rlwe_polyms0_base(0)'length - 1 loop
                    correct_result_0(k_idx)(coeff_idx) <= (correct_result_0(k_idx)(coeff_idx) + input_rlwe_polyms0(k_idx)(coeff_idx)) mod tfhe_modulus;
               end loop;
          end loop;

          wait for TIME_DELTA;

          if mixed_format then
               for i in 0 to correct_result_0'length - 1 loop
                    correct_result_0(i) <= to_ntt_mixed_format(correct_result_0(i), ntt_num_blocks_per_polym, pbs_throughput);
               end loop;
          end if;

          -- handle early reset for the module
          ext_prod_reset <= '0';
          reset <= '0';

          wait until ext_prod_first_result_polym_ready = '1';

          wait for TIME_DELTA; -- so that there can be no confusion when reading the output signal

          if not negacyclic then
               pass := true;
               for i in 0 to correct_result_0'length - 1 loop
                    pass := (compare_polyms(result_polym_buffer, correct_result_0(i), "singular blind rotation of test signal 0") and pass);
                    wait for next_sample_time;
               end loop;
          else
               report "No automatic check for negacyclic NTT - check correctness manually!" severity warning;
          end if;

          wait for next_sample_time; -- just to see if values go back to 0 as expected

          assert not pass report "All tests passed succesfully. Keep in mind that these are superfical tests! Verify more complex settings manually!" severity note;
          assert pass report "Testbench found errors" severity error;
          finished <= '1';
          wait;
     end process;

end architecture;
