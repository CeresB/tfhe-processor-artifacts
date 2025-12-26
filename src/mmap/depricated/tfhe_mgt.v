// ============================================================
// Engine FSM (consumes level start exactly once per assertion)
// ============================================================
module tfhe_mgt #
(
    parameter integer C_S_AXI_DATA_WIDTH = 32
)
(
    input  wire                          clk,
    input  wire                          reset_n,

    output reg  [C_S_AXI_DATA_WIDTH-1:0] host_rd_addr,
    output reg  [C_S_AXI_DATA_WIDTH-1:0] host_rd_len,
    output reg                           pbs_busy,
    output reg                           pbs_done,

    input  wire [C_S_AXI_DATA_WIDTH-1:0] host_wr_addr,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] host_wr_len,
    input  wire                          start_pbs,

    output  [7:0]                    user_led
);

  localparam PBS_IDLE  = 2'd0;
  localparam PBS_RUN   = 2'd1;
  localparam PBS_DRAIN = 2'd2;
  
  reg  [4:0]  led;


  assign user_led[7] = start_pbs;
  assign user_led[6] = pbs_busy;
  assign user_led[5] = pbs_done;
  assign user_led[4:0] = led;

  reg [1:0]  pbs_state;
  reg [63:0] delay_cnt;
  reg [23:0] led_cnt;

  // Consume level START once; re-arm when it goes low
  reg start_seen;

  always @(posedge clk) begin
    if (!reset_n) begin
      pbs_state    <= PBS_IDLE;
      pbs_busy     <= 1'b0;
      pbs_done     <= 1'b0;

      delay_cnt    <= 64'd0;
      led_cnt      <= 24'd0;

      host_rd_addr <= {C_S_AXI_DATA_WIDTH{1'b0}};
      host_rd_len  <= {C_S_AXI_DATA_WIDTH{1'b0}};
      led     <= 4'h00;

      start_seen   <= 1'b0;

    end else begin
      led_cnt <= led_cnt + 1'b1;

      // defaults
      pbs_busy <= 1'b0;
      pbs_done <= 1'b0;

      // re-arm when START drops (controller auto-clears on done)
      if (!start_pbs)
        start_seen <= 1'b0;

      case (pbs_state)

        PBS_IDLE: begin
          led  <= {led_cnt[23], 1'b0, led_cnt[23], 1'b0, led_cnt[23] };
          delay_cnt <= 64'd0;

          if (start_pbs && !start_seen) begin
            start_seen   <= 1'b1;
            host_rd_addr <= host_wr_addr;
            host_rd_len  <= host_wr_len;
            pbs_state    <= PBS_RUN;
          end
        end

        PBS_RUN: begin
          pbs_busy <= 1'b1;
          led <= led_cnt[23] ? 5'b10101 : 5'b01010;

          if (delay_cnt == 64'hFFFF_FFFF) begin
            delay_cnt <= 64'd0;
            pbs_state <= PBS_DRAIN;
          end else begin
            delay_cnt <= delay_cnt + 1'b1;
          end
        end

        PBS_DRAIN: begin
          pbs_busy <= 1'b1;
          led <= led_cnt[23:19];

          if (delay_cnt == 64'hFFFF_FFFF) begin
            delay_cnt <= 64'd0;
            pbs_done  <= 1'b1;    // 1-cycle pulse
            pbs_state <= PBS_IDLE;
          end else begin
            delay_cnt <= delay_cnt + 1'b1;
          end
        end

        default: pbs_state <= PBS_IDLE;

      endcase
    end
  end

endmodule