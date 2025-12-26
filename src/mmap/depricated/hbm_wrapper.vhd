library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.ip_cores_constants.all;
	use work.processor_utils.all;
	use work.datatypes_utils.all;
	use work.math_utils.all;
	use work.tfhe_constants.all;

--                  ┌───────────────┐
-- AXI from BD ───> │               │
--                  │   AXI MUX     ├──> hbm_0
-- Packages ──────> │               │
--                  └──────^────────┘
--                         │
--                     i_axi_sel


entity hbm_w is
  port (

    -- AXI select
    i_axi_sel     : in  std_logic;

    --- Global signals
    -- i_clk                : in  std_ulogic;
	-- i_clk_ref            : in  std_ulogic; -- must be a raw clock pin, hbm-ip-core uses it internally to do the 900MHz clock
	-- i_clk_apb            : in  std_ulogic;
	-- RESET_N            : in  std_ulogic;
	-- RESET_N_apb        : in  std_ulogic;
	TFHE_CLK	   : in  std_logic;




    ------------------------------------------------------------------
    -- External AXI master (to the crossbar)
    ------------------------------------------------------------------
    HBM_REF_CLK_0       : in  std_logic;                                 -- 100 MHz, drives a PLL. Must be sourced from a MMCM/BUFG

	AXI_00_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_00_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_00_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_00_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst: use '01' # 00fixed(not supported), 01incr, 11wrap(like incr but wraps at the end, slower)
	AXI_00_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr. id tag (we have no need for this if the outputs are in the correct order, otherwise need ping-pong-buffer)
	AXI_00_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- read burst length --> constant '1111'
	AXI_00_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- read burst size, only 256-bit size supported (b'101')
	AXI_00_ARVALID      : in  std_logic;                                 -- read addr valid --> constant 1
	AXI_00_ARREADY      : out std_logic;                                 -- "read address ready" --> can accept a new read address
	-- same as for read
	AXI_00_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_00_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_00_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_00_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_00_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_00_AWVALID      : in  std_logic;
	AXI_00_AWREADY      : out std_logic;                                 -- "write address ready" --> can accept a new write address
	--
	AXI_00_RREADY       : in  std_logic;                                 --"read ready" signals that we read the input so the next one can come? Must be high to transmit the input data, set to 1
	AXI_00_BREADY       : in  std_logic;                                 --"response ready" --> read response, can accept new response
	AXI_00_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);            -- data to write
	AXI_00_WLAST        : in  std_logic;                                 -- shows that this was the last value that was written
	AXI_00_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);             -- write strobe --> one bit per write byte on the bus to tell that it should be written --> set all to 1.
	AXI_00_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);             -- why would I need that? Is data loss expeced?
	AXI_00_WVALID       : in  std_logic;
	AXI_00_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);             -- no need?
	AXI_00_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);            -- read data
	AXI_00_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_00_RLAST        : out std_logic;                                 -- shows that this was the last value that was read
	AXI_00_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);              -- read response --> which are possible?
	AXI_00_RVALID       : out std_logic;                                 -- signals output is there
	AXI_00_WREADY       : out std_logic;                                 -- signals that the values are now stored
	--
	AXI_00_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);              --"response ID tag" for AXI_00_BRESP
	AXI_00_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);              --Write response: 00 - OK, 01 - exclusive access OK, 10 - slave error, 11 decode error
	AXI_00_BVALID       : out std_logic;                                 --"Write response ready"

	AXI_01_ACLK         : in  std_logic;
	AXI_01_ARESET_N     : in  std_logic;
	AXI_01_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_01_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_01_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_01_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_01_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_01_ARVALID      : in  std_logic;
	AXI_01_ARREADY      : out std_logic;
	AXI_01_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_01_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_01_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_01_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_01_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_01_AWVALID      : in  std_logic;
	AXI_01_AWREADY      : out std_logic;
	AXI_01_RREADY       : in  std_logic;
	AXI_01_BREADY       : in  std_logic;
	AXI_01_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_01_WLAST        : in  std_logic;
	AXI_01_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_01_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_01_WVALID       : in  std_logic;
	AXI_01_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_01_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_01_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_01_RLAST        : out std_logic;
	AXI_01_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_01_RVALID       : out std_logic;
	AXI_01_WREADY       : out std_logic;
	AXI_01_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_01_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_01_BVALID       : out std_logic;

	AXI_02_ACLK         : in  std_logic;
	AXI_02_ARESET_N     : in  std_logic;
	AXI_02_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_02_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_02_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_02_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_02_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_02_ARVALID      : in  std_logic;
	AXI_02_ARREADY      : out std_logic;
	AXI_02_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_02_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_02_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_02_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_02_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_02_AWVALID      : in  std_logic;
	AXI_02_AWREADY      : out std_logic;
	AXI_02_RREADY       : in  std_logic;
	AXI_02_BREADY       : in  std_logic;
	AXI_02_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_02_WLAST        : in  std_logic;
	AXI_02_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_02_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_02_WVALID       : in  std_logic;
	AXI_02_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_02_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_02_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_02_RLAST        : out std_logic;
	AXI_02_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_02_RVALID       : out std_logic;
	AXI_02_WREADY       : out std_logic;
	AXI_02_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_02_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_02_BVALID       : out std_logic;

	AXI_03_ACLK         : in  std_logic;
	AXI_03_ARESET_N     : in  std_logic;
	AXI_03_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_03_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_03_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_03_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_03_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_03_ARVALID      : in  std_logic;
	AXI_03_ARREADY      : out std_logic;
	AXI_03_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_03_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_03_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_03_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_03_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_03_AWVALID      : in  std_logic;
	AXI_03_AWREADY      : out std_logic;
	AXI_03_RREADY       : in  std_logic;
	AXI_03_BREADY       : in  std_logic;
	AXI_03_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_03_WLAST        : in  std_logic;
	AXI_03_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_03_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_03_WVALID       : in  std_logic;
	AXI_03_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_03_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_03_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_03_RLAST        : out std_logic;
	AXI_03_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_03_RVALID       : out std_logic;
	AXI_03_WREADY       : out std_logic;
	AXI_03_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_03_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_03_BVALID       : out std_logic;

	AXI_04_ACLK         : in  std_logic;
	AXI_04_ARESET_N     : in  std_logic;
	AXI_04_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_04_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_04_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_04_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_04_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_04_ARVALID      : in  std_logic;
	AXI_04_ARREADY      : out std_logic;
	AXI_04_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_04_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_04_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_04_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_04_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_04_AWVALID      : in  std_logic;
	AXI_04_AWREADY      : out std_logic;
	AXI_04_RREADY       : in  std_logic;
	AXI_04_BREADY       : in  std_logic;
	AXI_04_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_04_WLAST        : in  std_logic;
	AXI_04_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_04_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_04_WVALID       : in  std_logic;
	AXI_04_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_04_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_04_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_04_RLAST        : out std_logic;
	AXI_04_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_04_RVALID       : out std_logic;
	AXI_04_WREADY       : out std_logic;
	AXI_04_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_04_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_04_BVALID       : out std_logic;

	AXI_05_ACLK         : in  std_logic;
	AXI_05_ARESET_N     : in  std_logic;
	AXI_05_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_05_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_05_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_05_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_05_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_05_ARVALID      : in  std_logic;
	AXI_05_ARREADY      : out std_logic;
	AXI_05_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_05_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_05_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_05_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_05_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_05_AWVALID      : in  std_logic;
	AXI_05_AWREADY      : out std_logic;
	AXI_05_RREADY       : in  std_logic;
	AXI_05_BREADY       : in  std_logic;
	AXI_05_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_05_WLAST        : in  std_logic;
	AXI_05_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_05_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_05_WVALID       : in  std_logic;
	AXI_05_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_05_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_05_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_05_RLAST        : out std_logic;
	AXI_05_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_05_RVALID       : out std_logic;
	AXI_05_WREADY       : out std_logic;
	AXI_05_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_05_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_05_BVALID       : out std_logic;

	AXI_06_ACLK         : in  std_logic;
	AXI_06_ARESET_N     : in  std_logic;
	AXI_06_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_06_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_06_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_06_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_06_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_06_ARVALID      : in  std_logic;
	AXI_06_ARREADY      : out std_logic;
	AXI_06_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_06_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_06_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_06_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_06_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_06_AWVALID      : in  std_logic;
	AXI_06_AWREADY      : out std_logic;
	AXI_06_RREADY       : in  std_logic;
	AXI_06_BREADY       : in  std_logic;
	AXI_06_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_06_WLAST        : in  std_logic;
	AXI_06_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_06_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_06_WVALID       : in  std_logic;
	AXI_06_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_06_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_06_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_06_RLAST        : out std_logic;
	AXI_06_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_06_RVALID       : out std_logic;
	AXI_06_WREADY       : out std_logic;
	AXI_06_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_06_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_06_BVALID       : out std_logic;

	AXI_07_ACLK         : in  std_logic;
	AXI_07_ARESET_N     : in  std_logic;
	AXI_07_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_07_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_07_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_07_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_07_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_07_ARVALID      : in  std_logic;
	AXI_07_ARREADY      : out std_logic;
	AXI_07_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_07_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_07_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_07_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_07_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_07_AWVALID      : in  std_logic;
	AXI_07_AWREADY      : out std_logic;
	AXI_07_RREADY       : in  std_logic;
	AXI_07_BREADY       : in  std_logic;
	AXI_07_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_07_WLAST        : in  std_logic;
	AXI_07_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_07_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_07_WVALID       : in  std_logic;
	AXI_07_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_07_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_07_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_07_RLAST        : out std_logic;
	AXI_07_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_07_RVALID       : out std_logic;
	AXI_07_WREADY       : out std_logic;
	AXI_07_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_07_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_07_BVALID       : out std_logic;

	AXI_08_ACLK         : in  std_logic;
	AXI_08_ARESET_N     : in  std_logic;
	AXI_08_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_08_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_08_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_08_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_08_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_08_ARVALID      : in  std_logic;
	AXI_08_ARREADY      : out std_logic;
	AXI_08_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_08_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_08_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_08_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_08_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_08_AWVALID      : in  std_logic;
	AXI_08_AWREADY      : out std_logic;
	AXI_08_RREADY       : in  std_logic;
	AXI_08_BREADY       : in  std_logic;
	AXI_08_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_08_WLAST        : in  std_logic;
	AXI_08_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_08_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_08_WVALID       : in  std_logic;
	AXI_08_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_08_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_08_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_08_RLAST        : out std_logic;
	AXI_08_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_08_RVALID       : out std_logic;
	AXI_08_WREADY       : out std_logic;
	AXI_08_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_08_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_08_BVALID       : out std_logic;

	AXI_09_ACLK         : in  std_logic;
	AXI_09_ARESET_N     : in  std_logic;
	AXI_09_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_09_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_09_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_09_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_09_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_09_ARVALID      : in  std_logic;
	AXI_09_ARREADY      : out std_logic;
	AXI_09_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_09_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_09_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_09_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_09_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_09_AWVALID      : in  std_logic;
	AXI_09_AWREADY      : out std_logic;
	AXI_09_RREADY       : in  std_logic;
	AXI_09_BREADY       : in  std_logic;
	AXI_09_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_09_WLAST        : in  std_logic;
	AXI_09_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_09_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_09_WVALID       : in  std_logic;
	AXI_09_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_09_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_09_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_09_RLAST        : out std_logic;
	AXI_09_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_09_RVALID       : out std_logic;
	AXI_09_WREADY       : out std_logic;
	AXI_09_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_09_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_09_BVALID       : out std_logic;

	AXI_10_ACLK         : in  std_logic;
	AXI_10_ARESET_N     : in  std_logic;
	AXI_10_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_10_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_10_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_10_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_10_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_10_ARVALID      : in  std_logic;
	AXI_10_ARREADY      : out std_logic;
	AXI_10_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_10_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_10_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_10_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_10_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_10_AWVALID      : in  std_logic;
	AXI_10_AWREADY      : out std_logic;
	AXI_10_RREADY       : in  std_logic;
	AXI_10_BREADY       : in  std_logic;
	AXI_10_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_10_WLAST        : in  std_logic;
	AXI_10_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_10_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_10_WVALID       : in  std_logic;
	AXI_10_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_10_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_10_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_10_RLAST        : out std_logic;
	AXI_10_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_10_RVALID       : out std_logic;
	AXI_10_WREADY       : out std_logic;
	AXI_10_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_10_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_10_BVALID       : out std_logic;

	AXI_11_ACLK         : in  std_logic;
	AXI_11_ARESET_N     : in  std_logic;
	AXI_11_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_11_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_11_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_11_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_11_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_11_ARVALID      : in  std_logic;
	AXI_11_ARREADY      : out std_logic;
	AXI_11_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_11_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_11_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_11_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_11_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_11_AWVALID      : in  std_logic;
	AXI_11_AWREADY      : out std_logic;
	AXI_11_RREADY       : in  std_logic;
	AXI_11_BREADY       : in  std_logic;
	AXI_11_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_11_WLAST        : in  std_logic;
	AXI_11_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_11_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_11_WVALID       : in  std_logic;
	AXI_11_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_11_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_11_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_11_RLAST        : out std_logic;
	AXI_11_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_11_RVALID       : out std_logic;
	AXI_11_WREADY       : out std_logic;
	AXI_11_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_11_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_11_BVALID       : out std_logic;

	AXI_12_ACLK         : in  std_logic;
	AXI_12_ARESET_N     : in  std_logic;
	AXI_12_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_12_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_12_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_12_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_12_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_12_ARVALID      : in  std_logic;
	AXI_12_ARREADY      : out std_logic;
	AXI_12_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_12_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_12_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_12_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_12_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_12_AWVALID      : in  std_logic;
	AXI_12_AWREADY      : out std_logic;
	AXI_12_RREADY       : in  std_logic;
	AXI_12_BREADY       : in  std_logic;
	AXI_12_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_12_WLAST        : in  std_logic;
	AXI_12_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_12_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_12_WVALID       : in  std_logic;
	AXI_12_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_12_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_12_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_12_RLAST        : out std_logic;
	AXI_12_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_12_RVALID       : out std_logic;
	AXI_12_WREADY       : out std_logic;
	AXI_12_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_12_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_12_BVALID       : out std_logic;

	AXI_13_ACLK         : in  std_logic;
	AXI_13_ARESET_N     : in  std_logic;
	AXI_13_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_13_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_13_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_13_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_13_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_13_ARVALID      : in  std_logic;
	AXI_13_ARREADY      : out std_logic;
	AXI_13_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_13_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_13_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_13_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_13_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_13_AWVALID      : in  std_logic;
	AXI_13_AWREADY      : out std_logic;
	AXI_13_RREADY       : in  std_logic;
	AXI_13_BREADY       : in  std_logic;
	AXI_13_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_13_WLAST        : in  std_logic;
	AXI_13_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_13_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_13_WVALID       : in  std_logic;
	AXI_13_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_13_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_13_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_13_RLAST        : out std_logic;
	AXI_13_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_13_RVALID       : out std_logic;
	AXI_13_WREADY       : out std_logic;
	AXI_13_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_13_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_13_BVALID       : out std_logic;

	AXI_14_ACLK         : in  std_logic;
	AXI_14_ARESET_N     : in  std_logic;
	AXI_14_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_14_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_14_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_14_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_14_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_14_ARVALID      : in  std_logic;
	AXI_14_ARREADY      : out std_logic;
	AXI_14_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_14_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_14_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_14_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_14_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_14_AWVALID      : in  std_logic;
	AXI_14_AWREADY      : out std_logic;
	AXI_14_RREADY       : in  std_logic;
	AXI_14_BREADY       : in  std_logic;
	AXI_14_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_14_WLAST        : in  std_logic;
	AXI_14_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_14_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_14_WVALID       : in  std_logic;
	AXI_14_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_14_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_14_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_14_RLAST        : out std_logic;
	AXI_14_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_14_RVALID       : out std_logic;
	AXI_14_WREADY       : out std_logic;
	AXI_14_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_14_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_14_BVALID       : out std_logic;

	AXI_15_ACLK         : in  std_logic;
	AXI_15_ARESET_N     : in  std_logic;
	AXI_15_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_15_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_15_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_15_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_15_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_15_ARVALID      : in  std_logic;
	AXI_15_ARREADY      : out std_logic;
	AXI_15_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_15_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_15_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_15_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_15_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_15_AWVALID      : in  std_logic;
	AXI_15_AWREADY      : out std_logic;
	AXI_15_RREADY       : in  std_logic;
	AXI_15_BREADY       : in  std_logic;
	AXI_15_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_15_WLAST        : in  std_logic;
	AXI_15_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_15_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_15_WVALID       : in  std_logic;
	AXI_15_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_15_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_15_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_15_RLAST        : out std_logic;
	AXI_15_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_15_RVALID       : out std_logic;
	AXI_15_WREADY       : out std_logic;
	AXI_15_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_15_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_15_BVALID       : out std_logic;



	-- APB configures the HBM during startup
	APB_0_PCLK          : in  std_logic;                                 -- "APB port clock", must match with apb interface clock which is between 50 MHz and 100 MHz
	APB_0_PRESET_N      : in  std_logic;

	-- APB_0_PWDATA        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	-- APB_0_PADDR         : in  std_logic_vector(21 downto 0);
	-- APB_0_PENABLE       : in  std_logic;
	-- APB_0_PSEL          : in  std_logic;
	-- APB_0_PWRITE        : in  std_logic;
	-- APB_0_PRDATA        : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	-- APB_0_PREADY        : out std_logic;
	-- APB_0_PSLVERR       : out std_logic;
	apb_complete_0      : out std_logic;                                 -- indicates that the initial configuration is complete
	DRAM_0_STAT_CATTRIP : out std_logic;                                 -- catastrophiccally high temperatures, shutdown memory access!
	DRAM_0_STAT_TEMP    : out std_logic_vector(6 downto 0)

  );
