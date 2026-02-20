----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ntt_out_buf
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: This is the output buffer for the NTT-results in a blind rotation iteration.
--              It requires its own file due to the complexity involved to make Vivado
--             implement this in memory.
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
library work;
     use work.datatypes_utils.all;
     use work.constants_utils.all;
     use work.math_utils.all;
     use work.tfhe_utils.all;
     use work.tfhe_constants.all;

entity ntt_out_buf is
     generic (
          throughput            : integer;
          num_ntts              : integer;
          polyms_per_ciphertext : integer;
          ram_retiming_latency  : integer
     );
     port (
          i_clk               : in  std_ulogic;
          i_reset             : in  std_ulogic;                                  -- must be 1 clock tic earlier than i_result_ntt for computation of the addresses
          i_result_ntt        : in  sub_polynom(0 to throughput * num_ntts - 1); -- no buffer! you read it from memory anyway and it does not change during the computation
          o_result            : out sub_polynom(0 to throughput * num_ntts * polyms_per_ciphertext - 1);
          o_next_module_reset : out std_ulogic
     );
end entity;

architecture Behavioral of ntt_out_buf is

     component one_time_counter is
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
     end component;

     component manual_bram is
          generic (
               addr_length         : integer;
               ram_length          : integer;
               ram_out_bufs_length : integer;
               ram_type            : string;
               coeff_bit_width     : integer
          );
          port (
               i_clk     : in  std_ulogic;
               i_wr_en   : in  std_ulogic;
               i_wr_data : in  unsigned(0 to coeff_bit_width - 1);
               i_wr_addr : in  unsigned(0 to addr_length - 1);
               i_rd_addr : in  unsigned(0 to addr_length - 1);
               o_data    : out unsigned(0 to coeff_bit_width - 1)
          );
     end component;

     -- ram_unit has at max 1 read and 1 write per clock tic
     -- we work with a ping-pong buffer
     constant ping_buffer_length : integer := ntt_num_blocks_per_polym;
     constant ram_size           : integer := 2 * ping_buffer_length;
     constant num_ram_blocks     : integer := polyms_per_ciphertext * i_result_ntt'length;

     type small_bram_addr_arr is array (natural range <>) of unsigned(0 to get_bit_length(ping_buffer_length - 1) - 1);
     type bram_addr_arr is array (natural range <>) of unsigned(0 to get_bit_length(ram_size - 1) - 1);
     signal ram_rd_addr        : small_bram_addr_arr(0 to num_ram_blocks - 1);
     signal ram_wr_addr        : small_bram_addr_arr(0 to ram_rd_addr'length - 1);
     signal ram_rd_addr_offset : std_ulogic_vector(0 to ram_wr_addr'length - 1);
     signal ram_wr_addr_offset : std_ulogic_vector(0 to ram_wr_addr'length - 1);
     signal ram_rd_addr_full   : bram_addr_arr(0 to ram_wr_addr'length - 1);
     signal ram_wr_addr_full   : bram_addr_arr(0 to ram_wr_addr'length - 1);
     signal ram_wr_en          : std_ulogic_vector(0 to num_ram_blocks - 1);
     type bram_addr_cnt_arr is array (natural range <>) of unsigned(0 to get_bit_length(polyms_per_ciphertext - 1) - 1);
     signal wr_en_cnt : bram_addr_cnt_arr(0 to ram_wr_addr'length - 1);

     signal internal_reset_chain : std_ulogic_vector(0 to ntt_out_buf_reset_buf_len-1*boolean'pos(not use_ntt_out_buf_input_buffer)-1);
     signal internal_reset : std_ulogic;
     signal ram_input      : sub_polynom(0 to num_ram_blocks - 1);
     signal input_buf      : sub_polynom(0 to i_result_ntt'length - 1);

begin

     with_in_buf: if use_ntt_out_buf_input_buffer generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               input_buf <= i_result_ntt;
          end if;
          end process;
     end generate;
     no_in_buf: if not use_ntt_out_buf_input_buffer generate
          input_buf <= i_result_ntt;
     end generate;
     process (i_clk) is
     begin
          if rising_edge(i_clk) then
               internal_reset_chain(0) <= i_reset;
               internal_reset_chain(1 to internal_reset_chain'length-1) <= internal_reset_chain(0 to internal_reset_chain'length-2);
          end if;
     end process;
     internal_reset <= internal_reset_chain(internal_reset_chain'length-1);

     -- all buffers get the same input and we just toggle the write enable
     input_buf_map: for k_idx in 0 to polyms_per_ciphertext - 1 generate
          ram_input(k_idx * input_buf'length to (k_idx + 1) * input_buf'length - 1) <= input_buf;
     end generate;

     brams_per_polym_block: for L_coeff_k_idx in 0 to ram_input'length - 1 generate
          ram_elem: manual_bram
               generic map (
                    addr_length         => ram_rd_addr_full(0)'length,
                    ram_length          => ram_size,
                    ram_out_bufs_length => ram_retiming_latency,
                    ram_type            => ntt_big_out_buffer_ram_type,
                    coeff_bit_width     => ram_input(0)'length
               )
               port map (
                    i_clk     => i_clk,
                    i_wr_en   => ram_wr_en(L_coeff_k_idx),
                    i_wr_data => ram_input(L_coeff_k_idx),
                    i_wr_addr => ram_wr_addr_full(L_coeff_k_idx),
                    i_rd_addr => ram_rd_addr_full(L_coeff_k_idx),
                    o_data    => o_result(L_coeff_k_idx)
               );
          -- every bram has its own cnt 
          cnt_logic: process (i_clk)
               -- calculate the k_idx for this bram block
               constant L_k_idx     : integer := L_coeff_k_idx; -- =throughput*polyms_per_ciphertext*num_ntts;
               constant coeff_L_idx : integer := L_coeff_k_idx mod (throughput * num_ntts);
               constant k_idx       : integer := (L_k_idx - coeff_L_idx) / (throughput * num_ntts);
          begin
               if rising_edge(i_clk) then
                    if internal_reset = '1' then
                         wr_en_cnt(L_coeff_k_idx) <= to_unsigned(0, wr_en_cnt(0)'length);
                         ram_wr_en(L_coeff_k_idx) <= '0';
                         ram_rd_addr(L_coeff_k_idx) <= to_unsigned(ping_buffer_length - 1, ram_rd_addr(0)'length);
                         ram_wr_addr(L_coeff_k_idx) <= to_unsigned(ping_buffer_length - 1, ram_wr_addr(0)'length);
                         ram_rd_addr_offset(L_coeff_k_idx) <= '1';
                         -- instead of checking when this ram block has wr_en active, we give it an offset
                         ram_wr_addr_offset(L_coeff_k_idx) <= '0';
                    else
                         if ram_rd_addr(L_coeff_k_idx) = 0 then
                              ram_rd_addr(L_coeff_k_idx) <= to_unsigned(ping_buffer_length - 1, ram_rd_addr(0)'length);
                         else
                              ram_rd_addr(L_coeff_k_idx) <= ram_rd_addr(L_coeff_k_idx) - to_unsigned(1, ram_rd_addr(0)'length);
                         end if;

                         if ram_wr_addr(L_coeff_k_idx) = 0 then
                              ram_wr_addr(L_coeff_k_idx) <= to_unsigned(ping_buffer_length - 1, ram_wr_addr(0)'length);
                              
                              if wr_en_cnt(L_coeff_k_idx) < to_unsigned(polyms_per_ciphertext - 1, wr_en_cnt(0)'length) then
                                   wr_en_cnt(L_coeff_k_idx) <= wr_en_cnt(L_coeff_k_idx) + to_unsigned(1, wr_en_cnt(0)'length);
                              else
                                   wr_en_cnt(L_coeff_k_idx) <= to_unsigned(0, wr_en_cnt(0)'length);
                                   ram_rd_addr_offset(L_coeff_k_idx) <= not ram_rd_addr_offset(L_coeff_k_idx);
                              end if;
                              if wr_en_cnt(L_coeff_k_idx) = to_unsigned(k_idx, wr_en_cnt(0)'length) then
                                   ram_wr_addr_offset(L_coeff_k_idx) <= not ram_wr_addr_offset(L_coeff_k_idx);
                              end if;
                         else
                              ram_wr_addr(L_coeff_k_idx) <= ram_wr_addr(L_coeff_k_idx) - to_unsigned(1, ram_wr_addr(0)'length);
                         end if;

                         if wr_en_cnt(L_coeff_k_idx) = to_unsigned(k_idx, wr_en_cnt(0)'length) then
                              ram_wr_en(L_coeff_k_idx) <= '1';
                         else
                              ram_wr_en(L_coeff_k_idx) <= '0';
                         end if;
                    end if;
                    ram_rd_addr_full(L_coeff_k_idx) <= unsigned(ram_rd_addr_offset(L_coeff_k_idx) & ram_rd_addr(L_coeff_k_idx));
                    ram_wr_addr_full(L_coeff_k_idx) <= unsigned(ram_wr_addr_offset(L_coeff_k_idx) & ram_wr_addr(L_coeff_k_idx));
               end if;
          end process;
     end generate;

     initial_latency_counter: one_time_counter
          generic map (
               tripping_value     => num_polyms_per_rlwe_ciphertext * ntt_num_blocks_per_polym + ram_retiming_latency + 1 * boolean'pos(use_ntt_out_buf_input_buffer),
               out_negated        => true,
               bufferchain_length => trailing_reset_buffer_len
          )
          port map (
               i_clk     => i_clk,
               i_reset   => internal_reset,
               o_tripped => o_next_module_reset
          );

end architecture;
