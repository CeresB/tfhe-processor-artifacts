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
     use work.datatypes_utils.all;
     use work.math_utils.all;
     use work.ntt_utils.all;

entity top is
     port (clk_pin_p : in  STD_LOGIC;
           clk_pin_n : in  STD_LOGIC;
           led_pins  : out STD_LOGIC_VECTOR(7 downto 0) -- v4p ignore w-302
          );
end entity;

architecture Behavioral of top is
     constant throughput : integer := 2 ** log2_ntt_throughput;

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
               i_reset             : in  std_ulogic; -- reset must be 1 for at least ram_retiming_latency tics to set up the twiddle factors!
               i_sub_polym         : in  sub_polynom(0 to throughput - 1);
               o_result            : out sub_polynom(0 to throughput - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     component manual_constant_bram is
          generic (
               ram_content         : sub_polynom;
               addr_length         : integer;
               ram_out_bufs_length : integer;
               ram_type            : string
          );
          port (
               i_clk     : in  std_ulogic;
               i_rd_addr : in  unsigned(0 to addr_length - 1);
               o_data    : out synthesiseable_uint
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

     constant num_leds             : integer := 8;
     constant input_ram_num_coeffs : integer := 2 ** log2_coeffs_per_bram; -- vivado optimizes this away for some reason

     -- clock and controls
     signal clk_signal : std_logic := 'U';
     signal ntt_not_ready : std_logic;

     signal led_o        : std_ulogic_vector(0 to num_leds - 1);
     signal led_o_buffer : std_ulogic_vector(0 to num_leds - 1);

     signal ntt_reset        : std_ulogic := '1';
     signal ntt_result       : sub_polynom(0 to throughput - 1);
     signal ntt_input        : sub_polynom(0 to throughput - 1);
     signal ntt_input_buf        : sub_polynom(0 to throughput - 1);
     signal in_data        : sub_polynom(0 to throughput - 1);
     
     constant cnt_buffer_length    : integer := 2 * log2_ntt_throughput;
     type in_coeff_cnt_type is array (natural range <>) of unsigned(0 to get_bit_length(input_ram_num_coeffs - 1) - 1);
     signal ntt_in_coeff_cnt : in_coeff_cnt_type(0 to cnt_buffer_length - 1);

     constant num_leds_for_ntt_result : integer := get_min(led_o_buffer'length, ntt_result'length);
     constant num_other_leds          : integer := get_max(num_leds - num_leds_for_ntt_result, 0);

     signal led_secondary : std_logic_vector(num_other_leds - 1 downto 0) := (others => 'U');
     signal reset         : std_ulogic_vector(0 to 100 - 1)               := (others => '1');
     signal bits_cnt: unsigned(0 to get_bit_length(synthesiseable_uint'length-1)-1) := to_unsigned(0, get_bit_length(synthesiseable_uint'length-1));

     constant input_ram_content : sub_polynom(0 to throughput * input_ram_num_coeffs - 1) := get_random_test_sub_polym(throughput * input_ram_num_coeffs, 1234);

     -- attribute dont_touch               : string;
     -- attribute dont_touch of ntt_input  : signal is "true";
     -- attribute dont_touch of ntt_result : signal is "true";

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

     are_other_leds: if led_secondary'length > 1 generate
          other_leds_control: for i in 0 to led_secondary'length - 1 generate
               led_o(led_o'length - 1 - i) <= led_secondary(i);
          end generate;
          -- instantiate the LED controller
          led_ctl_i0: blink_logic
               port map (
                    clk_rx => clk_signal,
                    led_o  => led_secondary
               );
     end generate;

     -- the main code
     my_ntt: ntt
          generic map (
               throughput                => throughput,
               ntt_params                => ntt_params,
               invers                    => false,
               intt_no_final_reduction   => false,
               no_first_last_stage_logic => true
          )
          port map (
               i_clk               => clk_signal,
               i_reset             => ntt_reset,
               i_sub_polym         => ntt_input_buf,
               o_result            => ntt_result,
               o_next_module_reset => ntt_not_ready
          );

     in_coeff_cnt_logic: process (clk_signal) is
     begin
          if rising_edge(clk_signal) then
               if reset(reset'length - 1) = '1' then
                    ntt_in_coeff_cnt(0) <= to_unsigned(0, ntt_in_coeff_cnt(0)'length);
               else
                    ntt_in_coeff_cnt(0) <= ntt_in_coeff_cnt(0) + to_unsigned(1, ntt_in_coeff_cnt(0)'length);
               end if;
               ntt_in_coeff_cnt(1 to ntt_in_coeff_cnt'length - 1) <= ntt_in_coeff_cnt(0 to ntt_in_coeff_cnt'length - 2);
          end if;
     end process;

     process (clk_signal)
     begin
          if rising_edge(clk_signal) then
               reset(0) <= '0';
               reset(1 to reset'length - 1) <= reset(0 to reset'length - 2);
               bits_cnt <= bits_cnt + to_unsigned(1, bits_cnt'length);

               for i in 0 to num_leds_for_ntt_result - 1 loop
                    led_o(i) <= std_ulogic(ntt_result(i + to_integer(ntt_in_coeff_cnt(ntt_in_coeff_cnt'length-1)))(to_integer(bits_cnt)));
               end loop;
               led_o_buffer <= led_o;
               ntt_input_buf <= ntt_input;
               if ntt_not_ready='0' then
                    ntt_input <= ntt_result;
               else
                    ntt_input <= in_data;
               end if;
          end if;
     end process;

     input_ram_blocks: for coeff_idx in 0 to ntt_input'length - 1 generate
          input_ram: manual_constant_bram
               generic map (
                    ram_content         => input_ram_content(coeff_idx * input_ram_num_coeffs to (coeff_idx + 1) * input_ram_num_coeffs - 1),
                    addr_length         => ntt_in_coeff_cnt(0)'length,
                    ram_out_bufs_length => minimum_ram_retiming_latency,
                    ram_type            => ram_style_auto
               )
               port map (
                    i_clk     => clk_signal,
                    i_rd_addr => ntt_in_coeff_cnt(ntt_in_coeff_cnt'length-1),
                    o_data    => in_data(coeff_idx)
               );
     end generate;

end architecture;
