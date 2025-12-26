`timescale 1 ns / 1 ps


module controller #
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
  output wire                          tfhe_reset_n,
  output wire [3:0]                    hbm_rw_select,

  // --------------------------------------------------
  // User LED output
  // --------------------------------------------------
  output  [7:0]                    user_led,

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
  
  reg start_pbs_d;
  reg o_reset_n;

  integer byte_index;


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
      slv_reg0    <= 0; // clear start_pbs on reset and default HBM select to host
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
      slv_reg0 <= 0; // clear start_pbs on reset and default HBM select to host
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

  // ---------------- CONTROL ASSIGNMENTS ----------------
  // slv_reg0 [3:0] - control and status register
  //  bit 0     - start_pbs
  //  bit 1     - pbs_busy
  //  bit 2     - pbs_done
  //  bit 3     - reserved

  // slv_reg0 [7:4] - hbm r/w select for TFHE_PU and host
  //  bits 4     - hbm_tfhe_wr_select_stack_0
  //  bits 5     - hbm_tfhe_rd_select_stack_0
  //  bits 6     - hbm_tfhe_wr_select_stack_1
  //  bits 7     - hbm_tfhe_rd_select_stack_1

  // slv_reg0 [31:8] - reserved

  assign start_pbs    = slv_reg0[0];
  assign hbm_rw_select   = slv_reg0[7:4];

  assign tfhe_reset_n  = o_reset_n;

  // start_pbs edge detect and tfhe_reset_n logic
  always @(posedge S_AXI_ACLK) begin
      if (!S_AXI_ARESETN) begin
          start_pbs_d <= 1'b0;
          o_reset_n   <= 1'b0;
      end else begin
          start_pbs_d <= start_pbs;

          // rising edge detect
          if (!start_pbs_d && start_pbs)
              o_reset_n <= 1'b1;
          else if (!start_pbs)
              o_reset_n <= 1'b0;
      end
  end


  // Controller LED logic
  reg  [2:0]  led;
  assign user_led[7]   = start_pbs;
  assign user_led[6]   = pbs_busy;
  assign user_led[5]   = pbs_done;
  assign user_led[4:3] = {hbm_rw_select[2],hbm_rw_select[0]}; // Only show write select status
  assign user_led[2:0] = led;

  reg [23:0] led_cnt;
  reg [2:0]  seq_led;

  /* free-running counter */
  always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
    if (!S_AXI_ARESETN)
      led_cnt <= 24'd0;
    else
      led_cnt <= led_cnt + 1'b1;
  end

  /* Status register update and LED pattern logic */
  always @(posedge S_AXI_ACLK or negedge S_AXI_ARESETN) begin
    if (!S_AXI_ARESETN) begin
      led     <= 3'b000;
      seq_led <= 3'b001;
    end else begin

      /* Highest priority: PBS done -> all ON */
      if (pbs_done) begin
        led <= 3'b111;
        slv_reg0 [0] <= 1'b0;  // clear start_pbs
        slv_reg0 [2] <= 1'b1;  // set pbs_done, host has to clear this before next PBS start

      /* start_pbs active -> sequential pattern */
      end else if (start_pbs) begin
        if (led_cnt[23]) begin
          seq_led <= {seq_led[1:0], seq_led[2]};  // rotate left
          led     <= seq_led;
        end

      /* Idle -> heartbeat blink */
      end else begin
        led <= {3{led_cnt[23]}};  // all blink together
      end

      if (pbs_busy) slv_reg0 [1] <= 1'b1;  // set pbs_busy
      else slv_reg0 [1] <= 1'b0;  // clear pbs_busy
    end
  end


endmodule
