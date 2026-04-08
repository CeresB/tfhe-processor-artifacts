----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 23.09.2024 14:32:11
-- Design Name: 
-- Module Name: tfhe_pbs_accelerator
-- Project Name: TFHE Acceleration with FPGA
-- Target Devices: Virtex UltraScale+ HBM VCU128 FPGA
-- Tool Versions: Vivado 2024.1
-- Description: the tfhe_accelerator without hbm - it is assumed to work outside of this module.
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
library work;
  use work.constants_utils.all;
  use work.ip_cores_constants.all;
  use work.datatypes_utils.all;
  use work.math_utils.all;
  use work.tfhe_constants.all;
  use work.processor_utils.all;

entity tfhe_pbs_accelerator is
  port (
    i_clk               : in  std_ulogic;
    i_reset_n           : in  std_ulogic;
    i_ram_coeff_idx     : in  unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
    -- o_return_address    : out hbm_ps_port_memory_address;
    o_out_data          : out sub_polynom(0 to pbs_throughput - 1);
    o_next_module_reset : out std_ulogic;
    -- hbm related in / out signals
    i_ai_hbm_out        : in  hbm_ps_out_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
    i_bsk_hbm_out       : in  hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
    i_op_hbm_out        : in  hbm_ps_out_read_pkg;
    i_lut_hbm_out       : in  hbm_ps_out_read_pkg;
    i_b_hbm_out         : in  hbm_ps_out_read_pkg;
    o_ai_hbm_in         : out hbm_ps_in_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
    o_bsk_hbm_in        : out hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
    o_op_hbm_in         : out hbm_ps_in_read_pkg;
    o_lut_hbm_in        : out hbm_ps_in_read_pkg;
    o_b_hbm_in          : out hbm_ps_in_read_pkg
  );
end entity;

