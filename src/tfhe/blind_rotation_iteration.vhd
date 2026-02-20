----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: blind_rotation_iteration
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This module does more than an external product. It does the external product including mult by (X^a_i - 1) and +acc at the end.
--             Which corresponds to one iteration of the blind rotation.
--             To avoid buffers, i_ai and i_BSK_i_part need to be provided at the correct time. They are supposed to be in memory anyway and should not change during the operation.
--             It is expected that first acc.a is inserted in blocks size throughput and then acc.b (also in blocks size throughput).
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
     use work.math_utils.all;
     use work.ntt_utils.all;
     use work.tfhe_constants.all;

entity blind_rotation_iteration is
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
end entity;

architecture Behavioral of blind_rotation_iteration is

     component decomposition is
          generic (
               throughput           : integer;
               decomposition_length : integer;
               num_LSBs_to_round    : integer;
               bits_per_slice       : integer
          );
          port (
               i_clk       : in  std_ulogic;
               i_sub_polym : in  sub_polynom(0 to throughput - 1);
               o_result    : out synth_uint_vector(0 to throughput * decomposition_length - 1)
          );
     end component;

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
               i_reset             : in  std_ulogic;
               i_sub_polym         : in  sub_polynom(0 to throughput - 1);
               o_result            : out sub_polynom(0 to throughput - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     component ntt_out_buf is
          generic (
               throughput            : integer;
               num_ntts              : integer;
               polyms_per_ciphertext : integer;
               ram_retiming_latency  : integer
          );
          port (
               i_clk               : in  std_ulogic;
               i_reset             : in  std_ulogic;
               i_result_ntt        : in  sub_polynom(0 to throughput * num_ntts - 1); -- no buffer! you read it from memory anyway and it does not change during the computation
               o_result            : out sub_polynom(0 to throughput * num_ntts * polyms_per_ciphertext - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     component ab_mod_p_plain is
          generic (
               p : synthesiseable_uint
          );
          port (
               i_clk    : in  std_ulogic;
               i_num0   : in  synthesiseable_uint;
               i_num1   : in  synthesiseable_uint;
               o_result : out synthesiseable_uint
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

     component adder_tree is
          generic (
               vector_length : integer;
               modulus       : synthesiseable_uint
          );
          port (
               i_clk    : in  std_ulogic;
               i_vector : in  synth_uint_vector(0 to vector_length - 1);
               o_result : out synthesiseable_uint
          );
     end component;

     component mult_x_ai_minus_1_plus_acc is
          generic (
               throughput : integer
          );
          port (
               i_clk               : in  std_ulogic;
               i_reset             : in  std_ulogic;
               i_sub_polym         : in  sub_polynom(0 to throughput - 1);
               i_ai                : in  rotate_idx;
               i_acc               : in  sub_polynom(0 to throughput - 1);
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

     constant acc_buffer_length : integer := min_latency_till_monomial_mult - acc_buf_ram_retiming_latency;
     constant num_ntts          : integer := decomposition_length;
     constant num_intts         : integer := 1; -- currently only 1 intt is supported

     -- redundant constant that we need to have a throughput independent from global variables
     --constant ntt_blocks_per_polym : integer := num_coefficients / throughput; -- is a power of 2
     -- we would have to insert many more global variables here again for the latency caculations
     -- we omit that for the time being since the caller modules of this one also need to know those latencys
     type sub_polyms_size_throughput is array (natural range <>) of sub_polynom(0 to throughput - 1);

     constant extra_latency_buffer_ram_possible : boolean := (blind_rot_iter_extra_latency > (extra_latency_ram_retiming_latency + 1));
     constant extra_latency_buffer_length       : integer := get_max(1, blind_rot_iter_extra_latency - boolean'pos(extra_latency_buffer_ram_possible) * (extra_latency_ram_retiming_latency));
     signal extra_latency_reset_buffer          : std_ulogic_vector(0 to get_max(1, blind_rot_iter_extra_latency) - 1);
     signal extra_latency_reset_buffer_end_part : std_ulogic;
     signal extra_latency_buffer_end_part       : sub_polynom(0 to throughput - 1);
     signal extra_latency_buffer                : sub_polyms_size_throughput(0 to boolean'pos(not extra_latency_buffer_ram_possible) * extra_latency_buffer_length - 1);

     type extra_latency_cnt_buf is array (natural range <>) of unsigned(0 to get_bit_length(extra_latency_buffer_length) - 1);
     signal extra_latency_buffer_cnt : unsigned(0 to get_bit_length(extra_latency_buffer_length) - 1) := to_unsigned(0, get_bit_length(extra_latency_buffer_length)); -- this module needs an early reset for this to work
     signal extra_latency_buffer_cnt_buf_chain : extra_latency_cnt_buf(0 to counter_buffer_len - 2); -- -2 since chain_end handled separately
     signal extra_latency_buffer_cnt_buf_chain_end : unsigned(0 to extra_latency_buffer_cnt'length-1);

     -- we need an enormous buffer so that the old accumulator can be added at the end for the bootstrapping
     -- there is no other way since we work pipelined and do not want to strain the memory for this
     signal acc_old_part : sub_polynom(0 to throughput - 1);

     type acc_in_buffer_cnt_buf is array (natural range <>) of unsigned(0 to get_bit_length(acc_buffer_length) - 1);
     signal acc_in_buffer_cnt : unsigned(0 to get_bit_length(acc_buffer_length) - 1) := to_unsigned(0, get_bit_length(acc_buffer_length));
     signal acc_in_buffer_cnt_buf_chain : acc_in_buffer_cnt_buf(0 to counter_buffer_len - 2); -- -2 since chain_end handled separately
     signal acc_in_buffer_cnt_buf_chain_end : unsigned(0 to acc_in_buffer_cnt'length-1);

     -- decompose related signals
     signal decompose_output_line_format : synth_uint_vector(0 to throughput * decomposition_length - 1);
     signal decompose_output             : sub_polyms_size_throughput(0 to decomposition_length - 1);
     signal decomp_not_ready             : std_ulogic_vector(0 to num_ntts - 1);

     -- ntt related signals
     signal result_ntt                        : sub_polyms_size_throughput(0 to num_ntts - 1);
     signal result_ntt_line_format            : sub_polynom(0 to throughput * num_ntts - 1);
     signal result_ntt_out_buffer_line_format : sub_polynom(0 to throughput * num_ntts * polyms_per_ciphertext - 1);
     signal ntt_result_not_ready              : std_ulogic_vector(0 to num_ntts - 1);
     signal ntt_out_buf_reset                 : std_ulogic;

     -- elem-wise mult and adder tree related signals
     signal mult_result : sub_polynom(0 to i_BSK_i_part'length - 1);
     type sub_polyms_throughput_double is array (natural range <>) of sub_polynom_double(0 to throughput - 1);
     type sub_polyms_size_throughput_packed is array (natural range <>) of synth_uint_vector(0 to polyms_per_ciphertext * decomposition_length - 1);
     signal mult_result_packed : sub_polyms_size_throughput_packed(0 to throughput - 1);
     signal intt_reset         : std_ulogic;
     signal adder_tree_result  : sub_polyms_size_throughput(0 to num_intts - 1);
     signal adder_tree_result_buf  : sub_polyms_size_throughput(0 to num_intts - 1);

     -- intt related signals
     signal intt_result_not_ready        : std_ulogic;
     signal result_intt_not_rescaled     : sub_polynom(0 to throughput - 1);
     signal result_intt_not_rescaled_buf : sub_polynom(0 to throughput - 1);

     constant num_adder_tree_stages : integer := get_bit_length(decomposition_length * polyms_per_ciphertext - 1);
     constant log2_throughput       : integer := get_bit_length(throughput - 1);
     constant ntt_latency           : integer := get_ntt_latency(log2_num_coefficients, log2_throughput, ntt_params.negacyclic, false, false, false);

     constant clks_till_ntt_out_buf_ready          : integer := num_polyms_per_rlwe_ciphertext * ntt_num_blocks_per_polym + ntt_out_buf_ram_retiming_latency + 1; -- +1 for input buffer
     constant adder_tree_delay                     : integer := num_adder_tree_stages * clks_per_64_bit_add_mod;
     constant clks_till_intt_start_after_ntt_ready : integer := clks_till_ntt_out_buf_ready + clks_per_mult_mod + adder_tree_delay;

begin

     decompose_module: decomposition
          generic map (
               throughput           => throughput,
               decomposition_length => decomposition_length,
               num_LSBs_to_round    => num_LSBs_to_round,
               bits_per_slice       => bits_per_slice
          )
          port map (
               i_clk       => i_clk,
               i_sub_polym => extra_latency_buffer_end_part,
               o_result    => decompose_output_line_format
          );

     decomp_out_line_to_block_mapping: for L_idx in 0 to decompose_output'length - 1 generate
          decomp_to_ntt_mapping_2: for coeff_idx in 0 to decompose_output(0)'length - 1 generate
               decompose_output(L_idx)(coeff_idx) <= decompose_output_line_format(coeff_idx + L_idx * throughput);
          end generate;
     end generate;

     ntts: for L_idx in 0 to num_ntts - 1 generate
          initial_latency_counter: one_time_counter
               generic map (
                    tripping_value     => initial_decomp_delay_first_block - ntt_num_clks_reset_early,
                    out_negated        => true,
                    bufferchain_length => trailing_reset_buffer_len + (counter_buffer_len - 1)
               )
               port map (
                    i_clk     => i_clk,
                    i_reset   => extra_latency_reset_buffer_end_part,
                    o_tripped => decomp_not_ready(L_idx)
               );
          d_ntt: ntt
               generic map (
                    throughput                => throughput,
                    ntt_params                => ntt_params,
                    invers                    => false,
                    intt_no_final_reduction   => true,
                    no_first_last_stage_logic => true
               )
               port map (
                    i_clk               => i_clk,
                    i_reset             => decomp_not_ready(L_idx),
                    i_sub_polym         => decompose_output(L_idx),
                    o_result            => result_ntt(L_idx),
                    o_next_module_reset => ntt_result_not_ready(L_idx)
               );
     end generate;

     to_ntt_line_format: for ntt_idx in 0 to result_ntt'length - 1 generate
          to_ntt_line_format_coeff: for coeff_idx in 0 to result_ntt(0)'length - 1 generate
               result_ntt_line_format(ntt_idx * throughput + coeff_idx) <= result_ntt(ntt_idx)(coeff_idx);
          end generate;
     end generate;

     ntt_out_buf_reset_crtl: one_time_counter
          generic map (
               tripping_value     => ntt_latency + ntt_twiddle_rams_retiming_latency - 1-ntt_out_buf_reset_buf_len, -- -1 since ntt_out_buf needs one tic to compute the addresses
               out_negated        => true,
               bufferchain_length => trailing_reset_buffer_len
          )
          port map (
               i_clk     => i_clk,
               i_reset   => decomp_not_ready(0),
               o_tripped => ntt_out_buf_reset
          );
     ntt_out_buffer: ntt_out_buf
          generic map (
               throughput            => throughput,
               num_ntts              => result_ntt'length,
               polyms_per_ciphertext => polyms_per_ciphertext,
               ram_retiming_latency  => ntt_out_buf_ram_retiming_latency
          )
          port map (
               i_clk               => i_clk,
               i_reset             => ntt_out_buf_reset,
               i_result_ntt        => result_ntt_line_format,
               o_result            => result_ntt_out_buffer_line_format,
               o_next_module_reset => open
          );

     elem_wise_mults: for block_idx in 0 to polyms_per_ciphertext * num_ntts - 1 generate
          elem_wise_mult: for i in 0 to throughput - 1 generate
               big_mult_module: ab_mod_p_plain
                    generic map (
                         p => tfhe_modulus
                    )
                    port map (
                         i_clk    => i_clk,
                         i_num0   => result_ntt_out_buffer_line_format(i + block_idx * throughput),
                         i_num1   => i_BSK_i_part(i + block_idx * throughput),
                         o_result => mult_result(i + block_idx * throughput)
                    );
          end generate;
     end generate;

     -- transform mult result into vectors for the adder tree
     mult_out_buf: if use_elem_mult_res_output_buffer generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    for coeff_idx in 0 to mult_result_packed'length - 1 loop
                         for block_idx in 0 to mult_result_packed(0)'length - 1 loop
                              mult_result_packed(coeff_idx)(block_idx) <= mult_result(coeff_idx + block_idx * throughput);
                         end loop;
                    end loop;
               end if;
          end process;
     end generate;
     no_mult_out_buf: if not use_elem_mult_res_output_buffer generate
          mult_result_packed_mapping: for coeff_idx in 0 to mult_result_packed'length - 1 generate
               block_mapping: for block_idx in 0 to mult_result_packed(0)'length - 1 generate
                    mult_result_packed(coeff_idx)(block_idx) <= mult_result(coeff_idx + block_idx * throughput);
               end generate;
          end generate;
     end generate;

     sub_polym_adder_trees: for coeff_block_idx in 0 to mult_result_packed'length - 1 generate
          adder_tree_module: adder_tree
               generic map (
                    vector_length => mult_result_packed(0)'length,
                    modulus       => tfhe_modulus
               )
               port map (
                    i_clk    => i_clk,
                    i_vector => mult_result_packed(coeff_block_idx),
                    o_result => adder_tree_result(0)(coeff_block_idx)
               );
     end generate;

     initial_intt_reset_latency_counter: one_time_counter
          generic map (
               tripping_value     => clks_till_intt_start_after_ntt_ready - ntt_twiddle_rams_retiming_latency, -- -ntt_twiddle_rams_retiming_latency because of early reset for intt
               out_negated        => true,
               bufferchain_length => trailing_reset_buffer_len
          )
          port map (
               i_clk     => i_clk,
               i_reset   => ntt_result_not_ready(0),
               o_tripped => intt_reset
          );

     d_intt: ntt
          generic map (
               throughput                => throughput,
               ntt_params                => ntt_params,
               invers                    => true,
               intt_no_final_reduction   => true,
               no_first_last_stage_logic => true
          )
          port map (
               i_clk               => i_clk,
               i_reset             => intt_reset,
               i_sub_polym         => adder_tree_result_buf(0),
               o_result            => result_intt_not_rescaled,
               o_next_module_reset => intt_result_not_ready
          );
     
     intt_input_buf: if use_intt_input_buffer generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               adder_tree_result_buf <= adder_tree_result;
          end if;
          end process;
     end generate;
     no_intt_input_buf: if not use_intt_input_buffer generate
          adder_tree_result_buf <= adder_tree_result;
     end generate;

     intt_out_buf: if use_intt_res_output_buffer generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    result_intt_not_rescaled_buf <= result_intt_not_rescaled;
               end if;
          end process;
     end generate;
     no_intt_out_buf: if not use_intt_res_output_buffer generate
          result_intt_not_rescaled_buf <= result_intt_not_rescaled;
     end generate;

     end_step: mult_x_ai_minus_1_plus_acc
          generic map (
               throughput => throughput
          )
          port map (
               i_clk               => i_clk,
               i_reset             => intt_result_not_ready,
               i_sub_polym         => result_intt_not_rescaled_buf,
               i_ai                => i_ai,
               i_acc               => acc_old_part,
               o_result            => o_result,
               o_next_module_reset => o_next_module_reset
          );

     -- extra latency-buffer logic
     extra_latency_reset_buffer_end_part <= extra_latency_reset_buffer(extra_latency_reset_buffer'length - 1);

     extra_latency_no_buffer_present: if not extra_latency_buffer_ram_possible generate
          -- not enough headroom for using ram
          extra_latency_out_mapping: for i in 0 to extra_latency_buffer_end_part'length - 1 generate
               extra_latency_buffer_end_part(i) <= extra_latency_buffer(extra_latency_buffer'length - 1)(i);
          end generate;

          no_logic: if blind_rot_iter_extra_latency = 0 generate
               extra_latency_buffer(0)       <= i_acc_part;
               extra_latency_reset_buffer(0) <= i_reset;
          end generate;
          basic_buf_logic: if blind_rot_iter_extra_latency = 1 generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         extra_latency_buffer(0) <= i_acc_part;
                         extra_latency_reset_buffer(0) <= i_reset;
                    end if;
               end process;
          end generate;
          buf_logic: if blind_rot_iter_extra_latency > 1 generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         extra_latency_buffer(0) <= i_acc_part;
                         extra_latency_buffer(1 to extra_latency_buffer'length - 1) <= extra_latency_buffer(0 to extra_latency_buffer'length - 2);
                         extra_latency_reset_buffer(1 to extra_latency_reset_buffer'length - 1) <= extra_latency_reset_buffer(0 to extra_latency_reset_buffer'length - 2);
                         extra_latency_reset_buffer(0) <= i_reset;
                    end if;
               end process;
          end generate;
     end generate;

     extra_latency_buffer_present: if extra_latency_buffer_ram_possible generate
          extra_latency_brams: for coeff_idx in 0 to i_acc_part'length - 1 generate
               ram_elem: manual_bram
                    generic map (
                         addr_length         => extra_latency_buffer_cnt'length,
                         ram_length          => extra_latency_buffer_length,
                         ram_out_bufs_length => extra_latency_ram_retiming_latency,
                         ram_type            => extra_latency_buffer_ram_type,
                         coeff_bit_width     => i_acc_part(0)'length
                    )
                    port map (
                         i_clk     => i_clk,
                         i_wr_en   => '1',
                         i_wr_data => i_acc_part(coeff_idx),
                         i_wr_addr => extra_latency_buffer_cnt_buf_chain_end,
                         i_rd_addr => extra_latency_buffer_cnt_buf_chain_end,
                         o_data    => extra_latency_buffer_end_part(coeff_idx)
                    );
          end generate;

          -- the reset buffer is so insignificant that we make it rolling anyway
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    extra_latency_reset_buffer(1 to extra_latency_reset_buffer'length - 1) <= extra_latency_reset_buffer(0 to extra_latency_reset_buffer'length - 2);
                    extra_latency_reset_buffer(0) <= i_reset;
               end if;
          end process;

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
          do_extra_latency_buffer_cnt_buf_chain: if extra_latency_buffer_cnt_buf_chain'length > 0 generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         extra_latency_buffer_cnt_buf_chain(0) <= extra_latency_buffer_cnt;
                         extra_latency_buffer_cnt_buf_chain(1 to extra_latency_buffer_cnt_buf_chain'length-1) <= extra_latency_buffer_cnt_buf_chain(0 to extra_latency_buffer_cnt_buf_chain'length-2);
                    end if;
               end process;
               extra_latency_buffer_cnt_buf_chain_end <= extra_latency_buffer_cnt_buf_chain(extra_latency_buffer_cnt_buf_chain'length-1);
          end generate;
          no_extra_latency_buffer_cnt_buf_chain: if not (extra_latency_buffer_cnt_buf_chain'length > 0) generate
               extra_latency_buffer_cnt_buf_chain_end <= extra_latency_buffer_cnt;
          end generate;
     end generate;

     -- acc buffer logic
     acc_buffer_urams: for coeff_idx in 0 to extra_latency_buffer_end_part'length - 1 generate
          ram_elem: manual_bram
               generic map (
                    addr_length         => acc_in_buffer_cnt'length,
                    ram_length          => acc_buffer_length,
                    ram_out_bufs_length => acc_buf_ram_retiming_latency,
                    ram_type            => acc_buffer_ram_type,
                    coeff_bit_width     => extra_latency_buffer_end_part(0)'length
               )
               port map (
                    i_clk     => i_clk,
                    i_wr_en   => '1',
                    i_wr_data => extra_latency_buffer_end_part(coeff_idx),
                    i_wr_addr => acc_in_buffer_cnt_buf_chain_end,
                    i_rd_addr => acc_in_buffer_cnt_buf_chain_end,
                    o_data    => acc_old_part(coeff_idx)
               );
     end generate;

     acc_logic: process (i_clk)
     begin
          if rising_edge(i_clk) then
               if acc_in_buffer_cnt = 0 then
                    acc_in_buffer_cnt <= to_unsigned(acc_buffer_length - 1, acc_in_buffer_cnt'length);
               else
                    acc_in_buffer_cnt <= acc_in_buffer_cnt - to_unsigned(1, acc_in_buffer_cnt'length);
               end if;
          end if;
     end process;
     do_acc_in_buffer_cnt_buf_chain: if acc_in_buffer_cnt_buf_chain 'length > 0 generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    acc_in_buffer_cnt_buf_chain(0) <= acc_in_buffer_cnt;
                    acc_in_buffer_cnt_buf_chain(1 to acc_in_buffer_cnt_buf_chain'length - 1) <= acc_in_buffer_cnt_buf_chain(0 to acc_in_buffer_cnt_buf_chain'length - 2);
               end if;
          end process;
          acc_in_buffer_cnt_buf_chain_end <= acc_in_buffer_cnt_buf_chain(acc_in_buffer_cnt_buf_chain'length-1);
     end generate;
     no_acc_in_buffer_cnt_buf_chain: if not (acc_in_buffer_cnt_buf_chain'length > 0) generate
          acc_in_buffer_cnt_buf_chain_end <= acc_in_buffer_cnt;
     end generate;

end architecture;
