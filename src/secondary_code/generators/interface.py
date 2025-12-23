def print_axi_ports(start=0, end=15):
    template = """
        // --------------------------------------------------
        // AXI_{i:02d}
        // --------------------------------------------------
        input  wire [HBM_ADDR_WIDTH-1:0]               AXI_{i:02d}_ARADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]      AXI_{i:02d}_ARBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]             AXI_{i:02d}_ARID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]       AXI_{i:02d}_ARLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]      AXI_{i:02d}_ARSIZE,
        input  wire                                    AXI_{i:02d}_ARVALID,
        output wire                                    AXI_{i:02d}_ARREADY,

        input  wire [HBM_ADDR_WIDTH-1:0]               AXI_{i:02d}_AWADDR,
        input  wire [HBM_BURSTMODE_BIT_WIDTH-1:0]      AXI_{i:02d}_AWBURST,
        input  wire [HBM_ID_BIT_WIDTH-1:0]             AXI_{i:02d}_AWID,
        input  wire [HBM_BURSTLEN_BIT_WIDTH-1:0]       AXI_{i:02d}_AWLEN,
        input  wire [HBM_BURSTSIZE_BIT_WIDTH-1:0]      AXI_{i:02d}_AWSIZE,
        input  wire                                    AXI_{i:02d}_AWVALID,
        output wire                                    AXI_{i:02d}_AWREADY,

        input  wire                                    AXI_{i:02d}_RREADY,
        input  wire                                    AXI_{i:02d}_BREADY,

        input  wire [HBM_DATA_WIDTH-1:0]               AXI_{i:02d}_WDATA,
        input  wire                                    AXI_{i:02d}_WLAST,
        input  wire [HBM_BYTES_PER_PS_PORT-1:0]        AXI_{i:02d}_WSTRB,
        input  wire                                    AXI_{i:02d}_WVALID,
        output wire                                    AXI_{i:02d}_WREADY,

        output wire [HBM_DATA_WIDTH-1:0]               AXI_{i:02d}_RDATA,
        output wire [HBM_ID_BIT_WIDTH-1:0]             AXI_{i:02d}_RID,
        output wire                                    AXI_{i:02d}_RLAST,
        output wire [HBM_RESP_BIT_WIDTH-1:0]           AXI_{i:02d}_RRESP,
        output wire                                    AXI_{i:02d}_RVALID,

        output wire [HBM_ID_BIT_WIDTH-1:0]             AXI_{i:02d}_BID,
        output wire [HBM_RESP_BIT_WIDTH-1:0]           AXI_{i:02d}_BRESP,
        output wire                                    AXI_{i:02d}_BVALID,
    """

    for i in range(start, end + 1):
        print(template.format(i=i))


if __name__ == "__main__":
    print_axi_ports(0, 15)
