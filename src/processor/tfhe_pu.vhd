library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

library work;
	use work.ip_cores_constants.all;
	use work.processor_utils.all;
	use work.datatypes_utils.all;
	use work.math_utils.all;
	use work.tfhe_constants.all;

-- 			                 ┌───────────────┐
-- AXI 00 to 15 from BD ───> │               │
-- 			                 │   AXI MUX     ├──> hbm_0
-- 			Packages ──────> │               │
-- 			                 └──────^────────┘
-- 			                        │
-- 			                    i_axi_sel[0]

-- 			                 ┌───────────────┐
-- AXI 16 to 31 from BD ───> │               │
-- 			                 │   AXI MUX     ├──> hbm_1
-- 			Packages ──────> │               │
-- 			                 └──────^────────┘
-- 			                        │
-- 			                    i_axi_sel[1]


entity tfhe_pu is
  port (

    -- AXI select
    i_axi_sel     : in  std_logic_vector(1 downto 0);

    --- Global signals
    -- i_clk                : in  std_ulogic;
	-- i_clk_ref            : in  std_ulogic; -- must be a raw clock pin, hbm-ip-core uses it internally to do the 900MHz clock
	-- i_clk_apb            : in  std_ulogic;
	-- RESET_N            : in  std_ulogic;
	-- RESET_N_apb        : in  std_ulogic;
	TFHE_CLK	   : in  std_logic;
	TFHE_RESET_N : in std_ulogic;




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

	-- ==================================================
	-- AXI_16
	-- ==================================================

	AXI_16_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_16_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_16_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_16_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_16_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_16_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_16_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_16_ARVALID      : in  std_logic;
	AXI_16_ARREADY      : out std_logic;

	AXI_16_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_16_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_16_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_16_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_16_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_16_AWVALID      : in  std_logic;
	AXI_16_AWREADY      : out std_logic;

	AXI_16_RREADY       : in  std_logic;
	AXI_16_BREADY       : in  std_logic;

	AXI_16_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_16_WLAST        : in  std_logic;
	AXI_16_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_16_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_16_WVALID       : in  std_logic;

	AXI_16_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_16_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_16_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_16_RLAST        : out std_logic;
	AXI_16_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_16_RVALID       : out std_logic;

	AXI_16_WREADY       : out std_logic;

	AXI_16_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_16_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_16_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_17
	-- ==================================================

	AXI_17_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_17_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_17_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_17_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_17_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_17_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_17_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_17_ARVALID      : in  std_logic;
	AXI_17_ARREADY      : out std_logic;

	AXI_17_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_17_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_17_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_17_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_17_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_17_AWVALID      : in  std_logic;
	AXI_17_AWREADY      : out std_logic;

	AXI_17_RREADY       : in  std_logic;
	AXI_17_BREADY       : in  std_logic;

	AXI_17_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_17_WLAST        : in  std_logic;
	AXI_17_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_17_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_17_WVALID       : in  std_logic;

	AXI_17_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_17_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_17_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_17_RLAST        : out std_logic;
	AXI_17_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_17_RVALID       : out std_logic;

	AXI_17_WREADY       : out std_logic;

	AXI_17_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_17_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_17_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_18
	-- ==================================================

	AXI_18_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_18_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_18_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_18_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_18_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_18_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_18_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_18_ARVALID      : in  std_logic;
	AXI_18_ARREADY      : out std_logic;

	AXI_18_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_18_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_18_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_18_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_18_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_18_AWVALID      : in  std_logic;
	AXI_18_AWREADY      : out std_logic;

	AXI_18_RREADY       : in  std_logic;
	AXI_18_BREADY       : in  std_logic;

	AXI_18_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_18_WLAST        : in  std_logic;
	AXI_18_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_18_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_18_WVALID       : in  std_logic;

	AXI_18_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_18_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_18_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_18_RLAST        : out std_logic;
	AXI_18_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_18_RVALID       : out std_logic;

	AXI_18_WREADY       : out std_logic;

	AXI_18_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_18_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_18_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_19
	-- ==================================================

	AXI_19_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_19_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_19_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_19_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_19_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_19_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_19_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_19_ARVALID      : in  std_logic;
	AXI_19_ARREADY      : out std_logic;

	AXI_19_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_19_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_19_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_19_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_19_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_19_AWVALID      : in  std_logic;
	AXI_19_AWREADY      : out std_logic;

	AXI_19_RREADY       : in  std_logic;
	AXI_19_BREADY       : in  std_logic;

	AXI_19_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_19_WLAST        : in  std_logic;
	AXI_19_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_19_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_19_WVALID       : in  std_logic;

	AXI_19_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_19_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_19_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_19_RLAST        : out std_logic;
	AXI_19_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_19_RVALID       : out std_logic;

	AXI_19_WREADY       : out std_logic;

	AXI_19_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_19_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_19_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_20
	-- ==================================================

	AXI_20_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_20_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_20_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_20_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_20_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_20_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_20_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_20_ARVALID      : in  std_logic;
	AXI_20_ARREADY      : out std_logic;

	AXI_20_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_20_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_20_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_20_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_20_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_20_AWVALID      : in  std_logic;
	AXI_20_AWREADY      : out std_logic;

	AXI_20_RREADY       : in  std_logic;
	AXI_20_BREADY       : in  std_logic;

	AXI_20_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_20_WLAST        : in  std_logic;
	AXI_20_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_20_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_20_WVALID       : in  std_logic;

	AXI_20_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_20_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_20_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_20_RLAST        : out std_logic;
	AXI_20_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_20_RVALID       : out std_logic;

	AXI_20_WREADY       : out std_logic;

	AXI_20_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_20_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_20_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_21
	-- ==================================================

	AXI_21_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_21_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_21_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_21_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_21_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_21_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_21_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_21_ARVALID      : in  std_logic;
	AXI_21_ARREADY      : out std_logic;

	AXI_21_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_21_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_21_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_21_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_21_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_21_AWVALID      : in  std_logic;
	AXI_21_AWREADY      : out std_logic;

	AXI_21_RREADY       : in  std_logic;
	AXI_21_BREADY       : in  std_logic;

	AXI_21_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_21_WLAST        : in  std_logic;
	AXI_21_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_21_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_21_WVALID       : in  std_logic;

	AXI_21_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_21_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_21_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_21_RLAST        : out std_logic;
	AXI_21_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_21_RVALID       : out std_logic;

	AXI_21_WREADY       : out std_logic;

	AXI_21_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_21_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_21_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_22
	-- ==================================================

	AXI_22_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_22_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_22_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_22_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_22_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_22_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_22_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_22_ARVALID      : in  std_logic;
	AXI_22_ARREADY      : out std_logic;

	AXI_22_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_22_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_22_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_22_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_22_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_22_AWVALID      : in  std_logic;
	AXI_22_AWREADY      : out std_logic;

	AXI_22_RREADY       : in  std_logic;
	AXI_22_BREADY       : in  std_logic;

	AXI_22_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_22_WLAST        : in  std_logic;
	AXI_22_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_22_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_22_WVALID       : in  std_logic;

	AXI_22_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_22_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_22_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_22_RLAST        : out std_logic;
	AXI_22_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_22_RVALID       : out std_logic;

	AXI_22_WREADY       : out std_logic;

	AXI_22_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_22_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_22_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_23
	-- ==================================================

	AXI_23_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_23_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_23_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_23_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_23_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_23_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_23_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_23_ARVALID      : in  std_logic;
	AXI_23_ARREADY      : out std_logic;

	AXI_23_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_23_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_23_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_23_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_23_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_23_AWVALID      : in  std_logic;
	AXI_23_AWREADY      : out std_logic;

	AXI_23_RREADY       : in  std_logic;
	AXI_23_BREADY       : in  std_logic;

	AXI_23_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_23_WLAST        : in  std_logic;
	AXI_23_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_23_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_23_WVALID       : in  std_logic;

	AXI_23_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_23_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_23_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_23_RLAST        : out std_logic;
	AXI_23_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_23_RVALID       : out std_logic;

	AXI_23_WREADY       : out std_logic;

	AXI_23_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_23_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_23_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_24
	-- ==================================================

	AXI_24_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_24_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_24_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_24_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_24_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_24_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_24_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_24_ARVALID      : in  std_logic;
	AXI_24_ARREADY      : out std_logic;

	AXI_24_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_24_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_24_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_24_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_24_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_24_AWVALID      : in  std_logic;
	AXI_24_AWREADY      : out std_logic;

	AXI_24_RREADY       : in  std_logic;
	AXI_24_BREADY       : in  std_logic;

	AXI_24_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_24_WLAST        : in  std_logic;
	AXI_24_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_24_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_24_WVALID       : in  std_logic;

	AXI_24_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_24_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_24_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_24_RLAST        : out std_logic;
	AXI_24_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_24_RVALID       : out std_logic;

	AXI_24_WREADY       : out std_logic;

	AXI_24_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_24_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_24_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_25
	-- ==================================================

	AXI_25_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_25_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_25_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_25_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_25_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_25_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_25_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_25_ARVALID      : in  std_logic;
	AXI_25_ARREADY      : out std_logic;

	AXI_25_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_25_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_25_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_25_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_25_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_25_AWVALID      : in  std_logic;
	AXI_25_AWREADY      : out std_logic;

	AXI_25_RREADY       : in  std_logic;
	AXI_25_BREADY       : in  std_logic;

	AXI_25_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_25_WLAST        : in  std_logic;
	AXI_25_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_25_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_25_WVALID       : in  std_logic;

	AXI_25_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_25_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_25_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_25_RLAST        : out std_logic;
	AXI_25_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_25_RVALID       : out std_logic;

	AXI_25_WREADY       : out std_logic;

	AXI_25_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_25_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_25_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_26
	-- ==================================================

	AXI_26_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_26_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_26_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_26_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_26_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_26_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_26_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_26_ARVALID      : in  std_logic;
	AXI_26_ARREADY      : out std_logic;

	AXI_26_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_26_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_26_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_26_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_26_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_26_AWVALID      : in  std_logic;
	AXI_26_AWREADY      : out std_logic;

	AXI_26_RREADY       : in  std_logic;
	AXI_26_BREADY       : in  std_logic;

	AXI_26_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_26_WLAST        : in  std_logic;
	AXI_26_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_26_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_26_WVALID       : in  std_logic;

	AXI_26_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_26_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_26_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_26_RLAST        : out std_logic;
	AXI_26_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_26_RVALID       : out std_logic;

	AXI_26_WREADY       : out std_logic;

	AXI_26_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_26_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_26_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_27
	-- ==================================================

	AXI_27_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_27_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_27_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_27_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_27_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_27_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_27_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_27_ARVALID      : in  std_logic;
	AXI_27_ARREADY      : out std_logic;

	AXI_27_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_27_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_27_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_27_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_27_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_27_AWVALID      : in  std_logic;
	AXI_27_AWREADY      : out std_logic;

	AXI_27_RREADY       : in  std_logic;
	AXI_27_BREADY       : in  std_logic;

	AXI_27_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_27_WLAST        : in  std_logic;
	AXI_27_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_27_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_27_WVALID       : in  std_logic;

	AXI_27_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_27_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_27_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_27_RLAST        : out std_logic;
	AXI_27_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_27_RVALID       : out std_logic;

	AXI_27_WREADY       : out std_logic;

	AXI_27_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_27_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_27_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_28
	-- ==================================================

	AXI_28_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_28_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_28_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_28_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_28_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_28_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_28_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_28_ARVALID      : in  std_logic;
	AXI_28_ARREADY      : out std_logic;

	AXI_28_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_28_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_28_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_28_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_28_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_28_AWVALID      : in  std_logic;
	AXI_28_AWREADY      : out std_logic;

	AXI_28_RREADY       : in  std_logic;
	AXI_28_BREADY       : in  std_logic;

	AXI_28_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_28_WLAST        : in  std_logic;
	AXI_28_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_28_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_28_WVALID       : in  std_logic;

	AXI_28_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_28_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_28_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_28_RLAST        : out std_logic;
	AXI_28_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_28_RVALID       : out std_logic;

	AXI_28_WREADY       : out std_logic;

	AXI_28_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_28_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_28_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_29
	-- ==================================================

	AXI_29_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_29_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_29_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_29_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_29_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_29_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_29_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_29_ARVALID      : in  std_logic;
	AXI_29_ARREADY      : out std_logic;

	AXI_29_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_29_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_29_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_29_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_29_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_29_AWVALID      : in  std_logic;
	AXI_29_AWREADY      : out std_logic;

	AXI_29_RREADY       : in  std_logic;
	AXI_29_BREADY       : in  std_logic;

	AXI_29_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_29_WLAST        : in  std_logic;
	AXI_29_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_29_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_29_WVALID       : in  std_logic;

	AXI_29_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_29_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_29_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_29_RLAST        : out std_logic;
	AXI_29_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_29_RVALID       : out std_logic;

	AXI_29_WREADY       : out std_logic;

	AXI_29_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_29_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_29_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_30
	-- ==================================================

	AXI_30_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_30_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_30_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_30_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_30_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_30_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_30_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_30_ARVALID      : in  std_logic;
	AXI_30_ARREADY      : out std_logic;

	AXI_30_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_30_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_30_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_30_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_30_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_30_AWVALID      : in  std_logic;
	AXI_30_AWREADY      : out std_logic;

	AXI_30_RREADY       : in  std_logic;
	AXI_30_BREADY       : in  std_logic;

	AXI_30_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_30_WLAST        : in  std_logic;
	AXI_30_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_30_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_30_WVALID       : in  std_logic;

	AXI_30_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_30_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_30_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_30_RLAST        : out std_logic;
	AXI_30_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_30_RVALID       : out std_logic;

	AXI_30_WREADY       : out std_logic;

	AXI_30_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_30_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_30_BVALID       : out std_logic;

	-- ==================================================
	-- AXI_31
	-- ==================================================

	AXI_31_ACLK         : in  std_logic;                                 -- 450 MHz
	AXI_31_ARESET_N     : in  std_logic;                                 -- set to 0 to reset. Reset before start of data traffic
	-- start addr. must be 128-bit aligned, size must be multiple of 128bit
	AXI_31_ARADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0); -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
	AXI_31_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);              -- read burst
	AXI_31_ARID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);              -- read addr id
	AXI_31_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);              -- burst length
	AXI_31_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);              -- burst size
	AXI_31_ARVALID      : in  std_logic;
	AXI_31_ARREADY      : out std_logic;

	AXI_31_AWADDR       : in  std_logic_vector(hbm_addr_width-1 downto 0);
	AXI_31_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width-1 downto 0);
	AXI_31_AWID         : in  std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_31_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width-1 downto 0);
	AXI_31_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width-1 downto 0);
	AXI_31_AWVALID      : in  std_logic;
	AXI_31_AWREADY      : out std_logic;

	AXI_31_RREADY       : in  std_logic;
	AXI_31_BREADY       : in  std_logic;

	AXI_31_WDATA        : in  std_logic_vector(hbm_data_width-1 downto 0);
	AXI_31_WLAST        : in  std_logic;
	AXI_31_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_31_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_31_WVALID       : in  std_logic;

	AXI_31_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
	AXI_31_RDATA        : out std_logic_vector(hbm_data_width-1 downto 0);
	AXI_31_RID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_31_RLAST        : out std_logic;
	AXI_31_RRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_31_RVALID       : out std_logic;

	AXI_31_WREADY       : out std_logic;

	AXI_31_BID          : out std_logic_vector(hbm_id_bit_width-1 downto 0);
	AXI_31_BRESP        : out std_logic_vector(hbm_resp_bit_width-1 downto 0);
	AXI_31_BVALID       : out std_logic;


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

