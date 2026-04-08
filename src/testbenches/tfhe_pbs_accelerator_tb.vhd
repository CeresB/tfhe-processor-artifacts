----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.09.2024 08:38:39
-- Design Name: 
-- Module Name: tfhe_pbs_accelerator_tb - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Testing of the processor, but only in terms of manually testing if values arrive in the correct place and time.
--             Uses the fake version of the pbs for faster simulation.
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
     use IEEE.math_real.all;
library work;
     use work.constants_utils.all;
     use work.datatypes_utils.all;
     use work.ip_cores_constants.all;
     use work.tfhe_constants.all;
     use work.processor_utils.all;

entity tfhe_pbs_accelerator_tb is
     --  Port ( );
end entity;

architecture Behavioral of tfhe_pbs_accelerator_tb is

     component tfhe_pbs_accelerator is
          port (
               i_clk               : in  std_ulogic;
               i_reset_n           : in  std_ulogic;
               i_ram_coeff_idx     : in  unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
               -- o_return_address    : out hbm_ps_port_memory_address;
               o_out_data          : out sub_polynom(0 to pbs_throughput - 1);
               o_next_module_reset : out std_ulogic;
               -- hbm related in / out signals
               i_ai_hbm_out        : in  hbm_ps_out_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
               i_bsk_hbm_out       : in  hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
               i_op_hbm_out        : in  hbm_ps_out_read_pkg;
               i_lut_hbm_out       : in  hbm_ps_out_read_pkg;
               i_b_hbm_out         : in  hbm_ps_out_read_pkg;
               o_ai_hbm_in         : out hbm_ps_in_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
               o_bsk_hbm_in        : out hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
               o_op_hbm_in         : out hbm_ps_in_read_pkg;
               o_lut_hbm_in        : out hbm_ps_in_read_pkg;
               o_b_hbm_in          : out hbm_ps_in_read_pkg
          );
     end component;

     signal clk         : std_logic := '0';
     signal sim_reset_n : std_logic := '0';
     -- signal sim_reset_n_delayed : std_logic := '0';
     signal finished : std_logic := '0';

     constant TIME_DELTA : time := 10 ns;
     constant clk_period : time := TIME_DELTA * 2;
     -- constant throughput : integer := pbs_throughput;
     signal clk_cnt : integer;

     signal all_in_raw                  : std_logic_vector(0 to hbm_data_width - 1);
     signal all_in_raw_reversed         : std_logic_vector(hbm_data_width - 1 downto 0);
     signal all_in_raw_negated          : std_logic_vector(0 to hbm_data_width - 1);
     signal all_in_raw_negated_reversed : std_logic_vector(hbm_data_width - 1 downto 0);

     -- constant test_addresses_per_bsk: integer := addresses_per_bsk;
     constant test_blind_rot_iter_latency         : integer := blind_rot_iter_latency;         -- v4p ignore w-303
     constant test_blind_rot_iter_minimum_latency : integer := blind_rot_iter_minimum_latency; -- v4p ignore w-303
     constant test_blind_rot_iter_extra_latency   : integer := blind_rot_iter_extra_latency;   -- v4p ignore w-303
     constant test_blind_rotation_latency         : integer := blind_rotation_latency;         -- v4p ignore w-303

     constant channel_op_idx  : integer := 0;
     constant channel_lut_idx : integer := 1;
     constant channel_ai_idx  : integer := 2;
     constant channel_b_idx   : integer := 3;
     -- constant channel_result_idx : integer := 4;
     -- constant channel_bsk_idx    : integer := 5;
     constant num_channels : integer := 6;
     signal bsk_hbm_out      : hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
     signal bsk_hbm_in       : hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
     signal lwe_n_buf_rq_idx : unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
     -- signal lwe_n_buf_out              : sub_polynom(0 to pbs_throughput - 1);
     -- signal lwe_n_buf_out_valid        : std_ulogic;
     -- signal lwe_n_buf_write_next_reset : std_ulogic;
     signal read_out_pkgs_stack_1 : hbm_ps_out_read_pkg_arr(0 to num_channels - 1);
     signal read_in_pkgs_stack_1  : hbm_ps_in_read_pkg_arr(0 to num_channels - 1);
     signal ai_hbm_out            : hbm_ps_out_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
     signal ai_hbm_in             : hbm_ps_in_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);

     signal all_in_coeff_format : sub_polynom(0 to hbm_coeffs_per_clock_per_ps_port - 1);

