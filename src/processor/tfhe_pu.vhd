library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

library work;
  use work.ip_cores_constants.all;
  use work.processor_utils.all;
  use work.datatypes_utils.all;
  use work.math_utils.all;
  use work.tfhe_constants.all;

entity tfhe_pu is
  port (

    HBM_RW_SELECT       : in  std_logic_vector(3 downto 0);                           -- deprecated

    --- Global signals
    -- i_clk                : in  std_ulogic;
    -- i_clk_ref            : in  std_ulogic; -- must be a raw clock pin, hbm-ip-core uses it internally to do the 900MHz clock
    -- i_clk_apb            : in  std_ulogic;
    -- RESET_N            : in  std_ulogic;
    -- RESET_N_apb        : in  std_ulogic;
    TFHE_CLK            : in  std_logic;
    TFHE_RESET_N        : in  std_ulogic;
    AXI_ARESET_N        : in  std_ulogic;

    PBS_BUSY            : out std_logic;
    PBS_DONE            : out std_logic;
    START_PBS           : in  std_logic;

    ------------------------------------------------------------------
    -- External AXI master (to the crossbar)
    ------------------------------------------------------------------
    HBM_REF_CLK_0       : in  std_logic;                                              -- 100 MHz, drives a PLL. Must be sourced from a MMCM/BUFG
    HBM_REF_CLK_1       : in  std_logic;                                              -- 100 MHz, drives a PLL. Must be sourced from a MMCM/BUFG

    -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    AXI_00_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    AXI_00_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst: use '01' # 00fixed(not supported), 01incr, 11wrap(like incr but wraps at the end, slower)
    AXI_00_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr. id tag (we have no need for this if the outputs are in the correct order, otherwise need ping-pong-buffer)
    AXI_00_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- read burst length --> constant '1111'
    AXI_00_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- read burst size, only 256-bit size supported (b'101')
    AXI_00_ARVALID      : in  std_logic;                                              -- read addr valid --> constant 1
    AXI_00_ARREADY      : out std_logic;                                              -- "read address ready" --> can accept a new read address
    -- same as for read
    AXI_00_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_00_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_00_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_00_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_00_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_00_AWVALID      : in  std_logic;
    AXI_00_AWREADY      : out std_logic;                                              -- "write address ready" --> can accept a new write address
    --
    AXI_00_RREADY       : in  std_logic;                                              --"read ready" signals that we read the input so the next one can come? Must be high to transmit the input data, set to 1
    AXI_00_BREADY       : in  std_logic;                                              --"response ready" --> read response, can accept new response
    AXI_00_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);          -- data to write
    AXI_00_WLAST        : in  std_logic;                                              -- shows that this was the last value that was written
    AXI_00_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);   -- write strobe --> one bit per write byte on the bus to tell that it should be written --> set all to 1.
    AXI_00_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);   -- why would I need that? Is data loss expeced?
    AXI_00_WVALID       : in  std_logic;
    AXI_00_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);   -- no need?
    AXI_00_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);          -- read data
    AXI_00_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_00_RLAST        : out std_logic;                                              -- shows that this was the last value that was read
    AXI_00_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);      -- read response --> which are possible?
    AXI_00_RVALID       : out std_logic;                                              -- signals output is there
    AXI_00_WREADY       : out std_logic;                                              -- signals that the values are now stored
    --
    AXI_00_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);        --"response ID tag" for AXI_00_BRESP
    AXI_00_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);      --Write response: 00 - OK, 01 - exclusive access OK, 10 - slave error, 11 decode error
    AXI_00_BVALID       : out std_logic;                                              --"Write response ready"

    AXI_01_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_01_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_01_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_01_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_01_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_01_ARVALID      : in  std_logic;
    AXI_01_ARREADY      : out std_logic;
    AXI_01_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_01_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_01_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_01_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_01_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_01_AWVALID      : in  std_logic;
    AXI_01_AWREADY      : out std_logic;
    AXI_01_RREADY       : in  std_logic;
    AXI_01_BREADY       : in  std_logic;
    AXI_01_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_01_WLAST        : in  std_logic;
    AXI_01_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_01_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_01_WVALID       : in  std_logic;
    AXI_01_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_01_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_01_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_01_RLAST        : out std_logic;
    AXI_01_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_01_RVALID       : out std_logic;
    AXI_01_WREADY       : out std_logic;
    AXI_01_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_01_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_01_BVALID       : out std_logic;
    AXI_02_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_02_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_02_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_02_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_02_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_02_ARVALID      : in  std_logic;
    AXI_02_ARREADY      : out std_logic;
    AXI_02_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_02_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_02_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_02_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_02_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_02_AWVALID      : in  std_logic;
    AXI_02_AWREADY      : out std_logic;
    AXI_02_RREADY       : in  std_logic;
    AXI_02_BREADY       : in  std_logic;
    AXI_02_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_02_WLAST        : in  std_logic;
    AXI_02_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_02_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_02_WVALID       : in  std_logic;
    AXI_02_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_02_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_02_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_02_RLAST        : out std_logic;
    AXI_02_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_02_RVALID       : out std_logic;
    AXI_02_WREADY       : out std_logic;
    AXI_02_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_02_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_02_BVALID       : out std_logic;

    AXI_03_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_03_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_03_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_03_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_03_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_03_ARVALID      : in  std_logic;
    AXI_03_ARREADY      : out std_logic;
    AXI_03_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_03_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_03_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_03_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_03_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_03_AWVALID      : in  std_logic;
    AXI_03_AWREADY      : out std_logic;
    AXI_03_RREADY       : in  std_logic;
    AXI_03_BREADY       : in  std_logic;
    AXI_03_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_03_WLAST        : in  std_logic;
    AXI_03_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_03_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_03_WVALID       : in  std_logic;
    AXI_03_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_03_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_03_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_03_RLAST        : out std_logic;
    AXI_03_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_03_RVALID       : out std_logic;
    AXI_03_WREADY       : out std_logic;
    AXI_03_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_03_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_03_BVALID       : out std_logic;
    AXI_04_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_04_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_04_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_04_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_04_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_04_ARVALID      : in  std_logic;
    AXI_04_ARREADY      : out std_logic;
    AXI_04_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_04_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_04_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_04_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_04_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_04_AWVALID      : in  std_logic;
    AXI_04_AWREADY      : out std_logic;
    AXI_04_RREADY       : in  std_logic;
    AXI_04_BREADY       : in  std_logic;
    AXI_04_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_04_WLAST        : in  std_logic;
    AXI_04_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_04_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_04_WVALID       : in  std_logic;
    AXI_04_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_04_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_04_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_04_RLAST        : out std_logic;
    AXI_04_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_04_RVALID       : out std_logic;
    AXI_04_WREADY       : out std_logic;
    AXI_04_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_04_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_04_BVALID       : out std_logic;

    AXI_05_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_05_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_05_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_05_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_05_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_05_ARVALID      : in  std_logic;
    AXI_05_ARREADY      : out std_logic;
    AXI_05_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_05_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_05_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_05_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_05_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_05_AWVALID      : in  std_logic;
    AXI_05_AWREADY      : out std_logic;
    AXI_05_RREADY       : in  std_logic;
    AXI_05_BREADY       : in  std_logic;
    AXI_05_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_05_WLAST        : in  std_logic;
    AXI_05_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_05_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_05_WVALID       : in  std_logic;
    AXI_05_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_05_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_05_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_05_RLAST        : out std_logic;
    AXI_05_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_05_RVALID       : out std_logic;
    AXI_05_WREADY       : out std_logic;
    AXI_05_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_05_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_05_BVALID       : out std_logic;

    AXI_06_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_06_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_06_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_06_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_06_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_06_ARVALID      : in  std_logic;
    AXI_06_ARREADY      : out std_logic;
    AXI_06_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_06_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_06_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_06_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_06_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_06_AWVALID      : in  std_logic;
    AXI_06_AWREADY      : out std_logic;
    AXI_06_RREADY       : in  std_logic;
    AXI_06_BREADY       : in  std_logic;
    AXI_06_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_06_WLAST        : in  std_logic;
    AXI_06_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_06_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_06_WVALID       : in  std_logic;
    AXI_06_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_06_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_06_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_06_RLAST        : out std_logic;
    AXI_06_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_06_RVALID       : out std_logic;
    AXI_06_WREADY       : out std_logic;
    AXI_06_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_06_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_06_BVALID       : out std_logic;

    AXI_07_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_07_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_07_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_07_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_07_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_07_ARVALID      : in  std_logic;
    AXI_07_ARREADY      : out std_logic;
    AXI_07_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_07_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_07_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_07_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_07_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_07_AWVALID      : in  std_logic;
    AXI_07_AWREADY      : out std_logic;
    AXI_07_RREADY       : in  std_logic;
    AXI_07_BREADY       : in  std_logic;
    AXI_07_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_07_WLAST        : in  std_logic;
    AXI_07_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_07_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_07_WVALID       : in  std_logic;
    AXI_07_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_07_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_07_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_07_RLAST        : out std_logic;
    AXI_07_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_07_RVALID       : out std_logic;
    AXI_07_WREADY       : out std_logic;
    AXI_07_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_07_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_07_BVALID       : out std_logic;

    -- AXI_08_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_08_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_08_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_08_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_08_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_08_ARVALID      : in  std_logic;
    -- AXI_08_ARREADY      : out std_logic;
    -- AXI_08_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_08_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_08_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_08_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_08_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_08_AWVALID      : in  std_logic;
    -- AXI_08_AWREADY      : out std_logic;
    -- AXI_08_RREADY       : in  std_logic;
    -- AXI_08_BREADY       : in  std_logic;
    -- AXI_08_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_08_WLAST        : in  std_logic;
    -- AXI_08_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_08_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_08_WVALID       : in  std_logic;
    -- AXI_08_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_08_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_08_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_08_RLAST        : out std_logic;
    -- AXI_08_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_08_RVALID       : out std_logic;
    -- AXI_08_WREADY       : out std_logic;
    -- AXI_08_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_08_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_08_BVALID       : out std_logic;

    -- AXI_09_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_09_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_09_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_09_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_09_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_09_ARVALID      : in  std_logic;
    -- AXI_09_ARREADY      : out std_logic;
    -- AXI_09_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_09_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_09_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_09_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_09_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_09_AWVALID      : in  std_logic;
    -- AXI_09_AWREADY      : out std_logic;
    -- AXI_09_RREADY       : in  std_logic;
    -- AXI_09_BREADY       : in  std_logic;
    -- AXI_09_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_09_WLAST        : in  std_logic;
    -- AXI_09_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_09_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_09_WVALID       : in  std_logic;
    -- AXI_09_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_09_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_09_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_09_RLAST        : out std_logic;
    -- AXI_09_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_09_RVALID       : out std_logic;
    -- AXI_09_WREADY       : out std_logic;
    -- AXI_09_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_09_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_09_BVALID       : out std_logic;
    -- AXI_10_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_10_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_10_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_10_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_10_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_10_ARVALID      : in  std_logic;
    -- AXI_10_ARREADY      : out std_logic;
    -- AXI_10_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_10_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_10_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_10_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_10_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_10_AWVALID      : in  std_logic;
    -- AXI_10_AWREADY      : out std_logic;
    -- AXI_10_RREADY       : in  std_logic;
    -- AXI_10_BREADY       : in  std_logic;
    -- AXI_10_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_10_WLAST        : in  std_logic;
    -- AXI_10_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_10_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_10_WVALID       : in  std_logic;
    -- AXI_10_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_10_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_10_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_10_RLAST        : out std_logic;
    -- AXI_10_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_10_RVALID       : out std_logic;
    -- AXI_10_WREADY       : out std_logic;
    -- AXI_10_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_10_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_10_BVALID       : out std_logic;

    -- AXI_11_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_11_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_11_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_11_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_11_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_11_ARVALID      : in  std_logic;
    -- AXI_11_ARREADY      : out std_logic;
    -- AXI_11_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_11_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_11_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_11_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_11_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_11_AWVALID      : in  std_logic;
    -- AXI_11_AWREADY      : out std_logic;
    -- AXI_11_RREADY       : in  std_logic;
    -- AXI_11_BREADY       : in  std_logic;
    -- AXI_11_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_11_WLAST        : in  std_logic;
    -- AXI_11_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_11_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_11_WVALID       : in  std_logic;
    -- AXI_11_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_11_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_11_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_11_RLAST        : out std_logic;
    -- AXI_11_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_11_RVALID       : out std_logic;
    -- AXI_11_WREADY       : out std_logic;
    -- AXI_11_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_11_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_11_BVALID       : out std_logic;
    -- AXI_12_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_12_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_12_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_12_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_12_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_12_ARVALID      : in  std_logic;
    -- AXI_12_ARREADY      : out std_logic;
    -- AXI_12_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_12_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_12_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_12_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_12_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_12_AWVALID      : in  std_logic;
    -- AXI_12_AWREADY      : out std_logic;
    -- AXI_12_RREADY       : in  std_logic;
    -- AXI_12_BREADY       : in  std_logic;
    -- AXI_12_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_12_WLAST        : in  std_logic;
    -- AXI_12_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_12_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_12_WVALID       : in  std_logic;
    -- AXI_12_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_12_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_12_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_12_RLAST        : out std_logic;
    -- AXI_12_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_12_RVALID       : out std_logic;
    -- AXI_12_WREADY       : out std_logic;
    -- AXI_12_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_12_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_12_BVALID       : out std_logic;

    -- AXI_13_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_13_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_13_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_13_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_13_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_13_ARVALID      : in  std_logic;
    -- AXI_13_ARREADY      : out std_logic;
    -- AXI_13_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_13_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_13_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_13_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_13_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_13_AWVALID      : in  std_logic;
    -- AXI_13_AWREADY      : out std_logic;
    -- AXI_13_RREADY       : in  std_logic;
    -- AXI_13_BREADY       : in  std_logic;
    -- AXI_13_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_13_WLAST        : in  std_logic;
    -- AXI_13_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_13_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_13_WVALID       : in  std_logic;
    -- AXI_13_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_13_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_13_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_13_RLAST        : out std_logic;
    -- AXI_13_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_13_RVALID       : out std_logic;
    -- AXI_13_WREADY       : out std_logic;
    -- AXI_13_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_13_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_13_BVALID       : out std_logic;
    -- AXI_14_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_14_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_14_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_14_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_14_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_14_ARVALID      : in  std_logic;
    -- AXI_14_ARREADY      : out std_logic;
    -- AXI_14_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_14_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_14_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_14_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_14_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_14_AWVALID      : in  std_logic;
    -- AXI_14_AWREADY      : out std_logic;
    -- AXI_14_RREADY       : in  std_logic;
    -- AXI_14_BREADY       : in  std_logic;
    -- AXI_14_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_14_WLAST        : in  std_logic;
    -- AXI_14_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_14_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_14_WVALID       : in  std_logic;
    -- AXI_14_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_14_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_14_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_14_RLAST        : out std_logic;
    -- AXI_14_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_14_RVALID       : out std_logic;
    -- AXI_14_WREADY       : out std_logic;
    -- AXI_14_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_14_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_14_BVALID       : out std_logic;

    -- AXI_15_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_15_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_15_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_15_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_15_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_15_ARVALID      : in  std_logic;
    -- AXI_15_ARREADY      : out std_logic;
    -- AXI_15_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_15_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_15_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_15_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_15_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_15_AWVALID      : in  std_logic;
    -- AXI_15_AWREADY      : out std_logic;
    -- AXI_15_RREADY       : in  std_logic;
    -- AXI_15_BREADY       : in  std_logic;
    -- AXI_15_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_15_WLAST        : in  std_logic;
    -- AXI_15_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_15_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_15_WVALID       : in  std_logic;
    -- AXI_15_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_15_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_15_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_15_RLAST        : out std_logic;
    -- AXI_15_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_15_RVALID       : out std_logic;
    -- AXI_15_WREADY       : out std_logic;
    -- AXI_15_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_15_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_15_BVALID       : out std_logic;

    -- ==================================================
    -- AXI_16
    -- ==================================================

    -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    AXI_16_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    AXI_16_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    AXI_16_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    AXI_16_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    AXI_16_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    AXI_16_ARVALID      : in  std_logic;
    AXI_16_ARREADY      : out std_logic;

    AXI_16_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_16_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_16_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_16_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_16_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_16_AWVALID      : in  std_logic;
    AXI_16_AWREADY      : out std_logic;

    AXI_16_RREADY       : in  std_logic;
    AXI_16_BREADY       : in  std_logic;

    AXI_16_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_16_WLAST        : in  std_logic;
    AXI_16_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_16_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_16_WVALID       : in  std_logic;

    AXI_16_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_16_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_16_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_16_RLAST        : out std_logic;
    AXI_16_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_16_RVALID       : out std_logic;

    AXI_16_WREADY       : out std_logic;

    AXI_16_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_16_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_16_BVALID       : out std_logic;

    -- ==================================================
    -- AXI_17
    -- ==================================================

    -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    AXI_17_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    AXI_17_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    AXI_17_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    AXI_17_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    AXI_17_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    AXI_17_ARVALID      : in  std_logic;
    AXI_17_ARREADY      : out std_logic;

    AXI_17_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_17_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_17_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_17_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_17_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_17_AWVALID      : in  std_logic;
    AXI_17_AWREADY      : out std_logic;

    AXI_17_RREADY       : in  std_logic;
    AXI_17_BREADY       : in  std_logic;

    AXI_17_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_17_WLAST        : in  std_logic;
    AXI_17_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_17_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_17_WVALID       : in  std_logic;

    AXI_17_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_17_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_17_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_17_RLAST        : out std_logic;
    AXI_17_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_17_RVALID       : out std_logic;

    AXI_17_WREADY       : out std_logic;

    AXI_17_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_17_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_17_BVALID       : out std_logic;

    -- ==================================================
    -- AXI_18
    -- ==================================================

    -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    AXI_18_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    AXI_18_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    AXI_18_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    AXI_18_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    AXI_18_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    AXI_18_ARVALID      : in  std_logic;
    AXI_18_ARREADY      : out std_logic;

    AXI_18_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_18_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_18_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_18_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_18_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_18_AWVALID      : in  std_logic;
    AXI_18_AWREADY      : out std_logic;

    AXI_18_RREADY       : in  std_logic;
    AXI_18_BREADY       : in  std_logic;

    AXI_18_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_18_WLAST        : in  std_logic;
    AXI_18_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_18_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_18_WVALID       : in  std_logic;

    AXI_18_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_18_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_18_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_18_RLAST        : out std_logic;
    AXI_18_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_18_RVALID       : out std_logic;

    AXI_18_WREADY       : out std_logic;

    AXI_18_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_18_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_18_BVALID       : out std_logic;

    -- ==================================================
    -- AXI_19
    -- ==================================================

    -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    AXI_19_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    AXI_19_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    AXI_19_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    AXI_19_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    AXI_19_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    AXI_19_ARVALID      : in  std_logic;
    AXI_19_ARREADY      : out std_logic;

    AXI_19_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_19_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_19_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_19_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_19_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_19_AWVALID      : in  std_logic;
    AXI_19_AWREADY      : out std_logic;

    AXI_19_RREADY       : in  std_logic;
    AXI_19_BREADY       : in  std_logic;

    AXI_19_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_19_WLAST        : in  std_logic;
    AXI_19_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_19_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_19_WVALID       : in  std_logic;

    AXI_19_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_19_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_19_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_19_RLAST        : out std_logic;
    AXI_19_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_19_RVALID       : out std_logic;

    AXI_19_WREADY       : out std_logic;

    AXI_19_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_19_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_19_BVALID       : out std_logic;

    -- ==================================================
    -- AXI_20
    -- ==================================================

    -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    AXI_20_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    AXI_20_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    AXI_20_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    AXI_20_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    AXI_20_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    AXI_20_ARVALID      : in  std_logic;
    AXI_20_ARREADY      : out std_logic;

    AXI_20_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    AXI_20_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    AXI_20_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_20_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    AXI_20_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    AXI_20_AWVALID      : in  std_logic;
    AXI_20_AWREADY      : out std_logic;

    AXI_20_RREADY       : in  std_logic;
    AXI_20_BREADY       : in  std_logic;

    AXI_20_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_20_WLAST        : in  std_logic;
    AXI_20_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_20_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_20_WVALID       : in  std_logic;

    AXI_20_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    AXI_20_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    AXI_20_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_20_RLAST        : out std_logic;
    AXI_20_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_20_RVALID       : out std_logic;

    AXI_20_WREADY       : out std_logic;

    AXI_20_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    AXI_20_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    AXI_20_BVALID       : out std_logic;

    -- -- ==================================================
    -- -- AXI_21
    -- -- ==================================================

    -- -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    -- AXI_21_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    -- AXI_21_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    -- AXI_21_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    -- AXI_21_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    -- AXI_21_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    -- AXI_21_ARVALID      : in  std_logic;
    -- AXI_21_ARREADY      : out std_logic;

    -- AXI_21_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_21_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_21_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_21_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_21_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_21_AWVALID      : in  std_logic;
    -- AXI_21_AWREADY      : out std_logic;

    -- AXI_21_RREADY       : in  std_logic;
    -- AXI_21_BREADY       : in  std_logic;

    -- AXI_21_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_21_WLAST        : in  std_logic;
    -- AXI_21_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_21_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_21_WVALID       : in  std_logic;

    -- AXI_21_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_21_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_21_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_21_RLAST        : out std_logic;
    -- AXI_21_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_21_RVALID       : out std_logic;

    -- AXI_21_WREADY       : out std_logic;

    -- AXI_21_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_21_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_21_BVALID       : out std_logic;

    -- -- ==================================================
    -- -- AXI_22
    -- -- ==================================================

    -- -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    -- AXI_22_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    -- AXI_22_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    -- AXI_22_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    -- AXI_22_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    -- AXI_22_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    -- AXI_22_ARVALID      : in  std_logic;
    -- AXI_22_ARREADY      : out std_logic;

    -- AXI_22_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_22_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_22_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_22_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_22_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_22_AWVALID      : in  std_logic;
    -- AXI_22_AWREADY      : out std_logic;

    -- AXI_22_RREADY       : in  std_logic;
    -- AXI_22_BREADY       : in  std_logic;

    -- AXI_22_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_22_WLAST        : in  std_logic;
    -- AXI_22_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_22_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_22_WVALID       : in  std_logic;

    -- AXI_22_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_22_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_22_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_22_RLAST        : out std_logic;
    -- AXI_22_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_22_RVALID       : out std_logic;

    -- AXI_22_WREADY       : out std_logic;

    -- AXI_22_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_22_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_22_BVALID       : out std_logic;

    -- -- ==================================================
    -- -- AXI_23
    -- -- ==================================================

    -- -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    -- AXI_23_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    -- AXI_23_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    -- AXI_23_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    -- AXI_23_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    -- AXI_23_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    -- AXI_23_ARVALID      : in  std_logic;
    -- AXI_23_ARREADY      : out std_logic;

    -- AXI_23_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_23_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_23_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_23_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_23_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_23_AWVALID      : in  std_logic;
    -- AXI_23_AWREADY      : out std_logic;

    -- AXI_23_RREADY       : in  std_logic;
    -- AXI_23_BREADY       : in  std_logic;

    -- AXI_23_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_23_WLAST        : in  std_logic;
    -- AXI_23_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_23_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_23_WVALID       : in  std_logic;

    -- AXI_23_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_23_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_23_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_23_RLAST        : out std_logic;
    -- AXI_23_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_23_RVALID       : out std_logic;

    -- AXI_23_WREADY       : out std_logic;

    -- AXI_23_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_23_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_23_BVALID       : out std_logic;

    -- -- ==================================================
    -- -- AXI_24
    -- -- ==================================================

    -- -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    -- AXI_24_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    -- AXI_24_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    -- AXI_24_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    -- AXI_24_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    -- AXI_24_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    -- AXI_24_ARVALID      : in  std_logic;
    -- AXI_24_ARREADY      : out std_logic;

    -- AXI_24_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_24_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_24_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_24_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_24_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_24_AWVALID      : in  std_logic;
    -- AXI_24_AWREADY      : out std_logic;

    -- AXI_24_RREADY       : in  std_logic;
    -- AXI_24_BREADY       : in  std_logic;

    -- AXI_24_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_24_WLAST        : in  std_logic;
    -- AXI_24_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_24_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_24_WVALID       : in  std_logic;

    -- AXI_24_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_24_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_24_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_24_RLAST        : out std_logic;
    -- AXI_24_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_24_RVALID       : out std_logic;

    -- AXI_24_WREADY       : out std_logic;

    -- AXI_24_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_24_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_24_BVALID       : out std_logic;

    -- -- ==================================================
    -- -- AXI_25
    -- -- ==================================================

    -- -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    -- AXI_25_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    -- AXI_25_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    -- AXI_25_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    -- AXI_25_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    -- AXI_25_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    -- AXI_25_ARVALID      : in  std_logic;
    -- AXI_25_ARREADY      : out std_logic;

    -- AXI_25_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_25_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_25_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_25_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_25_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_25_AWVALID      : in  std_logic;
    -- AXI_25_AWREADY      : out std_logic;

    -- AXI_25_RREADY       : in  std_logic;
    -- AXI_25_BREADY       : in  std_logic;

    -- AXI_25_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_25_WLAST        : in  std_logic;
    -- AXI_25_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_25_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_25_WVALID       : in  std_logic;

    -- AXI_25_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_25_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_25_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_25_RLAST        : out std_logic;
    -- AXI_25_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_25_RVALID       : out std_logic;

    -- AXI_25_WREADY       : out std_logic;

    -- AXI_25_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_25_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_25_BVALID       : out std_logic;

    -- -- ==================================================
    -- -- AXI_26
    -- -- ==================================================

    -- -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    -- AXI_26_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    -- AXI_26_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    -- AXI_26_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    -- AXI_26_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    -- AXI_26_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    -- AXI_26_ARVALID      : in  std_logic;
    -- AXI_26_ARREADY      : out std_logic;

    -- AXI_26_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_26_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_26_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_26_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_26_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_26_AWVALID      : in  std_logic;
    -- AXI_26_AWREADY      : out std_logic;

    -- AXI_26_RREADY       : in  std_logic;
    -- AXI_26_BREADY       : in  std_logic;

    -- AXI_26_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_26_WLAST        : in  std_logic;
    -- AXI_26_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_26_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_26_WVALID       : in  std_logic;

    -- AXI_26_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_26_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_26_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_26_RLAST        : out std_logic;
    -- AXI_26_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_26_RVALID       : out std_logic;

    -- AXI_26_WREADY       : out std_logic;

    -- AXI_26_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_26_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_26_BVALID       : out std_logic;

    -- -- ==================================================
    -- -- AXI_27
    -- -- ==================================================

    -- -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    -- AXI_27_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    -- AXI_27_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    -- AXI_27_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    -- AXI_27_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    -- AXI_27_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    -- AXI_27_ARVALID      : in  std_logic;
    -- AXI_27_ARREADY      : out std_logic;

    -- AXI_27_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_27_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_27_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_27_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_27_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_27_AWVALID      : in  std_logic;
    -- AXI_27_AWREADY      : out std_logic;

    -- AXI_27_RREADY       : in  std_logic;
    -- AXI_27_BREADY       : in  std_logic;

    -- AXI_27_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_27_WLAST        : in  std_logic;
    -- AXI_27_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_27_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_27_WVALID       : in  std_logic;

    -- AXI_27_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_27_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_27_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_27_RLAST        : out std_logic;
    -- AXI_27_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_27_RVALID       : out std_logic;

    -- AXI_27_WREADY       : out std_logic;

    -- AXI_27_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_27_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_27_BVALID       : out std_logic;

    -- -- ==================================================
    -- -- AXI_28
    -- -- ==================================================

    -- -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    -- AXI_28_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    -- AXI_28_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    -- AXI_28_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    -- AXI_28_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    -- AXI_28_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    -- AXI_28_ARVALID      : in  std_logic;
    -- AXI_28_ARREADY      : out std_logic;

    -- AXI_28_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_28_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_28_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_28_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_28_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_28_AWVALID      : in  std_logic;
    -- AXI_28_AWREADY      : out std_logic;

    -- AXI_28_RREADY       : in  std_logic;
    -- AXI_28_BREADY       : in  std_logic;

    -- AXI_28_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_28_WLAST        : in  std_logic;
    -- AXI_28_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_28_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_28_WVALID       : in  std_logic;

    -- AXI_28_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_28_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_28_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_28_RLAST        : out std_logic;
    -- AXI_28_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_28_RVALID       : out std_logic;

    -- AXI_28_WREADY       : out std_logic;

    -- AXI_28_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_28_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_28_BVALID       : out std_logic;

    -- -- ==================================================
    -- -- AXI_29
    -- -- ==================================================

    -- -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    -- AXI_29_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    -- AXI_29_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    -- AXI_29_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    -- AXI_29_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    -- AXI_29_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    -- AXI_29_ARVALID      : in  std_logic;
    -- AXI_29_ARREADY      : out std_logic;

    -- AXI_29_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_29_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_29_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_29_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_29_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_29_AWVALID      : in  std_logic;
    -- AXI_29_AWREADY      : out std_logic;

    -- AXI_29_RREADY       : in  std_logic;
    -- AXI_29_BREADY       : in  std_logic;

    -- AXI_29_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_29_WLAST        : in  std_logic;
    -- AXI_29_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_29_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_29_WVALID       : in  std_logic;

    -- AXI_29_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_29_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_29_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_29_RLAST        : out std_logic;
    -- AXI_29_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_29_RVALID       : out std_logic;

    -- AXI_29_WREADY       : out std_logic;

    -- AXI_29_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_29_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_29_BVALID       : out std_logic;

    -- -- ==================================================
    -- -- AXI_30
    -- -- ==================================================

    -- -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    -- AXI_30_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    -- AXI_30_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    -- AXI_30_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    -- AXI_30_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    -- AXI_30_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    -- AXI_30_ARVALID      : in  std_logic;
    -- AXI_30_ARREADY      : out std_logic;

    -- AXI_30_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_30_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_30_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_30_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_30_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_30_AWVALID      : in  std_logic;
    -- AXI_30_AWREADY      : out std_logic;

    -- AXI_30_RREADY       : in  std_logic;
    -- AXI_30_BREADY       : in  std_logic;

    -- AXI_30_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_30_WLAST        : in  std_logic;
    -- AXI_30_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_30_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_30_WVALID       : in  std_logic;

    -- AXI_30_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_30_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_30_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_30_RLAST        : out std_logic;
    -- AXI_30_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_30_RVALID       : out std_logic;

    -- AXI_30_WREADY       : out std_logic;

    -- AXI_30_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_30_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_30_BVALID       : out std_logic;

    -- -- ==================================================
    -- -- AXI_31
    -- -- ==================================================

    -- -- start addr. must be 128-bit aligned, size must be multiple of 128bit
    -- AXI_31_ARADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);          -- bit 32 selects hbm stack, 31:28 selct AXI port, 27:5 addr, 4:0 unused
    -- AXI_31_ARBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0); -- read burst
    -- AXI_31_ARID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);        -- read addr id
    -- AXI_31_ARLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);  -- burst length
    -- AXI_31_ARSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0); -- burst size
    -- AXI_31_ARVALID      : in  std_logic;
    -- AXI_31_ARREADY      : out std_logic;

    -- AXI_31_AWADDR       : in  std_logic_vector(hbm_addr_width - 1 downto 0);
    -- AXI_31_AWBURST      : in  std_logic_vector(hbm_burstmode_bit_width - 1 downto 0);
    -- AXI_31_AWID         : in  std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_31_AWLEN        : in  std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
    -- AXI_31_AWSIZE       : in  std_logic_vector(hbm_burstsize_bit_width - 1 downto 0);
    -- AXI_31_AWVALID      : in  std_logic;
    -- AXI_31_AWREADY      : out std_logic;

    -- AXI_31_RREADY       : in  std_logic;
    -- AXI_31_BREADY       : in  std_logic;

    -- AXI_31_WDATA        : in  std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_31_WLAST        : in  std_logic;
    -- AXI_31_WSTRB        : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_31_WDATA_PARITY : in  std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_31_WVALID       : in  std_logic;

    -- AXI_31_RDATA_PARITY : out std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);
    -- AXI_31_RDATA        : out std_logic_vector(hbm_data_width - 1 downto 0);
    -- AXI_31_RID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_31_RLAST        : out std_logic;
    -- AXI_31_RRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_31_RVALID       : out std_logic;

    -- AXI_31_WREADY       : out std_logic;

    -- AXI_31_BID          : out std_logic_vector(hbm_id_bit_width - 1 downto 0);
    -- AXI_31_BRESP        : out std_logic_vector(hbm_resp_bit_width - 1 downto 0);
    -- AXI_31_BVALID       : out std_logic;

    -- APB configures the HBM during startup
    APB_0_PCLK          : in  std_logic;                                              -- "APB port clock", must match with apb interface clock which is between 50 MHz and 100 MHz
    APB_0_PRESET_N      : in  std_logic;

    -- APB_0_PWDATA        : in  std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
    -- APB_0_PADDR         : in  std_logic_vector(21 downto 0);
    -- APB_0_PENABLE       : in  std_logic;
    -- APB_0_PSEL          : in  std_logic;
    -- APB_0_PWRITE        : in  std_logic;
    -- APB_0_PRDATA        : out std_logic_vector(hbm_bytes_per_ps_port-1 downto 0);
    -- APB_0_PREADY        : out std_logic;
    -- APB_0_PSLVERR       : out std_logic;
    apb_complete_0      : out std_logic;                                              -- indicates that the initial configuration is complete
    DRAM_0_STAT_CATTRIP : out std_logic;                                              -- catastrophiccally high temperatures, shutdown memory access!
    DRAM_0_STAT_TEMP    : out std_logic_vector(6 downto 0);

    apb_complete_1      : out std_logic;                                              -- indicates that the initial configuration is complete
    DRAM_1_STAT_CATTRIP : out std_logic;                                              -- catastrophiccally high temperatures, shutdown memory access!
    DRAM_1_STAT_TEMP    : out std_logic_vector(6 downto 0)

  );
