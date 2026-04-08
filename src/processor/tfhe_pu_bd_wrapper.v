//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//Copyright 2022-2025 Advanced Micro Devices, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2025.1 (lin64) Build 6140274 Wed May 21 22:58:25 MDT 2025
//Date        : Wed Jan 28 15:41:37 2026
//Host        : ssi-fpgaserv running 64-bit Ubuntu 24.04.3 LTS
//Command     : generate_target tfhe_pu_bd_wrapper.bd
//Design      : tfhe_pu_bd_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module tfhe_pu_bd_wrapper
   (default_100mhz_clk_clk_n,
    default_100mhz_clk_clk_p,
    hbm_ref_clk_0,
    hbm_ref_clk_1,
    leds,
    pci_express_x8_rxn,
    pci_express_x8_rxp,
    pci_express_x8_txn,
    pci_express_x8_txp,
    pcie_perstn,
    pcie_refclk_clk_n,
    pcie_refclk_clk_p);
  input default_100mhz_clk_clk_n;
  input default_100mhz_clk_clk_p;
  input hbm_ref_clk_0;
  input hbm_ref_clk_1;
  output [7:0]leds;
  input [7:0]pci_express_x8_rxn;
  input [7:0]pci_express_x8_rxp;
  output [7:0]pci_express_x8_txn;
  output [7:0]pci_express_x8_txp;
  input pcie_perstn;
  input pcie_refclk_clk_n;
  input pcie_refclk_clk_p;

  wire default_100mhz_clk_clk_n;
  wire default_100mhz_clk_clk_p;
  wire hbm_ref_clk_0;
  wire hbm_ref_clk_1;
  wire [7:0]leds;
  wire [7:0]pci_express_x8_rxn;
  wire [7:0]pci_express_x8_rxp;
  wire [7:0]pci_express_x8_txn;
  wire [7:0]pci_express_x8_txp;
  wire pcie_perstn;
  wire pcie_refclk_clk_n;
  wire pcie_refclk_clk_p;

  tfhe_pu_bd tfhe_pu_bd_i
       (.default_100mhz_clk_clk_n(default_100mhz_clk_clk_n),
        .default_100mhz_clk_clk_p(default_100mhz_clk_clk_p),
        .hbm_ref_clk_0(hbm_ref_clk_0),
        .hbm_ref_clk_1(hbm_ref_clk_1),
        .leds(leds),
        .pci_express_x8_rxn(pci_express_x8_rxn),
        .pci_express_x8_rxp(pci_express_x8_rxp),
        .pci_express_x8_txn(pci_express_x8_txn),
        .pci_express_x8_txp(pci_express_x8_txp),
        .pcie_perstn(pcie_perstn),
        .pcie_refclk_clk_n(pcie_refclk_clk_n),
        .pcie_refclk_clk_p(pcie_refclk_clk_p));
endmodule
