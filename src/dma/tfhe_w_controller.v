`timescale 1 ns / 1 ps


module tfhe_w_controller #
(
  parameter integer C_S_AXI_DATA_WIDTH = 32,
  parameter integer C_S_AXI_ADDR_WIDTH = 6   // 6 regs -> 0x00–0x14
)
(
  // --------------------------------------------------
  // TFHE processor inputs (module-controlled state)
  // --------------------------------------------------
  input  wire [C_S_AXI_DATA_WIDTH-1:0] host_rd_addr,
  input  wire [C_S_AXI_DATA_WIDTH-1:0] host_rd_len,
  input  wire                          pbs_busy,
  input  wire                          pbs_done,

  // --------------------------------------------------
  // Controller outputs
  // --------------------------------------------------
  output wire [C_S_AXI_DATA_WIDTH-1:0] host_wr_addr,
  output wire [C_S_AXI_DATA_WIDTH-1:0] host_wr_len,
  output wire                          start_pbs,
  output wire [1:0]                    hbm_select,

  // --------------------------------------------------
  // AXI4-Lite interface
  // --------------------------------------------------
  // Global Clock Signal
  input wire  S_AXI_ACLK,
  // Global Reset Signal. This Signal is Active LOW
  input wire  S_AXI_ARESETN,

  // Write address
  input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
  input wire [2 : 0] S_AXI_AWPROT,
  input wire  S_AXI_AWVALID,
  output wire  S_AXI_AWREADY,

  // Write data
  input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
  input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
  input wire  S_AXI_WVALID,
  output wire  S_AXI_WREADY,

  // Write response
  output wire [1 : 0] S_AXI_BRESP,
  output wire  S_AXI_BVALID,
  input wire  S_AXI_BREADY,

  // Read address
  input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
  input wire [2 : 0] S_AXI_ARPROT,
  input wire  S_AXI_ARVALID,
  output wire  S_AXI_ARREADY,

  // Read data/resp
  output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
  output wire [1 : 0] S_AXI_RRESP,
  output wire  S_AXI_RVALID,
  input wire  S_AXI_RREADY
);

// AXI4-Lite internal signals
  reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_awaddr;
  reg axi_awready;
  reg axi_wready;
  reg [1 : 0] axi_bresp;
  reg axi_bvalid;

  reg [C_S_AXI_ADDR_WIDTH-1 : 0] axi_araddr;
  reg axi_arready;
  reg [1 : 0] axi_rresp;
  reg axi_rvalid;

  localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
  localparam integer OPT_MEM_ADDR_BITS = 3; // 6 registers

  // 6 Slave registers
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0;
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg1;
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg2;
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg3;
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg4;
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg5;

  integer byte_index;

  // LED logic
  reg [31:0] led_cnt;
  reg [7:0]  led_shift;

  // Assign AXI outputs
  assign S_AXI_AWREADY = axi_awready;
  assign S_AXI_WREADY  = axi_wready;
  assign S_AXI_BRESP   = axi_bresp;
  assign S_AXI_BVALID  = axi_bvalid;
  assign S_AXI_ARREADY = axi_arready;
  assign S_AXI_RRESP   = axi_rresp;
  assign S_AXI_RVALID  = axi_rvalid;

  // ---------------- WRITE FSM ----------------
  reg [1:0] state_write;
  localparam WIdle = 2'b00, Waddr = 2'b10, Wdata = 2'b11;

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_awready <= 1'b0;
      axi_wready  <= 1'b0;
      axi_bvalid  <= 1'b0;
      axi_bresp   <= 2'b00;
      axi_awaddr  <= 0;
      slv_reg0    <= 0;
      slv_reg1    <= 0;
      slv_reg2    <= 0;
      slv_reg3    <= 0;
      slv_reg4    <= 0;
      slv_reg5    <= 0;
      state_write <= WIdle;
    end else begin
      case (state_write)
        WIdle: begin
          axi_awready <= 1'b1;
          axi_wready  <= 1'b1;
          state_write <= Waddr;
        end

        Waddr: begin
          if (S_AXI_AWVALID && axi_awready) begin
            axi_awaddr <= S_AXI_AWADDR;
            if (S_AXI_WVALID) begin
              axi_bvalid <= 1'b1;
            end else begin
              axi_awready <= 1'b0;
              state_write <= Wdata;
            end
          end
          if (S_AXI_BREADY && axi_bvalid)
            axi_bvalid <= 1'b0;
        end

        Wdata: begin
          if (S_AXI_WVALID) begin
            axi_bvalid  <= 1'b1;
            axi_awready <= 1'b1;
            state_write <= Waddr;
          end
          if (S_AXI_BREADY && axi_bvalid)
            axi_bvalid <= 1'b0;
        end
      endcase
    end
  end

  // ---------------- REGISTER WRITE ----------------
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      slv_reg0 <= 0;
      slv_reg1 <= 0;
      slv_reg2 <= 0;
      slv_reg3 <= 0;
      slv_reg4 <= 0;
      slv_reg5 <= 0;
    end else begin
      if (S_AXI_WVALID) begin
        case ( (S_AXI_AWVALID) ?
               S_AXI_AWADDR[ADDR_LSB+OPT_MEM_ADDR_BITS-1:ADDR_LSB] :
               axi_awaddr [ADDR_LSB+OPT_MEM_ADDR_BITS-1:ADDR_LSB] )

          3'h0: for (byte_index=0; byte_index<(C_S_AXI_DATA_WIDTH/8); byte_index=byte_index+1)
                  if (S_AXI_WSTRB[byte_index])
                    slv_reg0[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];

          3'h1: for (byte_index=0; byte_index<(C_S_AXI_DATA_WIDTH/8); byte_index=byte_index+1)
                  if (S_AXI_WSTRB[byte_index])
                    slv_reg1[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];

          3'h2: for (byte_index=0; byte_index<(C_S_AXI_DATA_WIDTH/8); byte_index=byte_index+1)
                  if (S_AXI_WSTRB[byte_index])
                    slv_reg2[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];

          3'h3: for (byte_index=0; byte_index<(C_S_AXI_DATA_WIDTH/8); byte_index=byte_index+1)
                  if (S_AXI_WSTRB[byte_index])
                    slv_reg3[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];

          3'h4: for (byte_index=0; byte_index<(C_S_AXI_DATA_WIDTH/8); byte_index=byte_index+1)
                  if (S_AXI_WSTRB[byte_index])
                    slv_reg4[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];

          3'h5: for (byte_index=0; byte_index<(C_S_AXI_DATA_WIDTH/8); byte_index=byte_index+1)
                  if (S_AXI_WSTRB[byte_index])
                    slv_reg5[byte_index*8 +: 8] <= S_AXI_WDATA[byte_index*8 +: 8];

          default: ;
        endcase
      end
    end
  end

  // ---------------- READ FSM ----------------
  reg [1:0] state_read;
  localparam RIdle = 2'b00, Raddr = 2'b10, Rdata = 2'b11;

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      axi_arready <= 1'b0;
      axi_rvalid  <= 1'b0;
      axi_rresp   <= 2'b00;
      axi_araddr  <= 0;
      state_read  <= RIdle;
    end else begin
      case (state_read)
        RIdle: begin
          axi_arready <= 1'b1;
          state_read  <= Raddr;
        end

        Raddr: begin
          if (S_AXI_ARVALID && axi_arready) begin
            axi_araddr  <= S_AXI_ARADDR;
            axi_rvalid  <= 1'b1;
            axi_arready <= 1'b0;
            state_read  <= Rdata;
          end
        end

        Rdata: begin
          if (axi_rvalid && S_AXI_RREADY) begin
            axi_rvalid  <= 1'b0;
            axi_arready <= 1'b1;
            state_read  <= Raddr;
          end
        end
      endcase
    end
  end

  // ---------------- READ MUX ----------------
  assign S_AXI_RDATA =
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS-1:ADDR_LSB] == 3'h0) ? slv_reg0 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS-1:ADDR_LSB] == 3'h1) ? slv_reg1 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS-1:ADDR_LSB] == 3'h2) ? slv_reg2 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS-1:ADDR_LSB] == 3'h3) ? slv_reg3 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS-1:ADDR_LSB] == 3'h4) ? slv_reg4 :
    (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS-1:ADDR_LSB] == 3'h5) ? slv_reg5 :
    32'd0;

  assign start_pbs    = slv_reg0[0];
  assign hbm_select   = slv_reg0[2:1];


  // // ---------------- USER LED LOGIC (unchanged) ----------------
  // always @(posedge S_AXI_ACLK) begin
  //   if (!S_AXI_ARESETN) begin
  //     led_cnt   <= 32'd0;
  //     led_shift <= 8'b0000_0001;
  //     user_led  <= 8'b0000_0000;
  //   end else begin
  //     led_cnt <= led_cnt + 1;

  //     if (led_cnt >= (slv_reg1 != 32'd0 ? slv_reg1 : 32'd25_000_000)) begin
  //       led_cnt <= 32'd0;
  //       case (slv_reg0[2:0])
  //         3'b000: user_led <= 8'b0000_0000;
  //         3'b001: user_led <= 8'b1111_1111;
  //         3'b010: begin
  //           led_shift <= (led_shift == 8'b1000_0000) ? 8'b0000_0001 : (led_shift << 1);
  //           user_led  <= led_shift;
  //         end
  //         3'b011: begin
  //           led_shift <= (led_shift == 8'b0000_0001) ? 8'b1000_0000 : (led_shift >> 1);
  //           user_led  <= led_shift;
  //         end
  //         3'b100: user_led <= ~user_led;
  //         3'b101: user_led <= {slv_reg2[3:0], slv_reg2[3:0]};
  //         default: user_led <= slv_reg3[7:0];
  //       endcase
  //     end
  //   end
  // end

endmodule
