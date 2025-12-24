
`timescale 1 ns / 1 ps

	module tfhe_w #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 6,

		// Parameters of Axi Master Bus Interface M00_AXI
		parameter  C_M00_AXI_TARGET_SLAVE_BASE_ADDR	= 64'h40000000,
		parameter integer C_M00_AXI_BURST_LEN	= 16,
		parameter integer C_M00_AXI_ID_WIDTH	= 1,
		parameter integer C_M00_AXI_ADDR_WIDTH	= 64,
		parameter integer C_M00_AXI_DATA_WIDTH	= 256,
		parameter integer C_M00_AXI_AWUSER_WIDTH	= 0,
		parameter integer C_M00_AXI_ARUSER_WIDTH	= 0,
		parameter integer C_M00_AXI_WUSER_WIDTH	= 0,
		parameter integer C_M00_AXI_RUSER_WIDTH	= 0,
		parameter integer C_M00_AXI_BUSER_WIDTH	= 0,

		// ============================================================
		// Minimal parameters required by hbm_wrapper_hbm ports
		// (translated from ip_cores_constants.vhd)
		// ============================================================

		// ---------------- HBM topology ----------------
		parameter integer HBM_STACK_NUM_PS_PORTS = 16,

		// ---------------- HBM data path ----------------
		parameter integer  UNSIGNED_POLYM_COEFFICIENT_BIT_WIDTH = 64,
		parameter integer UNSIGNED_POLYM_COEFF_W = UNSIGNED_POLYM_COEFFICIENT_BIT_WIDTH,

		parameter integer HBM_COEFFS_PER_CLK_PER_PS_PORT = 4,
		parameter integer HBM_DATA_WIDTH = HBM_COEFFS_PER_CLK_PER_PS_PORT * UNSIGNED_POLYM_COEFF_W,

		parameter integer HBM_BYTES_PER_PS_PORT = HBM_DATA_WIDTH / 8,

		// ---------------- Addressing ----------------
		// Forced to 64 in VHDL (explicit override)
		parameter integer HBM_ADDR_WIDTH = 64,

		// ---------------- AXI burst fields ----------------
		parameter integer HBM_BURSTMODE_BIT_WIDTH = 2,
		parameter integer HBM_BURSTSIZE_BIT_WIDTH = 3,
		parameter integer HBM_BURSTLEN_BIT_WIDTH  = 4,

		// ---------------- AXI response / ID ----------------
		parameter integer HBM_RESP_BIT_WIDTH = 2,

		// get_bit_length(64 - 1) = 6
		parameter integer HBM_ID_BIT_WIDTH = 6,

		// ---------------- Flattened TFHE package widths ----------------
		// These must match how you flatten the VHDL records
		parameter integer HBM_PS_IN_WRITE_PKG_W  = HBM_DATA_WIDTH,
		parameter integer HBM_PS_IN_READ_PKG_W   = HBM_DATA_WIDTH,
		parameter integer HBM_PS_OUT_WRITE_PKG_W = HBM_DATA_WIDTH,
		parameter integer HBM_PS_OUT_READ_PKG_W  = HBM_DATA_WIDTH 

	)
	(
		// Users to add ports here
		input wire  TFHE_CLK,
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready,


		// --------------------------------------------------
		// HBM AXI interface
		// --------------------------------------------------
		input  wire                         HBM_REF_CLK_0,

		// --------------------------------------------------
        // AXI_00
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_00_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_00_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_00_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_00_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_00_ARSIZE,
        input  wire                         AXI_00_ARVALID,
        output wire                         AXI_00_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_00_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_00_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_00_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_00_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_00_AWSIZE,
        input  wire                         AXI_00_AWVALID,
        output wire                         AXI_00_AWREADY,

        input  wire                         AXI_00_RREADY,
        input  wire                         AXI_00_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_00_WDATA,
        input  wire                         AXI_00_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_00_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_00_WDATA_PARITY,
        input  wire                         AXI_00_WVALID,
        output wire                         AXI_00_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_00_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_00_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_00_RID,
        output wire                         AXI_00_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_00_RRESP,
        output wire                         AXI_00_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_00_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_00_BRESP,
        output wire                         AXI_00_BVALID,
    

        // --------------------------------------------------
        // AXI_01
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_01_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_01_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_01_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_01_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_01_ARSIZE,
        input  wire                         AXI_01_ARVALID,
        output wire                         AXI_01_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_01_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_01_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_01_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_01_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_01_AWSIZE,
        input  wire                         AXI_01_AWVALID,
        output wire                         AXI_01_AWREADY,

        input  wire                         AXI_01_RREADY,
        input  wire                         AXI_01_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_01_WDATA,
        input  wire                         AXI_01_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_01_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_01_WDATA_PARITY,
        input  wire                         AXI_01_WVALID,
        output wire                         AXI_01_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_01_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_01_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_01_RID,
        output wire                         AXI_01_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_01_RRESP,
        output wire                         AXI_01_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_01_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_01_BRESP,
        output wire                         AXI_01_BVALID,
    

        // --------------------------------------------------
        // AXI_02
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_02_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_02_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_02_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_02_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_02_ARSIZE,
        input  wire                         AXI_02_ARVALID,
        output wire                         AXI_02_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_02_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_02_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_02_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_02_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_02_AWSIZE,
        input  wire                         AXI_02_AWVALID,
        output wire                         AXI_02_AWREADY,

        input  wire                         AXI_02_RREADY,
        input  wire                         AXI_02_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_02_WDATA,
        input  wire                         AXI_02_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_02_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_02_WDATA_PARITY,
        input  wire                         AXI_02_WVALID,
        output wire                         AXI_02_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_02_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_02_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_02_RID,
        output wire                         AXI_02_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_02_RRESP,
        output wire                         AXI_02_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_02_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_02_BRESP,
        output wire                         AXI_02_BVALID,
    

        // --------------------------------------------------
        // AXI_03
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_03_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_03_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_03_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_03_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_03_ARSIZE,
        input  wire                         AXI_03_ARVALID,
        output wire                         AXI_03_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_03_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_03_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_03_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_03_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_03_AWSIZE,
        input  wire                         AXI_03_AWVALID,
        output wire                         AXI_03_AWREADY,

        input  wire                         AXI_03_RREADY,
        input  wire                         AXI_03_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_03_WDATA,
        input  wire                         AXI_03_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_03_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_03_WDATA_PARITY,
        input  wire                         AXI_03_WVALID,
        output wire                         AXI_03_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_03_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_03_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_03_RID,
        output wire                         AXI_03_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_03_RRESP,
        output wire                         AXI_03_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_03_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_03_BRESP,
        output wire                         AXI_03_BVALID,
    

        // --------------------------------------------------
        // AXI_04
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_04_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_04_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_04_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_04_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_04_ARSIZE,
        input  wire                         AXI_04_ARVALID,
        output wire                         AXI_04_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_04_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_04_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_04_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_04_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_04_AWSIZE,
        input  wire                         AXI_04_AWVALID,
        output wire                         AXI_04_AWREADY,

        input  wire                         AXI_04_RREADY,
        input  wire                         AXI_04_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_04_WDATA,
        input  wire                         AXI_04_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_04_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_04_WDATA_PARITY,
        input  wire                         AXI_04_WVALID,
        output wire                         AXI_04_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_04_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_04_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_04_RID,
        output wire                         AXI_04_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_04_RRESP,
        output wire                         AXI_04_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_04_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_04_BRESP,
        output wire                         AXI_04_BVALID,
    

        // --------------------------------------------------
        // AXI_05
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_05_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_05_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_05_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_05_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_05_ARSIZE,
        input  wire                         AXI_05_ARVALID,
        output wire                         AXI_05_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_05_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_05_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_05_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_05_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_05_AWSIZE,
        input  wire                         AXI_05_AWVALID,
        output wire                         AXI_05_AWREADY,

        input  wire                         AXI_05_RREADY,
        input  wire                         AXI_05_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_05_WDATA,
        input  wire                         AXI_05_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_05_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_05_WDATA_PARITY,
        input  wire                         AXI_05_WVALID,
        output wire                         AXI_05_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_05_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_05_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_05_RID,
        output wire                         AXI_05_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_05_RRESP,
        output wire                         AXI_05_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_05_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_05_BRESP,
        output wire                         AXI_05_BVALID,
    

        // --------------------------------------------------
        // AXI_06
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_06_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_06_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_06_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_06_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_06_ARSIZE,
        input  wire                         AXI_06_ARVALID,
        output wire                         AXI_06_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_06_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_06_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_06_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_06_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_06_AWSIZE,
        input  wire                         AXI_06_AWVALID,
        output wire                         AXI_06_AWREADY,

        input  wire                         AXI_06_RREADY,
        input  wire                         AXI_06_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_06_WDATA,
        input  wire                         AXI_06_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_06_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_06_WDATA_PARITY,
        input  wire                         AXI_06_WVALID,
        output wire                         AXI_06_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_06_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_06_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_06_RID,
        output wire                         AXI_06_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_06_RRESP,
        output wire                         AXI_06_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_06_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_06_BRESP,
        output wire                         AXI_06_BVALID,
    

        // --------------------------------------------------
        // AXI_07
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_07_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_07_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_07_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_07_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_07_ARSIZE,
        input  wire                         AXI_07_ARVALID,
        output wire                         AXI_07_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_07_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_07_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_07_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_07_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_07_AWSIZE,
        input  wire                         AXI_07_AWVALID,
        output wire                         AXI_07_AWREADY,

        input  wire                         AXI_07_RREADY,
        input  wire                         AXI_07_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_07_WDATA,
        input  wire                         AXI_07_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_07_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_07_WDATA_PARITY,
        input  wire                         AXI_07_WVALID,
        output wire                         AXI_07_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_07_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_07_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_07_RID,
        output wire                         AXI_07_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_07_RRESP,
        output wire                         AXI_07_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_07_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_07_BRESP,
        output wire                         AXI_07_BVALID,
    

        // --------------------------------------------------
        // AXI_08
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_08_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_08_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_08_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_08_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_08_ARSIZE,
        input  wire                         AXI_08_ARVALID,
        output wire                         AXI_08_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_08_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_08_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_08_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_08_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_08_AWSIZE,
        input  wire                         AXI_08_AWVALID,
        output wire                         AXI_08_AWREADY,

        input  wire                         AXI_08_RREADY,
        input  wire                         AXI_08_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_08_WDATA,
        input  wire                         AXI_08_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_08_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_08_WDATA_PARITY,
        input  wire                         AXI_08_WVALID,
        output wire                         AXI_08_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_08_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_08_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_08_RID,
        output wire                         AXI_08_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_08_RRESP,
        output wire                         AXI_08_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_08_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_08_BRESP,
        output wire                         AXI_08_BVALID,
    

        // --------------------------------------------------
        // AXI_09
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_09_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_09_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_09_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_09_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_09_ARSIZE,
        input  wire                         AXI_09_ARVALID,
        output wire                         AXI_09_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_09_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_09_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_09_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_09_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_09_AWSIZE,
        input  wire                         AXI_09_AWVALID,
        output wire                         AXI_09_AWREADY,

        input  wire                         AXI_09_RREADY,
        input  wire                         AXI_09_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_09_WDATA,
        input  wire                         AXI_09_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_09_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_09_WDATA_PARITY,
        input  wire                         AXI_09_WVALID,
        output wire                         AXI_09_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_09_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_09_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_09_RID,
        output wire                         AXI_09_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_09_RRESP,
        output wire                         AXI_09_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_09_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_09_BRESP,
        output wire                         AXI_09_BVALID,
    

        // --------------------------------------------------
        // AXI_10
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_10_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_10_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_10_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_10_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_10_ARSIZE,
        input  wire                         AXI_10_ARVALID,
        output wire                         AXI_10_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_10_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_10_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_10_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_10_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_10_AWSIZE,
        input  wire                         AXI_10_AWVALID,
        output wire                         AXI_10_AWREADY,

        input  wire                         AXI_10_RREADY,
        input  wire                         AXI_10_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_10_WDATA,
        input  wire                         AXI_10_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_10_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_10_WDATA_PARITY,
        input  wire                         AXI_10_WVALID,
        output wire                         AXI_10_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_10_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_10_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_10_RID,
        output wire                         AXI_10_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_10_RRESP,
        output wire                         AXI_10_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_10_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_10_BRESP,
        output wire                         AXI_10_BVALID,
    

        // --------------------------------------------------
        // AXI_11
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_11_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_11_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_11_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_11_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_11_ARSIZE,
        input  wire                         AXI_11_ARVALID,
        output wire                         AXI_11_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_11_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_11_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_11_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_11_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_11_AWSIZE,
        input  wire                         AXI_11_AWVALID,
        output wire                         AXI_11_AWREADY,

        input  wire                         AXI_11_RREADY,
        input  wire                         AXI_11_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_11_WDATA,
        input  wire                         AXI_11_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_11_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_11_WDATA_PARITY,
        input  wire                         AXI_11_WVALID,
        output wire                         AXI_11_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_11_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_11_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_11_RID,
        output wire                         AXI_11_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_11_RRESP,
        output wire                         AXI_11_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_11_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_11_BRESP,
        output wire                         AXI_11_BVALID,
    

        // --------------------------------------------------
        // AXI_12
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_12_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_12_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_12_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_12_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_12_ARSIZE,
        input  wire                         AXI_12_ARVALID,
        output wire                         AXI_12_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_12_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_12_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_12_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_12_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_12_AWSIZE,
        input  wire                         AXI_12_AWVALID,
        output wire                         AXI_12_AWREADY,

        input  wire                         AXI_12_RREADY,
        input  wire                         AXI_12_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_12_WDATA,
        input  wire                         AXI_12_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_12_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_12_WDATA_PARITY,
        input  wire                         AXI_12_WVALID,
        output wire                         AXI_12_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_12_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_12_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_12_RID,
        output wire                         AXI_12_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_12_RRESP,
        output wire                         AXI_12_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_12_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_12_BRESP,
        output wire                         AXI_12_BVALID,
    

        // --------------------------------------------------
        // AXI_13
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_13_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_13_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_13_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_13_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_13_ARSIZE,
        input  wire                         AXI_13_ARVALID,
        output wire                         AXI_13_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_13_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_13_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_13_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_13_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_13_AWSIZE,
        input  wire                         AXI_13_AWVALID,
        output wire                         AXI_13_AWREADY,

        input  wire                         AXI_13_RREADY,
        input  wire                         AXI_13_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_13_WDATA,
        input  wire                         AXI_13_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_13_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_13_WDATA_PARITY,
        input  wire                         AXI_13_WVALID,
        output wire                         AXI_13_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_13_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_13_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_13_RID,
        output wire                         AXI_13_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_13_RRESP,
        output wire                         AXI_13_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_13_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_13_BRESP,
        output wire                         AXI_13_BVALID,
    

        // --------------------------------------------------
        // AXI_14
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_14_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_14_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_14_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_14_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_14_ARSIZE,
        input  wire                         AXI_14_ARVALID,
        output wire                         AXI_14_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_14_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_14_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_14_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_14_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_14_AWSIZE,
        input  wire                         AXI_14_AWVALID,
        output wire                         AXI_14_AWREADY,

        input  wire                         AXI_14_RREADY,
        input  wire                         AXI_14_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_14_WDATA,
        input  wire                         AXI_14_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_14_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_14_WDATA_PARITY,
        input  wire                         AXI_14_WVALID,
        output wire                         AXI_14_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_14_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_14_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_14_RID,
        output wire                         AXI_14_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_14_RRESP,
        output wire                         AXI_14_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_14_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_14_BRESP,
        output wire                         AXI_14_BVALID,
    

        // --------------------------------------------------
        // AXI_15
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_15_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_15_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_15_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_15_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_15_ARSIZE,
        input  wire                         AXI_15_ARVALID,
        output wire                         AXI_15_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]    AXI_15_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]   AXI_15_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]          AXI_15_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]    AXI_15_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]   AXI_15_AWSIZE,
        input  wire                         AXI_15_AWVALID,
        output wire                         AXI_15_AWREADY,

        input  wire                         AXI_15_RREADY,
        input  wire                         AXI_15_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]    AXI_15_WDATA,
        input  wire                         AXI_15_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_15_WSTRB,
        // input  wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_15_WDATA_PARITY,
        input  wire                         AXI_15_WVALID,
        output wire                         AXI_15_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]    AXI_15_RDATA,
        // output wire [HBM_BYTES_PER_PS_PORT-1:0]       AXI_15_RDATA_PARITY,
        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_15_RID,
        output wire                         AXI_15_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_15_RRESP,
        output wire                         AXI_15_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]          AXI_15_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]        AXI_15_BRESP,
        output wire                         AXI_15_BVALID,

		input  wire                         AXI_00_ACLK,
		input  wire                         AXI_01_ACLK,
		input  wire                         AXI_02_ACLK,
		input  wire                         AXI_03_ACLK,
		input  wire                         AXI_04_ACLK,
		input  wire                         AXI_05_ACLK,
		input  wire                         AXI_06_ACLK,
		input  wire                         AXI_07_ACLK,
		input  wire                         AXI_08_ACLK,
		input  wire                         AXI_09_ACLK,
		input  wire                         AXI_10_ACLK,
		input  wire                         AXI_11_ACLK,
		input  wire                         AXI_12_ACLK,
		input  wire                         AXI_13_ACLK,
		input  wire                         AXI_14_ACLK,
		input  wire                         AXI_15_ACLK,

		// input  wire                         ARESET_N,

		input  wire                         AXI_00_ARESET_N,
		input  wire                         AXI_01_ARESET_N,
		input  wire                         AXI_02_ARESET_N,
		input  wire                         AXI_03_ARESET_N,
		input  wire                         AXI_04_ARESET_N,
		input  wire                         AXI_05_ARESET_N,
		input  wire                         AXI_06_ARESET_N,
		input  wire                         AXI_07_ARESET_N,
		input  wire                         AXI_08_ARESET_N,
		input  wire                         AXI_09_ARESET_N,
		input  wire                         AXI_10_ARESET_N,
		input  wire                         AXI_11_ARESET_N,
		input  wire                         AXI_12_ARESET_N,
		input  wire                         AXI_13_ARESET_N,
		input  wire                         AXI_14_ARESET_N,
		input  wire                         AXI_15_ARESET_N,

		// --------------------------------------------------
		// APB / Status
		// --------------------------------------------------
		input  wire                         APB_0_PCLK,
		input  wire                         APB_0_PRESET_N,

		// TFHE processor LED output		
		output wire [7:0] user_led
	);


	// Controll data addresses
	wire [C_S00_AXI_DATA_WIDTH-1 : 0] host_wr_addr;
	wire [C_S00_AXI_DATA_WIDTH-1 : 0] host_wr_len;
	wire [C_S00_AXI_DATA_WIDTH-1 : 0] host_rd_addr;
	wire [C_S00_AXI_DATA_WIDTH-1 : 0] host_rd_len;

	wire pbs_busy;
	wire pbs_done;
	wire start_pbs;

// Instantiation of Axi Bus Interface S00_AXI
	tfhe_w_controller #(
 .C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
 .C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) tfhe_w_controller_inst (
	// --------------------------------------------------
	// AXI-Lite interface
	// --------------------------------------------------
	.S_AXI_ACLK    (s00_axi_aclk),
	.S_AXI_ARESETN(s00_axi_aresetn),

	.S_AXI_AWADDR (s00_axi_awaddr),
	.S_AXI_AWVALID(s00_axi_awvalid),
	.S_AXI_AWREADY(s00_axi_awready),

	.S_AXI_WDATA  (s00_axi_wdata),
	.S_AXI_WSTRB  (s00_axi_wstrb),
	.S_AXI_WVALID (s00_axi_wvalid),
	.S_AXI_WREADY (s00_axi_wready),

	.S_AXI_BRESP  (s00_axi_bresp),
	.S_AXI_BVALID (s00_axi_bvalid),
	.S_AXI_BREADY (s00_axi_bready),

	.S_AXI_ARADDR (s00_axi_araddr),
	.S_AXI_ARVALID(s00_axi_arvalid),
	.S_AXI_ARREADY(s00_axi_arready),

	.S_AXI_RDATA  (s00_axi_rdata),
	.S_AXI_RRESP  (s00_axi_rresp),
	.S_AXI_RVALID (s00_axi_rvalid),
	.S_AXI_RREADY (s00_axi_rready),

	// --------------------------------------------------
	// Controller to TFHE processor interface
	// --------------------------------------------------
	.host_wr_addr (host_wr_addr), // from the host
	.host_wr_len  (host_wr_len), // from the host
	.host_rd_addr (host_rd_addr), // from TFHE processor
	.host_rd_len  (host_rd_len),  // from TFHE processor

	.pbs_busy     (pbs_busy), //from the TFHE processor
	.pbs_done     (pbs_done), //from the TFHE processor
	.start_pbs    (start_pbs) //from the controller
	);



//// Instantiation of Axi Bus Interface M00_AXI
	tfhe_pu # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH)
	) tfhe_pu_inst (
		.clk(s00_axi_aclk),
		.reset_n(s00_axi_aresetn),
		
		.user_led(user_led),

		// --------------------------------------------------
		// Controller to TFHE processor interface
		// --------------------------------------------------
		.host_wr_addr (host_wr_addr), // from the host
		.host_wr_len  (host_wr_len), // from the host
		.host_rd_addr (host_rd_addr), // from TFHE processor
		.host_rd_len  (host_rd_len),  // from TFHE processor

		.pbs_busy     (pbs_busy), //from the TFHE processor
		.pbs_done     (pbs_done), //from the TFHE processor
		.start_pbs    (start_pbs) //from the controller

	);

	hbm_w u_hbm_w_int (
		// --------------------------------------------------
		// AXI select
		// --------------------------------------------------
		.i_axi_sel                 (1'b0), // Only HBM-AXI4 for now

		// --------------------------------------------------
		// Global signals
		// --------------------------------------------------
		// .RESET_N                 (RESET_N),


		// --------------------------------------------------
		// High-throughput TFHE interface
		// // --------------------------------------------------
		// .i_write_pkgs              (i_write_pkgs),
		// .i_read_pkgs               (i_read_pkgs),
		// .o_write_pkgs              (o_write_pkgs),
		// .o_read_pkgs               (o_read_pkgs),
		// .o_initial_init_ready      (o_initial_init_ready),
		.TFHE_CLK				  (TFHE_CLK),

		// --------------------------------------------------
		// External AXI master – common
		// --------------------------------------------------
		.HBM_REF_CLK_0              (HBM_REF_CLK_0),

		.AXI_00_ACLK				(AXI_00_ACLK),
		.AXI_01_ACLK				(AXI_01_ACLK),
		.AXI_02_ACLK				(AXI_02_ACLK),	
		.AXI_03_ACLK				(AXI_03_ACLK),
		.AXI_04_ACLK				(AXI_04_ACLK),
		.AXI_05_ACLK				(AXI_05_ACLK),
		.AXI_06_ACLK				(AXI_06_ACLK),
		.AXI_07_ACLK				(AXI_07_ACLK),
		.AXI_08_ACLK				(AXI_08_ACLK),
		.AXI_09_ACLK				(AXI_09_ACLK),
		.AXI_10_ACLK				(AXI_10_ACLK),
		.AXI_11_ACLK				(AXI_11_ACLK),
		.AXI_12_ACLK				(AXI_12_ACLK),
		.AXI_13_ACLK				(AXI_13_ACLK),
		.AXI_14_ACLK				(AXI_14_ACLK),
		.AXI_15_ACLK				(AXI_15_ACLK),

		.AXI_00_ARESET_N			(AXI_00_ARESET_N),
		.AXI_01_ARESET_N			(AXI_01_ARESET_N),
		.AXI_02_ARESET_N			(AXI_02_ARESET_N),
		.AXI_03_ARESET_N			(AXI_03_ARESET_N),
		.AXI_04_ARESET_N			(AXI_04_ARESET_N),
		.AXI_05_ARESET_N			(AXI_05_ARESET_N),
		.AXI_06_ARESET_N			(AXI_06_ARESET_N),
		.AXI_07_ARESET_N			(AXI_07_ARESET_N),
		.AXI_08_ARESET_N			(AXI_08_ARESET_N),
		.AXI_09_ARESET_N			(AXI_09_ARESET_N),
		.AXI_10_ARESET_N			(AXI_10_ARESET_N),
		.AXI_11_ARESET_N			(AXI_11_ARESET_N),
		.AXI_12_ARESET_N			(AXI_12_ARESET_N),
		.AXI_13_ARESET_N			(AXI_13_ARESET_N),
		.AXI_14_ARESET_N			(AXI_14_ARESET_N),
		.AXI_15_ARESET_N			(AXI_15_ARESET_N),

		// --------------------------------------------------
		// AXI_00
		// --------------------------------------------------
		.AXI_00_ARADDR              (AXI_00_ARADDR),
		.AXI_00_ARBURST             (AXI_00_ARBURST),
		.AXI_00_ARID                (AXI_00_ARID),
		.AXI_00_ARLEN               (AXI_00_ARLEN),
		.AXI_00_ARSIZE              (AXI_00_ARSIZE),
		.AXI_00_ARVALID             (AXI_00_ARVALID),
		.AXI_00_ARREADY             (AXI_00_ARREADY),

		.AXI_00_AWADDR              (AXI_00_AWADDR),
		.AXI_00_AWBURST             (AXI_00_AWBURST),
		.AXI_00_AWID                (AXI_00_AWID),
		.AXI_00_AWLEN               (AXI_00_AWLEN),
		.AXI_00_AWSIZE              (AXI_00_AWSIZE),
		.AXI_00_AWVALID             (AXI_00_AWVALID),
		.AXI_00_AWREADY             (AXI_00_AWREADY),

		.AXI_00_RREADY              (AXI_00_RREADY),
		.AXI_00_BREADY              (AXI_00_BREADY),

		.AXI_00_WDATA               (AXI_00_WDATA),
		.AXI_00_WLAST               (AXI_00_WLAST),
		.AXI_00_WSTRB               (AXI_00_WSTRB),
		.AXI_00_WDATA_PARITY        (),
		.AXI_00_WVALID              (AXI_00_WVALID),
		.AXI_00_WREADY              (AXI_00_WREADY),

		.AXI_00_RDATA               (AXI_00_RDATA),
		.AXI_00_RDATA_PARITY        (),
		.AXI_00_RID                 (AXI_00_RID),
		.AXI_00_RLAST               (AXI_00_RLAST),
		.AXI_00_RRESP               (AXI_00_RRESP),
		.AXI_00_RVALID              (AXI_00_RVALID),

		.AXI_00_BID                 (AXI_00_BID),
		.AXI_00_BRESP               (AXI_00_BRESP),
		.AXI_00_BVALID              (AXI_00_BVALID),

		// --------------------------------------------------
		// AXI_01
		// --------------------------------------------------
		.AXI_01_ARADDR              (AXI_01_ARADDR),
		.AXI_01_ARBURST             (AXI_01_ARBURST),
		.AXI_01_ARID                (AXI_01_ARID),
		.AXI_01_ARLEN               (AXI_01_ARLEN),
		.AXI_01_ARSIZE              (AXI_01_ARSIZE),
		.AXI_01_ARVALID             (AXI_01_ARVALID),
		.AXI_01_ARREADY             (AXI_01_ARREADY),

		.AXI_01_AWADDR              (AXI_01_AWADDR),
		.AXI_01_AWBURST             (AXI_01_AWBURST),
		.AXI_01_AWID                (AXI_01_AWID),
		.AXI_01_AWLEN               (AXI_01_AWLEN),
		.AXI_01_AWSIZE              (AXI_01_AWSIZE),
		.AXI_01_AWVALID             (AXI_01_AWVALID),
		.AXI_01_AWREADY             (AXI_01_AWREADY),

		.AXI_01_RREADY              (AXI_01_RREADY),
		.AXI_01_BREADY              (AXI_01_BREADY),

		.AXI_01_WDATA               (AXI_01_WDATA),
		.AXI_01_WLAST               (AXI_01_WLAST),
		.AXI_01_WSTRB               (AXI_01_WSTRB),
		.AXI_01_WDATA_PARITY        (),
		.AXI_01_WVALID              (AXI_01_WVALID),
		.AXI_01_WREADY              (AXI_01_WREADY),

		.AXI_01_RDATA               (AXI_01_RDATA),
		.AXI_01_RDATA_PARITY        (AXI_01_RDATA_PARITY),
		.AXI_01_RID                 (AXI_01_RID),
		.AXI_01_RLAST               (AXI_01_RLAST),
		.AXI_01_RRESP               (AXI_01_RRESP),
		.AXI_01_RVALID              (AXI_01_RVALID),

		.AXI_01_BID                 (AXI_01_BID),
		.AXI_01_BRESP               (AXI_01_BRESP),
		.AXI_01_BVALID              (AXI_01_BVALID),


		// --------------------------------------------------
		// AXI_02
		// --------------------------------------------------
		.AXI_02_ARADDR              (AXI_02_ARADDR),
		.AXI_02_ARBURST             (AXI_02_ARBURST),
		.AXI_02_ARID                (AXI_02_ARID),
		.AXI_02_ARLEN               (AXI_02_ARLEN),
		.AXI_02_ARSIZE              (AXI_02_ARSIZE),
		.AXI_02_ARVALID             (AXI_02_ARVALID),
		.AXI_02_ARREADY             (AXI_02_ARREADY),

		.AXI_02_AWADDR              (AXI_02_AWADDR),
		.AXI_02_AWBURST             (AXI_02_AWBURST),
		.AXI_02_AWID                (AXI_02_AWID),
		.AXI_02_AWLEN               (AXI_02_AWLEN),
		.AXI_02_AWSIZE              (AXI_02_AWSIZE),
		.AXI_02_AWVALID             (AXI_02_AWVALID),
		.AXI_02_AWREADY             (AXI_02_AWREADY),

		.AXI_02_RREADY              (AXI_02_RREADY),
		.AXI_02_BREADY              (AXI_02_BREADY),

		.AXI_02_WDATA               (AXI_02_WDATA),
		.AXI_02_WLAST               (AXI_02_WLAST),
		.AXI_02_WSTRB               (AXI_02_WSTRB),
		.AXI_02_WDATA_PARITY        (),
		.AXI_02_WVALID              (AXI_02_WVALID),
		.AXI_02_WREADY              (AXI_02_WREADY),

		.AXI_02_RDATA               (AXI_02_RDATA),
		.AXI_02_RDATA_PARITY        (AXI_02_RDATA_PARITY),
		.AXI_02_RID                 (AXI_02_RID),
		.AXI_02_RLAST               (AXI_02_RLAST),
		.AXI_02_RRESP               (AXI_02_RRESP),
		.AXI_02_RVALID              (AXI_02_RVALID),

		.AXI_02_BID                 (AXI_02_BID),
		.AXI_02_BRESP               (AXI_02_BRESP),
		.AXI_02_BVALID              (AXI_02_BVALID),

		// --------------------------------------------------
		// AXI_03
		// --------------------------------------------------
		.AXI_03_ARADDR              (AXI_03_ARADDR),
		.AXI_03_ARBURST             (AXI_03_ARBURST),
		.AXI_03_ARID                (AXI_03_ARID),
		.AXI_03_ARLEN               (AXI_03_ARLEN),
		.AXI_03_ARSIZE              (AXI_03_ARSIZE),
		.AXI_03_ARVALID             (AXI_03_ARVALID),
		.AXI_03_ARREADY             (AXI_03_ARREADY),

		.AXI_03_AWADDR              (AXI_03_AWADDR),
		.AXI_03_AWBURST             (AXI_03_AWBURST),
		.AXI_03_AWID                (AXI_03_AWID),
		.AXI_03_AWLEN               (AXI_03_AWLEN),
		.AXI_03_AWSIZE              (AXI_03_AWSIZE),
		.AXI_03_AWVALID             (AXI_03_AWVALID),
		.AXI_03_AWREADY             (AXI_03_AWREADY),
		.AXI_03_RREADY              (AXI_03_RREADY),
		.AXI_03_BREADY              (AXI_03_BREADY),

		.AXI_03_WDATA               (AXI_03_WDATA),
		.AXI_03_WLAST               (AXI_03_WLAST),
		.AXI_03_WSTRB               (AXI_03_WSTRB),
		.AXI_03_WDATA_PARITY        (),
		.AXI_03_WVALID              (AXI_03_WVALID),
		.AXI_03_WREADY              (AXI_03_WREADY),

		.AXI_03_RDATA               (AXI_03_RDATA),
		.AXI_03_RDATA_PARITY        (AXI_03_RDATA_PARITY),
		.AXI_03_RID                 (AXI_03_RID),
		.AXI_03_RLAST               (AXI_03_RLAST),
		.AXI_03_RRESP               (AXI_03_RRESP),
		.AXI_03_RVALID              (AXI_03_RVALID),

		.AXI_03_BID                 (AXI_03_BID),
		.AXI_03_BRESP               (AXI_03_BRESP),
		.AXI_03_BVALID              (AXI_03_BVALID),


		// --------------------------------------------------
		// AXI_05
		// --------------------------------------------------
		.AXI_05_ARADDR              (AXI_05_ARADDR),
		.AXI_05_ARBURST             (AXI_05_ARBURST),
		.AXI_05_ARID                (AXI_05_ARID),
		.AXI_05_ARLEN               (AXI_05_ARLEN),
		.AXI_05_ARSIZE              (AXI_05_ARSIZE),
		.AXI_05_ARVALID             (AXI_05_ARVALID),
		.AXI_05_ARREADY             (AXI_05_ARREADY),

		.AXI_05_AWADDR              (AXI_05_AWADDR),
		.AXI_05_AWBURST             (AXI_05_AWBURST),
		.AXI_05_AWID                (AXI_05_AWID),
		.AXI_05_AWLEN               (AXI_05_AWLEN),
		.AXI_05_AWSIZE              (AXI_05_AWSIZE),
		.AXI_05_AWVALID             (AXI_05_AWVALID),
		.AXI_05_AWREADY             (AXI_05_AWREADY),

		.AXI_05_RREADY              (AXI_05_RREADY),
		.AXI_05_BREADY              (AXI_05_BREADY),

		.AXI_05_WDATA               (AXI_05_WDATA),
		.AXI_05_WLAST               (AXI_05_WLAST),
		.AXI_05_WSTRB               (AXI_05_WSTRB),
		.AXI_05_WDATA_PARITY        (),
		.AXI_05_WVALID              (AXI_05_WVALID),
		.AXI_05_WREADY              (AXI_05_WREADY),

		.AXI_05_RDATA               (AXI_05_RDATA),
		.AXI_05_RDATA_PARITY        (AXI_05_RDATA_PARITY),
		.AXI_05_RID                 (AXI_05_RID),
		.AXI_05_RLAST               (AXI_05_RLAST),
		.AXI_05_RRESP               (AXI_05_RRESP),
		.AXI_05_RVALID              (AXI_05_RVALID),

		.AXI_05_BID                 (AXI_05_BID),
		.AXI_05_BRESP               (AXI_05_BRESP),
		.AXI_05_BVALID              (AXI_05_BVALID),

		// --------------------------------------------------
		// AXI_06
		// --------------------------------------------------
		.AXI_06_ARADDR              (AXI_06_ARADDR),
		.AXI_06_ARBURST             (AXI_06_ARBURST),
		.AXI_06_ARID                (AXI_06_ARID),
		.AXI_06_ARLEN               (AXI_06_ARLEN),
		.AXI_06_ARSIZE              (AXI_06_ARSIZE),
		.AXI_06_ARVALID             (AXI_06_ARVALID),
		.AXI_06_ARREADY             (AXI_06_ARREADY),

		.AXI_06_AWADDR              (AXI_06_AWADDR),
		.AXI_06_AWBURST             (AXI_06_AWBURST),
		.AXI_06_AWID                (AXI_06_AWID),
		.AXI_06_AWLEN               (AXI_06_AWLEN),
		.AXI_06_AWSIZE              (AXI_06_AWSIZE),
		.AXI_06_AWVALID             (AXI_06_AWVALID),
		.AXI_06_AWREADY             (AXI_06_AWREADY),

		.AXI_06_RREADY              (AXI_06_RREADY),
		.AXI_06_BREADY              (AXI_06_BREADY),

		.AXI_06_WDATA               (AXI_06_WDATA),
		.AXI_06_WLAST               (AXI_06_WLAST),
		.AXI_06_WSTRB               (AXI_06_WSTRB),
		.AXI_06_WDATA_PARITY        (),
		.AXI_06_WVALID              (AXI_06_WVALID),
		.AXI_06_WREADY              (AXI_06_WREADY),

		.AXI_06_RDATA               (AXI_06_RDATA),
		.AXI_06_RDATA_PARITY        (AXI_06_RDATA_PARITY),
		.AXI_06_RID                 (AXI_06_RID),
		.AXI_06_RLAST               (AXI_06_RLAST),
		.AXI_06_RRESP               (AXI_06_RRESP),
		.AXI_06_RVALID              (AXI_06_RVALID),

		.AXI_06_BID                 (AXI_06_BID),
		.AXI_06_BRESP               (AXI_06_BRESP),
		.AXI_06_BVALID              (AXI_06_BVALID),

		// --------------------------------------------------
		// AXI_07
		// --------------------------------------------------
		.AXI_07_ARADDR              (AXI_07_ARADDR),
		.AXI_07_ARBURST             (AXI_07_ARBURST),
		.AXI_07_ARID                (AXI_07_ARID),
		.AXI_07_ARLEN               (AXI_07_ARLEN),
		.AXI_07_ARSIZE              (AXI_07_ARSIZE),
		.AXI_07_ARVALID             (AXI_07_ARVALID),
		.AXI_07_ARREADY             (AXI_07_ARREADY),

		.AXI_07_AWADDR              (AXI_07_AWADDR),
		.AXI_07_AWBURST             (AXI_07_AWBURST),
		.AXI_07_AWID                (AXI_07_AWID),
		.AXI_07_AWLEN               (AXI_07_AWLEN),
		.AXI_07_AWSIZE              (AXI_07_AWSIZE),
		.AXI_07_AWVALID             (AXI_07_AWVALID),
		.AXI_07_AWREADY             (AXI_07_AWREADY),
		.AXI_07_RREADY              (AXI_07_RREADY),
		.AXI_07_BREADY              (AXI_07_BREADY),

		.AXI_07_WDATA               (AXI_07_WDATA),
		.AXI_07_WLAST               (AXI_07_WLAST),
		.AXI_07_WSTRB               (AXI_07_WSTRB),
		.AXI_07_WDATA_PARITY        (),
		.AXI_07_WVALID              (AXI_07_WVALID),
		.AXI_07_WREADY              (AXI_07_WREADY),

		.AXI_07_RDATA               (AXI_07_RDATA),
		.AXI_07_RDATA_PARITY        (AXI_07_RDATA_PARITY),
		.AXI_07_RID                 (AXI_07_RID),
		.AXI_07_RLAST               (AXI_07_RLAST),
		.AXI_07_RRESP               (AXI_07_RRESP),
		.AXI_07_RVALID              (AXI_07_RVALID),

		.AXI_07_BID                 (AXI_07_BID),
		.AXI_07_BRESP               (AXI_07_BRESP),
		.AXI_07_BVALID              (AXI_07_BVALID),

		// --------------------------------------------------
		// AXI_08
		// --------------------------------------------------
		.AXI_08_ARADDR              (AXI_08_ARADDR),
		.AXI_08_ARBURST             (AXI_08_ARBURST),
		.AXI_08_ARID                (AXI_08_ARID),
		.AXI_08_ARLEN               (AXI_08_ARLEN),
		.AXI_08_ARSIZE              (AXI_08_ARSIZE),
		.AXI_08_ARVALID             (AXI_08_ARVALID),
		.AXI_08_ARREADY             (AXI_08_ARREADY),

		.AXI_08_AWADDR              (AXI_08_AWADDR),
		.AXI_08_AWBURST             (AXI_08_AWBURST),
		.AXI_08_AWID                (AXI_08_AWID),
		.AXI_08_AWLEN               (AXI_08_AWLEN),
		.AXI_08_AWSIZE              (AXI_08_AWSIZE),
		.AXI_08_AWVALID             (AXI_08_AWVALID),
		.AXI_08_AWREADY             (AXI_08_AWREADY),
		.AXI_08_RREADY              (AXI_08_RREADY),
		.AXI_08_BREADY              (AXI_08_BREADY),

		.AXI_08_WDATA               (AXI_08_WDATA),
		.AXI_08_WLAST               (AXI_08_WLAST),
		.AXI_08_WSTRB               (AXI_08_WSTRB),
		.AXI_08_WDATA_PARITY        (),
		.AXI_08_WVALID              (AXI_08_WVALID),
		.AXI_08_WREADY              (AXI_08_WREADY),

		.AXI_08_RDATA               (AXI_08_RDATA),
		.AXI_08_RDATA_PARITY        (AXI_08_RDATA_PARITY),
		.AXI_08_RID                 (AXI_08_RID),
		.AXI_08_RLAST               (AXI_08_RLAST),
		.AXI_08_RRESP               (AXI_08_RRESP),
		.AXI_08_RVALID              (AXI_08_RVALID),

		.AXI_08_BID                 (AXI_08_BID),
		.AXI_08_BRESP               (AXI_08_BRESP),
		.AXI_08_BVALID              (AXI_08_BVALID),


		// --------------------------------------------------
		// AXI_09
		// --------------------------------------------------
		.AXI_09_ARADDR              (AXI_09_ARADDR),
		.AXI_09_ARBURST             (AXI_09_ARBURST),
		.AXI_09_ARID                (AXI_09_ARID),
		.AXI_09_ARLEN               (AXI_09_ARLEN),
		.AXI_09_ARSIZE              (AXI_09_ARSIZE),
		.AXI_09_ARVALID             (AXI_09_ARVALID),
		.AXI_09_ARREADY             (AXI_09_ARREADY),

		.AXI_09_AWADDR              (AXI_09_AWADDR),
		.AXI_09_AWBURST             (AXI_09_AWBURST),
		.AXI_09_AWID                (AXI_09_AWID),
		.AXI_09_AWLEN               (AXI_09_AWLEN),
		.AXI_09_AWSIZE              (AXI_09_AWSIZE),
		.AXI_09_AWVALID             (AXI_09_AWVALID),
		.AXI_09_AWREADY             (AXI_09_AWREADY),

		.AXI_09_RREADY              (AXI_09_RREADY),
		.AXI_09_BREADY              (AXI_09_BREADY),

		.AXI_09_WDATA               (AXI_09_WDATA),
		.AXI_09_WLAST               (AXI_09_WLAST),
		.AXI_09_WSTRB               (AXI_09_WSTRB),
		.AXI_09_WDATA_PARITY        (),
		.AXI_09_WVALID              (AXI_09_WVALID),
		.AXI_09_WREADY              (AXI_09_WREADY),

		.AXI_09_RDATA               (AXI_09_RDATA),
		.AXI_09_RDATA_PARITY        (AXI_09_RDATA_PARITY),
		.AXI_09_RID                 (AXI_09_RID),
		.AXI_09_RLAST               (AXI_09_RLAST),
		.AXI_09_RRESP               (AXI_09_RRESP),
		.AXI_09_RVALID              (AXI_09_RVALID),

		.AXI_09_BID                 (AXI_09_BID),
		.AXI_09_BRESP               (AXI_09_BRESP),
		.AXI_09_BVALID              (AXI_09_BVALID),

		// --------------------------------------------------
		// AXI_10
		// --------------------------------------------------
		.AXI_10_ARADDR              (AXI_10_ARADDR),
		.AXI_10_ARBURST             (AXI_10_ARBURST),
		.AXI_10_ARID                (AXI_10_ARID),
		.AXI_10_ARLEN               (AXI_10_ARLEN),
		.AXI_10_ARSIZE              (AXI_10_ARSIZE),
		.AXI_10_ARVALID             (AXI_10_ARVALID),
		.AXI_10_ARREADY             (AXI_10_ARREADY),

		.AXI_10_AWADDR              (AXI_10_AWADDR),
		.AXI_10_AWBURST             (AXI_10_AWBURST),
		.AXI_10_AWID                (AXI_10_AWID),
		.AXI_10_AWLEN               (AXI_10_AWLEN),
		.AXI_10_AWSIZE              (AXI_10_AWSIZE),
		.AXI_10_AWVALID             (AXI_10_AWVALID),
		.AXI_10_AWREADY             (AXI_10_AWREADY),

		.AXI_10_RREADY              (AXI_10_RREADY),
		.AXI_10_BREADY              (AXI_10_BREADY),

		.AXI_10_WDATA               (AXI_10_WDATA),
		.AXI_10_WLAST               (AXI_10_WLAST),
		.AXI_10_WSTRB               (AXI_10_WSTRB),
		.AXI_10_WDATA_PARITY        (),
		.AXI_10_WVALID              (AXI_10_WVALID),
		.AXI_10_WREADY              (AXI_10_WREADY),

		.AXI_10_RDATA               (AXI_10_RDATA),
		.AXI_10_RDATA_PARITY        (AXI_10_RDATA_PARITY),
		.AXI_10_RID                 (AXI_10_RID),
		.AXI_10_RLAST               (AXI_10_RLAST),
		.AXI_10_RRESP               (AXI_10_RRESP),
		.AXI_10_RVALID              (AXI_10_RVALID),

		.AXI_10_BID                 (AXI_10_BID),
		.AXI_10_BRESP               (AXI_10_BRESP),
		.AXI_10_BVALID              (AXI_10_BVALID),

		// --------------------------------------------------
		// AXI_11
		// --------------------------------------------------
		.AXI_11_ARADDR              (AXI_11_ARADDR),
		.AXI_11_ARBURST             (AXI_11_ARBURST),
		.AXI_11_ARID                (AXI_11_ARID),
		.AXI_11_ARLEN               (AXI_11_ARLEN),
		.AXI_11_ARSIZE              (AXI_11_ARSIZE),
		.AXI_11_ARVALID             (AXI_11_ARVALID),
		.AXI_11_ARREADY             (AXI_11_ARREADY),

		.AXI_11_AWADDR              (AXI_11_AWADDR),
		.AXI_11_AWBURST             (AXI_11_AWBURST),
		.AXI_11_AWID                (AXI_11_AWID),
		.AXI_11_AWLEN               (AXI_11_AWLEN),
		.AXI_11_AWSIZE              (AXI_11_AWSIZE),
		.AXI_11_AWVALID             (AXI_11_AWVALID),
		.AXI_11_AWREADY             (AXI_11_AWREADY),

		.AXI_11_RREADY              (AXI_11_RREADY),
		.AXI_11_BREADY              (AXI_11_BREADY),

		.AXI_11_WDATA               (AXI_11_WDATA),
		.AXI_11_WLAST               (AXI_11_WLAST),
		.AXI_11_WSTRB               (AXI_11_WSTRB),
		.AXI_11_WDATA_PARITY        (),
		.AXI_11_WVALID              (AXI_11_WVALID),
		.AXI_11_WREADY              (AXI_11_WREADY),

		.AXI_11_RDATA               (AXI_11_RDATA),
		.AXI_11_RDATA_PARITY        (AXI_11_RDATA_PARITY),
		.AXI_11_RID                 (AXI_11_RID),
		.AXI_11_RLAST               (AXI_11_RLAST),
		.AXI_11_RRESP               (AXI_11_RRESP),
		.AXI_11_RVALID              (AXI_11_RVALID),

		.AXI_11_BID                 (AXI_11_BID),
		.AXI_11_BRESP               (AXI_11_BRESP),
		.AXI_11_BVALID              (AXI_11_BVALID),

		// --------------------------------------------------
		// AXI_12
		// --------------------------------------------------
		.AXI_12_ARADDR              (AXI_12_ARADDR),
		.AXI_12_ARBURST             (AXI_12_ARBURST),
		.AXI_12_ARID                (AXI_12_ARID),
		.AXI_12_ARLEN               (AXI_12_ARLEN),
		.AXI_12_ARSIZE              (AXI_12_ARSIZE),
		.AXI_12_ARVALID             (AXI_12_ARVALID),
		.AXI_12_ARREADY             (AXI_12_ARREADY),

		.AXI_12_AWADDR              (AXI_12_AWADDR),
		.AXI_12_AWBURST             (AXI_12_AWBURST),
		.AXI_12_AWID                (AXI_12_AWID),
		.AXI_12_AWLEN               (AXI_12_AWLEN),
		.AXI_12_AWSIZE              (AXI_12_AWSIZE),
		.AXI_12_AWVALID             (AXI_12_AWVALID),
		.AXI_12_AWREADY             (AXI_12_AWREADY),

		.AXI_12_RREADY              (AXI_12_RREADY),
		.AXI_12_BREADY              (AXI_12_BREADY),

		.AXI_12_WDATA               (AXI_12_WDATA),
		.AXI_12_WLAST               (AXI_12_WLAST),
		.AXI_12_WSTRB               (AXI_12_WSTRB),
		.AXI_12_WDATA_PARITY        (),
		.AXI_12_WVALID              (AXI_12_WVALID),
		.AXI_12_WREADY              (AXI_12_WREADY),

		.AXI_12_RDATA               (AXI_12_RDATA),
		.AXI_12_RDATA_PARITY        (AXI_12_RDATA_PARITY),
		.AXI_12_RID                 (AXI_12_RID),
		.AXI_12_RLAST               (AXI_12_RLAST),
		.AXI_12_RRESP               (AXI_12_RRESP),
		.AXI_12_RVALID              (AXI_12_RVALID),

		.AXI_12_BID                 (AXI_12_BID),
		.AXI_12_BRESP               (AXI_12_BRESP),
		.AXI_12_BVALID              (AXI_12_BVALID),

		// --------------------------------------------------
		// AXI_13
		// --------------------------------------------------
		.AXI_13_ARADDR              (AXI_13_ARADDR),
		.AXI_13_ARBURST             (AXI_13_ARBURST),
		.AXI_13_ARID                (AXI_13_ARID),
		.AXI_13_ARLEN               (AXI_13_ARLEN),
		.AXI_13_ARSIZE              (AXI_13_ARSIZE),
		.AXI_13_ARVALID             (AXI_13_ARVALID),
		.AXI_13_ARREADY             (AXI_13_ARREADY),

		.AXI_13_AWADDR              (AXI_13_AWADDR),
		.AXI_13_AWBURST             (AXI_13_AWBURST),
		.AXI_13_AWID                (AXI_13_AWID),
		.AXI_13_AWLEN               (AXI_13_AWLEN),
		.AXI_13_AWSIZE              (AXI_13_AWSIZE),
		.AXI_13_AWVALID             (AXI_13_AWVALID),
		.AXI_13_AWREADY             (AXI_13_AWREADY),

		.AXI_13_RREADY              (AXI_13_RREADY),
		.AXI_13_BREADY              (AXI_13_BREADY),

		.AXI_13_WDATA               (AXI_13_WDATA),
		.AXI_13_WLAST               (AXI_13_WLAST),
		.AXI_13_WSTRB               (AXI_13_WSTRB),
		.AXI_13_WDATA_PARITY        (),
		.AXI_13_WVALID              (AXI_13_WVALID),
		.AXI_13_WREADY              (AXI_13_WREADY),

		.AXI_13_RDATA               (AXI_13_RDATA),
		.AXI_13_RDATA_PARITY        (AXI_13_RDATA_PARITY),
		.AXI_13_RID                 (AXI_13_RID),
		.AXI_13_RLAST               (AXI_13_RLAST),
		.AXI_13_RRESP               (AXI_13_RRESP),
		.AXI_13_RVALID              (AXI_13_RVALID),

		.AXI_13_BID                 (AXI_13_BID),
		.AXI_13_BRESP               (AXI_13_BRESP),
		.AXI_13_BVALID              (AXI_13_BVALID),

		// --------------------------------------------------
		// AXI_14
		// --------------------------------------------------
		.AXI_14_ARADDR              (AXI_14_ARADDR),
		.AXI_14_ARBURST             (AXI_14_ARBURST),
		.AXI_14_ARID                (AXI_14_ARID),
		.AXI_14_ARLEN               (AXI_14_ARLEN),
		.AXI_14_ARSIZE              (AXI_14_ARSIZE),
		.AXI_14_ARVALID             (AXI_14_ARVALID),
		.AXI_14_ARREADY             (AXI_14_ARREADY),

		.AXI_14_AWADDR              (AXI_14_AWADDR),
		.AXI_14_AWBURST             (AXI_14_AWBURST),
		.AXI_14_AWID                (AXI_14_AWID),
		.AXI_14_AWLEN               (AXI_14_AWLEN),
		.AXI_14_AWSIZE              (AXI_14_AWSIZE),
		.AXI_14_AWVALID             (AXI_14_AWVALID),
		.AXI_14_AWREADY             (AXI_14_AWREADY),

		.AXI_14_RREADY              (AXI_14_RREADY),
		.AXI_14_BREADY              (AXI_14_BREADY),

		.AXI_14_WDATA               (AXI_14_WDATA),
		.AXI_14_WLAST               (AXI_14_WLAST),
		.AXI_14_WSTRB               (AXI_14_WSTRB),
		.AXI_14_WDATA_PARITY        (),
		.AXI_14_WVALID              (AXI_14_WVALID),
		.AXI_14_WREADY              (AXI_14_WREADY),

		.AXI_14_RDATA               (AXI_14_RDATA),
		.AXI_14_RDATA_PARITY        (AXI_14_RDATA_PARITY),
		.AXI_14_RID                 (AXI_14_RID),
		.AXI_14_RLAST               (AXI_14_RLAST),
		.AXI_14_RRESP               (AXI_14_RRESP),
		.AXI_14_RVALID              (AXI_14_RVALID),

		.AXI_14_BID                 (AXI_14_BID),
		.AXI_14_BRESP               (AXI_14_BRESP),
		.AXI_14_BVALID              (AXI_14_BVALID),

		// --------------------------------------------------
		// AXI_15
		// --------------------------------------------------
		.AXI_15_ARADDR              (AXI_15_ARADDR),
		.AXI_15_ARBURST             (AXI_15_ARBURST),
		.AXI_15_ARID                (AXI_15_ARID),
		.AXI_15_ARLEN               (AXI_15_ARLEN),
		.AXI_15_ARSIZE              (AXI_15_ARSIZE),
		.AXI_15_ARVALID             (AXI_15_ARVALID),
		.AXI_15_ARREADY             (AXI_15_ARREADY),

		.AXI_15_AWADDR              (AXI_15_AWADDR),
		.AXI_15_AWBURST             (AXI_15_AWBURST),
		.AXI_15_AWID                (AXI_15_AWID),
		.AXI_15_AWLEN               (AXI_15_AWLEN),
		.AXI_15_AWSIZE              (AXI_15_AWSIZE),
		.AXI_15_AWVALID             (AXI_15_AWVALID),
		.AXI_15_AWREADY             (AXI_15_AWREADY),
		.AXI_15_RREADY              (AXI_15_RREADY),
		.AXI_15_BREADY              (AXI_15_BREADY),

		.AXI_15_WDATA               (AXI_15_WDATA),
		.AXI_15_WLAST               (AXI_15_WLAST),
		.AXI_15_WSTRB               (AXI_15_WSTRB),
		.AXI_15_WDATA_PARITY        (),
		.AXI_15_WVALID              (AXI_15_WVALID),
		.AXI_15_WREADY              (AXI_15_WREADY),

		.AXI_15_RDATA               (AXI_15_RDATA),
		.AXI_15_RDATA_PARITY        (AXI_15_RDATA_PARITY),
		.AXI_15_RID                 (AXI_15_RID),
		.AXI_15_RLAST               (AXI_15_RLAST),
		.AXI_15_RRESP               (AXI_15_RRESP),
		.AXI_15_RVALID              (AXI_15_RVALID),

		.AXI_15_BID                 (AXI_15_BID),
		.AXI_15_BRESP               (AXI_15_BRESP),
		.AXI_15_BVALID              (AXI_15_BVALID),


		// --------------------------------------------------
		// APB / status
		// --------------------------------------------------
		.APB_0_PCLK                 (APB_0_PCLK),
		.APB_0_PRESET_N             (APB_0_PRESET_N),

		.apb_complete_0             (apb_complete_0),
		.DRAM_0_STAT_CATTRIP        (DRAM_0_STAT_CATTRIP),
		.DRAM_0_STAT_TEMP           (DRAM_0_STAT_TEMP)
	);



	// Add user logic here
	
	

	// User logic ends

	endmodule
