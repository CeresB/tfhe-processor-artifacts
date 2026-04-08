----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.09.2024 08:38:39
-- Design Name: 
-- Module Name: pbs_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Testing of the pbs. This is not for computation correctness testing but for manual testing
--             to see if the delays are set correctly.
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
     use IEEE.math_real.all;
library work;
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.tfhe_utils.all;
     use work.tfhe_constants.all;
     use work.tb_utils.all;
     use work.math_utils.all;
     use work.processor_utils.all;

entity pbs_tb is
     --  Port ( );
end entity;

architecture Behavioral of pbs_tb is

     component pbs is
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
     end component;

     signal clk      : std_logic := '0';
     signal reset    : std_logic := '0';
     signal finished : std_logic := '0';

     constant TIME_DELTA       : time    := 10 ns;
     constant clk_period       : time    := TIME_DELTA * 2;
     constant throughput       : integer := pbs_throughput;
     constant next_sample_time : time    := overall_throughput_num_blocks_per_polym * clk_period;

     signal pbs_first_result_ready : std_logic := '0';
     signal clk_cnt                : integer   := 0;
     signal input_choice           : std_logic;
     signal input_bsk              : lwe_n_a_dtype(0 to num_polyms_per_rlwe_ciphertext * decomp_length - 1);
     signal ai_array               : rotate_idx_array(0 to k_lwe - 1);

     signal pbs_output_not_ready  : std_logic := '0';
     signal pbs_reset             : std_logic;
     signal pbs_lwe_b             : rotate_idx;
     signal bsk_i_part            : sub_polynom(0 to throughput * decomp_length * num_polyms_per_rlwe_ciphertext - 1);
     signal pbs_result            : sub_polynom(0 to throughput - 1); -- v4p ignore w-303
     signal ai                    : rotate_idx;
     -- signal sample_extract_idx    : idx_int;
     signal pbs_lookup_table_part : sub_polynom(0 to throughput - 1);

     signal in_polym_cnt        : unsigned(0 to get_bit_length(k) - 1);
     signal bsk_polym_coeff_cnt : idx_int;
     signal ai_coeff_idx        : unsigned(0 to get_bit_length(k_lwe) - 1);
     signal in_coeff_cnt        : idx_int;
     signal ai_blocks_cnt       : integer;

     signal bsk_factor        : integer := 2;
     signal lwe_test_cipher_0 : LWE_memory;
     signal lwe_test_cipher_1 : LWE_memory;

     -- constant test_: integer := test;
     -- constant test_external_product_latency: integer := ext_prod_latency;
     -- constant test_blind_rotation_latency: integer := blind_rotation_latency;
     -- constant test_ext_prod_num_ciphertexts_in_pipeline: integer := ext_prod_num_ciphertexts_in_pipeline;
     -- constant test_ext_prod_extra_latency: integer := ext_prod_extra_latency;
     -- constant test_bs_init_latency: integer := bs_init_latency;
     -- constant test_sample_extract_latency: integer := sample_extract_latency;
     -- constant test_bs_clks_till_first_result_block: integer := bs_clks_till_first_result_block;

