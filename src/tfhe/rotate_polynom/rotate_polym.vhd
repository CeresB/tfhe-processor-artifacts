----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: rotate_polym
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: rotates a polynom by i_ai. Works together with polym_buffer.vhd, from which it requests values via o_request_idx.
--             i_rotate_by must be kept stable for polynom'length/throughput clock cycles.
--             Default rotation for polynoms like a0*x^2 + a1*x + a2 is to the left. Use reversed to change the direction.
--             Left-rotation by 1 results in: a1*x^2 + a2*x - a0
--             Right-rotation by 1 results in: -a2*x^2 + a0*x + a1
--             The module assumes that i_rotate_by is given (counter_buffer_len-1) tics after reset drops and i_sub_coeffs is valid one
--             tic after reset drops (this avoids a polym-sized buffer)
--             The module assumes that the input is in ntt-mixed format!
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

entity rotate_polym is
     generic (
          throughput   : integer;
          rotate_right : boolean;
          negated      : boolean -- set to true to negate the values in the output
     );
     port (
          i_clk               : in  std_ulogic;
          i_reset             : in  std_ulogic;
          i_sub_coeffs        : in  sub_polynom(0 to throughput - 1);
          i_rotate_by         : in  rotate_idx;
          o_ram_coeff_idx     : out unsigned(0 to get_bit_length((num_coefficients / throughput) - 1) * throughput / 2 - 1);
          o_result            : out sub_polynom(0 to throughput - 1);
          o_next_module_reset : out std_ulogic
     );
end entity;