architecture rtl of tfhe_pu is

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

	
	

begin


	ai_hbm_out(0)                            <= hbm_read_out_pkgs_stack_1(channel_ai_idx);
	hbm_read_in_pkgs_stack_1(channel_ai_idx) <= ai_hbm_in(0);

	-- we use stack 0 for bsk. Throw away data from unused ports.
	bsk_hbm_out                                           <= hbm_read_out_pkgs_stack_0(0 to bsk_hbm_out'length - 1);
	hbm_read_in_pkgs_stack_0(0 to bsk_hbm_out'length - 1) <= bsk_hbm_in;

	hbm_read_in_pkgs_stack_1(channel_ai_idx) <= ai_hbm_in(0);

	hbm_read_out_pkgs_stack_1 <= o_read_pkgs;

  ------------------------------------------------------------------
  -- HBM instance Stack 0 
  ------------------------------------------------------------------
	u_hbm_w_0_int : entity work.hbm_w_0
		port map (
			-- --------------------------------------------------
			-- AXI select
			-- --------------------------------------------------
			i_axi_sel            => i_axi_sel(0),  -- Only HBM-AXI4 for now

			-- --------------------------------------------------
			-- High-throughput TFHE interface
			-- --------------------------------------------------
			-- i_write_pkgs         => i_write_pkgs,
			-- i_read_pkgs          => i_read_pkgs,
			-- o_write_pkgs         => o_write_pkgs,
			-- o_read_pkgs          => o_read_pkgs,
			
			i_write_pkgs         => hbm_write_in_pkgs_stack_0,
			i_read_pkgs          => hbm_read_in_pkgs_stack_0, -- bsk_buf reads this hbm and thus delivers the read_in_pkg
			o_write_pkgs         => hbm_write_out_pkgs_stack_0,
			o_read_pkgs          => hbm_read_out_pkgs_stack_0,
			o_initial_init_ready => o_initial_init_ready,

			TFHE_CLK             => TFHE_CLK,

			-- --------------------------------------------------
			-- External AXI master – common
			-- --------------------------------------------------
			HBM_REF_CLK_0        => HBM_REF_CLK_0,

			AXI_00_ACLK          => AXI_00_ACLK,
			AXI_01_ACLK          => AXI_01_ACLK,
			AXI_02_ACLK          => AXI_02_ACLK,
			AXI_03_ACLK          => AXI_03_ACLK,
			AXI_04_ACLK          => AXI_04_ACLK,
			AXI_05_ACLK          => AXI_05_ACLK,
			AXI_06_ACLK          => AXI_06_ACLK,
			AXI_07_ACLK          => AXI_07_ACLK,
			AXI_08_ACLK          => AXI_08_ACLK,
			AXI_09_ACLK          => AXI_09_ACLK,
			AXI_10_ACLK          => AXI_10_ACLK,
			AXI_11_ACLK          => AXI_11_ACLK,
			AXI_12_ACLK          => AXI_12_ACLK,
			AXI_13_ACLK          => AXI_13_ACLK,
			AXI_14_ACLK          => AXI_14_ACLK,
			AXI_15_ACLK          => AXI_15_ACLK,

			AXI_00_ARESET_N      => AXI_00_ARESET_N,
			AXI_01_ARESET_N      => AXI_01_ARESET_N,
			AXI_02_ARESET_N      => AXI_02_ARESET_N,
			AXI_03_ARESET_N      => AXI_03_ARESET_N,
			AXI_04_ARESET_N      => AXI_04_ARESET_N,
			AXI_05_ARESET_N      => AXI_05_ARESET_N,
			AXI_06_ARESET_N      => AXI_06_ARESET_N,
			AXI_07_ARESET_N      => AXI_07_ARESET_N,
			AXI_08_ARESET_N      => AXI_08_ARESET_N,
			AXI_09_ARESET_N      => AXI_09_ARESET_N,
			AXI_10_ARESET_N      => AXI_10_ARESET_N,
			AXI_11_ARESET_N      => AXI_11_ARESET_N,
			AXI_12_ARESET_N      => AXI_12_ARESET_N,
			AXI_13_ARESET_N      => AXI_13_ARESET_N,
			AXI_14_ARESET_N      => AXI_14_ARESET_N,
			AXI_15_ARESET_N      => AXI_15_ARESET_N,

			-- --------------------------------------------------
			-- AXI_00
			-- --------------------------------------------------
			AXI_00_ARADDR        => AXI_00_ARADDR,
			AXI_00_ARBURST       => AXI_00_ARBURST,
			AXI_00_ARID          => AXI_00_ARID,
			AXI_00_ARLEN         => AXI_00_ARLEN,
			AXI_00_ARSIZE        => AXI_00_ARSIZE,
			AXI_00_ARVALID       => AXI_00_ARVALID,
			AXI_00_ARREADY       => AXI_00_ARREADY,

			AXI_00_AWADDR        => AXI_00_AWADDR,
			AXI_00_AWBURST       => AXI_00_AWBURST,
			AXI_00_AWID          => AXI_00_AWID,
			AXI_00_AWLEN         => AXI_00_AWLEN,
			AXI_00_AWSIZE        => AXI_00_AWSIZE,
			AXI_00_AWVALID       => AXI_00_AWVALID,
			AXI_00_AWREADY       => AXI_00_AWREADY,

			AXI_00_RREADY        => AXI_00_RREADY,
			AXI_00_BREADY        => AXI_00_BREADY,

			AXI_00_WDATA         => AXI_00_WDATA,
			AXI_00_WLAST         => AXI_00_WLAST,
			AXI_00_WSTRB         => AXI_00_WSTRB,
			AXI_00_WDATA_PARITY  => AXI_00_WDATA_PARITY,
			AXI_00_WVALID        => AXI_00_WVALID,
			AXI_00_WREADY        => AXI_00_WREADY,

			AXI_00_RDATA         => AXI_00_RDATA,
			AXI_00_RDATA_PARITY  => AXI_00_RDATA_PARITY,
			AXI_00_RID           => AXI_00_RID,
			AXI_00_RLAST         => AXI_00_RLAST,
			AXI_00_RRESP         => AXI_00_RRESP,
			AXI_00_RVALID        => AXI_00_RVALID,

			AXI_00_BID           => AXI_00_BID,
			AXI_00_BRESP         => AXI_00_BRESP,
			AXI_00_BVALID        => AXI_00_BVALID,

			-- --------------------------------------------------
			-- AXI_01
			-- --------------------------------------------------
			AXI_01_ARADDR        => AXI_01_ARADDR,
			AXI_01_ARBURST       => AXI_01_ARBURST,
			AXI_01_ARID          => AXI_01_ARID,
			AXI_01_ARLEN         => AXI_01_ARLEN,
			AXI_01_ARSIZE        => AXI_01_ARSIZE,
			AXI_01_ARVALID       => AXI_01_ARVALID,
			AXI_01_ARREADY       => AXI_01_ARREADY,

			AXI_01_AWADDR        => AXI_01_AWADDR,
			AXI_01_AWBURST       => AXI_01_AWBURST,
			AXI_01_AWID          => AXI_01_AWID,
			AXI_01_AWLEN         => AXI_01_AWLEN,
			AXI_01_AWSIZE        => AXI_01_AWSIZE,
			AXI_01_AWVALID       => AXI_01_AWVALID,
			AXI_01_AWREADY       => AXI_01_AWREADY,

			AXI_01_RREADY        => AXI_01_RREADY,
			AXI_01_BREADY        => AXI_01_BREADY,

			AXI_01_WDATA         => AXI_01_WDATA,
			AXI_01_WLAST         => AXI_01_WLAST,
			AXI_01_WSTRB         => AXI_01_WSTRB,
			AXI_01_WDATA_PARITY  => AXI_01_WDATA_PARITY,
			AXI_01_WVALID        => AXI_01_WVALID,
			AXI_01_WREADY        => AXI_01_WREADY,

			AXI_01_RDATA         => AXI_01_RDATA,
			AXI_01_RDATA_PARITY  => AXI_01_RDATA_PARITY,
			AXI_01_RID           => AXI_01_RID,
			AXI_01_RLAST         => AXI_01_RLAST,
			AXI_01_RRESP         => AXI_01_RRESP,
			AXI_01_RVALID        => AXI_01_RVALID,

			AXI_01_BID           => AXI_01_BID,
			AXI_01_BRESP         => AXI_01_BRESP,
			AXI_01_BVALID        => AXI_01_BVALID,

			-- --------------------------------------------------
			-- AXI_02
			-- --------------------------------------------------
			AXI_02_ARADDR        => AXI_02_ARADDR,
			AXI_02_ARBURST       => AXI_02_ARBURST,
			AXI_02_ARID          => AXI_02_ARID,
			AXI_02_ARLEN         => AXI_02_ARLEN,
			AXI_02_ARSIZE        => AXI_02_ARSIZE,
			AXI_02_ARVALID       => AXI_02_ARVALID,
			AXI_02_ARREADY       => AXI_02_ARREADY,

			AXI_02_AWADDR        => AXI_02_AWADDR,
			AXI_02_AWBURST       => AXI_02_AWBURST,
			AXI_02_AWID          => AXI_02_AWID,
			AXI_02_AWLEN         => AXI_02_AWLEN,
			AXI_02_AWSIZE        => AXI_02_AWSIZE,
			AXI_02_AWVALID       => AXI_02_AWVALID,
			AXI_02_AWREADY       => AXI_02_AWREADY,

			AXI_02_RREADY        => AXI_02_RREADY,
			AXI_02_BREADY        => AXI_02_BREADY,

			AXI_02_WDATA         => AXI_02_WDATA,
			AXI_02_WLAST         => AXI_02_WLAST,
			AXI_02_WSTRB         => AXI_02_WSTRB,
			AXI_02_WDATA_PARITY  => AXI_02_WDATA_PARITY,
			AXI_02_WVALID        => AXI_02_WVALID,
			AXI_02_WREADY        => AXI_02_WREADY,

			AXI_02_RDATA         => AXI_02_RDATA,
			AXI_02_RDATA_PARITY  => AXI_02_RDATA_PARITY,
			AXI_02_RID           => AXI_02_RID,
			AXI_02_RLAST         => AXI_02_RLAST,
			AXI_02_RRESP         => AXI_02_RRESP,
			AXI_02_RVALID        => AXI_02_RVALID,

			AXI_02_BID           => AXI_02_BID,
			AXI_02_BRESP         => AXI_02_BRESP,
			AXI_02_BVALID        => AXI_02_BVALID,

			-- --------------------------------------------------
			-- AXI_03
			-- --------------------------------------------------
			AXI_03_ARADDR        => AXI_03_ARADDR,
			AXI_03_ARBURST       => AXI_03_ARBURST,
			AXI_03_ARID          => AXI_03_ARID,
			AXI_03_ARLEN         => AXI_03_ARLEN,
			AXI_03_ARSIZE        => AXI_03_ARSIZE,
			AXI_03_ARVALID       => AXI_03_ARVALID,
			AXI_03_ARREADY       => AXI_03_ARREADY,

			AXI_03_AWADDR        => AXI_03_AWADDR,
			AXI_03_AWBURST       => AXI_03_AWBURST,
			AXI_03_AWID          => AXI_03_AWID,
			AXI_03_AWLEN         => AXI_03_AWLEN,
			AXI_03_AWSIZE        => AXI_03_AWSIZE,
			AXI_03_AWVALID       => AXI_03_AWVALID,
			AXI_03_AWREADY       => AXI_03_AWREADY,
			AXI_03_RREADY        => AXI_03_RREADY,
			AXI_03_BREADY        => AXI_03_BREADY,

			AXI_03_WDATA         => AXI_03_WDATA,
			AXI_03_WLAST         => AXI_03_WLAST,
			AXI_03_WSTRB         => AXI_03_WSTRB,
			AXI_03_WDATA_PARITY  => AXI_03_WDATA_PARITY,
			AXI_03_WVALID        => AXI_03_WVALID,
			AXI_03_WREADY        => AXI_03_WREADY,

			AXI_03_RDATA         => AXI_03_RDATA,
			AXI_03_RDATA_PARITY  => AXI_03_RDATA_PARITY,
			AXI_03_RID           => AXI_03_RID,
			AXI_03_RLAST         => AXI_03_RLAST,
			AXI_03_RRESP         => AXI_03_RRESP,
			AXI_03_RVALID        => AXI_03_RVALID,

			AXI_03_BID           => AXI_03_BID,
			AXI_03_BRESP         => AXI_03_BRESP,
			AXI_03_BVALID        => AXI_03_BVALID,

			-- --------------------------------------------------
			-- AXI_04
			-- --------------------------------------------------
			AXI_04_ARADDR        => AXI_04_ARADDR,
			AXI_04_ARBURST       => AXI_04_ARBURST,
			AXI_04_ARID          => AXI_04_ARID,
			AXI_04_ARLEN         => AXI_04_ARLEN,
			AXI_04_ARSIZE        => AXI_04_ARSIZE,
			AXI_04_ARVALID       => AXI_04_ARVALID,
			AXI_04_ARREADY       => AXI_04_ARREADY,

			AXI_04_AWADDR        => AXI_04_AWADDR,
			AXI_04_AWBURST       => AXI_04_AWBURST,
			AXI_04_AWID          => AXI_04_AWID,
			AXI_04_AWLEN         => AXI_04_AWLEN,
			AXI_04_AWSIZE        => AXI_04_AWSIZE,
			AXI_04_AWVALID       => AXI_04_AWVALID,
			AXI_04_AWREADY       => AXI_04_AWREADY,
			AXI_04_RREADY        => AXI_04_RREADY,
			AXI_04_BREADY        => AXI_04_BREADY,

			AXI_04_WDATA         => AXI_04_WDATA,
			AXI_04_WLAST         => AXI_04_WLAST,
			AXI_04_WSTRB         => AXI_04_WSTRB,
			AXI_04_WDATA_PARITY  => AXI_04_WDATA_PARITY,
			AXI_04_WVALID        => AXI_04_WVALID,
			AXI_04_WREADY        => AXI_04_WREADY,

			AXI_04_RDATA         => AXI_04_RDATA,
			AXI_04_RDATA_PARITY  => AXI_04_RDATA_PARITY,
			AXI_04_RID           => AXI_04_RID,
			AXI_04_RLAST         => AXI_04_RLAST,
			AXI_04_RRESP         => AXI_04_RRESP,
			AXI_04_RVALID        => AXI_04_RVALID,

			AXI_04_BID           => AXI_04_BID,
			AXI_04_BRESP         => AXI_04_BRESP,
			AXI_04_BVALID        => AXI_04_BVALID,
			-- --------------------------------------------------
			-- AXI_05
			-- --------------------------------------------------
			AXI_05_ARADDR        => AXI_05_ARADDR,
			AXI_05_ARBURST       => AXI_05_ARBURST,
			AXI_05_ARID          => AXI_05_ARID,
			AXI_05_ARLEN         => AXI_05_ARLEN,
			AXI_05_ARSIZE        => AXI_05_ARSIZE,
			AXI_05_ARVALID       => AXI_05_ARVALID,
			AXI_05_ARREADY       => AXI_05_ARREADY,

			AXI_05_AWADDR        => AXI_05_AWADDR,
			AXI_05_AWBURST       => AXI_05_AWBURST,
			AXI_05_AWID          => AXI_05_AWID,
			AXI_05_AWLEN         => AXI_05_AWLEN,
			AXI_05_AWSIZE        => AXI_05_AWSIZE,
			AXI_05_AWVALID       => AXI_05_AWVALID,
			AXI_05_AWREADY       => AXI_05_AWREADY,

			AXI_05_RREADY        => AXI_05_RREADY,
			AXI_05_BREADY        => AXI_05_BREADY,

			AXI_05_WDATA         => AXI_05_WDATA,
			AXI_05_WLAST         => AXI_05_WLAST,
			AXI_05_WSTRB         => AXI_05_WSTRB,
			AXI_05_WDATA_PARITY  => AXI_05_WDATA_PARITY,
			AXI_05_WVALID        => AXI_05_WVALID,
			AXI_05_WREADY        => AXI_05_WREADY,

			AXI_05_RDATA         => AXI_05_RDATA,
			AXI_05_RDATA_PARITY  => AXI_05_RDATA_PARITY,
			AXI_05_RID           => AXI_05_RID,
			AXI_05_RLAST         => AXI_05_RLAST,
			AXI_05_RRESP         => AXI_05_RRESP,
			AXI_05_RVALID        => AXI_05_RVALID,

			AXI_05_BID           => AXI_05_BID,
			AXI_05_BRESP         => AXI_05_BRESP,
			AXI_05_BVALID        => AXI_05_BVALID,

			-- --------------------------------------------------
			-- AXI_06
			-- --------------------------------------------------
			AXI_06_ARADDR        => AXI_06_ARADDR,
			AXI_06_ARBURST       => AXI_06_ARBURST,
			AXI_06_ARID          => AXI_06_ARID,
			AXI_06_ARLEN         => AXI_06_ARLEN,
			AXI_06_ARSIZE        => AXI_06_ARSIZE,
			AXI_06_ARVALID       => AXI_06_ARVALID,
			AXI_06_ARREADY       => AXI_06_ARREADY,

			AXI_06_AWADDR        => AXI_06_AWADDR,
			AXI_06_AWBURST       => AXI_06_AWBURST,
			AXI_06_AWID          => AXI_06_AWID,
			AXI_06_AWLEN         => AXI_06_AWLEN,
			AXI_06_AWSIZE        => AXI_06_AWSIZE,
			AXI_06_AWVALID       => AXI_06_AWVALID,
			AXI_06_AWREADY       => AXI_06_AWREADY,

			AXI_06_RREADY        => AXI_06_RREADY,
			AXI_06_BREADY        => AXI_06_BREADY,

			AXI_06_WDATA         => AXI_06_WDATA,
			AXI_06_WLAST         => AXI_06_WLAST,
			AXI_06_WSTRB         => AXI_06_WSTRB,
			AXI_06_WDATA_PARITY  => AXI_06_WDATA_PARITY,
			AXI_06_WVALID        => AXI_06_WVALID,
			AXI_06_WREADY        => AXI_06_WREADY,

			AXI_06_RDATA         => AXI_06_RDATA,
			AXI_06_RDATA_PARITY  => AXI_06_RDATA_PARITY,
			AXI_06_RID           => AXI_06_RID,
			AXI_06_RLAST         => AXI_06_RLAST,
			AXI_06_RRESP         => AXI_06_RRESP,
			AXI_06_RVALID        => AXI_06_RVALID,

			AXI_06_BID           => AXI_06_BID,
			AXI_06_BRESP         => AXI_06_BRESP,
			AXI_06_BVALID        => AXI_06_BVALID,

			-- --------------------------------------------------
			-- AXI_07
			-- --------------------------------------------------
			AXI_07_ARADDR        => AXI_07_ARADDR,
			AXI_07_ARBURST       => AXI_07_ARBURST,
			AXI_07_ARID          => AXI_07_ARID,
			AXI_07_ARLEN         => AXI_07_ARLEN,
			AXI_07_ARSIZE        => AXI_07_ARSIZE,
			AXI_07_ARVALID       => AXI_07_ARVALID,
			AXI_07_ARREADY       => AXI_07_ARREADY,

			AXI_07_AWADDR        => AXI_07_AWADDR,
			AXI_07_AWBURST       => AXI_07_AWBURST,
			AXI_07_AWID          => AXI_07_AWID,
			AXI_07_AWLEN         => AXI_07_AWLEN,
			AXI_07_AWSIZE        => AXI_07_AWSIZE,
			AXI_07_AWVALID       => AXI_07_AWVALID,
			AXI_07_AWREADY       => AXI_07_AWREADY,
			AXI_07_RREADY        => AXI_07_RREADY,
			AXI_07_BREADY        => AXI_07_BREADY,

			AXI_07_WDATA         => AXI_07_WDATA,
			AXI_07_WLAST         => AXI_07_WLAST,
			AXI_07_WSTRB         => AXI_07_WSTRB,
			AXI_07_WDATA_PARITY  => AXI_07_WDATA_PARITY,
			AXI_07_WVALID        => AXI_07_WVALID,
			AXI_07_WREADY        => AXI_07_WREADY,

			AXI_07_RDATA         => AXI_07_RDATA,
			AXI_07_RDATA_PARITY  => AXI_07_RDATA_PARITY,
			AXI_07_RID           => AXI_07_RID,
			AXI_07_RLAST         => AXI_07_RLAST,
			AXI_07_RRESP         => AXI_07_RRESP,
			AXI_07_RVALID        => AXI_07_RVALID,

			AXI_07_BID           => AXI_07_BID,
			AXI_07_BRESP         => AXI_07_BRESP,
			AXI_07_BVALID        => AXI_07_BVALID,

			-- --------------------------------------------------
			-- AXI_08
			-- --------------------------------------------------
			AXI_08_ARADDR        => AXI_08_ARADDR,
			AXI_08_ARBURST       => AXI_08_ARBURST,
			AXI_08_ARID          => AXI_08_ARID,
			AXI_08_ARLEN         => AXI_08_ARLEN,
			AXI_08_ARSIZE        => AXI_08_ARSIZE,
			AXI_08_ARVALID       => AXI_08_ARVALID,
			AXI_08_ARREADY       => AXI_08_ARREADY,

			AXI_08_AWADDR        => AXI_08_AWADDR,
			AXI_08_AWBURST       => AXI_08_AWBURST,
			AXI_08_AWID          => AXI_08_AWID,
			AXI_08_AWLEN         => AXI_08_AWLEN,
			AXI_08_AWSIZE        => AXI_08_AWSIZE,
			AXI_08_AWVALID       => AXI_08_AWVALID,
			AXI_08_AWREADY       => AXI_08_AWREADY,
			AXI_08_RREADY        => AXI_08_RREADY,
			AXI_08_BREADY        => AXI_08_BREADY,

			AXI_08_WDATA         => AXI_08_WDATA,
			AXI_08_WLAST         => AXI_08_WLAST,
			AXI_08_WSTRB         => AXI_08_WSTRB,
			AXI_08_WDATA_PARITY  => AXI_08_WDATA_PARITY,
			AXI_08_WVALID        => AXI_08_WVALID,
			AXI_08_WREADY        => AXI_08_WREADY,

			AXI_08_RDATA         => AXI_08_RDATA,
			AXI_08_RDATA_PARITY  => AXI_08_RDATA_PARITY,
			AXI_08_RID           => AXI_08_RID,
			AXI_08_RLAST         => AXI_08_RLAST,
			AXI_08_RRESP         => AXI_08_RRESP,
			AXI_08_RVALID        => AXI_08_RVALID,

			AXI_08_BID           => AXI_08_BID,
			AXI_08_BRESP         => AXI_08_BRESP,
			AXI_08_BVALID        => AXI_08_BVALID,

			-- --------------------------------------------------
			-- AXI_09
			-- --------------------------------------------------
			AXI_09_ARADDR        => AXI_09_ARADDR,
			AXI_09_ARBURST       => AXI_09_ARBURST,
			AXI_09_ARID          => AXI_09_ARID,
			AXI_09_ARLEN         => AXI_09_ARLEN,
			AXI_09_ARSIZE        => AXI_09_ARSIZE,
			AXI_09_ARVALID       => AXI_09_ARVALID,
			AXI_09_ARREADY       => AXI_09_ARREADY,

			AXI_09_AWADDR        => AXI_09_AWADDR,
			AXI_09_AWBURST       => AXI_09_AWBURST,
			AXI_09_AWID          => AXI_09_AWID,
			AXI_09_AWLEN         => AXI_09_AWLEN,
			AXI_09_AWSIZE        => AXI_09_AWSIZE,
			AXI_09_AWVALID       => AXI_09_AWVALID,
			AXI_09_AWREADY       => AXI_09_AWREADY,

			AXI_09_RREADY        => AXI_09_RREADY,
			AXI_09_BREADY        => AXI_09_BREADY,

			AXI_09_WDATA         => AXI_09_WDATA,
			AXI_09_WLAST         => AXI_09_WLAST,
			AXI_09_WSTRB         => AXI_09_WSTRB,
			AXI_09_WDATA_PARITY  => AXI_09_WDATA_PARITY,
			AXI_09_WVALID        => AXI_09_WVALID,
			AXI_09_WREADY        => AXI_09_WREADY,

			AXI_09_RDATA         => AXI_09_RDATA,
			AXI_09_RDATA_PARITY  => AXI_09_RDATA_PARITY,
			AXI_09_RID           => AXI_09_RID,
			AXI_09_RLAST         => AXI_09_RLAST,
			AXI_09_RRESP         => AXI_09_RRESP,
			AXI_09_RVALID        => AXI_09_RVALID,

			AXI_09_BID           => AXI_09_BID,
			AXI_09_BRESP         => AXI_09_BRESP,
			AXI_09_BVALID        => AXI_09_BVALID,

			-- --------------------------------------------------
			-- AXI_10
			-- --------------------------------------------------
			AXI_10_ARADDR        => AXI_10_ARADDR,
			AXI_10_ARBURST       => AXI_10_ARBURST,
			AXI_10_ARID          => AXI_10_ARID,
			AXI_10_ARLEN         => AXI_10_ARLEN,
			AXI_10_ARSIZE        => AXI_10_ARSIZE,
			AXI_10_ARVALID       => AXI_10_ARVALID,
			AXI_10_ARREADY       => AXI_10_ARREADY,

			AXI_10_AWADDR        => AXI_10_AWADDR,
			AXI_10_AWBURST       => AXI_10_AWBURST,
			AXI_10_AWID          => AXI_10_AWID,
			AXI_10_AWLEN         => AXI_10_AWLEN,
			AXI_10_AWSIZE        => AXI_10_AWSIZE,
			AXI_10_AWVALID       => AXI_10_AWVALID,
			AXI_10_AWREADY       => AXI_10_AWREADY,

			AXI_10_RREADY        => AXI_10_RREADY,
			AXI_10_BREADY        => AXI_10_BREADY,

			AXI_10_WDATA         => AXI_10_WDATA,
			AXI_10_WLAST         => AXI_10_WLAST,
			AXI_10_WSTRB         => AXI_10_WSTRB,
			AXI_10_WDATA_PARITY  => AXI_10_WDATA_PARITY,
			AXI_10_WVALID        => AXI_10_WVALID,
			AXI_10_WREADY        => AXI_10_WREADY,

			AXI_10_RDATA         => AXI_10_RDATA,
			AXI_10_RDATA_PARITY  => AXI_10_RDATA_PARITY,
			AXI_10_RID           => AXI_10_RID,
			AXI_10_RLAST         => AXI_10_RLAST,
			AXI_10_RRESP         => AXI_10_RRESP,
			AXI_10_RVALID        => AXI_10_RVALID,

			AXI_10_BID           => AXI_10_BID,
			AXI_10_BRESP         => AXI_10_BRESP,
			AXI_10_BVALID        => AXI_10_BVALID,

			-- --------------------------------------------------
			-- AXI_11
			-- --------------------------------------------------
			AXI_11_ARADDR        => AXI_11_ARADDR,
			AXI_11_ARBURST       => AXI_11_ARBURST,
			AXI_11_ARID          => AXI_11_ARID,
			AXI_11_ARLEN         => AXI_11_ARLEN,
			AXI_11_ARSIZE        => AXI_11_ARSIZE,
			AXI_11_ARVALID       => AXI_11_ARVALID,
			AXI_11_ARREADY       => AXI_11_ARREADY,

			AXI_11_AWADDR        => AXI_11_AWADDR,
			AXI_11_AWBURST       => AXI_11_AWBURST,
			AXI_11_AWID          => AXI_11_AWID,
			AXI_11_AWLEN         => AXI_11_AWLEN,
			AXI_11_AWSIZE        => AXI_11_AWSIZE,
			AXI_11_AWVALID       => AXI_11_AWVALID,
			AXI_11_AWREADY       => AXI_11_AWREADY,

			AXI_11_RREADY        => AXI_11_RREADY,
			AXI_11_BREADY        => AXI_11_BREADY,

			AXI_11_WDATA         => AXI_11_WDATA,
			AXI_11_WLAST         => AXI_11_WLAST,
			AXI_11_WSTRB         => AXI_11_WSTRB,
			AXI_11_WDATA_PARITY  => AXI_11_WDATA_PARITY,
			AXI_11_WVALID        => AXI_11_WVALID,
			AXI_11_WREADY        => AXI_11_WREADY,

			AXI_11_RDATA         => AXI_11_RDATA,
			AXI_11_RDATA_PARITY  => AXI_11_RDATA_PARITY,
			AXI_11_RID           => AXI_11_RID,
			AXI_11_RLAST         => AXI_11_RLAST,
			AXI_11_RRESP         => AXI_11_RRESP,
			AXI_11_RVALID        => AXI_11_RVALID,

			AXI_11_BID           => AXI_11_BID,
			AXI_11_BRESP         => AXI_11_BRESP,
			AXI_11_BVALID        => AXI_11_BVALID,

			-- --------------------------------------------------
			-- AXI_12
			-- --------------------------------------------------
			AXI_12_ARADDR        => AXI_12_ARADDR,
			AXI_12_ARBURST       => AXI_12_ARBURST,
			AXI_12_ARID          => AXI_12_ARID,
			AXI_12_ARLEN         => AXI_12_ARLEN,
			AXI_12_ARSIZE        => AXI_12_ARSIZE,
			AXI_12_ARVALID       => AXI_12_ARVALID,
			AXI_12_ARREADY       => AXI_12_ARREADY,

			AXI_12_AWADDR        => AXI_12_AWADDR,
			AXI_12_AWBURST       => AXI_12_AWBURST,
			AXI_12_AWID          => AXI_12_AWID,
			AXI_12_AWLEN         => AXI_12_AWLEN,
			AXI_12_AWSIZE        => AXI_12_AWSIZE,
			AXI_12_AWVALID       => AXI_12_AWVALID,
			AXI_12_AWREADY       => AXI_12_AWREADY,

			AXI_12_RREADY        => AXI_12_RREADY,
			AXI_12_BREADY        => AXI_12_BREADY,

			AXI_12_WDATA         => AXI_12_WDATA,
			AXI_12_WLAST         => AXI_12_WLAST,
			AXI_12_WSTRB         => AXI_12_WSTRB,
			AXI_12_WDATA_PARITY  => AXI_12_WDATA_PARITY,
			AXI_12_WVALID        => AXI_12_WVALID,
			AXI_12_WREADY        => AXI_12_WREADY,

			AXI_12_RDATA         => AXI_12_RDATA,
			AXI_12_RDATA_PARITY  => AXI_12_RDATA_PARITY,
			AXI_12_RID           => AXI_12_RID,
			AXI_12_RLAST         => AXI_12_RLAST,
			AXI_12_RRESP         => AXI_12_RRESP,
			AXI_12_RVALID        => AXI_12_RVALID,

			AXI_12_BID           => AXI_12_BID,
			AXI_12_BRESP         => AXI_12_BRESP,
			AXI_12_BVALID        => AXI_12_BVALID,

			-- --------------------------------------------------
			-- AXI_13
			-- --------------------------------------------------
			AXI_13_ARADDR        => AXI_13_ARADDR,
			AXI_13_ARBURST       => AXI_13_ARBURST,
			AXI_13_ARID          => AXI_13_ARID,
			AXI_13_ARLEN         => AXI_13_ARLEN,
			AXI_13_ARSIZE        => AXI_13_ARSIZE,
			AXI_13_ARVALID       => AXI_13_ARVALID,
			AXI_13_ARREADY       => AXI_13_ARREADY,

			AXI_13_AWADDR        => AXI_13_AWADDR,
			AXI_13_AWBURST       => AXI_13_AWBURST,
			AXI_13_AWID          => AXI_13_AWID,
			AXI_13_AWLEN         => AXI_13_AWLEN,
			AXI_13_AWSIZE        => AXI_13_AWSIZE,
			AXI_13_AWVALID       => AXI_13_AWVALID,
			AXI_13_AWREADY       => AXI_13_AWREADY,

			AXI_13_RREADY        => AXI_13_RREADY,
			AXI_13_BREADY        => AXI_13_BREADY,

			AXI_13_WDATA         => AXI_13_WDATA,
			AXI_13_WLAST         => AXI_13_WLAST,
			AXI_13_WSTRB         => AXI_13_WSTRB,
			AXI_13_WDATA_PARITY  => AXI_13_WDATA_PARITY,
			AXI_13_WVALID        => AXI_13_WVALID,
			AXI_13_WREADY        => AXI_13_WREADY,

			AXI_13_RDATA         => AXI_13_RDATA,
			AXI_13_RDATA_PARITY  => AXI_13_RDATA_PARITY,
			AXI_13_RID           => AXI_13_RID,
			AXI_13_RLAST         => AXI_13_RLAST,
			AXI_13_RRESP         => AXI_13_RRESP,
			AXI_13_RVALID        => AXI_13_RVALID,

			AXI_13_BID           => AXI_13_BID,
			AXI_13_BRESP         => AXI_13_BRESP,
			AXI_13_BVALID        => AXI_13_BVALID,

			-- --------------------------------------------------
			-- AXI_14
			-- --------------------------------------------------
			AXI_14_ARADDR        => AXI_14_ARADDR,
			AXI_14_ARBURST       => AXI_14_ARBURST,
			AXI_14_ARID          => AXI_14_ARID,
			AXI_14_ARLEN         => AXI_14_ARLEN,
			AXI_14_ARSIZE        => AXI_14_ARSIZE,
			AXI_14_ARVALID       => AXI_14_ARVALID,
			AXI_14_ARREADY       => AXI_14_ARREADY,

			AXI_14_AWADDR        => AXI_14_AWADDR,
			AXI_14_AWBURST       => AXI_14_AWBURST,
			AXI_14_AWID          => AXI_14_AWID,
			AXI_14_AWLEN         => AXI_14_AWLEN,
			AXI_14_AWSIZE        => AXI_14_AWSIZE,
			AXI_14_AWVALID       => AXI_14_AWVALID,
			AXI_14_AWREADY       => AXI_14_AWREADY,

			AXI_14_RREADY        => AXI_14_RREADY,
			AXI_14_BREADY        => AXI_14_BREADY,

			AXI_14_WDATA         => AXI_14_WDATA,
			AXI_14_WLAST         => AXI_14_WLAST,
			AXI_14_WSTRB         => AXI_14_WSTRB,
			AXI_14_WDATA_PARITY  => AXI_14_WDATA_PARITY,
			AXI_14_WVALID        => AXI_14_WVALID,
			AXI_14_WREADY        => AXI_14_WREADY,

			AXI_14_RDATA         => AXI_14_RDATA,
			AXI_14_RDATA_PARITY  => AXI_14_RDATA_PARITY,
			AXI_14_RID           => AXI_14_RID,
			AXI_14_RLAST         => AXI_14_RLAST,
			AXI_14_RRESP         => AXI_14_RRESP,
			AXI_14_RVALID        => AXI_14_RVALID,

			AXI_14_BID           => AXI_14_BID,
			AXI_14_BRESP         => AXI_14_BRESP,
			AXI_14_BVALID        => AXI_14_BVALID,

			-- --------------------------------------------------
			-- AXI_15
			-- --------------------------------------------------
			AXI_15_ARADDR        => AXI_15_ARADDR,
			AXI_15_ARBURST       => AXI_15_ARBURST,
			AXI_15_ARID          => AXI_15_ARID,
			AXI_15_ARLEN         => AXI_15_ARLEN,
			AXI_15_ARSIZE        => AXI_15_ARSIZE,
			AXI_15_ARVALID       => AXI_15_ARVALID,
			AXI_15_ARREADY       => AXI_15_ARREADY,

			AXI_15_AWADDR        => AXI_15_AWADDR,
			AXI_15_AWBURST       => AXI_15_AWBURST,
			AXI_15_AWID          => AXI_15_AWID,
			AXI_15_AWLEN         => AXI_15_AWLEN,
			AXI_15_AWSIZE        => AXI_15_AWSIZE,
			AXI_15_AWVALID       => AXI_15_AWVALID,
			AXI_15_AWREADY       => AXI_15_AWREADY,
			AXI_15_RREADY        => AXI_15_RREADY,
			AXI_15_BREADY        => AXI_15_BREADY,

			AXI_15_WDATA         => AXI_15_WDATA,
			AXI_15_WLAST         => AXI_15_WLAST,
			AXI_15_WSTRB         => AXI_15_WSTRB,
			AXI_15_WDATA_PARITY  => AXI_15_WDATA_PARITY,
			AXI_15_WVALID        => AXI_15_WVALID,
			AXI_15_WREADY        => AXI_15_WREADY,

			AXI_15_RDATA         => AXI_15_RDATA,
			AXI_15_RDATA_PARITY  => AXI_15_RDATA_PARITY,
			AXI_15_RID           => AXI_15_RID,
			AXI_15_RLAST         => AXI_15_RLAST,
			AXI_15_RRESP         => AXI_15_RRESP,
			AXI_15_RVALID        => AXI_15_RVALID,

			AXI_15_BID           => AXI_15_BID,
			AXI_15_BRESP         => AXI_15_BRESP,
			AXI_15_BVALID        => AXI_15_BVALID,

			-- --------------------------------------------------
			-- APB / status
			-- --------------------------------------------------
			APB_0_PCLK           => APB_0_PCLK,
			APB_0_PRESET_N       => APB_0_PRESET_N,

			apb_complete_0       => apb_complete_0,
			DRAM_0_STAT_CATTRIP  => DRAM_0_STAT_CATTRIP,
			DRAM_0_STAT_TEMP     => DRAM_0_STAT_TEMP
		);

  ------------------------------------------------------------------
  -- HBM instance Stack 1 
  ------------------------------------------------------------------
	u_hbm_w_1_int : entity work.hbm_w_1
		port map (
			-- --------------------------------------------------
			-- AXI select
			-- --------------------------------------------------
			i_axi_sel            => i_axi_sel(1),  -- Only HBM-AXI4 for now

			-- --------------------------------------------------
			-- High-throughput TFHE interface
			-- --------------------------------------------------
			-- i_write_pkgs         => i_write_pkgs,
			-- i_read_pkgs          => i_read_pkgs,
			-- o_write_pkgs         => o_write_pkgs,
			-- o_read_pkgs          => o_read_pkgs,
			
			i_write_pkgs         => hbm_write_in_pkgs_stack_1,
			i_read_pkgs          => hbm_read_in_pkgs_stack_1, -- bsk_buf reads this hbm and thus delivers the read_in_pkg
			o_write_pkgs         => hbm_write_out_pkgs_stack_1,
			o_read_pkgs          => hbm_read_out_pkgs_stack_1,
			o_initial_init_ready => o_initial_init_ready,

			TFHE_CLK             => TFHE_CLK,

			-- --------------------------------------------------
			-- External AXI master – common
			-- --------------------------------------------------
			HBM_REF_CLK_0        => HBM_REF_CLK_0,

			AXI_00_ACLK          => AXI_16_ACLK,
			AXI_01_ACLK          => AXI_17_ACLK,
			AXI_02_ACLK          => AXI_18_ACLK,
			AXI_03_ACLK          => AXI_19_ACLK,
			AXI_04_ACLK          => AXI_20_ACLK,
			AXI_05_ACLK          => AXI_21_ACLK,
			AXI_06_ACLK          => AXI_22_ACLK,
			AXI_07_ACLK          => AXI_23_ACLK,
			AXI_08_ACLK          => AXI_24_ACLK,
			AXI_09_ACLK          => AXI_25_ACLK,
			AXI_10_ACLK          => AXI_26_ACLK,
			AXI_11_ACLK          => AXI_27_ACLK,
			AXI_12_ACLK          => AXI_28_ACLK,
			AXI_13_ACLK          => AXI_29_ACLK,
			AXI_14_ACLK          => AXI_30_ACLK,
			AXI_15_ACLK          => AXI_31_ACLK,

			AXI_00_ARESET_N      => AXI_16_ARESET_N,
			AXI_01_ARESET_N      => AXI_17_ARESET_N,
			AXI_02_ARESET_N      => AXI_18_ARESET_N,
			AXI_03_ARESET_N      => AXI_19_ARESET_N,
			AXI_04_ARESET_N      => AXI_20_ARESET_N,
			AXI_05_ARESET_N      => AXI_21_ARESET_N,
			AXI_06_ARESET_N      => AXI_22_ARESET_N,
			AXI_07_ARESET_N      => AXI_23_ARESET_N,
			AXI_08_ARESET_N      => AXI_24_ARESET_N,
			AXI_09_ARESET_N      => AXI_25_ARESET_N,
			AXI_10_ARESET_N      => AXI_26_ARESET_N,
			AXI_11_ARESET_N      => AXI_27_ARESET_N,
			AXI_12_ARESET_N      => AXI_28_ARESET_N,
			AXI_13_ARESET_N      => AXI_29_ARESET_N,
			AXI_14_ARESET_N      => AXI_30_ARESET_N,
			AXI_15_ARESET_N      => AXI_31_ARESET_N,

			-- --------------------------------------------------
			-- AXI_00
			-- --------------------------------------------------
			AXI_00_ARADDR          => AXI_16_ARADDR,
			AXI_00_ARBURST         => AXI_16_ARBURST,
			AXI_00_ARID            => AXI_16_ARID,
			AXI_00_ARLEN           => AXI_16_ARLEN,
			AXI_00_ARSIZE          => AXI_16_ARSIZE,
			AXI_00_ARVALID         => AXI_16_ARVALID,
			AXI_00_ARREADY         => AXI_16_ARREADY,

			AXI_00_AWADDR          => AXI_16_AWADDR,
			AXI_00_AWBURST         => AXI_16_AWBURST,
			AXI_00_AWID            => AXI_16_AWID,
			AXI_00_AWLEN           => AXI_16_AWLEN,
			AXI_00_AWSIZE          => AXI_16_AWSIZE,
			AXI_00_AWVALID         => AXI_16_AWVALID,
			AXI_00_AWREADY         => AXI_16_AWREADY,

			AXI_00_RREADY          => AXI_16_RREADY,
			AXI_00_BREADY          => AXI_16_BREADY,
			AXI_00_WDATA           => AXI_16_WDATA,
			AXI_00_WLAST           => AXI_16_WLAST,
			AXI_00_WSTRB           => AXI_16_WSTRB,
			AXI_00_WDATA_PARITY    => AXI_16_WDATA_PARITY,
			AXI_00_WVALID          => AXI_16_WVALID,
			AXI_00_WREADY          => AXI_16_WREADY,

			AXI_00_RDATA           => AXI_16_RDATA,
			AXI_00_RDATA_PARITY    => AXI_16_RDATA_PARITY,
			AXI_00_RID             => AXI_16_RID,
			AXI_00_RLAST           => AXI_16_RLAST,
			AXI_00_RRESP           => AXI_16_RRESP,
			AXI_00_RVALID          => AXI_16_RVALID,

			AXI_00_BID             => AXI_16_BID,
			AXI_00_BRESP           => AXI_16_BRESP,
			AXI_00_BVALID          => AXI_16_BVALID,

			-- --------------------------------------------------
			-- AXI_01
			-- --------------------------------------------------
			AXI_01_ARADDR          => AXI_17_ARADDR,
			AXI_01_ARBURST         => AXI_17_ARBURST,
			AXI_01_ARID            => AXI_17_ARID,
			AXI_01_ARLEN           => AXI_17_ARLEN,
			AXI_01_ARSIZE          => AXI_17_ARSIZE,
			AXI_01_ARVALID         => AXI_17_ARVALID,
			AXI_01_ARREADY         => AXI_17_ARREADY,

			AXI_01_AWADDR          => AXI_17_AWADDR,
			AXI_01_AWBURST         => AXI_17_AWBURST,
			AXI_01_AWID            => AXI_17_AWID,
			AXI_01_AWLEN           => AXI_17_AWLEN,
			AXI_01_AWSIZE          => AXI_17_AWSIZE,
			AXI_01_AWVALID         => AXI_17_AWVALID,
			AXI_01_AWREADY         => AXI_17_AWREADY,

			AXI_01_RREADY          => AXI_17_RREADY,
			AXI_01_BREADY          => AXI_17_BREADY,
			AXI_01_WDATA           => AXI_17_WDATA,
			AXI_01_WLAST           => AXI_17_WLAST,
			AXI_01_WSTRB           => AXI_17_WSTRB,
			AXI_01_WDATA_PARITY    => AXI_17_WDATA_PARITY,
			AXI_01_WVALID          => AXI_17_WVALID,
			AXI_01_WREADY          => AXI_17_WREADY,

			AXI_01_RDATA           => AXI_17_RDATA,
			AXI_01_RDATA_PARITY    => AXI_17_RDATA_PARITY,
			AXI_01_RID             => AXI_17_RID,
			AXI_01_RLAST           => AXI_17_RLAST,
			AXI_01_RRESP           => AXI_17_RRESP,
			AXI_01_RVALID          => AXI_17_RVALID,

			AXI_01_BID             => AXI_17_BID,
			AXI_01_BRESP           => AXI_17_BRESP,
			AXI_01_BVALID          => AXI_17_BVALID,

			-- --------------------------------------------------
			-- AXI_02
			-- --------------------------------------------------
			AXI_02_ARADDR          => AXI_18_ARADDR,
			AXI_02_ARBURST         => AXI_18_ARBURST,
			AXI_02_ARID            => AXI_18_ARID,
			AXI_02_ARLEN           => AXI_18_ARLEN,
			AXI_02_ARSIZE          => AXI_18_ARSIZE,
			AXI_02_ARVALID         => AXI_18_ARVALID,
			AXI_02_ARREADY         => AXI_18_ARREADY,

			AXI_02_AWADDR          => AXI_18_AWADDR,
			AXI_02_AWBURST         => AXI_18_AWBURST,
			AXI_02_AWID            => AXI_18_AWID,
			AXI_02_AWLEN           => AXI_18_AWLEN,
			AXI_02_AWSIZE          => AXI_18_AWSIZE,
			AXI_02_AWVALID         => AXI_18_AWVALID,
			AXI_02_AWREADY         => AXI_18_AWREADY,

			AXI_02_RREADY          => AXI_18_RREADY,
			AXI_02_BREADY          => AXI_18_BREADY,
			AXI_02_WDATA           => AXI_18_WDATA,
			AXI_02_WLAST           => AXI_18_WLAST,
			AXI_02_WSTRB           => AXI_18_WSTRB,
			AXI_02_WDATA_PARITY    => AXI_18_WDATA_PARITY,
			AXI_02_WVALID          => AXI_18_WVALID,
			AXI_02_WREADY          => AXI_18_WREADY,

			AXI_02_RDATA           => AXI_18_RDATA,
			AXI_02_RDATA_PARITY    => AXI_18_RDATA_PARITY,
			AXI_02_RID             => AXI_18_RID,
			AXI_02_RLAST           => AXI_18_RLAST,
			AXI_02_RRESP           => AXI_18_RRESP,
			AXI_02_RVALID          => AXI_18_RVALID,

			AXI_02_BID             => AXI_18_BID,
			AXI_02_BRESP           => AXI_18_BRESP,
			AXI_02_BVALID          => AXI_18_BVALID,

			-- --------------------------------------------------
			-- AXI_03
			-- --------------------------------------------------
			AXI_03_ARADDR          => AXI_19_ARADDR,
			AXI_03_ARBURST         => AXI_19_ARBURST,
			AXI_03_ARID            => AXI_19_ARID,
			AXI_03_ARLEN           => AXI_19_ARLEN,
			AXI_03_ARSIZE          => AXI_19_ARSIZE,
			AXI_03_ARVALID         => AXI_19_ARVALID,
			AXI_03_ARREADY         => AXI_19_ARREADY,

			AXI_03_AWADDR          => AXI_19_AWADDR,
			AXI_03_AWBURST         => AXI_19_AWBURST,
			AXI_03_AWID            => AXI_19_AWID,
			AXI_03_AWLEN           => AXI_19_AWLEN,
			AXI_03_AWSIZE          => AXI_19_AWSIZE,
			AXI_03_AWVALID         => AXI_19_AWVALID,
			AXI_03_AWREADY         => AXI_19_AWREADY,

			AXI_03_RREADY          => AXI_19_RREADY,
			AXI_03_BREADY          => AXI_19_BREADY,
			AXI_03_WDATA           => AXI_19_WDATA,
			AXI_03_WLAST           => AXI_19_WLAST,
			AXI_03_WSTRB           => AXI_19_WSTRB,
			AXI_03_WDATA_PARITY    => AXI_19_WDATA_PARITY,
			AXI_03_WVALID          => AXI_19_WVALID,
			AXI_03_WREADY          => AXI_19_WREADY,

			AXI_03_RDATA           => AXI_19_RDATA,
			AXI_03_RDATA_PARITY    => AXI_19_RDATA_PARITY,
			AXI_03_RID             => AXI_19_RID,
			AXI_03_RLAST           => AXI_19_RLAST,
			AXI_03_RRESP           => AXI_19_RRESP,
			AXI_03_RVALID          => AXI_19_RVALID,

			AXI_03_BID             => AXI_19_BID,
			AXI_03_BRESP           => AXI_19_BRESP,
			AXI_03_BVALID          => AXI_19_BVALID,

			-- --------------------------------------------------
			-- AXI_04
			-- --------------------------------------------------
			AXI_04_ARADDR          => AXI_20_ARADDR,
			AXI_04_ARBURST         => AXI_20_ARBURST,
			AXI_04_ARID            => AXI_20_ARID,
			AXI_04_ARLEN           => AXI_20_ARLEN,
			AXI_04_ARSIZE          => AXI_20_ARSIZE,
			AXI_04_ARVALID         => AXI_20_ARVALID,
			AXI_04_ARREADY         => AXI_20_ARREADY,

			AXI_04_AWADDR          => AXI_20_AWADDR,
			AXI_04_AWBURST         => AXI_20_AWBURST,
			AXI_04_AWID            => AXI_20_AWID,
			AXI_04_AWLEN           => AXI_20_AWLEN,
			AXI_04_AWSIZE          => AXI_20_AWSIZE,
			AXI_04_AWVALID         => AXI_20_AWVALID,
			AXI_04_AWREADY         => AXI_20_AWREADY,

			AXI_04_RREADY          => AXI_20_RREADY,
			AXI_04_BREADY          => AXI_20_BREADY,
			AXI_04_WDATA           => AXI_20_WDATA,
			AXI_04_WLAST           => AXI_20_WLAST,
			AXI_04_WSTRB           => AXI_20_WSTRB,
			AXI_04_WDATA_PARITY    => AXI_20_WDATA_PARITY,
			AXI_04_WVALID          => AXI_20_WVALID,
			AXI_04_WREADY          => AXI_20_WREADY,

			AXI_04_RDATA           => AXI_20_RDATA,
			AXI_04_RDATA_PARITY    => AXI_20_RDATA_PARITY,
			AXI_04_RID             => AXI_20_RID,
			AXI_04_RLAST           => AXI_20_RLAST,
			AXI_04_RRESP           => AXI_20_RRESP,
			AXI_04_RVALID          => AXI_20_RVALID,

			AXI_04_BID             => AXI_20_BID,
			AXI_04_BRESP           => AXI_20_BRESP,
			AXI_04_BVALID          => AXI_20_BVALID,

			-- --------------------------------------------------
			-- AXI_05
			-- --------------------------------------------------
			AXI_05_ARADDR          => AXI_21_ARADDR,
			AXI_05_ARBURST         => AXI_21_ARBURST,
			AXI_05_ARID            => AXI_21_ARID,
			AXI_05_ARLEN           => AXI_21_ARLEN,
			AXI_05_ARSIZE          => AXI_21_ARSIZE,
			AXI_05_ARVALID         => AXI_21_ARVALID,
			AXI_05_ARREADY         => AXI_21_ARREADY,

			AXI_05_AWADDR          => AXI_21_AWADDR,
			AXI_05_AWBURST         => AXI_21_AWBURST,
			AXI_05_AWID            => AXI_21_AWID,
			AXI_05_AWLEN           => AXI_21_AWLEN,
			AXI_05_AWSIZE          => AXI_21_AWSIZE,
			AXI_05_AWVALID         => AXI_21_AWVALID,
			AXI_05_AWREADY         => AXI_21_AWREADY,

			AXI_05_RREADY          => AXI_21_RREADY,
			AXI_05_BREADY          => AXI_21_BREADY,
			AXI_05_WDATA           => AXI_21_WDATA,
			AXI_05_WLAST           => AXI_21_WLAST,
			AXI_05_WSTRB           => AXI_21_WSTRB,
			AXI_05_WDATA_PARITY    => AXI_21_WDATA_PARITY,
			AXI_05_WVALID          => AXI_21_WVALID,
			AXI_05_WREADY          => AXI_21_WREADY,

			AXI_05_RDATA           => AXI_21_RDATA,
			AXI_05_RDATA_PARITY    => AXI_21_RDATA_PARITY,
			AXI_05_RID             => AXI_21_RID,
			AXI_05_RLAST           => AXI_21_RLAST,
			AXI_05_RRESP           => AXI_21_RRESP,
			AXI_05_RVALID          => AXI_21_RVALID,

			AXI_05_BID             => AXI_21_BID,
			AXI_05_BRESP           => AXI_21_BRESP,
			AXI_05_BVALID          => AXI_21_BVALID,

			-- --------------------------------------------------
			-- AXI_06
			-- --------------------------------------------------
			AXI_06_ARADDR          => AXI_22_ARADDR,
			AXI_06_ARBURST         => AXI_22_ARBURST,
			AXI_06_ARID            => AXI_22_ARID,
			AXI_06_ARLEN           => AXI_22_ARLEN,
			AXI_06_ARSIZE          => AXI_22_ARSIZE,
			AXI_06_ARVALID         => AXI_22_ARVALID,
			AXI_06_ARREADY         => AXI_22_ARREADY,

			AXI_06_AWADDR          => AXI_22_AWADDR,
			AXI_06_AWBURST         => AXI_22_AWBURST,
			AXI_06_AWID            => AXI_22_AWID,
			AXI_06_AWLEN           => AXI_22_AWLEN,
			AXI_06_AWSIZE          => AXI_22_AWSIZE,
			AXI_06_AWVALID         => AXI_22_AWVALID,
			AXI_06_AWREADY         => AXI_22_AWREADY,

			AXI_06_RREADY          => AXI_22_RREADY,
			AXI_06_BREADY          => AXI_22_BREADY,
			AXI_06_WDATA           => AXI_22_WDATA,
			AXI_06_WLAST           => AXI_22_WLAST,
			AXI_06_WSTRB           => AXI_22_WSTRB,
			AXI_06_WDATA_PARITY    => AXI_22_WDATA_PARITY,
			AXI_06_WVALID          => AXI_22_WVALID,
			AXI_06_WREADY          => AXI_22_WREADY,

			AXI_06_RDATA           => AXI_22_RDATA,
			AXI_06_RDATA_PARITY    => AXI_22_RDATA_PARITY,
			AXI_06_RID             => AXI_22_RID,
			AXI_06_RLAST           => AXI_22_RLAST,
			AXI_06_RRESP           => AXI_22_RRESP,
			AXI_06_RVALID          => AXI_22_RVALID,

			AXI_06_BID             => AXI_22_BID,
			AXI_06_BRESP           => AXI_22_BRESP,
			AXI_06_BVALID          => AXI_22_BVALID,

			-- --------------------------------------------------
			-- AXI_07
			-- --------------------------------------------------
			AXI_07_ARADDR          => AXI_23_ARADDR,
			AXI_07_ARBURST         => AXI_23_ARBURST,
			AXI_07_ARID            => AXI_23_ARID,
			AXI_07_ARLEN           => AXI_23_ARLEN,
			AXI_07_ARSIZE          => AXI_23_ARSIZE,
			AXI_07_ARVALID         => AXI_23_ARVALID,
			AXI_07_ARREADY         => AXI_23_ARREADY,

			AXI_07_AWADDR          => AXI_23_AWADDR,
			AXI_07_AWBURST         => AXI_23_AWBURST,
			AXI_07_AWID            => AXI_23_AWID,
			AXI_07_AWLEN           => AXI_23_AWLEN,
			AXI_07_AWSIZE          => AXI_23_AWSIZE,
			AXI_07_AWVALID         => AXI_23_AWVALID,
			AXI_07_AWREADY         => AXI_23_AWREADY,

			AXI_07_RREADY          => AXI_23_RREADY,
			AXI_07_BREADY          => AXI_23_BREADY,
			AXI_07_WDATA           => AXI_23_WDATA,
			AXI_07_WLAST           => AXI_23_WLAST,
			AXI_07_WSTRB           => AXI_23_WSTRB,
			AXI_07_WDATA_PARITY    => AXI_23_WDATA_PARITY,
			AXI_07_WVALID          => AXI_23_WVALID,
			AXI_07_WREADY          => AXI_23_WREADY,

			AXI_07_RDATA           => AXI_23_RDATA,
			AXI_07_RDATA_PARITY    => AXI_23_RDATA_PARITY,
			AXI_07_RID             => AXI_23_RID,
			AXI_07_RLAST           => AXI_23_RLAST,
			AXI_07_RRESP           => AXI_23_RRESP,
			AXI_07_RVALID          => AXI_23_RVALID,

			AXI_07_BID             => AXI_23_BID,
			AXI_07_BRESP           => AXI_23_BRESP,
			AXI_07_BVALID          => AXI_23_BVALID,

			-- --------------------------------------------------
			-- AXI_08
			-- --------------------------------------------------
			AXI_08_ARADDR          => AXI_24_ARADDR,
			AXI_08_ARBURST         => AXI_24_ARBURST,
			AXI_08_ARID            => AXI_24_ARID,
			AXI_08_ARLEN           => AXI_24_ARLEN,
			AXI_08_ARSIZE          => AXI_24_ARSIZE,
			AXI_08_ARVALID         => AXI_24_ARVALID,
			AXI_08_ARREADY         => AXI_24_ARREADY,

			AXI_08_AWADDR          => AXI_24_AWADDR,
			AXI_08_AWBURST         => AXI_24_AWBURST,
			AXI_08_AWID            => AXI_24_AWID,
			AXI_08_AWLEN           => AXI_24_AWLEN,
			AXI_08_AWSIZE          => AXI_24_AWSIZE,
			AXI_08_AWVALID         => AXI_24_AWVALID,
			AXI_08_AWREADY         => AXI_24_AWREADY,

			AXI_08_RREADY          => AXI_24_RREADY,
			AXI_08_BREADY          => AXI_24_BREADY,
			AXI_08_WDATA           => AXI_24_WDATA,
			AXI_08_WLAST           => AXI_24_WLAST,
			AXI_08_WSTRB           => AXI_24_WSTRB,
			AXI_08_WDATA_PARITY    => AXI_24_WDATA_PARITY,
			AXI_08_WVALID          => AXI_24_WVALID,
			AXI_08_WREADY          => AXI_24_WREADY,

			AXI_08_RDATA           => AXI_24_RDATA,
			AXI_08_RDATA_PARITY    => AXI_24_RDATA_PARITY,
			AXI_08_RID             => AXI_24_RID,
			AXI_08_RLAST           => AXI_24_RLAST,
			AXI_08_RRESP           => AXI_24_RRESP,
			AXI_08_RVALID          => AXI_24_RVALID,

			AXI_08_BID             => AXI_24_BID,
			AXI_08_BRESP           => AXI_24_BRESP,
			AXI_08_BVALID          => AXI_24_BVALID,

			-- --------------------------------------------------
			-- AXI_09
			-- --------------------------------------------------
			AXI_09_ARADDR          => AXI_25_ARADDR,
			AXI_09_ARBURST         => AXI_25_ARBURST,
			AXI_09_ARID            => AXI_25_ARID,
			AXI_09_ARLEN           => AXI_25_ARLEN,
			AXI_09_ARSIZE          => AXI_25_ARSIZE,
			AXI_09_ARVALID         => AXI_25_ARVALID,
			AXI_09_ARREADY         => AXI_25_ARREADY,

			AXI_09_AWADDR          => AXI_25_AWADDR,
			AXI_09_AWBURST         => AXI_25_AWBURST,
			AXI_09_AWID            => AXI_25_AWID,
			AXI_09_AWLEN           => AXI_25_AWLEN,
			AXI_09_AWSIZE          => AXI_25_AWSIZE,
			AXI_09_AWVALID         => AXI_25_AWVALID,
			AXI_09_AWREADY         => AXI_25_AWREADY,

			AXI_09_RREADY          => AXI_25_RREADY,
			AXI_09_BREADY          => AXI_25_BREADY,
			AXI_09_WDATA           => AXI_25_WDATA,
			AXI_09_WLAST           => AXI_25_WLAST,
			AXI_09_WSTRB           => AXI_25_WSTRB,
			AXI_09_WDATA_PARITY    => AXI_25_WDATA_PARITY,
			AXI_09_WVALID          => AXI_25_WVALID,
			AXI_09_WREADY          => AXI_25_WREADY,

			AXI_09_RDATA           => AXI_25_RDATA,
			AXI_09_RDATA_PARITY    => AXI_25_RDATA_PARITY,
			AXI_09_RID             => AXI_25_RID,
			AXI_09_RLAST           => AXI_25_RLAST,
			AXI_09_RRESP           => AXI_25_RRESP,
			AXI_09_RVALID          => AXI_25_RVALID,

			AXI_09_BID             => AXI_25_BID,
			AXI_09_BRESP           => AXI_25_BRESP,
			AXI_09_BVALID          => AXI_25_BVALID,

			-- --------------------------------------------------
			-- AXI_10
			-- --------------------------------------------------
			AXI_10_ARADDR          => AXI_26_ARADDR,
			AXI_10_ARBURST         => AXI_26_ARBURST,
			AXI_10_ARID            => AXI_26_ARID,
			AXI_10_ARLEN           => AXI_26_ARLEN,
			AXI_10_ARSIZE          => AXI_26_ARSIZE,
			AXI_10_ARVALID         => AXI_26_ARVALID,
			AXI_10_ARREADY         => AXI_26_ARREADY,

			AXI_10_AWADDR          => AXI_26_AWADDR,
			AXI_10_AWBURST         => AXI_26_AWBURST,
			AXI_10_AWID            => AXI_26_AWID,
			AXI_10_AWLEN           => AXI_26_AWLEN,
			AXI_10_AWSIZE          => AXI_26_AWSIZE,
			AXI_10_AWVALID         => AXI_26_AWVALID,
			AXI_10_AWREADY         => AXI_26_AWREADY,

			AXI_10_RREADY          => AXI_26_RREADY,
			AXI_10_BREADY          => AXI_26_BREADY,
			AXI_10_WDATA           => AXI_26_WDATA,
			AXI_10_WLAST           => AXI_26_WLAST,
			AXI_10_WSTRB           => AXI_26_WSTRB,
			AXI_10_WDATA_PARITY    => AXI_26_WDATA_PARITY,
			AXI_10_WVALID          => AXI_26_WVALID,
			AXI_10_WREADY          => AXI_26_WREADY,

			AXI_10_RDATA           => AXI_26_RDATA,
			AXI_10_RDATA_PARITY    => AXI_26_RDATA_PARITY,
			AXI_10_RID             => AXI_26_RID,
			AXI_10_RLAST           => AXI_26_RLAST,
			AXI_10_RRESP           => AXI_26_RRESP,
			AXI_10_RVALID          => AXI_26_RVALID,

			AXI_10_BID             => AXI_26_BID,
			AXI_10_BRESP           => AXI_26_BRESP,
			AXI_10_BVALID          => AXI_26_BVALID,

			-- --------------------------------------------------
			-- AXI_11
			-- --------------------------------------------------
			AXI_11_ARADDR          => AXI_27_ARADDR,
			AXI_11_ARBURST         => AXI_27_ARBURST,
			AXI_11_ARID            => AXI_27_ARID,
			AXI_11_ARLEN           => AXI_27_ARLEN,
			AXI_11_ARSIZE          => AXI_27_ARSIZE,
			AXI_11_ARVALID         => AXI_27_ARVALID,
			AXI_11_ARREADY         => AXI_27_ARREADY,

			AXI_11_AWADDR          => AXI_27_AWADDR,
			AXI_11_AWBURST         => AXI_27_AWBURST,
			AXI_11_AWID            => AXI_27_AWID,
			AXI_11_AWLEN           => AXI_27_AWLEN,
			AXI_11_AWSIZE          => AXI_27_AWSIZE,
			AXI_11_AWVALID         => AXI_27_AWVALID,
			AXI_11_AWREADY         => AXI_27_AWREADY,

			AXI_11_RREADY          => AXI_27_RREADY,
			AXI_11_BREADY          => AXI_27_BREADY,
			AXI_11_WDATA           => AXI_27_WDATA,
			AXI_11_WLAST           => AXI_27_WLAST,
			AXI_11_WSTRB           => AXI_27_WSTRB,
			AXI_11_WDATA_PARITY    => AXI_27_WDATA_PARITY,
			AXI_11_WVALID          => AXI_27_WVALID,
			AXI_11_WREADY          => AXI_27_WREADY,

			AXI_11_RDATA           => AXI_27_RDATA,
			AXI_11_RDATA_PARITY    => AXI_27_RDATA_PARITY,
			AXI_11_RID             => AXI_27_RID,
			AXI_11_RLAST           => AXI_27_RLAST,
			AXI_11_RRESP           => AXI_27_RRESP,
			AXI_11_RVALID          => AXI_27_RVALID,

			AXI_11_BID             => AXI_27_BID,
			AXI_11_BRESP           => AXI_27_BRESP,
			AXI_11_BVALID          => AXI_27_BVALID,

			-- --------------------------------------------------
			-- AXI_12
			-- --------------------------------------------------
			AXI_12_ARADDR          => AXI_28_ARADDR,
			AXI_12_ARBURST         => AXI_28_ARBURST,
			AXI_12_ARID            => AXI_28_ARID,
			AXI_12_ARLEN           => AXI_28_ARLEN,
			AXI_12_ARSIZE          => AXI_28_ARSIZE,
			AXI_12_ARVALID         => AXI_28_ARVALID,
			AXI_12_ARREADY         => AXI_28_ARREADY,

			AXI_12_AWADDR          => AXI_28_AWADDR,
			AXI_12_AWBURST         => AXI_28_AWBURST,
			AXI_12_AWID            => AXI_28_AWID,
			AXI_12_AWLEN           => AXI_28_AWLEN,
			AXI_12_AWSIZE          => AXI_28_AWSIZE,
			AXI_12_AWVALID         => AXI_28_AWVALID,
			AXI_12_AWREADY         => AXI_28_AWREADY,

			AXI_12_RREADY          => AXI_28_RREADY,
			AXI_12_BREADY          => AXI_28_BREADY,
			AXI_12_WDATA           => AXI_28_WDATA,
			AXI_12_WLAST           => AXI_28_WLAST,
			AXI_12_WSTRB           => AXI_28_WSTRB,
			AXI_12_WDATA_PARITY    => AXI_28_WDATA_PARITY,
			AXI_12_WVALID          => AXI_28_WVALID,
			AXI_12_WREADY          => AXI_28_WREADY,

			AXI_12_RDATA           => AXI_28_RDATA,
			AXI_12_RDATA_PARITY    => AXI_28_RDATA_PARITY,
			AXI_12_RID             => AXI_28_RID,
			AXI_12_RLAST           => AXI_28_RLAST,
			AXI_12_RRESP           => AXI_28_RRESP,
			AXI_12_RVALID          => AXI_28_RVALID,

			AXI_12_BID             => AXI_28_BID,
			AXI_12_BRESP           => AXI_28_BRESP,
			AXI_12_BVALID          => AXI_28_BVALID,

			-- --------------------------------------------------
			-- AXI_13
			-- --------------------------------------------------
			AXI_13_ARADDR          => AXI_29_ARADDR,
			AXI_13_ARBURST         => AXI_29_ARBURST,
			AXI_13_ARID            => AXI_29_ARID,
			AXI_13_ARLEN           => AXI_29_ARLEN,
			AXI_13_ARSIZE          => AXI_29_ARSIZE,
			AXI_13_ARVALID         => AXI_29_ARVALID,
			AXI_13_ARREADY         => AXI_29_ARREADY,

			AXI_13_AWADDR          => AXI_29_AWADDR,
			AXI_13_AWBURST         => AXI_29_AWBURST,
			AXI_13_AWID            => AXI_29_AWID,
			AXI_13_AWLEN           => AXI_29_AWLEN,
			AXI_13_AWSIZE          => AXI_29_AWSIZE,
			AXI_13_AWVALID         => AXI_29_AWVALID,
			AXI_13_AWREADY         => AXI_29_AWREADY,

			AXI_13_RREADY          => AXI_29_RREADY,
			AXI_13_BREADY          => AXI_29_BREADY,
			AXI_13_WDATA           => AXI_29_WDATA,
			AXI_13_WLAST           => AXI_29_WLAST,
			AXI_13_WSTRB           => AXI_29_WSTRB,
			AXI_13_WDATA_PARITY    => AXI_29_WDATA_PARITY,
			AXI_13_WVALID          => AXI_29_WVALID,
			AXI_13_WREADY          => AXI_29_WREADY,

			AXI_13_RDATA           => AXI_29_RDATA,
			AXI_13_RDATA_PARITY    => AXI_29_RDATA_PARITY,
			AXI_13_RID             => AXI_29_RID,
			AXI_13_RLAST           => AXI_29_RLAST,
			AXI_13_RRESP           => AXI_29_RRESP,
			AXI_13_RVALID          => AXI_29_RVALID,

			AXI_13_BID             => AXI_29_BID,
			AXI_13_BRESP           => AXI_29_BRESP,
			AXI_13_BVALID          => AXI_29_BVALID,

			-- --------------------------------------------------
			-- AXI_14
			-- --------------------------------------------------
			AXI_14_ARADDR          => AXI_30_ARADDR,
			AXI_14_ARBURST         => AXI_30_ARBURST,
			AXI_14_ARID            => AXI_30_ARID,
			AXI_14_ARLEN           => AXI_30_ARLEN,
			AXI_14_ARSIZE          => AXI_30_ARSIZE,
			AXI_14_ARVALID         => AXI_30_ARVALID,
			AXI_14_ARREADY         => AXI_30_ARREADY,

			AXI_14_AWADDR          => AXI_30_AWADDR,
			AXI_14_AWBURST         => AXI_30_AWBURST,
			AXI_14_AWID            => AXI_30_AWID,
			AXI_14_AWLEN           => AXI_30_AWLEN,
			AXI_14_AWSIZE          => AXI_30_AWSIZE,
			AXI_14_AWVALID         => AXI_30_AWVALID,
			AXI_14_AWREADY         => AXI_30_AWREADY,

			AXI_14_RREADY          => AXI_30_RREADY,
			AXI_14_BREADY          => AXI_30_BREADY,
			AXI_14_WDATA           => AXI_30_WDATA,
			AXI_14_WLAST           => AXI_30_WLAST,
			AXI_14_WSTRB           => AXI_30_WSTRB,
			AXI_14_WDATA_PARITY    => AXI_30_WDATA_PARITY,
			AXI_14_WVALID          => AXI_30_WVALID,
			AXI_14_WREADY          => AXI_30_WREADY,

			AXI_14_RDATA           => AXI_30_RDATA,
			AXI_14_RDATA_PARITY    => AXI_30_RDATA_PARITY,
			AXI_14_RID             => AXI_30_RID,
			AXI_14_RLAST           => AXI_30_RLAST,
			AXI_14_RRESP           => AXI_30_RRESP,
			AXI_14_RVALID          => AXI_30_RVALID,

			AXI_14_BID             => AXI_30_BID,
			AXI_14_BRESP           => AXI_30_BRESP,
			AXI_14_BVALID          => AXI_30_BVALID,

			-- --------------------------------------------------
			-- AXI_15
			-- --------------------------------------------------
			AXI_15_ARADDR          => AXI_31_ARADDR,
			AXI_15_ARBURST         => AXI_31_ARBURST,
			AXI_15_ARID            => AXI_31_ARID,
			AXI_15_ARLEN           => AXI_31_ARLEN,
			AXI_15_ARSIZE          => AXI_31_ARSIZE,
			AXI_15_ARVALID         => AXI_31_ARVALID,
			AXI_15_ARREADY         => AXI_31_ARREADY,

			AXI_15_AWADDR          => AXI_31_AWADDR,
			AXI_15_AWBURST         => AXI_31_AWBURST,
			AXI_15_AWID            => AXI_31_AWID,
			AXI_15_AWLEN           => AXI_31_AWLEN,
			AXI_15_AWSIZE          => AXI_31_AWSIZE,
			AXI_15_AWVALID         => AXI_31_AWVALID,
			AXI_15_AWREADY         => AXI_31_AWREADY,

			AXI_15_RREADY          => AXI_31_RREADY,
			AXI_15_BREADY          => AXI_31_BREADY,
			AXI_15_WDATA           => AXI_31_WDATA,
			AXI_15_WLAST           => AXI_31_WLAST,
			AXI_15_WSTRB           => AXI_31_WSTRB,
			AXI_15_WDATA_PARITY    => AXI_31_WDATA_PARITY,
			AXI_15_WVALID          => AXI_31_WVALID,
			AXI_15_WREADY          => AXI_31_WREADY,

			AXI_15_RDATA           => AXI_31_RDATA,
			AXI_15_RDATA_PARITY    => AXI_31_RDATA_PARITY,
			AXI_15_RID             => AXI_31_RID,
			AXI_15_RLAST           => AXI_31_RLAST,
			AXI_15_RRESP           => AXI_31_RRESP,
			AXI_15_RVALID          => AXI_31_RVALID,

			AXI_15_BID             => AXI_31_BID,
			AXI_15_BRESP           => AXI_31_BRESP,
			AXI_15_BVALID          => AXI_31_BVALID,

			-- --------------------------------------------------
			-- APB / status
			-- --------------------------------------------------
			APB_0_PCLK           => APB_0_PCLK,
			APB_0_PRESET_N       => APB_0_PRESET_N,

			apb_complete_0       => apb_complete_0,
			DRAM_0_STAT_CATTRIP  => DRAM_0_STAT_CATTRIP,
			DRAM_0_STAT_TEMP     => DRAM_0_STAT_TEMP
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
