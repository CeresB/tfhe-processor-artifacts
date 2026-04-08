----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: shift_array
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: shifting an array in stages for less congestion
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

entity shift_array is
     generic (
          log2_arr_len : integer;
          num_stages : integer -- must be smaller log2_arr_len, can be 0
     );
     port (
          i_clk  : in  std_ulogic;
          i_arr : in  sub_polynom(0 to (2**log2_arr_len)-1);
          i_shift : in  unsigned(0 to log2_arr_len-1);
          o_res  : out sub_polynom(0 to (2**log2_arr_len)-1)
     );
end entity;

architecture Behavioral of shift_array is

     constant sanitized_stage_num: integer := get_min(log2_arr_len,num_stages);
     constant internal_num_stages: integer := sanitized_stage_num + 1*boolean'pos(sanitized_stage_num=log2_arr_len-1); -- if there is just one stage left, do it in a proper stage

     type wait_registers_sub_polym is array (natural range <>) of sub_polynom(0 to o_res'length - 1);
     type wait_registers_shift_int is array (natural range <>) of unsigned(0 to i_shift'length-1);
     signal temp_shift_arr: wait_registers_sub_polym(0 to internal_num_stages+1-1); -- +1 for the end piece
     signal shift_int: wait_registers_shift_int(0 to temp_shift_arr'length-1-1*boolean'pos(not (internal_num_stages < log2_arr_len)));
     -- signal temp_shift_arr: wait_registers_sub_polym(0 to log2_arr_len+1-1);
     -- signal shift_int: wait_registers_shift_int(0 to internal_num_stages-1*boolean'pos(not (internal_num_stages < log2_arr_len)));

begin

    temp_shift_arr(0) <= i_arr;
    shift_int(0) <= i_shift;
    process (i_clk) is
    begin
      if rising_edge(i_clk) then
        shift_int(1 to shift_int'length-1) <= shift_int(0 to shift_int'length-2);
      end if;
    end process;

    end_shift: if internal_num_stages < log2_arr_len generate
     -- shift the rest in one cycle with many connections

        process (i_clk) is
        begin
        if rising_edge(i_clk) then
            for i in 0 to i_arr'length - 1 loop
                o_res(i) <= temp_shift_arr(temp_shift_arr'length-1)(to_integer(to_unsigned(i, shift_int(0)'length) + shift_int(shift_int'length - 1)(num_stages to shift_int(0)'length-1)));
            end loop;
        end if;
        end process;

          -- shift_end: for stage_idx in internal_num_stages to temp_shift_arr'length-2 generate
          --      temp_shift_arr(stage_idx+1) <= temp_shift_arr(stage_idx)(2**(log2_arr_len-1-stage_idx) to temp_shift_arr(0)'length-1) & temp_shift_arr(stage_idx)(0 to 2**(log2_arr_len-1-stage_idx)-1) when shift_int(shift_int'length-1)(stage_idx) = '1' else temp_shift_arr(stage_idx);
          --      process (i_clk) is
          --      begin
          --           if rising_edge(i_clk) then
          --           o_res <= temp_shift_arr(temp_shift_arr'length-1);
          --           end if;
          --      end process;
          -- end generate;
    end generate;
    no_end_shift: if not (internal_num_stages < log2_arr_len) generate
     o_res <= temp_shift_arr(temp_shift_arr'length-1);
    end generate;

     shift_stage: for stage_idx in 0 to internal_num_stages-1 generate
        process (i_clk) is
        begin
        if rising_edge(i_clk) then
               if shift_int(stage_idx)(stage_idx) = '1' then
                    temp_shift_arr(stage_idx+1) <= temp_shift_arr(stage_idx)(2**(log2_arr_len-1-stage_idx) to temp_shift_arr(0)'length-1) & temp_shift_arr(stage_idx)(0 to 2**(log2_arr_len-1-stage_idx)-1);
               else
                    temp_shift_arr(stage_idx+1) <= temp_shift_arr(stage_idx);
               end if;
        end if;
        end process;
     end generate;


end architecture;
