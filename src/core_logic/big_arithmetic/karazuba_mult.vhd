----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: karazuba_mult
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
     use work.datatypes_utils.all;
     use work.math_utils.all;

entity karazuba_mult is
     generic (
          base_len            : integer;
          dsp_retiming_length : integer
     );
     port (
          i_clk  : in  std_ulogic;
          i_num0 : in  unsigned(0 to 2 * base_len - 1);
          i_num1 : in  unsigned(0 to 2 * base_len - 1);
          o_res  : out unsigned(0 to 4 * base_len - 1)
     );
end entity;

architecture Behavioral of karazuba_mult is

     component mult_dsp_level is
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
     end component;

     -- constant base_signed : integer := base_len + 1;
     subtype half_reg is unsigned(0 to base_len - 1);
     subtype full_reg is unsigned(0 to 2 * base_len - 1);
     type half_reg_wait_regs is array (natural range <>) of half_reg;
     type full_reg_wait_regs is array (natural range <>) of full_reg;

     signal a0 : half_reg;
     signal b0 : half_reg;
     signal a1 : half_reg;
     signal b1 : half_reg;
     signal p1       : full_reg; -- with the max values for a1 & b1 its 64 bits unsigned
     signal p2       : full_reg; -- with the max values for a0 & b0 its 64 bits unsigned
     signal p2_upper : half_reg;
     signal p2_lower : half_reg;
     signal p1_plus_p2_minus_p2upper : unsigned(0 to (p1'length + 2) - 1); -- +2 for carry

     signal a1_plus_a0 : unsigned(0 to a1'length + 1 - 1);         -- +1 for carry
     signal b1_plus_b0 : unsigned(0 to b1'length + 1 - 1);         -- +1 for carry
     signal p3         : unsigned(0 to 2 * a1_plus_a0'length - 1); -- with the max values for a1,a0,b1 & b0 its 66 bits unsigned

     -- signal p2_minus_p2upper : unsigned(0 to p2'length - 1); -- no carry possible
     -- signal p1_plus_p2_minus_p2upper : unsigned(0 to (p1'length + 2) - 1); -- +2 for carry
     signal p123_temp         : unsigned(0 to p3'length - 1);
     signal p123_temp_upper   : unsigned(0 to p3'length-base_len - 1);
     signal p123_temp_lower   : unsigned(0 to base_len - 1);
     signal p123_temp_lower_buf   : unsigned(0 to p123_temp_lower'length - 1);

     signal p123 : unsigned(0 to 2 * base_len - 1); -- p3=p1+p2+a1*b0+a0*b1 --> p3-(p1+p2) is always positive here

     signal p1_wait_reg_2      : full_reg;
     signal p1_wait_reg_3      : full_reg;
     signal p2_lower_wait_regs : half_reg_wait_regs(0 to 3 - 1);
     signal p2_lower_wait_regs_end : half_reg;
     signal p2_lower_wait_regs_cnt: unsigned(0 to get_bit_length(p2_lower_wait_regs'length-1-1)-1) := to_unsigned(p2_lower_wait_regs'length-1-1,get_bit_length(p2_lower_wait_regs'length-1-1)); -- another -1 because end part handles separately

     constant p2_lower_regs_rolling: boolean := true;

     signal num0_buf: unsigned(0 to i_num0'length - 1);
     signal num1_buf: unsigned(0 to i_num1'length - 1);

begin

     in_buf: if use_mult_karazuba_in_buffer generate
          process (i_clk) is
          begin
            if rising_edge(i_clk) then
               num0_buf <= i_num0;
               num1_buf <= i_num1;
            end if;
          end process;
     end generate;
     no_in_buf: if not use_mult_karazuba_in_buffer generate
          num0_buf <= i_num0;
          num1_buf <= i_num1;
     end generate;

     -- MSB is at index 0
     -- leading 0 ensures the numbers are not interpreted as negative numbers
     a1 <= num0_buf(0 to base_len - 1);
     b1 <= num1_buf(0 to base_len - 1);
     a0 <= num0_buf(base_len to num0_buf'length - 1);
     b0 <= num1_buf(base_len to num1_buf'length - 1);
     p2_upper <= (p2(0 to base_len - 1));
     p2_lower <= (p2(base_len to 2 * base_len - 1));
     p123_temp_upper <= (p123_temp(0 to p123_temp_upper'length - 1));
     p123_temp_lower <= (p123_temp(p123_temp_upper'length to p123_temp'length - 1));

     o_res <= unsigned(std_ulogic_vector(p123) & std_ulogic_vector(p123_temp_lower_buf) & std_ulogic_vector(p2_lower_wait_regs_end));

     p1_mult: mult_dsp_level
          generic map (
               base_len            => a1'length,
               dsp_retiming_length => dsp_retiming_length
          )
          port map (
               i_clk  => i_clk,
               i_num0 => a1,
               i_num1 => b1,
               o_res  => p1
          );
     p2_mult: mult_dsp_level
          generic map (
               base_len            => a0'length,
               dsp_retiming_length => dsp_retiming_length
          )
          port map (
               i_clk  => i_clk,
               i_num0 => a0,
               i_num1 => b0,
               o_res  => p2
          );
     p3_mult: mult_dsp_level
          generic map (
               base_len            => a1_plus_a0'length,
               dsp_retiming_length => dsp_retiming_length
          )
          port map (
               i_clk  => i_clk,
               i_num0 => a1_plus_a0,
               i_num1 => b1_plus_b0,
               o_res  => p3
          );

     process (i_clk)
     begin
          if rising_edge(i_clk) then
               a1_plus_a0 <= ('0' & a1) + a0; -- extend one operand for the carry bit
               b1_plus_b0 <= ('0' & b1) + b0; -- extend one operand for the carry bit

               -- stage x-1
               -- we rewrite (p3-(p1+p2))*2**(n/2)+p2 to (p3-(p1+p2))+p2_upper || p2_lower = p3-(p1+p2-p2_upper) || p2_lower
               -- p1 and p2 finish one tic earlier than p3
               -- use that time to calculate p1+p2-p2_upper
               p1_plus_p2_minus_p2upper <= unsigned(std_ulogic_vector(to_unsigned(0, 2)) & std_ulogic_vector(p1)) + p2 - p2_upper; -- extend one operand for the carry bit
               p1_wait_reg_2 <= p1;

               -- stage x
               -- p3 is there
               p123_temp <= p3 - p1_plus_p2_minus_p2upper;
               p1_wait_reg_3 <= p1_wait_reg_2;

               -- stage x+1
               p123_temp_lower_buf <= p123_temp_lower;
               p123 <= p1_wait_reg_3 + p123_temp_upper;
          end if;
     end process;

     p2_regs_rolling: if p2_lower_regs_rolling generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    p2_lower_wait_regs <= p2_lower & p2_lower_wait_regs(0 to p2_lower_wait_regs'length - 2);
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
