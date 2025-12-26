
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
		parameter integer C_M00_AXI_BUSER_WIDTH	= 0 

	)
	(
		// Users to add ports here
		input wire  tfhe_clk,
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

// tfhe_w_controller # ( 
// 		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
// 		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
// 	) tfhe_w_controller_inst (
// 		.S_AXI_ACLK(s00_axi_aclk),
// 		.S_AXI_ARESETN(s00_axi_aresetn),
// 		.S_AXI_AWADDR(s00_axi_awaddr),
// 		.S_AXI_AWPROT(s00_axi_awprot),
// 		.S_AXI_AWVALID(s00_axi_awvalid),
// 		.S_AXI_AWREADY(s00_axi_awready),
// 		.S_AXI_WDATA(s00_axi_wdata),
// 		.S_AXI_WSTRB(s00_axi_wstrb),
// 		.S_AXI_WVALID(s00_axi_wvalid),
// 		.S_AXI_WREADY(s00_axi_wready),
// 		.S_AXI_BRESP(s00_axi_bresp),
// 		.S_AXI_BVALID(s00_axi_bvalid),
// 		.S_AXI_BREADY(s00_axi_bready),
// 		.S_AXI_ARADDR(s00_axi_araddr),
// 		.S_AXI_ARPROT(s00_axi_arprot),
// 		.S_AXI_ARVALID(s00_axi_arvalid),
// 		.S_AXI_ARREADY(s00_axi_arready),
// 		.S_AXI_RDATA(s00_axi_rdata),
// 		.S_AXI_RRESP(s00_axi_rresp),
// 		.S_AXI_RVALID(s00_axi_rvalid),
// 		.S_AXI_RREADY(s00_axi_rready),
		
// 		.user_led(user_led)
// 	);


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


	// Add user logic here
	
	

	// User logic ends

	endmodule
