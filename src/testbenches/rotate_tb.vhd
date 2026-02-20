----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.09.2024 08:38:39
-- Design Name: 
-- Module Name: rotate_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
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
library work;
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.math_utils.all;
     use work.tfhe_constants.all;
     use work.tb_utils.all;

entity rotate_tb is
     --  Port ( );
end entity;

architecture Behavioral of rotate_tb is

     component rotate_polym_with_buffer is
          generic (
               throughput    : integer;
               rotate_right  : boolean;
               rotate_offset : integer;
               negate_polym  : boolean;
               reverse_polym : boolean
          );
          port (
               i_clk               : in  std_ulogic;
               i_reset             : in  std_ulogic;
               i_sub_polym         : in  sub_polynom(0 to throughput - 1);
               i_rotate_by         : in  rotate_idx;
               o_result            : out sub_polynom(0 to throughput - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     constant TIME_DELTA : time := 10 ns;
     constant clk_period : time := TIME_DELTA * 2;

     constant log2_throughput : integer := log2_ntt_throughput;

     constant reversed_mode : boolean := false;
     constant r_right       : boolean := true;
     constant throughput    : integer := 2 ** log2_throughput;

     constant log2_throughput_num_blocks_per_polym : integer := log2_num_coefficients - log2_throughput;
     constant throughput_num_blocks_per_polym      : integer := 2 ** log2_throughput_num_blocks_per_polym;
     constant next_sample_time                     : time    := throughput_num_blocks_per_polym * clk_period;

     signal rotate_input  : sub_polynom(0 to throughput - 1);
     signal rotate_output : sub_polynom(0 to throughput - 1);
     signal rotate_reset  : std_ulogic_vector(0 to counter_buffer_len - 1);

     signal rotate_input_coeff_cnt  : idx_int := to_unsigned(0, log2_num_coefficients);
     signal rotate_output_coeff_cnt : idx_int := to_unsigned(0, log2_num_coefficients);

     signal rotate_input_tb               : polynom;
     signal rotate_input_to_calc_solution : polynom;
     signal rotate_result_buffer_polym    : polynom;
     signal result_rotate_tb              : polynom; -- v4p ignore w-303
     signal clk                           : std_ulogic := '1';
     signal rotate_firstoutput_not_ready  : std_ulogic_vector(0 to counter_buffer_len - 1);
     signal rotate_complete_output_ready  : std_ulogic := '0';

     signal finished : std_ulogic := '0';

     -- 5 tests: the first two should not change the polynomial, the third should switch the sign of all coefficients
     -- but not change their order, the forth and fifth do an actual rotation
     signal rotate_by_array : int_array(0 to 2 + num_coefficients - 1);
     signal solution_array  : polynom_array(0 to rotate_by_array'length - 1);

     signal test_rotate_by         : rotate_idx;
     signal test_rotate_by_delayed : rotate_idx;
     signal rotate_reset_delayed   : std_ulogic := '1';

     signal tests_done          : std_ulogic := '0';
     signal rotate_tests_passed : boolean; -- v4p ignore w-303
     signal clk_cnt             : integer    := 0;

begin
     clk <= not clk after TIME_DELTA when finished /= '1' else '0';

     rotate_with_buffer: rotate_polym_with_buffer
          generic map (
               throughput    => throughput,
               rotate_right  => r_right,
               rotate_offset => 0,     -- little need to test this setting, its implementation is quite simple
               negate_polym  => false, -- little need to test this setting, its implementation is quite simple
               reverse_polym => reversed_mode
          )
          port map (
               i_clk               => clk,
               i_reset             => rotate_reset_delayed,
               i_sub_polym         => rotate_input,
               i_rotate_by         => test_rotate_by_delayed,
               o_result            => rotate_output,
               o_next_module_reset => rotate_firstoutput_not_ready(0)
          );

     rotate_complete_output_ready <= '1' when rotate_output_coeff_cnt = to_unsigned(0, rotate_output_coeff_cnt'length) and rotate_firstoutput_not_ready(rotate_firstoutput_not_ready'length - 1) = '0' and rotate_reset_delayed = '0' else '0';

     one_early: if (num_coefficients / throughput) - buffer_answer_delay < 0 generate
          assert not ((num_coefficients / throughput) - buffer_answer_delay < - 1) report "throughput not big enough" severity error;
          test_rotate_by_delayed <= test_rotate_by;
     end generate;
     on_time: if not ((num_coefficients / throughput) - buffer_answer_delay < 0) generate
          process (clk) is
          begin
               if rising_edge(clk) then
                    test_rotate_by_delayed <= test_rotate_by;
               end if;
          end process;
     end generate;

     process (clk)
     begin
          if rising_edge(clk) then

               rotate_reset_delayed <= rotate_reset(0);
               rotate_reset(1 to rotate_reset'length - 1) <= rotate_reset(0 to rotate_reset'length - 2);
               rotate_firstoutput_not_ready(1 to rotate_firstoutput_not_ready'length - 1) <= rotate_firstoutput_not_ready(0 to rotate_firstoutput_not_ready'length - 2);

               if rotate_reset(rotate_reset'length - 1) = '1' then
                    rotate_input_coeff_cnt <= to_unsigned(0, rotate_input_coeff_cnt'length);
                    clk_cnt <= 0;
               else
                    clk_cnt <= clk_cnt + 1;
                    rotate_input_coeff_cnt <= rotate_input_coeff_cnt + to_unsigned(throughput, rotate_input_coeff_cnt'length);
                    rotate_input <= rotate_input_tb(to_integer(rotate_input_coeff_cnt) to to_integer(rotate_input_coeff_cnt) + throughput - 1);

                    if rotate_firstoutput_not_ready(rotate_firstoutput_not_ready'length - 1) = '0' then
                         rotate_output_coeff_cnt <= rotate_output_coeff_cnt + to_unsigned(throughput, rotate_output_coeff_cnt'length);
                         rotate_result_buffer_polym(to_integer(rotate_output_coeff_cnt) to to_integer(rotate_output_coeff_cnt) + throughput - 1) <= rotate_output;

                         if rotate_output_coeff_cnt = to_unsigned(0, rotate_output_coeff_cnt'length) then
                              result_rotate_tb <= rotate_result_buffer_polym;
                         end if;
                    else
                         rotate_output_coeff_cnt <= to_unsigned(0, rotate_output_coeff_cnt'length);
                    end if;
               end if;
          end if;
     end process;

     simulation_start_tests: process
     begin
          rotate_reset(0) <= '1';
          rotate_input_tb <= get_test_sub_polym(rotate_input_tb'length, 1, 1); -- 1,2,3,...
          rotate_by_array(0) <= 2 * polynom'length;
          rotate_by_array(1) <= polynom'length;
          for i in 2 to rotate_by_array'length - 1 loop
               rotate_by_array(i) <= i - 2;
          end loop;

          wait for TIME_DELTA;
          if reversed_mode then
               rotate_input_to_calc_solution <= get_test_sub_polym(rotate_input_tb'length, rotate_input_tb'length, - 1); -- ...,3,2,1
          else
               rotate_input_to_calc_solution <= rotate_input_tb;
          end if;
          wait for TIME_DELTA;

          -- init solutions
          solution_array(0) <= rotate_input_to_calc_solution;
          solution_array(1) <= rotate_input_to_calc_solution;
          for i in 0 to solution_array(2)'length - 1 loop
               solution_array(1)(i) <= sign_switch_tb(rotate_input_to_calc_solution(i), tfhe_modulus);
          end loop;

          if r_right then
               for rotate_idx in 2 to rotate_by_array'length - 1 loop
                    for i in 0 to solution_array(0)'length - 1 loop
                         solution_array(rotate_idx)(i) <= rotate_input_to_calc_solution((i - rotate_by_array(rotate_idx)) mod polynom'length);
                    end loop;
               end loop;
               wait for TIME_DELTA;
               for rotate_idx in 2 to rotate_by_array'length - 1 loop
                    for i in 0 to rotate_by_array(rotate_idx) - 1 loop
                         solution_array(rotate_idx)(i) <= sign_switch_tb(solution_array(rotate_idx)(i), tfhe_modulus);
                    end loop;
               end loop;
          else
               for rotate_idx in 2 to rotate_by_array'length - 1 loop
                    for i in 0 to solution_array(0)'length - 1 loop
                         solution_array(rotate_idx)(i) <= rotate_input_to_calc_solution((i + rotate_by_array(rotate_idx)) mod polynom'length);
                    end loop;
               end loop;
               wait for TIME_DELTA;
               for rotate_idx in 2 to rotate_by_array'length - 1 loop
                    for i in 0 to rotate_by_array(rotate_idx) - 1 loop
                         solution_array(rotate_idx)(solution_array(0)'length - 1 - i) <= sign_switch_tb(solution_array(rotate_idx)(solution_array(0)'length - 1 - i), tfhe_modulus);
                    end loop;
               end loop;
          end if;

          wait for TIME_DELTA;
          -- remember ntt-mixed
          rotate_input_tb <= to_ntt_mixed_format(rotate_input_tb, throughput_num_blocks_per_polym, throughput);
          for i in 0 to solution_array'length - 1 loop
               solution_array(i) <= to_ntt_mixed_format(solution_array(i), throughput_num_blocks_per_polym, throughput);
          end loop;

          -- computation of the expected solution for the chosen inputs is done
          -- rotate_reset must be active at least throughput-many clock cycles for the high-fanout-counter
          for i in 0 to throughput - 1 loop
               wait for clk_period;
          end loop;

          wait until rising_edge(clk);
          rotate_reset(0) <= '0';
          test_rotate_by <= to_rotate_idx(rotate_by_array(rotate_by_array'length - 1));
          wait for (counter_buffer_len - 1) * clk_period;
          for i in 0 to rotate_by_array'length - 1 loop
               test_rotate_by <= to_rotate_idx(rotate_by_array(i));
               wait for next_sample_time;
          end loop;

          wait;
     end process;

     simulation_check_rotate_results: process
          variable pass : boolean := false;
     begin
          wait until rotate_firstoutput_not_ready(0) = '1';
          wait until rotate_firstoutput_not_ready(0) = '0';
          wait until rotate_complete_output_ready = '1';
          wait until rotate_complete_output_ready = '1';
          wait for TIME_DELTA; -- so that there can be no confusion when reading the output signal

          pass := true;
          for i in 0 to rotate_by_array'length - 1 loop
               pass := pass and (compare_polyms(rotate_result_buffer_polym, solution_array(i), "rotation by " & integer'image(rotate_by_array(i))));
               wait for next_sample_time;
               if rotate_complete_output_ready = '0' then
                    wait until rotate_complete_output_ready = '1';
                    wait for TIME_DELTA;
               end if;
          end loop;

          rotate_tests_passed <= pass;
          tests_done <= '1';
          wait;
     end process;

     resumee: process
     begin
          wait until tests_done = '1';

          assert rotate_tests_passed report "Testbench found errors in rotation module" severity error;

          assert not rotate_tests_passed report "All rotate tests passed" severity note;
          finished <= '1';
          wait;
     end process;

end architecture;
