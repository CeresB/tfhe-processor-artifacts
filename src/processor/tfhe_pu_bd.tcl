
################################################################
# This is a generated script based on design: tfhe_pu_bd
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2025.1
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   if { [string compare $scripts_vivado_version $current_vivado_version] > 0 } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2042 -severity "ERROR" " This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Sourcing the script failed since it was created with a future version of Vivado."}

   } else {
     catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   }

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source tfhe_pu_bd_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# tfhe_block

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xcvu37p-fsvh2892-2L-e
   set_property BOARD_PART xilinx.com:vcu128:part0:1.0 [current_project]
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name tfhe_pu_bd

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
xilinx.com:ip:clk_wiz:6.0\
xilinx.com:ip:smartconnect:1.0\
xilinx.com:ip:xpm_cdc_gen:1.0\
xilinx.com:ip:util_ds_buf:2.2\
xilinx.com:ip:xdma:4.2\
xilinx.com:ip:axi_clock_converter:2.1\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

##################################################################
# CHECK Modules
##################################################################
set bCheckModules 1
if { $bCheckModules == 1 } {
   set list_check_mods "\ 
tfhe_block\
"

   set list_mods_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2020 -severity "INFO" "Checking if the following modules exist in the project's sources: $list_check_mods ."

   foreach mod_vlnv $list_check_mods {
      if { [can_resolve_reference $mod_vlnv] == 0 } {
         lappend list_mods_missing $mod_vlnv
      }
   }

   if { $list_mods_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2021 -severity "ERROR" "The following module(s) are not found in the project: $list_mods_missing" }
      common::send_gid_msg -ssname BD::TCL -id 2022 -severity "INFO" "Please add source files for the missing module(s) above."
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################



# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set default_100mhz_clk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 default_100mhz_clk ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {100000000} \
   ] $default_100mhz_clk

  set pci_express_x8 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:pcie_7x_mgt_rtl:1.0 pci_express_x8 ]

  set pcie_refclk [ create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 pcie_refclk ]


  # Create ports
  set leds [ create_bd_port -dir O -from 7 -to 0 leds ]
  set hbm_ref_clk_0 [ create_bd_port -dir I -type clk -freq_hz 100000000 hbm_ref_clk_0 ]
  set pcie_perstn [ create_bd_port -dir I -type rst pcie_perstn ]
  set_property -dict [ list \
   CONFIG.POLARITY {ACTIVE_LOW} \
 ] $pcie_perstn
  set hbm_ref_clk_1 [ create_bd_port -dir I -type clk -freq_hz 100000000 hbm_ref_clk_1 ]

  # Create instance: clk_wiz_0, and set properties
  set clk_wiz_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0 ]
  set_property -dict [list \
    CONFIG.AUTO_PRIMITIVE {PLL} \
    CONFIG.CLKIN2_JITTER_PS {149.99} \
    CONFIG.CLKOUT1_DRIVES {BUFG} \
    CONFIG.CLKOUT1_JITTER {109.471} \
    CONFIG.CLKOUT1_PHASE_ERROR {82.897} \
    CONFIG.CLKOUT2_DRIVES {Buffer} \
    CONFIG.CLKOUT2_JITTER {88.518} \
    CONFIG.CLKOUT2_PHASE_ERROR {82.897} \
    CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {325} \
    CONFIG.CLKOUT2_USED {true} \
    CONFIG.CLKOUT3_DRIVES {Buffer} \
    CONFIG.CLKOUT3_JITTER {144.719} \
    CONFIG.CLKOUT3_PHASE_ERROR {114.212} \
    CONFIG.CLKOUT3_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT3_USED {false} \
    CONFIG.CLKOUT4_DRIVES {Buffer} \
    CONFIG.CLKOUT5_DRIVES {Buffer} \
    CONFIG.CLKOUT6_DRIVES {Buffer} \
    CONFIG.CLKOUT7_DRIVES {Buffer} \
    CONFIG.CLK_IN1_BOARD_INTERFACE {default_100mhz_clk} \
    CONFIG.CLK_IN2_BOARD_INTERFACE {Custom} \
    CONFIG.CLK_OUT1_PORT {apb_clk} \
    CONFIG.CLK_OUT2_PORT {tfhe_clk} \
    CONFIG.CLK_OUT3_PORT {clk_out3} \
    CONFIG.FEEDBACK_SOURCE {FDBK_AUTO} \
    CONFIG.MMCM_BANDWIDTH {OPTIMIZED} \
    CONFIG.MMCM_CLKFBOUT_MULT_F {13} \
    CONFIG.MMCM_CLKIN2_PERIOD {10.000} \
    CONFIG.MMCM_CLKOUT0_DIVIDE_F {13} \
    CONFIG.MMCM_CLKOUT1_DIVIDE {4} \
    CONFIG.MMCM_CLKOUT2_DIVIDE {1} \
    CONFIG.MMCM_COMPENSATION {AUTO} \
    CONFIG.NUM_OUT_CLKS {2} \
    CONFIG.OPTIMIZE_CLOCKING_STRUCTURE_EN {true} \
    CONFIG.PRIMITIVE {Auto} \
    CONFIG.PRIM_SOURCE {Differential_clock_capable_pin} \
    CONFIG.RESET_BOARD_INTERFACE {Custom} \
    CONFIG.SECONDARY_SOURCE {Single_ended_clock_capable_pin} \
    CONFIG.USE_BOARD_FLOW {true} \
    CONFIG.USE_INCLK_SWITCHOVER {false} \
    CONFIG.USE_LOCKED {false} \
    CONFIG.USE_RESET {false} \
  ] $clk_wiz_0


  # Create instance: tfhe_block_0, and set properties
  set block_name tfhe_block
  set block_cell_name tfhe_block_0
  if { [catch {set tfhe_block_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $tfhe_block_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: smartconnect_1, and set properties
  set smartconnect_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 smartconnect_1 ]
  set_property -dict [list \
    CONFIG.NUM_MI {13} \
    CONFIG.NUM_SI {1} \
  ] $smartconnect_1


  # Create instance: xpm_cdc_gen_0, and set properties
  set xpm_cdc_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xpm_cdc_gen:1.0 xpm_cdc_gen_0 ]
  set_property CONFIG.CDC_TYPE {xpm_cdc_async_rst} $xpm_cdc_gen_0


  # Create instance: util_ds_buf_0, and set properties
  set util_ds_buf_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:util_ds_buf:2.2 util_ds_buf_0 ]
  set_property CONFIG.DIFF_CLK_IN_BOARD_INTERFACE {pcie_refclk} $util_ds_buf_0


  # Create instance: xdma_1, and set properties
  set xdma_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xdma:4.2 xdma_1 ]
  set_property -dict [list \
    CONFIG.PCIE_BOARD_INTERFACE {pci_express_x8} \
    CONFIG.SYS_RST_N_BOARD_INTERFACE {pcie_perstn} \
    CONFIG.axilite_master_en {true} \
    CONFIG.cfg_mgmt_if {false} \
    CONFIG.mode_selection {Advanced} \
    CONFIG.pcie_extended_tag {true} \
    CONFIG.pf0_msi_enabled {false} \
    CONFIG.pl_link_cap_max_link_speed {8.0_GT/s} \
    CONFIG.xdma_rnum_chnl {1} \
    CONFIG.xdma_wnum_chnl {1} \
  ] $xdma_1


  # Create instance: axi_clock_converter_0, and set properties
  set axi_clock_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 axi_clock_converter_0 ]
  set_property CONFIG.ACLK_ASYNC {1} $axi_clock_converter_0


  # Create instance: axi_clock_converter_1, and set properties
  set axi_clock_converter_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_clock_converter:2.1 axi_clock_converter_1 ]
  set_property CONFIG.ACLK_ASYNC {1} $axi_clock_converter_1


  # Create instance: xpm_cdc_gen_1, and set properties
  set xpm_cdc_gen_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xpm_cdc_gen:1.0 xpm_cdc_gen_1 ]
  set_property CONFIG.CDC_TYPE {xpm_cdc_async_rst} $xpm_cdc_gen_1


  # Create interface connections
  connect_bd_intf_net -intf_net axi_clock_converter_0_M_AXI [get_bd_intf_pins smartconnect_1/S00_AXI] [get_bd_intf_pins axi_clock_converter_0/M_AXI]
  connect_bd_intf_net -intf_net axi_clock_converter_1_M_AXI [get_bd_intf_pins tfhe_block_0/s00_axi] [get_bd_intf_pins axi_clock_converter_1/M_AXI]
  connect_bd_intf_net -intf_net default_100mhz_clk_1 [get_bd_intf_ports default_100mhz_clk] [get_bd_intf_pins clk_wiz_0/CLK_IN1_D]
  connect_bd_intf_net -intf_net pcie_refclk_1 [get_bd_intf_ports pcie_refclk] [get_bd_intf_pins util_ds_buf_0/CLK_IN_D]
  connect_bd_intf_net -intf_net smartconnect_1_M00_AXI [get_bd_intf_pins smartconnect_1/M00_AXI] [get_bd_intf_pins tfhe_block_0/AXI_00]
  connect_bd_intf_net -intf_net smartconnect_1_M01_AXI [get_bd_intf_pins smartconnect_1/M01_AXI] [get_bd_intf_pins tfhe_block_0/AXI_01]
  connect_bd_intf_net -intf_net smartconnect_1_M02_AXI [get_bd_intf_pins smartconnect_1/M02_AXI] [get_bd_intf_pins tfhe_block_0/AXI_02]
  connect_bd_intf_net -intf_net smartconnect_1_M03_AXI [get_bd_intf_pins tfhe_block_0/AXI_03] [get_bd_intf_pins smartconnect_1/M03_AXI]
  connect_bd_intf_net -intf_net smartconnect_1_M04_AXI [get_bd_intf_pins smartconnect_1/M04_AXI] [get_bd_intf_pins tfhe_block_0/AXI_04]
  connect_bd_intf_net -intf_net smartconnect_1_M05_AXI [get_bd_intf_pins smartconnect_1/M05_AXI] [get_bd_intf_pins tfhe_block_0/AXI_05]
  connect_bd_intf_net -intf_net smartconnect_1_M06_AXI [get_bd_intf_pins smartconnect_1/M06_AXI] [get_bd_intf_pins tfhe_block_0/AXI_06]
  connect_bd_intf_net -intf_net smartconnect_1_M07_AXI [get_bd_intf_pins tfhe_block_0/AXI_07] [get_bd_intf_pins smartconnect_1/M07_AXI]
  connect_bd_intf_net -intf_net smartconnect_1_M08_AXI [get_bd_intf_pins tfhe_block_0/AXI_16] [get_bd_intf_pins smartconnect_1/M08_AXI]
  connect_bd_intf_net -intf_net smartconnect_1_M09_AXI [get_bd_intf_pins smartconnect_1/M09_AXI] [get_bd_intf_pins tfhe_block_0/AXI_17]
  connect_bd_intf_net -intf_net smartconnect_1_M10_AXI [get_bd_intf_pins tfhe_block_0/AXI_18] [get_bd_intf_pins smartconnect_1/M10_AXI]
  connect_bd_intf_net -intf_net smartconnect_1_M11_AXI [get_bd_intf_pins smartconnect_1/M11_AXI] [get_bd_intf_pins tfhe_block_0/AXI_19]
  connect_bd_intf_net -intf_net smartconnect_1_M12_AXI [get_bd_intf_pins tfhe_block_0/AXI_20] [get_bd_intf_pins smartconnect_1/M12_AXI]
  connect_bd_intf_net -intf_net xdma_1_M_AXI [get_bd_intf_pins axi_clock_converter_0/S_AXI] [get_bd_intf_pins xdma_1/M_AXI]
  connect_bd_intf_net -intf_net xdma_1_M_AXI_LITE [get_bd_intf_pins xdma_1/M_AXI_LITE] [get_bd_intf_pins axi_clock_converter_1/S_AXI]
  connect_bd_intf_net -intf_net xdma_1_pcie_mgt [get_bd_intf_ports pci_express_x8] [get_bd_intf_pins xdma_1/pcie_mgt]

  # Create port connections
  connect_bd_net -net clk_wiz_0_apb_clk  [get_bd_pins clk_wiz_0/apb_clk] \
  [get_bd_pins xpm_cdc_gen_0/dest_clk] \
  [get_bd_pins tfhe_block_0/APB_0_PCLK]
  connect_bd_net -net clk_wiz_0_tfhe_clk  [get_bd_pins clk_wiz_0/tfhe_clk] \
  [get_bd_pins axi_clock_converter_0/m_axi_aclk] \
  [get_bd_pins smartconnect_1/aclk] \
  [get_bd_pins axi_clock_converter_1/m_axi_aclk] \
  [get_bd_pins xpm_cdc_gen_1/dest_clk] \
  [get_bd_pins tfhe_block_0/TFHE_CLK] \
  [get_bd_pins tfhe_block_0/s00_axi_aclk] \
  [get_bd_pins tfhe_block_0/AXI_00_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_01_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_02_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_03_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_04_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_05_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_06_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_07_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_16_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_17_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_18_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_19_ACLK] \
  [get_bd_pins tfhe_block_0/AXI_20_ACLK]
  connect_bd_net -net hbm_ref_clk_0_1  [get_bd_ports hbm_ref_clk_0] \
  [get_bd_pins tfhe_block_0/HBM_REF_CLK_0]
  connect_bd_net -net hbm_ref_clk_1_1  [get_bd_ports hbm_ref_clk_1] \
  [get_bd_pins tfhe_block_0/HBM_REF_CLK_1]
  connect_bd_net -net pcie_perstn_1  [get_bd_ports pcie_perstn] \
  [get_bd_pins xdma_1/sys_rst_n]
  connect_bd_net -net tfhe_block_0_user_led  [get_bd_pins tfhe_block_0/user_led] \
  [get_bd_ports leds]
  connect_bd_net -net util_ds_buf_0_IBUF_DS_ODIV2  [get_bd_pins util_ds_buf_0/IBUF_DS_ODIV2] \
  [get_bd_pins xdma_1/sys_clk]
  connect_bd_net -net util_ds_buf_0_IBUF_OUT  [get_bd_pins util_ds_buf_0/IBUF_OUT] \
  [get_bd_pins xdma_1/sys_clk_gt]
  connect_bd_net -net xdma_0_axi_aresetn1  [get_bd_pins xdma_1/axi_aresetn] \
  [get_bd_pins axi_clock_converter_0/s_axi_aresetn] \
  [get_bd_pins axi_clock_converter_1/s_axi_aresetn]
  connect_bd_net -net xdma_1_axi_aclk  [get_bd_pins xdma_1/axi_aclk] \
  [get_bd_pins axi_clock_converter_0/s_axi_aclk] \
  [get_bd_pins axi_clock_converter_1/s_axi_aclk] \
  [get_bd_pins xpm_cdc_gen_1/src_arst] \
  [get_bd_pins xpm_cdc_gen_0/src_arst]
  connect_bd_net -net xpm_cdc_gen_0_dest_arst  [get_bd_pins xpm_cdc_gen_0/dest_arst] \
  [get_bd_pins tfhe_block_0/APB_0_PRESET_N]
  connect_bd_net -net xpm_cdc_gen_1_dest_out  [get_bd_pins xpm_cdc_gen_1/dest_arst] \
  [get_bd_pins smartconnect_1/aresetn] \
  [get_bd_pins axi_clock_converter_0/m_axi_aresetn] \
  [get_bd_pins axi_clock_converter_1/m_axi_aresetn] \
  [get_bd_pins tfhe_block_0/s00_axi_aresetn] \
  [get_bd_pins tfhe_block_0/AXI_ARESET_N]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x20000000 -with_name SEG_tfhe_block_0_reg0 -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_00/reg0] -force
  assign_bd_address -offset 0x20000000 -range 0x20000000 -with_name SEG_tfhe_block_0_reg0_1 -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_01/reg0] -force
  assign_bd_address -offset 0x40000000 -range 0x20000000 -with_name SEG_tfhe_block_0_reg0_2 -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_04/reg0] -force
  assign_bd_address -offset 0x60000000 -range 0x20000000 -with_name SEG_tfhe_block_0_reg0_3 -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_07/reg0] -force
  assign_bd_address -offset 0xE0000000 -range 0x20000000 -with_name SEG_tfhe_block_0_reg0_7 -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_02/reg0] -force
  assign_bd_address -offset 0x000100000000 -range 0x20000000 -with_name SEG_tfhe_block_0_reg0_8 -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_03/reg0] -force
  assign_bd_address -offset 0x000120000000 -range 0x20000000 -with_name SEG_tfhe_block_0_reg0_9 -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_05/reg0] -force
  assign_bd_address -offset 0x000140000000 -range 0x20000000 -with_name SEG_tfhe_block_0_reg0_10 -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_06/reg0] -force
  assign_bd_address -offset 0x00000000 -range 0x000100000000 -target_address_space [get_bd_addr_spaces xdma_1/M_AXI_LITE] [get_bd_addr_segs tfhe_block_0/s00_axi/reg0] -force

  # Exclude Address Segments
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_17/reg0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_19/reg0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_20/reg0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_16/reg0]
  exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces xdma_1/M_AXI] [get_bd_addr_segs tfhe_block_0/AXI_18/reg0]


  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################