begin
     clk <= not clk after TIME_DELTA when finished /= '1' else '0';

     dut: pbs
          generic map (
               throughput                     => throughput,
               decomposition_length           => decomp_length,
               num_LSBs_to_round              => decomp_num_LSBs_to_round,
               polyms_per_ciphertext          => num_polyms_per_rlwe_ciphertext,
               bits_per_slice                 => log2_decomp_base,
               min_latency_till_monomial_mult => blind_rot_iter_min_latency_till_monomial_mult,
               num_iterations                 => k_lwe
          )
          port map (
               i_clk                => clk,
               i_reset              => pbs_reset,
               i_lookup_table_part  => pbs_lookup_table_part,
               i_lwe_b              => pbs_lwe_b,
               i_lwe_ai             => ai,
               -- i_sample_extract_idx => sample_extract_idx,
               -- o_sample_extract_idx => open,
               i_BSK_i_part         => bsk_i_part,
               o_result             => pbs_result,
               o_next_module_reset  => pbs_output_not_ready
          );

     process (clk)
     begin
          if rising_edge(clk) then
               if reset = '1' then
                    clk_cnt <= 0;
                    in_coeff_cnt <= to_unsigned(0, in_coeff_cnt'length);
                    bsk_polym_coeff_cnt <= to_unsigned(0, bsk_polym_coeff_cnt'length);
                    ai_coeff_idx <= to_unsigned(0, ai_coeff_idx'length);
                    in_polym_cnt <= to_unsigned(0, in_polym_cnt'length);
                    input_choice <= '0';
                    pbs_reset <= '1';
                    pbs_first_result_ready <= '0';
                    ai_blocks_cnt <= 0;

                    -- pbs_lwe_b <= lwe_test_cipher_0.lwe.b;
                    -- ai_array <= lwe_test_cipher_0.lwe.a;
                    -- pbs_lwe_idx <= lwe_test_cipher_0.adr;
               else
                    clk_cnt <= clk_cnt + 1;
                    pbs_reset <= '0';

                    for i in 0 to pbs_lookup_table_part'length - 1 loop
                         pbs_lookup_table_part(i) <= pbs_default_lookuptable(to_integer(in_coeff_cnt) + i);
                    end loop;

                    if in_coeff_cnt = to_unsigned(num_coefficients - throughput, in_coeff_cnt'length) then
                         if in_polym_cnt < to_unsigned(k, in_polym_cnt'length) then
                              in_polym_cnt <= in_polym_cnt + to_unsigned(1, in_polym_cnt'length);
                         else
                              in_polym_cnt <= to_unsigned(0, in_polym_cnt'length);
                         end if;
                    end if;
                    in_coeff_cnt <= in_coeff_cnt + to_unsigned(throughput, in_coeff_cnt'length);
                    if in_polym_cnt = to_unsigned(0, in_polym_cnt'length) and in_coeff_cnt = to_unsigned(0, in_coeff_cnt'length) then
                         -- sample_extract_idx <= sample_extract_default_sample_extract_idx;
                         if input_choice = '0' then
                              pbs_lwe_b <= to_rotate_idx(lwe_test_cipher_0.lwe.b);
                              for i in 0 to ai_array'length-1 loop
                                   ai_array(i) <= to_rotate_idx(lwe_test_cipher_0.lwe.a(i));
                              end loop;
                         else
                              pbs_lwe_b <= to_rotate_idx(lwe_test_cipher_1.lwe.b);
                              for i in 0 to ai_array'length-1 loop
                                   ai_array(i) <= to_rotate_idx(lwe_test_cipher_1.lwe.a(i));
                              end loop;
                         end if;
                         input_choice <= not input_choice;
                    end if;

                    for polym_idx in 0 to input_bsk'length - 1 loop
                         for coeff_idx in 0 to throughput - 1 loop
                              bsk_i_part(polym_idx * throughput + coeff_idx) <= input_bsk(polym_idx)(coeff_idx + to_integer(bsk_polym_coeff_cnt));
                         end loop;
                    end loop;

                    if clk_cnt > blind_rot_iter_latency_till_elem_wise_mult + bs_init_latency - 1 then
                         bsk_polym_coeff_cnt <= bsk_polym_coeff_cnt + to_unsigned(throughput, bsk_polym_coeff_cnt'length);
                    end if;

                    if clk_cnt > blind_rot_iter_latency_till_monomial_mult + bs_init_latency - 1 then
                         ai <= ai_array(to_integer(ai_coeff_idx));
                         -- ai is valid for one iteration
                         if ai_blocks_cnt < blind_rot_iter_latency - 1 then
                              ai_blocks_cnt <= ai_blocks_cnt + 1;
                         else
                              ai_blocks_cnt <= 0;

                              if ai_coeff_idx < to_unsigned(k_lwe - 1, ai_coeff_idx'length) then
                                   ai_coeff_idx <= ai_coeff_idx + to_unsigned(1, ai_coeff_idx'length);
                              else
                                   ai_coeff_idx <= to_unsigned(0, ai_coeff_idx'length);
                              end if;
                         end if;
                    end if;

                    if pbs_output_not_ready = '0' and clk_cnt > bs_clks_till_first_result_block + 1 - 1 then
                         pbs_first_result_ready <= '1';
                    end if;
               end if;
          end if;
     end process;

     simulation: process
     begin
          reset <= '1';
          lwe_test_cipher_0 <= get_test_lwe_memory(100 + 2 ** (log2_decomp_base + 1), 0, 3, 1);
          lwe_test_cipher_1 <= get_test_lwe_memory(475 + 10 * 2 ** (log2_decomp_base + 1), 2 ** (log2_decomp_base + 1), 10 * 2 ** (log2_decomp_base + 1) - 1, 2);

          input_bsk <= get_test_BSKi(0, bsk_factor);

          wait for clk_period;
          wait for clk_period;
          wait for clk_period;
          reset <= '0';

          report "Waiting too long? Check k_lwe parameter setting! It is set to " & integer'image(k_lwe) severity note;
          wait until pbs_first_result_ready = '1';

          wait for TIME_DELTA; -- so that there can be no confusion when reading the output signal
          wait for next_sample_time;
          wait for next_sample_time;
          wait for next_sample_time;

          report "Check correctness manually!" severity warning;
          finished <= '1';
          wait;
     end process;

end architecture;
