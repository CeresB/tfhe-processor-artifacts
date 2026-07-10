----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: blind_rotation
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This module does the programmable bootstrapping operation through accumulation.
--             It does not do any memory communication and expects the inputs to arrive at the correct time.
--             This module trusts that the inputs i_lwe_ai and i_acc_part stay stable for num_coeffs/throughput clock tics.
-- Dependencies: see imports
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
     use work.datatypes_utils.all;
     use work.constants_utils.all;
     use work.tfhe_constants.all;
     use work.math_utils.all;

entity blind_rotation is
     generic (
          throughput                     : integer;
          decomposition_length           : integer; -- for the external product
          num_LSBs_to_round              : integer; -- for the external product
          bits_per_slice                 : integer; -- for the external product
          polyms_per_ciphertext          : integer; -- for the external product
          min_latency_till_monomial_mult : integer; -- for the external product
          num_iterations                 : integer  -- aka k_lwe
     );
     port (
          i_clk               : in  std_ulogic;
          i_reset             : in  std_ulogic;
          i_lwe_ai            : in  rotate_idx_array(0 to br_unrolling_factor-1);
          i_acc_part          : in  sub_polynom(0 to throughput - 1);
          i_BSK_i_part        : in  sub_polynom(0 to throughput * decomposition_length * polyms_per_ciphertext * br_unrolling_factor - 1);
          o_result            : out sub_polynom(0 to throughput - 1);
          o_next_module_reset : out std_ulogic
     );
end entity;

