----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: bski_pbs_pingpongbuffer.vhd
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: takes bski for the pbs and buffers it in a way that it provides the signals at the correct time for the pbs.
--             bsk_hbm_coeffs_per_clk must be a power of 2 that is smaller than o_bski_part'length.
--             A ping-pong buffer is used. The module requests data from hbm and uses that to fill the buffers.
--             The ping buffer is written to in the beginning. After that it is ready for the pbs. While one buffer provides
--             bsk_i for the pbs the other buffer is filled by bsk_(i+1).
--             Every blind rotation iteration the buffers switch function. This is called batched bootstrapping and
--             amortized the bski loading time.
--             Bsk_i is required for every ciphertext of the batch. So we read bsk_i batchsize-many times before
--             we need bsk_(i+1).
--             When using burst, only every burstlen-address that this module outputs is actually read by hbm.
--             (But we still update the read address every clock tic in case burstlength changes).
--             Buffer pattern:
--             With reference to big design: hbm provides 64 coeffs/tic, bski_buffer must provide 128 coeffs/tic
--             So each hbm port is requested twice to fill one buffer slot. So we read 2 sub-blocks.
--             That is why its structured interleaved:
--                  coefficient x | sub block 0
--                  coefficient x+1 | sub block 1
--                  coefficient x+2 | sub block 0
--                  coefficient x+3 | sub block 1 and so on
--             So inside an HBM port data must be arranged like this:
--                  coefficient x
--                  coefficient x+2
--                  coefficient x+1
--                  coefficient x+3 and so on
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
     use IEEE.math_real.all;
library work;
     use work.constants_utils.all;
     use work.ip_cores_constants.all;
     use work.datatypes_utils.all;
     use work.tfhe_constants.all;
     use work.math_utils.all;
     use work.processor_utils.all;

entity bski_pbs_pingpongbuffer is
     port (
          i_clk                    : in  std_ulogic;
          i_pbs_reset              : in  std_ulogic;
          i_reset_n                : in  std_ulogic;
          i_hbm_ps_in_read_out_pkg : in  hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
          o_hbm_ps_in_read_in_pkg  : out hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
          o_bski_part              : out sub_polynom(0 to pbs_bsk_coeffs_needed_per_clk - 1);
          o_ready_to_output        : out std_ulogic
     );
end entity;

