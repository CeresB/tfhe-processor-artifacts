----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 08:14:04
-- Design Name: 
-- Module Name: top_pbs - Behavioral
-- Project Name: TFHE FPGA Acceleration
-- Target Devices: Virtex Ultrascale+ VCU128
-- Tool Versions: Vivado 2024.1
-- Description: Used to instantiate the PBS module on the FPGA to measure
--             its max operating freqeuncy and resource consumption.
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
     use IEEE.math_real.all;
library work;
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.ntt_utils.all;
     use work.tfhe_utils.all;
     use work.tfhe_constants.all;
     use work.math_utils.all;
     use work.processor_utils.all;

entity top is
     port (clk_pin_p  : in  STD_LOGIC;
           clk_pin_n  : in  STD_LOGIC;
           led_pins   : out STD_LOGIC_VECTOR(7 downto 0) -- v4p ignore w-302
          );
end entity;

architecture Behavioral of top is

     component pbs is
          generic (
               throughput                     : integer;
               decomposition_length           : integer; -- for the external product
               num_LSBs_to_round              : integer; -- for the external product
               bits_per_slice                 : integer; -- for the external product
               polyms_per_ciphertext          : integer; -- for the external product
               min_latency_till_monomial_mult : integer; -- for the external product
               num_iterations                 : integer  -- for the blind rotation
          );
          port (
               i_clk                : in  std_ulogic;
               i_reset              : in  std_ulogic;
               i_lookup_table_part  : in  sub_polynom(0 to throughput - 1); -- for the programmable bootstrapping, only a part of an RLWE ciphertext
               i_lwe_b              : in  rotate_idx;
               i_lwe_ai             : in  rotate_idx;
               i_BSK_i_part         : in  sub_polynom(0 to throughput * decomposition_length * polyms_per_ciphertext - 1);
               i_sample_extract_idx : in  idx_int;
               o_sample_extract_idx : out idx_int;
               o_result             : out sub_polynom(0 to throughput - 1);
               o_next_module_reset  : out std_ulogic
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

     constant num_leds : integer := 8;

     constant throughput : integer := pbs_throughput;

     -- clock and controls
     signal clk_signal   : std_logic                               := 'U';
     signal led_o        : std_logic_vector(num_leds - 1 downto 0) := (others => 'U');
     signal led_o_buffer : std_logic_vector(0 to led_o'length - 1);

     signal pbs_lut  : sub_polynom(0 to throughput - 1);

     signal ai     : rotate_idx;
     signal ai_raw : synthesiseable_uint;
     signal b_val : rotate_idx;
     signal b_val_raw : synthesiseable_uint;

     signal bsk_i_part : sub_polynom(0 to throughput * decomp_length * num_polyms_per_rlwe_ciphertext - 1);
     -- constant bski_num_coeffs: integer := num_polyms_per_rlwe_ciphertext * decomp_length * num_coefficients;
     constant bski_ram_num_coeffs  : integer := 2 ** log2_coeffs_per_bram; --num_coefficients / throughput;
     constant input_ram_num_coeffs : integer := 2 ** (log2_coeffs_per_bram);
     constant ai_ram_num_coeffs    : integer := 2 ** (log2_coeffs_per_bram - 2);
     constant b_ram_num_coeffs    : integer := 2 * pbs_batchsize;
     constant cnt_buffer_length    : integer := 2;
     constant extra_buf_retiming_latency    : integer := 0;

     type br_in_coeff_cnt_type is array (natural range <>) of unsigned(0 to get_bit_length(input_ram_num_coeffs - 1) - 1);
     signal br_in_coeff_cnt : br_in_coeff_cnt_type(0 to cnt_buffer_length - 1);
     type bsk_coeff_cnt_type is array (natural range <>) of unsigned(0 to get_bit_length(bski_ram_num_coeffs - 1) - 1);
     signal bsk_coeff_cnt : bsk_coeff_cnt_type(0 to cnt_buffer_length - 1);
     type ai_coeff_cnt_type is array (natural range <>) of unsigned(0 to get_bit_length(ai_ram_num_coeffs - 1) - 1);
     signal ai_coeff_cnt : ai_coeff_cnt_type(0 to cnt_buffer_length - 1);
     type b_coeff_cnt_type is array (natural range <>) of unsigned(0 to get_bit_length(b_ram_num_coeffs - 1) - 1);
     signal b_coeff_cnt : b_coeff_cnt_type(0 to cnt_buffer_length - 1);

     signal reset : std_ulogic_vector(0 to 15 - 1) := (others => '1');

     constant bski_ram_content  : sub_polynom(0 to bsk_i_part'length * bski_ram_num_coeffs - 1) := get_random_test_sub_polym(bsk_i_part'length * bski_ram_num_coeffs, 123);
     constant input_ram_content : sub_polynom(0 to throughput * input_ram_num_coeffs - 1)       := get_random_test_sub_polym(throughput * input_ram_num_coeffs, 1234);
     constant ai_ram_content    : sub_polynom(0 to ai_ram_num_coeffs - 1)                       := get_random_test_sub_polym(ai_ram_num_coeffs, 12345);
     constant b_ram_content    : sub_polynom(0 to b_ram_num_coeffs - 1)                       := get_random_test_sub_polym(b_ram_num_coeffs, 6789);

     signal pbs_lookup_table_part_buffer : sub_polynom(0 to throughput - 1);
     signal pbs_result            : sub_polynom(0 to throughput - 1);
     signal pbs_display_coeff_cnt : idx_int    := to_unsigned(0, log2_num_coefficients);

     constant num_leds_for_pbs_result : integer := get_min(num_leds, pbs_result'length);
     constant num_other_leds          : integer := num_leds - num_leds_for_pbs_result;

     signal led_secondary : std_logic_vector(num_other_leds - 1 downto 0) := (others => 'U');

     attribute dont_touch               : string;
     attribute dont_touch of pbs_result  : signal is "true";
     attribute dont_touch of bsk_i_part : signal is "true";

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
     my_pbs: pbs
          generic map (
               throughput                     => throughput,
               decomposition_length           => decomp_length,
               num_LSBs_to_round              => decomp_num_LSBs_to_round,
               bits_per_slice                 => log2_decomp_base,
               polyms_per_ciphertext          => num_polyms_per_rlwe_ciphertext,
               min_latency_till_monomial_mult => blind_rot_iter_min_latency_till_monomial_mult,
               num_iterations                 => k_lwe
          )
          port map (
               i_clk                => clk_signal,
               i_reset              => reset(reset'length - 1),
               i_lookup_table_part  => pbs_lookup_table_part_buffer,
               i_lwe_b              => b_val,
               i_lwe_ai             => ai,
               i_BSK_i_part         => bsk_i_part,
               i_sample_extract_idx => sample_extract_default_sample_extract_idx,
               o_sample_extract_idx => open,
               o_result             => pbs_result,
               o_next_module_reset  => open
          );

     in_coeff_cnt_logic: process (clk_signal) is
     begin
          if rising_edge(clk_signal) then
               if reset(reset'length - 1) = '1' then
                    br_in_coeff_cnt(0) <= to_unsigned(0, br_in_coeff_cnt(0)'length);
               else
                    br_in_coeff_cnt(0) <= br_in_coeff_cnt(0) + to_unsigned(1, br_in_coeff_cnt(0)'length);
               end if;
               br_in_coeff_cnt(1 to br_in_coeff_cnt'length - 1) <= br_in_coeff_cnt(0 to br_in_coeff_cnt'length - 2);
          end if;
     end process;

     ai_coeff_cnt_logic: process (clk_signal) is
     begin
          if rising_edge(clk_signal) then
               if reset(reset'length - 1) = '1' then
                    ai_coeff_cnt(0) <= to_unsigned(0, ai_coeff_cnt(0)'length);
               else
                    ai_coeff_cnt(0) <= ai_coeff_cnt(0) + to_unsigned(1, ai_coeff_cnt(0)'length);
               end if;
               ai_coeff_cnt(1 to ai_coeff_cnt'length - 1) <= ai_coeff_cnt(0 to ai_coeff_cnt'length - 2);
          end if;
     end process;

     b_coeff_cnt_logic: process (clk_signal) is
     begin
          if rising_edge(clk_signal) then
               if reset(reset'length - 1) = '1' then
                    b_coeff_cnt(0) <= to_unsigned(0, b_coeff_cnt(0)'length);
               else
                    b_coeff_cnt(0) <= b_coeff_cnt(0) + to_unsigned(1, b_coeff_cnt(0)'length);
               end if;
               b_coeff_cnt(1 to b_coeff_cnt'length - 1) <= b_coeff_cnt(0 to b_coeff_cnt'length - 2);
          end if;
     end process;

     bsk_coeff_cnt_logic: process (clk_signal) is
     begin
          if rising_edge(clk_signal) then
               if reset(reset'length - 1) = '1' then
                    bsk_coeff_cnt(0) <= to_unsigned(0, bsk_coeff_cnt(0)'length);
               else
                    bsk_coeff_cnt(0) <= bsk_coeff_cnt(0) + to_unsigned(1, bsk_coeff_cnt(0)'length);
               end if;
               bsk_coeff_cnt(1 to bsk_coeff_cnt'length - 1) <= bsk_coeff_cnt(0 to bsk_coeff_cnt'length - 2);
          end if;
     end process;

     process (clk_signal)
     begin
          if rising_edge(clk_signal) then
               led_o_buffer <= led_o;
               reset(0) <= '0';
               reset(1 to reset'length - 1) <= reset(0 to reset'length - 2);
               pbs_lookup_table_part_buffer <= pbs_lut;

               for i in 0 to num_leds_for_pbs_result - 1 loop
                    led_o(i) <= std_ulogic(pbs_result(i + to_integer(pbs_display_coeff_cnt))(0));
               end loop;
          end if;
     end process;

     input_ram_blocks: for coeff_idx in 0 to pbs_lut'length - 1 generate
          input_ram: manual_constant_bram
               generic map (
                    ram_content         => input_ram_content(coeff_idx * input_ram_num_coeffs to (coeff_idx + 1) * input_ram_num_coeffs - 1),
                    addr_length         => br_in_coeff_cnt(0)'length,
                    ram_out_bufs_length => default_ram_retiming_latency+extra_buf_retiming_latency,
                    ram_type            => ram_style_auto
               )
               port map (
                    i_clk     => clk_signal,
                    i_rd_addr => br_in_coeff_cnt(br_in_coeff_cnt'length - 1),
                    o_data    => pbs_lut(coeff_idx)
               );
     end generate;

     bski_ram_blocks: for bski_coeff_idx in 0 to bsk_i_part'length - 1 generate
          bski_ram: manual_constant_bram
               generic map (
                    ram_content         => bski_ram_content(bski_coeff_idx * bski_ram_num_coeffs to (bski_coeff_idx + 1) * bski_ram_num_coeffs - 1),
                    addr_length         => bsk_coeff_cnt(0)'length,
                    ram_out_bufs_length => default_ram_retiming_latency+extra_buf_retiming_latency,
                    ram_type            => ram_style_auto
               )
               port map (
                    i_clk     => clk_signal,
                    i_rd_addr => bsk_coeff_cnt(bsk_coeff_cnt'length - 1),
                    o_data    => bsk_i_part(bski_coeff_idx)
               );
     end generate;

     b_ram: manual_constant_bram
          generic map (
               ram_content         => b_ram_content,
               addr_length         => b_coeff_cnt(0)'length,
               ram_out_bufs_length => default_ram_retiming_latency+extra_buf_retiming_latency,
               ram_type            => ram_style_auto
          )
          port map (
               i_clk     => clk_signal,
               i_rd_addr => b_coeff_cnt(b_coeff_cnt'length - 1),
               o_data    => b_val_raw
          );
     b_val <= b_val_raw(b_val_raw'length - b_val'length to b_val_raw'length - 1);

     ai_ram: manual_constant_bram
          generic map (
               ram_content         => ai_ram_content,
               addr_length         => ai_coeff_cnt(0)'length,
               ram_out_bufs_length => default_ram_retiming_latency+extra_buf_retiming_latency,
               ram_type            => ram_style_auto
          )
          port map (
               i_clk     => clk_signal,
               i_rd_addr => ai_coeff_cnt(ai_coeff_cnt'length - 1),
               o_data    => ai_raw
          );
     ai <= ai_raw(ai_raw'length - ai'length to ai_raw'length - 1);

end architecture;
