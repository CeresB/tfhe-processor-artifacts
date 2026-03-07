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

entity karazuba_mult_dsp_level is
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

architecture Behavioral of karazuba_mult_dsp_level is

     constant half_base : integer := base_len / 2;         --rounded down, 16 bit
     constant rest_base : integer := base_len - half_base; -- 16 bit
     subtype half_reg is unsigned(0 to half_base - 1);
     subtype half_rest_reg is unsigned(0 to rest_base - 1);

     subtype full_reg is unsigned(0 to 2 * half_base - 1);
     subtype full_rest_reg is unsigned(0 to 2 * rest_base - 1);

     signal a0     : half_reg;
     signal b0     : half_reg;
     signal a1     : half_rest_reg;
     signal b1     : half_rest_reg;
     -- signal a0_buf : half_reg;
     signal a1_buf : half_rest_reg;
     signal b0_buf : half_reg;
     signal b1_buf : half_rest_reg;
     signal a0_buf2     : half_reg;
     signal a1_buf2     : half_rest_reg;
     signal b0_buf2     : half_reg;
     signal b1_buf2     : half_rest_reg;

     signal p1 : full_rest_reg; -- 16x16 bit
     signal p2 : full_reg; -- 16x16 bit
     signal p3 : unsigned(0 to 2 * (rest_base + 1) - 1); -- 17x17 bit

     signal p2_upper : half_reg;
     signal p2_lower : half_reg;
     signal p2_lower_buf : half_reg;
     signal p123 : unsigned(0 to o_res'length-p2_lower'length - 1);

     signal p3_minus_p1plusp2: unsigned(0 to p3'length-1); -- always positive
     signal p2_buf: full_reg;
     signal p1_reconstructed: full_rest_reg;
     signal p1_reconstructed_temp: unsigned(0 to p1_reconstructed'length+1 -1);
     signal p1_plus_p2 : unsigned(0 to (p1'length + 1) - 1); -- +2 for carry

     -- wait registers for the multiplication result which are pushed back into the DSPs
     type wait_registers_mult_result_p1 is array (natural range <>) of unsigned(0 to p1'length - 1);
     type wait_registers_mult_result_p2 is array (natural range <>) of unsigned(0 to p2'length - 1);
     type wait_registers_mult_result_p3 is array (natural range <>) of unsigned(0 to p3'length - 1);
     constant dsp_mult_retiming_length: integer := dsp_retiming_length-1-1; -- without preadder and with input buffered
     signal p1_wait_regs : wait_registers_mult_result_p1(0 to dsp_mult_retiming_length-1 - 1); -- -1 because we need the value for the post-adder
     signal p2_wait_regs : wait_registers_mult_result_p2(0 to dsp_mult_retiming_length - 1);
     signal p3_wait_regs : wait_registers_mult_result_p3(0 to dsp_mult_retiming_length-1 - 1); -- -1 because we need the value for the post-adder

     signal res_buf : unsigned(0 to o_res'length - 1);

     signal a1_plus_a0 : unsigned(0 to a1'length + 1 - 1); -- +1 for carry
     signal b1_plus_b0 : unsigned(0 to b1'length + 1 - 1); -- +1 for carry

     signal a1_plus_a0_buf : unsigned(0 to a1_plus_a0'length - 1);
     signal a1_plus_a0_buf2 : unsigned(0 to a1_plus_a0'length - 1);

begin
     -- MSB is at index 0
     -- leading 0 ensures the numbers are not interpreted as negative numbers
     a1 <= i_num0(0 to rest_base - 1);
     b1 <= i_num1(0 to rest_base - 1);
     a0 <= i_num0(rest_base to i_num0'length - 1);
     b0 <= i_num1(rest_base to i_num1'length - 1);
     p1_reconstructed <= p1_reconstructed_temp(1 to p1_reconstructed_temp'length-1);

     p1 <= p1_wait_regs(p1_wait_regs'length - 1);
     p2 <= p2_wait_regs(p2_wait_regs'length - 1);
     p3 <= p3_wait_regs(p3_wait_regs'length - 1);

     res_buf <= unsigned(std_ulogic_vector(p123) & std_ulogic_vector(p2_lower_buf));

     -- buffer output?
     o_res <= res_buf;

     process (i_clk)
     begin
          if rising_edge(i_clk) then
               -- the dsps want their input buffered
               -- stage 0
               a0_buf2 <= a0;
               a1_buf2 <= a1;
               b0_buf2 <= b0;
               b1_buf2 <= b1;
               a1_plus_a0 <= ('0' & a1) + a0; -- extend one operand for the carry bit

               -- stage 1
               p2_wait_regs(0) <= a0_buf2 * b0_buf2;
               a1_buf <= a1_buf2;
               b1_buf <= b1_buf2;
               b0_buf <= b0_buf2;
               a1_plus_a0_buf2 <= a1_plus_a0;

               -- stage 2
               p1_wait_regs(0) <= a1_buf * b1_buf;
               a1_plus_a0_buf <= a1_plus_a0_buf2;
               b1_plus_b0 <= (('0' & b1_buf) + b0_buf); -- should be done in p3-dsp-pre-adder. Extend one operand for the carry bit

               -- stage 3
               p3_wait_regs(0) <= a1_plus_a0_buf * b1_plus_b0;
               p1_plus_p2 <= p1 + resize(p2,p1_plus_p2'length); -- shall happen in post-ader of p1 mult
               p2_buf <= p2;

               -- stage 4
               p3_minus_p1plusp2 <= p3 - p1_plus_p2;
               p1_reconstructed_temp <= p1_plus_p2 - p2_buf;
               p2_upper <= (p2_buf(0 to half_base - 1));
               p2_lower <= (p2_buf(half_base to 2 * half_base - 1));

               -- stage 5
               p2_lower_buf <= p2_lower;
               p123 <= unsigned(std_ulogic_vector(p1_reconstructed) & std_ulogic_vector(p2_upper)) + p3_minus_p1plusp2;

               p1_wait_regs(1 to p1_wait_regs'length - 1) <= p1_wait_regs(0 to p1_wait_regs'length - 2);
               p2_wait_regs(1 to p2_wait_regs'length - 1) <= p2_wait_regs(0 to p2_wait_regs'length - 2);
               p3_wait_regs(1 to p3_wait_regs'length - 1) <= p3_wait_regs(0 to p3_wait_regs'length - 2);
          end if;
     end process;

end architecture;
