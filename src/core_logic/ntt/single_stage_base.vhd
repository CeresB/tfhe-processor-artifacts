----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: single_stage_base
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This is a single stage of an ntt, meant to work in a bigger context.
--             This is the dataflow for the throughput/2-many butterflies of a stage.
--             The input is assumed to already be in the correct order.
--             This module mainly handels the twiddle factors and feeds the butterflys accordingly.
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
     use work.ntt_utils.all;
     use work.math_utils.all;

entity single_stage_base is
     generic (
          prime                 : synthesiseable_uint;
          invers                : boolean;
          twiddle_idxs_to_use   : index_2d_array;
          twiddle_vals_to_index : ntt_twiddle_values_to_index;
          throughput            : integer;
          total_num_stages      : integer;
          no_mult               : boolean
     );
     port (
          i_clk              : in  std_ulogic;
          i_reset            : in  std_ulogic;
          i_polym            : in  sub_polynom(0 to throughput - 1);
          o_result           : out sub_polynom(0 to throughput - 1);
          o_next_stage_reset : out std_ulogic
     );
end entity;

architecture Behavioral of single_stage_base is

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

     constant bf_block_num_butterflys           : integer                                             := throughput / samples_per_butterfly;
     constant total_num_butterflies_per_stage   : integer                                             := 2 ** total_num_stages / samples_per_butterfly;
     constant tws_per_bf                        : integer                                             := total_num_butterflies_per_stage / bf_block_num_butterflys;
     constant twiddle_idxs_to_use_idx_sanitized : index_2d_array(0 to twiddle_idxs_to_use'length - 1) := twiddle_idxs_to_use; -- the elements in this array still have their old indices, this makes them start from 0 again
     constant twiddle_idxs_delayed              : index_2d_array(0 to twiddle_idxs_to_use'length - 1) := get_idx_column_for_stage(twiddle_idxs_to_use_idx_sanitized, throughput, total_num_stages, boolean'pos(invers and (not no_mult)) * gentleman_sande_twiddle_offset + 1 * boolean'pos(ntt_butterfly_in_bufs));
     constant twiddle_factors                   : sub_polynom                                         := tw_idx_column_to_tw_factors(twiddle_idxs_delayed, twiddle_vals_to_index.twiddle_factor_table, true, throughput);

     constant half_throughput : integer := throughput / 2;
     constant tripping_val    : integer := boolean'pos(no_mult) * sequential_stage_clks_till_first_butterfly_result_no_mult + boolean'pos(not no_mult) * sequential_stage_clks_till_first_butterfly_result;

     signal bf_twiddle_factor : sub_polynom(0 to bf_block_num_butterflys - 1);

     signal twiddle_cnt : unsigned(0 to get_bit_length(tws_per_bf - 1) - 1);
     
     signal internal_reset_chain : std_ulogic_vector(0 to ntt_cnts_early_reset - 1);
     signal internal_reset       : std_ulogic;

begin

     reset_latency_counter: one_time_counter
          generic map (
               tripping_value     => tripping_val,
               out_negated        => true,
               bufferchain_length => trailing_reset_buffer_len
          )
          port map (
               i_clk     => i_clk,
               i_reset   => i_reset,
               o_tripped => o_next_stage_reset
          );
     
     reset_chain: if internal_reset_chain'length > 0 generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    internal_reset_chain <= i_reset & internal_reset_chain(0 to internal_reset_chain'length - 2);
               end if;
          end process;
          internal_reset <= internal_reset_chain(internal_reset_chain'length - 1);
     end generate;
     no_reset_chain: if not (internal_reset_chain'length > 0) generate
          internal_reset <= i_reset;
     end generate;

     process (i_clk)
     begin
          if rising_edge(i_clk) then
               if internal_reset = '1' then
                    twiddle_cnt <= to_unsigned(0, twiddle_cnt'length);
               else
                    twiddle_cnt <= twiddle_cnt + to_unsigned(1, twiddle_cnt'length);
               end if;
          end if;
     end process;
     
     butterfly_block: for butterfly_idx in 0 to bf_block_num_butterflys - 1 generate
          tw_ram: manual_constant_bram
               generic map (
                    ram_content         => twiddle_factors(butterfly_idx * tws_per_bf to (butterfly_idx + 1) * tws_per_bf - 1),
                    addr_length         => twiddle_cnt'length,
                    ram_out_bufs_length => ntt_twiddle_rams_retiming_latency,
                    ram_type            => twiddle_ram_type
               )
               port map (
                    i_clk     => i_clk,
                    i_rd_addr => twiddle_cnt,
                    o_data    => bf_twiddle_factor(butterfly_idx)
               );
          ntt_butterfly_instance: ntt_butterfly_optimized
               generic map (
                    prime   => prime,
                    invers  => invers,
                    no_mult => no_mult
               )
               port map (
                    i_clk            => i_clk,
                    i_numA           => i_polym(butterfly_idx),
                    i_numB           => i_polym(butterfly_idx + half_throughput),
                    i_twiddle_factor => bf_twiddle_factor(butterfly_idx),
                    o_resultA        => o_result(butterfly_idx),
                    o_resultB        => o_result(butterfly_idx + half_throughput)
               );
     end generate;

end architecture;
