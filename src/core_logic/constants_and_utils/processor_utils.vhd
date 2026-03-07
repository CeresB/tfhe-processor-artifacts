----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: processor_utils - package
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: So far this contains only datatypes that are used by our testbenches.
--             But the idea is that later this files contains material for the (memory-) organization of the TFHE processor.
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
     use work.ip_cores_constants.all;
     use work.datatypes_utils.all;
     use work.math_utils.all;
     use work.tfhe_constants.all;
     use work.tfhe_utils.all;

package processor_utils is

     constant no_muladd_module : boolean := true; -- mullad&keyswitch is outside of the scope of this project

     constant log2_memory_address : integer := 32;
     subtype hbm_ps_port_memory_address is unsigned(hbm_addr_width - 1 downto 0);
     function to_stack_memory_address(
          addr : integer
     ) return hbm_ps_port_memory_address;
     function to_stack_memory_address(
          addr : unsigned
     ) return hbm_ps_port_memory_address;

     constant pbs_return_addr_delay    : integer := bs_clks_till_first_result_block;
     constant sample_extract_idx_delay : integer := bs_clks_till_first_result_block - sample_extract_latency;

     constant clks_ai_valid                 : integer := num_polyms_per_rlwe_ciphertext * num_coefficients / pbs_throughput;
     constant clks_b_valid                  : integer := clks_ai_valid;
     constant pbs_bsk_coeffs_needed_per_clk : integer := decomp_length * num_polyms_per_rlwe_ciphertext * pbs_throughput;
     constant bsk_hbm_num_ps_ports          : integer := 8; -- max. 16, we calculated that 8 are fast enough with batchsize 9 and throughput=32
     constant bsk_hbm_num_coeffs_per_clk    : integer := bsk_hbm_num_ps_ports * hbm_coeffs_per_clock_per_ps_port;
     constant bsk_hbm_coeffs_per_clk        : integer := get_min(bsk_hbm_num_coeffs_per_clk, pbs_bsk_coeffs_needed_per_clk); -- must be a power of 2
     constant bsk_hbm_num_ports_to_use    : integer := bsk_hbm_coeffs_per_clk / hbm_coeffs_per_clock_per_ps_port;

     -- constants for pbs_lut_storage
     constant coeffs_per_pbs_lut : integer := num_polyms_per_rlwe_ciphertext * num_coefficients;

     -- constants for lwe_n_storage
     constant num_pbs_out_write_cycles             : integer := (num_polyms_per_rlwe_ciphertext * pbs_batchsize * num_coefficients) / pbs_throughput;
     constant write_blocks_per_lwe                 : integer := (k * num_coefficients) / pbs_throughput + 1; -- + 1 for block that contains b
     constant write_blocks_in_lwe_n_ram            : integer := write_blocks_per_lwe * pbs_batchsize;
     constant write_blocks_in_lwe_n_ram_bit_length : integer := get_bit_length(write_blocks_in_lwe_n_ram - 1);
     constant read_blocks_in_lwe_n_ram             : integer := ((k * num_coefficients) / hbm_coeffs_per_clock_per_ps_port + 1) * pbs_batchsize;

     -- if 4gb per stack hbm: one channel has 256MB, corresponding to an address space of log2(256MB)-1=2^27
     constant hbm_ps_port_addr_range : hbm_ps_port_memory_address := to_unsigned(2 ** hbm_ps_port_addr_width, hbm_ps_port_memory_address'length);

     -- base addresses for the HBM channels - must be the same as in the axi-crossbar-ip core!
     constant op_base_addr  : hbm_ps_port_memory_address := to_stack_memory_address(0);
     constant ai_base_addr  : hbm_ps_port_memory_address := to_stack_memory_address(hbm_ps_port_addr_range * to_stack_memory_address(1));
     constant b_base_addr   : hbm_ps_port_memory_address := to_stack_memory_address(hbm_ps_port_addr_range * to_stack_memory_address(2));
     constant lut_base_addr : hbm_ps_port_memory_address := to_stack_memory_address(hbm_ps_port_addr_range * to_stack_memory_address(3));
     constant res_base_addr : hbm_ps_port_memory_address := to_stack_memory_address(hbm_ps_port_addr_range * to_stack_memory_address(4));
     constant bsk_base_addr : hbm_ps_port_memory_address := to_stack_memory_address(hbm_ps_port_addr_range * to_stack_memory_address(16));

     constant bsk_end_addr : hbm_ps_port_memory_address := bsk_base_addr + to_unsigned((hbm_bytes_per_ps_port * k_lwe * decomp_length) * (num_polyms_per_rlwe_ciphertext * num_polyms_per_rlwe_ciphertext * num_coefficients) / bsk_hbm_coeffs_per_clk, hbm_ps_port_memory_address'length);
     --constant ai_end_addr  : hbm_ps_port_memory_address := 0; -- no wrap around, no end address
     --constant b_end_addr  : hbm_ps_port_memory_address := 0; -- no wrap around, no end address
     --constant lut_end_addr  : hbm_ps_port_memory_address := 0; -- no wrap around, no end address
     constant op_end_addr  : hbm_ps_port_memory_address := op_base_addr + hbm_ps_port_addr_range;
     constant res_end_addr : hbm_ps_port_memory_address := res_base_addr + to_unsigned(hbm_bytes_per_ps_port * read_blocks_in_lwe_n_ram, hbm_ps_port_memory_address'length);

     type hbm_ps_port_memory_address_arr is array (natural range <>) of hbm_ps_port_memory_address;

     type pbs_operation is record
          -- do not change the order of these elements without changing the op-decode part
          lwe_addr_in        : hbm_ps_port_memory_address;
          -- lwe_addr_out       : hbm_ps_port_memory_address;
          lut_start_addr     : hbm_ps_port_memory_address;
          -- sample_extract_idx : idx_int;
          -- in the future: maybe choice of different bootstrapping keys through providing address
     end record;

     subtype hbm_parity_bits_logic is std_logic_vector(hbm_bytes_per_ps_port - 1 downto 0);

     -- these types are for hbm and pcie
     type hbm_ps_in_write_pkg is record
          wdata        : std_logic_vector(hbm_data_width - 1 downto 0);
          wlast        : std_ulogic;
          wdata_parity : hbm_parity_bits_logic;
          wvalid       : std_ulogic;
          awaddr       : hbm_ps_port_memory_address;
          awvalid      : std_ulogic;
          awid         : std_logic_vector(hbm_id_bit_width - 1 downto 0);
          bready       : std_ulogic;
          awlen        : std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
     end record;
     type hbm_ps_out_write_pkg is record
          awready : std_ulogic;
          wready  : std_ulogic;
          bid     : std_logic_vector(hbm_id_bit_width - 1 downto 0);
          bresp   : std_logic_vector(hbm_resp_bit_width - 1 downto 0);
          bvalid  : std_ulogic;
     end record;
     type hbm_ps_in_write_pkg_arr is array (natural range <>) of hbm_ps_in_write_pkg;
     type hbm_ps_out_write_pkg_arr is array (natural range <>) of hbm_ps_out_write_pkg;

     type hbm_ps_in_read_pkg is record
          araddr  : hbm_ps_port_memory_address;
          arvalid : std_ulogic;
          arid    : std_logic_vector(hbm_id_bit_width - 1 downto 0);
          rready  : std_ulogic;
          arlen   : std_logic_vector(hbm_burstlen_bit_width - 1 downto 0);
     end record;
     type hbm_ps_out_read_pkg is record
          rdata        : std_logic_vector(hbm_data_width - 1 downto 0);
          rlast        : std_ulogic;
          rdata_parity : hbm_parity_bits_logic;
          arready      : std_ulogic;
          rid          : std_logic_vector(hbm_id_bit_width - 1 downto 0);
          rresp        : std_logic_vector(hbm_resp_bit_width - 1 downto 0);
          rvalid       : std_ulogic;
     end record;
     type hbm_ps_in_read_pkg_arr is array (natural range <>) of hbm_ps_in_read_pkg;
     type hbm_ps_out_read_pkg_arr is array (natural range <>) of hbm_ps_out_read_pkg;

     type axi_in_crtl_pkg is record
          len        : std_logic_vector(axi_len_bits - 1 downto 0);
          size       : std_logic_vector(axi_burstsize_bits - 1 downto 0);
          burst      : std_logic_vector(axi_burstmode_bits - 1 downto 0);
          -- lock       : std_logic;
          cache      : std_logic_vector(axi_cache_bits - 1 downto 0);
          prot       : std_logic_vector(axi_prot_bits - 1 downto 0);
          qos        : std_logic_vector(axi_qos_bits - 1 downto 0);
          id         : std_logic_vector(axi_id_bit_width - 1 downto 0);
          addr       : std_logic_vector(axi_addr_bits - 1 downto 0);
          addr_valid : std_logic;
          ready      : std_logic;
     end record;
     type axi_in_write_pkg is record
          data   : std_logic_vector(hbm_data_width - 1 downto 0);
          valid  : std_logic;
          crtl   : axi_in_crtl_pkg;
          strobe : std_logic_vector(axi_strobe_bits - 1 downto 0);
          last   : std_logic;
     end record;
     type axi_in_read_pkg is record
          crtl : axi_in_crtl_pkg;
     end record;

     type axi_out_crtl_pkg is record
          addr_ready : std_logic;
          id         : std_logic_vector(axi_id_bit_width - 1 downto 0);
          resp       : std_logic_vector(axi_resp_bits - 1 downto 0);
          valid      : std_logic;
     end record;
     type axi_out_read_pkg is record
          crtl : axi_out_crtl_pkg;
          data : std_logic_vector(hbm_data_width - 1 downto 0);
          last : std_logic;
     end record;
     type axi_out_write_pkg is record
          crtl  : axi_out_crtl_pkg;
          ready : std_logic;
     end record;

     -- secondary - only used for easier testbenches
     type LWE_memory is record
          lwe  : ciphertext_LWE;
          addr : unsigned(0 to log2_memory_address - 1);
     end record;

     type RLWE_memory is record
          rlwe : ciphertext_RLWE;
          addr : unsigned(0 to log2_memory_address - 1);
     end record;

     function get_test_lwe_memory(
          start_num : integer;
          step_size : integer;
          b_val     : integer;
          addr      : integer
     ) return LWE_memory;

     -- function get_test_rlwe_memory(
     --      addr : integer
     -- ) return RLWE_memory;
end package;

package body processor_utils is

     function to_stack_memory_address(
               addr : integer
          ) return hbm_ps_port_memory_address is
          variable res : hbm_ps_port_memory_address;
     begin
          res := to_unsigned(addr, hbm_ps_port_memory_address'length);
          return res;
     end function;

     function to_stack_memory_address(
               addr : unsigned
          ) return hbm_ps_port_memory_address is
          variable res : hbm_ps_port_memory_address;
     begin
          res := resize(addr, hbm_ps_port_memory_address'length);
          return res;
     end function;

     function get_test_lwe_memory(
               start_num : integer;
               step_size : integer;
               b_val     : integer;
               addr      : integer
          ) return LWE_memory is
          variable res : LWE_memory;
     begin
          res.addr := to_unsigned(addr, log2_memory_address);
          res.lwe.a := to_synth_int_vector(get_test_sub_polym(res.lwe.a'length, start_num, step_size));
          res.lwe.b := to_synth_uint(b_val);
          return res;
     end function;

     -- function get_test_rlwe_memory(
     --           addr : integer
     --      ) return RLWE_memory is
     --      variable res : RLWE_memory;
     -- begin
     --      res.addr := to_unsigned(addr, log2_memory_address);
     --      for k_idx in 0 to RLWE_memory.rlwe.a'length - 1 loop
     --           res.rlwe.a(k_idx) := get_random_test_polym;
     --      end loop;
     --      res.rlwe.b := get_random_test_polym;
     --      return res;
     -- end function;
end package body;