architecture Behavioral of tfhe_pbs_accelerator is

  component pbs_lut_buffer is
    port (
      i_clk                  : in  std_ulogic;
      i_init            : in  std_ulogic;
      i_lut_start_addr       : in  hbm_ps_port_memory_address;
      i_lut_addr_valid       : in  std_ulogic;
      i_reset_n              : in  std_ulogic;
      i_hbm_read_out         : in  hbm_ps_out_read_pkg;
      o_hbm_read_in          : out hbm_ps_in_read_pkg;
      o_lut_part             : out sub_polynom(0 to pbs_throughput - 1);
      o_ready_to_output      : out std_ulogic
    );
  end component;

  component op_pbs_pingpongbuffer is
    port (
      i_clk                  : in  std_ulogic;
      i_reset_n              : in  std_ulogic;
      i_pbs_reset            : in  std_ulogic;
      i_hbm_read_out         : in  hbm_ps_out_read_pkg;
      o_lut_start_addr       : out hbm_ps_port_memory_address;
      o_b_addr               : out hbm_ps_port_memory_address;
      o_a_addr               : out hbm_ps_port_memory_address;
      o_addr_valid         : out std_ulogic;
      -- o_return_address       : out hbm_ps_port_memory_address;
      -- o_return_address_valid          : out std_ulogic;
      -- o_sample_extract_idx   : out idx_int;
      o_init          : out std_ulogic;
      o_hbm_read_in          : out hbm_ps_in_read_pkg
    );
  end component;

  component pbs is
    generic (
      throughput                     : integer;
      decomposition_length           : integer; -- for the external product
      num_LSBs_to_round              : integer; -- for the external product
      bits_per_slice                 : integer; -- for the external product
      polyms_per_ciphertext          : integer; -- for the external product
      min_latency_till_monomial_mult : integer; -- for the external product
      num_iterations                 : integer  -- for the blind rotation
    );
    port (
      i_clk                : in  std_ulogic;
      i_reset              : in  std_ulogic;
      i_lookup_table_part  : in  sub_polynom(0 to throughput - 1); -- for the programmable bootstrapping, only a part of an RLWE ciphertext
      i_lwe_b              : in  rotate_idx;
      i_lwe_ai             : in  rotate_idx;
      i_BSK_i_part         : in  sub_polynom(0 to throughput * decomposition_length * polyms_per_ciphertext - 1);
      -- i_sample_extract_idx : in  idx_int;
      -- o_sample_extract_idx : out idx_int;
      o_result             : out sub_polynom(0 to throughput - 1);
      o_next_module_reset  : out std_ulogic
    );
  end component;

  component pbs_b_buffer is
    port (
      i_clk             : in  std_ulogic;
      i_init       : in  std_ulogic;
      i_lwe_addr        : in  hbm_ps_port_memory_address;
      i_lwe_addr_valid  : in  std_ulogic;
      i_reset_n         : in  std_ulogic;
      i_hbm_read_out    : in  hbm_ps_out_read_pkg;
      o_hbm_read_in     : out hbm_ps_in_read_pkg;
      o_b               : out rotate_idx;
      o_ready_to_output : out std_ulogic
    );
  end component;

  component ai_pbs_pingpongbuffer is
    port (
      i_clk                    : in  std_ulogic;
      i_lwe_addr               : in  hbm_ps_port_memory_address;
      i_lwe_addr_valid         : in  std_ulogic;
      i_pbs_reset              : in  std_ulogic;
      i_reset_n                : in  std_ulogic;
      i_hbm_ps_in_read_out_pkg : in  hbm_ps_out_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
      o_hbm_ps_in_read_in_pkg  : out hbm_ps_in_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
      o_ai_coeff               : out rotate_idx;
      o_ready_to_output        : out std_ulogic
    );
  end component;

  component bski_pbs_pingpongbuffer is
    port (
      i_clk                    : in  std_ulogic;
      i_pbs_reset              : in  std_ulogic;
      i_reset_n                : in  std_ulogic;
      i_hbm_ps_in_read_out_pkg : in  hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
      o_hbm_ps_in_read_in_pkg  : out hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
      o_bski_part              : out sub_polynom(0 to pbs_bsk_coeffs_needed_per_clk - 1);
      o_ready_to_output        : out std_ulogic
    );
  end component;

  component pbs_lwe_n_storage_write is
    port (
      i_clk                : in  std_ulogic;
      i_pbs_result         : in  sub_polynom(0 to pbs_throughput - 1);
      -- i_sample_extract_idx : in  idx_int;
      i_ram_coeff_idx      : in  unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
      i_reset              : in  std_ulogic;

      o_coeffs             : out sub_polynom(0 to pbs_throughput - 1);
      o_next_module_reset  : out std_ulogic
    );
  end component;

  -- op buffer signals
  signal current_lut_start_addr       : hbm_ps_port_memory_address;
  -- signal current_sample_extract_idx   : idx_int;
  signal init_iteration                : std_ulogic;

  -- pbs signals
  signal pbs_output_not_ready         : std_logic;
  signal pbs_reset                    : std_logic;
  signal pbs_reset_delayed            : std_logic;
  signal pbs_reset_ram_retiming_chain : std_logic_vector(0 to default_ram_retiming_latency - 1);
  signal pbs_lwe_b                    : rotate_idx;
  signal bsk_i_part                   : sub_polynom(0 to pbs_throughput * decomp_length * num_polyms_per_rlwe_ciphertext - 1);
  signal pbs_result                   : sub_polynom(0 to pbs_throughput - 1);
  signal ai                           : rotate_idx;
  signal pbs_lut_part                 : sub_polynom(0 to pbs_throughput - 1);
  -- signal pbs_b_extract_idx            : idx_int;

  -- pingpong buffer ready signals
  signal lut_storage_ready  : std_ulogic;
  signal bski_storage_ready : std_ulogic;
  signal ai_storage_ready   : std_ulogic;
  signal b_storage_ready    : std_ulogic;

  signal a_addr       : hbm_ps_port_memory_address;
  signal all_addrs_valid : std_ulogic;
  signal b_addr       : hbm_ps_port_memory_address;

  signal reset_n_delayed : std_ulogic;