end entity;

architecture rtl of hbm_w is

	signal lwe_n_buf_out              : sub_polynom(0 to pbs_throughput - 1);
	signal lwe_n_buf_out_valid        : std_ulogic;
	signal lwe_n_buf_write_next_reset : std_ulogic;
	signal lwe_n_buf_rq_idx           : unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);

	signal ai_hbm_out : hbm_ps_out_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
	signal ai_hbm_in  : hbm_ps_in_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
	signal bsk_hbm_out : hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
	signal bsk_hbm_in  : hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);

	signal hbm_write_in_pkgs_stack_0  : hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
	signal hbm_write_out_pkgs_stack_0 : hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
	signal hbm_read_in_pkgs_stack_0   : hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
	signal hbm_read_out_pkgs_stack_0  : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);

	signal hbm_write_in_pkgs_stack_1  : hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
	signal hbm_write_out_pkgs_stack_1 : hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
	signal hbm_read_in_pkgs_stack_1   : hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
	signal hbm_read_out_pkgs_stack_1  : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);

	constant channel_op_idx     : integer := 0;
	constant channel_lut_idx    : integer := 1;
	constant channel_ai_idx     : integer := 2;
	constant channel_b_idx      : integer := 3;
	constant channel_result_idx : integer := 4;
	constant channel_bsk_idx    : integer := 5;

	------------------------------------------------------------------
    -- High-throughput TFHE interface (to the processor)
    ------------------------------------------------------------------
	signal i_write_pkgs         : hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
	signal i_read_pkgs          : hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
	signal o_write_pkgs         : hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
	signal o_read_pkgs          : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
	signal o_initial_init_ready : std_ulogic;

	signal TFHE_RESET_N : std_ulogic;