architecture Behavioral of rotate_polym is

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

     component shift_array is
          generic (
               log2_arr_len : integer;
               num_stages : integer -- must be smaller log2_arr_len
          );
          port (
               i_clk  : in  std_ulogic;
               i_arr : in  sub_polynom(0 to (2**log2_arr_len)-1);
               i_shift : in  unsigned(0 to log2_arr_len-1);
               o_res  : out sub_polynom(0 to (2**log2_arr_len)-1)
          );
     end component;

     signal ai_roll_factor     : idx_int;
     signal ai_roll_factor_msb : std_ulogic;
     signal ai_sign_part       : std_ulogic;

     signal index_plus_ai_reduced        : idx_int_array(0 to o_result'length - 1);      -- does modulo automatically
     signal index_plus_ai_reduced_buffer : idx_int_array(0 to o_result'length / 2 - 1);  -- does modulo automatically

     signal input_coeff_cnt      : unsigned(0 to log2_num_coefficients - 1 - 1); -- another -1 because need half cnt for ntt mixed format;

     signal index_original_value        : idx_int_array(0 to o_result'length - 1); -- does modulo automatically
     signal index_original_value_buffer : idx_int_array(0 to o_result'length - 1);

     signal polym_part_rolled                      : sub_polynom(0 to o_result'length - 1);

     signal roll_info : std_ulogic_vector(0 to o_result'length - 1);
     type bools_wait_reg is array (natural range <>) of std_ulogic_vector(0 to buffer_answer_delay + rotate_polym_reorder_delay - 1);
     signal roll_info_wait_regs : bools_wait_reg(0 to o_result'length - 1);

     signal switch_sign_wait_regs : std_ulogic_vector(0 to (roll_info_wait_regs(0)'length + 2) - 1); -- +2 because of the stages until a request to the outside buffer is made

     constant compare_val               : std_ulogic_vector(0 to 0)        := std_ulogic_vector(to_unsigned(boolean'pos(not negated), 1));

     constant coeffs_per_ram_block            : integer := num_coefficients / throughput;
     constant coeffs_per_ram_block_bit_length : integer := get_bit_length(coeffs_per_ram_block - 1);
     constant log2_throughput                 : integer := get_bit_length(throughput - 1);
     constant log2_half_throughput             : integer := log2_throughput-1;
     signal lowest_idx_signal  : unsigned(0 to get_max(1,log2_half_throughput) - 1);
     signal ai_throughput_part : unsigned(0 to get_max(1,log2_half_throughput) - 1);
     signal across_block_offset        : unsigned(0 to log2_throughput-1); -- for the shift across blocks
     signal inner_block_offset       : unsigned(0 to get_max(1,log2_half_throughput) - 1); -- for the inner-block shift

     type inner_block_offset_chain is array (natural range <>) of unsigned(0 to inner_block_offset'length - 1);
     signal inner_block_offset_buf : inner_block_offset_chain(0 to buffer_answer_delay-1 - 1); -- -1 because input is seperate
     type across_block_offset_chain is array (natural range <>) of unsigned(0 to across_block_offset'length - 1);
     signal across_block_offset_buf  : across_block_offset_chain(0 to inner_block_offset_buf'length+(rotate_reorder_stages-1) - 1);

     signal index_plus_ai_reduced_buffer_2_part : unsigned(0 to inner_block_offset'length - 1);
     signal index_plus_ai_reduced_buffer_2_msb  : std_ulogic;

     signal input_blocks_rearanged: sub_polynom(0 to o_result'length - 1);
     signal in_block0: sub_polynom(0 to throughput/2 - 1);
     signal in_block1: sub_polynom(0 to throughput/2 - 1);
     signal in_block0_shifted: sub_polynom(0 to throughput/2 - 1);
     signal in_block1_shifted: sub_polynom(0 to throughput/2 - 1);
     signal res_buf: sub_polynom(0 to o_result'length - 1);

begin

     out_buf: if rotate_polym_out_buffer generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               o_result <= res_buf;
          end if;
          end process;
     end generate;
     no_out_buf: if not rotate_polym_out_buffer generate
          o_result <= res_buf;
     end generate;

     in_block0 <= i_sub_coeffs(0 to throughput/2-1);
     in_block1 <= i_sub_coeffs(throughput/2 to throughput-1);

     initial_latency_counter: one_time_counter
          generic map (
               tripping_value     => rotate_polym_first_block_initial_delay,
               out_negated        => true,
               bufferchain_length => trailing_reset_buffer_len
          )
          port map (
               i_clk     => i_clk,
               i_reset   => i_reset,
               o_tripped => o_next_module_reset
          );

     -- MSB is at idx 0. We want log2_num_coefficients+1 LSBs as everything above is moduloed away anyway.
     -- assuming that i_ai is not negative (which should be the case since our modulo reductions always return positive values)
     -- the upper bit of i_rotate_by decides how we do the sign switch, we only care if its an even or odd number
     -- and the lower bits contain the number that we are actually rotating the polynom by
     ai_roll_factor <= i_rotate_by(1 to i_rotate_by'length - 1);
     ai_sign_part   <= i_rotate_by(0);

     shift_regs: for i in 0 to roll_info_wait_regs'length - 1 generate
          -- vivado should infer this as shift registers
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    roll_info_wait_regs(i) <= roll_info(i) & roll_info_wait_regs(i)(0 to roll_info_wait_regs(0)'length - 2);
               end if;
          end process;
     end generate;

     rotate_left_logic: if not rotate_right generate
          lowest_idx_signal_computation: if log2_half_throughput > 0 generate
               process (i_clk) is
               begin
                    if rising_edge(i_clk) then
                         -- compared to rotate right: lowest idx is usually at 0
                         -- if last idx rolled over (check with substracting throughput/2) than it is at 0 minus the last idx value
                         -- and if not there at throughput/2-1
                         if ai_roll_factor_msb = '0' then
                              if index_plus_ai_reduced(index_plus_ai_reduced'length - 1) - to_unsigned(throughput / 2, index_plus_ai_reduced(0)'length) < index_plus_ai_reduced(index_plus_ai_reduced'length - 1) then
                                   lowest_idx_signal <= to_unsigned(0, lowest_idx_signal'length);
                              else
                                   lowest_idx_signal <= to_unsigned(index_plus_ai_reduced'length - 1, lowest_idx_signal'length) - index_plus_ai_reduced(index_plus_ai_reduced'length - 1)(index_plus_ai_reduced(0)'length - lowest_idx_signal'length to index_plus_ai_reduced(0)'length - 1);
                              end if;
                         else
                              if index_plus_ai_reduced(throughput / 2 - 1) - to_unsigned(throughput / 2, index_plus_ai_reduced(0)'length) < index_plus_ai_reduced(throughput / 2 - 1) then
                                   lowest_idx_signal <= to_unsigned(0, lowest_idx_signal'length);
                              else
                                   lowest_idx_signal <= to_unsigned(index_plus_ai_reduced'length - 1, lowest_idx_signal'length) - index_plus_ai_reduced(throughput / 2 - 1)(index_plus_ai_reduced(0)'length - lowest_idx_signal'length to index_plus_ai_reduced(0)'length - 1);
                              end if;
                         end if;
                    end if;
               end process;
          end generate;
          no_lowest_idx_signal_computation: if not (log2_half_throughput > 0) generate
               lowest_idx_signal <= to_unsigned(0, lowest_idx_signal'length);
          end generate;

          process (i_clk)
          begin
               if rising_edge(i_clk) then

                    for i in 0 to index_plus_ai_reduced'length / 2 - 1 loop
                         o_ram_coeff_idx(i * coeffs_per_ram_block_bit_length to (i + 1) * coeffs_per_ram_block_bit_length - 1) <= index_plus_ai_reduced((to_integer(to_unsigned(i, ai_throughput_part'length) - ai_throughput_part)))(1 to 1 + coeffs_per_ram_block_bit_length - 1); -- here is a change to rotate right
                    end loop;

                    for i in 0 to index_plus_ai_reduced'length - 1 loop
                         index_plus_ai_reduced(i) <= index_original_value(i) + ai_roll_factor; -- here is a change to rotate right

                         if index_plus_ai_reduced(i) < index_original_value_buffer(i) then -- here is a change to rotate right
                              roll_info(i) <= '1';
                         else
                              roll_info(i) <= '0';
                         end if;
                    end loop;
               end if;
          end process;
     end generate;

     rotate_right_logic: if rotate_right generate
          lowest_idx_signal_computation: if log2_half_throughput > 0 generate
               process (i_clk) is
               begin
                    if rising_edge(i_clk) then
                         -- need to find inner_block_offset, which determines the order in which a bufferblock-group is read
                         -- inner_block_offset is the block index of the lowest index that we request
                         -- we want to read from the lowest idx upwards
                         -- the lowest idx is always at position 0 but not if that idx+throughput/2 < idx
                         -- since we count up: if at idx 0 is not the lowest, the lowest must be at idx = num_coeffs-1 - index_plus_ai_reduced(0) + 1 = -index_plus_ai_reduced(0) mod throughput
                         -- exception: if ai_roll_factor >= N/2 then lowest idx is at position throughput/2
                         if ai_roll_factor_msb = '0' then
                              if index_plus_ai_reduced(0) + to_unsigned(throughput / 2, index_plus_ai_reduced(0)'length) > index_plus_ai_reduced(0) then
                                   lowest_idx_signal <= to_unsigned(0, lowest_idx_signal'length);
                              else
                                   lowest_idx_signal <= to_unsigned(0, lowest_idx_signal'length) - index_plus_ai_reduced(0)(index_plus_ai_reduced(0)'length - lowest_idx_signal'length to index_plus_ai_reduced(0)'length - 1);
                              end if;
                         else
                              if index_plus_ai_reduced(throughput / 2) + to_unsigned(throughput / 2, index_plus_ai_reduced(0)'length) > index_plus_ai_reduced(throughput / 2) then
                                   lowest_idx_signal <= to_unsigned(0, lowest_idx_signal'length);
                              else
                                   lowest_idx_signal <= to_unsigned(0, lowest_idx_signal'length) - index_plus_ai_reduced(throughput / 2)(index_plus_ai_reduced(0)'length - lowest_idx_signal'length to index_plus_ai_reduced(0)'length - 1);
                              end if;
                         end if;
                    end if;
               end process;
          end generate;
          no_lowest_idx_signal_computation: if not (log2_half_throughput > 0) generate
               lowest_idx_signal <= to_unsigned(0, lowest_idx_signal'length);
          end generate;

          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    for i in 0 to index_plus_ai_reduced'length / 2 - 1 loop
                         -- index_plus_ai_reduced: ignore first bit, it is for ntt mixed half
                         -- first ram_coeff_idx is for the first block, second for the second block and so on
                         -- where is the coefficient idx for the first block? At ai mod (throughput/2).
                         o_ram_coeff_idx(i * coeffs_per_ram_block_bit_length to (i + 1) * coeffs_per_ram_block_bit_length - 1) <= index_plus_ai_reduced((to_integer(to_unsigned(i, ai_throughput_part'length) + ai_throughput_part)))(1 to 1 + coeffs_per_ram_block_bit_length - 1);
                    end loop;

                    for i in 0 to index_plus_ai_reduced'length - 1 loop
                         -- if we rotate by 0 we request coefficients 0,1,2,3,...
                         -- if we rotate by 1 to the right we want to request coefficients -1,0,1,2 because the last coefficient rolls over
                         -- and becomes the new first coefficient. Bottom line: rotate right = subtract ai_roll_factor
                         index_plus_ai_reduced(i) <= index_original_value(i) - ai_roll_factor;

                         if index_plus_ai_reduced(i) > index_original_value_buffer(i) then
                              roll_info(i) <= '1'; -- coefficient rolled over polynom bounds
                         else
                              roll_info(i) <= '0'; -- coefficient stayed within polynom bounds
                         end if;
                    end loop;
               end if;
          end process;
     end generate;

     half_throughput_computation: if log2_half_throughput > 0 generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    ai_throughput_part <= ai_roll_factor(ai_roll_factor'length - ai_throughput_part'length to ai_roll_factor'length - 1);
                    
                    -- we use block offset to rearrange what the polynom-buffer provided us with
                    inner_block_offset <= index_plus_ai_reduced_buffer(to_integer(lowest_idx_signal))(index_plus_ai_reduced_buffer(0)'length - inner_block_offset'length to index_plus_ai_reduced_buffer(0)'length - 1);

                    -- across_block_offset is the idx from which we start reading the result
                    -- the coefficients inside the mixed-halves are in the right order
                    -- where do we find the first idx in the result? At the position of its buffer block? No, the blocks are sorted.
                    -- only need to know the half and then from where to read the half
                    -- read the half from the buffer block of the index and correct by inner_block_offset
                    index_plus_ai_reduced_buffer_2_part <= index_plus_ai_reduced_buffer(0)(index_plus_ai_reduced_buffer(0)'length - (inner_block_offset'length) to index_plus_ai_reduced_buffer(0)'length - 1);
                    across_block_offset <= index_plus_ai_reduced_buffer_2_msb & (index_plus_ai_reduced_buffer_2_part - inner_block_offset);
                    ai_roll_factor_msb <= ai_roll_factor(0);
               end if;
          end process;
     end generate;
     no_half_throughput_computation: if not (log2_half_throughput > 0) generate
          ai_throughput_part <= to_unsigned(0,ai_throughput_part'length);
          inner_block_offset <= to_unsigned(0,inner_block_offset'length);
          ai_roll_factor_msb <= '0';
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    across_block_offset(0) <= index_plus_ai_reduced_buffer_2_msb;
               end if;
          end process;
     end generate;

     shift: if log2_half_throughput > 0 generate
          shift_block0: shift_array
               generic map (
                    log2_arr_len => log2_half_throughput,
                    num_stages   => rotate_reorder_stages
               )
               port map (
                    i_clk   => i_clk,
                    i_arr   => in_block0,
                    i_shift => inner_block_offset_buf(inner_block_offset_buf'length - 1),
                    o_res   => in_block0_shifted
               );
          shift_block1: shift_array
               generic map (
                    log2_arr_len => log2_half_throughput,
                    num_stages   => rotate_reorder_stages
               )
               port map (
                    i_clk   => i_clk,
                    i_arr   => in_block1,
                    i_shift => inner_block_offset_buf(inner_block_offset_buf'length - 1),
                    o_res   => in_block1_shifted
               );
     end generate;
     no_shift: if not (log2_half_throughput > 0) generate
          in_block0_shifted <= in_block0;
          in_block1_shifted <= in_block1;
     end generate;
     
     input_blocks_rearanged <= in_block0_shifted & in_block1_shifted;
     shift_long: shift_array
          generic map (
               log2_arr_len => log2_throughput,
               num_stages   => rotate_reorder_stages+1 -- +1 so complexity is equal to in_block shift
          )
          port map (
               i_clk   => i_clk,
               i_arr   => input_blocks_rearanged,
               i_shift => across_block_offset_buf(across_block_offset_buf'length - 1),
               o_res   => polym_part_rolled
          );

     process (i_clk)
     begin
          if rising_edge(i_clk) then
               -- stage 0
               -- switch sign computation
               switch_sign_wait_regs <= ai_sign_part & switch_sign_wait_regs(0 to switch_sign_wait_regs'length - 2);
               -- index_original_value is one too early so ai_roll_factor does not need to be buffered
               index_original_value_buffer <= index_original_value;
               -- stage 0 computes index_plus_ai_reduced in another process

               -- stage 1
               -- uses index_plus_ai_reduced to compute roll_info
               -- stage 2 and 3: computation of polym_part_rolled
               index_plus_ai_reduced_buffer <= index_plus_ai_reduced(0 to index_plus_ai_reduced_buffer'length - 1);
               index_plus_ai_reduced_buffer_2_msb <= index_plus_ai_reduced_buffer(0)(0);

               -- i_sub_coeffs arrive a bit later due to pingpong_ram_retiming_latency!
               -- delay inner_block_offset and across_block_offset
               across_block_offset_buf <= across_block_offset & across_block_offset_buf(0 to across_block_offset_buf'length - 2);
               inner_block_offset_buf <= inner_block_offset & inner_block_offset_buf(0 to inner_block_offset_buf'length - 2);

               -- roll_info is computed
               -- stage x+1
               for i in 0 to res_buf'length - 1 loop
                    if (switch_sign_wait_regs(switch_sign_wait_regs'length - 1) = '1') xor (roll_info_wait_regs(i)(roll_info_wait_regs(0)'length - 1) = compare_val(0)) then
                         -- coefficient sign must change
                         res_buf(i) <= tfhe_modulus - polym_part_rolled(i); -- sign flipped
                    else
                         -- coefficient can remain as-is
                         res_buf(i) <= polym_part_rolled(i);
                    end if;
               end loop;
          end if;
     end process;

     process (i_clk)
     begin
          if rising_edge(i_clk) then
               -- getting this counter going is the reason for why reset must be dropped an additional clock tic earlier
               if i_reset = '1' then
                    input_coeff_cnt <= to_unsigned(0, input_coeff_cnt'length);
               else
                    input_coeff_cnt <= input_coeff_cnt + to_unsigned(throughput / 2, input_coeff_cnt'length);
               end if;

               for i in 0 to index_original_value'length / 2 - 1 loop
                    index_original_value(i) <= to_unsigned(i, idx_int'length) + ('0' & input_coeff_cnt);
                    index_original_value(throughput / 2 + i) <= to_unsigned(i + num_coefficients / 2, idx_int'length) + ('0' & input_coeff_cnt);
               end loop;
          end if;
     end process;

end architecture;