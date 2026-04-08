----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: rotate_polym_with_buffer
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: merges rotate_polym and polym_buffer. This module requires that 2*throughput < num_coefficients,
--             as it takes rotate_polym_reset_clks_ahead clock tics until rotate has processed ai far enough to request coefficients
--             and if the outside module does not provide ai earlier the polym-buffer sends coefficients into nothingness.
-- Dependencies: see imports
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
     use work.datatypes_utils.all;
     use work.constants_utils.all;
     use work.math_utils.all;

entity rotate_polym_with_buffer is
     generic (
          throughput    : integer;
          rotate_right  : boolean;
          rotate_offset : integer;
          negate_polym  : boolean;
          reverse_polym : boolean
     );
     port (
          i_clk               : in  std_ulogic;
          i_reset             : in  std_ulogic;
          i_sub_polym         : in  sub_polynom(0 to throughput - 1);
          i_rotate_by         : in  rotate_idx;
          o_result            : out sub_polynom(0 to throughput - 1);
          o_next_module_reset : out std_ulogic
     );
end entity;

architecture Behavioral of rotate_polym_with_buffer is

     component rotate_polym is
          generic (
               throughput   : integer;
               rotate_right : boolean;
               negated      : boolean
          );
          port (
               i_clk               : in  std_ulogic;
               i_reset             : in  std_ulogic;
               i_sub_coeffs        : in  sub_polynom(0 to throughput - 1);
               i_rotate_by         : in  rotate_idx;
               o_ram_coeff_idx     : out unsigned(0 to get_bit_length((num_coefficients / throughput) - 1) * throughput / 2 - 1);
               o_result            : out sub_polynom(0 to throughput - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     component polym_buffer is
          generic (
               throughput     : integer;
               store_reversed : boolean
          );
          port (
               i_clk               : in  std_ulogic;
               i_reset             : in  std_ulogic;
               i_sub_polym         : in  sub_polynom(0 to throughput - 1);
               i_ram_coeff_idx     : in  unsigned(0 to get_bit_length((num_coefficients / throughput) - 1) * throughput / 2 - 1);
               o_result            : out sub_polynom(0 to throughput - 1);
               o_next_module_reset : out std_ulogic
          );
     end component;

     signal rotate_request_coeff_indices : unsigned(0 to get_bit_length((num_coefficients / throughput) - 1) * throughput / 2 - 1);
     signal rotate_input                 : sub_polynom(0 to throughput - 1);
     signal rotate_reset                 : std_ulogic;
     signal rotate_reset_from_buffer     : std_ulogic;
     constant rotate_by_length : integer := (num_coefficients / throughput) - rotate_polym_reset_clks_ahead - 1 + 1; -- clks till rotate_buffer drops next_stage reset. -1 because of rotate_by_bufferchain_end, +1 to compute index_plus_ai_reduced
     signal rotate_by_bufferchain     : rotate_idx_array(0 to get_max(1, rotate_by_length) - 1);
     
     signal rotate_by_bufferchain_end : rotate_idx;
     signal wait_regs_cnt : unsigned(0 to get_bit_length(rotate_by_bufferchain'length - 1) - 1) := to_unsigned(0, get_bit_length(rotate_by_bufferchain'length - 1));

begin

     rotate_input_buf: polym_buffer
          generic map (
               throughput     => throughput,
               store_reversed => reverse_polym
          )
          port map (
               i_clk               => i_clk,
               i_reset             => i_reset,
               i_sub_polym         => i_sub_polym,
               i_ram_coeff_idx     => rotate_request_coeff_indices,
               o_result            => rotate_input,
               o_next_module_reset => rotate_reset_from_buffer
          );

     rotate_module: rotate_polym
          generic map (
               throughput   => throughput,
               rotate_right => rotate_right,
               negated      => negate_polym
          )
          port map (
               i_clk               => i_clk,
               i_reset             => rotate_reset,
               i_sub_coeffs        => rotate_input,
               i_rotate_by         => rotate_by_bufferchain_end,
               o_ram_coeff_idx     => rotate_request_coeff_indices,
               o_result            => o_result,
               o_next_module_reset => o_next_module_reset
          );

     rotate_reset <= rotate_reset_from_buffer;
     no_bufferchain: if rotate_by_length <= 0 generate
          process (i_clk)
          begin
               if rising_edge(i_clk) then
                    rotate_by_bufferchain(0) <= i_rotate_by + to_unsigned(rotate_offset, i_rotate_by'length);
               end if;
          end process;
          rotate_by_bufferchain_end <= rotate_by_bufferchain(rotate_by_bufferchain'length - 1);
     end generate;

     bufferchain: if not (rotate_by_length <= 0) generate
          rolling_buffer: if rolling_rotate_by_buffer generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         rotate_by_bufferchain(0) <= i_rotate_by + to_unsigned(rotate_offset, i_rotate_by'length);
                         rotate_by_bufferchain(1 to rotate_by_bufferchain'length - 1) <= rotate_by_bufferchain(0 to rotate_by_bufferchain'length - 2);
                         rotate_by_bufferchain_end <= rotate_by_bufferchain(rotate_by_bufferchain'length - 1);
                    end if;
               end process;
          end generate;

          non_rolling_buffer: if not rolling_rotate_by_buffer generate
               process (i_clk)
               begin
                    if rising_edge(i_clk) then
                         if wait_regs_cnt = 0 then
                              wait_regs_cnt <= to_unsigned(rotate_by_bufferchain'length - 1, wait_regs_cnt'length);
                         else
                              wait_regs_cnt <= wait_regs_cnt - to_unsigned(1, wait_regs_cnt'length);
                         end if;
                         rotate_by_bufferchain(to_integer(wait_regs_cnt)) <= i_rotate_by + to_unsigned(rotate_offset, i_rotate_by'length);
                         rotate_by_bufferchain_end <= rotate_by_bufferchain(to_integer(wait_regs_cnt));
                    end if;
               end process;
          end generate;
     end generate;

end architecture;
