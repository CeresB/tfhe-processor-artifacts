`timescale 1 ns / 1 ps

// ============================================================
// AXI-Lite controller / register block
// ============================================================
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

  // --------------------------------------------------
  // AXI4-Lite interface
  // --------------------------------------------------
  input  wire                          S_AXI_ACLK,
  input  wire                          S_AXI_ARESETN,

  input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
  input  wire                          S_AXI_AWVALID,
  output reg                           S_AXI_AWREADY,

  input  wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
  input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] S_AXI_WSTRB,
  input  wire                          S_AXI_WVALID,
  output reg                           S_AXI_WREADY,

  output reg  [1:0]                    S_AXI_BRESP,
  output reg                           S_AXI_BVALID,
  input  wire                          S_AXI_BREADY,

  input  wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
  input  wire                          S_AXI_ARVALID,
  output reg                           S_AXI_ARREADY,

  output reg  [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
  output reg  [1:0]                    S_AXI_RRESP,
  output reg                           S_AXI_RVALID,
  input  wire                          S_AXI_RREADY
);

  // Register offsets:
  // 0x00 CTRL     (W/R) bit0=START (level). HW clears on pbs_done.
  // 0x04 WR_ADDR  (W/R)
  // 0x08 WR_LEN   (W/R)
  // 0x0C STATUS   (R)   bit0=busy(live), bit1=done(sticky)
  // 0x10 RD_ADDR  (R)
  // 0x14 RD_LEN   (R)

  localparam integer ADDR_LSB = 2;

  // --------------------------------------------------
  // Slave registers
  // --------------------------------------------------
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg0; // CTRL
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg1; // WR_ADDR
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg2; // WR_LEN
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg3; // STATUS (RO)
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg4; // RD_ADDR (RO)
  reg [C_S_AXI_DATA_WIDTH-1:0] slv_reg5; // RD_LEN  (RO)

  assign host_wr_addr = slv_reg1;
  assign host_wr_len  = slv_reg2;
  assign start_pbs    = slv_reg0[0];

  // --------------------------------------------------
  // AXI write channel (AW and W can arrive independently)
  // Single outstanding write response.
  // --------------------------------------------------
  reg [C_S_AXI_ADDR_WIDTH-1:0] awaddr_lat;
  reg [C_S_AXI_DATA_WIDTH-1:0] wdata_lat;
  reg [(C_S_AXI_DATA_WIDTH/8)-1:0] wstrb_lat;
  reg aw_captured;
  reg w_captured;

  wire aw_hs = S_AXI_AWVALID && S_AXI_AWREADY;
  wire w_hs  = S_AXI_WVALID  && S_AXI_WREADY;

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      S_AXI_AWREADY <= 1'b0;
      S_AXI_WREADY  <= 1'b0;
    end else begin
      S_AXI_AWREADY <= (~aw_captured) && (~S_AXI_BVALID);
      S_AXI_WREADY  <= (~w_captured)  && (~S_AXI_BVALID);
    end
  end

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      awaddr_lat  <= {C_S_AXI_ADDR_WIDTH{1'b0}};
      wdata_lat   <= {C_S_AXI_DATA_WIDTH{1'b0}};
      wstrb_lat   <= {(C_S_AXI_DATA_WIDTH/8){1'b0}};
      aw_captured <= 1'b0;
      w_captured  <= 1'b0;
    end else begin
      if (aw_hs) begin
        awaddr_lat  <= S_AXI_AWADDR;
        aw_captured <= 1'b1;
      end
      if (w_hs) begin
        wdata_lat   <= S_AXI_WDATA;
        wstrb_lat   <= S_AXI_WSTRB;
        w_captured  <= 1'b1;
      end
    end
  end

  wire do_write = aw_captured && w_captured && (~S_AXI_BVALID);
  wire [2:0] aw_sel_lat = awaddr_lat[ADDR_LSB+2:ADDR_LSB];

  integer b;

  // --------------------------------------------------
  // Register file + write response + STATUS handling
  // --------------------------------------------------
  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      slv_reg0 <= 0;
      slv_reg1 <= 0;
      slv_reg2 <= 0;

      slv_reg3 <= 0;
      slv_reg4 <= 0;
      slv_reg5 <= 0;

      S_AXI_BVALID <= 1'b0;
      S_AXI_BRESP  <= 2'b00;

      aw_captured <= 1'b0;
      w_captured  <= 1'b0;
    end else begin
      // --- live STATUS + latch DONE sticky
      slv_reg3[0] <= pbs_busy;
      if (pbs_done)
        slv_reg3[1] <= 1'b1; // sticky
      slv_reg3[C_S_AXI_DATA_WIDTH-1:2] <= 0;

      // --- RO mirrors
      slv_reg4 <= host_rd_addr;
      slv_reg5 <= host_rd_len;

      // --- complete write when both beats captured
      if (do_write) begin
        case (aw_sel_lat)
          3'h0: begin
            for (b=0; b<C_S_AXI_DATA_WIDTH/8; b=b+1)
              if (wstrb_lat[b]) slv_reg0[b*8+:8] <= wdata_lat[b*8+:8];

            // clear sticky DONE when SW writes CTRL[0]=1 (new start)
            if (wstrb_lat[0] && wdata_lat[0])
              slv_reg3[1] <= 1'b0;
          end

          3'h1: begin
            for (b=0; b<C_S_AXI_DATA_WIDTH/8; b=b+1)
              if (wstrb_lat[b]) slv_reg1[b*8+:8] <= wdata_lat[b*8+:8];
          end

          3'h2: begin
            for (b=0; b<C_S_AXI_DATA_WIDTH/8; b=b+1)
              if (wstrb_lat[b]) slv_reg2[b*8+:8] <= wdata_lat[b*8+:8];
          end

          default: ; // ignore writes to RO regs
        endcase

        S_AXI_BVALID <= 1'b1;
        S_AXI_BRESP  <= 2'b00; // OKAY

        aw_captured <= 1'b0;
        w_captured  <= 1'b0;

      end else if (S_AXI_BVALID && S_AXI_BREADY) begin
        S_AXI_BVALID <= 1'b0;
      end

      // --- HW auto-clear START when done (level START contract)
      if (pbs_done)
        slv_reg0[0] <= 1'b0;
    end
  end

  // --------------------------------------------------
  // AXI read channel (single outstanding)
  // --------------------------------------------------
  wire [2:0] ar_sel = S_AXI_ARADDR[ADDR_LSB+2:ADDR_LSB];

  always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
      S_AXI_ARREADY <= 1'b0;
      S_AXI_RVALID  <= 1'b0;
      S_AXI_RRESP   <= 2'b00;
      S_AXI_RDATA   <= 0;
    end else begin
      S_AXI_ARREADY <= ~S_AXI_RVALID;

      if (S_AXI_ARVALID && S_AXI_ARREADY) begin
        S_AXI_RVALID <= 1'b1;
        S_AXI_RRESP  <= 2'b00;
        case (ar_sel)
          3'h0: S_AXI_RDATA <= slv_reg0;
          3'h1: S_AXI_RDATA <= slv_reg1;
          3'h2: S_AXI_RDATA <= slv_reg2;
          3'h3: S_AXI_RDATA <= slv_reg3;
          3'h4: S_AXI_RDATA <= slv_reg4;
          3'h5: S_AXI_RDATA <= slv_reg5;
          default: S_AXI_RDATA <= 0;
        endcase
      end else if (S_AXI_RVALID && S_AXI_RREADY) begin
        S_AXI_RVALID <= 1'b0;
      end
    end
  end

endmodule

`timescale 1 ns / 1 ps

	module tfhe_w_controller #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 4
	)
	(
		// Users to add ports here
		output reg [7:0] user_led,
		// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave) 
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY
	);

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 1;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 4
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
	integer	 byte_index;

	// User LED logic
    reg [31:0] led_cnt;
    reg [7:0]  led_shift;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	 //state machine varibles 
	 reg [1:0] state_write;
	 reg [1:0] state_read;
	 //State machine local parameters
	 localparam Idle = 2'b00,Raddr = 2'b10,Rdata = 2'b11 ,Waddr = 2'b10,Wdata = 2'b11;
	// Implement Write state machine
	// Outstanding write transactions are not supported by the slave i.e., master should assert bready to receive response on or before it starts sending the new transaction
	always @(posedge S_AXI_ACLK)                                 
	  begin                                 
	     if (S_AXI_ARESETN == 1'b0)                                 
	       begin                                 
	         axi_awready <= 0;                                 
	         axi_wready <= 0;                                 
	         axi_bvalid <= 0;                                 
	         axi_bresp <= 0;                                 
	         axi_awaddr <= 0;                                 
	         state_write <= Idle;                                 
	       end                                 
	     else                                  
	       begin                                 
	         case(state_write)                                 
	           Idle:                                      
	             begin                                 
	               if(S_AXI_ARESETN == 1'b1)                                  
	                 begin                                 
	                   axi_awready <= 1'b1;                                 
	                   axi_wready <= 1'b1;                                 
	                   state_write <= Waddr;                                 
	                 end                                 
	               else state_write <= state_write;                                 
	             end                                 
	           Waddr:        //At this state, slave is ready to receive address along with corresponding control signals and first data packet. Response valid is also handled at this state                                 
	             begin                                 
	               if (S_AXI_AWVALID && S_AXI_AWREADY)                                 
	                  begin                                 
	                    axi_awaddr <= S_AXI_AWADDR;                                 
	                    if(S_AXI_WVALID)                                  
	                      begin                                   
	                        axi_awready <= 1'b1;                                 
	                        state_write <= Waddr;                                 
	                        axi_bvalid <= 1'b1;                                 
	                      end                                 
	                    else                                  
	                      begin                                 
	                        axi_awready <= 1'b0;                                 
	                        state_write <= Wdata;                                 
	                        if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;                                 
	                      end                                 
	                  end                                 
	               else                                  
	                  begin                                 
	                    state_write <= state_write;                                 
	                    if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;                                 
	                   end                                 
	             end                                 
	          Wdata:        //At this state, slave is ready to receive the data packets until the number of transfers is equal to burst length                                 
	             begin                                 
	               if (S_AXI_WVALID)                                 
	                 begin                                 
	                   state_write <= Waddr;                                 
	                   axi_bvalid <= 1'b1;                                 
	                   axi_awready <= 1'b1;                                 
	                 end                                 
	                else                                  
	                 begin                                 
	                   state_write <= state_write;                                 
	                   if (S_AXI_BREADY && axi_bvalid) axi_bvalid <= 1'b0;                                 
	                 end                                              
	             end                                 
	          endcase                                 
	        end                                 
	      end                                 

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      slv_reg3 <= 0;
	    end 
	  else begin
	    if (S_AXI_WVALID)
	      begin
	        case ( (S_AXI_AWVALID) ? S_AXI_AWADDR[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] : axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	          2'h0:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 0
	                slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          2'h1:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          2'h2:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 2
	                slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          2'h3:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          default : begin
	                      slv_reg0 <= slv_reg0;
	                      slv_reg1 <= slv_reg1;
	                      slv_reg2 <= slv_reg2;
	                      slv_reg3 <= slv_reg3;
	                    end
	        endcase
	      end
	  end
	end    

	// Implement read state machine
	  always @(posedge S_AXI_ACLK)                                       
	    begin                                       
	      if (S_AXI_ARESETN == 1'b0)                                       
	        begin                                       
	         //asserting initial values to all 0's during reset                                       
	         axi_arready <= 1'b0;                                       
	         axi_rvalid <= 1'b0;                                       
	         axi_rresp <= 1'b0;                                       
	         state_read <= Idle;                                       
	        end                                       
	      else                                       
	        begin                                       
	          case(state_read)                                       
	            Idle:     //Initial state inidicating reset is done and ready to receive read/write transactions                                       
	              begin                                                
	                if (S_AXI_ARESETN == 1'b1)                                        
	                  begin                                       
	                    state_read <= Raddr;                                       
	                    axi_arready <= 1'b1;                                       
	                  end                                       
	                else state_read <= state_read;                                       
	              end                                       
	            Raddr:        //At this state, slave is ready to receive address along with corresponding control signals                                       
	              begin                                       
	                if (S_AXI_ARVALID && S_AXI_ARREADY)                                       
	                  begin                                       
	                    state_read <= Rdata;                                       
	                    axi_araddr <= S_AXI_ARADDR;                                       
	                    axi_rvalid <= 1'b1;                                       
	                    axi_arready <= 1'b0;                                       
	                  end                                       
	                else state_read <= state_read;                                       
	              end                                       
	            Rdata:        //At this state, slave is ready to send the data packets until the number of transfers is equal to burst length                                       
	              begin                                           
	                if (S_AXI_RVALID && S_AXI_RREADY)                                       
	                  begin                                       
	                    axi_rvalid <= 1'b0;                                       
	                    axi_arready <= 1'b1;                                       
	                    state_read <= Raddr;                                       
	                  end                                       
	                else state_read <= state_read;                                       
	              end                                       
	           endcase                                       
	          end                                       
	        end                                         
	// Implement memory mapped register select and read logic generation
	  assign S_AXI_RDATA = (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 2'h0) ? slv_reg0 : (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 2'h1) ? slv_reg1 : (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 2'h2) ? slv_reg2 : (axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] == 2'h3) ? slv_reg3 : 0; 

	// Add user logic here

	// Simple LED pattern generator
    // slv_reg0[2:0] selects pattern
    // slv_reg1 sets speed (divider)
    always @(posedge S_AXI_ACLK) begin
        if (S_AXI_ARESETN == 1'b0) begin
            led_cnt   <= 32'd0;
            led_shift <= 8'b0000_0001;
            user_led  <= 8'b0000_0000;
        end else begin
            // Counter for slow blinking / shifting
            led_cnt <= led_cnt + 1;

            // Use slv_reg1 as programmable divider, or fall back to a default
            // if it is zero.
            if (led_cnt >= (slv_reg1 != 32'd0 ? slv_reg1 : 32'd25_000_000)) begin
                led_cnt <= 32'd0;

                case (slv_reg0[2:0])
                    3'b000: begin
                        // All off
                        user_led <= 8'b0000_0000;
                    end

                    3'b001: begin
                        // All on
                        user_led <= 8'b1111_1111;
                    end

                    3'b010: begin
                        // Walking 1 (left)
                        led_shift <= (led_shift == 8'b1000_0000) ?
                                     8'b0000_0001 :
                                     (led_shift << 1);
                        user_led <= led_shift;
                    end

                    3'b011: begin
                        // Walking 1 (right)
                        led_shift <= (led_shift == 8'b0000_0001) ?
                                     8'b1000_0000 :
                                     (led_shift >> 1);
                        user_led <= led_shift;
                    end

                    3'b100: begin
                        // Blink all
                        user_led <= ~user_led;
                    end

                    3'b101: begin
                        // Upper nibble bar graph from slv_reg2[3:0]
                        user_led <= {slv_reg2[3:0], slv_reg2[3:0]};
                    end

                    default: begin
                        // Default pattern: mirror slv_reg3[7:0]
                        user_led <= slv_reg3[7:0];
                    end
                endcase
            end
        end
    end

	// User logic ends

	endmodule