architecture Behavioral of blind_rotation is

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
     
     component manual_bram is
          generic (
               addr_length         : integer;
               ram_length          : integer;
               ram_out_bufs_length : integer;
               ram_type            : string;
               coeff_bit_width     : integer
          );
          port (
               i_clk     : in  std_ulogic;
               i_wr_en   : in  std_ulogic;
               i_wr_data : in  unsigned(0 to coeff_bit_width - 1);
               i_wr_addr : in  unsigned(0 to addr_length - 1);
               i_rd_addr : in  unsigned(0 to addr_length - 1);
               o_data    : out unsigned(0 to coeff_bit_width - 1)
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

     constant ciphertexts_per_blind_rotation : integer := num_iterations * blind_rot_iter_num_ciphertexts_in_pipeline;
     constant bsk_coeffs_per_pbs_loop: integer := throughput * decomposition_length * polyms_per_ciphertext;

     constant blocks_per_ciphertext : integer := (num_coefficients / throughput) * num_polyms_per_rlwe_ciphertext;
     signal ciphertext_block_cnt  : unsigned(0 to get_bit_length(blocks_per_ciphertext - 1) - 1);
     signal ciphertext_cnt        : unsigned(0 to get_bit_length(ciphertexts_per_blind_rotation - 1) - 1);
     
     type sub_polyms_size_throughput is array (natural range <>) of sub_polynom(0 to throughput - 1);
     signal blind_rot_iter_input  : sub_polyms_size_throughput(0 to br_unrolling_factor - 1);
     signal blind_rot_iter_input_buf  : sub_polyms_size_throughput(0 to br_unrolling_factor - 1);
     signal blind_rot_iter_output : sub_polyms_size_throughput(0 to br_unrolling_factor - 1);
     signal blind_rot_iter_output_buf : sub_polyms_size_throughput(0 to br_unrolling_factor - 1);

     signal blind_rot_iter_reset  : std_ulogic_vector(0 to br_unrolling_factor-1);
     signal blind_rot_iter_reset_buf  : std_ulogic_vector(0 to br_unrolling_factor-1);
     signal blind_rot_iter_next_reset  : std_ulogic_vector(0 to br_unrolling_factor-1);

     type input_arr is array (natural range <>) of sub_polynom(0 to (blind_rot_iter_input(0)'length) * boolean'pos(use_pbs_fake) - 1);
     signal fake_input_storage : input_arr(0 to (blind_rot_iter_latency - 1) * boolean'pos(use_pbs_fake) - 1);

     constant ciphertext_cnt_early_trigger : integer := 2*log2_pbs_throughput;
     signal mode_change_bufferchain : std_ulogic_vector(0 to ciphertext_cnt_early_trigger - 1);
     signal next_module_reset_chain : std_ulogic_vector(0 to mode_change_bufferchain'length+2-1); -- +2 because mode_change takes 2 clk tics before it steers the outputs

     constant extra_latency_buffer_ram_possible : boolean := (blind_rot_iter_extra_latency > (extra_latency_ram_retiming_latency + 1));
     constant extra_latency_buffer_length       : integer := get_max(1, blind_rot_iter_extra_latency - boolean'pos(extra_latency_buffer_ram_possible) * (extra_latency_ram_retiming_latency));
     signal extra_latency_buffer_end_part       : sub_polynom(0 to throughput - 1);
     signal extra_latency_buffer                : sub_polyms_size_throughput(0 to boolean'pos(not extra_latency_buffer_ram_possible) * extra_latency_buffer_length - 1);
     signal extra_latency_buffer_cnt : unsigned(0 to get_bit_length(extra_latency_buffer_length) - 1) := to_unsigned(0, get_bit_length(extra_latency_buffer_length)); -- this module needs an early reset for this to work

     signal extra_latency_buffer_input: sub_polynom(0 to throughput - 1);
     signal extra_latency_buffer_reset: std_ulogic;

begin

     -- extra latency-buffer logic
     blind_rot_iter_input(0) <= extra_latency_buffer_end_part;
     extra_latency_no_buffer_present: if not extra_latency_buffer_ram_possible generate
          -- not enough headroom for using ram
          extra_latency_out_mapping: for i in 0 to extra_latency_buffer_end_part'length - 1 generate
               extra_latency_buffer_end_part(i) <= extra_latency_buffer(extra_latency_buffer'length - 1)(i);
          end generate;

          no_logic: if blind_rot_iter_extra_latency = 0 generate
               extra_latency_buffer(0)       <= extra_latency_buffer_input;
          end generate;
          basic_buf_logic: if blind_rot_iter_extra_latency = 1 generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         extra_latency_buffer(0) <= extra_latency_buffer_input;
                    end if;
               end process;
          end generate;
          buf_logic: if blind_rot_iter_extra_latency > 1 generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         extra_latency_buffer <= extra_latency_buffer_input & extra_latency_buffer(0 to extra_latency_buffer'length - 2);
                    end if;
               end process;
          end generate;
     end generate;

     extra_latency_buffer_present: if extra_latency_buffer_ram_possible generate
          extra_latency_brams: for coeff_idx in 0 to extra_latency_buffer_input'length - 1 generate
               ram_elem: manual_bram
                    generic map (
                         addr_length         => extra_latency_buffer_cnt'length,
                         ram_length          => extra_latency_buffer_length,
                         ram_out_bufs_length => extra_latency_ram_retiming_latency,
                         ram_type            => extra_latency_buffer_ram_type,
                         coeff_bit_width     => extra_latency_buffer_input(0)'length
                    )
                    port map (
                         i_clk     => i_clk,
                         i_wr_en   => '1',
                         i_wr_data => extra_latency_buffer_input(coeff_idx),
                         i_wr_addr => extra_latency_buffer_cnt,
                         i_rd_addr => extra_latency_buffer_cnt,
                         o_data    => extra_latency_buffer_end_part(coeff_idx)
                    );
          end generate;

          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    if extra_latency_buffer_cnt = 0 then
                         extra_latency_buffer_cnt <= to_unsigned(extra_latency_buffer_length - 1, extra_latency_buffer_cnt'length);
                    else
                         extra_latency_buffer_cnt <= extra_latency_buffer_cnt - to_unsigned(1, extra_latency_buffer_cnt'length);
                    end if;
               end if;
          end process;
     end generate;

     initial_latency_counter: one_time_counter
          generic map (
               tripping_value     => blind_rot_iter_extra_latency + initial_decomp_delay_first_block - ntt_num_clks_reset_early,
               out_negated        => true,
               bufferchain_length => trailing_reset_buffer_len
          )
          port map (
               i_clk     => i_clk,
               i_reset   => extra_latency_buffer_reset,
               o_tripped => blind_rot_iter_reset(0)
          );

     big_compute_module: if not use_pbs_fake generate
          pbs_loop_unrolling: for i in 0 to br_unrolling_factor-1 generate
               blind_rot_iter: blind_rotation_iteration
                    generic map (
                         throughput                     => throughput,
                         decomposition_length           => decomposition_length,
                         num_LSBs_to_round              => num_LSBs_to_round,
                         bits_per_slice                 => bits_per_slice,
                         polyms_per_ciphertext          => num_polyms_per_rlwe_ciphertext,
                         min_latency_till_monomial_mult => min_latency_till_monomial_mult
                    )
                    port map (
                         i_clk               => i_clk,
                         i_reset             => blind_rot_iter_reset_buf(i),
                         i_ai                => i_lwe_ai(i),
                         i_acc_part          => blind_rot_iter_input_buf(i),
                         i_BSK_i_part        => i_BSK_i_part(i*bsk_coeffs_per_pbs_loop to (i+1)*bsk_coeffs_per_pbs_loop-1),
                         o_result            => blind_rot_iter_output_buf(i),
                         o_next_module_reset => blind_rot_iter_next_reset(i)
                    );
          end generate;
     end generate;

     fake_compute_module: if use_pbs_fake generate
          -- for faster simulation just behave the same latency-wise but nothing more
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    if blind_rot_iter_reset_buf(0) = '0' then
                         fake_input_storage(0) <= blind_rot_iter_input_buf(0);
                         fake_input_storage(1 to fake_input_storage'length - 1) <= fake_input_storage(0 to fake_input_storage'length - 2);
                         blind_rot_iter_output_buf(blind_rot_iter_output_buf'length-1) <= fake_input_storage(fake_input_storage'length - 1);
                    end if;
               end if;
          end process;
     end generate;

     o_next_module_reset <= next_module_reset_chain(next_module_reset_chain'length-1);
     process (i_clk)
     begin
          if rising_edge(i_clk) then
               next_module_reset_chain(1 to next_module_reset_chain'length-1) <= next_module_reset_chain(0 to next_module_reset_chain'length-2);
               blind_rot_iter_reset(1 to blind_rot_iter_reset'length-1) <= blind_rot_iter_next_reset(0 to blind_rot_iter_next_reset'length-2);
               blind_rot_iter_input(1 to blind_rot_iter_input'length-1) <= blind_rot_iter_output(0 to blind_rot_iter_output'length-2);

               if i_reset = '1' then
                    ciphertext_block_cnt <= to_unsigned(blocks_per_ciphertext - 1 - ciphertext_cnt_early_trigger, ciphertext_block_cnt'length);
                    ciphertext_cnt <= to_unsigned(ciphertexts_per_blind_rotation - 1, ciphertext_cnt'length);
                    extra_latency_buffer_reset <= '1';
                    next_module_reset_chain(0) <= '1';
               else
                    -- input of external product has one delay so reset also needs a delay
                    extra_latency_buffer_reset <= '0';
                    -- output of this module has one delay so reset for next module also needs a delay

                    if ciphertext_cnt = 0 and ciphertext_block_cnt = 0 then
                         next_module_reset_chain(0) <= '0';
                    end if;

                    if ciphertext_block_cnt = 0 then
                         ciphertext_block_cnt <= to_unsigned(blocks_per_ciphertext - 1, ciphertext_block_cnt'length);
                         -- new ciphertext starts
                         if ciphertext_cnt = 0 then
                              ciphertext_cnt <= to_unsigned(ciphertexts_per_blind_rotation - 1, ciphertext_cnt'length);
                         else
                              ciphertext_cnt <= ciphertext_cnt - to_unsigned(1, ciphertext_cnt'length);
                         end if;
                    else
                         ciphertext_block_cnt <= ciphertext_block_cnt - to_unsigned(1, ciphertext_block_cnt'length);
                    end if;
               end if;

               -- blind_rot_iter_input and blind_rot_iter_output change every clock tic
               -- because of high fanout trigger this early and use bufferchain
               if ciphertext_cnt > to_unsigned(ciphertexts_per_blind_rotation-ciphertext_cnt_early_trigger-blind_rot_iter_num_ciphertexts_in_pipeline-1, ciphertext_cnt'length) then
                    -- input-output phase
                    mode_change_bufferchain(0) <= '0';
               else
                    -- loop phase
                    mode_change_bufferchain(0) <= '1';
               end if;
               mode_change_bufferchain(1 to mode_change_bufferchain'length - 1) <= mode_change_bufferchain(0 to mode_change_bufferchain'length - 2);

               -- blind_rot_iter_input and blind_rot_iter_output change every clock tic
               if mode_change_bufferchain(mode_change_bufferchain'length - 1) = '0' then
                    -- input-output phase
                    extra_latency_buffer_input <= i_acc_part;
                    o_result <= blind_rot_iter_output(blind_rot_iter_output'length-1);
               else
                    -- loop phase
                    extra_latency_buffer_input <= blind_rot_iter_output(blind_rot_iter_output'length-1);
               end if;

          end if;
     end process;

     out_buf: if buffer_blind_rot_output generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               for i in 0 to br_unrolling_factor-1 loop
                    blind_rot_iter_output(i) <= blind_rot_iter_output_buf(i);
               end loop;
          end if;
          end process;
     end generate;
     no_out_buf: if not buffer_blind_rot_output generate
          set_all: for i in 0 to br_unrolling_factor-1 generate
               blind_rot_iter_output(i) <= blind_rot_iter_output_buf(i);
          end generate;
     end generate;

     in_buf: if buffer_blind_rot_input generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               for i in 0 to br_unrolling_factor-1 loop
                    blind_rot_iter_input_buf(i) <= blind_rot_iter_input(i);
                    blind_rot_iter_reset_buf(i) <= blind_rot_iter_reset(i);
               end loop;
          end if;
          end process;
     end generate;
     no_in_buf: if not buffer_blind_rot_input generate
          set_all: for i in 0 to br_unrolling_factor-1 generate
               blind_rot_iter_input_buf(i) <= blind_rot_iter_input(i);
               blind_rot_iter_reset_buf(i) <= blind_rot_iter_reset(i);
          end generate;
     end generate;

end architecture;
