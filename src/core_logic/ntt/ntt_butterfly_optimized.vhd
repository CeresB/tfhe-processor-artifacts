----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ntt_butterfly_optimized
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: if not invers: CT-butterfly that computes resA = a+b*tw and resB = a-b*tw
--             if invers: GS-butterfly that computes resA = a+b and resB = (a-b)*tw
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
     use work.datatypes_utils.all;
     use work.constants_utils.all;
     use work.math_utils.all;

     -- cooley-tukey 2-point-butterfly
     -- if invers = true: gentleman-sande 2-point-butterfly

entity ntt_butterfly_optimized is
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
end entity;

architecture Behavioral of ntt_butterfly_optimized is
     signal wait_regs          : wait_registers_uint(0 to clks_per_ab_mod_p - 1 - 1); -- another -1 because of wait_regs_output
     signal a_part             : synthesiseable_uint;
     signal mod_res            : synthesiseable_uint;
     signal easy_mod_res_plus  : synthesiseable_uint;
     signal easy_mod_res_minus : synthesiseable_uint;
     signal big_add_num0       : synthesiseable_uint;
     signal big_add_num1       : synthesiseable_uint;
     signal wait_regs_input    : synthesiseable_uint;

     signal input_A_buf  : synthesiseable_uint;
     signal input_B_buf  : synthesiseable_uint;
     signal output_A_buf : synthesiseable_uint;
     signal output_B_buf : synthesiseable_uint;

     signal wait_regs_cnt : unsigned(0 to get_bit_length(wait_regs'length - 1) - 1) := to_unsigned(0, get_bit_length(wait_regs'length - 1));
     -- signal wait_regs_pre_output : synthesiseable_uint;
     signal wait_regs_output : synthesiseable_uint;

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

     component add_reduce is
          generic (
               substraction : boolean;
               modulus      : synthesiseable_uint
          );
          port (
               i_clk    : in  std_ulogic;
               i_num0   : in  synthesiseable_uint;
               i_num1   : in  synthesiseable_uint;
               o_result : out synthesiseable_uint
          );
     end component;

begin

     in_bufs: if ntt_butterfly_in_bufs generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    input_A_buf <= i_numA;
                    input_B_buf <= i_numB;
               end if;
          end process;
     end generate;
     no_in_bufs: if not ntt_butterfly_in_bufs generate
          input_A_buf <= i_numA;
          input_B_buf <= i_numB;
     end generate;

     out_bufs: if ntt_butterfly_out_bufs generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    o_resultA <= output_A_buf;
                    o_resultB <= output_B_buf;
               end if;
          end process;
     end generate;
     no_out_bufs: if not ntt_butterfly_out_bufs generate
          o_resultA <= output_A_buf;
          o_resultB <= output_B_buf;
     end generate;

     no_mult_logic: if no_mult generate
          big_add_num0 <= input_A_buf;
          big_add_num1 <= input_B_buf;
          output_A_buf <= easy_mod_res_plus;
          output_B_buf <= easy_mod_res_minus;
     end generate;

     mult_logic: if not no_mult generate

          rolling_wait_regs: if rolling_butterfly_buffers generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         wait_regs <= wait_regs_input & wait_regs(0 to wait_regs'length - 2);
                         wait_regs_output <= wait_regs(wait_regs'length - 1);
                    end if;
               end process;
          end generate;

          no_rolling_wait_regs: if not rolling_butterfly_buffers generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         if wait_regs_cnt = 0 then
                              wait_regs_cnt <= to_unsigned(wait_regs'length - 1, wait_regs_cnt'length);
                         else
                              wait_regs_cnt <= wait_regs_cnt - to_unsigned(1, wait_regs_cnt'length);
                         end if;
                         wait_regs(to_integer(wait_regs_cnt)) <= wait_regs_input;
                         wait_regs_output <= wait_regs(to_integer(wait_regs_cnt));
                    end if;
               end process;
          end generate;

          ntt_butterfly: if not invers generate
               wait_regs_input <= input_A_buf;
               a_part          <= input_B_buf;
               big_add_num1    <= mod_res;
               big_add_num0    <= wait_regs_output;
               output_A_buf    <= easy_mod_res_plus;
               output_B_buf    <= easy_mod_res_minus;
          end generate;

          intt_butterfly: if invers generate
               wait_regs_input <= easy_mod_res_plus;
               output_A_buf    <= wait_regs_output;
               a_part          <= easy_mod_res_minus;
               big_add_num0    <= input_A_buf;
               big_add_num1    <= input_B_buf;
               output_B_buf    <= mod_res;
          end generate;

          mod_module: ntt_mult_mod_twiddle
               generic map (
                    prime => prime
               )
               port map (
                    i_clk            => i_clk,
                    i_a_part         => a_part,
                    i_twiddle_factor => i_twiddle_factor,
                    o_mod_res        => mod_res
               );
     end generate;

     add_reduce_module_plus: add_reduce
          generic map (
               substraction => false,
               modulus      => prime
          )
          port map (
               i_clk    => i_clk,
               i_num0   => big_add_num0,
               i_num1   => big_add_num1,
               o_result => easy_mod_res_plus
          );

     add_reduce_module_minus: add_reduce
          generic map (
               substraction => true,
               modulus      => prime
          )
          port map (
               i_clk    => i_clk,
               i_num0   => big_add_num0,
               i_num1   => big_add_num1,
               o_result => easy_mod_res_minus
          );

end architecture;
