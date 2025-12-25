----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: tfhe_processor
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: the tfhe_accelerator with hbm
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
     use work.ip_cores_constants.all;
     use work.datatypes_utils.all;
     use work.math_utils.all;
     use work.tfhe_constants.all;
     use work.processor_utils.all;

entity tfhe_processor is
     port (
          i_sys_clk          : in std_ulogic;
          i_clk_ref      : in std_ulogic; -- for hbm stack 0
          i_clk_ref_2    : in std_ulogic; -- for hbm stack 1
          i_clk_apb      : in std_ulogic; -- for both hbm stacks
          -- i_reset_n_apb  : in std_ulogic; -- for both hbm stacks
          i_sys_clk_pcie : in std_ulogic; -- 100 MHz
          i_sys_clk_gt   : in std_ulogic--; -- 100 MHz, must be directly driven from BUFDS_GTE
          -- i_reset_n      : in std_ulogic
     );
end entity;

architecture Behavioral of tfhe_processor is

     component tfhe_pbs_accelerator is
          port (
               i_clk               : in  std_ulogic;
               i_reset_n           : in  std_ulogic;
               i_ram_coeff_idx     : in  unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
               o_return_address    : out hbm_ps_port_memory_address;
               o_out_valid         : out std_ulogic;
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

     component pbs_lwe_n_storage_read_to_ks is
          port (
               i_clk               : in  std_ulogic;
               i_coeffs            : in  sub_polynom(0 to pbs_throughput - 1);
               i_coeffs_valid      : in  std_ulogic;
               i_reset             : in  std_ulogic;

               o_ram_coeff_idx     : out unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
               o_coeff             : out synthesiseable_uint;
               o_coeff_valid       : out std_ulogic;
               o_next_module_reset : out std_ulogic
          );
     end component;

     component pbs_lwe_n_storage_read_to_hbm is
          port (
               i_clk           : in  std_ulogic;
               i_coeffs        : in  sub_polynom(0 to pbs_throughput - 1);
               i_coeffs_valid  : in  std_ulogic;
               i_reset         : in  std_ulogic;
               i_hbm_write_out : in  hbm_ps_out_write_pkg;
               o_hbm_write_in  : out hbm_ps_in_write_pkg;
               o_ram_coeff_idx : out unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1)
          );
     end component;

     component hbm_wrapper_hbm_0_right is
          port (
               i_clk                : in  std_ulogic;
               i_clk_ref            : in  std_ulogic; -- must be a raw clock pin, hbm-ip-core uses it internally to do the 900MHz clock
               i_clk_apb            : in  std_ulogic;
               i_reset_n            : in  std_ulogic;
               i_reset_n_apb        : in  std_ulogic;
               i_write_pkgs         : in  hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               i_read_pkgs          : in  hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               o_write_pkgs         : out hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               o_read_pkgs          : out hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               o_initial_init_ready : out std_ulogic
          );
     end component;

     component hbm_wrapper_hbm_1_left is
          port (
               i_clk                : in  std_ulogic;
               i_clk_ref            : in  std_ulogic; -- must be a raw clock pin, hbm-ip-core uses it internally to do the 900MHz clock
               i_clk_apb            : in  std_ulogic;
               i_reset_n            : in  std_ulogic;
               i_reset_n_apb        : in  std_ulogic;
               i_write_pkgs         : in  hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               i_read_pkgs          : in  hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               o_write_pkgs         : out hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               o_read_pkgs          : out hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
               o_initial_init_ready : out std_ulogic
          );
     end component;

     component axi_crossbar_0_wrapper is
          generic (
               num_axi_slaves : integer
          );
          port (
               i_clk           : in  std_ulogic;
               i_reset_n       : in  std_ulogic;
               i_write_pkgs    : in  axi_in_write_pkg;                                  -- small pkg from master
               i_read_pkgs     : in  axi_in_read_pkg;                                   -- small pkg from master
               i_hbm_read_out  : in  hbm_ps_out_read_pkg_arr(0 to num_axi_slaves - 1);  -- big pkg for master from slaves
               i_hbm_write_out : in  hbm_ps_out_write_pkg_arr(0 to num_axi_slaves - 1); -- big pkg for master from slaves
               o_hbm_read_in   : out hbm_ps_in_read_pkg_arr(0 to num_axi_slaves - 1);   -- big pkg for slaves from master
               o_hbm_write_in  : out hbm_ps_in_write_pkg_arr(0 to num_axi_slaves - 1);  -- big pkg for slaves from master
               o_write_pkgs    : out axi_out_write_pkg;                                 -- small pkg from one slave for the master
               o_read_pkgs     : out axi_out_read_pkg                                   -- small pkg from one slave for the master
          );
     end component;

     -- axi_crossbar_1_wrapper removed: external PCIe/XDMA and full crossbar not required

     -- xdma_0_wrapper removed: external PCIe/XDMA is not used in this simplified build

     -- pcie wrapper removed for simplified M00-only HBM access

     constant channel_op_idx     : integer := 0;
     constant channel_lut_idx    : integer := 1;
     constant channel_ai_idx     : integer := 2;
     constant channel_b_idx      : integer := 3;
     constant channel_result_idx : integer := 4;
     constant channel_bsk_idx    : integer := 5;

     -- constant num_writeable_channels : integer := 5;
     constant hbm_stack_1_num_used_channels  : integer := 5;
     constant hbm_stack_1_num_write_channels : integer := 4;
     -- constant write_channels_indices : int_array(0 to num_writeable_channels - 1) := (channel_op_idx, channel_lut_idx, channel_ai_idx, channel_b_idx, channel_bsk_idx);
     signal lwe_n_buf_out              : sub_polynom(0 to pbs_throughput - 1);
     signal lwe_n_buf_out_valid        : std_ulogic;
     signal lwe_n_buf_write_next_reset : std_ulogic;
     signal lwe_n_buf_rq_idx           : unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);

     signal hbm_write_in_pkgs_stack_0  : hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
     signal hbm_write_out_pkgs_stack_0 : hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
     signal hbm_read_in_pkgs_stack_0   : hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
     signal hbm_read_out_pkgs_stack_0  : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);

     signal hbm_write_in_pkgs_stack_1  : hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
     signal hbm_write_out_pkgs_stack_1 : hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
     signal hbm_read_in_pkgs_stack_1   : hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
     signal hbm_read_out_pkgs_stack_1  : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);

     signal bsk_hbm_out : hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
     signal bsk_hbm_in  : hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);

     signal ai_hbm_out : hbm_ps_out_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
     signal ai_hbm_in  : hbm_ps_in_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);

     signal axi_read_out_pkgs_stack_0 : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1); -- v4p ignore w-302. Because its unconnected on purpose

     signal axi_hbm_0_master_write_in         : axi_in_write_pkg;
     signal axi_hbm_0_master_write_out        : axi_out_write_pkg;
     signal axi_hbm_0_master_read_in          : axi_in_read_pkg; -- kept for M00 interface
     -- signal axi_hbm_0_master_read_out      : axi_out_read_pkg; -- not used in simplified build

     signal computing_clk   : std_ulogic;
     signal computing_reset : std_ulogic;
     signal axi_clk         : std_ulogic;
     signal axi_reset_n     : std_ulogic;

     constant reset_cnt_val: integer := 8;
     signal reset_clk_cnt: unsigned(0 to get_bit_length(reset_cnt_val-1)-1) := to_unsigned(0,get_bit_length(reset_cnt_val-1));
     signal internal_reset_n_apb: std_ulogic := '0';