begin


	ai_hbm_out(0)                            <= hbm_read_out_pkgs_stack_1(channel_ai_idx);
	hbm_read_in_pkgs_stack_1(channel_ai_idx) <= ai_hbm_in(0);

	-- we use stack 0 for bsk. Throw away data from unused ports.
	bsk_hbm_out                                           <= hbm_read_out_pkgs_stack_0(0 to bsk_hbm_out'length - 1);
	hbm_read_in_pkgs_stack_0(0 to bsk_hbm_out'length - 1) <= bsk_hbm_in;

	hbm_read_in_pkgs_stack_1(channel_ai_idx) <= ai_hbm_in(0);

	hbm_read_out_pkgs_stack_1 <= o_read_pkgs;

  ------------------------------------------------------------------
  -- HBM instance 
  ------------------------------------------------------------------
	hbm_0_inst: hbm_0
		port map (
			HBM_REF_CLK_0       => HBM_REF_CLK_0,
			-- AXI in short: the party that sends the data sets valid='1', the party that receives the data indicates that through ready='1'
			-- here we transmit read/write-address and the write-data and we receive the read-data
			AXI_00_ACLK         => AXI_00_ACLK,
			AXI_00_ARESET_N     => AXI_00_ARESET_N,
			AXI_00_ARADDR       => AXI_00_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(0).araddr),
			AXI_00_ARBURST      => AXI_00_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_00_ARID         => AXI_00_ARID when i_axi_sel = '1' else i_read_pkgs(0).arid,
			AXI_00_ARLEN        => AXI_00_ARLEN when i_axi_sel = '1' else i_read_pkgs(0).arlen,
			AXI_00_ARSIZE       => AXI_00_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_00_ARVALID      => AXI_00_ARVALID when i_axi_sel = '1' else i_read_pkgs(0).arvalid,
			AXI_00_ARREADY      => AXI_00_ARREADY when i_axi_sel = '1' else o_read_pkgs(0).arready,
			AXI_00_AWADDR       => AXI_00_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(0).awaddr),
			AXI_00_AWBURST      => AXI_00_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_00_AWID         => AXI_00_AWID when i_axi_sel = '1' else i_write_pkgs(0).awid,
			AXI_00_AWLEN        => AXI_00_AWLEN when i_axi_sel = '1' else i_write_pkgs(0).awlen,
			AXI_00_AWSIZE       => AXI_00_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_00_AWVALID      => AXI_00_AWVALID when i_axi_sel = '1' else i_write_pkgs(0).awvalid,
			AXI_00_AWREADY      => AXI_00_AWREADY when i_axi_sel = '1' else o_write_pkgs(0).awready,
			AXI_00_RREADY       => AXI_00_RREADY when i_axi_sel = '1' else i_read_pkgs(0).rready,
			AXI_00_BREADY       => AXI_00_BREADY when i_axi_sel = '1' else i_write_pkgs(0).bready,
			AXI_00_WDATA        => AXI_00_WDATA when i_axi_sel = '1' else i_write_pkgs(0).wdata,
			AXI_00_WLAST        => AXI_00_WLAST when i_axi_sel = '1' else i_write_pkgs(0).wlast,
			AXI_00_WSTRB        => AXI_00_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_00_WDATA_PARITY => AXI_00_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(0).wdata_parity,
			AXI_00_WVALID       => AXI_00_WVALID when i_axi_sel = '1' else i_write_pkgs(0).wvalid,
			AXI_00_RDATA_PARITY => AXI_00_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(0).rdata_parity,
			AXI_00_RDATA        => AXI_00_RDATA when i_axi_sel = '1' else o_read_pkgs(0).rdata,
			AXI_00_RID          => AXI_00_RID when i_axi_sel = '1' else o_read_pkgs(0).rid,
			AXI_00_RLAST        => AXI_00_RLAST when i_axi_sel = '1' else o_read_pkgs(0).rlast,
			AXI_00_RRESP        => AXI_00_RRESP when i_axi_sel = '1' else o_read_pkgs(0).rresp,
			AXI_00_RVALID       => AXI_00_RVALID when i_axi_sel = '1' else o_read_pkgs(0).rvalid,
			AXI_00_WREADY       => AXI_00_WREADY when i_axi_sel = '1' else o_write_pkgs(0).wready,
			AXI_00_BID          => AXI_00_BID when i_axi_sel = '1' else o_write_pkgs(0).bid,
			AXI_00_BRESP        => AXI_00_BRESP when i_axi_sel = '1' else o_write_pkgs(0).bresp,
			AXI_00_BVALID       => AXI_00_BVALID when i_axi_sel = '1' else o_write_pkgs(0).bvalid,

			-- the outputs response_id, read_last, read_valid and write_ready should be the same for all banks, so we dont set them
			AXI_01_ACLK         => AXI_01_ACLK,
			AXI_01_ARESET_N     => AXI_01_ARESET_N,
			AXI_01_ARADDR       => AXI_01_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(1).araddr),
			AXI_01_ARBURST      => AXI_01_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_01_ARID         => AXI_01_ARID when i_axi_sel = '1' else i_read_pkgs(1).arid,
			AXI_01_ARLEN        => AXI_01_ARLEN when i_axi_sel = '1' else i_read_pkgs(1).arlen,
			AXI_01_ARSIZE       => AXI_01_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_01_ARVALID      => AXI_01_ARVALID when i_axi_sel = '1' else i_read_pkgs(1).arvalid,
			AXI_01_ARREADY      => AXI_01_ARREADY when i_axi_sel = '1' else o_read_pkgs(1).arready,
			AXI_01_AWADDR       => AXI_01_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(1).awaddr),
			AXI_01_AWBURST      => AXI_01_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_01_AWID         => AXI_01_AWID when i_axi_sel = '1' else i_write_pkgs(1).awid,
			AXI_01_AWLEN        => AXI_01_AWLEN when i_axi_sel = '1' else i_write_pkgs(1).awlen,
			AXI_01_AWSIZE       => AXI_01_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_01_AWVALID      => AXI_01_AWVALID when i_axi_sel = '1' else i_write_pkgs(1).awvalid,
			AXI_01_AWREADY      => AXI_01_AWREADY when i_axi_sel = '1' else o_write_pkgs(1).awready,
			AXI_01_RREADY       => AXI_01_RREADY when i_axi_sel = '1' else i_read_pkgs(1).rready,
			AXI_01_BREADY       => AXI_01_BREADY when i_axi_sel = '1' else i_write_pkgs(1).bready,
			AXI_01_WDATA        => AXI_01_WDATA when i_axi_sel = '1' else i_write_pkgs(1).wdata,
			AXI_01_WLAST        => AXI_01_WLAST when i_axi_sel = '1' else i_write_pkgs(1).wlast,
			AXI_01_WSTRB        => AXI_01_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_01_WDATA_PARITY => AXI_01_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(1).wdata_parity,
			AXI_01_WVALID       => AXI_01_WVALID when i_axi_sel = '1' else i_write_pkgs(1).wvalid,
			AXI_01_RDATA_PARITY => AXI_01_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(1).rdata_parity,
			AXI_01_RDATA        => AXI_01_RDATA when i_axi_sel = '1' else o_read_pkgs(1).rdata,
			AXI_01_RID          => AXI_01_RID when i_axi_sel = '1' else o_read_pkgs(1).rid,
			AXI_01_RLAST        => AXI_01_RLAST when i_axi_sel = '1' else o_read_pkgs(1).rlast,
			AXI_01_RRESP        => AXI_01_RRESP when i_axi_sel = '1' else o_read_pkgs(1).rresp,
			AXI_01_RVALID       => AXI_01_RVALID when i_axi_sel = '1' else o_read_pkgs(1).rvalid,
			AXI_01_WREADY       => AXI_01_WREADY when i_axi_sel = '1' else o_write_pkgs(1).wready,
			AXI_01_BID          => AXI_01_BID when i_axi_sel = '1' else o_write_pkgs(1).bid,
			AXI_01_BRESP        => AXI_01_BRESP when i_axi_sel = '1' else o_write_pkgs(1).bresp,
			AXI_01_BVALID       => AXI_01_BVALID when i_axi_sel = '1' else o_write_pkgs(1).bvalid,

			AXI_02_ACLK         => AXI_02_ACLK,
			AXI_02_ARESET_N     => AXI_02_ARESET_N,
			AXI_02_ARADDR       => AXI_02_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(2).araddr),
			AXI_02_ARBURST      => AXI_02_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_02_ARID         => AXI_02_ARID when i_axi_sel = '1' else i_read_pkgs(2).arid,
			AXI_02_ARLEN        => AXI_02_ARLEN when i_axi_sel = '1' else i_read_pkgs(2).arlen,
			AXI_02_ARSIZE       => AXI_02_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_02_ARVALID      => AXI_02_ARVALID when i_axi_sel = '1' else i_read_pkgs(2).arvalid,
			AXI_02_ARREADY      => AXI_02_ARREADY when i_axi_sel = '1' else o_read_pkgs(2).arready,
			AXI_02_AWADDR       => AXI_02_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(2).awaddr),
			AXI_02_AWBURST      => AXI_02_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_02_AWID         => AXI_02_AWID when i_axi_sel = '1' else i_write_pkgs(2).awid,
			AXI_02_AWLEN        => AXI_02_AWLEN when i_axi_sel = '1' else i_write_pkgs(2).awlen,
			AXI_02_AWSIZE       => AXI_02_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_02_AWVALID      => AXI_02_AWVALID when i_axi_sel = '1' else i_write_pkgs(2).awvalid,
			AXI_02_AWREADY      => AXI_02_AWREADY when i_axi_sel = '1' else o_write_pkgs(2).awready,
			AXI_02_RREADY       => AXI_02_RREADY when i_axi_sel = '1' else i_read_pkgs(2).rready,
			AXI_02_BREADY       => AXI_02_BREADY when i_axi_sel = '1' else i_write_pkgs(2).bready,
			AXI_02_WDATA        => AXI_02_WDATA when i_axi_sel = '1' else i_write_pkgs(2).wdata,
			AXI_02_WLAST        => AXI_02_WLAST when i_axi_sel = '1' else i_write_pkgs(2).wlast,
			AXI_02_WSTRB        => AXI_02_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_02_WDATA_PARITY => AXI_02_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(2).wdata_parity,
			AXI_02_WVALID       => AXI_02_WVALID when i_axi_sel = '1' else i_write_pkgs(2).wvalid,
			AXI_02_RDATA_PARITY => AXI_02_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(2).rdata_parity,
			AXI_02_RDATA        => AXI_02_RDATA when i_axi_sel = '1' else o_read_pkgs(2).rdata,
			AXI_02_RID          => AXI_02_RID when i_axi_sel = '1' else o_read_pkgs(2).rid,
			AXI_02_RLAST        => AXI_02_RLAST when i_axi_sel = '1' else o_read_pkgs(2).rlast,
			AXI_02_RRESP        => AXI_02_RRESP when i_axi_sel = '1' else o_read_pkgs(2).rresp,
			AXI_02_RVALID       => AXI_02_RVALID when i_axi_sel = '1' else o_read_pkgs(2).rvalid,
			AXI_02_WREADY       => AXI_02_WREADY when i_axi_sel = '1' else o_write_pkgs(2).wready,
			AXI_02_BID          => AXI_02_BID when i_axi_sel = '1' else o_write_pkgs(2).bid,
			AXI_02_BRESP        => AXI_02_BRESP when i_axi_sel = '1' else o_write_pkgs(2).bresp,
			AXI_02_BVALID       => AXI_02_BVALID when i_axi_sel = '1' else o_write_pkgs(2).bvalid,

			AXI_03_ACLK         => AXI_03_ACLK,
			AXI_03_ARESET_N     => AXI_03_ARESET_N,
			AXI_03_ARADDR       => AXI_03_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(3).araddr),
			AXI_03_ARBURST      => AXI_03_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_03_ARID         => AXI_03_ARID when i_axi_sel = '1' else i_read_pkgs(3).arid,
			AXI_03_ARLEN        => AXI_03_ARLEN when i_axi_sel = '1' else i_read_pkgs(3).arlen,
			AXI_03_ARSIZE       => AXI_03_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_03_ARVALID      => AXI_03_ARVALID when i_axi_sel = '1' else i_read_pkgs(3).arvalid,
			AXI_03_ARREADY      => AXI_03_ARREADY when i_axi_sel = '1' else o_read_pkgs(3).arready,
			AXI_03_AWADDR       => AXI_03_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(3).awaddr),
			AXI_03_AWBURST      => AXI_03_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_03_AWID         => AXI_03_AWID when i_axi_sel = '1' else i_write_pkgs(3).awid,
			AXI_03_AWLEN        => AXI_03_AWLEN when i_axi_sel = '1' else i_write_pkgs(3).awlen,
			AXI_03_AWSIZE       => AXI_03_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_03_AWVALID      => AXI_03_AWVALID when i_axi_sel = '1' else i_write_pkgs(3).awvalid,
			AXI_03_AWREADY      => AXI_03_AWREADY when i_axi_sel = '1' else o_write_pkgs(3).awready,
			AXI_03_RREADY       => AXI_03_RREADY when i_axi_sel = '1' else i_read_pkgs(3).rready,
			AXI_03_BREADY       => AXI_03_BREADY when i_axi_sel = '1' else i_write_pkgs(3).bready,
			AXI_03_WDATA        => AXI_03_WDATA when i_axi_sel = '1' else i_write_pkgs(3).wdata,
			AXI_03_WLAST        => AXI_03_WLAST when i_axi_sel = '1' else i_write_pkgs(3).wlast,
			AXI_03_WSTRB        => AXI_03_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_03_WDATA_PARITY => AXI_03_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(3).wdata_parity,
			AXI_03_WVALID       => AXI_03_WVALID when i_axi_sel = '1' else i_write_pkgs(3).wvalid,
			AXI_03_RDATA_PARITY => AXI_03_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(3).rdata_parity,
			AXI_03_RDATA        => AXI_03_RDATA when i_axi_sel = '1' else o_read_pkgs(3).rdata,
			AXI_03_RID          => AXI_03_RID when i_axi_sel = '1' else o_read_pkgs(3).rid,
			AXI_03_RLAST        => AXI_03_RLAST when i_axi_sel = '1' else o_read_pkgs(3).rlast,
			AXI_03_RRESP        => AXI_03_RRESP when i_axi_sel = '1' else o_read_pkgs(3).rresp,
			AXI_03_RVALID       => AXI_03_RVALID when i_axi_sel = '1' else o_read_pkgs(3).rvalid,
			AXI_03_WREADY       => AXI_03_WREADY when i_axi_sel = '1' else o_write_pkgs(3).wready,
			AXI_03_BID          => AXI_03_BID when i_axi_sel = '1' else o_write_pkgs(3).bid,
			AXI_03_BRESP        => AXI_03_BRESP when i_axi_sel = '1' else o_write_pkgs(3).bresp,
			AXI_03_BVALID       => AXI_03_BVALID when i_axi_sel = '1' else o_write_pkgs(3).bvalid,

			AXI_04_ACLK         => AXI_04_ACLK,
			AXI_04_ARESET_N     => AXI_04_ARESET_N,
			AXI_04_ARADDR       => AXI_04_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(4).araddr),
			AXI_04_ARBURST      => AXI_04_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_04_ARID         => AXI_04_ARID when i_axi_sel = '1' else i_read_pkgs(4).arid,
			AXI_04_ARLEN        => AXI_04_ARLEN when i_axi_sel = '1' else i_read_pkgs(4).arlen,
			AXI_04_ARSIZE       => AXI_04_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_04_ARVALID      => AXI_04_ARVALID when i_axi_sel = '1' else i_read_pkgs(4).arvalid,
			AXI_04_ARREADY      => AXI_04_ARREADY when i_axi_sel = '1' else o_read_pkgs(4).arready,
			AXI_04_AWADDR       => AXI_04_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(4).awaddr),
			AXI_04_AWBURST      => AXI_04_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_04_AWID         => AXI_04_AWID when i_axi_sel = '1' else i_write_pkgs(4).awid,
			AXI_04_AWLEN        => AXI_04_AWLEN when i_axi_sel = '1' else i_write_pkgs(4).awlen,
			AXI_04_AWSIZE       => AXI_04_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_04_AWVALID      => AXI_04_AWVALID when i_axi_sel = '1' else i_write_pkgs(4).awvalid,
			AXI_04_AWREADY      => AXI_04_AWREADY when i_axi_sel = '1' else o_write_pkgs(4).awready,
			AXI_04_RREADY       => AXI_04_RREADY when i_axi_sel = '1' else i_read_pkgs(4).rready,
			AXI_04_BREADY       => AXI_04_BREADY when i_axi_sel = '1' else i_write_pkgs(4).bready,
			AXI_04_WDATA        => AXI_04_WDATA when i_axi_sel = '1' else i_write_pkgs(4).wdata,
			AXI_04_WLAST        => AXI_04_WLAST when i_axi_sel = '1' else i_write_pkgs(4).wlast,
			AXI_04_WSTRB        => AXI_04_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_04_WDATA_PARITY => AXI_04_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(4).wdata_parity,
			AXI_04_WVALID       => AXI_04_WVALID when i_axi_sel = '1' else i_write_pkgs(4).wvalid,
			AXI_04_RDATA_PARITY => AXI_04_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(4).rdata_parity,
			AXI_04_RDATA        => AXI_04_RDATA when i_axi_sel = '1' else o_read_pkgs(4).rdata,
			AXI_04_RID          => AXI_04_RID when i_axi_sel = '1' else o_read_pkgs(4).rid,
			AXI_04_RLAST        => AXI_04_RLAST when i_axi_sel = '1' else o_read_pkgs(4).rlast,
			AXI_04_RRESP        => AXI_04_RRESP when i_axi_sel = '1' else o_read_pkgs(4).rresp,
			AXI_04_RVALID       => AXI_04_RVALID when i_axi_sel = '1' else o_read_pkgs(4).rvalid,
			AXI_04_WREADY       => AXI_04_WREADY when i_axi_sel = '1' else o_write_pkgs(4).wready,
			AXI_04_BID          => AXI_04_BID when i_axi_sel = '1' else o_write_pkgs(4).bid,
			AXI_04_BRESP        => AXI_04_BRESP when i_axi_sel = '1' else o_write_pkgs(4).bresp,
			AXI_04_BVALID       => AXI_04_BVALID when i_axi_sel = '1' else o_write_pkgs(4).bvalid,

			AXI_05_ACLK         => AXI_05_ACLK,
			AXI_05_ARESET_N     => AXI_05_ARESET_N,
			AXI_05_ARADDR       => AXI_05_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(5).araddr),
			AXI_05_ARBURST      => AXI_05_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_05_ARID         => AXI_05_ARID when i_axi_sel = '1' else i_read_pkgs(5).arid,
			AXI_05_ARLEN        => AXI_05_ARLEN when i_axi_sel = '1' else i_read_pkgs(5).arlen,
			AXI_05_ARSIZE       => AXI_05_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_05_ARVALID      => AXI_05_ARVALID when i_axi_sel = '1' else i_read_pkgs(5).arvalid,
			AXI_05_ARREADY      => AXI_05_ARREADY when i_axi_sel = '1' else o_read_pkgs(5).arready,
			AXI_05_AWADDR       => AXI_05_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(5).awaddr),
			AXI_05_AWBURST      => AXI_05_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_05_AWID         => AXI_05_AWID when i_axi_sel = '1' else i_write_pkgs(5).awid,
			AXI_05_AWLEN        => AXI_05_AWLEN when i_axi_sel = '1' else i_write_pkgs(5).awlen,
			AXI_05_AWSIZE       => AXI_05_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_05_AWVALID      => AXI_05_AWVALID when i_axi_sel = '1' else i_write_pkgs(5).awvalid,
			AXI_05_AWREADY      => AXI_05_AWREADY when i_axi_sel = '1' else o_write_pkgs(5).awready,
			AXI_05_RREADY       => AXI_05_RREADY when i_axi_sel = '1' else i_read_pkgs(5).rready,
			AXI_05_BREADY       => AXI_05_BREADY when i_axi_sel = '1' else i_write_pkgs(5).bready,
			AXI_05_WDATA        => AXI_05_WDATA when i_axi_sel = '1' else i_write_pkgs(5).wdata,
			AXI_05_WLAST        => AXI_05_WLAST when i_axi_sel = '1' else i_write_pkgs(5).wlast,
			AXI_05_WSTRB        => AXI_05_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_05_WDATA_PARITY => AXI_05_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(5).wdata_parity,
			AXI_05_WVALID       => AXI_05_WVALID when i_axi_sel = '1' else i_write_pkgs(5).wvalid,
			AXI_05_RDATA_PARITY => AXI_05_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(5).rdata_parity,
			AXI_05_RDATA        => AXI_05_RDATA when i_axi_sel = '1' else o_read_pkgs(5).rdata,
			AXI_05_RID          => AXI_05_RID when i_axi_sel = '1' else o_read_pkgs(5).rid,
			AXI_05_RLAST        => AXI_05_RLAST when i_axi_sel = '1' else o_read_pkgs(5).rlast,
			AXI_05_RRESP        => AXI_05_RRESP when i_axi_sel = '1' else o_read_pkgs(5).rresp,
			AXI_05_RVALID       => AXI_05_RVALID when i_axi_sel = '1' else o_read_pkgs(5).rvalid,
			AXI_05_WREADY       => AXI_05_WREADY when i_axi_sel = '1' else o_write_pkgs(5).wready,
			AXI_05_BID          => AXI_05_BID when i_axi_sel = '1' else o_write_pkgs(5).bid,
			AXI_05_BRESP        => AXI_05_BRESP when i_axi_sel = '1' else o_write_pkgs(5).bresp,
			AXI_05_BVALID       => AXI_05_BVALID when i_axi_sel = '1' else o_write_pkgs(5).bvalid,

			AXI_06_ACLK         => AXI_06_ACLK,
			AXI_06_ARESET_N     => AXI_06_ARESET_N,
			AXI_06_ARADDR       => AXI_06_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(6).araddr),
			AXI_06_ARBURST      => AXI_06_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_06_ARID         => AXI_06_ARID when i_axi_sel = '1' else i_read_pkgs(6).arid,
			AXI_06_ARLEN        => AXI_06_ARLEN when i_axi_sel = '1' else i_read_pkgs(6).arlen,
			AXI_06_ARSIZE       => AXI_06_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_06_ARVALID      => AXI_06_ARVALID when i_axi_sel = '1' else i_read_pkgs(6).arvalid,
			AXI_06_ARREADY      => AXI_06_ARREADY when i_axi_sel = '1' else o_read_pkgs(6).arready,
			AXI_06_AWADDR       => AXI_06_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(6).awaddr),
			AXI_06_AWBURST      => AXI_06_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_06_AWID         => AXI_06_AWID when i_axi_sel = '1' else i_write_pkgs(6).awid,
			AXI_06_AWLEN        => AXI_06_AWLEN when i_axi_sel = '1' else i_write_pkgs(6).awlen,
			AXI_06_AWSIZE       => AXI_06_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_06_AWVALID      => AXI_06_AWVALID when i_axi_sel = '1' else i_write_pkgs(6).awvalid,
			AXI_06_AWREADY      => AXI_06_AWREADY when i_axi_sel = '1' else o_write_pkgs(6).awready,
			AXI_06_RREADY       => AXI_06_RREADY when i_axi_sel = '1' else i_read_pkgs(6).rready,
			AXI_06_BREADY       => AXI_06_BREADY when i_axi_sel = '1' else i_write_pkgs(6).bready,
			AXI_06_WDATA        => AXI_06_WDATA when i_axi_sel = '1' else i_write_pkgs(6).wdata,
			AXI_06_WLAST        => AXI_06_WLAST when i_axi_sel = '1' else i_write_pkgs(6).wlast,
			AXI_06_WSTRB        => AXI_06_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_06_WDATA_PARITY => AXI_06_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(6).wdata_parity,
			AXI_06_WVALID       => AXI_06_WVALID when i_axi_sel = '1' else i_write_pkgs(6).wvalid,
			AXI_06_RDATA_PARITY => AXI_06_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(6).rdata_parity,
			AXI_06_RDATA        => AXI_06_RDATA when i_axi_sel = '1' else o_read_pkgs(6).rdata,
			AXI_06_RID          => AXI_06_RID when i_axi_sel = '1' else o_read_pkgs(6).rid,
			AXI_06_RLAST        => AXI_06_RLAST when i_axi_sel = '1' else o_read_pkgs(6).rlast,
			AXI_06_RRESP        => AXI_06_RRESP when i_axi_sel = '1' else o_read_pkgs(6).rresp,
			AXI_06_RVALID       => AXI_06_RVALID when i_axi_sel = '1' else o_read_pkgs(6).rvalid,
			AXI_06_WREADY       => AXI_06_WREADY when i_axi_sel = '1' else o_write_pkgs(6).wready,
			AXI_06_BID          => AXI_06_BID when i_axi_sel = '1' else o_write_pkgs(6).bid,
			AXI_06_BRESP        => AXI_06_BRESP when i_axi_sel = '1' else o_write_pkgs(6).bresp,
			AXI_06_BVALID       => AXI_06_BVALID when i_axi_sel = '1' else o_write_pkgs(6).bvalid,

			AXI_07_ACLK         => AXI_07_ACLK,
			AXI_07_ARESET_N     => AXI_07_ARESET_N,
			AXI_07_ARADDR       => AXI_07_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(7).araddr),
			AXI_07_ARBURST      => AXI_07_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_07_ARID         => AXI_07_ARID when i_axi_sel = '1' else i_read_pkgs(7).arid,
			AXI_07_ARLEN        => AXI_07_ARLEN when i_axi_sel = '1' else i_read_pkgs(7).arlen,
			AXI_07_ARSIZE       => AXI_07_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_07_ARVALID      => AXI_07_ARVALID when i_axi_sel = '1' else i_read_pkgs(7).arvalid,
			AXI_07_ARREADY      => AXI_07_ARREADY when i_axi_sel = '1' else o_read_pkgs(7).arready,
			AXI_07_AWADDR       => AXI_07_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(7).awaddr),
			AXI_07_AWBURST      => AXI_07_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_07_AWID         => AXI_07_AWID when i_axi_sel = '1' else i_write_pkgs(7).awid,
			AXI_07_AWLEN        => AXI_07_AWLEN when i_axi_sel = '1' else i_write_pkgs(7).awlen,
			AXI_07_AWSIZE       => AXI_07_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_07_AWVALID      => AXI_07_AWVALID when i_axi_sel = '1' else i_write_pkgs(7).awvalid,
			AXI_07_AWREADY      => AXI_07_AWREADY when i_axi_sel = '1' else o_write_pkgs(7).awready,
			AXI_07_RREADY       => AXI_07_RREADY when i_axi_sel = '1' else i_read_pkgs(7).rready,
			AXI_07_BREADY       => AXI_07_BREADY when i_axi_sel = '1' else i_write_pkgs(7).bready,
			AXI_07_WDATA        => AXI_07_WDATA when i_axi_sel = '1' else i_write_pkgs(7).wdata,
			AXI_07_WLAST        => AXI_07_WLAST when i_axi_sel = '1' else i_write_pkgs(7).wlast,
			AXI_07_WSTRB        => AXI_07_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_07_WDATA_PARITY => AXI_07_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(7).wdata_parity,
			AXI_07_WVALID       => AXI_07_WVALID when i_axi_sel = '1' else i_write_pkgs(7).wvalid,
			AXI_07_RDATA_PARITY => AXI_07_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(7).rdata_parity,
			AXI_07_RDATA        => AXI_07_RDATA when i_axi_sel = '1' else o_read_pkgs(7).rdata,
			AXI_07_RID          => AXI_07_RID when i_axi_sel = '1' else o_read_pkgs(7).rid,
			AXI_07_RLAST        => AXI_07_RLAST when i_axi_sel = '1' else o_read_pkgs(7).rlast,
			AXI_07_RRESP        => AXI_07_RRESP when i_axi_sel = '1' else o_read_pkgs(7).rresp,
			AXI_07_RVALID       => AXI_07_RVALID when i_axi_sel = '1' else o_read_pkgs(7).rvalid,
			AXI_07_WREADY       => AXI_07_WREADY when i_axi_sel = '1' else o_write_pkgs(7).wready,
			AXI_07_BID          => AXI_07_BID when i_axi_sel = '1' else o_write_pkgs(7).bid,
			AXI_07_BRESP        => AXI_07_BRESP when i_axi_sel = '1' else o_write_pkgs(7).bresp,
			AXI_07_BVALID       => AXI_07_BVALID when i_axi_sel = '1' else o_write_pkgs(7).bvalid,

			AXI_08_ACLK         => AXI_08_ACLK,
			AXI_08_ARESET_N     => AXI_08_ARESET_N,
			AXI_08_ARADDR       => AXI_08_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(8).araddr),
			AXI_08_ARBURST      => AXI_08_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_08_ARID         => AXI_08_ARID when i_axi_sel = '1' else i_read_pkgs(8).arid,
			AXI_08_ARLEN        => AXI_08_ARLEN when i_axi_sel = '1' else i_read_pkgs(8).arlen,
			AXI_08_ARSIZE       => AXI_08_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_08_ARVALID      => AXI_08_ARVALID when i_axi_sel = '1' else i_read_pkgs(8).arvalid,
			AXI_08_ARREADY      => AXI_08_ARREADY when i_axi_sel = '1' else o_read_pkgs(8).arready,
			AXI_08_AWADDR       => AXI_08_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(8).awaddr),
			AXI_08_AWBURST      => AXI_08_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_08_AWID         => AXI_08_AWID when i_axi_sel = '1' else i_write_pkgs(8).awid,
			AXI_08_AWLEN        => AXI_08_AWLEN when i_axi_sel = '1' else i_write_pkgs(8).awlen,
			AXI_08_AWSIZE       => AXI_08_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_08_AWVALID      => AXI_08_AWVALID when i_axi_sel = '1' else i_write_pkgs(8).awvalid,
			AXI_08_AWREADY      => AXI_08_AWREADY when i_axi_sel = '1' else o_write_pkgs(8).awready,
			AXI_08_RREADY       => AXI_08_RREADY when i_axi_sel = '1' else i_read_pkgs(8).rready,
			AXI_08_BREADY       => AXI_08_BREADY when i_axi_sel = '1' else i_write_pkgs(8).bready,
			AXI_08_WDATA        => AXI_08_WDATA when i_axi_sel = '1' else i_write_pkgs(8).wdata,
			AXI_08_WLAST        => AXI_08_WLAST when i_axi_sel = '1' else i_write_pkgs(8).wlast,
			AXI_08_WSTRB        => AXI_08_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_08_WDATA_PARITY => AXI_08_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(8).wdata_parity,
			AXI_08_WVALID       => AXI_08_WVALID when i_axi_sel = '1' else i_write_pkgs(8).wvalid,
			AXI_08_RDATA_PARITY => AXI_08_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(8).rdata_parity,
			AXI_08_RDATA        => AXI_08_RDATA when i_axi_sel = '1' else o_read_pkgs(8).rdata,
			AXI_08_RID          => AXI_08_RID when i_axi_sel = '1' else o_read_pkgs(8).rid,
			AXI_08_RLAST        => AXI_08_RLAST when i_axi_sel = '1' else o_read_pkgs(8).rlast,
			AXI_08_RRESP        => AXI_08_RRESP when i_axi_sel = '1' else o_read_pkgs(8).rresp,
			AXI_08_RVALID       => AXI_08_RVALID when i_axi_sel = '1' else o_read_pkgs(8).rvalid,
			AXI_08_WREADY       => AXI_08_WREADY when i_axi_sel = '1' else o_write_pkgs(8).wready,
			AXI_08_BID          => AXI_08_BID when i_axi_sel = '1' else o_write_pkgs(8).bid,
			AXI_08_BRESP        => AXI_08_BRESP when i_axi_sel = '1' else o_write_pkgs(8).bresp,
			AXI_08_BVALID       => AXI_08_BVALID when i_axi_sel = '1' else o_write_pkgs(8).bvalid,

			AXI_09_ACLK         => AXI_09_ACLK,
			AXI_09_ARESET_N     => AXI_09_ARESET_N,
			AXI_09_ARADDR       => AXI_09_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(9).araddr),
			AXI_09_ARBURST      => AXI_09_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_09_ARID         => AXI_09_ARID when i_axi_sel = '1' else i_read_pkgs(9).arid,
			AXI_09_ARLEN        => AXI_09_ARLEN when i_axi_sel = '1' else i_read_pkgs(9).arlen,
			AXI_09_ARSIZE       => AXI_09_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_09_ARVALID      => AXI_09_ARVALID when i_axi_sel = '1' else i_read_pkgs(9).arvalid,
			AXI_09_ARREADY      => AXI_09_ARREADY when i_axi_sel = '1' else o_read_pkgs(9).arready,
			AXI_09_AWADDR       => AXI_09_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(9).awaddr),
			AXI_09_AWBURST      => AXI_09_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_09_AWID         => AXI_09_AWID when i_axi_sel = '1' else i_write_pkgs(9).awid,
			AXI_09_AWLEN        => AXI_09_AWLEN when i_axi_sel = '1' else i_write_pkgs(9).awlen,
			AXI_09_AWSIZE       => AXI_09_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_09_AWVALID      => AXI_09_AWVALID when i_axi_sel = '1' else i_write_pkgs(9).awvalid,
			AXI_09_AWREADY      => AXI_09_AWREADY when i_axi_sel = '1' else o_write_pkgs(9).awready,
			AXI_09_RREADY       => AXI_09_RREADY when i_axi_sel = '1' else i_read_pkgs(9).rready,
			AXI_09_BREADY       => AXI_09_BREADY when i_axi_sel = '1' else i_write_pkgs(9).bready,
			AXI_09_WDATA        => AXI_09_WDATA when i_axi_sel = '1' else i_write_pkgs(9).wdata,
			AXI_09_WLAST        => AXI_09_WLAST when i_axi_sel = '1' else i_write_pkgs(9).wlast,
			AXI_09_WSTRB        => AXI_09_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_09_WDATA_PARITY => AXI_09_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(9).wdata_parity,
			AXI_09_WVALID       => AXI_09_WVALID when i_axi_sel = '1' else i_write_pkgs(9).wvalid,
			AXI_09_RDATA_PARITY => AXI_09_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(9).rdata_parity,
			AXI_09_RDATA        => AXI_09_RDATA when i_axi_sel = '1' else o_read_pkgs(9).rdata,
			AXI_09_RID          => AXI_09_RID when i_axi_sel = '1' else o_read_pkgs(9).rid,
			AXI_09_RLAST        => AXI_09_RLAST when i_axi_sel = '1' else o_read_pkgs(9).rlast,
			AXI_09_RRESP        => AXI_09_RRESP when i_axi_sel = '1' else o_read_pkgs(9).rresp,
			AXI_09_RVALID       => AXI_09_RVALID when i_axi_sel = '1' else o_read_pkgs(9).rvalid,
			AXI_09_WREADY       => AXI_09_WREADY when i_axi_sel = '1' else o_write_pkgs(9).wready,
			AXI_09_BID          => AXI_09_BID when i_axi_sel = '1' else o_write_pkgs(9).bid,
			AXI_09_BRESP        => AXI_09_BRESP when i_axi_sel = '1' else o_write_pkgs(9).bresp,
			AXI_09_BVALID       => AXI_09_BVALID when i_axi_sel = '1' else o_write_pkgs(9).bvalid,

			AXI_10_ACLK         => AXI_10_ACLK,
			AXI_10_ARESET_N     => AXI_10_ARESET_N,
			AXI_10_ARADDR       => AXI_10_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(10).araddr),
			AXI_10_ARBURST      => AXI_10_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_10_ARID         => AXI_10_ARID when i_axi_sel = '1' else i_read_pkgs(10).arid,
			AXI_10_ARLEN        => AXI_10_ARLEN when i_axi_sel = '1' else i_read_pkgs(10).arlen,
			AXI_10_ARSIZE       => AXI_10_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_10_ARVALID      => AXI_10_ARVALID when i_axi_sel = '1' else i_read_pkgs(10).arvalid,
			AXI_10_ARREADY      => AXI_10_ARREADY when i_axi_sel = '1' else o_read_pkgs(10).arready,
			AXI_10_AWADDR       => AXI_10_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(10).awaddr),
			AXI_10_AWBURST      => AXI_10_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_10_AWID         => AXI_10_AWID when i_axi_sel = '1' else i_write_pkgs(10).awid,
			AXI_10_AWLEN        => AXI_10_AWLEN when i_axi_sel = '1' else i_write_pkgs(10).awlen,
			AXI_10_AWSIZE       => AXI_10_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_10_AWVALID      => AXI_10_AWVALID when i_axi_sel = '1' else i_write_pkgs(10).awvalid,
			AXI_10_AWREADY      => AXI_10_AWREADY when i_axi_sel = '1' else o_write_pkgs(10).awready,
			AXI_10_RREADY       => AXI_10_RREADY when i_axi_sel = '1' else i_read_pkgs(10).rready,
			AXI_10_BREADY       => AXI_10_BREADY when i_axi_sel = '1' else i_write_pkgs(10).bready,
			AXI_10_WDATA        => AXI_10_WDATA when i_axi_sel = '1' else i_write_pkgs(10).wdata,
			AXI_10_WLAST        => AXI_10_WLAST when i_axi_sel = '1' else i_write_pkgs(10).wlast,
			AXI_10_WSTRB        => AXI_10_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_10_WDATA_PARITY => AXI_10_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(10).wdata_parity,
			AXI_10_WVALID       => AXI_10_WVALID when i_axi_sel = '1' else i_write_pkgs(10).wvalid,
			AXI_10_RDATA_PARITY => AXI_10_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(10).rdata_parity,
			AXI_10_RDATA        => AXI_10_RDATA when i_axi_sel = '1' else o_read_pkgs(10).rdata,
			AXI_10_RID          => AXI_10_RID when i_axi_sel = '1' else o_read_pkgs(10).rid,
			AXI_10_RLAST        => AXI_10_RLAST when i_axi_sel = '1' else o_read_pkgs(10).rlast,
			AXI_10_RRESP        => AXI_10_RRESP when i_axi_sel = '1' else o_read_pkgs(10).rresp,
			AXI_10_RVALID       => AXI_10_RVALID when i_axi_sel = '1' else o_read_pkgs(10).rvalid,
			AXI_10_WREADY       => AXI_10_WREADY when i_axi_sel = '1' else o_write_pkgs(10).wready,
			AXI_10_BID          => AXI_10_BID when i_axi_sel = '1' else o_write_pkgs(10).bid,
			AXI_10_BRESP        => AXI_10_BRESP when i_axi_sel = '1' else o_write_pkgs(10).bresp,
			AXI_10_BVALID       => AXI_10_BVALID when i_axi_sel = '1' else o_write_pkgs(10).bvalid,

			AXI_11_ACLK         => AXI_11_ACLK,
			AXI_11_ARESET_N     => AXI_11_ARESET_N,
			AXI_11_ARADDR       => AXI_11_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(11).araddr),
			AXI_11_ARBURST      => AXI_11_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_11_ARID         => AXI_11_ARID when i_axi_sel = '1' else i_read_pkgs(11).arid,
			AXI_11_ARLEN        => AXI_11_ARLEN when i_axi_sel = '1' else i_read_pkgs(11).arlen,
			AXI_11_ARSIZE       => AXI_11_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_11_ARVALID      => AXI_11_ARVALID when i_axi_sel = '1' else i_read_pkgs(11).arvalid,
			AXI_11_ARREADY      => AXI_11_ARREADY when i_axi_sel = '1' else o_read_pkgs(11).arready,
			AXI_11_AWADDR       => AXI_11_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(11).awaddr),
			AXI_11_AWBURST      => AXI_11_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_11_AWID         => AXI_11_AWID when i_axi_sel = '1' else i_write_pkgs(11).awid,
			AXI_11_AWLEN        => AXI_11_AWLEN when i_axi_sel = '1' else i_write_pkgs(11).awlen,
			AXI_11_AWSIZE       => AXI_11_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_11_AWVALID      => AXI_11_AWVALID when i_axi_sel = '1' else i_write_pkgs(11).awvalid,
			AXI_11_AWREADY      => AXI_11_AWREADY when i_axi_sel = '1' else o_write_pkgs(11).awready,
			AXI_11_RREADY       => AXI_11_RREADY when i_axi_sel = '1' else i_read_pkgs(11).rready,
			AXI_11_BREADY       => AXI_11_BREADY when i_axi_sel = '1' else i_write_pkgs(11).bready,
			AXI_11_WDATA        => AXI_11_WDATA when i_axi_sel = '1' else i_write_pkgs(11).wdata,
			AXI_11_WLAST        => AXI_11_WLAST when i_axi_sel = '1' else i_write_pkgs(11).wlast,
			AXI_11_WSTRB        => AXI_11_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_11_WDATA_PARITY => AXI_11_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(11).wdata_parity,
			AXI_11_WVALID       => AXI_11_WVALID when i_axi_sel = '1' else i_write_pkgs(11).wvalid,
			AXI_11_RDATA_PARITY => AXI_11_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(11).rdata_parity,
			AXI_11_RDATA        => AXI_11_RDATA when i_axi_sel = '1' else o_read_pkgs(11).rdata,
			AXI_11_RID          => AXI_11_RID when i_axi_sel = '1' else o_read_pkgs(11).rid,
			AXI_11_RLAST        => AXI_11_RLAST when i_axi_sel = '1' else o_read_pkgs(11).rlast,
			AXI_11_RRESP        => AXI_11_RRESP when i_axi_sel = '1' else o_read_pkgs(11).rresp,
			AXI_11_RVALID       => AXI_11_RVALID when i_axi_sel = '1' else o_read_pkgs(11).rvalid,
			AXI_11_WREADY       => AXI_11_WREADY when i_axi_sel = '1' else o_write_pkgs(11).wready,
			AXI_11_BID          => AXI_11_BID when i_axi_sel = '1' else o_write_pkgs(11).bid,
			AXI_11_BRESP        => AXI_11_BRESP when i_axi_sel = '1' else o_write_pkgs(11).bresp,
			AXI_11_BVALID       => AXI_11_BVALID when i_axi_sel = '1' else o_write_pkgs(11).bvalid,

			AXI_12_ACLK         => AXI_12_ACLK,
			AXI_12_ARESET_N     => AXI_12_ARESET_N,
			AXI_12_ARADDR       => AXI_12_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(12).araddr),
			AXI_12_ARBURST      => AXI_12_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_12_ARID         => AXI_12_ARID when i_axi_sel = '1' else i_read_pkgs(12).arid,
			AXI_12_ARLEN        => AXI_12_ARLEN when i_axi_sel = '1' else i_read_pkgs(12).arlen,
			AXI_12_ARSIZE       => AXI_12_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_12_ARVALID      => AXI_12_ARVALID when i_axi_sel = '1' else i_read_pkgs(12).arvalid,
			AXI_12_ARREADY      => AXI_12_ARREADY when i_axi_sel = '1' else o_read_pkgs(12).arready,
			AXI_12_AWADDR       => AXI_12_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(12).awaddr),
			AXI_12_AWBURST      => AXI_12_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_12_AWID         => AXI_12_AWID when i_axi_sel = '1' else i_write_pkgs(12).awid,
			AXI_12_AWLEN        => AXI_12_AWLEN when i_axi_sel = '1' else i_write_pkgs(12).awlen,
			AXI_12_AWSIZE       => AXI_12_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_12_AWVALID      => AXI_12_AWVALID when i_axi_sel = '1' else i_write_pkgs(12).awvalid,
			AXI_12_AWREADY      => AXI_12_AWREADY when i_axi_sel = '1' else o_write_pkgs(12).awready,
			AXI_12_RREADY       => AXI_12_RREADY when i_axi_sel = '1' else i_read_pkgs(12).rready,
			AXI_12_BREADY       => AXI_12_BREADY when i_axi_sel = '1' else i_write_pkgs(12).bready,
			AXI_12_WDATA        => AXI_12_WDATA when i_axi_sel = '1' else i_write_pkgs(12).wdata,
			AXI_12_WLAST        => AXI_12_WLAST when i_axi_sel = '1' else i_write_pkgs(12).wlast,
			AXI_12_WSTRB        => AXI_12_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_12_WDATA_PARITY => AXI_12_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(12).wdata_parity,
			AXI_12_WVALID       => AXI_12_WVALID when i_axi_sel = '1' else i_write_pkgs(12).wvalid,
			AXI_12_RDATA_PARITY => AXI_12_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(12).rdata_parity,
			AXI_12_RDATA        => AXI_12_RDATA when i_axi_sel = '1' else o_read_pkgs(12).rdata,
			AXI_12_RID          => AXI_12_RID when i_axi_sel = '1' else o_read_pkgs(12).rid,
			AXI_12_RLAST        => AXI_12_RLAST when i_axi_sel = '1' else o_read_pkgs(12).rlast,
			AXI_12_RRESP        => AXI_12_RRESP when i_axi_sel = '1' else o_read_pkgs(12).rresp,
			AXI_12_RVALID       => AXI_12_RVALID when i_axi_sel = '1' else o_read_pkgs(12).rvalid,
			AXI_12_WREADY       => AXI_12_WREADY when i_axi_sel = '1' else o_write_pkgs(12).wready,
			AXI_12_BID          => AXI_12_BID when i_axi_sel = '1' else o_write_pkgs(12).bid,
			AXI_12_BRESP        => AXI_12_BRESP when i_axi_sel = '1' else o_write_pkgs(12).bresp,
			AXI_12_BVALID       => AXI_12_BVALID when i_axi_sel = '1' else o_write_pkgs(12).bvalid,

			AXI_13_ACLK         => AXI_13_ACLK,
			AXI_13_ARESET_N     => AXI_13_ARESET_N,
			AXI_13_ARADDR       => AXI_13_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(13).araddr),
			AXI_13_ARBURST      => AXI_13_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_13_ARID         => AXI_13_ARID when i_axi_sel = '1' else i_read_pkgs(13).arid,
			AXI_13_ARLEN        => AXI_13_ARLEN when i_axi_sel = '1' else i_read_pkgs(13).arlen,
			AXI_13_ARSIZE       => AXI_13_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_13_ARVALID      => AXI_13_ARVALID when i_axi_sel = '1' else i_read_pkgs(13).arvalid,
			AXI_13_ARREADY      => AXI_13_ARREADY when i_axi_sel = '1' else o_read_pkgs(13).arready,
			AXI_13_AWADDR       => AXI_13_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(13).awaddr),
			AXI_13_AWBURST      => AXI_13_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_13_AWID         => AXI_13_AWID when i_axi_sel = '1' else i_write_pkgs(13).awid,
			AXI_13_AWLEN        => AXI_13_AWLEN when i_axi_sel = '1' else i_write_pkgs(13).awlen,
			AXI_13_AWSIZE       => AXI_13_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_13_AWVALID      => AXI_13_AWVALID when i_axi_sel = '1' else i_write_pkgs(13).awvalid,
			AXI_13_AWREADY      => AXI_13_AWREADY when i_axi_sel = '1' else o_write_pkgs(13).awready,
			AXI_13_RREADY       => AXI_13_RREADY when i_axi_sel = '1' else i_read_pkgs(13).rready,
			AXI_13_BREADY       => AXI_13_BREADY when i_axi_sel = '1' else i_write_pkgs(13).bready,
			AXI_13_WDATA        => AXI_13_WDATA when i_axi_sel = '1' else i_write_pkgs(13).wdata,
			AXI_13_WLAST        => AXI_13_WLAST when i_axi_sel = '1' else i_write_pkgs(13).wlast,
			AXI_13_WSTRB        => AXI_13_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_13_WDATA_PARITY => AXI_13_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(13).wdata_parity,
			AXI_13_WVALID       => AXI_13_WVALID when i_axi_sel = '1' else i_write_pkgs(13).wvalid,
			AXI_13_RDATA_PARITY => AXI_13_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(13).rdata_parity,
			AXI_13_RDATA        => AXI_13_RDATA when i_axi_sel = '1' else o_read_pkgs(13).rdata,
			AXI_13_RID          => AXI_13_RID when i_axi_sel = '1' else o_read_pkgs(13).rid,
			AXI_13_RLAST        => AXI_13_RLAST when i_axi_sel = '1' else o_read_pkgs(13).rlast,
			AXI_13_RRESP        => AXI_13_RRESP when i_axi_sel = '1' else o_read_pkgs(13).rresp,
			AXI_13_RVALID       => AXI_13_RVALID when i_axi_sel = '1' else o_read_pkgs(13).rvalid,
			AXI_13_WREADY       => AXI_13_WREADY when i_axi_sel = '1' else o_write_pkgs(13).wready,
			AXI_13_BID          => AXI_13_BID when i_axi_sel = '1' else o_write_pkgs(13).bid,
			AXI_13_BRESP        => AXI_13_BRESP when i_axi_sel = '1' else o_write_pkgs(13).bresp,
			AXI_13_BVALID       => AXI_13_BVALID when i_axi_sel = '1' else o_write_pkgs(13).bvalid,

			AXI_14_ACLK         => AXI_14_ACLK,
			AXI_14_ARESET_N     => AXI_14_ARESET_N,
			AXI_14_ARADDR       => AXI_14_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(14).araddr),
			AXI_14_ARBURST      => AXI_14_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_14_ARID         => AXI_14_ARID when i_axi_sel = '1' else i_read_pkgs(14).arid,
			AXI_14_ARLEN        => AXI_14_ARLEN when i_axi_sel = '1' else i_read_pkgs(14).arlen,
			AXI_14_ARSIZE       => AXI_14_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_14_ARVALID      => AXI_14_ARVALID when i_axi_sel = '1' else i_read_pkgs(14).arvalid,
			AXI_14_ARREADY      => AXI_14_ARREADY when i_axi_sel = '1' else o_read_pkgs(14).arready,
			AXI_14_AWADDR       => AXI_14_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(14).awaddr),
			AXI_14_AWBURST      => AXI_14_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_14_AWID         => AXI_14_AWID when i_axi_sel = '1' else i_write_pkgs(14).awid,
			AXI_14_AWLEN        => AXI_14_AWLEN when i_axi_sel = '1' else i_write_pkgs(14).awlen,
			AXI_14_AWSIZE       => AXI_14_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_14_AWVALID      => AXI_14_AWVALID when i_axi_sel = '1' else i_write_pkgs(14).awvalid,
			AXI_14_AWREADY      => AXI_14_AWREADY when i_axi_sel = '1' else o_write_pkgs(14).awready,
			AXI_14_RREADY       => AXI_14_RREADY when i_axi_sel = '1' else i_read_pkgs(14).rready,
			AXI_14_BREADY       => AXI_14_BREADY when i_axi_sel = '1' else i_write_pkgs(14).bready,
			AXI_14_WDATA        => AXI_14_WDATA when i_axi_sel = '1' else i_write_pkgs(14).wdata,
			AXI_14_WLAST        => AXI_14_WLAST when i_axi_sel = '1' else i_write_pkgs(14).wlast,
			AXI_14_WSTRB        => AXI_14_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_14_WDATA_PARITY => AXI_14_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(14).wdata_parity,
			AXI_14_WVALID       => AXI_14_WVALID when i_axi_sel = '1' else i_write_pkgs(14).wvalid,
			AXI_14_RDATA_PARITY => AXI_14_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(14).rdata_parity,
			AXI_14_RDATA        => AXI_14_RDATA when i_axi_sel = '1' else o_read_pkgs(14).rdata,
			AXI_14_RID          => AXI_14_RID when i_axi_sel = '1' else o_read_pkgs(14).rid,
			AXI_14_RLAST        => AXI_14_RLAST when i_axi_sel = '1' else o_read_pkgs(14).rlast,
			AXI_14_RRESP        => AXI_14_RRESP when i_axi_sel = '1' else o_read_pkgs(14).rresp,
			AXI_14_RVALID       => AXI_14_RVALID when i_axi_sel = '1' else o_read_pkgs(14).rvalid,
			AXI_14_WREADY       => AXI_14_WREADY when i_axi_sel = '1' else o_write_pkgs(14).wready,
			AXI_14_BID          => AXI_14_BID when i_axi_sel = '1' else o_write_pkgs(14).bid,
			AXI_14_BRESP        => AXI_14_BRESP when i_axi_sel = '1' else o_write_pkgs(14).bresp,
			AXI_14_BVALID       => AXI_14_BVALID when i_axi_sel = '1' else o_write_pkgs(14).bvalid,

			AXI_15_ACLK         => AXI_15_ACLK,
			AXI_15_ARESET_N     => AXI_15_ARESET_N,
			AXI_15_ARADDR       => AXI_15_ARADDR when i_axi_sel = '1' else std_logic_vector(i_read_pkgs(15).araddr),
			AXI_15_ARBURST      => AXI_15_ARBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_15_ARID         => AXI_15_ARID when i_axi_sel = '1' else i_read_pkgs(15).arid,
			AXI_15_ARLEN        => AXI_15_ARLEN when i_axi_sel = '1' else i_read_pkgs(15).arlen,
			AXI_15_ARSIZE       => AXI_15_ARSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_15_ARVALID      => AXI_15_ARVALID when i_axi_sel = '1' else i_read_pkgs(15).arvalid,
			AXI_15_ARREADY      => AXI_15_ARREADY when i_axi_sel = '1' else o_read_pkgs(15).arready,
			AXI_15_AWADDR       => AXI_15_AWADDR when i_axi_sel = '1' else std_logic_vector(i_write_pkgs(15).awaddr),
			AXI_15_AWBURST      => AXI_15_AWBURST when i_axi_sel = '1' else std_logic_vector(hbm_burstmode),
			AXI_15_AWID         => AXI_15_AWID when i_axi_sel = '1' else i_write_pkgs(15).awid,
			AXI_15_AWLEN        => AXI_15_AWLEN when i_axi_sel = '1' else i_write_pkgs(15).awlen,
			AXI_15_AWSIZE       => AXI_15_AWSIZE when i_axi_sel = '1' else std_logic_vector(hbm_burstsize),
			AXI_15_AWVALID      => AXI_15_AWVALID when i_axi_sel = '1' else i_write_pkgs(15).awvalid,
			AXI_15_AWREADY      => AXI_15_AWREADY when i_axi_sel = '1' else o_write_pkgs(15).awready,
			AXI_15_RREADY       => AXI_15_RREADY when i_axi_sel = '1' else i_read_pkgs(15).rready,
			AXI_15_BREADY       => AXI_15_BREADY when i_axi_sel = '1' else i_write_pkgs(15).bready,
			AXI_15_WDATA        => AXI_15_WDATA when i_axi_sel = '1' else i_write_pkgs(15).wdata,
			AXI_15_WLAST        => AXI_15_WLAST when i_axi_sel = '1' else i_write_pkgs(15).wlast,
			AXI_15_WSTRB        => AXI_15_WSTRB when i_axi_sel = '1' else std_logic_vector(hbm_strobe_setting),
			AXI_15_WDATA_PARITY => AXI_15_WDATA_PARITY when i_axi_sel = '1' else i_write_pkgs(15).wdata_parity,
			AXI_15_WVALID       => AXI_15_WVALID when i_axi_sel = '1' else i_write_pkgs(15).wvalid,
			AXI_15_RDATA_PARITY => AXI_15_RDATA_PARITY when i_axi_sel = '1' else o_read_pkgs(15).rdata_parity,
			AXI_15_RDATA        => AXI_15_RDATA when i_axi_sel = '1' else o_read_pkgs(15).rdata,
			AXI_15_RID          => AXI_15_RID when i_axi_sel = '1' else o_read_pkgs(15).rid,
			AXI_15_RLAST        => AXI_15_RLAST when i_axi_sel = '1' else o_read_pkgs(15).rlast,
			AXI_15_RRESP        => AXI_15_RRESP when i_axi_sel = '1' else o_read_pkgs(15).rresp,
			AXI_15_RVALID       => AXI_15_RVALID when i_axi_sel = '1' else o_read_pkgs(15).rvalid,
			AXI_15_WREADY       => AXI_15_WREADY when i_axi_sel = '1' else o_write_pkgs(15).wready,
			AXI_15_BID          => AXI_15_BID when i_axi_sel = '1' else o_write_pkgs(15).bid,
			AXI_15_BRESP        => AXI_15_BRESP when i_axi_sel = '1' else o_write_pkgs(15).bresp,
			AXI_15_BVALID       => AXI_15_BVALID when i_axi_sel = '1' else o_write_pkgs(15).bvalid,

			APB_0_PCLK          => APB_0_PCLK,
			APB_0_PRESET_N      => APB_0_PRESET_N,

			-- -- hbm read does not work if we don't drive these ports with zeros?
			-- APB_0_PWDATA        => (others => '0'),
			-- APB_0_PADDR         => (others => '0'),
			-- APB_0_PENABLE       => '0',
			-- APB_0_PSEL          => '0',
			-- APB_0_PWRITE        => '0',
			-- APB_0_PRDATA        => open,
			-- APB_0_PREADY        => open,
			-- APB_0_PSLVERR       => open,
			apb_complete_0      => o_initial_init_ready,
			DRAM_0_STAT_CATTRIP => open,
			DRAM_0_STAT_TEMP    => open
		);



	u_pbs_accel : entity work.tfhe_pbs_accelerator
		port map (
			i_clk               => TFHE_CLK,
			i_reset_n           => TFHE_RESET_N,
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

		
		u_pbs_lwe_to_hbm : entity work.pbs_lwe_n_storage_read_to_hbm
			port map (
				i_clk           => TFHE_CLK,
				i_coeffs        => lwe_n_buf_out,
				i_coeffs_valid  => lwe_n_buf_out_valid,
				i_reset         => lwe_n_buf_write_next_reset,
				i_hbm_write_out => hbm_write_out_pkgs_stack_1(channel_result_idx),
				o_hbm_write_in  => hbm_write_in_pkgs_stack_1(channel_result_idx),
				o_ram_coeff_idx => lwe_n_buf_rq_idx
			);


end architecture;