begin

     clk <= not clk after TIME_DELTA when finished /= '1' else '0';

     dut: tfhe_pbs_accelerator
          port map (
               i_clk               => clk,
               i_reset_n           => sim_reset_n,
               i_ram_coeff_idx     => lwe_n_buf_rq_idx,
               i_ai_hbm_out        => ai_hbm_out,
               i_bsk_hbm_out       => bsk_hbm_out,
               i_op_hbm_out        => read_out_pkgs_stack_1(channel_op_idx),
               i_lut_hbm_out       => read_out_pkgs_stack_1(channel_lut_idx),
               i_b_hbm_out         => read_out_pkgs_stack_1(channel_b_idx),
               -- o_return_address    => open,
               o_out_data          => open, --lwe_n_buf_out,
               o_next_module_reset => open, --lwe_n_buf_write_next_reset,
               o_ai_hbm_in         => ai_hbm_in,
               o_bsk_hbm_in        => bsk_hbm_in,
               o_op_hbm_in         => read_in_pkgs_stack_1(channel_op_idx),
               o_lut_hbm_in        => read_in_pkgs_stack_1(channel_lut_idx),
               o_b_hbm_in          => read_in_pkgs_stack_1(channel_b_idx)
          );
     -- current setting: only one hbm port for ai
     ai_hbm_out(0)                        <= read_out_pkgs_stack_1(channel_ai_idx);
     read_in_pkgs_stack_1(channel_ai_idx) <= ai_hbm_in(0);

     process (clk)
     begin
          if rising_edge(clk) then
               if sim_reset_n = '0' then
                    clk_cnt <= 0;
               else
                    clk_cnt <= clk_cnt + 1;
               end if;
               -- sim_reset_n_delayed <= sim_reset_n;
               lwe_n_buf_rq_idx <= to_unsigned(clk_cnt mod write_blocks_in_lwe_n_ram, lwe_n_buf_rq_idx'length);
               for i in 0 to all_in_coeff_format'length - 1 loop
                    all_in_coeff_format(i) <= to_unsigned(clk_cnt, all_in_coeff_format(0)'length);
                    all_in_raw(i * unsigned_polym_coefficient_bit_width to (i + 1) * unsigned_polym_coefficient_bit_width - 1) <= std_logic_vector(all_in_coeff_format(i));
               end loop;
               all_in_raw_negated <= std_logic_vector(to_unsigned(0, all_in_raw'length) - to_unsigned(clk_cnt, all_in_raw'length));
          end if;
     end process;

     reverse_bits: for bit_idx in 0 to all_in_raw'length - 1 generate
          -- the reversal happens because one variable is (0 to ...) and the other is (... downto 0)
          all_in_raw_reversed(bit_idx)         <= all_in_raw(bit_idx);
          all_in_raw_negated_reversed(bit_idx) <= all_in_raw_negated(bit_idx);
     end generate;

     bsk_channel_map: for channel_idx in 0 to bsk_hbm_out'length - 1 generate
          bsk_hbm_out(channel_idx).rdata        <= all_in_raw_reversed;
          process (clk) is
          begin
            if rising_edge(clk) then
               bsk_hbm_out(channel_idx).rvalid       <= bsk_hbm_in(channel_idx).arvalid;
            end if;
          end process;
          bsk_hbm_out(channel_idx).arready      <= '1';
          bsk_hbm_out(channel_idx).rdata_parity <= (others => '0');
          bsk_hbm_out(channel_idx).rid          <= std_logic_vector(to_unsigned(clk_cnt, hbm_id_bit_width));
          bsk_hbm_out(channel_idx).rlast        <= '0';
          bsk_hbm_out(channel_idx).rresp        <= (others => '0');
     end generate;

     channel_map: for channel_idx in 0 to read_out_pkgs_stack_1'length - 1 generate
          if_op_buf: if channel_idx = channel_op_idx generate
               read_out_pkgs_stack_1(channel_idx).rdata <= all_in_raw_reversed;
          end generate;
          if_b_buf: if channel_idx = channel_b_idx generate
               -- only the first coefficient is used for anything so we must make sure it contains something changing in the testbench
               read_out_pkgs_stack_1(channel_idx).rdata <= std_logic_vector(shift_right(unsigned(all_in_raw_reversed), 3 * unsigned_polym_coefficient_bit_width));
          end generate;
          if_ai_buf: if channel_idx = channel_ai_idx generate
               read_out_pkgs_stack_1(channel_idx).rdata <= all_in_raw_reversed;
          end generate;
          if_lut_buf: if channel_idx = channel_lut_idx generate
               read_out_pkgs_stack_1(channel_idx).rdata <= all_in_raw_reversed;
          end generate;
          process (clk) is
          begin
            if rising_edge(clk) then
               read_out_pkgs_stack_1(channel_idx).rvalid       <= read_in_pkgs_stack_1(channel_idx).arvalid;
            end if;
          end process;
          read_out_pkgs_stack_1(channel_idx).arready      <= '1';
          read_out_pkgs_stack_1(channel_idx).rdata_parity <= (others => '0');
          read_out_pkgs_stack_1(channel_idx).rid          <= std_logic_vector(to_unsigned(clk_cnt, hbm_id_bit_width));
          read_out_pkgs_stack_1(channel_idx).rlast        <= '0';
          read_out_pkgs_stack_1(channel_idx).rresp        <= (others => '0');
     end generate;

     simulation: process
     begin
          sim_reset_n <= '0';

          wait until rising_edge(clk);
          -- reset must be active at least throughput-many clock cycles for the high-fanout-counters
          for i in 0 to pbs_throughput - 1 loop
               wait for clk_period;
          end loop;

          sim_reset_n <= '1';

          report "Waiting too long? Check k_lwe parameter setting! It is set to " & integer'image(k_lwe) severity note;

          wait for TIME_DELTA; -- so that there can be no confusion when reading the output signal

          report "Check correctness manually!" severity warning;
          -- finished <= '1';
          wait;
     end process;

end architecture;
