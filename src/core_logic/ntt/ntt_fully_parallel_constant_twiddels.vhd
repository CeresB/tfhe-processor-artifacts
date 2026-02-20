----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ntt_fully_parallel_constant_twiddles
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This is a fully pipelined and fully parallel negacyclic ntt, meant to work in a bigger context
--             This module does do the re-scaling at the end of the intt
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
library work;
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.math_utils.all;
     use work.ntt_utils.all;

entity ntt_fully_parallel_constant_twiddles is
     generic (
          prime               : synthesiseable_uint;
          num_stages          : integer;
          invers              : boolean;
          first_stage_no_mult : boolean;
          twiddle_values      : ntt_twiddle_values_to_index;
          without_rescaling   : boolean;
          n_invers            : synthesiseable_uint
     );
     port (
          i_clk    : in  std_ulogic;
          i_polym  : in  polynom;
          o_result : out polynom
     );
end entity;

architecture Behavioral of ntt_fully_parallel_constant_twiddles is
     constant num_butterflies_per_stage : integer              := 2 ** num_stages / samples_per_butterfly;
     constant twiddles_to_use           : tw_subtable_as_array := twiddle_values.twiddle_factor_table;
     type stages_samples is array (0 to num_stages - 1) of polynom;

     signal stage_inputs  : stages_samples;
     signal stage_outputs : stages_samples;
     -- better: outside module provides the correct twiddle table one clk tic later
     --signal twiddle_buffer: tw_index_subtable; -- because we buffer the input polynom we must also buffer the output polynom
     component ntt_butterfly_optimized is
          generic (
               prime   : synthesiseable_uint;
               invers  : boolean;
               no_mult : boolean
          );
          port (
               i_clk            : in  std_ulogic;
               i_numA           : in  synthesiseable_uint;
               i_numB           : in  synthesiseable_uint;
               i_twiddle_factor : in  synthesiseable_uint;
               o_resultA        : out synthesiseable_uint;
               o_resultB        : out synthesiseable_uint
          );
     end component;

     component ntt_mult_mod_twiddle is
          generic (
               prime : synthesiseable_uint
          );
          port (
               i_clk            : in  std_ulogic;
               i_a_part         : in  synthesiseable_uint;
               i_twiddle_factor : in  synthesiseable_uint;
               o_mod_res        : out synthesiseable_uint
          );
     end component;

begin

     flow_chain: if not invers generate
          -- the output is the input of the next stage
          stage_inputs <= i_polym & stage_outputs(0 to stage_outputs'length - 2);
          o_result <= stage_outputs(stage_outputs'length - 1);
     end generate;

     flow_chain_invers: if invers generate
          -- we reverse the stage order for the intt, so that we can reuse the twiddle-table and other logic from the normal ntt
          -- the output is the input of the next stage
          stage_inputs <= stage_outputs(1 to stage_outputs'length - 1) & i_polym;

          no_intt_rescaling: if without_rescaling generate
               o_result <= stage_outputs(0);
          end generate;

          intt_rescaling: if not without_rescaling generate
               mod_modules: for i in 0 to o_result'length - 1 generate
                    ab_mod_p: ntt_mult_mod_twiddle
                         generic map (
                              prime => prime
                         )
                         port map (
                              i_clk            => i_clk,
                              i_a_part         => stage_outputs(0)(i),
                              i_twiddle_factor => n_invers,
                              o_mod_res        => o_result(i)
                         );
               end generate;
          end generate;
     end generate;

     ntt_stages: for stage_idx in 0 to num_stages - 1 generate -- for each stage
          sub_ntts: for sub_ntt_idx in 0 to (2 ** stage_idx) - 1 generate
               --butterflies per sub_ntt on this stage = num_butterflies_per_stage/num_sub_ntts
               ntt_butterflies: for butterfly_idx in 0 to (num_butterflies_per_stage / (2 ** stage_idx)) - 1 generate
                    -- samples_per_sub_ntt = 2**(num_stages - stage_idx)
                    -- bias = sub_ntt_idx * samples_per_sub_ntt
                    -- sample_distance = 2**(num_stages-1 - stage_idx)
                    -- numA idx: bias + butterfly_idx
                    -- numB idx: bias + sample_distance + butterfly_idx
                    ntt_butterfly_instance: ntt_butterfly_optimized
                         generic map (
                              prime   => prime,
                              invers  => invers,
                              no_mult => (stage_idx = 0) and first_stage_no_mult
                         )
                         port map (
                              i_clk            => i_clk,
                              i_numA           => stage_inputs(stage_idx)((sub_ntt_idx * (2 ** (num_stages - stage_idx))) + butterfly_idx),
                              i_numB           => stage_inputs(stage_idx)((sub_ntt_idx * (2 ** (num_stages - stage_idx))) + (2 ** (num_stages - 1 - stage_idx)) + butterfly_idx),
                              i_twiddle_factor => twiddles_to_use(stage_idx * num_butterflies_per_stage + (sub_ntt_idx * ((num_butterflies_per_stage / (2 ** stage_idx)))) + butterfly_idx),
                              o_resultA        => stage_outputs(stage_idx)((sub_ntt_idx * (2 ** (num_stages - stage_idx))) + butterfly_idx),
                              o_resultB        => stage_outputs(stage_idx)((sub_ntt_idx * (2 ** (num_stages - stage_idx))) + (2 ** (num_stages - 1 - stage_idx)) + butterfly_idx)
                         );
               end generate;
          end generate;
     end generate;

end architecture;