architecture Behavioral of bski_pbs_pingpongbuffer is

     -- memory pattern: receive input-blocks, store and assemble them till size of output-block
     -- return sequentially all out-blocks pbs_batchsize-times
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

     constant num_blocks_per_rlwe_ciphertext    : integer := num_polyms_per_rlwe_ciphertext * ntt_num_blocks_per_polym;
     constant clks_till_next_bski_must_be_ready : integer := num_blocks_per_rlwe_ciphertext * pbs_batchsize;
     constant clks_per_bski_part_load           : integer := integer(ceil(real(num_polyms_per_rlwe_ciphertext * bsk_hbm_coeffs_per_clk) / real(bsk_hbm_coeffs_per_clk)));
     constant clks_per_bski_load                : integer := ntt_num_blocks_per_polym * clks_per_bski_part_load;
     constant worst_case_clks_per_bski_load     : integer := clks_per_bski_load + hbm_worst_case_delay_in_clks;

     signal bski_buf_input  : sub_polynom(0 to o_bski_part'length - 1);
     constant ping_buf_length : integer := num_blocks_per_rlwe_ciphertext;
     constant bski_buf_length : integer := 2 * ping_buf_length;

     signal enough_rqs_to_fill_bufs : std_ulogic_vector(0 to bsk_hbm_num_ports_to_use-1);
     signal init_done              : std_ulogic_vector(0 to bsk_hbm_num_ports_to_use-1);
     type bram_wr_addr_arr is array(natural range <>) of unsigned(0 to get_bit_length(bski_buf_length - 1) - 1); -- is a power of 2 --> modulos itself
     signal bram_write_addrs      : bram_wr_addr_arr(0 to bsk_hbm_num_ports_to_use-1);

     constant num_sub_blocks        : integer := o_bski_part'length / bsk_hbm_coeffs_per_clk;
     constant num_sub_blocks_coeffs : integer := num_sub_blocks*hbm_coeffs_per_clock_per_ps_port;
     type rq_block_cnt_arr is array(natural range <>) of unsigned(0 to get_bit_length(ping_buf_length*num_sub_blocks - 1) - 1);
     signal rq_block_cnts           : rq_block_cnt_arr(0 to bsk_hbm_num_ports_to_use-1);

     type sub_block_cnt_arr is array(natural range <>) of unsigned(0 to get_max(1,get_bit_length(num_sub_blocks-1)) - 1);
     signal receive_sub_block_cnts         : sub_block_cnt_arr(0 to bsk_hbm_num_ports_to_use-1);

     signal out_part_cnt : unsigned(0 to bram_write_addrs(0)'length - 1); -- modulos itself
     signal out_part_cnt_offset      : unsigned(0 to out_part_cnt'length - 1);
     signal out_part_cnt_full        : unsigned(0 to out_part_cnt'length - 1);

     signal out_batchsize_cnt : unsigned(0 to get_bit_length(pbs_batchsize - 1) - 1);

     signal start_outputting : std_ulogic;

     signal bski_rq_addrs : hbm_ps_port_memory_address_arr(0 to bsk_hbm_num_ports_to_use-1);
     signal hbm_part     : sub_polynom(0 to bsk_hbm_coeffs_per_clk - 1);

     signal write_en_vec     : std_ulogic_vector(0 to o_bski_part'length - 1);
     signal write_en_vec_buf : std_ulogic_vector(0 to write_en_vec'length - 1);
     
     signal i_buf_hbm_ps_in_read_out_pkg : hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
     signal o_buf_hbm_ps_in_read_in_pkg  : hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);

begin

     -- we assume that the HBM is more than fast enough to write to the buffer, so it will never be late but can be too early
     speed_requirement_check: if clks_till_next_bski_must_be_ready < worst_case_clks_per_bski_load generate
          assert false report "Sorry - HBM not fast enough for this configuration" severity error;
     end generate;

     out_buf: if use_hbm_output_buffer generate
          process (i_clk) is
          begin
          if rising_edge(i_clk) then
               o_hbm_ps_in_read_in_pkg <= o_buf_hbm_ps_in_read_in_pkg;
               i_buf_hbm_ps_in_read_out_pkg <= i_hbm_ps_in_read_out_pkg;
          end if;
          end process;
     end generate;
     no_out_buf: if not use_hbm_output_buffer generate
          o_hbm_ps_in_read_in_pkg <= o_buf_hbm_ps_in_read_in_pkg;
          i_buf_hbm_ps_in_read_out_pkg <= i_hbm_ps_in_read_out_pkg;
     end generate;

     -- bsk buffer treats its hbm channels as one. Need to replicate the signal correctly with the addresses
     -- Each bsk hbm channel is controlled independently
     per_port_logic: for port_idx in 0 to bsk_hbm_num_ports_to_use - 1 generate
          -- fixed values
          o_buf_hbm_ps_in_read_in_pkg(port_idx).arid    <= std_logic_vector(to_unsigned(0, o_buf_hbm_ps_in_read_in_pkg(0).arid'length)); -- we expect that the requests are handled in the same order as we send them. We dont check the ids.
          o_buf_hbm_ps_in_read_in_pkg(port_idx).arlen   <= std_logic_vector(to_unsigned(bsk_burstlen, o_buf_hbm_ps_in_read_in_pkg(0).arlen'length));
          o_buf_hbm_ps_in_read_in_pkg(port_idx).rready  <= '1';
          o_buf_hbm_ps_in_read_in_pkg(port_idx).araddr(hbm_port_and_stack_addr_width - 1 downto 0) <= bsk_base_addr(hbm_port_and_stack_addr_width - 1 downto 0) + to_unsigned(port_idx, hbm_port_and_stack_addr_width); -- set the addr-bits that lead to the channel, keep the channel addr-bits
          o_buf_hbm_ps_in_read_in_pkg(port_idx).araddr(o_buf_hbm_ps_in_read_in_pkg(0).araddr'length - 1 downto hbm_port_and_stack_addr_width) <= bski_rq_addrs(port_idx)(o_buf_hbm_ps_in_read_in_pkg(0).araddr'length - 1 downto hbm_port_and_stack_addr_width);
          
          write_enable_logic: for coeff_idx in 0 to num_sub_blocks_coeffs-1 generate
               process (i_clk) is
               begin
               if rising_edge(i_clk) then
                    -- alternate between rows, the rows are interleaved so that hbm signals have to travel less distance
                    if receive_sub_block_cnts(port_idx) = to_unsigned(coeff_idx mod num_sub_blocks, receive_sub_block_cnts(0)'length) and (i_buf_hbm_ps_in_read_out_pkg(port_idx).rvalid = '1') then
                         write_en_vec(port_idx*num_sub_blocks_coeffs + coeff_idx) <= '1';
                    else
                         write_en_vec(port_idx*num_sub_blocks_coeffs + coeff_idx) <= '0';
                    end if;
               end if;
               end process;
          end generate;
          receive_cnts: process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    if i_reset_n = '0' then
                         receive_sub_block_cnts(port_idx) <= to_unsigned(0, receive_sub_block_cnts(0)'length); -- receive_sub_block_cnts keeps track of what rams to write
                         bram_write_addrs(port_idx) <= to_unsigned(0, bram_write_addrs(0)'length); -- bram_write_addrs keeps track where to write in the ram
                    elsif i_buf_hbm_ps_in_read_out_pkg(port_idx).rvalid = '1' then
                         -- FW: avoid this by initilizing bram_write_addrs per sub-block with an offset, then only count up
                         -- receive cnt logic
                         if receive_sub_block_cnts(port_idx) < to_unsigned(num_sub_blocks - 1, receive_sub_block_cnts(0)'length) then
                              receive_sub_block_cnts(port_idx) <= receive_sub_block_cnts(port_idx) + to_unsigned(1, receive_sub_block_cnts(0)'length);
                         else
                              receive_sub_block_cnts(port_idx) <= to_unsigned(0, receive_sub_block_cnts(0)'length);
                         end if;

                         if receive_sub_block_cnts(port_idx) = to_unsigned(num_sub_blocks - 1, receive_sub_block_cnts(0)'length) then
                              if bram_write_addrs(port_idx) < to_unsigned(bski_buf_length - 1, bram_write_addrs(0)'length) then
                                   bram_write_addrs(port_idx) <= bram_write_addrs(port_idx) + to_unsigned(1, bram_write_addrs(0)'length);
                              else
                                   bram_write_addrs(port_idx) <= to_unsigned(0, bram_write_addrs(0)'length);
                              end if;
                         end if;
                    end if;
               end if;
          end process;

          -- we assume that writing always finishes before reading
          axi_handling: process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    if i_reset_n = '0' then
                         enough_rqs_to_fill_bufs(port_idx) <= '0';
                         init_done(port_idx) <= '0';

                         rq_block_cnts(port_idx) <= to_unsigned(0, rq_block_cnts(0)'length); -- keeps track when to stop requesting. Could use bski_rq_addrs instead but bad if later multiple keys
                         o_buf_hbm_ps_in_read_in_pkg(port_idx).arvalid <= '0';
                         bski_rq_addrs(port_idx) <= bsk_base_addr;
                    else

                         if i_buf_hbm_ps_in_read_out_pkg(port_idx).arready = '1' and enough_rqs_to_fill_bufs(port_idx) = '0' then
                              -- increment request address
                              if bski_rq_addrs(port_idx) < bsk_end_addr - to_unsigned(1, bski_rq_addrs(0)'length) then
                                   bski_rq_addrs(port_idx) <= bski_rq_addrs(port_idx) + to_unsigned(hbm_bytes_per_ps_port, bski_rq_addrs(0)'length);
                              else
                                   bski_rq_addrs(port_idx) <= bsk_base_addr;
                              end if;
                              o_buf_hbm_ps_in_read_in_pkg(port_idx).arvalid <= '1';

                              if rq_block_cnts(port_idx) < to_unsigned(ping_buf_length*num_sub_blocks - 1, rq_block_cnts(0)'length) then
                                   rq_block_cnts(port_idx) <= rq_block_cnts(port_idx) + to_unsigned(1, rq_block_cnts(0)'length);
                              else
                                   rq_block_cnts(port_idx) <= to_unsigned(0, rq_block_cnts(0)'length);
                              end if;
                         else
                              o_buf_hbm_ps_in_read_in_pkg(port_idx).arvalid <= '0';
                         end if;

                         if out_batchsize_cnt = to_unsigned(pbs_batchsize - 1, out_batchsize_cnt'length) then
                              -- when read is done enable requests again
                              enough_rqs_to_fill_bufs(port_idx) <= '0';
                         elsif rq_block_cnts(port_idx) = to_unsigned(ping_buf_length*num_sub_blocks - 1, rq_block_cnts(0)'length) then
                              if init_done(port_idx) = '0' then
                                   init_done(port_idx) <= '1';
                              else
                                   -- write of ping or pong is done, stop requesting
                                   enough_rqs_to_fill_bufs(port_idx)<= '1';
                              end if;
                         end if;
                    end if;
               end if;
          end process;
     end generate;

     -- drive constant signals on unused ports
     deactive_ports: for port_idx in bsk_hbm_num_ports_to_use to o_buf_hbm_ps_in_read_in_pkg'length-1 generate
          o_buf_hbm_ps_in_read_in_pkg(port_idx).arid    <= std_logic_vector(to_unsigned(0, o_buf_hbm_ps_in_read_in_pkg(0).arid'length));
          o_buf_hbm_ps_in_read_in_pkg(port_idx).arlen   <= std_logic_vector(to_unsigned(bsk_burstlen, o_buf_hbm_ps_in_read_in_pkg(0).arlen'length));
          o_buf_hbm_ps_in_read_in_pkg(port_idx).rready  <= '0';
          o_buf_hbm_ps_in_read_in_pkg(port_idx).araddr <= to_unsigned(0, o_buf_hbm_ps_in_read_in_pkg(0).araddr'length);
          o_buf_hbm_ps_in_read_in_pkg(port_idx).arvalid  <= '0';
     end generate;
     
     crtl_logic_ready_to_output: one_time_counter
          generic map (
               tripping_value     => worst_case_clks_per_bski_load - 1,
               out_negated        => false,
               bufferchain_length => log2_pbs_throughput
          )
          port map (
               i_clk     => i_clk,
               i_reset   => i_reset_n,
               o_tripped => o_ready_to_output
          );
     
     bski_brams: for coeff_idx in 0 to o_bski_part'length - 1 generate
          process (i_clk) is
          begin
               if rising_edge(i_clk) then
                    write_en_vec_buf(coeff_idx) <= write_en_vec(coeff_idx);
               end if;
          end process;
          ram_elem: manual_bram
               generic map (
                    addr_length         => bram_write_addrs(0)'length,
                    ram_length          => bski_buf_length,
                    ram_out_bufs_length => bski_buffer_output_buffer,
                    ram_type            => ram_style_bram,
                    coeff_bit_width     => bski_buf_input(0)'length
               )
               port map (
                    i_clk     => i_clk,
                    i_wr_en   => write_en_vec_buf(coeff_idx),
                    i_wr_data => bski_buf_input(coeff_idx),
                    i_wr_addr => bram_write_addrs(coeff_idx / num_sub_blocks_coeffs), -- division without rounding, only the integer part counts
                    i_rd_addr => out_part_cnt_full,
                    o_data    => o_bski_part(coeff_idx)
               );
     end generate;

     bits2coeffs: for coeff_idx in 0 to hbm_part'length - 1 generate
          bits2bits: for bit_idx in 0 to hbm_part(0)'length - 1 generate
               hbm_part(coeff_idx)(bit_idx) <= i_buf_hbm_ps_in_read_out_pkg(coeff_idx / hbm_coeffs_per_clock_per_ps_port).rdata((coeff_idx mod hbm_coeffs_per_clock_per_ps_port) * hbm_part(0)'length + bit_idx);
          end generate;
     end generate;
     -- ignore excess coefficients when not all of the hbm stack is needed
     map_hbm_out_to_buf_input: for coeff_idx in 0 to hbm_part'length-1 generate
          coeff_spread: for sub_block_idx in 0 to num_sub_blocks-1 generate
               bski_buf_input(coeff_idx*num_sub_blocks+sub_block_idx) <= hbm_part(coeff_idx);
          end generate;
     end generate;

     -- when reading from the buffer treat all hbm-channel-buffers like one
     initial_latency_counter: one_time_counter
          generic map (
               tripping_value     => blind_rot_iter_latency_till_elem_wise_mult - 1 - bski_buffer_output_buffer - 1*boolean'pos(use_hbm_output_buffer),
               out_negated        => false,
               bufferchain_length => log2_pbs_throughput
          )
          port map (
               i_clk     => i_clk,
               i_reset   => i_pbs_reset,
               o_tripped => start_outputting
          );
     -- read batchsize-many times from the same buffer before switching
     read_from_buf_logic: process (i_clk) is
     begin
          if rising_edge(i_clk) then
               if i_reset_n = '0' then
                    out_part_cnt_offset <= to_unsigned(0, out_part_cnt_offset'length);
                    out_part_cnt <= to_unsigned(0, out_part_cnt'length);
                    out_batchsize_cnt <= to_unsigned(0, out_batchsize_cnt'length);
               elsif start_outputting = '1' then
                    if out_part_cnt < to_unsigned(ping_buf_length - 1, out_part_cnt'length) then
                         out_part_cnt <= out_part_cnt + to_unsigned(1, out_part_cnt'length);
                    else
                         out_part_cnt <= to_unsigned(0, out_part_cnt'length);
                         if out_batchsize_cnt < to_unsigned(pbs_batchsize - 1, out_batchsize_cnt'length) then
                              out_batchsize_cnt <= out_batchsize_cnt + to_unsigned(1, out_batchsize_cnt'length);
                         else
                              out_batchsize_cnt <= to_unsigned(0, out_batchsize_cnt'length);
                              out_part_cnt_offset <= out_part_cnt_offset + to_unsigned(ping_buf_length, out_part_cnt_offset'length);
                         end if;
                    end if;
               end if;
               out_part_cnt_full <= out_part_cnt + out_part_cnt_offset;
          end if;
     end process;

end architecture;
