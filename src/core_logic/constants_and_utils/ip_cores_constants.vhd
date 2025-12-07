----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: ip_cores_constants - package
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: constants that reflect ip-core settings
-- Dependencies: see imports
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
     use IEEE.STD_LOGIC_1164.all;
     use IEEE.numeric_std.all;
     use IEEE.math_real.all;
library work;
     use work.constants_utils.all;
     use work.math_utils.all;

package ip_cores_constants is

     constant hbm_8gb_per_stack                : boolean := false;                                       -- otherwise 4gb per stack
     constant hbm_stack_num_ps_ports           : integer := 16;
     constant hbm_coeffs_per_clock_per_ps_port : integer := 4;
     constant hbm_data_width                   : integer := hbm_coeffs_per_clock_per_ps_port * unsigned_polym_coefficient_bit_width;
     constant hbm_worst_case_delay_in_clks     : integer := 150;                                         --150; -- 117 cycles refresh and some buffer
     constant hbm_bytes_per_ps_port            : integer := hbm_data_width / 8;
     constant hbm_ps_port_addr_width           : integer := 23 + 1 * boolean'pos(hbm_8gb_per_stack) + 5; -- +5 because 4:0 unused as we always address 32 bytes = 256 bits at once
     constant hbm_port_and_stack_addr_width    : integer := 1 + 4;                                       -- bit 32 selects hbm stack, 31:28 select AXI port
     constant hbm_addr_width                   : integer :=  64; -- changed --hbm_port_and_stack_addr_width + hbm_ps_port_addr_width;
     -- constant hbm_block_addr_step              : integer                        := hbm_bytes_per_ps_port;                       -- because we have 256 bits = 32 bytes packages
     constant hbm_burstlen_max        : unsigned(3 downto 0)           := x"F";                   --"1111";
     constant hbm_burstlen_no_burst   : unsigned(3 downto 0)           := x"0";                   --"0000";
     constant hbm_burstmode           : unsigned(1 downto 0)           := "01";                   -- burstmode: only 01=incremental supported
     constant hbm_burstsize           : unsigned(2 downto 0)           := "101";                  -- read burst size, only 256-bit size supported (b'101')
     constant hbm_addr_base_bits      : unsigned(4 downto 0)           := "00000";                -- 256bit= 32 byte = 5 bits to address these bytes, memory will not provide less so the last 5 bits of an address are always 0
     constant hbm_strobe_setting      : std_ulogic_vector(31 downto 0) := x"FFFFFFFF";            -- all '1' as we dont use strobe
     constant hbm_id_bit_width        : integer                        := get_bit_length(64 - 1); -- hbm queue can store 64 requests
     constant hbm_burstmode_bit_width : integer                        := hbm_burstmode'length;
     constant hbm_burstsize_bit_width : integer                        := hbm_burstsize'length;
     constant hbm_burstlen_bit_width  : integer                        := hbm_burstlen_max'length;
     constant hbm_resp_bit_width      : integer                        := 2;

     constant ai_hbm_num_ps_ports   : integer := 1;
     constant ai_burstlen           : integer := get_min(1 - 1, hbm_burstlen_bit_width); -- keep small, high burstlen can lead to significantly higher k_lwe and with that lower PBS/s score
     constant ai_hbm_coeffs_per_clk : integer := ai_hbm_num_ps_ports * hbm_coeffs_per_clock_per_ps_port;
     constant ai_hbm_bytes_per_clk  : integer := ai_hbm_coeffs_per_clk * 8;
     constant bsk_burstlen          : integer := to_integer(hbm_burstlen_max);

     -- crossbar related
     constant axi_burstlen_bits         : integer := 8; -- is just a constant
     constant crossbar_num_axi_masters  : integer := 1;
     constant crossbar_0_num_axi_slaves : integer := hbm_stack_num_ps_ports;
     constant crossbar_1_num_axi_slaves : integer := 6; -- hbm channels: op, lut, ai, b, result and bsk_crossbar
     constant num_axi_slave_interfaces  : integer := crossbar_num_axi_masters;
     constant axi_addr_bits             : integer := hbm_addr_width;
     constant axi_len_bits              : integer := axi_burstlen_bits;
     constant axi_burstsize_bits        : integer := hbm_burstsize_bit_width;
     constant axi_burstmode_bits        : integer := hbm_burstmode_bit_width;
     constant axi_cache_bits            : integer := 4; -- ?
     constant axi_prot_bits             : integer := 3; -- protection level: for secure and non-secure transactions
     constant axi_qos_bits              : integer := 4; -- is a transaction priority-setting
     constant axi_resp_bits             : integer := hbm_resp_bit_width;
     constant axi_pkg_bit_size          : integer := hbm_data_width;
     constant axi_strobe_bits           : integer := hbm_strobe_setting'length;
     constant axi_region_bits           : integer := 0; -- originally 4, but hbm_ip uses 16 regions
     constant axi_id_bit_width          : integer := hbm_id_bit_width;
     -- pcie related
     constant pcie_irq_bit_width             : integer := 1;
     constant pcie_id_bit_width              : integer := 4;
     constant pcie_resp_bit_width            : integer := hbm_resp_bit_width;
     constant pcie_data_bit_width            : integer := hbm_data_width;
     constant pcie_cfg_mgmt_addr_bit_width   : integer := 19;
     constant pcie_cfg_mgmt_data_bit_width   : integer := 32;
     constant pcie_cfg_byte_enable_bit_width : integer := 4;
     constant pcie_rx_tx_bit_width           : integer := 4; -- PL_LINK_CAP_MAX_LINK_WIDTH
     constant pcie_msi_vec_width_bit_width   : integer := 3;
     constant pcie_addr_bit_width            : integer := 64;
     constant pcie_tkeep_bit_width           : integer := 8;
     constant pcie_rq_tuser_bit_width        : integer := 62;
     constant pcie_rq_cc_tuser_bit_width     : integer := 33;
     constant pcie_cp_np_bit_width           : integer := 2;

     -- hbm-ip uses 6 bits for the id, axi_crossbar as well but xdma offers only 4 bits (TODO: find the IP-core setting to avoid this conversion)
     constant id_pad_bits_length   : integer                                           := axi_id_bit_width - pcie_id_bit_width;
     constant id_pad_bits_unsigned : unsigned(id_pad_bits_length - 1 downto 0)         := to_unsigned(0, id_pad_bits_length);
     constant id_pad_bits          : std_logic_vector(id_pad_bits_length - 1 downto 0) := std_logic_vector(id_pad_bits_unsigned);
     -- hbm-ip has 4 bits for burstlength, axi has 8 bits (TODO: find the IP-core setting to avoid this conversion)
     constant burstlen_pad_bits_length   : integer                                                 := axi_burstlen_bits - hbm_burstlen_bit_width;
     constant burstlen_pad_bits_unsigned : unsigned(burstlen_pad_bits_length - 1 downto 0)         := to_unsigned(0, burstlen_pad_bits_length);
     constant burstlen_pad_bits          : std_logic_vector(burstlen_pad_bits_length - 1 downto 0) := std_logic_vector(burstlen_pad_bits_unsigned);

end package;

package body ip_cores_constants is

end package body;
