#!/usr/bin/env python3

NUM_AXI = 16          # AXI_00 ... AXI_31
READ_SEL  = "HBM_R_SELECT"
WRITE_SEL = "HBM_W_SELECT"

def axi(idx):
    return f"AXI_{idx:02d}"

def gen():
    lines = []

    for i in range(NUM_AXI):
        a = axi(i)

        # --------------------------------------------------
        # Clock / Reset (no mux)
        # --------------------------------------------------
        lines.append(f"\t\t{a}_ACLK         => {a}_ACLK,")
        lines.append(f"\t\t{a}_ARESET_N     => {a}_ARESET_N,")

        # --------------------------------------------------
        # READ ADDRESS CHANNEL
        # --------------------------------------------------
        lines.append(f"\t\t{a}_ARADDR       => {a}_ARADDR when {READ_SEL} = '0' else std_logic_vector(i_read_pkgs({i}).araddr),")
        lines.append(f"\t\t{a}_ARBURST      => {a}_ARBURST when {READ_SEL} = '0' else std_logic_vector(hbm_burstmode),")
        lines.append(f"\t\t{a}_ARID         => {a}_ARID when {READ_SEL} = '0' else i_read_pkgs({i}).arid,")
        lines.append(f"\t\t{a}_ARLEN        => {a}_ARLEN when {READ_SEL} = '0' else i_read_pkgs({i}).arlen,")
        lines.append(f"\t\t{a}_ARSIZE       => {a}_ARSIZE when {READ_SEL} = '0' else std_logic_vector(hbm_burstsize),")
        lines.append(f"\t\t{a}_ARVALID      => {a}_ARVALID when {READ_SEL} = '0' else i_read_pkgs({i}).arvalid,")
        lines.append(f"\t\t{a}_ARREADY      => {a}_ARREADY when {READ_SEL} = '0' else o_read_pkgs({i}).arready,")

        # --------------------------------------------------
        # WRITE ADDRESS CHANNEL
        # --------------------------------------------------
        lines.append(f"\t\t{a}_AWADDR       => {a}_AWADDR when {WRITE_SEL} = '0' else std_logic_vector(i_write_pkgs({i}).awaddr),")
        lines.append(f"\t\t{a}_AWBURST      => {a}_AWBURST when {WRITE_SEL} = '0' else std_logic_vector(hbm_burstmode),")
        lines.append(f"\t\t{a}_AWID         => {a}_AWID when {WRITE_SEL} = '0' else i_write_pkgs({i}).awid,")
        lines.append(f"\t\t{a}_AWLEN        => {a}_AWLEN when {WRITE_SEL} = '0' else i_write_pkgs({i}).awlen,")
        lines.append(f"\t\t{a}_AWSIZE       => {a}_AWSIZE when {WRITE_SEL} = '0' else std_logic_vector(hbm_burstsize),")
        lines.append(f"\t\t{a}_AWVALID      => {a}_AWVALID when {WRITE_SEL} = '0' else i_write_pkgs({i}).awvalid,")
        lines.append(f"\t\t{a}_AWREADY      => {a}_AWREADY when {WRITE_SEL} = '0' else o_write_pkgs({i}).awready,")

        # --------------------------------------------------
        # WRITE DATA CHANNEL
        # --------------------------------------------------
        lines.append(f"\t\t{a}_WDATA        => {a}_WDATA when {WRITE_SEL} = '0' else i_write_pkgs({i}).wdata,")
        lines.append(f"\t\t{a}_WLAST        => {a}_WLAST when {WRITE_SEL} = '0' else i_write_pkgs({i}).wlast,")
        lines.append(f"\t\t{a}_WSTRB        => {a}_WSTRB when {WRITE_SEL} = '0' else std_logic_vector(hbm_strobe_setting),")
        lines.append(f"\t\t{a}_WDATA_PARITY => {a}_WDATA_PARITY when {WRITE_SEL} = '0' else i_write_pkgs({i}).wdata_parity,")
        lines.append(f"\t\t{a}_WVALID       => {a}_WVALID when {WRITE_SEL} = '0' else i_write_pkgs({i}).wvalid,")
        lines.append(f"\t\t{a}_WREADY       => {a}_WREADY when {WRITE_SEL} = '0' else o_write_pkgs({i}).wready,")

        # --------------------------------------------------
        # READ DATA CHANNEL
        # --------------------------------------------------
        lines.append(f"\t\t{a}_RDATA        => {a}_RDATA when {READ_SEL} = '0' else o_read_pkgs({i}).rdata,")
        lines.append(f"\t\t{a}_RDATA_PARITY => {a}_RDATA_PARITY when {READ_SEL} = '0' else o_read_pkgs({i}).rdata_parity,")
        lines.append(f"\t\t{a}_RID          => {a}_RID when {READ_SEL} = '0' else o_read_pkgs({i}).rid,")
        lines.append(f"\t\t{a}_RLAST        => {a}_RLAST when {READ_SEL} = '0' else o_read_pkgs({i}).rlast,")
        lines.append(f"\t\t{a}_RRESP        => {a}_RRESP when {READ_SEL} = '0' else o_read_pkgs({i}).rresp,")
        lines.append(f"\t\t{a}_RVALID       => {a}_RVALID when {READ_SEL} = '0' else o_read_pkgs({i}).rvalid,")
        lines.append(f"\t\t{a}_RREADY       => {a}_RREADY when {READ_SEL} = '0' else i_read_pkgs({i}).rready,")

        # --------------------------------------------------
        # WRITE RESPONSE CHANNEL
        # --------------------------------------------------
        lines.append(f"\t\t{a}_BID          => {a}_BID when {WRITE_SEL} = '0' else o_write_pkgs({i}).bid,")
        lines.append(f"\t\t{a}_BRESP        => {a}_BRESP when {WRITE_SEL} = '0' else o_write_pkgs({i}).bresp,")
        lines.append(f"\t\t{a}_BVALID       => {a}_BVALID when {WRITE_SEL} = '0' else o_write_pkgs({i}).bvalid,")
        lines.append(f"\t\t{a}_BREADY       => {a}_BREADY when {WRITE_SEL} = '0' else i_write_pkgs({i}).bready,")

        lines.append("")  # blank line between AXI ports

    return "\n".join(lines)

if __name__ == "__main__":
    print(gen())
