library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
     use work.datatypes_utils.all;
     use work.constants_utils.all;
    use work.ip_cores_constants.all;
    use work.processor_utils.all;
    use work.tfhe_constants.all;
    use work.math_utils.all;
     use work.ntt_utils.all;

entity tfhe_block is
    generic (
        ----------------------------------------------------------------
        -- AXI Slave (S00) parameters
        ----------------------------------------------------------------
        C_S00_AXI_DATA_WIDTH : integer := 32;
        C_S00_AXI_ADDR_WIDTH : integer := 4;

        ----------------------------------------------------------------
        -- AXI Master (M00) parameters
        ----------------------------------------------------------------
        C_M00_AXI_TARGET_SLAVE_BASE_ADDR : std_logic_vector(63 downto 0) := x"40000000";
        C_M00_AXI_BURST_LEN  : integer := 16;
        C_M00_AXI_ID_WIDTH   : integer := 6;
        C_M00_AXI_ADDR_WIDTH : integer :=  64; -- hbm_id_bit_width;
        C_M00_AXI_DATA_WIDTH : integer := 32;
        C_M00_AXI_AWUSER_WIDTH : integer := 4; -- axi_addr_bits
        C_M00_AXI_ARUSER_WIDTH : integer := 0;
        C_M00_AXI_WUSER_WIDTH  : integer := 0;
        C_M00_AXI_RUSER_WIDTH  : integer := 0;
        C_M00_AXI_BUSER_WIDTH  : integer := 0;

        ----------------------------------------------------------------
        -- AXI Master (M01) parameters
        ----------------------------------------------------------------
        C_M01_AXI_TARGET_SLAVE_BASE_ADDR : std_logic_vector(63 downto 0) := x"40000000";
        C_M01_AXI_BURST_LEN  : integer := 16;
        C_M01_AXI_ID_WIDTH   : integer := 1;
        C_M01_AXI_ADDR_WIDTH : integer := 64;
        C_M01_AXI_DATA_WIDTH : integer := 32;
        C_M01_AXI_AWUSER_WIDTH : integer := 0;
        C_M01_AXI_ARUSER_WIDTH : integer := 0;
        C_M01_AXI_WUSER_WIDTH  : integer := 0;
        C_M01_AXI_RUSER_WIDTH  : integer := 0;
        C_M01_AXI_BUSER_WIDTH  : integer := 0
    );
    port (
        ----------------------------------------------------------------
        -- User clock
        ----------------------------------------------------------------
        tfhe_clk : in std_logic;

        ----------------------------------------------------------------
        -- AXI4-Lite Slave Interface (S00_AXI)
        ----------------------------------------------------------------
        s00_axi_aclk    : in  std_logic;
        s00_axi_aresetn : in  std_logic;
        s00_axi_awaddr  : in  std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
        s00_axi_awprot  : in  std_logic_vector(2 downto 0);
        s00_axi_awvalid : in  std_logic;
        s00_axi_awready : out std_logic;
        s00_axi_wdata   : in  std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
        s00_axi_wstrb   : in  std_logic_vector((C_S00_AXI_DATA_WIDTH/8)-1 downto 0);
        s00_axi_wvalid  : in  std_logic;
        s00_axi_wready  : out std_logic;
        s00_axi_bresp   : out std_logic_vector(1 downto 0);
        s00_axi_bvalid  : out std_logic;
        s00_axi_bready  : in  std_logic;
        s00_axi_araddr  : in  std_logic_vector(C_S00_AXI_ADDR_WIDTH-1 downto 0);
        s00_axi_arprot  : in  std_logic_vector(2 downto 0);
        s00_axi_arvalid : in  std_logic;
        s00_axi_arready : out std_logic;
        s00_axi_rdata   : out std_logic_vector(C_S00_AXI_DATA_WIDTH-1 downto 0);
        s00_axi_rresp   : out std_logic_vector(1 downto 0);
        s00_axi_rvalid  : out std_logic;
        s00_axi_rready  : in  std_logic;

        ----------------------------------------------------------------
        -- AXI Master Interface M00_AXI
        ----------------------------------------------------------------
        m00_axi_init_axi_txn : in  std_logic;
        m00_axi_txn_done     : out std_logic;
        m00_axi_error        : out std_logic;
        m00_axi_aclk         : in  std_logic;
        m00_axi_aresetn      : in  std_logic;

        m00_axi_awid    : out std_logic_vector(C_M00_AXI_ID_WIDTH-1 downto 0);
        m00_axi_awaddr  : out std_logic_vector(C_M00_AXI_ADDR_WIDTH-1 downto 0);
        m00_axi_awlen   : out std_logic_vector(7 downto 0);
        m00_axi_awsize  : out std_logic_vector(2 downto 0);
        m00_axi_awburst : out std_logic_vector(1 downto 0);
        m00_axi_awlock  : out std_logic;
        m00_axi_awcache : out std_logic_vector(3 downto 0);
        m00_axi_awprot  : out std_logic_vector(2 downto 0);
        m00_axi_awqos   : out std_logic_vector(3 downto 0);
        m00_axi_awuser  : out std_logic_vector(C_M00_AXI_AWUSER_WIDTH-1 downto 0);
        m00_axi_awvalid : out std_logic;
        m00_axi_awready : in  std_logic;

        m00_axi_wdata  : out std_logic_vector(C_M00_AXI_DATA_WIDTH-1 downto 0);
        m00_axi_wstrb  : out std_logic_vector(C_M00_AXI_DATA_WIDTH/8-1 downto 0);
        m00_axi_wlast  : out std_logic;
        m00_axi_wuser  : out std_logic_vector(C_M00_AXI_WUSER_WIDTH-1 downto 0);
        m00_axi_wvalid : out std_logic;
        m00_axi_wready : in  std_logic;

        m00_axi_bid    : in  std_logic_vector(C_M00_AXI_ID_WIDTH-1 downto 0);
        m00_axi_bresp  : in  std_logic_vector(1 downto 0);
        m00_axi_buser  : in  std_logic_vector(C_M00_AXI_BUSER_WIDTH-1 downto 0);
        m00_axi_bvalid : in  std_logic;
        m00_axi_bready : out std_logic;

        m00_axi_arid    : out std_logic_vector(C_M00_AXI_ID_WIDTH-1 downto 0);
        m00_axi_araddr  : out std_logic_vector(C_M00_AXI_ADDR_WIDTH-1 downto 0);
        m00_axi_arlen   : out std_logic_vector(7 downto 0);
        m00_axi_arsize  : out std_logic_vector(2 downto 0);
        m00_axi_arburst : out std_logic_vector(1 downto 0);
        m00_axi_arlock  : out std_logic;
        m00_axi_arcache : out std_logic_vector(3 downto 0);
        m00_axi_arprot  : out std_logic_vector(2 downto 0);
        m00_axi_arqos   : out std_logic_vector(3 downto 0);
        m00_axi_aruser  : out std_logic_vector(C_M00_AXI_ARUSER_WIDTH-1 downto 0);
        m00_axi_arvalid : out std_logic;
        m00_axi_arready : in  std_logic;

        m00_axi_rid    : in  std_logic_vector(C_M00_AXI_ID_WIDTH-1 downto 0);
        m00_axi_rdata  : in  std_logic_vector(C_M00_AXI_DATA_WIDTH-1 downto 0);
        m00_axi_rresp  : in  std_logic_vector(1 downto 0);
        m00_axi_rlast  : in  std_logic;
        m00_axi_ruser  : in  std_logic_vector(C_M00_AXI_RUSER_WIDTH-1 downto 0);
        m00_axi_rvalid : in  std_logic;
        m00_axi_rready : out std_logic;

        ----------------------------------------------------------------
        -- AXI Master Interface M01_AXI (same style as above)
        ----------------------------------------------------------------
        m01_axi_init_axi_txn : in  std_logic;
        m01_axi_txn_done     : out std_logic;
        m01_axi_error        : out std_logic;
        m01_axi_aclk         : in  std_logic;
        m01_axi_aresetn      : in  std_logic;

        m01_axi_awid    : out std_logic_vector(C_M01_AXI_ID_WIDTH-1 downto 0);
        m01_axi_awaddr  : out std_logic_vector(C_M01_AXI_ADDR_WIDTH-1 downto 0);
        m01_axi_awlen   : out std_logic_vector(7 downto 0);
        m01_axi_awsize  : out std_logic_vector(2 downto 0);
        m01_axi_awburst : out std_logic_vector(1 downto 0);
        m01_axi_awlock  : out std_logic;
        m01_axi_awcache : out std_logic_vector(3 downto 0);
        m01_axi_awprot  : out std_logic_vector(2 downto 0);
        m01_axi_awqos   : out std_logic_vector(3 downto 0);
        m01_axi_awuser  : out std_logic_vector(C_M01_AXI_AWUSER_WIDTH-1 downto 0);
        m01_axi_awvalid : out std_logic;
        m01_axi_awready : in  std_logic;

        m01_axi_wdata  : out std_logic_vector(C_M01_AXI_DATA_WIDTH-1 downto 0);
        m01_axi_wstrb  : out std_logic_vector(C_M01_AXI_DATA_WIDTH/8-1 downto 0);
        m01_axi_wlast  : out std_logic;
        m01_axi_wuser  : out std_logic_vector(C_M01_AXI_WUSER_WIDTH-1 downto 0);
        m01_axi_wvalid : out std_logic;
        m01_axi_wready : in  std_logic;

        m01_axi_bid    : in  std_logic_vector(C_M01_AXI_ID_WIDTH-1 downto 0);
        m01_axi_bresp  : in  std_logic_vector(1 downto 0);
        m01_axi_buser  : in  std_logic_vector(C_M01_AXI_BUSER_WIDTH-1 downto 0);
        m01_axi_bvalid : in  std_logic;
        m01_axi_bready : out std_logic;

        m01_axi_arid    : out std_logic_vector(C_M01_AXI_ID_WIDTH-1 downto 0);
        m01_axi_araddr  : out std_logic_vector(C_M01_AXI_ADDR_WIDTH-1 downto 0);
        m01_axi_arlen   : out std_logic_vector(7 downto 0);
        m01_axi_arsize  : out std_logic_vector(2 downto 0);
        m01_axi_arburst : out std_logic_vector(1 downto 0);
        m01_axi_arlock  : out std_logic;
        m01_axi_arcache : out std_logic_vector(3 downto 0);
        m01_axi_arprot  : out std_logic_vector(2 downto 0);
        m01_axi_arqos   : out std_logic_vector(3 downto 0);
        m01_axi_aruser  : out std_logic_vector(C_M01_AXI_ARUSER_WIDTH-1 downto 0);
        m01_axi_arvalid : out std_logic;
        m01_axi_arready : in  std_logic;

        m01_axi_rid    : in  std_logic_vector(C_M01_AXI_ID_WIDTH-1 downto 0);
        m01_axi_rdata  : in  std_logic_vector(C_M01_AXI_DATA_WIDTH-1 downto 0);
        m01_axi_rresp  : in  std_logic_vector(1 downto 0);
        m01_axi_rlast  : in  std_logic;
        m01_axi_ruser  : in  std_logic_vector(C_M01_AXI_RUSER_WIDTH-1 downto 0);
        m01_axi_rvalid : in  std_logic;
        m01_axi_rready : out std_logic;

        ----------------------------------------------------------------
        -- User LEDs
        ----------------------------------------------------------------
        user_led : out std_logic_vector(7 downto 0)
    );
