----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: karazuba_mult_dsp_level
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: n-bit times n-bit multiplication using Karazuba to split it into
--             three n/2-bit multiplications.
--             For num0 = a1*2**(n/2)+a0 and num1 = b1*2**(n/2)+b0 It computes:
--             p1*2**(n) + (p3-(p1+p2))*2**(n/2)+p2
--             where
--             p1=a1*b1
--             p2=a0*b0
--             p3=(a1+a0)*(b1+b0)
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
     use work.math_utils.all;

entity karazuba_mult_dsp_level_p3 is
     generic (
          base_len            : integer;
          dsp_retiming_length : integer
     );
     port (
          i_clk  : in  std_ulogic;
          i_num0 : in  unsigned(0 to base_len - 1);
          i_num1 : in  unsigned(0 to base_len - 1);
          o_res  : out unsigned(0 to 2 * base_len - 1)
     );
end entity;

architecture Behavioral of karazuba_mult_dsp_level_p3 is

     constant half_base : integer := base_len / 2;         --rounded down
     constant rest_base : integer := base_len - half_base;
     subtype half_reg is unsigned(0 to half_base - 1);
     subtype half_rest_reg is unsigned(0 to rest_base - 1);

     subtype full_reg is unsigned(0 to 2 * half_base - 1);
     subtype full_rest_reg is unsigned(0 to 2 * rest_base - 1);

     signal a0     : half_reg;
     signal b0     : half_reg;
     signal a1     : half_rest_reg;
     signal b1     : half_rest_reg;
     -- signal a0_buf : half_reg;
     -- signal a1_buf : half_rest_reg;
     signal b0_buf : half_reg;
     signal b1_buf_wo_msb : half_reg;
     signal a0_buf2     : half_reg;
     signal a1_buf2     : half_rest_reg;
     signal b0_buf2     : half_reg;
     signal b1_buf2     : half_rest_reg;

     signal p1 : full_rest_reg;
     signal p2 : full_reg;
     signal p3 : unsigned(0 to (rest_base + 1)+(half_base+1) - 1);

     signal p2_upper : half_reg;
     signal p2_lower : half_reg;
     signal p2_minus_p2upper : full_reg;
     signal p1_minus_carry : unsigned(0 to p1'length + 2 - 1);

     signal p1_plus_p2_minus_p2upper : unsigned(0 to (p1'length + 2) - 1); -- +2 for carry

     signal p123_temp : unsigned(0 to p3'length+1 - 1); -- p3=p1+p2+a1*b0+a0*b1 --> p3-(p1+p2) is always positive here
     signal p123_temp_upper   : unsigned(0 to p3'length+1-half_base - 1);
     signal p123_temp_lower   : half_reg;
     signal p123_temp_lower_buf   : unsigned(0 to p123_temp_lower'length - 1);
     signal p123 : unsigned(0 to o_res'length-2*half_base - 1);

     -- wait registers for the multiplication result which are pushed back into the DSPs
     type wait_registers_mult_result_p1 is array (natural range <>) of unsigned(0 to p1'length - 1);
     type wait_registers_mult_result_p2 is array (natural range <>) of unsigned(0 to p2'length - 1);
     type wait_registers_mult_result_p3 is array (natural range <>) of unsigned(0 to p3'length - 1);
     constant dsp_retiming_length_no_preadder: integer := dsp_retiming_length-1;
     signal p1_wait_regs : wait_registers_mult_result_p1(0 to dsp_retiming_length_no_preadder-1 - 1); -- -1 because no post-adder
     signal p2_wait_regs : wait_registers_mult_result_p2(0 to dsp_retiming_length_no_preadder-1 - 1); -- -1 because no post-adder
     signal p3_wait_regs : wait_registers_mult_result_p3(0 to dsp_retiming_length_no_preadder-1 - 1); -- -1 because we need the value for the post-adder

     signal p1_wait_reg_2 : wait_registers_mult_result_p1(0 to 2+1 - 1);

     type half_reg_wait_regs is array (natural range <>) of half_reg;
     signal p2_lower_wait_regs : half_reg_wait_regs(0 to 3+1 - 1);
     signal p2_lower_wait_regs_end : half_reg;
     signal p2_lower_wait_regs_cnt: unsigned(0 to get_bit_length(p2_lower_wait_regs'length-1-1)-1) := to_unsigned(p2_lower_wait_regs'length-1-1,get_bit_length(p2_lower_wait_regs'length-1-1)); -- another -1 because end part handles separately

     signal res_buf : unsigned(0 to o_res'length - 1);

     signal a1_plus_a0 : unsigned(0 to a1'length + 1 - 1); -- +1 for carry
     signal b1_plus_b0 : unsigned(0 to b0'length + 1 - 1); -- +1 for carry
    --  signal a1_plus_a0_buf : unsigned(0 to a1_plus_a0'length - 1);
     -- signal b1_plus_b0_buf : unsigned(0 to a1_plus_a0'length - 1);

     constant p2_lower_regs_rolling: boolean := true;

    type wait_regs_num is array(natural range <>) of unsigned(0 to a1_plus_a0'length-1);
    signal a0_plus_a1_buf_chain: wait_regs_num(0 to 1-1);
    signal b1_msb_buf_chain: std_logic_vector(0 to 1-1);
    signal a0_plus_a1_b1msb_shifted: unsigned(0 to a1_plus_a0'length+b1'length-1-1);
    constant zero_vals: unsigned(0 to a0_plus_a1_b1msb_shifted'length-1) := to_unsigned(0,a0_plus_a1_b1msb_shifted'length);
    signal sub_value: unsigned(0 to a0_plus_a1_b1msb_shifted'length-1);

begin
     -- MSB is at index 0
     -- leading 0 ensures the numbers are not interpreted as negative numbers
     a1 <= i_num0(0 to rest_base - 1);
     a0 <= i_num0(rest_base to i_num0'length - 1);
     b1 <= i_num1(0 to rest_base - 1);
     b0 <= i_num1(rest_base to i_num1'length - 1);
     p2_upper <= (p2(0 to half_base - 1));
     p2_lower <= (p2(half_base to 2 * half_base - 1));
     p123_temp_upper <= (p123_temp(0 to p123_temp_upper'length - 1));
     p123_temp_lower <= (p123_temp(p123_temp_upper'length to p123_temp'length - 1));

     p1 <= p1_wait_regs(p1_wait_regs'length - 1);
     p2 <= p2_wait_regs(p2_wait_regs'length - 1);
     p3 <= p3_wait_regs(p3_wait_regs'length - 1);

     res_buf <= unsigned(std_ulogic_vector(p123) & std_ulogic_vector(p123_temp_lower_buf) & std_ulogic_vector(p2_lower_wait_regs_end));

     -- buffer output?
     o_res <= res_buf;

     a0_plus_a1_b1msb_shifted(0 to a1_plus_a0'length-1) <= a1_plus_a0;
     -- a0_plus_a1_b1msb_shifted(0 to a1_plus_a0'length-1) <= a0_plus_a1_buf_chain(a0_plus_a1_buf_chain'length-1);
     a0_plus_a1_b1msb_shifted(a1_plus_a0'length to a0_plus_a1_b1msb_shifted'length-1) <= (others=>'0');

     process (i_clk)
     begin
          if rising_edge(i_clk) then
               -- stage -1
               -- the dsps want their input buffered
               a0_buf2 <= a0;
               a1_buf2 <= a1;
               b0_buf2 <= b0;
               b1_buf2 <= b1;

               -- stage 0
               -- a0_buf <= a0_buf2;
               -- a1_buf <= a1_buf2;
               b0_buf <= b0_buf2;
               -- idea: reduce b1 by 1 bit and manually add it conditionally later to reduce the multiplication by 1
               --   such that the multiplication fits into a DSP
               b1_buf_wo_msb <= b1_buf2(1 to b1_buf2'length-1);
               b1_msb_buf_chain(0) <= b1_buf2(0);
               b1_msb_buf_chain(1 to b1_msb_buf_chain'length - 1) <= b1_msb_buf_chain(0 to b1_msb_buf_chain'length - 2);

               a1_plus_a0 <= ('0' & a1_buf2) + a0_buf2; -- extend one operand for the carry bit
               p2_wait_regs(0) <= a0_buf2 * b0_buf2;
               p1_wait_regs(0) <= a1_buf2 * b1_buf2;

               -- stage 1
               a0_plus_a1_buf_chain(0) <= a1_plus_a0;
               a0_plus_a1_buf_chain(1 to a0_plus_a1_buf_chain'length - 1) <= a0_plus_a1_buf_chain(0 to a0_plus_a1_buf_chain'length - 2);
            --    a1_plus_a0_buf <= a1_plus_a0; -- buffered inside the dsp
               b1_plus_b0 <= (('0' & b1_buf_wo_msb) + b0_buf); -- should be done in p3-dsp-pre-adder. Extend one operand for the carry bit

               -- stage 2
               p3_wait_regs(0) <= a0_plus_a1_buf_chain(0) * b1_plus_b0;

               p1_wait_regs(1 to p1_wait_regs'length - 1) <= p1_wait_regs(0 to p1_wait_regs'length - 2);
               p2_wait_regs(1 to p2_wait_regs'length - 1) <= p2_wait_regs(0 to p2_wait_regs'length - 2);
               p3_wait_regs(1 to p3_wait_regs'length - 1) <= p3_wait_regs(0 to p3_wait_regs'length - 2);

               -- stage 3
               -- p2 & p1 are ready
               p1_wait_reg_2(0) <= p1;
               p1_wait_reg_2(1 to p1_wait_reg_2'length - 1) <= p1_wait_reg_2(0 to p1_wait_reg_2'length - 2);
            --    p1_plus_p2_minus_p2upper <= unsigned(std_ulogic_vector(to_unsigned(0, 2)) & std_ulogic_vector(p1)) + p2 - p2_upper; -- extend one operand for the carry bit
               if b1_msb_buf_chain(b1_msb_buf_chain'length-1) = '1' then
                sub_value <= a0_plus_a1_b1msb_shifted;
               else
                sub_value <= zero_vals;
               end if;
               p2_minus_p2upper <= p2 - p2_upper;
               p1_minus_carry <= unsigned(std_ulogic_vector(to_unsigned(0, 2)) & std_ulogic_vector(p1)) - sub_value;
                p1_plus_p2_minus_p2upper <= p1_minus_carry + p2_minus_p2upper; -- extend one operand for the carry bit
               --  p1_plus_p2_minus_p2upper <= unsigned(std_ulogic_vector(to_unsigned(0, 2)) & std_ulogic_vector(p1)) + p2 - p2_upper - sub_value; -- extend one operand for the carry bit

               -- stage 4
               -- put p1_plus_p2_minus_p2upper in the post-adder of p3
                p123_temp <= unsigned(signed('0' & p3) - signed(p1_plus_p2_minus_p2upper));

               -- stage 5
               p123 <= p1_wait_reg_2(p1_wait_reg_2'length-1) + p123_temp_upper;

               p123_temp_lower_buf <= p123_temp_lower;
          end if;
     end process;

     p2_regs_rolling: if p2_lower_regs_rolling generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    p2_lower_wait_regs(0) <= p2_lower;
                    p2_lower_wait_regs(1 to p2_lower_wait_regs'length - 1) <= p2_lower_wait_regs(0 to p2_lower_wait_regs'length - 2);
               end if;
          end process;
          p2_lower_wait_regs_end <= p2_lower_wait_regs(p2_lower_wait_regs'length-1);
     end generate;
     
     p2_regs_not_rolling: if not p2_lower_regs_rolling generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    if p2_lower_wait_regs_cnt = 0 then
                         p2_lower_wait_regs_cnt <= to_unsigned(p2_lower_wait_regs'length-1-1,p2_lower_wait_regs_cnt'length);
                    else
                         p2_lower_wait_regs_cnt <= p2_lower_wait_regs_cnt - to_unsigned(1,p2_lower_wait_regs_cnt'length);
                    end if;
                    p2_lower_wait_regs(to_integer(p2_lower_wait_regs_cnt)) <= p2_lower;
                    p2_lower_wait_regs_end <= p2_lower_wait_regs(to_integer(p2_lower_wait_regs_cnt));
               end if;
          end process;
     end generate;

end architecture;
