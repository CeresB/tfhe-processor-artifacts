`timescale 1 ns / 1 ps

module tfhe_w_master_full_v1_0_M00_AXI #
(
    parameter  C_M_TARGET_SLAVE_BASE_ADDR = 64'h40000000,
    parameter integer C_M_AXI_BURST_LEN   = 16,
    parameter integer C_M_AXI_ID_WIDTH    = 1,
    parameter integer C_M_AXI_ADDR_WIDTH  = 64,
    parameter integer C_M_AXI_DATA_WIDTH  = 256,
    parameter integer C_M_AXI_AWUSER_WIDTH = 0,
    parameter integer C_M_AXI_ARUSER_WIDTH = 0,
    parameter integer C_M_AXI_WUSER_WIDTH  = 0,
    parameter integer C_M_AXI_RUSER_WIDTH  = 0,
    parameter integer C_M_AXI_BUSER_WIDTH  = 0,
    parameter integer C_S_AXI_DATA_WIDTH	= 32
)
(
    // Not used anymore
    input  wire INIT_AXI_TXN,
    output wire TXN_DONE,
    output wire ERROR,

    // Clock / Reset
    input  wire M_AXI_ACLK,
    input  wire M_AXI_ARESETN,

    // ---------------------------------------------------------
    // AXI4 MASTER INTERFACE
    // ---------------------------------------------------------

    // -------------------- WRITE ADDRESS CHANNEL --------------------
    output wire  [C_M_AXI_ID_WIDTH-1:0]    M_AXI_AWID,
    output wire  [C_M_AXI_ADDR_WIDTH-1:0]  M_AXI_AWADDR,
    output wire  [7:0]                     M_AXI_AWLEN,
    output wire  [2:0]                     M_AXI_AWSIZE,
    output wire  [1:0]                     M_AXI_AWBURST,
    output wire                            M_AXI_AWLOCK,
    output wire  [3:0]                     M_AXI_AWCACHE,
    output wire  [2:0]                     M_AXI_AWPROT,
    output wire  [3:0]                     M_AXI_AWQOS,
    output wire  [C_M_AXI_AWUSER_WIDTH-1:0]M_AXI_AWUSER,
    output wire                            M_AXI_AWVALID,
    input  wire                            M_AXI_AWREADY,

    // -------------------- WRITE DATA CHANNEL --------------------
    output wire  [C_M_AXI_DATA_WIDTH-1:0]   M_AXI_WDATA,
    output wire  [C_M_AXI_DATA_WIDTH/8-1:0] M_AXI_WSTRB,
    output wire                             M_AXI_WLAST,
    output wire  [C_M_AXI_WUSER_WIDTH-1:0]  M_AXI_WUSER,
    output wire                             M_AXI_WVALID,
    input  wire                             M_AXI_WREADY,

    // -------------------- WRITE RESPONSE --------------------
    input  wire  [C_M_AXI_ID_WIDTH-1:0]    M_AXI_BID,
    input  wire  [1:0]                     M_AXI_BRESP,
    input  wire  [C_M_AXI_BUSER_WIDTH-1:0] M_AXI_BUSER,
    input  wire                            M_AXI_BVALID,
    output wire                            M_AXI_BREADY,

    // -------------------- READ ADDRESS CHANNEL --------------------
    output wire  [C_M_AXI_ID_WIDTH-1:0]    M_AXI_ARID,
    output wire  [C_M_AXI_ADDR_WIDTH-1:0]  M_AXI_ARADDR,
    output wire  [7:0]                     M_AXI_ARLEN,
    output wire  [2:0]                     M_AXI_ARSIZE,
    output wire  [1:0]                     M_AXI_ARBURST,
    output wire                            M_AXI_ARLOCK,
    output wire  [3:0]                     M_AXI_ARCACHE,
    output wire  [2:0]                     M_AXI_ARPROT,
    output wire  [3:0]                     M_AXI_ARQOS,
    output wire  [C_M_AXI_ARUSER_WIDTH-1:0]M_AXI_ARUSER,
    output wire                            M_AXI_ARVALID,
    input  wire                            M_AXI_ARREADY,

    // -------------------- READ DATA CHANNEL --------------------
    input  wire  [C_M_AXI_ID_WIDTH-1:0]    M_AXI_RID,
    input  wire  [C_M_AXI_DATA_WIDTH-1:0]  M_AXI_RDATA,
    input  wire  [1:0]                     M_AXI_RRESP,
    input  wire                            M_AXI_RLAST,
    input  wire  [C_M_AXI_RUSER_WIDTH-1:0] M_AXI_RUSER,
    input  wire                            M_AXI_RVALID,
    output wire                            M_AXI_RREADY,

    // --------------------------------------------------
    // TFHE processor inputs (module-controlled state)
    // --------------------------------------------------
    output  wire [C_S_AXI_DATA_WIDTH-1:0] host_rd_addr,
    output  wire [C_S_AXI_DATA_WIDTH-1:0] host_rd_len,
    output  wire                          pbs_busy,
    output  wire                          pbs_done,

    // --------------------------------------------------
    // Controller outputs
    // --------------------------------------------------
    input wire [C_S_AXI_DATA_WIDTH-1:0] host_wr_addr,
    input wire [C_S_AXI_DATA_WIDTH-1:0] host_wr_len,
    input wire                          start_pbs,

    output [7:0] user_led
);

//
// ================================================================
// CONSTANT TIE-OFFS FOR UNUSED AXI SIGNALS
// ================================================================
assign M_AXI_AWID    = {C_M_AXI_ID_WIDTH{1'b0}};
assign M_AXI_AWLOCK  = 1'b0;
assign M_AXI_AWCACHE = 4'b0010;
assign M_AXI_AWPROT  = 3'b000;
assign M_AXI_AWQOS   = 4'b0000;
assign M_AXI_AWUSER  = {C_M_AXI_AWUSER_WIDTH{1'b0}};

assign M_AXI_ARID    = {C_M_AXI_ID_WIDTH{1'b0}};
assign M_AXI_ARLOCK  = 1'b0;
assign M_AXI_ARCACHE = 4'b0010;
assign M_AXI_ARPROT  = 3'b000;
assign M_AXI_ARQOS   = 4'b0000;
assign M_AXI_ARUSER  = {C_M_AXI_ARUSER_WIDTH{1'b0}};

assign M_AXI_WSTRB = { (C_M_AXI_DATA_WIDTH/8){1'b1} };
assign M_AXI_WUSER = {C_M_AXI_WUSER_WIDTH{1'b0}};


//
// ================================================================
// INTERNAL WIRES FROM TFHE VHDL AXI WRAPPER
// ================================================================
wire [C_M_AXI_ADDR_WIDTH-1:0] tfhe_awaddr;
wire                          tfhe_awvalid;
wire [C_M_AXI_DATA_WIDTH-1:0] tfhe_wdata;
wire                          tfhe_wvalid;
wire                          tfhe_wlast;
wire                          tfhe_bready;

wire [C_M_AXI_ADDR_WIDTH-1:0] tfhe_araddr;
wire                          tfhe_arvalid;
wire                          tfhe_rready;


//
// ================================================================
// CONNECT TFHE to AXI WRAPPER (WRITE + READ)
// ================================================================

// ---------------- WRITE ----------------
assign M_AXI_AWADDR  = tfhe_awaddr; //This needs to be connected to the address going to the controller [host_data_address_3]
assign M_AXI_AWLEN   = C_M_AXI_BURST_LEN - 1;
assign M_AXI_AWSIZE  = $clog2(C_M_AXI_DATA_WIDTH/8);
assign M_AXI_AWBURST = 2'b01;   // INCR
assign M_AXI_AWVALID = tfhe_awvalid;

assign M_AXI_WDATA   = tfhe_wdata;
assign M_AXI_WVALID  = tfhe_wvalid;
assign M_AXI_WLAST   = tfhe_wlast;

assign M_AXI_BREADY  = tfhe_bready;

// ---------------- READ ----------------
assign M_AXI_ARADDR  = tfhe_araddr; //This needs to be connected to the address coming from the controller [host_data_address_2]
assign M_AXI_ARVALID = tfhe_arvalid;
assign M_AXI_ARLEN   = C_M_AXI_BURST_LEN - 1;
assign M_AXI_ARSIZE  = $clog2(C_M_AXI_DATA_WIDTH/8);
assign M_AXI_ARBURST = 2'b01;

assign M_AXI_RREADY  = tfhe_rready;


//
// ================================================================
// UPDATED VHDL WRAPPER ( WRITE + READ)
// ================================================================
tfhe_pbs_accelerator_axi #(
    .C_M_AXI_ADDR_WIDTH (C_M_AXI_ADDR_WIDTH),
    .C_M_AXI_DATA_WIDTH (C_M_AXI_DATA_WIDTH),
    .C_M_AXI_BURST_LEN  (C_M_AXI_BURST_LEN),
    .C_S_AXI_DATA_WIDTH (C_S_AXI_DATA_WIDTH)
) u_tfhe (
    .i_clk     (M_AXI_ACLK),
    .i_reset_n (M_AXI_ARESETN),

    // ------------ READ ------------
    .M_AXI_ARADDR  (tfhe_araddr),
    .M_AXI_ARLEN   (),                 // internally handled in VHDL, for now
    .M_AXI_ARSIZE  (),
    .M_AXI_ARBURST (),
    .M_AXI_ARVALID (tfhe_arvalid),
    .M_AXI_ARREADY (M_AXI_ARREADY),

    .M_AXI_RDATA   (M_AXI_RDATA),
    .M_AXI_RRESP   (M_AXI_RRESP),
    .M_AXI_RLAST   (M_AXI_RLAST),
    .M_AXI_RVALID  (M_AXI_RVALID),
    .M_AXI_RREADY  (tfhe_rready),

    // ------------ WRITE ------------
    .M_AXI_AWADDR  (tfhe_awaddr),
    .M_AXI_AWLEN   (),                 // internally handled in VHDL, for now
    .M_AXI_AWSIZE  (),
    .M_AXI_AWBURST (),
    .M_AXI_AWVALID (tfhe_awvalid),
    .M_AXI_AWREADY (M_AXI_AWREADY),

    .M_AXI_WDATA   (tfhe_wdata),
    .M_AXI_WVALID  (tfhe_wvalid),
    .M_AXI_WLAST   (tfhe_wlast),
    .M_AXI_WREADY  (M_AXI_WREADY),

    .M_AXI_BRESP   (M_AXI_BRESP),
    .M_AXI_BVALID  (M_AXI_BVALID),
    .M_AXI_BREADY  (tfhe_bready),
    
    .user_led(user_led),
    .host_rd_addr(host_rd_addr),
    .host_rd_len(host_rd_len),
    .pbs_busy(pbs_busy),
    .pbs_done(pbs_done),
    .start_pbs(start_pbs)
);


//
// ================================================================
// UNUSED STATUS OUTPUTS
// ================================================================
assign TXN_DONE = 1'b0;
assign ERROR    = 1'b0;

endmodule