end entity;


architecture rtl of tfhe_block is

    --------------------------------------------------------------------
    -- Internal signals (matching Verilog instantiation)
    --------------------------------------------------------------------
    -- clocks / resets for internal user logic
    -- signal computing_clk   : std_logic;
    -- signal computing_reset : std_logic;

    -- -- signals for PBS accelerator and simple HBM adapter
    -- signal lwe_n_buf_out              : sub_polynom(0 to pbs_throughput - 1);
    -- signal lwe_n_buf_out_valid        : std_ulogic := '0';
    -- signal lwe_n_buf_write_next_reset : std_ulogic := '0';
    -- signal lwe_n_buf_rq_idx           : unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1) := (others => '0');

    -- -- minimal HBM package signals (single-stack mapping for AI/BSK)
    -- signal ai_hbm_out : hbm_ps_out_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
    -- signal ai_hbm_in  : hbm_ps_in_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
    -- signal bsk_hbm_out : hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
    -- signal bsk_hbm_in  : hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);

    -- -- default (inactive) HBM packages to initialize arrays
    -- constant default_hbm_out_read_pkg : hbm_ps_out_read_pkg := (
    --     rdata        => (others => '0'),
    --     rlast        => '0',
    --     rdata_parity => (others => '0'),
    --     arready      => '0',
    --     rid          => (others => '0'),
    --     rresp        => (others => '0'),
    --     rvalid       => '0'
    -- );

    -- constant default_hbm_in_read_pkg : hbm_ps_in_read_pkg := (
    --     araddr  => (others => '0'),
    --     arvalid => '0',
    --     arid    => (others => '0'),
    --     rready  => '0',
    --     arlen   => (others => '0')
    -- );