# add and configure the left hbm stack
create_ip -name hbm -vendor xilinx.com -library ip -version 1.0 -module_name hbm_0
set_property -dict [list \
CONFIG.USER_APB_EN {false} \
CONFIG.USER_HBM_TCK_0 {325} \
CONFIG.USER_MC0_EN_DATA_MASK {false} \
CONFIG.USER_MC0_TRAFFIC_OPTION {Linear} \
CONFIG.USER_SWITCH_ENABLE_00 {FALSE} \
CONFIG.USER_XSDB_INTF_EN {FALSE} \
] [get_ips hbm_0]

# add and configure the right hbm stack
create_ip -name hbm -vendor xilinx.com -library ip -version 1.0 -module_name hbm_1
set_property -dict [list \
CONFIG.USER_APB_EN {false} \
CONFIG.USER_HBM_TCK_0 {325} \
CONFIG.USER_MC0_EN_DATA_MASK {false} \
CONFIG.USER_MC0_TRAFFIC_OPTION {Linear} \
CONFIG.USER_SINGLE_STACK_SELECTION {RIGHT} \
CONFIG.USER_SWITCH_ENABLE_00 {FALSE} \
CONFIG.USER_XSDB_INTF_EN {FALSE} \
] [get_ips hbm_1]

create_root_design ""


# set tfhe_pu_top as top module
set_property top tfhe_pu_top [current_fileset]

# disable out-of-context synthesis
set_property GENERATE_SYNTH_CHECKPOINT FALSE [get_files *.xci]
generate_target all [get_files tfhe_pu_bd.bd]

# refresh block design
update_module_reference tfhe_pu_bd_tfhe_block_0_0

