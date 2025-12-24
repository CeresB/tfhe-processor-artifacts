
##-----------------------------------------------------------------------------
##
## (c) Copyright 2020-2025 Advanced Micro Devices, Inc. All rights reserved.
##
## This file contains confidential and proprietary information
## of AMD and is protected under U.S. and
## international copyright and other intellectual property
## laws.
##
## DISCLAIMER
## This disclaimer is not a license and does not grant any
## rights to the materials distributed herewith. Except as
## otherwise provided in a valid license issued to you by
## AMD, and to the maximum extent permitted by applicable
## law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
## WITH ALL FAULTS, AND AMD HEREBY DISCLAIMS ALL WARRANTIES
## AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
## BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
## INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
## (2) AMD shall not be liable (whether in contract or tort,
## including negligence, or under any other theory of
## related to, arising under or in connection with these
## materials, including for any direct, or any indirect,
## special, incidental, or consequential loss or damage
## (including loss of data, profits, goodwill, or any type of
## loss or damage suffered as a result of any action brought
## by a third party) even if such damage or loss was
## reasonably foreseeable or AMD had been advised of the
## possibility of the same.
##
## CRITICAL APPLICATIONS
## AMD products are not designed or intended to be fail-
## safe, or for use in any application requiring fail-safe
## performance, such as life-support or safety devices or
## systems, Class III medical devices, nuclear facilities,
## applications related to the deployment of airbags, or any
## other applications that could lead to death, personal
## injury, or severe property or environmental damage
## (individually and collectively, "Critical
## Applications"). Customer assumes the sole risk and
## liability of any use of AMD products in Critical
## Applications, subject only to applicable laws and
## regulations governing limitations on product liability.
##
## THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
## PART OF THIS FILE AT ALL TIMES.
##
##-----------------------------------------------------------------------------
##
## Project    : The Xilinx PCI Express DMA 
## File       : xilinx_pcie_xdma_ref_board.xdc
## Version    : 4.2
##-----------------------------------------------------------------------------
#
# User Configuration
# Link Width   - x16
# Link Speed   - Gen1
# Family       - virtexuplusHBM
# Part         - xcvu37p
# Package      - fsvh2892
# Speed grade  - -2L
#
# PCIe Block INT - 6
# PCIe Block STR - PCIE4C_X1Y0
#

# Xilinx Reference Board is VCU128
###############################################################################
# User Time Names / User Time Groups / Time Specs
###############################################################################
##
## Free Running Clock is Required for IBERT/DRP operations.
##
#############################################################################################################
create_clock -name sys_clk -period 10 [get_ports sys_clk_p]
#
#############################################################################################################
set_false_path -from [get_ports sys_rst_n]
set_property PULLUP true [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS18 [get_ports sys_rst_n]
#
set_property LOC [get_package_pins -filter {PIN_FUNC =~ *_PERSTN0_65}] [get_ports sys_rst_n]
#set_property PACKAGE_PIN AJ31 [get_ports sys_rst_n]
#
set_property CONFIG_VOLTAGE 1.8 [current_design]
#
#############################################################################################################
set_property LOC [get_package_pins -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} -of_objects [get_iobanks -of_objects [get_sites GTYE4_CHANNEL_X1Y7]]]/REFCLK0P]] [get_ports sys_clk_p]
set_property LOC [get_package_pins -of_objects [get_bels [get_sites -filter {NAME =~ *COMMON*} -of_objects [get_iobanks -of_objects [get_sites GTYE4_CHANNEL_X1Y7]]]/REFCLK0N]] [get_ports sys_clk_n]
#
#############################################################################################################
#############################################################################################################
#
#
# BITFILE/BITSTREAM compress options
#
#set_property BITSTREAM.CONFIG.EXTMASTERCCLK_EN div-1 [current_design]
#set_property BITSTREAM.CONFIG.BPI_SYNC_MODE Type1 [current_design]
#set_property CONFIG_MODE BPI16 [current_design]
#set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
#set_property BITSTREAM.CONFIG.UNUSEDPIN Pulldown [current_design]
#
#
set_false_path -to [get_pins -hier *sync_reg[0]/D]
#

#---------------------- Adding waiver for exdes level constraints --------------------------------#

create_waiver -type DRC -id {REQP-1839} -tags "1166691" -scope -internal -user "xdma" -desc "DRC expects synchronous pins to be provided to BRAM inputs. Since synchronization is present one stage before, it is safe to ignore" -objects [list [get_cells -hierarchical -filter {NAME =~ {*/blk_mem_xdma_inst/U0/inst_blk_mem_gen/*.ram}}] [get_cells -hierarchical -filter {NAME =~ {*/AXI_BRAM_CTL/U0/gint_inst*.mem_reg*} && PRIMITIVE_TYPE =~ {*BRAM*}}] [get_cells -hierarchical -filter {NAME =~ {*xdma_inst/U0/gint_inst*.mem_reg*} && PRIMITIVE_TYPE =~ {*BRAM*}}] [get_cells -hierarchical -filter {NAME =~ {*axi_bram_gen_bypass_inst/U0/gint_inst*.mem_reg*} && PRIMITIVE_TYPE =~ {*BRAM*}}] [get_cells -hierarchical -filter {NAME =~ {*/blk_mem_axiLM_inst/U0/inst_blk_mem_gen/*.ram}}] [get_cells -hierarchical -filter {NAME =~ {*/blk_mem_gen_bypass_inst/U0/inst_blk_mem_gen/*.ram}}]]

create_waiver -type CDC -id {CDC-1} -tags "1165825" -scope -internal -user "xdma" -desc "PCIe reset path -Safe to waive" -from [get_ports sys_rst_n] -to [get_pins -hier -filter {NAME =~ {*/user_clk_heartbeat_reg[*]/R}}]


## CLK
set_property IOSTANDARD LVDS [get_ports clk_pin_p]
set_property IOSTANDARD LVDS [get_ports clk_pin_n]
set_property PACKAGE_PIN F35 [get_ports clk_pin_p]
set_property PACKAGE_PIN F36 [get_ports clk_pin_n]

#set_property IOSTANDARD LVCMOS18 [get_ports clk2_pin_p]
## set_property IOSTANDARD LVCMOS18 [get_ports clk2_pin_n]
#set_property IOSTANDARD LVCMOS18 [get_ports clk3_pin_p]
## set_property IOSTANDARD LVCMOS18 [get_ports clk3_pin_n]
###set_property CONFIG_VOLTAGE 1.8 [current_design]
#set_property PACKAGE_PIN BJ4 [get_ports clk2_pin_p]
## set_property PACKAGE_PIN BK3 [get_ports clk2_pin_n]
#set_property PACKAGE_PIN BH51 [get_ports clk3_pin_p]
## set_property PACKAGE_PIN BJ51 [get_ports clk3_pin_n]
set_property CFGBVS GND [current_design]


## LEDs
set_property IOSTANDARD LVCMOS18 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {leds[7]}]

set_property PACKAGE_PIN BH24 [get_ports {leds[0]}]
set_property PACKAGE_PIN BG24 [get_ports {leds[1]}]
set_property PACKAGE_PIN BG25 [get_ports {leds[2]}]
set_property PACKAGE_PIN BF25 [get_ports {leds[3]}]
set_property PACKAGE_PIN BF26 [get_ports {leds[4]}]
set_property PACKAGE_PIN BF27 [get_ports {leds[5]}]
set_property PACKAGE_PIN BG27 [get_ports {leds[6]}]
set_property PACKAGE_PIN BG28 [get_ports {leds[7]}]


