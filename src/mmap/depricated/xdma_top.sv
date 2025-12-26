`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 11/07/2025 04:40:09 PM
// Design Name: 
// Module Name: xdma_hbm_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module xdma_hbm_top#(
  parameter integer PL_LINK_CAP_MAX_LINK_WIDTH = 8,   // VCU128 is x8
  parameter integer PL_LINK_CAP_MAX_LINK_SPEED = 4    // Gen3
)(
  // PCIe x8
  output [PL_LINK_CAP_MAX_LINK_WIDTH-1:0] pci_exp_txp,
  output [PL_LINK_CAP_MAX_LINK_WIDTH-1:0] pci_exp_txn,
  input  [PL_LINK_CAP_MAX_LINK_WIDTH-1:0] pci_exp_rxp,
  input  [PL_LINK_CAP_MAX_LINK_WIDTH-1:0] pci_exp_rxn,

  // PCIe slot refclk + PERST#
  input  sys_clk_p,
  input  sys_clk_n,
  input  sys_rst_n,
  
  input clk_pin_p,
  input clk_pin_n,
  
  output leds

    
);



  // Lane mapping (x8)
  localparam integer LANES = 8;
  wire [LANES-1:0] txp8, txn8, rxp8, rxn8;
  assign rxp8 = pci_exp_rxp[LANES-1:0];
  assign rxn8 = pci_exp_rxn[LANES-1:0];
  assign pci_exp_txp[LANES-1:0] = txp8;
  assign pci_exp_txn[LANES-1:0] = txn8;
  generate if (PL_LINK_CAP_MAX_LINK_WIDTH > LANES) begin : g_pad
    assign pci_exp_txp[PL_LINK_CAP_MAX_LINK_WIDTH-1:LANES] = '0;
    assign pci_exp_txn[PL_LINK_CAP_MAX_LINK_WIDTH-1:LANES] = '0;
  end endgenerate

  // Block design wrapper
  xdma_hbm_wrapper u_bd (
    .default_100mhz_clk_clk_n(clk_pin_n),
    .default_100mhz_clk_clk_p(clk_pin_p),
    .pci_express_x8_rxn(rxn8),
    .pci_express_x8_rxp(rxp8),
    .pci_express_x8_txn(txn8),
    .pci_express_x8_txp(txp8),
    .pcie_perstn       (sys_rst_n),
    .pcie_refclk_clk_n (sys_clk_n),
    .pcie_refclk_clk_p (sys_clk_p),
    .leds(leds)
  );

endmodule
