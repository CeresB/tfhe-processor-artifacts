----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ntt_fully_parallel_stage_base
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This is a wrapper for ntt_fully_parallel_optimized, which handels the twiddle factors for ntt_fully_parallel_optimized.
--             It functions similar to single_stage_base.vhd but with a twiddle-factor table instead of a twiddle-factor column.
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
     use work.datatypes_utils.all;
     use work.constants_utils.all;
     use work.math_utils.all;
     use work.ntt_utils.all;

entity ntt_fully_parallel_stage_base is
     generic (
          prime                 : synthesiseable_uint;
          twiddle_idxs_to_use   : index_2d_array;
          twiddle_vals_to_index : ntt_twiddle_values_to_index;
          invers                : boolean;
          throughput            : integer;
          total_num_stages      : integer; -- for the whole ntt, not just the fully-parallel part
          first_stage_no_mult   : boolean
     );
     port (
          i_clk              : in  std_ulogic;
          i_reset            : in  std_ulogic;
          i_polym            : in  sub_polynom(0 to throughput - 1);
          o_result           : out sub_polynom(0 to throughput - 1);
          o_next_stage_reset : out std_ulogic
     );
end entity;

architecture Behavioral of ntt_fully_parallel_stage_base is

     component ntt_fully_parallel_optimized is
          generic (
               prime               : synthesiseable_uint;
               num_stages          : integer;
               invers              : boolean;
               first_stage_no_mult : boolean
          );
          port (
               i_clk             : in  std_ulogic;
               i_polym           : in  sub_polynom;
               i_twiddles_to_use : in  sub_polynom;
               o_result          : out sub_polynom
          );
     end component;

     component one_time_counter is
          generic (
               tripping_value     : integer;
               out_negated        : boolean;
               bufferchain_length : integer
          );
          port (
               i_clk     : in  std_ulogic;
               i_reset   : in  std_ulogic;
               o_tripped : out std_ulogic
          );
     end component;

     component manual_constant_bram is
          generic (
               ram_content         : sub_polynom;
               addr_length         : integer;
               ram_out_bufs_length : integer;
               ram_type            : string
          );
          port (
               i_clk     : in  std_ulogic;
               i_rd_addr : in  unsigned(0 to addr_length - 1);
               o_data    : out synthesiseable_uint
          );
     end component;

     constant bf_block_num_butterflys         : integer := throughput / samples_per_butterfly;
     constant total_num_butterflies_per_stage : integer := 2 ** total_num_stages / samples_per_butterfly;
     constant tws_per_bf                      : integer := total_num_butterflies_per_stage / bf_block_num_butterflys;

     constant log2_throughput           : integer     := get_bit_length(throughput - 1);
     constant num_stages_fully_parallel : integer     := log2_throughput;
     constant twiddles_to_use           : sub_polynom := tw_idx_columns_to_tw_factors(total_num_stages, twiddle_idxs_to_use, twiddle_vals_to_index.twiddle_factor_table, true, throughput);
     constant total_num_tws_per_stage   : integer     := 2 ** total_num_stages / samples_per_butterfly;
     signal fully_parallel_ntt_twiddles : sub_polynom(0 to num_stages_fully_parallel * bf_block_num_butterflys - 1);
     signal fp_substage_resets          : std_ulogic_vector(0 to num_stages_fully_parallel + 1 - 1); -- +1 for initial reset
     type resets_chain is array(natural range <>) of std_ulogic_vector(0 to fp_substage_resets'length-1);
     signal fp_substage_resets_chain: resets_chain(0 to ntt_cnts_early_reset-ntt_twiddle_rams_fp_stage_additional_retiming_latency - 1);
     signal fp_substage_internal_resets          : std_ulogic_vector(0 to fp_substage_resets'length - 1);

     type tw_row_cnts is array (natural range <>) of unsigned(0 to get_bit_length(tws_per_bf - 1) - 1);
     type tw_cnts_buf is array (natural range <>) of tw_row_cnts(0 to num_stages_fully_parallel - 1);
     signal input_twiddle_cnts : tw_cnts_buf(0 to counter_buffer_len - 1);

begin

     fp_substage_resets(0) <= i_reset;
     o_next_stage_reset    <= fp_substage_resets(fp_substage_resets'length - 1);
     reset_logic: for sub_stage_idx in 1 to fp_substage_resets'length - 1 generate
          reset_latency_counter: one_time_counter
               generic map (
                    tripping_value     => clks_per_butterfly+1*boolean'pos(fp_stage_substage_ouput_buffers),
                    out_negated        => true,
                    bufferchain_length => trailing_reset_buffer_len
               )
               port map (
                    i_clk     => i_clk,
                    i_reset   => fp_substage_resets(sub_stage_idx - 1),
                    o_tripped => fp_substage_resets(sub_stage_idx)
               );
     end generate;

     reset_chain: if fp_substage_resets_chain'length > 0 generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    fp_substage_resets_chain <= fp_substage_resets & fp_substage_resets_chain(0 to fp_substage_resets_chain'length - 2);
               end if;
          end process;
          fp_substage_internal_resets <= fp_substage_resets_chain(fp_substage_resets_chain'length - 1);
     end generate;
     no_reset_chain: if not (fp_substage_resets_chain'length > 0) generate
          fp_substage_internal_resets <= fp_substage_resets;
     end generate;

     process (i_clk) is
     begin
       if rising_edge(i_clk) then
               input_twiddle_cnts(1 to input_twiddle_cnts'length - 1) <= input_twiddle_cnts(0 to input_twiddle_cnts'length - 2);
       end if;
     end process;

     stage_tw_rams: for sub_stage_idx in 0 to input_twiddle_cnts(0)'length - 1 generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    if fp_substage_internal_resets(boolean'pos(not invers) * (sub_stage_idx) + boolean'pos(invers) * (num_stages_fully_parallel - 1 - sub_stage_idx)) = '1' then
                         input_twiddle_cnts(0)(sub_stage_idx) <= to_unsigned(0, input_twiddle_cnts(0)(0)'length);
                    else
                         input_twiddle_cnts(0)(sub_stage_idx) <= input_twiddle_cnts(0)(sub_stage_idx) + to_unsigned(1, input_twiddle_cnts(0)(0)'length);
                    end if;
               end if;
          end process;

          tw_rams: for butterfly_idx in 0 to bf_block_num_butterflys - 1 generate
               tw_ram: manual_constant_bram
                    generic map (
                         ram_content         => twiddles_to_use(sub_stage_idx * total_num_tws_per_stage + butterfly_idx * tws_per_bf to sub_stage_idx * total_num_tws_per_stage + (butterfly_idx + 1) * tws_per_bf - 1),
                         addr_length         => input_twiddle_cnts(0)(0)'length,
                         ram_out_bufs_length => ntt_twiddle_rams_retiming_latency+ntt_twiddle_rams_fp_stage_additional_retiming_latency,
                         ram_type            => twiddle_ram_type
                    )
                    port map (
                         i_clk     => i_clk,
                         i_rd_addr => input_twiddle_cnts(input_twiddle_cnts'length - 1)(sub_stage_idx),
                         o_data    => fully_parallel_ntt_twiddles(sub_stage_idx * bf_block_num_butterflys + butterfly_idx)
                    );
          end generate;
     end generate;

     ntt_fully_parallel_optimized_inst: ntt_fully_parallel_optimized
          generic map (
               prime               => prime,
               num_stages          => num_stages_fully_parallel,
               invers              => invers,
               first_stage_no_mult => first_stage_no_mult
          )
          port map (
               i_clk             => i_clk,
               i_polym           => i_polym,
               i_twiddles_to_use => fully_parallel_ntt_twiddles,
               o_result          => o_result
          );

end architecture;