end entity;

architecture rtl of tfhe_pu is

  signal lwe_n_buf_out              : sub_polynom(0 to pbs_throughput - 1);
  signal lwe_n_buf_out_valid        : std_ulogic;
  signal lwe_n_buf_write_next_reset : std_ulogic;
  signal lwe_n_buf_rq_idx           : unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);

  signal ai_hbm_out  : hbm_ps_out_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
  signal ai_hbm_in   : hbm_ps_in_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
  signal bsk_hbm_out : hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
  signal bsk_hbm_in  : hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);

  -- for the inside connection
  signal intermediate_hbm_write_in_pkgs_stack_0  : hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal intermediate_hbm_write_out_pkgs_stack_0 : hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal intermediate_hbm_read_in_pkgs_stack_0   : hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal intermediate_hbm_read_out_pkgs_stack_0  : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal intermediate_hbm_write_in_pkgs_stack_1  : hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal intermediate_hbm_write_out_pkgs_stack_1 : hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal intermediate_hbm_read_in_pkgs_stack_1   : hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal intermediate_hbm_read_out_pkgs_stack_1  : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);

  -- for the outside connection
  signal hbm_write_in_pkgs_stack_0  : hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal hbm_write_out_pkgs_stack_0 : hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal hbm_read_in_pkgs_stack_0   : hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1); -- v4p ignore w-303. Because unused on purpose, intermediate fetches directly from hbm
  signal hbm_read_out_pkgs_stack_0  : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal hbm_write_in_pkgs_stack_1  : hbm_ps_in_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal hbm_write_out_pkgs_stack_1 : hbm_ps_out_write_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal hbm_read_in_pkgs_stack_1   : hbm_ps_in_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);
  signal hbm_read_out_pkgs_stack_1  : hbm_ps_out_read_pkg_arr(0 to hbm_stack_num_ps_ports - 1);

  -- bsk gets channels 0 to 7.
  constant channel_op_idx     : integer := 0;
  constant channel_lut_idx    : integer := 1;
  constant channel_ai_idx     : integer := 2;
  constant channel_b_idx      : integer := 3;
  constant channel_result_idx : integer := 4;
  --constant channel_bsk_idx    : integer := 5; -- only used when cascading crossbars

  -- constant hbm_stack_1_num_used_channels  : integer := 5;
  constant hbm_stack_1_num_write_channels : integer := 4;