begin

     computing_clk   <= axi_clk;
     computing_reset <= axi_reset_n;
     
     process (i_clk_apb)
     begin
          if rising_edge(i_clk_apb) then
               reset_clk_cnt <= reset_clk_cnt + to_unsigned(1, reset_clk_cnt'length);
               -- reset must be asserted for at least one clk_signal_ref clock cycle
               -- reset_n is initialized with 0
               if reset_clk_cnt > to_unsigned(reset_cnt_val,reset_clk_cnt'length) then
                    internal_reset_n_apb <= '1';
               end if;
          end if;
     end process;

     pbs_computing: tfhe_pbs_accelerator
          port map (
               i_clk               => computing_clk,
               i_reset_n           => computing_reset,
               i_ram_coeff_idx     => lwe_n_buf_rq_idx,
               i_ai_hbm_out        => ai_hbm_out,
               i_bsk_hbm_out       => bsk_hbm_out,
               i_op_hbm_out        => hbm_read_out_pkgs_stack_1(channel_op_idx),
               i_lut_hbm_out       => hbm_read_out_pkgs_stack_1(channel_lut_idx),
               i_b_hbm_out         => hbm_read_out_pkgs_stack_1(channel_b_idx),
               o_out_valid         => lwe_n_buf_out_valid,
               o_return_address    => open,
               o_out_data          => lwe_n_buf_out,
               o_next_module_reset => lwe_n_buf_write_next_reset,
               o_ai_hbm_in         => ai_hbm_in,
               o_bsk_hbm_in        => bsk_hbm_in,
               o_op_hbm_in         => hbm_read_in_pkgs_stack_1(channel_op_idx),
               o_lut_hbm_in        => hbm_read_in_pkgs_stack_1(channel_lut_idx),
               o_b_hbm_in          => hbm_read_in_pkgs_stack_1(channel_b_idx)
          );

     only_pbs: if no_muladd_module generate
          read_lwe_n_storage: pbs_lwe_n_storage_read_to_hbm
               port map (
                    i_clk           => computing_clk,
                    i_coeffs        => lwe_n_buf_out,
                    i_coeffs_valid  => lwe_n_buf_out_valid,
                    i_reset         => lwe_n_buf_write_next_reset,
                    i_hbm_write_out => hbm_write_out_pkgs_stack_1(channel_result_idx),
                    o_hbm_write_in  => hbm_write_in_pkgs_stack_1(channel_result_idx),
                    o_ram_coeff_idx => lwe_n_buf_rq_idx
               );
     end generate;

     full_tfhe_processor_pbs: if not no_muladd_module generate
          -- read_lwe_n_storage: pbs_lwe_n_storage_read_to_ks
          --      port map (
          --           i_clk               => i_clk,
          --           i_coeffs            => lwe_n_buf_out,
          --           i_coeffs_valid      => lwe_n_buf_out_valid,
          --           i_reset             => lwe_n_buf_write_next_reset,
          --           o_ram_coeff_idx     => lwe_n_buf_rq_idx,
          --           o_coeff             => open, -- TODO
          --           o_coeff_valid       => open, -- TODO
          --           o_next_module_reset => open
          --      );
     end generate;

     hbm_stack_0: hbm_wrapper_hbm_0_right
          port map (
               i_clk                => axi_clk,
               i_clk_ref            => i_clk_ref,
               i_clk_apb            => i_clk_apb,
               i_reset_n            => axi_reset_n,
               i_reset_n_apb        => internal_reset_n_apb,
               i_write_pkgs         => hbm_write_in_pkgs_stack_0,
               i_read_pkgs          => hbm_read_in_pkgs_stack_0, -- bsk_buf reads this hbm and thus delivers the read_in_pkg
               o_write_pkgs         => hbm_write_out_pkgs_stack_0,
               o_read_pkgs          => hbm_read_out_pkgs_stack_0,
               o_initial_init_ready => open
          );
     -- we use stack 0 for bsk. Throw away data from unused ports.
     bsk_hbm_out                                           <= hbm_read_out_pkgs_stack_0(0 to bsk_hbm_out'length - 1);
     hbm_read_in_pkgs_stack_0(0 to bsk_hbm_out'length - 1) <= bsk_hbm_in;

     hbm_stack_1: hbm_wrapper_hbm_1_left
          port map (
               i_clk                => axi_clk,
               i_clk_ref            => i_clk_ref_2,
               i_clk_apb            => i_clk_apb,
               i_reset_n            => axi_reset_n,
               i_reset_n_apb        => internal_reset_n_apb,
               i_write_pkgs         => hbm_write_in_pkgs_stack_1,
               i_read_pkgs          => hbm_read_in_pkgs_stack_1,
               o_write_pkgs         => hbm_write_out_pkgs_stack_1,
               o_read_pkgs          => hbm_read_out_pkgs_stack_1,
               o_initial_init_ready => open
          );
     -- current setting: only one hbm port for ai
     ai_hbm_out(0)                            <= hbm_read_out_pkgs_stack_1(channel_ai_idx);
     hbm_read_in_pkgs_stack_1(channel_ai_idx) <= ai_hbm_in(0);

     axi_for_hbm_0: axi_crossbar_0_wrapper
          generic map (
               num_axi_slaves => crossbar_0_num_axi_slaves
          )
          port map (
               i_clk           => axi_clk,
               i_reset_n       => axi_reset_n,
               i_write_pkgs    => axi_hbm_0_master_write_in,
               i_read_pkgs     => axi_hbm_0_master_read_in,  -- unconnected on purpose
               i_hbm_read_out  => axi_read_out_pkgs_stack_0, -- unconnected in purpose
               i_hbm_write_out => hbm_write_out_pkgs_stack_0,
               o_hbm_read_in   => open,                      -- unconnected in purpose
               o_hbm_write_in  => hbm_write_in_pkgs_stack_0,
               o_write_pkgs    => axi_hbm_0_master_write_out,
               o_read_pkgs     => open -- unconnected on purpose
          );

     -- Simplified: we remove the full crossbar to PCIe/XDMA and associated inactive-channel glue.
     -- Keep only the mapping to the M00 AXI master via axi_hbm_0_master_* signals.
     -- Deactivate unused channels of hbm stack 0
     make_channels_inactive_0: for channel_idx in 0 to axi_read_out_pkgs_stack_0'length - 1 generate
          axi_read_out_pkgs_stack_0(channel_idx).arready      <= '0';
          axi_read_out_pkgs_stack_0(channel_idx).rdata        <= (others => '0');
          axi_read_out_pkgs_stack_0(channel_idx).rdata_parity <= (others => '0');
          axi_read_out_pkgs_stack_0(channel_idx).rid          <= (others => '0');
          axi_read_out_pkgs_stack_0(channel_idx).rlast        <= '0';
          axi_read_out_pkgs_stack_0(channel_idx).rresp        <= (others => '0');
          axi_read_out_pkgs_stack_0(channel_idx).rvalid       <= '0';
     end generate;

     -- Map HBM write/read packages to the external M00 AXI master bridge
     -- For a simplified M00-only flow: drive the M00 master input from the BSK channel
     -- If you want a different channel, change channel_bsk_idx to the desired channel here.
     axi_hbm_0_master_write_in.data            <= hbm_write_in_pkgs_stack_1(channel_bsk_idx).wdata;
     axi_hbm_0_master_write_in.crtl.addr       <= std_logic_vector(hbm_write_in_pkgs_stack_1(channel_bsk_idx).awaddr);
     axi_hbm_0_master_write_in.crtl.addr_valid <= hbm_write_in_pkgs_stack_1(channel_bsk_idx).awvalid;
     axi_hbm_0_master_write_in.crtl.len        <= burstlen_pad_bits & hbm_write_in_pkgs_stack_1(channel_bsk_idx).awlen; -- burstlength conversion
     axi_hbm_0_master_write_in.crtl.ready      <= hbm_write_in_pkgs_stack_1(channel_bsk_idx).bready;
     axi_hbm_0_master_write_in.valid           <= hbm_write_in_pkgs_stack_1(channel_bsk_idx).wvalid;
     axi_hbm_0_master_write_in.strobe          <= std_logic_vector(hbm_strobe_setting);
     axi_hbm_0_master_write_in.crtl.burst      <= std_logic_vector(hbm_burstmode);
     axi_hbm_0_master_write_in.crtl.size       <= std_logic_vector(hbm_burstsize);
     axi_hbm_0_master_write_in.crtl.cache      <= (others => '0');
     axi_hbm_0_master_write_in.crtl.id         <= hbm_write_in_pkgs_stack_1(channel_bsk_idx).awid;
     axi_hbm_0_master_write_in.crtl.prot       <= (others => '0');
     axi_hbm_0_master_write_in.crtl.qos        <= (others => '0');
     axi_hbm_0_master_write_in.last            <= hbm_write_in_pkgs_stack_1(channel_bsk_idx).wlast;

     -- reflect response and ready back from the M00 master bridge into HBM write-out pkg
     hbm_write_out_pkgs_stack_1(channel_bsk_idx).awready <= axi_hbm_0_master_write_out.crtl.addr_ready;
     hbm_write_out_pkgs_stack_1(channel_bsk_idx).wready  <= axi_hbm_0_master_write_out.ready;
     hbm_write_out_pkgs_stack_1(channel_bsk_idx).bresp   <= axi_hbm_0_master_write_out.crtl.resp;
     hbm_write_out_pkgs_stack_1(channel_bsk_idx).bvalid  <= axi_hbm_0_master_write_out.crtl.valid;
     hbm_write_out_pkgs_stack_1(channel_bsk_idx).bid     <= axi_hbm_0_master_write_out.crtl.id;

     -- Simple default for read side: no active M00-initiated reads in this simplified flow
     axi_hbm_0_master_read_in.crtl.addr_valid            <= '0';
     axi_hbm_0_master_read_in.crtl.ready                 <= '0';
     axi_hbm_0_master_read_in.crtl.addr                  <= (others => '0');
     axi_hbm_0_master_read_in.crtl.burst                 <= (others => '0');
     axi_hbm_0_master_read_in.crtl.cache                 <= (others => '0');
     axi_hbm_0_master_read_in.crtl.id                    <= (others => '0');
     axi_hbm_0_master_read_in.crtl.len                   <= (others => '0');
     axi_hbm_0_master_read_in.crtl.prot                  <= (others => '0');
     axi_hbm_0_master_read_in.crtl.qos                   <= (others => '0');
     axi_hbm_0_master_read_in.crtl.size                  <= (others => '0');

     -- PCIe / XDMA instantiations removed for simplified M00-only HBM access

end architecture;
