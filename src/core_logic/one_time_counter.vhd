----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: one_time_clock
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: A one-time counter used for relaying resets at the correct time
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
     use work.math_utils.all;
     use work.constants_utils.all;

entity one_time_counter is
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
end entity;

architecture Behavioral of one_time_counter is

     constant internal_tripping_value : integer := get_max(0, tripping_value - 1 - bufferchain_length); -- -1 because it takes a cycle for the output to be processed
     signal clk_cnt : unsigned(0 to 1+get_max(1, get_bit_length(internal_tripping_value)) - 1); --+1 for underflow detection
     constant internal_tripping_value_unsigned : unsigned(0 to clk_cnt'length - 1) := to_unsigned(get_max(0,internal_tripping_value-1), clk_cnt'length);-- -1 for underflow detection check

     signal out_bufferchain_input : std_ulogic;
     constant internal_bufferchain_length : integer := bufferchain_length * boolean'pos(bufferchain_length < tripping_value) + (tripping_value) * boolean'pos(not(bufferchain_length < tripping_value));
     signal out_bufferchain : std_ulogic_vector(0 to get_max(1, internal_bufferchain_length) - 1);

     constant triggered_val : std_ulogic_vector(0 to 0) := std_ulogic_vector(to_unsigned(boolean'pos(not out_negated), 1));

begin

     trouble: if tripping_value < 0 generate
          assert false report "Counter has negative tripping value - cannot be correct!" severity error;
     end generate;

     no_delay: if tripping_value = 0 generate
          not_negated: if not out_negated generate
               o_tripped <= not i_reset;
          end generate;
          negated: if out_negated generate
               o_tripped <= i_reset;
          end generate;
     end generate;
     
     with_delay: if not (tripping_value = 0) generate
          o_tripped <= out_bufferchain(out_bufferchain'length - 1);

          counter_present: if bufferchain_length < tripping_value generate
               no_out_bufferchain_logic: if not (bufferchain_length > 0) generate
                    out_bufferchain(out_bufferchain'length - 1) <= out_bufferchain_input;
               end generate;
               out_bufferchain_logic: if bufferchain_length > 0 generate
                    process (i_clk) is
                    begin
                         if rising_edge(i_clk) then
                              out_bufferchain(0) <= out_bufferchain_input;
                              out_bufferchain(1 to out_bufferchain'length - 1) <= out_bufferchain(0 to out_bufferchain'length - 2);
                         end if;
                    end process;
               end generate;

               use_ctn: if internal_tripping_value > 0 generate
                    process (i_clk)
                    begin
                         if rising_edge(i_clk) then
                              if i_reset = '1' then
                                   clk_cnt <= internal_tripping_value_unsigned;
                                   out_bufferchain_input <= not triggered_val(0);
                              else
                                   if clk_cnt(0) = '1' then
                                        out_bufferchain_input <= triggered_val(0);
                                   else
                                        clk_cnt <= clk_cnt - to_unsigned(1, clk_cnt'length);
                                   end if;
                              end if;
                         end if;
                    end process;
               end generate;

               no_ctn: if not (internal_tripping_value > 0) generate
                    process (i_clk) is
                    begin
                         if rising_edge(i_clk) then
                              if i_reset = '1' then
                                   out_bufferchain_input <= not triggered_val(0);
                              else
                                   out_bufferchain_input <= triggered_val(0);
                              end if;
                         end if;
                    end process;
               end generate;

          end generate;

          no_counter_present: if not (bufferchain_length < tripping_value) generate
               process (i_clk) is
               begin
                    if rising_edge(i_clk) then
                         if i_reset = '1' then
                              out_bufferchain(0) <= not triggered_val(0);
                         else
                              out_bufferchain(0) <= triggered_val(0);
                         end if;
                         out_bufferchain(1 to out_bufferchain'length - 1) <= out_bufferchain(0 to out_bufferchain'length - 2);
                    end if;
               end process;
          end generate;
     end generate;
     
end architecture;
