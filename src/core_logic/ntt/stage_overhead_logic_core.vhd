----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: stage_overhead_logic_core
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: submodule which allows to only buffer three quarters of the input polynom of each ntt/intt stage.
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

entity stage_overhead_logic_core is
     generic (
          input_size : integer; -- must be a multiple of throughput
          throughput : integer  -- must be a power of 2
     );
     port (
          i_clk                   : in  std_ulogic;
          i_reset                 : in  std_ulogic;
          i_previous_stage_output : in  sub_polynom(0 to throughput - 1);
          o_next_stage_input      : out sub_polynom(0 to throughput - 1);
          o_next_stage_reset      : out std_ulogic
     );
end entity;

architecture Behavioral of stage_overhead_logic_core is

     component one_time_counter is
          generic (
               tripping_value     : integer;
               out_negated        : boolean;
               bufferchain_length : integer -- must be smaller than tripping_value
          );
          port (
               i_clk     : in  std_ulogic;
               i_reset   : in  std_ulogic;
               o_tripped : out std_ulogic
          );
     end component;

     constant is_last_ntt_or_first_intt_stage : boolean := (input_size = throughput);                -- no in_coeff_cnt and out_coeff_cnt
     constant input_buffer_size               : integer := 2 * input_size;                           -- input_size is at minimum equal to throughput
     -- BE CAREFUL: quarter_cnt_width must be wide enough to hold ram_block'length-1 for the counter to work!
     constant num_quarter_blocks              : integer := input_buffer_size / (throughput / 2) / 4; -- input_buffer_size is at minimum 2*throughput. throughput is at minimum 2.
     constant quarter_cnt_width               : integer := get_bit_length(num_quarter_blocks - 1);

     constant half_throughput : integer := throughput / 2;
     -- only one read and write per clock tic for each ram block
     subtype ram_block is sub_polynom(0 to (2 ** (quarter_cnt_width)) - 1);
     type quarter_buffer is array (0 to throughput / 2 - 1) of ram_block;
     signal input_first_quarter_buffer : quarter_buffer;
     signal input_mid_quarter_buffer   : quarter_buffer;
     signal input_forth_quarter_buffer : quarter_buffer;

     type in_coeff_quarter_cnt_buf is array (natural range <>) of unsigned(0 to get_max(1, quarter_cnt_width) - 1);
     signal in_coeff_quarter_cnt : in_coeff_quarter_cnt_buf(0 to counter_buffer_len - 1);
     signal in_other_half        : std_ulogic_vector(0 to counter_buffer_len + ntt_in_other_half_early - 1);

     type sub_polynom_throughput_vec is array (natural range <>) of sub_polynom(0 to throughput - 1);
     signal out_bufs : sub_polynom_throughput_vec(0 to ntt_stage_logic_out_bufs - 1);
     constant reset_cnt_tripping_val : integer := ram_block'length + out_bufs'length;

     signal internal_reset_chain : std_ulogic_vector(0 to ntt_num_clks_reset_early-(counter_buffer_len-1) - 1);
     signal internal_reset       : std_ulogic;
     signal internal_in_other_half_reset       : std_ulogic;
     signal in_other_half_cnt : unsigned(0 to in_coeff_quarter_cnt(0)'length - 1); -- is in_coeff_quarter_cnt detached from its reset

     constant cnt_step_val     : integer := 1;
     constant cnt_start_val : integer := ram_block'length - cnt_step_val;

begin

     initial_latency_counter: one_time_counter
          generic map (
               tripping_value     => reset_cnt_tripping_val,
               out_negated        => true,
               bufferchain_length => trailing_reset_buffer_len
          )
          port map (
               i_clk     => i_clk,
               i_reset   => i_reset,
               o_tripped => o_next_stage_reset
          );

     with_cnt: if not (is_last_ntt_or_first_intt_stage) generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    if internal_in_other_half_reset = '1' then
                         in_other_half(0) <= '0';
                         in_other_half_cnt <= to_unsigned(cnt_start_val, in_other_half_cnt'length);
                    else
                         in_other_half_cnt <= in_other_half_cnt - to_unsigned(cnt_step_val, in_other_half_cnt'length);
                         if in_other_half_cnt = 0 then
                              in_other_half(0) <= not in_other_half(0);
                         end if;
                    end if;
                    if internal_reset = '1' then
                         in_coeff_quarter_cnt(0) <= to_unsigned(cnt_start_val, in_coeff_quarter_cnt(0)'length);
                    else
                         in_coeff_quarter_cnt(0) <= in_coeff_quarter_cnt(0) - to_unsigned(cnt_step_val, in_coeff_quarter_cnt(0)'length);
                    end if;
                    in_coeff_quarter_cnt(1 to in_coeff_quarter_cnt'length - 1) <= in_coeff_quarter_cnt(0 to in_coeff_quarter_cnt'length - 2);
                    in_other_half(1 to in_other_half'length - 1) <= in_other_half(0 to in_other_half'length - 2);
               end if;
          end process;
     end generate;

     no_cnts: if (is_last_ntt_or_first_intt_stage) generate
          --in_coeff_quarter_cnt(0) <= to_unsigned(0, in_coeff_quarter_cnt(0)'length);
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    if internal_in_other_half_reset = '1' then
                         in_other_half(0) <= '0';
                    else
                         in_other_half(0) <= not in_other_half(0);
                    end if;
                    in_other_half(1 to in_other_half'length - 1) <= in_other_half(0 to in_other_half'length - 2);
               end if;
          end process;
     end generate;

     reset_chain: if internal_reset_chain'length > 0 generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    internal_reset_chain <= i_reset & internal_reset_chain(0 to internal_reset_chain'length - 2);
               end if;
          end process;
          internal_reset <= internal_reset_chain(internal_reset_chain'length - 1);
          internal_in_other_half_reset <= internal_reset_chain(internal_reset_chain'length - 1 - ntt_in_other_half_early);
     end generate;
     no_reset_chain: if not (internal_reset_chain'length > 0) generate
          internal_reset <= i_reset;
          internal_in_other_half_reset <= i_reset; -- should not happen, ntt_in_other_half_early < ntt_cnts_early_reset
     end generate;

     buffer_rw_logic: for i in 0 to half_throughput - 1 generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    if in_other_half(in_other_half'length - 1) = '0' then
                         input_first_quarter_buffer(i)(to_integer(in_coeff_quarter_cnt(in_coeff_quarter_cnt'length - 1))) <= i_previous_stage_output(i);
                         input_mid_quarter_buffer(i)(to_integer(in_coeff_quarter_cnt(in_coeff_quarter_cnt'length - 1))) <= i_previous_stage_output(i + half_throughput);
                         out_bufs(0)(i) <= input_mid_quarter_buffer(i)(to_integer(in_coeff_quarter_cnt(in_coeff_quarter_cnt'length - 1)));
                         out_bufs(0)(half_throughput + i) <= input_forth_quarter_buffer(i)(to_integer(in_coeff_quarter_cnt(in_coeff_quarter_cnt'length - 1)));
                    else
                         out_bufs(0)(i) <= input_first_quarter_buffer(i)(to_integer(in_coeff_quarter_cnt(in_coeff_quarter_cnt'length - 1)));
                         -- the second quarter is not buffered in the ntt
                         out_bufs(0)(half_throughput + i) <= i_previous_stage_output(i);
                         input_forth_quarter_buffer(i)(to_integer(in_coeff_quarter_cnt(in_coeff_quarter_cnt'length - 1))) <= i_previous_stage_output(i + half_throughput);
                    end if;
               end if;
          end process;
     end generate;

     --out_buf_logic: if out_bufs'length-1 > 0 generate
     process (i_clk) is
     begin
          if rising_edge(i_clk) then
               out_bufs(1 to out_bufs'length - 1) <= out_bufs(0 to out_bufs'length - 2);
          end if;
     end process;
     --end generate;

     o_next_stage_input <= out_bufs(out_bufs'length - 1);

end architecture;