begin

  PBS_BUSY <= START_PBS;

  -- hbm stack 1 channels --> channels 16 to 31, only a few being used
  -- hbm stack 0 channels --> channels 0 to 15, used for bsk only

  -- connecting stack 0
  -- connect bsk-channels-read to accelerator
  ps_port_map: for i in 0 to bsk_hbm_in'length - 1 generate
    bsk_hbm_out(i)                            <= intermediate_hbm_read_out_pkgs_stack_0(i); --Throws away data from unused ports
    intermediate_hbm_read_in_pkgs_stack_0(i)  <= bsk_hbm_in(i);                             --Throws away data from unused ports
    -- connect bsk-channels-write to pcie
    intermediate_hbm_write_in_pkgs_stack_0(i) <= hbm_write_in_pkgs_stack_0(i);
    hbm_write_out_pkgs_stack_0(i)             <= intermediate_hbm_write_out_pkgs_stack_0(i);
  end generate;
  -- -- no read for pcie on the bsk channels --> deactivate read feedback by driving those signals with 0
  -- stack_0_no_pcie_read: for channel_idx in 0 to hbm_stack_num_ps_ports - 1 generate
  --   hbm_read_out_pkgs_stack_0(channel_idx).arready      <= '0';
  --   hbm_read_out_pkgs_stack_0(channel_idx).rvalid       <= '0';
  --   hbm_read_out_pkgs_stack_0(channel_idx).rdata        <= (others => '0');
  --   hbm_read_out_pkgs_stack_0(channel_idx).rdata_parity <= (others => '0');
  --   hbm_read_out_pkgs_stack_0(channel_idx).rid          <= (others => '0');
  --   hbm_read_out_pkgs_stack_0(channel_idx).rlast        <= '0';
  --   hbm_read_out_pkgs_stack_0(channel_idx).rresp        <= (others => '0');
  -- end generate;

  -- connecting stack 1
  -- connect ai-channel-read to accelerator
  ai_hbm_out(0)                                         <= intermediate_hbm_read_out_pkgs_stack_1(channel_ai_idx);
  intermediate_hbm_read_in_pkgs_stack_1(channel_ai_idx) <= ai_hbm_in(0);
  -- info: channel op, lut & b directly are connected to the accelerator since they cannot consist of multiple channels
  make_channels_active: for channel_idx in 0 to hbm_stack_1_num_write_channels-1 generate
    -- ai/op/lut/b-channel-read is connected to accelerator
    -- connect ai/op/lut/b-channel-write to pcie
    hbm_write_out_pkgs_stack_1(channel_idx)             <= intermediate_hbm_write_out_pkgs_stack_1(channel_idx);
    intermediate_hbm_write_in_pkgs_stack_1(channel_idx) <= hbm_write_in_pkgs_stack_1(channel_idx);

    -- -- no read for pcie on these channels --> deactivate read feedback by driving those signals with 0
    -- hbm_read_out_pkgs_stack_1(channel_idx).arready      <= '0';
    -- hbm_read_out_pkgs_stack_1(channel_idx).rvalid       <= '0';
    -- hbm_read_out_pkgs_stack_1(channel_idx).rdata        <= (others => '0');
    -- hbm_read_out_pkgs_stack_1(channel_idx).rdata_parity <= (others => '0');
    -- hbm_read_out_pkgs_stack_1(channel_idx).rid          <= (others => '0');
    -- hbm_read_out_pkgs_stack_1(channel_idx).rlast        <= '0';
    -- hbm_read_out_pkgs_stack_1(channel_idx).rresp        <= (others => '0');
  end generate;

  -- exception: result channel is the only one where accelerator can write and pcie can only read
  -- connect result-channel-read to pcie
  hbm_read_out_pkgs_stack_1(channel_result_idx)             <= intermediate_hbm_read_out_pkgs_stack_1(channel_result_idx);
  intermediate_hbm_read_in_pkgs_stack_1(channel_result_idx) <= hbm_read_in_pkgs_stack_1(channel_result_idx);
  -- info: result-channel-write is directly connected to the pbs_lwe_n_storage

  -- -- no write for pcie on the result channel --> deactivate read feedback by driving those signals with 0
  -- hbm_write_out_pkgs_stack_1(channel_result_idx).awready <= '0';
  -- hbm_write_out_pkgs_stack_1(channel_result_idx).bid     <= (others => '0');
  -- hbm_write_out_pkgs_stack_1(channel_result_idx).bresp   <= (others => '0');
  -- hbm_write_out_pkgs_stack_1(channel_result_idx).bvalid  <= '0';
  -- hbm_write_out_pkgs_stack_1(channel_result_idx).wready  <= '0';

  --   -- the other channels of hbm stack 1 are unused --> deactivate read and write feedback for pcie by driving those signals with 0
  --   make_channels_inactive_1: for channel_idx in hbm_stack_1_num_used_channels to hbm_stack_num_ps_ports - 1 generate
  --     hbm_read_out_pkgs_stack_1(channel_idx).arready      <= '0';
  --     hbm_read_out_pkgs_stack_1(channel_idx).rvalid       <= '0';
  --     hbm_read_out_pkgs_stack_1(channel_idx).rdata        <= (others => '0');
  --     hbm_read_out_pkgs_stack_1(channel_idx).rdata_parity <= (others => '0');
  --     hbm_read_out_pkgs_stack_1(channel_idx).rid          <= (others => '0');
  --     hbm_read_out_pkgs_stack_1(channel_idx).rlast        <= '0';
  --     hbm_read_out_pkgs_stack_1(channel_idx).rresp        <= (others => '0');

  -- 	hbm_write_out_pkgs_stack_1(channel_idx).awready <= '0';
  -- 	hbm_write_out_pkgs_stack_1(channel_idx).bid     <= (others => '0');
  -- 	hbm_write_out_pkgs_stack_1(channel_idx).bresp   <= (others => '0');
  -- 	hbm_write_out_pkgs_stack_1(channel_idx).bvalid  <= '0';
  -- 	hbm_write_out_pkgs_stack_1(channel_idx).wready  <= '0';
  -- 	-- set the inputs of these hbm channels to zero as well to avoid warnings? May be bad for timing though
  --     -- intermediate_hbm_write_in_pkgs_stack_1(channel_idx).awvalid      <= '0';
  --     -- intermediate_hbm_write_in_pkgs_stack_1(channel_idx).wvalid       <= '0';
  --     -- intermediate_hbm_write_in_pkgs_stack_1(channel_idx).bready       <= '0';
  --     -- intermediate_hbm_write_in_pkgs_stack_1(channel_idx).awaddr       <= (others => '0');
  --     -- intermediate_hbm_write_in_pkgs_stack_1(channel_idx).awid         <= (others => '0');
  --     -- intermediate_hbm_write_in_pkgs_stack_1(channel_idx).awlen        <= (others => '0');
  --     -- intermediate_hbm_write_in_pkgs_stack_1(channel_idx).wdata        <= (others => '0');
  --     -- intermediate_hbm_write_in_pkgs_stack_1(channel_idx).wdata_parity <= (others => '0');
  --     -- intermediate_hbm_write_in_pkgs_stack_1(channel_idx).wlast        <= '0';
  --     -- intermediate_hbm_read_in_pkgs_stack_1(channel_idx).arvalid <= '0';
  --     -- intermediate_hbm_read_in_pkgs_stack_1(channel_idx).rready  <= '0';
  --     -- intermediate_hbm_read_in_pkgs_stack_1(channel_idx).araddr  <= (others => '0');
  --     -- intermediate_hbm_read_in_pkgs_stack_1(channel_idx).arid    <= (others => '0');
  --     -- intermediate_hbm_read_in_pkgs_stack_1(channel_idx).arlen   <= (others => '0');
  --   end generate;
  u_pbs_accel: entity work.tfhe_pbs_accelerator
    port map (
      i_clk               => TFHE_CLK,
      i_reset_n           => TFHE_RESET_N, --tfhe_reset_n_sync,
      i_ram_coeff_idx     => lwe_n_buf_rq_idx,
      i_ai_hbm_out        => ai_hbm_out,
      i_bsk_hbm_out       => bsk_hbm_out,
      i_op_hbm_out        => intermediate_hbm_read_out_pkgs_stack_1(channel_op_idx),
      i_lut_hbm_out       => intermediate_hbm_read_out_pkgs_stack_1(channel_lut_idx),
      i_b_hbm_out         => intermediate_hbm_read_out_pkgs_stack_1(channel_b_idx),
      o_out_valid         => lwe_n_buf_out_valid,
      o_return_address    => open,
      o_out_data          => lwe_n_buf_out,
      o_next_module_reset => lwe_n_buf_write_next_reset,
      o_ai_hbm_in         => ai_hbm_in,
      o_bsk_hbm_in        => bsk_hbm_in,
      o_op_hbm_in         => intermediate_hbm_read_in_pkgs_stack_1(channel_op_idx),
      o_lut_hbm_in        => intermediate_hbm_read_in_pkgs_stack_1(channel_lut_idx),
      o_b_hbm_in          => intermediate_hbm_read_in_pkgs_stack_1(channel_b_idx)
    );

  u_pbs_lwe_to_hbm: entity work.pbs_lwe_n_storage_read_to_hbm
    port map (
      i_clk           => TFHE_CLK,
      i_coeffs        => lwe_n_buf_out,
      i_coeffs_valid  => lwe_n_buf_out_valid,
      i_reset         => lwe_n_buf_write_next_reset,
      i_hbm_write_out => intermediate_hbm_write_out_pkgs_stack_1(channel_result_idx),
      o_hbm_write_in  => intermediate_hbm_write_in_pkgs_stack_1(channel_result_idx),
      o_ram_coeff_idx => lwe_n_buf_rq_idx,
      o_done          => PBS_DONE
    );

  hbm_stack_0: entity work.hbm_wrapper_hbm_0_right
    port map (
      i_clk               => TFHE_CLK,
      HBM_REF_CLK_0       => HBM_REF_CLK_0,
      i_clk_apb           => APB_0_PCLK,
      i_reset_n           => AXI_ARESET_N,
      i_reset_n_apb       => APB_0_PRESET_N,
      i_write_pkgs        => intermediate_hbm_write_in_pkgs_stack_0,
      i_read_pkgs         => intermediate_hbm_read_in_pkgs_stack_0, -- bsk_buf reads this hbm and thus delivers the read_in_pkg
      o_write_pkgs        => intermediate_hbm_write_out_pkgs_stack_0,
      o_read_pkgs         => intermediate_hbm_read_out_pkgs_stack_0,
      apb_complete_0      => apb_complete_0,
      DRAM_0_STAT_CATTRIP => DRAM_0_STAT_CATTRIP,
      DRAM_0_STAT_TEMP    => DRAM_0_STAT_TEMP
    );

  hbm_stack_1: entity work.hbm_wrapper_hbm_1_left
    port map (
      i_clk               => TFHE_CLK,
      HBM_REF_CLK_0       => HBM_REF_CLK_1,
      i_clk_apb           => APB_0_PCLK,
      i_reset_n           => AXI_ARESET_N,
      i_reset_n_apb       => APB_0_PRESET_N,
      i_write_pkgs        => intermediate_hbm_write_in_pkgs_stack_1,
      i_read_pkgs         => intermediate_hbm_read_in_pkgs_stack_1,
      o_write_pkgs        => intermediate_hbm_write_out_pkgs_stack_1,
      o_read_pkgs         => intermediate_hbm_read_out_pkgs_stack_1,
      apb_complete_0      => apb_complete_1,
      DRAM_0_STAT_CATTRIP => DRAM_1_STAT_CATTRIP,
      DRAM_0_STAT_TEMP    => DRAM_1_STAT_TEMP
    );

  -- repeating stuff down here: mapping the block input to the more generic structure
  hbm_write_in_pkgs_stack_0(0).awid         <= AXI_00_AWID;
  hbm_write_in_pkgs_stack_0(0).awlen        <= AXI_00_AWLEN;
  hbm_write_in_pkgs_stack_0(0).awvalid      <= AXI_00_AWVALID;
  hbm_write_in_pkgs_stack_0(0).awaddr       <= unsigned(AXI_00_AWADDR);
  hbm_write_in_pkgs_stack_0(0).bready       <= AXI_00_BREADY;
  hbm_write_in_pkgs_stack_0(0).wdata        <= AXI_00_WDATA;
  hbm_write_in_pkgs_stack_0(0).wlast        <= AXI_00_WLAST;
  hbm_write_in_pkgs_stack_0(0).wdata_parity <= AXI_00_WDATA_PARITY;
  hbm_write_in_pkgs_stack_0(0).wvalid       <= AXI_00_WVALID;
  hbm_read_in_pkgs_stack_0(0).araddr        <= unsigned(AXI_00_ARADDR);
  hbm_read_in_pkgs_stack_0(0).arid          <= AXI_00_ARID;
  hbm_read_in_pkgs_stack_0(0).arlen         <= AXI_00_ARLEN;
  hbm_read_in_pkgs_stack_0(0).arvalid       <= AXI_00_ARVALID;
  hbm_read_in_pkgs_stack_0(0).rready        <= AXI_00_RREADY;
  AXI_00_AWREADY                            <= hbm_write_out_pkgs_stack_0(0).awready;
  AXI_00_ARREADY                            <= hbm_read_out_pkgs_stack_0(0).arready;
  AXI_00_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_0(0).rdata_parity;
  AXI_00_RDATA                              <= hbm_read_out_pkgs_stack_0(0).rdata;
  AXI_00_RID                                <= hbm_read_out_pkgs_stack_0(0).rid;
  AXI_00_RLAST                              <= hbm_read_out_pkgs_stack_0(0).rlast;
  AXI_00_RRESP                              <= hbm_read_out_pkgs_stack_0(0).rresp;
  AXI_00_RVALID                             <= hbm_read_out_pkgs_stack_0(0).rvalid;
  AXI_00_WREADY                             <= hbm_write_out_pkgs_stack_0(0).wready;
  AXI_00_BID                                <= hbm_write_out_pkgs_stack_0(0).bid;
  AXI_00_BRESP                              <= hbm_write_out_pkgs_stack_0(0).bresp;
  AXI_00_BVALID                             <= hbm_write_out_pkgs_stack_0(0).bvalid;

  hbm_write_in_pkgs_stack_0(1).awid         <= AXI_01_AWID;
  hbm_write_in_pkgs_stack_0(1).awlen        <= AXI_01_AWLEN;
  hbm_write_in_pkgs_stack_0(1).awvalid      <= AXI_01_AWVALID;
  hbm_write_in_pkgs_stack_0(1).awaddr       <= unsigned(AXI_01_AWADDR);
  hbm_write_in_pkgs_stack_0(1).bready       <= AXI_01_BREADY;
  hbm_write_in_pkgs_stack_0(1).wdata        <= AXI_01_WDATA;
  hbm_write_in_pkgs_stack_0(1).wlast        <= AXI_01_WLAST;
  hbm_write_in_pkgs_stack_0(1).wdata_parity <= AXI_01_WDATA_PARITY;
  hbm_write_in_pkgs_stack_0(1).wvalid       <= AXI_01_WVALID;
  hbm_read_in_pkgs_stack_0(1).araddr        <= unsigned(AXI_01_ARADDR);
  hbm_read_in_pkgs_stack_0(1).arid          <= AXI_01_ARID;
  hbm_read_in_pkgs_stack_0(1).arlen         <= AXI_01_ARLEN;
  hbm_read_in_pkgs_stack_0(1).arvalid       <= AXI_01_ARVALID;
  hbm_read_in_pkgs_stack_0(1).rready        <= AXI_01_RREADY;
  AXI_01_ARREADY                            <= hbm_read_out_pkgs_stack_0(1).arready;
  AXI_01_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_0(1).rdata_parity;
  AXI_01_RDATA                              <= hbm_read_out_pkgs_stack_0(1).rdata;
  AXI_01_RID                                <= hbm_read_out_pkgs_stack_0(1).rid;
  AXI_01_RLAST                              <= hbm_read_out_pkgs_stack_0(1).rlast;
  AXI_01_RRESP                              <= hbm_read_out_pkgs_stack_0(1).rresp;
  AXI_01_RVALID                             <= hbm_read_out_pkgs_stack_0(1).rvalid;
  AXI_01_AWREADY                            <= hbm_write_out_pkgs_stack_0(1).awready;
  AXI_01_WREADY                             <= hbm_write_out_pkgs_stack_0(1).wready;
  AXI_01_BID                                <= hbm_write_out_pkgs_stack_0(1).bid;
  AXI_01_BRESP                              <= hbm_write_out_pkgs_stack_0(1).bresp;
  AXI_01_BVALID                             <= hbm_write_out_pkgs_stack_0(1).bvalid;

  hbm_write_in_pkgs_stack_0(2).awid         <= AXI_02_AWID;
  hbm_write_in_pkgs_stack_0(2).awlen        <= AXI_02_AWLEN;
  hbm_write_in_pkgs_stack_0(2).awvalid      <= AXI_02_AWVALID;
  hbm_write_in_pkgs_stack_0(2).awaddr       <= unsigned(AXI_02_AWADDR);
  hbm_write_in_pkgs_stack_0(2).bready       <= AXI_02_BREADY;
  hbm_write_in_pkgs_stack_0(2).wdata        <= AXI_02_WDATA;
  hbm_write_in_pkgs_stack_0(2).wlast        <= AXI_02_WLAST;
  hbm_write_in_pkgs_stack_0(2).wdata_parity <= AXI_02_WDATA_PARITY;
  hbm_write_in_pkgs_stack_0(2).wvalid       <= AXI_02_WVALID;
  hbm_read_in_pkgs_stack_0(2).araddr        <= unsigned(AXI_02_ARADDR);
  hbm_read_in_pkgs_stack_0(2).arid          <= AXI_02_ARID;
  hbm_read_in_pkgs_stack_0(2).arlen         <= AXI_02_ARLEN;
  hbm_read_in_pkgs_stack_0(2).arvalid       <= AXI_02_ARVALID;
  hbm_read_in_pkgs_stack_0(2).rready        <= AXI_02_RREADY;
  AXI_02_ARREADY                            <= hbm_read_out_pkgs_stack_0(2).arready;
  AXI_02_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_0(2).rdata_parity;
  AXI_02_RDATA                              <= hbm_read_out_pkgs_stack_0(2).rdata;
  AXI_02_RID                                <= hbm_read_out_pkgs_stack_0(2).rid;
  AXI_02_RLAST                              <= hbm_read_out_pkgs_stack_0(2).rlast;
  AXI_02_RRESP                              <= hbm_read_out_pkgs_stack_0(2).rresp;
  AXI_02_RVALID                             <= hbm_read_out_pkgs_stack_0(2).rvalid;
  AXI_02_AWREADY                            <= hbm_write_out_pkgs_stack_0(2).awready;
  AXI_02_WREADY                             <= hbm_write_out_pkgs_stack_0(2).wready;
  AXI_02_BID                                <= hbm_write_out_pkgs_stack_0(2).bid;
  AXI_02_BRESP                              <= hbm_write_out_pkgs_stack_0(2).bresp;
  AXI_02_BVALID                             <= hbm_write_out_pkgs_stack_0(2).bvalid;

  hbm_write_in_pkgs_stack_0(3).awid         <= AXI_03_AWID;
  hbm_write_in_pkgs_stack_0(3).awlen        <= AXI_03_AWLEN;
  hbm_write_in_pkgs_stack_0(3).awvalid      <= AXI_03_AWVALID;
  hbm_write_in_pkgs_stack_0(3).awaddr       <= unsigned(AXI_03_AWADDR);
  hbm_write_in_pkgs_stack_0(3).bready       <= AXI_03_BREADY;
  hbm_write_in_pkgs_stack_0(3).wdata        <= AXI_03_WDATA;
  hbm_write_in_pkgs_stack_0(3).wlast        <= AXI_03_WLAST;
  hbm_write_in_pkgs_stack_0(3).wdata_parity <= AXI_03_WDATA_PARITY;
  hbm_write_in_pkgs_stack_0(3).wvalid       <= AXI_03_WVALID;
  hbm_read_in_pkgs_stack_0(3).araddr        <= unsigned(AXI_03_ARADDR);
  hbm_read_in_pkgs_stack_0(3).arid          <= AXI_03_ARID;
  hbm_read_in_pkgs_stack_0(3).arlen         <= AXI_03_ARLEN;
  hbm_read_in_pkgs_stack_0(3).arvalid       <= AXI_03_ARVALID;
  hbm_read_in_pkgs_stack_0(3).rready        <= AXI_03_RREADY;
  AXI_03_ARREADY                            <= hbm_read_out_pkgs_stack_0(3).arready;
  AXI_03_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_0(3).rdata_parity;
  AXI_03_RDATA                              <= hbm_read_out_pkgs_stack_0(3).rdata;
  AXI_03_RID                                <= hbm_read_out_pkgs_stack_0(3).rid;
  AXI_03_RLAST                              <= hbm_read_out_pkgs_stack_0(3).rlast;
  AXI_03_RRESP                              <= hbm_read_out_pkgs_stack_0(3).rresp;
  AXI_03_RVALID                             <= hbm_read_out_pkgs_stack_0(3).rvalid;
  AXI_03_AWREADY                            <= hbm_write_out_pkgs_stack_0(3).awready;
  AXI_03_WREADY                             <= hbm_write_out_pkgs_stack_0(3).wready;
  AXI_03_BID                                <= hbm_write_out_pkgs_stack_0(3).bid;
  AXI_03_BRESP                              <= hbm_write_out_pkgs_stack_0(3).bresp;
  AXI_03_BVALID                             <= hbm_write_out_pkgs_stack_0(3).bvalid;

  hbm_write_in_pkgs_stack_0(4).awid         <= AXI_04_AWID;
  hbm_write_in_pkgs_stack_0(4).awlen        <= AXI_04_AWLEN;
  hbm_write_in_pkgs_stack_0(4).awvalid      <= AXI_04_AWVALID;
  hbm_write_in_pkgs_stack_0(4).awaddr       <= unsigned(AXI_04_AWADDR);
  hbm_write_in_pkgs_stack_0(4).bready       <= AXI_04_BREADY;
  hbm_write_in_pkgs_stack_0(4).wdata        <= AXI_04_WDATA;
  hbm_write_in_pkgs_stack_0(4).wlast        <= AXI_04_WLAST;
  hbm_write_in_pkgs_stack_0(4).wdata_parity <= AXI_04_WDATA_PARITY;
  hbm_write_in_pkgs_stack_0(4).wvalid       <= AXI_04_WVALID;
  hbm_read_in_pkgs_stack_0(4).araddr        <= unsigned(AXI_04_ARADDR);
  hbm_read_in_pkgs_stack_0(4).arid          <= AXI_04_ARID;
  hbm_read_in_pkgs_stack_0(4).arlen         <= AXI_04_ARLEN;
  hbm_read_in_pkgs_stack_0(4).arvalid       <= AXI_04_ARVALID;
  hbm_read_in_pkgs_stack_0(4).rready        <= AXI_04_RREADY;
  AXI_04_ARREADY                            <= hbm_read_out_pkgs_stack_0(4).arready;
  AXI_04_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_0(4).rdata_parity;
  AXI_04_RDATA                              <= hbm_read_out_pkgs_stack_0(4).rdata;
  AXI_04_RID                                <= hbm_read_out_pkgs_stack_0(4).rid;
  AXI_04_RLAST                              <= hbm_read_out_pkgs_stack_0(4).rlast;
  AXI_04_RRESP                              <= hbm_read_out_pkgs_stack_0(4).rresp;
  AXI_04_RVALID                             <= hbm_read_out_pkgs_stack_0(4).rvalid;
  AXI_04_AWREADY                            <= hbm_write_out_pkgs_stack_0(4).awready;
  AXI_04_WREADY                             <= hbm_write_out_pkgs_stack_0(4).wready;
  AXI_04_BID                                <= hbm_write_out_pkgs_stack_0(4).bid;
  AXI_04_BRESP                              <= hbm_write_out_pkgs_stack_0(4).bresp;
  AXI_04_BVALID                             <= hbm_write_out_pkgs_stack_0(4).bvalid;

  hbm_write_in_pkgs_stack_0(5).awid         <= AXI_05_AWID;
  hbm_write_in_pkgs_stack_0(5).awlen        <= AXI_05_AWLEN;
  hbm_write_in_pkgs_stack_0(5).awvalid      <= AXI_05_AWVALID;
  hbm_write_in_pkgs_stack_0(5).awaddr       <= unsigned(AXI_05_AWADDR);
  hbm_write_in_pkgs_stack_0(5).bready       <= AXI_05_BREADY;
  hbm_write_in_pkgs_stack_0(5).wdata        <= AXI_05_WDATA;
  hbm_write_in_pkgs_stack_0(5).wlast        <= AXI_05_WLAST;
  hbm_write_in_pkgs_stack_0(5).wdata_parity <= AXI_05_WDATA_PARITY;
  hbm_write_in_pkgs_stack_0(5).wvalid       <= AXI_05_WVALID;
  hbm_read_in_pkgs_stack_0(5).araddr        <= unsigned(AXI_05_ARADDR);
  hbm_read_in_pkgs_stack_0(5).arid          <= AXI_05_ARID;
  hbm_read_in_pkgs_stack_0(5).arlen         <= AXI_05_ARLEN;
  hbm_read_in_pkgs_stack_0(5).arvalid       <= AXI_05_ARVALID;
  hbm_read_in_pkgs_stack_0(5).rready        <= AXI_05_RREADY;
  AXI_05_ARREADY                            <= hbm_read_out_pkgs_stack_0(5).arready;
  AXI_05_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_0(5).rdata_parity;
  AXI_05_RDATA                              <= hbm_read_out_pkgs_stack_0(5).rdata;
  AXI_05_RID                                <= hbm_read_out_pkgs_stack_0(5).rid;
  AXI_05_RLAST                              <= hbm_read_out_pkgs_stack_0(5).rlast;
  AXI_05_RRESP                              <= hbm_read_out_pkgs_stack_0(5).rresp;
  AXI_05_RVALID                             <= hbm_read_out_pkgs_stack_0(5).rvalid;
  AXI_05_AWREADY                            <= hbm_write_out_pkgs_stack_0(5).awready;
  AXI_05_WREADY                             <= hbm_write_out_pkgs_stack_0(5).wready;
  AXI_05_BID                                <= hbm_write_out_pkgs_stack_0(5).bid;
  AXI_05_BRESP                              <= hbm_write_out_pkgs_stack_0(5).bresp;
  AXI_05_BVALID                             <= hbm_write_out_pkgs_stack_0(5).bvalid;

  hbm_write_in_pkgs_stack_0(6).awid         <= AXI_06_AWID;
  hbm_write_in_pkgs_stack_0(6).awlen        <= AXI_06_AWLEN;
  hbm_write_in_pkgs_stack_0(6).awvalid      <= AXI_06_AWVALID;
  hbm_write_in_pkgs_stack_0(6).awaddr       <= unsigned(AXI_06_AWADDR);
  hbm_write_in_pkgs_stack_0(6).bready       <= AXI_06_BREADY;
  hbm_write_in_pkgs_stack_0(6).wdata        <= AXI_06_WDATA;
  hbm_write_in_pkgs_stack_0(6).wlast        <= AXI_06_WLAST;
  hbm_write_in_pkgs_stack_0(6).wdata_parity <= AXI_06_WDATA_PARITY;
  hbm_write_in_pkgs_stack_0(6).wvalid       <= AXI_06_WVALID;
  hbm_read_in_pkgs_stack_0(6).araddr        <= unsigned(AXI_06_ARADDR);
  hbm_read_in_pkgs_stack_0(6).arid          <= AXI_06_ARID;
  hbm_read_in_pkgs_stack_0(6).arlen         <= AXI_06_ARLEN;
  hbm_read_in_pkgs_stack_0(6).arvalid       <= AXI_06_ARVALID;
  hbm_read_in_pkgs_stack_0(6).rready        <= AXI_06_RREADY;
  AXI_06_ARREADY                            <= hbm_read_out_pkgs_stack_0(6).arready;
  AXI_06_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_0(6).rdata_parity;
  AXI_06_RDATA                              <= hbm_read_out_pkgs_stack_0(6).rdata;
  AXI_06_RID                                <= hbm_read_out_pkgs_stack_0(6).rid;
  AXI_06_RLAST                              <= hbm_read_out_pkgs_stack_0(6).rlast;
  AXI_06_RRESP                              <= hbm_read_out_pkgs_stack_0(6).rresp;
  AXI_06_RVALID                             <= hbm_read_out_pkgs_stack_0(6).rvalid;
  AXI_06_AWREADY                            <= hbm_write_out_pkgs_stack_0(6).awready;
  AXI_06_WREADY                             <= hbm_write_out_pkgs_stack_0(6).wready;
  AXI_06_BID                                <= hbm_write_out_pkgs_stack_0(6).bid;
  AXI_06_BRESP                              <= hbm_write_out_pkgs_stack_0(6).bresp;
  AXI_06_BVALID                             <= hbm_write_out_pkgs_stack_0(6).bvalid;

  hbm_write_in_pkgs_stack_0(7).awid         <= AXI_07_AWID;
  hbm_write_in_pkgs_stack_0(7).awlen        <= AXI_07_AWLEN;
  hbm_write_in_pkgs_stack_0(7).awvalid      <= AXI_07_AWVALID;
  hbm_write_in_pkgs_stack_0(7).awaddr       <= unsigned(AXI_07_AWADDR);
  hbm_write_in_pkgs_stack_0(7).bready       <= AXI_07_BREADY;
  hbm_write_in_pkgs_stack_0(7).wdata        <= AXI_07_WDATA;
  hbm_write_in_pkgs_stack_0(7).wlast        <= AXI_07_WLAST;
  hbm_write_in_pkgs_stack_0(7).wdata_parity <= AXI_07_WDATA_PARITY;
  hbm_write_in_pkgs_stack_0(7).wvalid       <= AXI_07_WVALID;
  hbm_read_in_pkgs_stack_0(7).araddr        <= unsigned(AXI_07_ARADDR);
  hbm_read_in_pkgs_stack_0(7).arid          <= AXI_07_ARID;
  hbm_read_in_pkgs_stack_0(7).arlen         <= AXI_07_ARLEN;
  hbm_read_in_pkgs_stack_0(7).arvalid       <= AXI_07_ARVALID;
  hbm_read_in_pkgs_stack_0(7).rready        <= AXI_07_RREADY;
  AXI_07_ARREADY                            <= hbm_read_out_pkgs_stack_0(7).arready;
  AXI_07_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_0(7).rdata_parity;
  AXI_07_RDATA                              <= hbm_read_out_pkgs_stack_0(7).rdata;
  AXI_07_RID                                <= hbm_read_out_pkgs_stack_0(7).rid;
  AXI_07_RLAST                              <= hbm_read_out_pkgs_stack_0(7).rlast;
  AXI_07_RRESP                              <= hbm_read_out_pkgs_stack_0(7).rresp;
  AXI_07_RVALID                             <= hbm_read_out_pkgs_stack_0(7).rvalid;
  AXI_07_AWREADY                            <= hbm_write_out_pkgs_stack_0(7).awready;
  AXI_07_WREADY                             <= hbm_write_out_pkgs_stack_0(7).wready;
  AXI_07_BID                                <= hbm_write_out_pkgs_stack_0(7).bid;
  AXI_07_BRESP                              <= hbm_write_out_pkgs_stack_0(7).bresp;
  AXI_07_BVALID                             <= hbm_write_out_pkgs_stack_0(7).bvalid;

  -- hbm_write_in_pkgs_stack_0(8).awid         <= AXI_08_AWID;
  -- hbm_write_in_pkgs_stack_0(8).awlen        <= AXI_08_AWLEN;
  -- hbm_write_in_pkgs_stack_0(8).awvalid      <= AXI_08_AWVALID;
  -- hbm_write_in_pkgs_stack_0(8).awaddr       <= unsigned(AXI_08_AWADDR);
  -- hbm_write_in_pkgs_stack_0(8).bready       <= AXI_08_BREADY;
  -- hbm_write_in_pkgs_stack_0(8).wdata        <= AXI_08_WDATA;
  -- hbm_write_in_pkgs_stack_0(8).wlast        <= AXI_08_WLAST;
  -- hbm_write_in_pkgs_stack_0(8).wdata_parity <= AXI_08_WDATA_PARITY;
  -- hbm_write_in_pkgs_stack_0(8).wvalid       <= AXI_08_WVALID;
  -- hbm_read_in_pkgs_stack_0(8).araddr        <= unsigned(AXI_08_ARADDR);
  -- hbm_read_in_pkgs_stack_0(8).arid          <= AXI_08_ARID;
  -- hbm_read_in_pkgs_stack_0(8).arlen         <= AXI_08_ARLEN;
  -- hbm_read_in_pkgs_stack_0(8).arvalid       <= AXI_08_ARVALID;
  -- hbm_read_in_pkgs_stack_0(8).rready        <= AXI_08_RREADY;
  -- AXI_08_ARREADY                            <= hbm_read_out_pkgs_stack_0(8).arready;
  -- AXI_08_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_0(8).rdata_parity;
  -- AXI_08_RDATA                              <= hbm_read_out_pkgs_stack_0(8).rdata;
  -- AXI_08_RID                                <= hbm_read_out_pkgs_stack_0(8).rid;
  -- AXI_08_RLAST                              <= hbm_read_out_pkgs_stack_0(8).rlast;
  -- AXI_08_RRESP                              <= hbm_read_out_pkgs_stack_0(8).rresp;
  -- AXI_08_RVALID                             <= hbm_read_out_pkgs_stack_0(8).rvalid;
  -- AXI_08_AWREADY                            <= hbm_write_out_pkgs_stack_0(8).awready;
  -- AXI_08_WREADY                             <= hbm_write_out_pkgs_stack_0(8).wready;
  -- AXI_08_BID                                <= hbm_write_out_pkgs_stack_0(8).bid;
  -- AXI_08_BRESP                              <= hbm_write_out_pkgs_stack_0(8).bresp;
  -- AXI_08_BVALID                             <= hbm_write_out_pkgs_stack_0(8).bvalid;

  -- hbm_write_in_pkgs_stack_0(9).awid         <= AXI_09_AWID;
  -- hbm_write_in_pkgs_stack_0(9).awlen        <= AXI_09_AWLEN;
  -- hbm_write_in_pkgs_stack_0(9).awvalid      <= AXI_09_AWVALID;
  -- hbm_write_in_pkgs_stack_0(9).awaddr       <= unsigned(AXI_09_AWADDR);
  -- hbm_write_in_pkgs_stack_0(9).bready       <= AXI_09_BREADY;
  -- hbm_write_in_pkgs_stack_0(9).wdata        <= AXI_09_WDATA;
  -- hbm_write_in_pkgs_stack_0(9).wlast        <= AXI_09_WLAST;
  -- hbm_write_in_pkgs_stack_0(9).wdata_parity <= AXI_09_WDATA_PARITY;
  -- hbm_write_in_pkgs_stack_0(9).wvalid       <= AXI_09_WVALID;
  -- hbm_read_in_pkgs_stack_0(9).araddr        <= unsigned(AXI_09_ARADDR);
  -- hbm_read_in_pkgs_stack_0(9).arid          <= AXI_09_ARID;
  -- hbm_read_in_pkgs_stack_0(9).arlen         <= AXI_09_ARLEN;
  -- hbm_read_in_pkgs_stack_0(9).arvalid       <= AXI_09_ARVALID;
  -- hbm_read_in_pkgs_stack_0(9).rready        <= AXI_09_RREADY;
  -- AXI_09_ARREADY                            <= hbm_read_out_pkgs_stack_0(9).arready;
  -- AXI_09_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_0(9).rdata_parity;
  -- AXI_09_RDATA                              <= hbm_read_out_pkgs_stack_0(9).rdata;
  -- AXI_09_RID                                <= hbm_read_out_pkgs_stack_0(9).rid;
  -- AXI_09_RLAST                              <= hbm_read_out_pkgs_stack_0(9).rlast;
  -- AXI_09_RRESP                              <= hbm_read_out_pkgs_stack_0(9).rresp;
  -- AXI_09_RVALID                             <= hbm_read_out_pkgs_stack_0(9).rvalid;
  -- AXI_09_AWREADY                            <= hbm_write_out_pkgs_stack_0(9).awready;
  -- AXI_09_WREADY                             <= hbm_write_out_pkgs_stack_0(9).wready;
  -- AXI_09_BID                                <= hbm_write_out_pkgs_stack_0(9).bid;
  -- AXI_09_BRESP                              <= hbm_write_out_pkgs_stack_0(9).bresp;
  -- AXI_09_BVALID                             <= hbm_write_out_pkgs_stack_0(9).bvalid;
  -- hbm_write_in_pkgs_stack_0(10).awid         <= AXI_10_AWID;
  -- hbm_write_in_pkgs_stack_0(10).awlen        <= AXI_10_AWLEN;
  -- hbm_write_in_pkgs_stack_0(10).awvalid      <= AXI_10_AWVALID;
  -- hbm_write_in_pkgs_stack_0(10).awaddr       <= unsigned(AXI_10_AWADDR);
  -- hbm_write_in_pkgs_stack_0(10).bready       <= AXI_10_BREADY;
  -- hbm_write_in_pkgs_stack_0(10).wdata        <= AXI_10_WDATA;
  -- hbm_write_in_pkgs_stack_0(10).wlast        <= AXI_10_WLAST;
  -- hbm_write_in_pkgs_stack_0(10).wdata_parity <= AXI_10_WDATA_PARITY;
  -- hbm_write_in_pkgs_stack_0(10).wvalid       <= AXI_10_WVALID;
  -- hbm_read_in_pkgs_stack_0(10).araddr        <= unsigned(AXI_10_ARADDR);
  -- hbm_read_in_pkgs_stack_0(10).arid          <= AXI_10_ARID;
  -- hbm_read_in_pkgs_stack_0(10).arlen         <= AXI_10_ARLEN;
  -- hbm_read_in_pkgs_stack_0(10).arvalid       <= AXI_10_ARVALID;
  -- hbm_read_in_pkgs_stack_0(10).rready        <= AXI_10_RREADY;
  -- AXI_10_ARREADY                             <= hbm_read_out_pkgs_stack_0(10).arready;
  -- AXI_10_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_0(10).rdata_parity;
  -- AXI_10_RDATA                               <= hbm_read_out_pkgs_stack_0(10).rdata;
  -- AXI_10_RID                                 <= hbm_read_out_pkgs_stack_0(10).rid;
  -- AXI_10_RLAST                               <= hbm_read_out_pkgs_stack_0(10).rlast;
  -- AXI_10_RRESP                               <= hbm_read_out_pkgs_stack_0(10).rresp;
  -- AXI_10_RVALID                              <= hbm_read_out_pkgs_stack_0(10).rvalid;
  -- AXI_10_AWREADY                             <= hbm_write_out_pkgs_stack_0(10).awready;
  -- AXI_10_WREADY                              <= hbm_write_out_pkgs_stack_0(10).wready;
  -- AXI_10_BID                                 <= hbm_write_out_pkgs_stack_0(10).bid;
  -- AXI_10_BRESP                               <= hbm_write_out_pkgs_stack_0(10).bresp;
  -- AXI_10_BVALID                              <= hbm_write_out_pkgs_stack_0(10).bvalid;

  -- hbm_write_in_pkgs_stack_0(11).awid         <= AXI_11_AWID;
  -- hbm_write_in_pkgs_stack_0(11).awlen        <= AXI_11_AWLEN;
  -- hbm_write_in_pkgs_stack_0(11).awvalid      <= AXI_11_AWVALID;
  -- hbm_write_in_pkgs_stack_0(11).awaddr       <= unsigned(AXI_11_AWADDR);
  -- hbm_write_in_pkgs_stack_0(11).bready       <= AXI_11_BREADY;
  -- hbm_write_in_pkgs_stack_0(11).wdata        <= AXI_11_WDATA;
  -- hbm_write_in_pkgs_stack_0(11).wlast        <= AXI_11_WLAST;
  -- hbm_write_in_pkgs_stack_0(11).wdata_parity <= AXI_11_WDATA_PARITY;
  -- hbm_write_in_pkgs_stack_0(11).wvalid       <= AXI_11_WVALID;
  -- hbm_read_in_pkgs_stack_0(11).araddr        <= unsigned(AXI_11_ARADDR);
  -- hbm_read_in_pkgs_stack_0(11).arid          <= AXI_11_ARID;
  -- hbm_read_in_pkgs_stack_0(11).arlen         <= AXI_11_ARLEN;
  -- hbm_read_in_pkgs_stack_0(11).arvalid       <= AXI_11_ARVALID;
  -- hbm_read_in_pkgs_stack_0(11).rready        <= AXI_11_RREADY;
  -- AXI_11_ARREADY                             <= hbm_read_out_pkgs_stack_0(11).arready;
  -- AXI_11_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_0(11).rdata_parity;
  -- AXI_11_RDATA                               <= hbm_read_out_pkgs_stack_0(11).rdata;
  -- AXI_11_RID                                 <= hbm_read_out_pkgs_stack_0(11).rid;
  -- AXI_11_RLAST                               <= hbm_read_out_pkgs_stack_0(11).rlast;
  -- AXI_11_RRESP                               <= hbm_read_out_pkgs_stack_0(11).rresp;
  -- AXI_11_RVALID                              <= hbm_read_out_pkgs_stack_0(11).rvalid;
  -- AXI_11_AWREADY                             <= hbm_write_out_pkgs_stack_0(11).awready;
  -- AXI_11_WREADY                              <= hbm_write_out_pkgs_stack_0(11).wready;
  -- AXI_11_BID                                 <= hbm_write_out_pkgs_stack_0(11).bid;
  -- AXI_11_BRESP                               <= hbm_write_out_pkgs_stack_0(11).bresp;
  -- AXI_11_BVALID                              <= hbm_write_out_pkgs_stack_0(11).bvalid;

  -- hbm_write_in_pkgs_stack_0(12).awid         <= AXI_12_AWID;
  -- hbm_write_in_pkgs_stack_0(12).awlen        <= AXI_12_AWLEN;
  -- hbm_write_in_pkgs_stack_0(12).awvalid      <= AXI_12_AWVALID;
  -- hbm_write_in_pkgs_stack_0(12).awaddr       <= unsigned(AXI_12_AWADDR);
  -- hbm_write_in_pkgs_stack_0(12).bready       <= AXI_12_BREADY;
  -- hbm_write_in_pkgs_stack_0(12).wdata        <= AXI_12_WDATA;
  -- hbm_write_in_pkgs_stack_0(12).wlast        <= AXI_12_WLAST;
  -- hbm_write_in_pkgs_stack_0(12).wdata_parity <= AXI_12_WDATA_PARITY;
  -- hbm_write_in_pkgs_stack_0(12).wvalid       <= AXI_12_WVALID;
  -- hbm_read_in_pkgs_stack_0(12).araddr        <= unsigned(AXI_12_ARADDR);
  -- hbm_read_in_pkgs_stack_0(12).arid          <= AXI_12_ARID;
  -- hbm_read_in_pkgs_stack_0(12).arlen         <= AXI_12_ARLEN;
  -- hbm_read_in_pkgs_stack_0(12).arvalid       <= AXI_12_ARVALID;
  -- hbm_read_in_pkgs_stack_0(12).rready        <= AXI_12_RREADY;
  -- AXI_12_ARREADY                             <= hbm_read_out_pkgs_stack_0(12).arready;
  -- AXI_12_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_0(12).rdata_parity;
  -- AXI_12_RDATA                               <= hbm_read_out_pkgs_stack_0(12).rdata;
  -- AXI_12_RID                                 <= hbm_read_out_pkgs_stack_0(12).rid;
  -- AXI_12_RLAST                               <= hbm_read_out_pkgs_stack_0(12).rlast;
  -- AXI_12_RRESP                               <= hbm_read_out_pkgs_stack_0(12).rresp;
  -- AXI_12_RVALID                              <= hbm_read_out_pkgs_stack_0(12).rvalid;
  -- AXI_12_AWREADY                             <= hbm_write_out_pkgs_stack_0(12).awready;
  -- AXI_12_WREADY                              <= hbm_write_out_pkgs_stack_0(12).wready;
  -- AXI_12_BID                                 <= hbm_write_out_pkgs_stack_0(12).bid;
  -- AXI_12_BRESP                               <= hbm_write_out_pkgs_stack_0(12).bresp;
  -- AXI_12_BVALID                              <= hbm_write_out_pkgs_stack_0(12).bvalid;

  -- hbm_write_in_pkgs_stack_0(13).awid         <= AXI_13_AWID;
  -- hbm_write_in_pkgs_stack_0(13).awlen        <= AXI_13_AWLEN;
  -- hbm_write_in_pkgs_stack_0(13).awvalid      <= AXI_13_AWVALID;
  -- hbm_write_in_pkgs_stack_0(13).awaddr       <= unsigned(AXI_13_AWADDR);
  -- hbm_write_in_pkgs_stack_0(13).bready       <= AXI_13_BREADY;
  -- hbm_write_in_pkgs_stack_0(13).wdata        <= AXI_13_WDATA;
  -- hbm_write_in_pkgs_stack_0(13).wlast        <= AXI_13_WLAST;
  -- hbm_write_in_pkgs_stack_0(13).wdata_parity <= AXI_13_WDATA_PARITY;
  -- hbm_write_in_pkgs_stack_0(13).wvalid       <= AXI_13_WVALID;
  -- hbm_read_in_pkgs_stack_0(13).araddr        <= unsigned(AXI_13_ARADDR);
  -- hbm_read_in_pkgs_stack_0(13).arid          <= AXI_13_ARID;
  -- hbm_read_in_pkgs_stack_0(13).arlen         <= AXI_13_ARLEN;
  -- hbm_read_in_pkgs_stack_0(13).arvalid       <= AXI_13_ARVALID;
  -- hbm_read_in_pkgs_stack_0(13).rready        <= AXI_13_RREADY;
  -- AXI_13_ARREADY                             <= hbm_read_out_pkgs_stack_0(13).arready;
  -- AXI_13_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_0(13).rdata_parity;
  -- AXI_13_RDATA                               <= hbm_read_out_pkgs_stack_0(13).rdata;
  -- AXI_13_RID                                 <= hbm_read_out_pkgs_stack_0(13).rid;
  -- AXI_13_RLAST                               <= hbm_read_out_pkgs_stack_0(13).rlast;
  -- AXI_13_RRESP                               <= hbm_read_out_pkgs_stack_0(13).rresp;
  -- AXI_13_RVALID                              <= hbm_read_out_pkgs_stack_0(13).rvalid;
  -- AXI_13_AWREADY                             <= hbm_write_out_pkgs_stack_0(13).awready;
  -- AXI_13_WREADY                              <= hbm_write_out_pkgs_stack_0(13).wready;
  -- AXI_13_BID                                 <= hbm_write_out_pkgs_stack_0(13).bid;
  -- AXI_13_BRESP                               <= hbm_write_out_pkgs_stack_0(13).bresp;
  -- AXI_13_BVALID                              <= hbm_write_out_pkgs_stack_0(13).bvalid;
  
  -- hbm_write_in_pkgs_stack_0(14).awid         <= AXI_14_AWID;
  -- hbm_write_in_pkgs_stack_0(14).awlen        <= AXI_14_AWLEN;
  -- hbm_write_in_pkgs_stack_0(14).awvalid      <= AXI_14_AWVALID;
  -- hbm_write_in_pkgs_stack_0(14).awaddr       <= unsigned(AXI_14_AWADDR);
  -- hbm_write_in_pkgs_stack_0(14).bready       <= AXI_14_BREADY;
  -- hbm_write_in_pkgs_stack_0(14).wdata        <= AXI_14_WDATA;
  -- hbm_write_in_pkgs_stack_0(14).wlast        <= AXI_14_WLAST;
  -- hbm_write_in_pkgs_stack_0(14).wdata_parity <= AXI_14_WDATA_PARITY;
  -- hbm_write_in_pkgs_stack_0(14).wvalid       <= AXI_14_WVALID;
  -- hbm_read_in_pkgs_stack_0(14).araddr        <= unsigned(AXI_14_ARADDR);
  -- hbm_read_in_pkgs_stack_0(14).arid          <= AXI_14_ARID;
  -- hbm_read_in_pkgs_stack_0(14).arlen         <= AXI_14_ARLEN;
  -- hbm_read_in_pkgs_stack_0(14).arvalid       <= AXI_14_ARVALID;
  -- hbm_read_in_pkgs_stack_0(14).rready        <= AXI_14_RREADY;
  -- AXI_14_ARREADY                             <= hbm_read_out_pkgs_stack_0(14).arready;
  -- AXI_14_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_0(14).rdata_parity;
  -- AXI_14_RDATA                               <= hbm_read_out_pkgs_stack_0(14).rdata;
  -- AXI_14_RID                                 <= hbm_read_out_pkgs_stack_0(14).rid;
  -- AXI_14_RLAST                               <= hbm_read_out_pkgs_stack_0(14).rlast;
  -- AXI_14_RRESP                               <= hbm_read_out_pkgs_stack_0(14).rresp;
  -- AXI_14_RVALID                              <= hbm_read_out_pkgs_stack_0(14).rvalid;
  -- AXI_14_AWREADY                             <= hbm_write_out_pkgs_stack_0(14).awready;
  -- AXI_14_WREADY                              <= hbm_write_out_pkgs_stack_0(14).wready;
  -- AXI_14_BID                                 <= hbm_write_out_pkgs_stack_0(14).bid;
  -- AXI_14_BRESP                               <= hbm_write_out_pkgs_stack_0(14).bresp;
  -- AXI_14_BVALID                              <= hbm_write_out_pkgs_stack_0(14).bvalid;

  -- hbm_write_in_pkgs_stack_0(15).awid         <= AXI_15_AWID;
  -- hbm_write_in_pkgs_stack_0(15).awlen        <= AXI_15_AWLEN;
  -- hbm_write_in_pkgs_stack_0(15).awvalid      <= AXI_15_AWVALID;
  -- hbm_write_in_pkgs_stack_0(15).awaddr       <= unsigned(AXI_15_AWADDR);
  -- hbm_write_in_pkgs_stack_0(15).bready       <= AXI_15_BREADY;
  -- hbm_write_in_pkgs_stack_0(15).wdata        <= AXI_15_WDATA;
  -- hbm_write_in_pkgs_stack_0(15).wlast        <= AXI_15_WLAST;
  -- hbm_write_in_pkgs_stack_0(15).wdata_parity <= AXI_15_WDATA_PARITY;
  -- hbm_write_in_pkgs_stack_0(15).wvalid       <= AXI_15_WVALID;
  -- hbm_read_in_pkgs_stack_0(15).araddr        <= unsigned(AXI_15_ARADDR);
  -- hbm_read_in_pkgs_stack_0(15).arid          <= AXI_15_ARID;
  -- hbm_read_in_pkgs_stack_0(15).arlen         <= AXI_15_ARLEN;
  -- hbm_read_in_pkgs_stack_0(15).arvalid       <= AXI_15_ARVALID;
  -- hbm_read_in_pkgs_stack_0(15).rready        <= AXI_15_RREADY;
  -- AXI_15_ARREADY                             <= hbm_read_out_pkgs_stack_0(15).arready;
  -- AXI_15_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_0(15).rdata_parity;
  -- AXI_15_RDATA                               <= hbm_read_out_pkgs_stack_0(15).rdata;
  -- AXI_15_RID                                 <= hbm_read_out_pkgs_stack_0(15).rid;
  -- AXI_15_RLAST                               <= hbm_read_out_pkgs_stack_0(15).rlast;
  -- AXI_15_RRESP                               <= hbm_read_out_pkgs_stack_0(15).rresp;
  -- AXI_15_RVALID                              <= hbm_read_out_pkgs_stack_0(15).rvalid;
  -- AXI_15_AWREADY                             <= hbm_write_out_pkgs_stack_0(15).awready;
  -- AXI_15_WREADY                              <= hbm_write_out_pkgs_stack_0(15).wready;
  -- AXI_15_BID                                 <= hbm_write_out_pkgs_stack_0(15).bid;
  -- AXI_15_BRESP                               <= hbm_write_out_pkgs_stack_0(15).bresp;
  -- AXI_15_BVALID                              <= hbm_write_out_pkgs_stack_0(15).bvalid;

  hbm_write_in_pkgs_stack_1(0).awid         <= AXI_16_AWID;
  hbm_write_in_pkgs_stack_1(0).awlen        <= AXI_16_AWLEN;
  hbm_write_in_pkgs_stack_1(0).awvalid      <= AXI_16_AWVALID;
  hbm_write_in_pkgs_stack_1(0).awaddr       <= unsigned(AXI_16_AWADDR);
  hbm_write_in_pkgs_stack_1(0).bready       <= AXI_16_BREADY;
  hbm_write_in_pkgs_stack_1(0).wdata        <= AXI_16_WDATA;
  hbm_write_in_pkgs_stack_1(0).wlast        <= AXI_16_WLAST;
  hbm_write_in_pkgs_stack_1(0).wdata_parity <= AXI_16_WDATA_PARITY;
  hbm_write_in_pkgs_stack_1(0).wvalid       <= AXI_16_WVALID;
  hbm_read_in_pkgs_stack_1(0).araddr        <= unsigned(AXI_16_ARADDR);
  hbm_read_in_pkgs_stack_1(0).arid          <= AXI_16_ARID;
  hbm_read_in_pkgs_stack_1(0).arlen         <= AXI_16_ARLEN;
  hbm_read_in_pkgs_stack_1(0).arvalid       <= AXI_16_ARVALID;
  hbm_read_in_pkgs_stack_1(0).rready        <= AXI_16_RREADY;
  AXI_16_ARREADY                            <= hbm_read_out_pkgs_stack_1(0).arready;
  AXI_16_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_1(0).rdata_parity;
  AXI_16_RDATA                              <= hbm_read_out_pkgs_stack_1(0).rdata;
  AXI_16_RID                                <= hbm_read_out_pkgs_stack_1(0).rid;
  AXI_16_RLAST                              <= hbm_read_out_pkgs_stack_1(0).rlast;
  AXI_16_RRESP                              <= hbm_read_out_pkgs_stack_1(0).rresp;
  AXI_16_RVALID                             <= hbm_read_out_pkgs_stack_1(0).rvalid;
  AXI_16_AWREADY                            <= hbm_write_out_pkgs_stack_1(0).awready;
  AXI_16_WREADY                             <= hbm_write_out_pkgs_stack_1(0).wready;
  AXI_16_BID                                <= hbm_write_out_pkgs_stack_1(0).bid;
  AXI_16_BRESP                              <= hbm_write_out_pkgs_stack_1(0).bresp;
  AXI_16_BVALID                             <= hbm_write_out_pkgs_stack_1(0).bvalid;

  hbm_write_in_pkgs_stack_1(1).awid         <= AXI_17_AWID;
  hbm_write_in_pkgs_stack_1(1).awlen        <= AXI_17_AWLEN;
  hbm_write_in_pkgs_stack_1(1).awvalid      <= AXI_17_AWVALID;
  hbm_write_in_pkgs_stack_1(1).awaddr       <= unsigned(AXI_17_AWADDR);
  hbm_write_in_pkgs_stack_1(1).bready       <= AXI_17_BREADY;
  hbm_write_in_pkgs_stack_1(1).wdata        <= AXI_17_WDATA;
  hbm_write_in_pkgs_stack_1(1).wlast        <= AXI_17_WLAST;
  hbm_write_in_pkgs_stack_1(1).wdata_parity <= AXI_17_WDATA_PARITY;
  hbm_write_in_pkgs_stack_1(1).wvalid       <= AXI_17_WVALID;
  hbm_read_in_pkgs_stack_1(1).araddr        <= unsigned(AXI_17_ARADDR);
  hbm_read_in_pkgs_stack_1(1).arid          <= AXI_17_ARID;
  hbm_read_in_pkgs_stack_1(1).arlen         <= AXI_17_ARLEN;
  hbm_read_in_pkgs_stack_1(1).arvalid       <= AXI_17_ARVALID;
  hbm_read_in_pkgs_stack_1(1).rready        <= AXI_17_RREADY;
  AXI_17_ARREADY                            <= hbm_read_out_pkgs_stack_1(1).arready;
  AXI_17_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_1(1).rdata_parity;
  AXI_17_RDATA                              <= hbm_read_out_pkgs_stack_1(1).rdata;
  AXI_17_RID                                <= hbm_read_out_pkgs_stack_1(1).rid;
  AXI_17_RLAST                              <= hbm_read_out_pkgs_stack_1(1).rlast;
  AXI_17_RRESP                              <= hbm_read_out_pkgs_stack_1(1).rresp;
  AXI_17_RVALID                             <= hbm_read_out_pkgs_stack_1(1).rvalid;
  AXI_17_AWREADY                            <= hbm_write_out_pkgs_stack_1(1).awready;
  AXI_17_WREADY                             <= hbm_write_out_pkgs_stack_1(1).wready;
  AXI_17_BID                                <= hbm_write_out_pkgs_stack_1(1).bid;
  AXI_17_BRESP                              <= hbm_write_out_pkgs_stack_1(1).bresp;
  AXI_17_BVALID                             <= hbm_write_out_pkgs_stack_1(1).bvalid;

  hbm_write_in_pkgs_stack_1(2).awid         <= AXI_18_AWID;
  hbm_write_in_pkgs_stack_1(2).awlen        <= AXI_18_AWLEN;
  hbm_write_in_pkgs_stack_1(2).awvalid      <= AXI_18_AWVALID;
  hbm_write_in_pkgs_stack_1(2).awaddr       <= unsigned(AXI_18_AWADDR);
  hbm_write_in_pkgs_stack_1(2).bready       <= AXI_18_BREADY;
  hbm_write_in_pkgs_stack_1(2).wdata        <= AXI_18_WDATA;
  hbm_write_in_pkgs_stack_1(2).wlast        <= AXI_18_WLAST;
  hbm_write_in_pkgs_stack_1(2).wdata_parity <= AXI_18_WDATA_PARITY;
  hbm_write_in_pkgs_stack_1(2).wvalid       <= AXI_18_WVALID;
  hbm_read_in_pkgs_stack_1(2).araddr        <= unsigned(AXI_18_ARADDR);
  hbm_read_in_pkgs_stack_1(2).arid          <= AXI_18_ARID;
  hbm_read_in_pkgs_stack_1(2).arlen         <= AXI_18_ARLEN;
  hbm_read_in_pkgs_stack_1(2).arvalid       <= AXI_18_ARVALID;
  hbm_read_in_pkgs_stack_1(2).rready        <= AXI_18_RREADY;
  AXI_18_ARREADY                            <= hbm_read_out_pkgs_stack_1(2).arready;
  AXI_18_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_1(2).rdata_parity;
  AXI_18_RDATA                              <= hbm_read_out_pkgs_stack_1(2).rdata;
  AXI_18_RID                                <= hbm_read_out_pkgs_stack_1(2).rid;
  AXI_18_RLAST                              <= hbm_read_out_pkgs_stack_1(2).rlast;
  AXI_18_RRESP                              <= hbm_read_out_pkgs_stack_1(2).rresp;
  AXI_18_RVALID                             <= hbm_read_out_pkgs_stack_1(2).rvalid;
  AXI_18_AWREADY                            <= hbm_write_out_pkgs_stack_1(2).awready;
  AXI_18_WREADY                             <= hbm_write_out_pkgs_stack_1(2).wready;
  AXI_18_BID                                <= hbm_write_out_pkgs_stack_1(2).bid;
  AXI_18_BRESP                              <= hbm_write_out_pkgs_stack_1(2).bresp;
  AXI_18_BVALID                             <= hbm_write_out_pkgs_stack_1(2).bvalid;

  hbm_write_in_pkgs_stack_1(3).awid         <= AXI_19_AWID;
  hbm_write_in_pkgs_stack_1(3).awlen        <= AXI_19_AWLEN;
  hbm_write_in_pkgs_stack_1(3).awvalid      <= AXI_19_AWVALID;
  hbm_write_in_pkgs_stack_1(3).awaddr       <= unsigned(AXI_19_AWADDR);
  hbm_write_in_pkgs_stack_1(3).bready       <= AXI_19_BREADY;
  hbm_write_in_pkgs_stack_1(3).wdata        <= AXI_19_WDATA;
  hbm_write_in_pkgs_stack_1(3).wlast        <= AXI_19_WLAST;
  hbm_write_in_pkgs_stack_1(3).wdata_parity <= AXI_19_WDATA_PARITY;
  hbm_write_in_pkgs_stack_1(3).wvalid       <= AXI_19_WVALID;
  hbm_read_in_pkgs_stack_1(3).araddr        <= unsigned(AXI_19_ARADDR);
  hbm_read_in_pkgs_stack_1(3).arid          <= AXI_19_ARID;
  hbm_read_in_pkgs_stack_1(3).arlen         <= AXI_19_ARLEN;
  hbm_read_in_pkgs_stack_1(3).arvalid       <= AXI_19_ARVALID;
  hbm_read_in_pkgs_stack_1(3).rready        <= AXI_19_RREADY;
  AXI_19_ARREADY                            <= hbm_read_out_pkgs_stack_1(3).arready;
  AXI_19_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_1(3).rdata_parity;
  AXI_19_RDATA                              <= hbm_read_out_pkgs_stack_1(3).rdata;
  AXI_19_RID                                <= hbm_read_out_pkgs_stack_1(3).rid;
  AXI_19_RLAST                              <= hbm_read_out_pkgs_stack_1(3).rlast;
  AXI_19_RRESP                              <= hbm_read_out_pkgs_stack_1(3).rresp;
  AXI_19_RVALID                             <= hbm_read_out_pkgs_stack_1(3).rvalid;
  AXI_19_AWREADY                            <= hbm_write_out_pkgs_stack_1(3).awready;
  AXI_19_WREADY                             <= hbm_write_out_pkgs_stack_1(3).wready;
  AXI_19_BID                                <= hbm_write_out_pkgs_stack_1(3).bid;
  AXI_19_BRESP                              <= hbm_write_out_pkgs_stack_1(3).bresp;
  AXI_19_BVALID                             <= hbm_write_out_pkgs_stack_1(3).bvalid;

  hbm_write_in_pkgs_stack_1(4).awid         <= AXI_20_AWID;
  hbm_write_in_pkgs_stack_1(4).awlen        <= AXI_20_AWLEN;
  hbm_write_in_pkgs_stack_1(4).awvalid      <= AXI_20_AWVALID;
  hbm_write_in_pkgs_stack_1(4).awaddr       <= unsigned(AXI_20_AWADDR);
  hbm_write_in_pkgs_stack_1(4).bready       <= AXI_20_BREADY;
  hbm_write_in_pkgs_stack_1(4).wdata        <= AXI_20_WDATA;
  hbm_write_in_pkgs_stack_1(4).wlast        <= AXI_20_WLAST;
  hbm_write_in_pkgs_stack_1(4).wdata_parity <= AXI_20_WDATA_PARITY;
  hbm_write_in_pkgs_stack_1(4).wvalid       <= AXI_20_WVALID;
  hbm_read_in_pkgs_stack_1(4).araddr        <= unsigned(AXI_20_ARADDR);
  hbm_read_in_pkgs_stack_1(4).arid          <= AXI_20_ARID;
  hbm_read_in_pkgs_stack_1(4).arlen         <= AXI_20_ARLEN;
  hbm_read_in_pkgs_stack_1(4).arvalid       <= AXI_20_ARVALID;
  hbm_read_in_pkgs_stack_1(4).rready        <= AXI_20_RREADY;
  AXI_20_ARREADY                            <= hbm_read_out_pkgs_stack_1(4).arready;
  AXI_20_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_1(4).rdata_parity;
  AXI_20_RDATA                              <= hbm_read_out_pkgs_stack_1(4).rdata;
  AXI_20_RID                                <= hbm_read_out_pkgs_stack_1(4).rid;
  AXI_20_RLAST                              <= hbm_read_out_pkgs_stack_1(4).rlast;
  AXI_20_RRESP                              <= hbm_read_out_pkgs_stack_1(4).rresp;
  AXI_20_RVALID                             <= hbm_read_out_pkgs_stack_1(4).rvalid;
  AXI_20_AWREADY                            <= hbm_write_out_pkgs_stack_1(4).awready;
  AXI_20_WREADY                             <= hbm_write_out_pkgs_stack_1(4).wready;
  AXI_20_BID                                <= hbm_write_out_pkgs_stack_1(4).bid;
  AXI_20_BRESP                              <= hbm_write_out_pkgs_stack_1(4).bresp;
  AXI_20_BVALID                             <= hbm_write_out_pkgs_stack_1(4).bvalid;

  -- hbm_write_in_pkgs_stack_1(5).awid         <= AXI_21_AWID;
  -- hbm_write_in_pkgs_stack_1(5).awlen        <= AXI_21_AWLEN;
  -- hbm_write_in_pkgs_stack_1(5).awvalid      <= AXI_21_AWVALID;
  -- hbm_write_in_pkgs_stack_1(5).awaddr       <= unsigned(AXI_21_AWADDR);
  -- hbm_write_in_pkgs_stack_1(5).bready       <= AXI_21_BREADY;
  -- hbm_write_in_pkgs_stack_1(5).wdata        <= AXI_21_WDATA;
  -- hbm_write_in_pkgs_stack_1(5).wlast        <= AXI_21_WLAST;
  -- hbm_write_in_pkgs_stack_1(5).wdata_parity <= AXI_21_WDATA_PARITY;
  -- hbm_write_in_pkgs_stack_1(5).wvalid       <= AXI_21_WVALID;
  -- hbm_read_in_pkgs_stack_1(5).araddr        <= unsigned(AXI_21_ARADDR);
  -- hbm_read_in_pkgs_stack_1(5).arid          <= AXI_21_ARID;
  -- hbm_read_in_pkgs_stack_1(5).arlen         <= AXI_21_ARLEN;
  -- hbm_read_in_pkgs_stack_1(5).arvalid       <= AXI_21_ARVALID;
  -- hbm_read_in_pkgs_stack_1(5).rready        <= AXI_21_RREADY;
  -- AXI_21_ARREADY                            <= hbm_read_out_pkgs_stack_1(5).arready;
  -- AXI_21_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_1(5).rdata_parity;
  -- AXI_21_RDATA                              <= hbm_read_out_pkgs_stack_1(5).rdata;
  -- AXI_21_RID                                <= hbm_read_out_pkgs_stack_1(5).rid;
  -- AXI_21_RLAST                              <= hbm_read_out_pkgs_stack_1(5).rlast;
  -- AXI_21_RRESP                              <= hbm_read_out_pkgs_stack_1(5).rresp;
  -- AXI_21_RVALID                             <= hbm_read_out_pkgs_stack_1(5).rvalid;
  -- AXI_21_AWREADY                            <= hbm_write_out_pkgs_stack_1(5).awready;
  -- AXI_21_WREADY                             <= hbm_write_out_pkgs_stack_1(5).wready;
  -- AXI_21_BID                                <= hbm_write_out_pkgs_stack_1(5).bid;
  -- AXI_21_BRESP                              <= hbm_write_out_pkgs_stack_1(5).bresp;
  -- AXI_21_BVALID                             <= hbm_write_out_pkgs_stack_1(5).bvalid;

  --   hbm_write_in_pkgs_stack_1(6).awid         <= AXI_22_AWID;
  --   hbm_write_in_pkgs_stack_1(6).awlen        <= AXI_22_AWLEN;
  --   hbm_write_in_pkgs_stack_1(6).awvalid      <= AXI_22_AWVALID;
  --   hbm_write_in_pkgs_stack_1(6).awaddr       <= unsigned(AXI_22_AWADDR);
  --   hbm_write_in_pkgs_stack_1(6).bready       <= AXI_22_BREADY;
  --   hbm_write_in_pkgs_stack_1(6).wdata        <= AXI_22_WDATA;
  --   hbm_write_in_pkgs_stack_1(6).wlast        <= AXI_22_WLAST;
  --   hbm_write_in_pkgs_stack_1(6).wdata_parity <= AXI_22_WDATA_PARITY;
  --   hbm_write_in_pkgs_stack_1(6).wvalid       <= AXI_22_WVALID;
  --   hbm_read_in_pkgs_stack_1(6).araddr        <= unsigned(AXI_22_ARADDR);
  --   hbm_read_in_pkgs_stack_1(6).arid          <= AXI_22_ARID;
  --   hbm_read_in_pkgs_stack_1(6).arlen         <= AXI_22_ARLEN;
  --   hbm_read_in_pkgs_stack_1(6).arvalid       <= AXI_22_ARVALID;
  --   hbm_read_in_pkgs_stack_1(6).rready        <= AXI_22_RREADY;
  --   AXI_22_ARREADY                            <= hbm_read_out_pkgs_stack_1(6).arready;
  --   AXI_22_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_1(6).rdata_parity;
  --   AXI_22_RDATA                              <= hbm_read_out_pkgs_stack_1(6).rdata;
  --   AXI_22_RID                                <= hbm_read_out_pkgs_stack_1(6).rid;
  --   AXI_22_RLAST                              <= hbm_read_out_pkgs_stack_1(6).rlast;
  --   AXI_22_RRESP                              <= hbm_read_out_pkgs_stack_1(6).rresp;
  --   AXI_22_RVALID                             <= hbm_read_out_pkgs_stack_1(6).rvalid;
  --   AXI_22_AWREADY                            <= hbm_write_out_pkgs_stack_1(6).awready;
  --   AXI_22_WREADY                             <= hbm_write_out_pkgs_stack_1(6).wready;
  --   AXI_22_BID                                <= hbm_write_out_pkgs_stack_1(6).bid;
  --   AXI_22_BRESP                              <= hbm_write_out_pkgs_stack_1(6).bresp;
  --   AXI_22_BVALID                             <= hbm_write_out_pkgs_stack_1(6).bvalid;

  --   hbm_write_in_pkgs_stack_1(7).awid         <= AXI_23_AWID;
  --   hbm_write_in_pkgs_stack_1(7).awlen        <= AXI_23_AWLEN;
  --   hbm_write_in_pkgs_stack_1(7).awvalid      <= AXI_23_AWVALID;
  --   hbm_write_in_pkgs_stack_1(7).awaddr       <= unsigned(AXI_23_AWADDR);
  --   hbm_write_in_pkgs_stack_1(7).bready       <= AXI_23_BREADY;
  --   hbm_write_in_pkgs_stack_1(7).wdata        <= AXI_23_WDATA;
  --   hbm_write_in_pkgs_stack_1(7).wlast        <= AXI_23_WLAST;
  --   hbm_write_in_pkgs_stack_1(7).wdata_parity <= AXI_23_WDATA_PARITY;
  --   hbm_write_in_pkgs_stack_1(7).wvalid       <= AXI_23_WVALID;
  --   hbm_read_in_pkgs_stack_1(7).araddr        <= unsigned(AXI_23_ARADDR);
  --   hbm_read_in_pkgs_stack_1(7).arid          <= AXI_23_ARID;
  --   hbm_read_in_pkgs_stack_1(7).arlen         <= AXI_23_ARLEN;
  --   hbm_read_in_pkgs_stack_1(7).arvalid       <= AXI_23_ARVALID;
  --   hbm_read_in_pkgs_stack_1(7).rready        <= AXI_23_RREADY;
  --   AXI_23_ARREADY                            <= hbm_read_out_pkgs_stack_1(7).arready;
  --   AXI_23_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_1(7).rdata_parity;
  --   AXI_23_RDATA                              <= hbm_read_out_pkgs_stack_1(7).rdata;
  --   AXI_23_RID                                <= hbm_read_out_pkgs_stack_1(7).rid;
  --   AXI_23_RLAST                              <= hbm_read_out_pkgs_stack_1(7).rlast;
  --   AXI_23_RRESP                              <= hbm_read_out_pkgs_stack_1(7).rresp;
  --   AXI_23_RVALID                             <= hbm_read_out_pkgs_stack_1(7).rvalid;
  --   AXI_23_AWREADY                            <= hbm_write_out_pkgs_stack_1(7).awready;
  --   AXI_23_WREADY                             <= hbm_write_out_pkgs_stack_1(7).wready;
  --   AXI_23_BID                                <= hbm_write_out_pkgs_stack_1(7).bid;
  --   AXI_23_BRESP                              <= hbm_write_out_pkgs_stack_1(7).bresp;
  --   AXI_23_BVALID                             <= hbm_write_out_pkgs_stack_1(7).bvalid;

  --   hbm_write_in_pkgs_stack_1(8).awid         <= AXI_24_AWID;
  --   hbm_write_in_pkgs_stack_1(8).awlen        <= AXI_24_AWLEN;
  --   hbm_write_in_pkgs_stack_1(8).awvalid      <= AXI_24_AWVALID;
  --   hbm_write_in_pkgs_stack_1(8).awaddr       <= unsigned(AXI_24_AWADDR);
  --   hbm_write_in_pkgs_stack_1(8).bready       <= AXI_24_BREADY;
  --   hbm_write_in_pkgs_stack_1(8).wdata        <= AXI_24_WDATA;
  --   hbm_write_in_pkgs_stack_1(8).wlast        <= AXI_24_WLAST;
  --   hbm_write_in_pkgs_stack_1(8).wdata_parity <= AXI_24_WDATA_PARITY;
  --   hbm_write_in_pkgs_stack_1(8).wvalid       <= AXI_24_WVALID;
  --   hbm_read_in_pkgs_stack_1(8).araddr        <= unsigned(AXI_24_ARADDR);
  --   hbm_read_in_pkgs_stack_1(8).arid          <= AXI_24_ARID;
  --   hbm_read_in_pkgs_stack_1(8).arlen         <= AXI_24_ARLEN;
  --   hbm_read_in_pkgs_stack_1(8).arvalid       <= AXI_24_ARVALID;
  --   hbm_read_in_pkgs_stack_1(8).rready        <= AXI_24_RREADY;
  --   AXI_24_ARREADY                            <= hbm_read_out_pkgs_stack_1(8).arready;
  --   AXI_24_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_1(8).rdata_parity;
  --   AXI_24_RDATA                              <= hbm_read_out_pkgs_stack_1(8).rdata;
  --   AXI_24_RID                                <= hbm_read_out_pkgs_stack_1(8).rid;
  --   AXI_24_RLAST                              <= hbm_read_out_pkgs_stack_1(8).rlast;
  --   AXI_24_RRESP                              <= hbm_read_out_pkgs_stack_1(8).rresp;
  --   AXI_24_RVALID                             <= hbm_read_out_pkgs_stack_1(8).rvalid;
  --   AXI_24_AWREADY                            <= hbm_write_out_pkgs_stack_1(8).awready;
  --   AXI_24_WREADY                             <= hbm_write_out_pkgs_stack_1(8).wready;
  --   AXI_24_BID                                <= hbm_write_out_pkgs_stack_1(8).bid;
  --   AXI_24_BRESP                              <= hbm_write_out_pkgs_stack_1(8).bresp;
  --   AXI_24_BVALID                             <= hbm_write_out_pkgs_stack_1(8).bvalid;

  --   hbm_write_in_pkgs_stack_1(9).awid         <= AXI_25_AWID;
  --   hbm_write_in_pkgs_stack_1(9).awlen        <= AXI_25_AWLEN;
  --   hbm_write_in_pkgs_stack_1(9).awvalid      <= AXI_25_AWVALID;
  --   hbm_write_in_pkgs_stack_1(9).awaddr       <= unsigned(AXI_25_AWADDR);
  --   hbm_write_in_pkgs_stack_1(9).bready       <= AXI_25_BREADY;
  --   hbm_write_in_pkgs_stack_1(9).wdata        <= AXI_25_WDATA;
  --   hbm_write_in_pkgs_stack_1(9).wlast        <= AXI_25_WLAST;
  --   hbm_write_in_pkgs_stack_1(9).wdata_parity <= AXI_25_WDATA_PARITY;
  --   hbm_write_in_pkgs_stack_1(9).wvalid       <= AXI_25_WVALID;
  --   hbm_read_in_pkgs_stack_1(9).araddr        <= unsigned(AXI_25_ARADDR);
  --   hbm_read_in_pkgs_stack_1(9).arid          <= AXI_25_ARID;
  --   hbm_read_in_pkgs_stack_1(9).arlen         <= AXI_25_ARLEN;
  --   hbm_read_in_pkgs_stack_1(9).arvalid       <= AXI_25_ARVALID;
  --   hbm_read_in_pkgs_stack_1(9).rready        <= AXI_25_RREADY;
  --   AXI_25_ARREADY                            <= hbm_read_out_pkgs_stack_1(9).arready;
  --   AXI_25_RDATA_PARITY                       <= hbm_read_out_pkgs_stack_1(9).rdata_parity;
  --   AXI_25_RDATA                              <= hbm_read_out_pkgs_stack_1(9).rdata;
  --   AXI_25_RID                                <= hbm_read_out_pkgs_stack_1(9).rid;
  --   AXI_25_RLAST                              <= hbm_read_out_pkgs_stack_1(9).rlast;
  --   AXI_25_RRESP                              <= hbm_read_out_pkgs_stack_1(9).rresp;
  --   AXI_25_RVALID                             <= hbm_read_out_pkgs_stack_1(9).rvalid;
  --   AXI_25_AWREADY                            <= hbm_write_out_pkgs_stack_1(9).awready;
  --   AXI_25_WREADY                             <= hbm_write_out_pkgs_stack_1(9).wready;
  --   AXI_25_BID                                <= hbm_write_out_pkgs_stack_1(9).bid;
  --   AXI_25_BRESP                              <= hbm_write_out_pkgs_stack_1(9).bresp;
  --   AXI_25_BVALID                             <= hbm_write_out_pkgs_stack_1(9).bvalid;

  --   hbm_write_in_pkgs_stack_1(10).awid         <= AXI_26_AWID;
  --   hbm_write_in_pkgs_stack_1(10).awlen        <= AXI_26_AWLEN;
  --   hbm_write_in_pkgs_stack_1(10).awvalid      <= AXI_26_AWVALID;
  --   hbm_write_in_pkgs_stack_1(10).awaddr       <= unsigned(AXI_26_AWADDR);
  --   hbm_write_in_pkgs_stack_1(10).bready       <= AXI_26_BREADY;
  --   hbm_write_in_pkgs_stack_1(10).wdata        <= AXI_26_WDATA;
  --   hbm_write_in_pkgs_stack_1(10).wlast        <= AXI_26_WLAST;
  --   hbm_write_in_pkgs_stack_1(10).wdata_parity <= AXI_26_WDATA_PARITY;
  --   hbm_write_in_pkgs_stack_1(10).wvalid       <= AXI_26_WVALID;
  --   hbm_read_in_pkgs_stack_1(10).araddr        <= unsigned(AXI_26_ARADDR);
  --   hbm_read_in_pkgs_stack_1(10).arid          <= AXI_26_ARID;
  --   hbm_read_in_pkgs_stack_1(10).arlen         <= AXI_26_ARLEN;
  --   hbm_read_in_pkgs_stack_1(10).arvalid       <= AXI_26_ARVALID;
  --   hbm_read_in_pkgs_stack_1(10).rready        <= AXI_26_RREADY;
  --   AXI_26_ARREADY                             <= hbm_read_out_pkgs_stack_1(10).arready;
  --   AXI_26_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_1(10).rdata_parity;
  --   AXI_26_RDATA                               <= hbm_read_out_pkgs_stack_1(10).rdata;
  --   AXI_26_RID                                 <= hbm_read_out_pkgs_stack_1(10).rid;
  --   AXI_26_RLAST                               <= hbm_read_out_pkgs_stack_1(10).rlast;
  --   AXI_26_RRESP                               <= hbm_read_out_pkgs_stack_1(10).rresp;
  --   AXI_26_RVALID                              <= hbm_read_out_pkgs_stack_1(10).rvalid;
  --   AXI_26_AWREADY                             <= hbm_write_out_pkgs_stack_1(10).awready;
  --   AXI_26_WREADY                              <= hbm_write_out_pkgs_stack_1(10).wready;
  --   AXI_26_BID                                 <= hbm_write_out_pkgs_stack_1(10).bid;
  --   AXI_26_BRESP                               <= hbm_write_out_pkgs_stack_1(10).bresp;
  --   AXI_26_BVALID                              <= hbm_write_out_pkgs_stack_1(10).bvalid;

  --   hbm_write_in_pkgs_stack_1(11).awid         <= AXI_27_AWID;
  --   hbm_write_in_pkgs_stack_1(11).awlen        <= AXI_27_AWLEN;
  --   hbm_write_in_pkgs_stack_1(11).awvalid      <= AXI_27_AWVALID;
  --   hbm_write_in_pkgs_stack_1(11).awaddr       <= unsigned(AXI_27_AWADDR);
  --   hbm_write_in_pkgs_stack_1(11).bready       <= AXI_27_BREADY;
  --   hbm_write_in_pkgs_stack_1(11).wdata        <= AXI_27_WDATA;
  --   hbm_write_in_pkgs_stack_1(11).wlast        <= AXI_27_WLAST;
  --   hbm_write_in_pkgs_stack_1(11).wdata_parity <= AXI_27_WDATA_PARITY;
  --   hbm_write_in_pkgs_stack_1(11).wvalid       <= AXI_27_WVALID;
  --   hbm_read_in_pkgs_stack_1(11).araddr        <= unsigned(AXI_27_ARADDR);
  --   hbm_read_in_pkgs_stack_1(11).arid          <= AXI_27_ARID;
  --   hbm_read_in_pkgs_stack_1(11).arlen         <= AXI_27_ARLEN;
  --   hbm_read_in_pkgs_stack_1(11).arvalid       <= AXI_27_ARVALID;
  --   hbm_read_in_pkgs_stack_1(11).rready        <= AXI_27_RREADY;
  --   AXI_27_ARREADY                             <= hbm_read_out_pkgs_stack_1(11).arready;
  --   AXI_27_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_1(11).rdata_parity;
  --   AXI_27_RDATA                               <= hbm_read_out_pkgs_stack_1(11).rdata;
  --   AXI_27_RID                                 <= hbm_read_out_pkgs_stack_1(11).rid;
  --   AXI_27_RLAST                               <= hbm_read_out_pkgs_stack_1(11).rlast;
  --   AXI_27_RRESP                               <= hbm_read_out_pkgs_stack_1(11).rresp;
  --   AXI_27_RVALID                              <= hbm_read_out_pkgs_stack_1(11).rvalid;
  --   AXI_27_AWREADY                             <= hbm_write_out_pkgs_stack_1(11).awready;
  --   AXI_27_WREADY                              <= hbm_write_out_pkgs_stack_1(11).wready;
  --   AXI_27_BID                                 <= hbm_write_out_pkgs_stack_1(11).bid;
  --   AXI_27_BRESP                               <= hbm_write_out_pkgs_stack_1(11).bresp;
  --   AXI_27_BVALID                              <= hbm_write_out_pkgs_stack_1(11).bvalid;

  --   hbm_write_in_pkgs_stack_1(12).awid         <= AXI_28_AWID;
  --   hbm_write_in_pkgs_stack_1(12).awlen        <= AXI_28_AWLEN;
  --   hbm_write_in_pkgs_stack_1(12).awvalid      <= AXI_28_AWVALID;
  --   hbm_write_in_pkgs_stack_1(12).awaddr       <= unsigned(AXI_28_AWADDR);
  --   hbm_write_in_pkgs_stack_1(12).bready       <= AXI_28_BREADY;
  --   hbm_write_in_pkgs_stack_1(12).wdata        <= AXI_28_WDATA;
  --   hbm_write_in_pkgs_stack_1(12).wlast        <= AXI_28_WLAST;
  --   hbm_write_in_pkgs_stack_1(12).wdata_parity <= AXI_28_WDATA_PARITY;
  --   hbm_write_in_pkgs_stack_1(12).wvalid       <= AXI_28_WVALID;
  --   hbm_read_in_pkgs_stack_1(12).araddr        <= unsigned(AXI_28_ARADDR);
  --   hbm_read_in_pkgs_stack_1(12).arid          <= AXI_28_ARID;
  --   hbm_read_in_pkgs_stack_1(12).arlen         <= AXI_28_ARLEN;
  --   hbm_read_in_pkgs_stack_1(12).arvalid       <= AXI_28_ARVALID;
  --   hbm_read_in_pkgs_stack_1(12).rready        <= AXI_28_RREADY;
  --   AXI_28_ARREADY                             <= hbm_read_out_pkgs_stack_1(12).arready;
  --   AXI_28_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_1(12).rdata_parity;
  --   AXI_28_RDATA                               <= hbm_read_out_pkgs_stack_1(12).rdata;
  --   AXI_28_RID                                 <= hbm_read_out_pkgs_stack_1(12).rid;
  --   AXI_28_RLAST                               <= hbm_read_out_pkgs_stack_1(12).rlast;
  --   AXI_28_RRESP                               <= hbm_read_out_pkgs_stack_1(12).rresp;
  --   AXI_28_RVALID                              <= hbm_read_out_pkgs_stack_1(12).rvalid;
  --   AXI_28_AWREADY                             <= hbm_write_out_pkgs_stack_1(12).awready;
  --   AXI_28_WREADY                              <= hbm_write_out_pkgs_stack_1(12).wready;
  --   AXI_28_BID                                 <= hbm_write_out_pkgs_stack_1(12).bid;
  --   AXI_28_BRESP                               <= hbm_write_out_pkgs_stack_1(12).bresp;
  --   AXI_28_BVALID                              <= hbm_write_out_pkgs_stack_1(12).bvalid;

  --   hbm_write_in_pkgs_stack_1(13).awid         <= AXI_29_AWID;
  --   hbm_write_in_pkgs_stack_1(13).awlen        <= AXI_29_AWLEN;
  --   hbm_write_in_pkgs_stack_1(13).awvalid      <= AXI_29_AWVALID;
  --   hbm_write_in_pkgs_stack_1(13).awaddr       <= unsigned(AXI_29_AWADDR);
  --   hbm_write_in_pkgs_stack_1(13).bready       <= AXI_29_BREADY;
  --   hbm_write_in_pkgs_stack_1(13).wdata        <= AXI_29_WDATA;
  --   hbm_write_in_pkgs_stack_1(13).wlast        <= AXI_29_WLAST;
  --   hbm_write_in_pkgs_stack_1(13).wdata_parity <= AXI_29_WDATA_PARITY;
  --   hbm_write_in_pkgs_stack_1(13).wvalid       <= AXI_29_WVALID;
  --   hbm_read_in_pkgs_stack_1(13).araddr        <= unsigned(AXI_29_ARADDR);
  --   hbm_read_in_pkgs_stack_1(13).arid          <= AXI_29_ARID;
  --   hbm_read_in_pkgs_stack_1(13).arlen         <= AXI_29_ARLEN;
  --   hbm_read_in_pkgs_stack_1(13).arvalid       <= AXI_29_ARVALID;
  --   hbm_read_in_pkgs_stack_1(13).rready        <= AXI_29_RREADY;
  --   AXI_29_ARREADY                             <= hbm_read_out_pkgs_stack_1(13).arready;
  --   AXI_29_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_1(13).rdata_parity;
  --   AXI_29_RDATA                               <= hbm_read_out_pkgs_stack_1(13).rdata;
  --   AXI_29_RID                                 <= hbm_read_out_pkgs_stack_1(13).rid;
  --   AXI_29_RLAST                               <= hbm_read_out_pkgs_stack_1(13).rlast;
  --   AXI_29_RRESP                               <= hbm_read_out_pkgs_stack_1(13).rresp;
  --   AXI_29_RVALID                              <= hbm_read_out_pkgs_stack_1(13).rvalid;
  --   AXI_29_AWREADY                             <= hbm_write_out_pkgs_stack_1(13).awready;
  --   AXI_29_WREADY                              <= hbm_write_out_pkgs_stack_1(13).wready;
  --   AXI_29_BID                                 <= hbm_write_out_pkgs_stack_1(13).bid;
  --   AXI_29_BRESP                               <= hbm_write_out_pkgs_stack_1(13).bresp;
  --   AXI_29_BVALID                              <= hbm_write_out_pkgs_stack_1(13).bvalid;

  --   hbm_write_in_pkgs_stack_1(14).awid         <= AXI_30_AWID;
  --   hbm_write_in_pkgs_stack_1(14).awlen        <= AXI_30_AWLEN;
  --   hbm_write_in_pkgs_stack_1(14).awvalid      <= AXI_30_AWVALID;
  --   hbm_write_in_pkgs_stack_1(14).awaddr       <= unsigned(AXI_30_AWADDR);
  --   hbm_write_in_pkgs_stack_1(14).bready       <= AXI_30_BREADY;
  --   hbm_write_in_pkgs_stack_1(14).wdata        <= AXI_30_WDATA;
  --   hbm_write_in_pkgs_stack_1(14).wlast        <= AXI_30_WLAST;
  --   hbm_write_in_pkgs_stack_1(14).wdata_parity <= AXI_30_WDATA_PARITY;
  --   hbm_write_in_pkgs_stack_1(14).wvalid       <= AXI_30_WVALID;
  --   hbm_read_in_pkgs_stack_1(14).araddr        <= unsigned(AXI_30_ARADDR);
  --   hbm_read_in_pkgs_stack_1(14).arid          <= AXI_30_ARID;
  --   hbm_read_in_pkgs_stack_1(14).arlen         <= AXI_30_ARLEN;
  --   hbm_read_in_pkgs_stack_1(14).arvalid       <= AXI_30_ARVALID;
  --   hbm_read_in_pkgs_stack_1(14).rready        <= AXI_30_RREADY;
  --   AXI_30_ARREADY                             <= hbm_read_out_pkgs_stack_1(14).arready;
  --   AXI_30_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_1(14).rdata_parity;
  --   AXI_30_RDATA                               <= hbm_read_out_pkgs_stack_1(14).rdata;
  --   AXI_30_RID                                 <= hbm_read_out_pkgs_stack_1(14).rid;
  --   AXI_30_RLAST                               <= hbm_read_out_pkgs_stack_1(14).rlast;
  --   AXI_30_RRESP                               <= hbm_read_out_pkgs_stack_1(14).rresp;
  --   AXI_30_RVALID                              <= hbm_read_out_pkgs_stack_1(14).rvalid;
  --   AXI_30_AWREADY                             <= hbm_write_out_pkgs_stack_1(14).awready;
  --   AXI_30_WREADY                              <= hbm_write_out_pkgs_stack_1(14).wready;
  --   AXI_30_BID                                 <= hbm_write_out_pkgs_stack_1(14).bid;
  --   AXI_30_BRESP                               <= hbm_write_out_pkgs_stack_1(14).bresp;
  --   AXI_30_BVALID                              <= hbm_write_out_pkgs_stack_1(14).bvalid;

  --   hbm_write_in_pkgs_stack_1(15).awid         <= AXI_31_AWID;
  --   hbm_write_in_pkgs_stack_1(15).awlen        <= AXI_31_AWLEN;
  --   hbm_write_in_pkgs_stack_1(15).awvalid      <= AXI_31_AWVALID;
  --   hbm_write_in_pkgs_stack_1(15).awaddr       <= unsigned(AXI_31_AWADDR);
  --   hbm_write_in_pkgs_stack_1(15).bready       <= AXI_31_BREADY;
  --   hbm_write_in_pkgs_stack_1(15).wdata        <= AXI_31_WDATA;
  --   hbm_write_in_pkgs_stack_1(15).wlast        <= AXI_31_WLAST;
  --   hbm_write_in_pkgs_stack_1(15).wdata_parity <= AXI_31_WDATA_PARITY;
  --   hbm_write_in_pkgs_stack_1(15).wvalid       <= AXI_31_WVALID;
  --   hbm_read_in_pkgs_stack_1(15).araddr        <= unsigned(AXI_31_ARADDR);
  --   hbm_read_in_pkgs_stack_1(15).arid          <= AXI_31_ARID;
  --   hbm_read_in_pkgs_stack_1(15).arlen         <= AXI_31_ARLEN;
  --   hbm_read_in_pkgs_stack_1(15).arvalid       <= AXI_31_ARVALID;
  --   hbm_read_in_pkgs_stack_1(15).rready        <= AXI_31_RREADY;
  --   AXI_31_ARREADY                             <= hbm_read_out_pkgs_stack_1(15).arready;
  --   AXI_31_RDATA_PARITY                        <= hbm_read_out_pkgs_stack_1(15).rdata_parity;
  --   AXI_31_RDATA                               <= hbm_read_out_pkgs_stack_1(15).rdata;
  --   AXI_31_RID                                 <= hbm_read_out_pkgs_stack_1(15).rid;
  --   AXI_31_RLAST                               <= hbm_read_out_pkgs_stack_1(15).rlast;
  --   AXI_31_RRESP                               <= hbm_read_out_pkgs_stack_1(15).rresp;
  --   AXI_31_RVALID                              <= hbm_read_out_pkgs_stack_1(15).rvalid;
  --   AXI_31_AWREADY                             <= hbm_write_out_pkgs_stack_1(15).awready;
  --   AXI_31_WREADY                              <= hbm_write_out_pkgs_stack_1(15).wready;
  --   AXI_31_BID                                 <= hbm_write_out_pkgs_stack_1(15).bid;
  --   AXI_31_BRESP                               <= hbm_write_out_pkgs_stack_1(15).bresp;
  --   AXI_31_BVALID                              <= hbm_write_out_pkgs_stack_1(15).bvalid;
end architecture;
