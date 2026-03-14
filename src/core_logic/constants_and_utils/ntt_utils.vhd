----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ntt_utils - package
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: Mainly initialization-related utils for the NTT. The logic for the twisting factors and other
--             NTT-specific precomputed values are here. This file also contains NTT-specific datatypes and delay calculations.
--             Important: call none of these functions during runtime because that is inefficient!
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
     use work.math_utils.all;
     use work.ntt_prime_list_pair.all;

package ntt_utils is
     -- INFO: you find the coefficient-size setting in constants_utils.vhd

     -- values that are inferred - DO NOT CHANGE ANYTHING BELOW THIS LINE
     -- All functions in this file are only for computations during initialization
     -- cannot do 2 dimensional subtable as throughput dictates the 2. dimension and then we would need to duplicate the whole
     -- fully parallel codebase for each choice of throughput
     type tw_subtable_as_array is array (natural range <>) of synthesiseable_uint;
     type tw_subtable_int_as_array is array (natural range <>) of integer;

     constant table_size_as_array : integer := log2_num_coefficients * (2 ** log2_num_coefficients / samples_per_butterfly); -- necessary because "record elements cannot be unconstrained"
     type ntt_params_with_precomputed_values is record
          twiddle_factor_table        : tw_subtable_as_array(0 to table_size_as_array - 1);
          invers_twiddle_factor_table : tw_subtable_as_array(0 to table_size_as_array - 1);
          twiddle_indices             : index_2d_array(0 to table_size_as_array - 1);
          prime                       : synthesiseable_uint;
          negacyclic                  : boolean;
          log2_num_coeffs             : integer;
          omega                       : synthesiseable_uint; -- if negacyclic make sure this is omega_2n
          omega_invers                : synthesiseable_uint; -- if negacyclic make sure this is omega_2n_invers
          n_invers                    : synthesiseable_uint;
     end record;

     type ntt_params_with_precomputed_values_short is record -- ditches invers/non-invers and keeps only one value
          twiddle_factor_table : tw_subtable_as_array(0 to table_size_as_array - 1);
          twiddle_indices      : index_2d_array(0 to table_size_as_array - 1);
          prime                : synthesiseable_uint;
          negacyclic           : boolean;
          invers               : boolean;
          total_num_stages     : integer;
          omega                : synthesiseable_uint;
          n_invers             : synthesiseable_uint;
     end record;

     type ntt_twiddle_values_to_index is record
          twiddle_factor_table : tw_subtable_as_array(0 to table_size_as_array - 1);
          -- put precomputed values for barett or similar here
     end record;

     function init_twiddle_exponents(
          log2_num_coeffs : integer;
          for_negacyclic  : boolean
     ) return tw_subtable_int_as_array;

     function init_twiddle_factors(
          prime              : synthesiseable_uint;
          omega              : synthesiseable_uint;
          tw_exponents_table : tw_subtable_int_as_array;
          ntt_size           : integer
     ) return tw_subtable_as_array;

     function get_idx_column_for_stage(
          table           : index_2d_array; -- log2_num_coeffs*total_num_butterflies_per_stage
          throughput      : integer;
          log2_num_coeffs : integer;
          delay           : integer
     ) return index_2d_array;

     function get_idx_columns_for_fully_parallel_stages(
          invers                    : boolean;
          table                     : index_2d_array;
          num_stages_fully_parallel : integer;
          log2_num_coeffs           : integer
     ) return index_2d_array;

     -- To each twiddle factors can belong a precomputed value.
     -- We pass on the index of the twiddle factor, as this avoids passing on both
     -- twiddle factor and the precomputed value. Otherwise if we chose non-precomputed-value-reduction the
     -- precomputed value would still be passed on and potentionally consume FPGA ressources.
     function init_twiddle_factor_indices(
          log2_num_coeffs : integer
     ) return index_2d_array;

     function tw_idx_column_to_tw_factors(
          tw_idx_column   : index_2d_array;
          tw_factor_table : tw_subtable_as_array;
          interweave      : boolean;
          throughput      : integer
     ) return sub_polynom;

     function tw_idx_columns_to_tw_factors(
          log2_num_coeffs : integer;
          tw_idx_columns  : index_2d_array;
          tw_factor_table : tw_subtable_as_array;
          interweave      : boolean;
          throughput      : integer
     ) return sub_polynom;

     function get_ntt_latency(
          log2_input_size    : integer;
          log2_throughput    : integer;
          negacyclic         : boolean;
          intt               : boolean;
          with_intt_recaling : boolean;
          with_format_switch : boolean
     ) return integer;

     function get_ntt_params(
          log2_num_coeffs : integer;
          negacyclic      : boolean;
          prime           : synthesiseable_uint;
          omega           : synthesiseable_uint;
          omega_invers    : synthesiseable_uint;
          omega_2n        : synthesiseable_uint;
          omega_2n_invers : synthesiseable_uint;
          n_invers        : synthesiseable_uint
     ) return ntt_params_with_precomputed_values;

     function chose_ntt_params(
          ntt_params : ntt_params_with_precomputed_values;
          invers     : boolean
     ) return ntt_params_with_precomputed_values_short;

     function get_tw_values_to_index(
          ntt_params_short : ntt_params_with_precomputed_values_short
     ) return ntt_twiddle_values_to_index;

     function zero_indices(
          polym : sub_polynom
     ) return sub_polynom;

     function get_ntt_prime_list_pair return prime_list_pair;

     constant ntt_prime_list_pair : prime_list_pair     := get_ntt_prime_list_pair; -- params_prime7681, params_solinas_prime
     constant ntt_prime           : synthesiseable_uint := (ntt_prime_list_pair.prime);
     constant ntt_n_invers        : synthesiseable_uint := (ntt_prime_list_pair.list(log2_num_coefficients).n_invers);

     constant omega           : synthesiseable_uint := ntt_prime_list_pair.list(log2_num_coefficients).omega;
     constant omega_invers    : synthesiseable_uint := ntt_prime_list_pair.list(log2_num_coefficients).omega_invers;
     constant omega_2n        : synthesiseable_uint := ntt_prime_list_pair.list(log2_num_coefficients + 1).omega;
     constant omega_2n_invers : synthesiseable_uint := ntt_prime_list_pair.list(log2_num_coefficients + 1).omega_invers;

     constant ntt_params : ntt_params_with_precomputed_values := get_ntt_params(log2_num_coefficients, negacyclic, ntt_prime, omega, omega_invers, omega_2n, omega_2n_invers, ntt_n_invers);

     -- reducing a 1 bit overflow by substracting the prime can be modeled via an addition. Advantage: the bit widht of the addition is smaller
     -- e.g. overflow num = 1 0...0 + num_without_overflow_bit | mod p -->  overflow_reduced_num + num_without_overflow_bit | this cannot have a carry when the biggest num to reduce is 2*(p-1)
     constant overflow_reduced: synthesiseable_uint_extended := shift_left(to_unsigned(1, ntt_prime'length+1),ntt_prime'length) - ntt_prime; -- first bit is always 0
     constant overflow_bit_width: integer := get_bit_length(overflow_reduced(1 to overflow_reduced'length-1));
     constant overflow_reduced_num: unsigned(0 to overflow_bit_width-1) := resize(overflow_reduced,overflow_bit_width);

end package;

package body ntt_utils is

     function get_ntt_prime_list_pair return prime_list_pair is
          variable res : prime_list_pair;
     begin
          -- if you chose ntt_modulo_solution_solinas in constants_utils you MUST set ntt_params to params_solinas_prime! The solinas modulo solution only works with params_solinas_prime!
          -- --> the debug_mode flag handles the modulo solution as well, no worries
          if debug_mode then
               res := params_prime7681;
          else
               res := params_solinas_prime;
          end if;
          return res;
     end function;

     function get_ntt_params(
               log2_num_coeffs : integer;
               negacyclic      : boolean;
               prime           : synthesiseable_uint;
               omega           : synthesiseable_uint;
               omega_invers    : synthesiseable_uint;
               omega_2n        : synthesiseable_uint;
               omega_2n_invers : synthesiseable_uint;
               n_invers        : synthesiseable_uint
          ) return ntt_params_with_precomputed_values is
          constant total_num_bfs_per_stage : integer := 2 ** log2_num_coeffs / samples_per_butterfly;
          variable res          : ntt_params_with_precomputed_values;
          variable tw_exp_table : tw_subtable_int_as_array(0 to log2_num_coeffs * total_num_bfs_per_stage - 1);
     begin
          res.prime := prime;
          res.negacyclic := negacyclic;
          res.log2_num_coeffs := log2_num_coeffs;
          res.n_invers := n_invers;
          if negacyclic then
               res.omega := omega_2n;
               res.omega_invers := omega_2n_invers;
          else
               res.omega := omega;
               res.omega_invers := omega_invers;
          end if;
          if not dead_simulation then
               tw_exp_table := init_twiddle_exponents(log2_num_coeffs, negacyclic);
               res.twiddle_factor_table := init_twiddle_factors(prime, res.omega, tw_exp_table, 2 ** log2_num_coeffs);
               res.invers_twiddle_factor_table := init_twiddle_factors(prime, res.omega_invers, tw_exp_table, 2 ** log2_num_coeffs);
               res.twiddle_indices := init_twiddle_factor_indices(log2_num_coeffs);
          end if;
          return res;
     end function;

     function chose_ntt_params(
               ntt_params : ntt_params_with_precomputed_values;
               invers     : boolean
          ) return ntt_params_with_precomputed_values_short is
          variable res : ntt_params_with_precomputed_values_short;
     begin
          res.invers := invers;
          res.total_num_stages := ntt_params.log2_num_coeffs;
          res.negacyclic := ntt_params.negacyclic;
          res.prime := ntt_params.prime;
          res.n_invers := ntt_params.n_invers;
          res.twiddle_indices := ntt_params.twiddle_indices;
          if invers then
               res.omega := ntt_params.omega_invers;
               res.twiddle_factor_table := ntt_params.invers_twiddle_factor_table;
          else
               res.omega := ntt_params.omega;
               res.twiddle_factor_table := ntt_params.twiddle_factor_table;
          end if;
          return res;
     end function;

     function get_tw_values_to_index(
               ntt_params_short : ntt_params_with_precomputed_values_short
          ) return ntt_twiddle_values_to_index is
          variable res : ntt_twiddle_values_to_index;
     begin
          res.twiddle_factor_table := ntt_params_short.twiddle_factor_table;
          -- can add precomputed values here
          return res;
     end function;

     function get_idx_columns_for_fully_parallel_stages(-- relevant for sequential ntt
               invers                    : boolean;
               table                     : index_2d_array; -- log2_num_coeffs*total_num_butterflies_per_stage
               num_stages_fully_parallel : integer;
               log2_num_coeffs           : integer
          ) return index_2d_array is
          constant total_num_bfs_per_stage       : integer := 2 ** log2_num_coeffs / samples_per_butterfly;
          constant num_non_fully_parallel_stages : integer := log2_num_coeffs - num_stages_fully_parallel;
          constant throughput                    : integer := 2 ** num_stages_fully_parallel;
          variable correct_columns : index_2d_array(0 to num_stages_fully_parallel * total_num_bfs_per_stage - 1);
          variable twiddle_column  : index_2d_array(0 to total_num_bfs_per_stage - 1);
          variable delay           : integer;
     begin
          -- extract the twiddle columns which are used by the fully parallel stage
          for i in 0 to num_stages_fully_parallel - 1 loop
               for j in 0 to total_num_bfs_per_stage - 1 loop
                    correct_columns(i * total_num_bfs_per_stage + j) := table((i + num_non_fully_parallel_stages) * total_num_bfs_per_stage + j);
               end loop;
          end loop;
          -- here we do the same that we do in the single stages, just for multiple twiddle-columns at once
          for stage_idx in 0 to num_stages_fully_parallel - 1 loop
               twiddle_column := correct_columns(stage_idx * total_num_bfs_per_stage to (stage_idx + 1) * total_num_bfs_per_stage - 1);
               -- stages are connected reversed for intt --> need to apply twiddle delay reversed as well
               -- and intt needs to respect the gentleman_sande_twiddle_offset
               delay := boolean'pos(invers) * (gentleman_sande_twiddle_offset) + 1 * boolean'pos(ntt_butterfly_in_bufs);
               correct_columns(stage_idx * total_num_bfs_per_stage to (stage_idx + 1) * total_num_bfs_per_stage - 1) := get_idx_column_for_stage(twiddle_column, throughput, log2_num_coeffs, delay);
          end loop;
          -- note: this is for the fully parallel stages of a sequential ntt. In this setting there cannot be a twiddle-column with no multiplication
          return correct_columns;
     end function;

     function get_idx_column_for_stage(
               table           : index_2d_array; -- log2_num_coeffs*total_num_butterflies_per_stage
               throughput      : integer;
               log2_num_coeffs : integer;
               delay           : integer
          ) return index_2d_array is
          constant total_num_bfs_per_stage  : integer := 2 ** log2_num_coeffs / samples_per_butterfly;
          constant num_butterflys_per_block : integer := throughput / samples_per_butterfly;
          constant twiddles_per_butterfly   : integer := total_num_bfs_per_stage / num_butterflys_per_block;
          constant total_num_blocks         : integer := 2 ** log2_num_coeffs / throughput;
          variable twiddle_column    : index_2d_array(0 to total_num_bfs_per_stage - 1);
          variable twiddle_block     : index_2d_array(0 to twiddles_per_butterfly - 1);
          variable twiddle_block_new : index_2d_array(0 to twiddles_per_butterfly - 1);
     begin
          twiddle_column := table;
          -- twiddle column looks like this: bf0_0_tw, bf1_0_tw, bf2_0_tw, ... bf0_1_tw, bf1_1_tw, bf2_1_tw, ...
          -- need: bf0_0_tw, bf0_1_tw, bf0_2_tw, ...
          for bf_idx in 0 to num_butterflys_per_block - 1 loop
               for block_idx in 0 to total_num_blocks - 1 loop
                    twiddle_block(block_idx) := twiddle_column(block_idx * num_butterflys_per_block + bf_idx);
               end loop;
               -- now shift inside the twiddle block
               for j in 0 to twiddle_block'length - 1 loop
                    twiddle_block_new(j) := twiddle_block((j - delay) mod twiddle_block'length);
               end loop;
               -- writeback
               for block_idx in 0 to total_num_blocks - 1 loop
                    twiddle_column(block_idx * num_butterflys_per_block + bf_idx) := twiddle_block_new(block_idx);
               end loop;
          end loop;
          return twiddle_column;
     end function;

     function init_twiddle_factor_indices(
               log2_num_coeffs : integer
          ) return index_2d_array is
          constant total_num_bfs_per_stage : integer := 2 ** log2_num_coeffs / samples_per_butterfly;
          variable table : index_2d_array(0 to log2_num_coeffs * total_num_bfs_per_stage - 1);
          variable temp  : index_2d;
     begin
          for i in 0 to log2_num_coeffs - 1 loop
               for j in 0 to total_num_bfs_per_stage - 1 loop
                    temp.col := i;
                    temp.row := j;
                    table(i * total_num_bfs_per_stage + j) := temp;
               end loop;
          end loop;

          return table;
     end function;

     function init_twiddle_exponents(
               log2_num_coeffs : integer;
               for_negacyclic  : boolean
          ) return tw_subtable_int_as_array is
          constant total_num_bfs_per_stage : integer := 2 ** log2_num_coeffs / samples_per_butterfly;
          variable table        : tw_subtable_int_as_array(0 to log2_num_coeffs * total_num_bfs_per_stage - 1);
          variable idx_reversed : integer;
          variable temp         : std_ulogic_vector(0 to log2_num_coeffs - 2);
          variable i            : integer;
     begin
          for stage_idx in 0 to log2_num_coeffs - 1 loop
               -- we only need every 2**idx row of the twiddle matrix
               i := 2 ** (stage_idx);
               for j in 0 to total_num_bfs_per_stage - 1 loop
                    -- bit-reverse index j
                    temp := std_ulogic_vector(to_unsigned(j, log2_num_coeffs - 1));
                    idx_reversed := to_integer(unsigned(reverse_vector(temp)));
                    if for_negacyclic then
                         table((log2_num_coeffs - 1 - stage_idx) * total_num_bfs_per_stage + idx_reversed) := ((i * (2 * j + 1)) mod (2 ** log2_num_coeffs));
                    else
                         table((log2_num_coeffs - 1 - stage_idx) * total_num_bfs_per_stage + idx_reversed) := ((i * j) mod ((2 ** log2_num_coeffs) / 2));
                    end if;
               end loop;
          end loop;
          return table;
     end function;

     function init_twiddle_factors(
               prime              : synthesiseable_uint;
               omega              : synthesiseable_uint;
               tw_exponents_table : tw_subtable_int_as_array;
               ntt_size           : integer
          ) return tw_subtable_as_array is
          variable table                          : tw_subtable_as_array(0 to tw_exponents_table'length - 1);
          variable tw_exponent_to_tw_factor_array : synth_uint_vector(0 to ntt_size - 1);
          constant ntt_size_half : integer := ntt_size / 2;
          constant num_loops     : integer := tw_exponents_table'length / ntt_size_half; -- = num ntt stages
     begin
          -- we need all twiddle-exponents to be turned into twiddle-factors
          -- this slows down the elaboration step. Keeping the computing minimal by
          -- computing the twiddle-factor to every twiddle exponent and then looking it up
          tw_exponent_to_tw_factor_array(0) := to_unsigned(1, tw_exponent_to_tw_factor_array(0)'length);
          for i in 1 to tw_exponent_to_tw_factor_array'length - 1 loop
               tw_exponent_to_tw_factor_array(i) := a_b_mod_p(omega, tw_exponent_to_tw_factor_array(i - 1), prime);
          end loop;
          -- -- vivado annoys with Synth 8-403: loop limit exceeded
          -- for i in 0 to tw_exponents_table'length - 1 loop
          --      table(i) := tw_exponent_to_tw_factor_array(tw_exponents_table(i));
          -- end loop;
          -- so we unroll the loop
          for j in 0 to num_loops - 1 loop
               for i in 0 to ntt_size_half - 1 loop
                    table(j * ntt_size_half + i) := tw_exponent_to_tw_factor_array(tw_exponents_table(j * ntt_size_half + i));
               end loop;
          end loop;

          -- -- a lot slower: transform every exponent to twiddle factor each time from scratch
          -- for i in 0 to tw_exponents_table'length - 1 loop
          --      table(i) := anti_overflow_exp_mod_p(omega, tw_exponents_table(i), prime);
          -- end loop;
          return table;
     end function;

     function tw_idx_column_to_tw_factors(
               tw_idx_column   : index_2d_array;
               tw_factor_table : tw_subtable_as_array;
               interweave      : boolean;
               throughput      : integer
          ) return sub_polynom is
          variable res        : sub_polynom(0 to tw_idx_column'length - 1);
          variable res_weaved : sub_polynom(0 to tw_idx_column'length - 1);
          constant num_butterflys : integer := throughput / samples_per_butterfly;
          constant clks_per_polym : integer := tw_idx_column'length / num_butterflys;
     begin

          for i in 0 to tw_idx_column'length - 1 loop
               res(i) := tw_factor_table((tw_idx_column(i).col) * tw_idx_column'length + tw_idx_column(i).row);
          end loop;

          -- interweave array, s.t. all twiddles used by the n-th butterfly are next to each other
          if interweave then
               for i in 0 to num_butterflys - 1 loop
                    for j in 0 to clks_per_polym - 1 loop
                         res_weaved(i * clks_per_polym + j) := res(i + j * num_butterflys);
                    end loop;
               end loop;
          else
               res_weaved := res;
          end if;

          return res_weaved;
     end function;

     function tw_idx_columns_to_tw_factors(-- for fully parallel in sequential ntt
               log2_num_coeffs : integer;
               tw_idx_columns  : index_2d_array;
               tw_factor_table : tw_subtable_as_array;
               interweave      : boolean;
               throughput      : integer
          ) return sub_polynom is
          constant total_num_bfs_per_stage : integer := 2 ** log2_num_coeffs / samples_per_butterfly;
          constant num_stages              : integer := tw_idx_columns'length / total_num_bfs_per_stage;
          variable tw_idx_column : index_2d_array(0 to total_num_bfs_per_stage - 1);
          variable res           : sub_polynom(0 to tw_idx_columns'length - 1);
     begin
          for col_idx in 0 to num_stages - 1 loop
               tw_idx_column := tw_idx_columns(col_idx * total_num_bfs_per_stage to (col_idx + 1) * total_num_bfs_per_stage - 1);
               res(col_idx * total_num_bfs_per_stage to (col_idx + 1) * total_num_bfs_per_stage - 1) := tw_idx_column_to_tw_factors(tw_idx_column, tw_factor_table, interweave, throughput);
          end loop;
          -- need to respect the delay between fully-parallel-stages - but that is already dealt with through shifting tw_idx_columns
          return res;
     end function;

     function get_ntt_latency(
               log2_input_size    : integer;
               log2_throughput    : integer;
               negacyclic         : boolean;
               intt               : boolean;
               with_intt_recaling : boolean;
               with_format_switch : boolean
          ) return integer is
          variable res                             : integer;
          variable ntt_block_delay                 : integer;
          variable ntt_clks_till_first_block_ready : integer;
          constant ntt_num_stages_fully_parallel          : integer := log2_throughput;
          constant ntt_num_single_stages                  : integer := log2_input_size - ntt_num_stages_fully_parallel;
          constant ntt_num_blocks_per_polym               : integer := 2 ** log2_input_size / 2 ** log2_throughput;                                                                                                                                                                                             -- is a power of 2
          constant ntt_sequential_stages_pipeline_latency : integer := initial_clks_per_sequential_block * (ntt_num_single_stages - 1) + boolean'pos(negacyclic) * sequential_stage_clks_till_first_butterfly_result + boolean'pos(not negacyclic) * sequential_stage_clks_till_first_butterfly_result_no_mult; -- one stage has no ab_mod_p as the twiddles are 1
          constant ntt_parallel_stages_pipeline_latency   : integer := clks_per_butterfly * ntt_num_stages_fully_parallel;
          constant ntt_stages_pipeline_latency            : integer := ntt_sequential_stages_pipeline_latency + ntt_parallel_stages_pipeline_latency + ntt_num_stages_fully_parallel*boolean'pos(fp_stage_substage_ouput_buffers);
          constant intt_rescaling_latency                 : integer := clks_per_ab_mod_p;
     begin
          -- this calculates the latency from first input to first output (NOT the reset-drops to first output latency)
          if ntt_num_single_stages > 0 then
               -- first stage must receive ntt_num_blocks_per_polym/2 before it has an output for the second stage
               -- second stage must receive ntt_num_blocks_per_polym/4 before it has an output for the third stage
               -- in total: 1/2 + 1/4 + ...
               ntt_block_delay := 0;
               if with_format_switch then
                    ntt_block_delay := ntt_num_blocks_per_polym / 2;
               end if;
               for sequential_stage in 0 to ntt_num_single_stages - 1 loop
                    ntt_block_delay := ntt_block_delay + ntt_stage_logic_out_bufs + ((ntt_num_blocks_per_polym / 2) / (2 ** sequential_stage));
               end loop;
               ntt_clks_till_first_block_ready := ntt_stages_pipeline_latency + ntt_block_delay;

               res := ntt_clks_till_first_block_ready;
          else
               -- fully parallel ntt
               res := boolean'pos(not negacyclic) * ((ntt_num_stages_fully_parallel - 1) * clks_per_butterfly + clks_per_butterfly_without_mult_modulo) + boolean'pos(negacyclic) * ntt_num_stages_fully_parallel * clks_per_butterfly + ntt_num_stages_fully_parallel*boolean'pos(fp_stage_substage_ouput_buffers);
          end if;

          if intt and with_intt_recaling then
               res := res + intt_rescaling_latency;
          end if;

          return res;
     end function;

     function zero_indices(
               polym : sub_polynom
          ) return sub_polynom is
          variable res : sub_polynom(0 to polym'length - 1);
     begin
          for i in 0 to res'length - 1 loop
               res(i) := polym(polym'left + i);
          end loop;
          return res;
     end function;

end package body;