begin

  process (i_clk) is
  begin
    if rising_edge(i_clk) then
      if i_reset_n = '0' then
        pbs_reset <= '1';
      else
        if pbs_reset = '1' then
          pbs_reset <= not(bski_storage_ready and ai_storage_ready and lut_storage_ready and b_storage_ready);
        else
          -- b_storage_ready and lut_storage_ready will become low again when the new batch starts
          -- however, pbs reset shall be kept low regardless of this
          -- we only need the resets to start up the pipeline correctly
        end if;
      end if;
      pbs_reset_delayed <= pbs_reset;
      pbs_reset_ram_retiming_chain(0) <= pbs_reset_delayed;
      pbs_reset_ram_retiming_chain(1 to pbs_reset_ram_retiming_chain'length - 1) <= pbs_reset_ram_retiming_chain(0 to pbs_reset_ram_retiming_chain'length - 2);
      reset_n_delayed <= i_reset_n;
    end if;
  end process;

  op_buffer: op_pbs_pingpongbuffer
    port map (
      i_clk                  => i_clk,
      i_reset_n              => i_reset_n,
      i_pbs_reset            => pbs_reset_delayed,
      i_hbm_read_out         => i_op_hbm_out,
      o_hbm_read_in          => o_op_hbm_in,
      o_lut_start_addr       => current_lut_start_addr,
      o_b_addr               => b_addr,
      o_a_addr               => a_addr,
      o_addr_valid         => all_addrs_valid,
      -- o_return_address       => o_return_address,
      -- o_sample_extract_idx   => current_sample_extract_idx,
      o_init            => init_iteration
    );

  bski_pbs_pingpongbuffer_inst: bski_pbs_pingpongbuffer
    port map (
      i_clk                    => i_clk,
      i_reset_n                => reset_n_delayed,
      i_pbs_reset              => pbs_reset_delayed,
      i_hbm_ps_in_read_out_pkg => i_bsk_hbm_out,
      o_hbm_ps_in_read_in_pkg  => o_bsk_hbm_in,
      o_bski_part              => bsk_i_part,
      o_ready_to_output        => bski_storage_ready
    );

  ai_pbs_pingpongbuffer_inst: ai_pbs_pingpongbuffer
    port map (
      i_clk                    => i_clk,
      i_lwe_addr               => a_addr,
      i_lwe_addr_valid         => all_addrs_valid,
      i_reset_n                => reset_n_delayed,
      i_pbs_reset              => pbs_reset_delayed,
      i_hbm_ps_in_read_out_pkg => i_ai_hbm_out,
      o_hbm_ps_in_read_in_pkg  => o_ai_hbm_in,
      o_ai_coeff               => ai,
      o_ready_to_output        => ai_storage_ready
    );

  lut_buffer_inst: pbs_lut_buffer
    port map (
      i_clk                  => i_clk,
      i_init            => init_iteration,
      i_lut_start_addr       => current_lut_start_addr,
      i_reset_n              => reset_n_delayed,
      i_lut_addr_valid       => all_addrs_valid,
      i_hbm_read_out         => i_lut_hbm_out,
      o_hbm_read_in          => o_lut_hbm_in,
      o_lut_part             => pbs_lut_part,
      o_ready_to_output      => lut_storage_ready
    );

  -- b storage is less frequently used that ai storage and can therefore be faster
  -- this is why it has address buffers independent from those of ai buffer
  b_buffer_inst: pbs_b_buffer
    port map (
      i_clk             => i_clk,
      i_init       => init_iteration,
      i_lwe_addr        => b_addr,
      i_lwe_addr_valid => all_addrs_valid,
      i_reset_n         => reset_n_delayed,
      i_hbm_read_out    => i_b_hbm_out,
      o_hbm_read_in     => o_b_hbm_in,
      o_b               => pbs_lwe_b,
      o_ready_to_output => b_storage_ready
    );

  pbs_computation: pbs
    generic map (
      throughput                     => pbs_throughput,
      decomposition_length           => decomp_length,
      num_LSBs_to_round              => decomp_num_LSBs_to_round,
      polyms_per_ciphertext          => num_polyms_per_rlwe_ciphertext,
      bits_per_slice                 => log2_decomp_base,
      min_latency_till_monomial_mult => blind_rot_iter_min_latency_till_monomial_mult,
      num_iterations                 => k_lwe
    )
    port map (
      i_clk                => i_clk,
      i_reset              => pbs_reset_ram_retiming_chain(pbs_reset_ram_retiming_chain'length - 1),
      i_lookup_table_part  => pbs_lut_part,
      i_lwe_b              => pbs_lwe_b,
      i_lwe_ai             => ai,
      i_BSK_i_part         => bsk_i_part,
      -- i_sample_extract_idx => current_sample_extract_idx,
      -- o_sample_extract_idx => pbs_b_extract_idx,
      o_result             => pbs_result,
      o_next_module_reset  => pbs_output_not_ready
    );

  pbs_lwe_n_storage_inst: pbs_lwe_n_storage_write
    port map (
      i_clk                => i_clk,
      i_pbs_result         => pbs_result,
      -- i_sample_extract_idx => pbs_b_extract_idx,
      i_ram_coeff_idx      => i_ram_coeff_idx,
      i_reset              => pbs_output_not_ready,
      o_coeffs             => o_out_data,
      o_next_module_reset  => o_next_module_reset
    );

end architecture;
