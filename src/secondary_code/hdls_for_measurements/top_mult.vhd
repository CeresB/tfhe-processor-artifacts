----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 08:14:04
-- Design Name: 
-- Module Name: top_ntt - Behavioral
-- Project Name: TFHE FPGA Acceleration
-- Target Devices: Virtex Ultrascale+ VCU128
-- Tool Versions: Vivado 2024.1
-- Description: Used to instantiate the ntt on the FPGA to measure
--             its max operating frequency and resource consumption.
--             The outputs are piped to the FPGA's LEDs, such that Vivado does not
--             optimize logic away during implementation.
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.numeric_std.all;

library UNISIM;
     use UNISIM.VComponents.all; -- v4p ignore e-202

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.NUMERIC_STD.all;
library work;
     use work.constants_utils.all;

entity top is
     port (clk_pin_p  : in  STD_LOGIC;
           clk_pin_n  : in  STD_LOGIC;
           led_pins   : out STD_LOGIC_VECTOR(7 downto 0) -- v4p ignore w-302
          );
end entity;

architecture Behavioral of top is

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

     component karazuba_mult is
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
     end component;

     -- we keep blink logic, so that we know for certain when the fpga is running
     component blink_logic is
          port (
               clk_rx : in  std_logic;
               led_o  : out std_logic_vector
          );
     end component;

     component clk_wiz_0 is
          port (clk_in1_p : in  std_logic;
                clk_in1_n : in  std_logic;
                clk_out1  : out std_logic
               );
     end component;
     
     constant num_leds                  : integer := 8;

     signal clk_signal : std_logic := 'U';

     signal led_o        : std_ulogic_vector(0 to num_leds - 1);
     signal led_o_buffer : std_ulogic_vector(0 to num_leds - 1);

     constant base_len: integer := 64;
     subtype mult_in_type_num is unsigned(0 to base_len - 1);
     signal mult_input0: mult_in_type_num := to_unsigned(1,base_len);
     signal mult_input1: mult_in_type_num := to_unsigned(1,base_len);
     signal mult_res: unsigned(0 to 2 * base_len - 1);

     attribute dont_touch               : string;
     attribute dont_touch of mult_res  : signal is "true";

begin

     -- define the buffers for the incoming data, clocks, and control
     clk_core_inst: clk_wiz_0
          port map (clk_in1_p => clk_pin_p,
                    clk_in1_n => clk_pin_n,
                    clk_out1  => clk_signal
          );

     -- define the buffers for the outgoing data
     OBUF_led_ix: for j in 0 to led_o_buffer'length - 1 generate
          OBUF_led_i: OBUF port map (I => led_o_buffer(j), O => LED_pins(j)); -- v4p ignore e-202
     end generate;

     led_control: for i in 0 to num_leds - 1 generate
          led_o(i) <= mult_res(i);
     end generate;

     -- the main code
     -- kara_mult: mult_dsp_level
     --      generic map (
     --           base_len            => base_len,
     --           dsp_retiming_length => dsp_level_retiming_registers
     --      )
     --      port map (
     --           i_clk  => clk_signal,
     --           i_num0 => mult_input0,
     --           i_num1 => mult_input1,
     --           o_res  => mult_res
     --      );
     -- def_mult: default_mult
     --      generic map (
     --           base_len            => base_len,
     --           dsp_retiming_length => dsp_level_retiming_registers
     --      )
     --      port map (
     --           i_clk  => clk_signal,
     --           i_num0 => mult_input0,
     --           i_num1 => mult_input1,
     --           o_res  => mult_res
     --      );
     kara_mult: karazuba_mult
          generic map (
               base_len            => 32,
               dsp_retiming_length => dsp_level_retiming_registers
          )
          port map (
               i_clk  => clk_signal,
               i_num0 => mult_input0,
               i_num1 => mult_input1,
               o_res  => mult_res
          );

     process (clk_signal)
     begin
          if rising_edge(clk_signal) then
               led_o_buffer <= led_o;
               mult_input0 <= mult_input0 + to_unsigned(1,mult_input0'length-1);
               mult_input1 <= mult_input1 + to_unsigned(1,mult_input1'length-1);
          end if;
     end process;

end architecture;
