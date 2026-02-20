----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: mult_dsp_level
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: 
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

entity mult_dsp_level is
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

architecture Behavioral of mult_dsp_level is

     component default_mult is
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

     component karazuba_mult_dsp_level is
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

     component karazuba_mult_dsp_level_p3 is
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

begin

     karazuba: if karazuba_depth_2 generate
          not_p3: if base_len < 33 generate
               karazuba_mult: karazuba_mult_dsp_level
                    generic map (
                         base_len            => base_len,
                         dsp_retiming_length => dsp_retiming_length
                    )
                    port map (
                         i_clk  => i_clk,
                         i_num0 => i_num0,
                         i_num1 => i_num1,
                         o_res  => o_res
                    );
          end generate;
          is_p3: if not(base_len < 33) generate
          -- p3 is 33x33 which forces an unsigned 17x17 bit multiplication with karazuba, but our DSPs are 27x18 signed and cannot do that cleanly
               -- karazuba_mult: karazuba_mult_dsp_level_p3
               -- karazuba_mult: karazuba_mult_dsp_level
               --      generic map (
               --           base_len            => base_len,
               --           dsp_retiming_length => dsp_retiming_length
               --      )
               --      port map (
               --           i_clk  => i_clk,
               --           i_num0 => i_num0,
               --           i_num1 => i_num1,
               --           o_res  => o_res
               --      );
               mult: default_mult
                    generic map (
                         base_len            => base_len,
                         dsp_retiming_length => default_32_bit_mult_latency
                    )
                    port map (
                         i_clk  => i_clk,
                         i_num0 => i_num0,
                         i_num1 => i_num1,
                         o_res  => o_res
                    );
          end generate;
     end generate;

     mult_default: if not karazuba_depth_2 generate
          mult: default_mult
               generic map (
                    base_len            => base_len,
                    dsp_retiming_length => dsp_retiming_length
               )
               port map (
                    i_clk  => i_clk,
                    i_num0 => i_num0,
                    i_num1 => i_num1,
                    o_res  => o_res
               );
     end generate;

end architecture;