begin

    --------------------------------------------------------------------
    -- AXI Slave S00 controller instance
    --------------------------------------------------------------------
    tfhe_w_controller_inst : entity work.tfhe_w_controller
        generic map (
            C_S_AXI_DATA_WIDTH => C_S00_AXI_DATA_WIDTH,
            C_S_AXI_ADDR_WIDTH => C_S00_AXI_ADDR_WIDTH
        )
        port map (
            S_AXI_ACLK    => s00_axi_aclk,
            S_AXI_ARESETN => s00_axi_aresetn,
            S_AXI_AWADDR  => s00_axi_awaddr,
            S_AXI_AWPROT  => s00_axi_awprot,
            S_AXI_AWVALID => s00_axi_awvalid,
            S_AXI_AWREADY => s00_axi_awready,
            S_AXI_WDATA   => s00_axi_wdata,
            S_AXI_WSTRB   => s00_axi_wstrb,
            S_AXI_WVALID  => s00_axi_wvalid,
            S_AXI_WREADY  => s00_axi_wready,
            S_AXI_BRESP   => s00_axi_bresp,
            S_AXI_BVALID  => s00_axi_bvalid,
            S_AXI_BREADY  => s00_axi_bready,
            S_AXI_ARADDR  => s00_axi_araddr,
            S_AXI_ARPROT  => s00_axi_arprot,
            S_AXI_ARVALID => s00_axi_arvalid,
            S_AXI_ARREADY => s00_axi_arready,
            S_AXI_RDATA   => s00_axi_rdata,
            S_AXI_RRESP   => s00_axi_rresp,
            S_AXI_RVALID  => s00_axi_rvalid,
            S_AXI_RREADY  => s00_axi_rready,
            user_led      => user_led
        );

    --------------------------------------------------------------------
    -- AXI Master M00 instance
    --------------------------------------------------------------------
    tfhe_w_master_m00 : entity work.tfhe_w_master_full_v1_0_M00_AXI
        generic map (
            C_M_TARGET_SLAVE_BASE_ADDR => C_M00_AXI_TARGET_SLAVE_BASE_ADDR,
            C_M_AXI_BURST_LEN => C_M00_AXI_BURST_LEN,
            C_M_AXI_ID_WIDTH  => C_M00_AXI_ID_WIDTH,
            C_M_AXI_ADDR_WIDTH => C_M00_AXI_ADDR_WIDTH,
            C_M_AXI_DATA_WIDTH => C_M00_AXI_DATA_WIDTH,
            C_M_AXI_AWUSER_WIDTH => C_M00_AXI_AWUSER_WIDTH,
            C_M_AXI_ARUSER_WIDTH => C_M00_AXI_ARUSER_WIDTH,
            C_M_AXI_WUSER_WIDTH => C_M00_AXI_WUSER_WIDTH,
            C_M_AXI_RUSER_WIDTH => C_M00_AXI_RUSER_WIDTH,
            C_M_AXI_BUSER_WIDTH => C_M00_AXI_BUSER_WIDTH
        )
        port map (
            INIT_AXI_TXN => m00_axi_init_axi_txn,
            TXN_DONE     => m00_axi_txn_done,
            ERROR        => m00_axi_error,
            M_AXI_ACLK   => m00_axi_aclk,
            M_AXI_ARESETN => m00_axi_aresetn,

            M_AXI_AWID    => m00_axi_awid,
            M_AXI_AWADDR  => m00_axi_awaddr,
            M_AXI_AWLEN   => m00_axi_awlen,
            M_AXI_AWSIZE  => m00_axi_awsize,
            M_AXI_AWBURST => m00_axi_awburst,
            M_AXI_AWLOCK  => m00_axi_awlock,
            M_AXI_AWCACHE => m00_axi_awcache,
            M_AXI_AWPROT  => m00_axi_awprot,
            M_AXI_AWQOS   => m00_axi_awqos,
            M_AXI_AWUSER  => m00_axi_awuser,
            M_AXI_AWVALID => m00_axi_awvalid,
            M_AXI_AWREADY => m00_axi_awready,

            M_AXI_WDATA  => m00_axi_wdata,
            M_AXI_WSTRB  => m00_axi_wstrb,
            M_AXI_WLAST  => m00_axi_wlast,
            M_AXI_WUSER  => m00_axi_wuser,
            M_AXI_WVALID => m00_axi_wvalid,
            M_AXI_WREADY => m00_axi_wready,

            M_AXI_BID    => m00_axi_bid,
            M_AXI_BRESP  => m00_axi_bresp,
            M_AXI_BUSER  => m00_axi_buser,
            M_AXI_BVALID => m00_axi_bvalid,
            M_AXI_BREADY => m00_axi_bready,

            M_AXI_ARID    => m00_axi_arid,
            M_AXI_ARADDR  => m00_axi_araddr,
            M_AXI_ARLEN   => m00_axi_arlen,
            M_AXI_ARSIZE  => m00_axi_arsize,
            M_AXI_ARBURST => m00_axi_arburst,
            M_AXI_ARLOCK  => m00_axi_arlock,
            M_AXI_ARCACHE => m00_axi_arcache,
            M_AXI_ARPROT  => m00_axi_arprot,
            M_AXI_ARQOS   => m00_axi_arqos,
            M_AXI_ARUSER  => m00_axi_aruser,
            M_AXI_ARVALID => m00_axi_arvalid,
            M_AXI_ARREADY => m00_axi_arready,

            M_AXI_RID    => m00_axi_rid,
            M_AXI_RDATA  => m00_axi_rdata,
            M_AXI_RRESP  => m00_axi_rresp,
            M_AXI_RLAST  => m00_axi_rlast,
            M_AXI_RUSER  => m00_axi_ruser,
            M_AXI_RVALID => m00_axi_rvalid,
            M_AXI_RREADY => m00_axi_rready
        );

    --------------------------------------------------------------------
    -- Simple PBS accelerator + M00 read-adapter hookup
    --------------------------------------------------------------------
    -- drive internal computing clock/reset from top-level
    -- computing_clk   <= tfhe_clk;
    -- computing_reset <= s00_axi_aresetn;

    -- -- initialize arrays with default packages where not used
    -- ai_hbm_out  <= (others => default_hbm_out_read_pkg);
    -- bsk_hbm_out <= (others => default_hbm_out_read_pkg);
    -- ai_hbm_in   <= (others => default_hbm_in_read_pkg);
    -- bsk_hbm_in  <= (others => default_hbm_in_read_pkg);

    -- -- instantiate the PBS computing core 
    -- pbs_computing_inst : entity work.tfhe_pbs_accelerator
    --     port map (
    --         i_clk               => computing_clk,
    --         i_reset_n           => computing_reset,
    --         i_ram_coeff_idx     => lwe_n_buf_rq_idx,
    --         o_return_address    => open,
    --         o_out_valid         => lwe_n_buf_out_valid,
    --         o_out_data          => lwe_n_buf_out,
    --         o_next_module_reset => lwe_n_buf_write_next_reset,
    --         i_ai_hbm_out        => ai_hbm_out,
    --         i_bsk_hbm_out       => bsk_hbm_out,
    --         i_op_hbm_out        => default_hbm_out_read_pkg,
    --         i_lut_hbm_out       => default_hbm_out_read_pkg,
    --         i_b_hbm_out         => default_hbm_out_read_pkg,
    --         o_ai_hbm_in         => ai_hbm_in,
    --         o_bsk_hbm_in        => bsk_hbm_in,
    --         o_op_hbm_in         => open,
    --         o_lut_hbm_in        => open,
    --         o_b_hbm_in          => open
    --     );

    -- -- adapter: convert one hbm_ps_in_read_pkg (from PBS) into M00 AXI read
    -- u_hbm_read_pkg_to_m00_adapter : entity work.hbm_read_pkg_to_m00_adapter
    --     port map (
    --         i_clk    => m00_axi_aclk,
    --         i_reset_n=> m00_axi_aresetn,
    --         i_hbm_read_in  => ai_hbm_in(0),
    --         o_hbm_read_out => ai_hbm_out(0),

    --         M_AXI_ARID    => m00_axi_arid,
    --         M_AXI_ARADDR  => m00_axi_araddr,
    --         M_AXI_ARLEN   => m00_axi_arlen,
    --         M_AXI_ARSIZE  => m00_axi_arsize,
    --         M_AXI_ARBURST => m00_axi_arburst,
    --         M_AXI_ARLOCK  => m00_axi_arlock,
    --         M_AXI_ARCACHE => m00_axi_arcache,
    --         M_AXI_ARPROT  => m00_axi_arprot,
    --         M_AXI_ARQOS   => m00_axi_arqos,
    --         M_AXI_ARUSER  => m00_axi_aruser,
    --         M_AXI_ARVALID => m00_axi_arvalid,
    --         M_AXI_ARREADY => m00_axi_arready,

    --         M_AXI_RID     => m00_axi_rid,
    --         M_AXI_RDATA   => m00_axi_rdata,
    --         M_AXI_RRESP   => m00_axi_rresp,
    --         M_AXI_RLAST   => m00_axi_rlast,
    --         M_AXI_RUSER   => m00_axi_ruser,
    --         M_AXI_RVALID  => m00_axi_rvalid,
    --         M_AXI_RREADY  => m00_axi_rready
    --     );

    --------------------------------------------------------------------
    -- AXI Master M01 instance
    --------------------------------------------------------------------
    tfhe_w_master_m01 : entity work.tfhe_w_master_full_v1_0_M01_AXI
        generic map (
            C_M_TARGET_SLAVE_BASE_ADDR => C_M01_AXI_TARGET_SLAVE_BASE_ADDR,
            C_M_AXI_BURST_LEN => C_M01_AXI_BURST_LEN,
            C_M_AXI_ID_WIDTH  => C_M01_AXI_ID_WIDTH,
            C_M_AXI_ADDR_WIDTH => C_M01_AXI_ADDR_WIDTH,
            C_M_AXI_DATA_WIDTH => C_M01_AXI_DATA_WIDTH,
            C_M_AXI_AWUSER_WIDTH => C_M01_AXI_AWUSER_WIDTH,
            C_M_AXI_ARUSER_WIDTH => C_M01_AXI_ARUSER_WIDTH,
            C_M_AXI_WUSER_WIDTH => C_M01_AXI_WUSER_WIDTH,
            C_M_AXI_RUSER_WIDTH => C_M01_AXI_RUSER_WIDTH,
            C_M_AXI_BUSER_WIDTH => C_M01_AXI_BUSER_WIDTH
        )
        port map (
            INIT_AXI_TXN => m01_axi_init_axi_txn,
            TXN_DONE     => m01_axi_txn_done,
            ERROR        => m01_axi_error,
            M_AXI_ACLK   => m01_axi_aclk,
            M_AXI_ARESETN => m01_axi_aresetn,

            M_AXI_AWID    => m01_axi_awid,
            M_AXI_AWADDR  => m01_axi_awaddr,
            M_AXI_AWLEN   => m01_axi_awlen,
            M_AXI_AWSIZE  => m01_axi_awsize,
            M_AXI_AWBURST => m01_axi_awburst,
            M_AXI_AWLOCK  => m01_axi_awlock,
            M_AXI_AWCACHE => m01_axi_awcache,
            M_AXI_AWPROT  => m01_axi_awprot,
            M_AXI_AWQOS   => m01_axi_awqos,
            M_AXI_AWUSER  => m01_axi_awuser,
            M_AXI_AWVALID => m01_axi_awvalid,
            M_AXI_AWREADY => m01_axi_awready,

            M_AXI_WDATA  => m01_axi_wdata,
            M_AXI_WSTRB  => m01_axi_wstrb,
            M_AXI_WLAST  => m01_axi_wlast,
            M_AXI_WUSER  => m01_axi_wuser,
            M_AXI_WVALID => m01_axi_wvalid,
            M_AXI_WREADY => m01_axi_wready,

            M_AXI_BID    => m01_axi_bid,
            M_AXI_BRESP  => m01_axi_bresp,
            M_AXI_BUSER  => m01_axi_buser,
            M_AXI_BVALID => m01_axi_bvalid,
            M_AXI_BREADY => m01_axi_bready,

            M_AXI_ARID    => m01_axi_arid,
            M_AXI_ARADDR  => m01_axi_araddr,
            M_AXI_ARLEN   => m01_axi_arlen,
            M_AXI_ARSIZE  => m01_axi_arsize,
            M_AXI_ARBURST => m01_axi_arburst,
            M_AXI_ARLOCK  => m01_axi_arlock,
            M_AXI_ARCACHE => m01_axi_arcache,
            M_AXI_ARPROT  => m01_axi_arprot,
            M_AXI_ARQOS   => m01_axi_arqos,
            M_AXI_ARUSER  => m01_axi_aruser,
            M_AXI_ARVALID => m01_axi_arvalid,
            M_AXI_ARREADY => m01_axi_arready,

            M_AXI_RID    => m01_axi_rid,
            M_AXI_RDATA  => m01_axi_rdata,
            M_AXI_RRESP  => m01_axi_rresp,
            M_AXI_RLAST  => m01_axi_rlast,
            M_AXI_RUSER  => m01_axi_ruser,
            M_AXI_RVALID => m01_axi_rvalid,
            M_AXI_RREADY => m01_axi_rready
        );

end architecture rtl;
