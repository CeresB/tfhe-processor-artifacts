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

entity tfhe_pbs_accelerator_axi is
  generic (
    C_M_AXI_ADDR_WIDTH : integer := axi_addr_bits;      -- should equal hbm_addr_width
    C_M_AXI_DATA_WIDTH : integer := hbm_data_width;     -- must equal hbm_data_width
    C_M_AXI_BURST_LEN  : integer := 16;                  -- max burst length (beats)
    C_S_AXI_DATA_WIDTH : integer := 32
  );
  port (
    -- Core clock/reset
    i_clk               : in  std_ulogic;
    i_reset_n           : in  std_ulogic;

    -- PBS control / output interface to the rest of the processor
    o_ram_coeff_idx     : out unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);
    o_return_address    : out hbm_ps_port_memory_address;
    o_out_valid         : out std_ulogic;
    o_out_data          : out sub_polynom(0 to pbs_throughput - 1);
    o_next_module_reset : out std_ulogic;

    --------------------------------------------------------------------
    -- AXI4 READ MASTER INTERFACE (single port, to be read from HBM)
    --------------------------------------------------------------------
    M_AXI_ARADDR  : out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
    M_AXI_ARLEN   : out std_logic_vector(7 downto 0);
    M_AXI_ARSIZE  : out std_logic_vector(2 downto 0);
    M_AXI_ARBURST : out std_logic_vector(1 downto 0);
    M_AXI_ARVALID : out std_logic;
    M_AXI_ARREADY : in  std_logic;

    M_AXI_RDATA   : in  std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    M_AXI_RRESP   : in  std_logic_vector(1 downto 0);
    M_AXI_RLAST   : in  std_logic;
    M_AXI_RVALID  : in  std_logic;
    M_AXI_RREADY  : out std_logic;

    --------------------------------------------------------------------
    -- AXI4 WRITE MASTER INTERFACE (for PBS result to HBM)
    --------------------------------------------------------------------
    M_AXI_AWADDR  : out std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0);
    M_AXI_AWLEN   : out std_logic_vector(7 downto 0);
    M_AXI_AWSIZE  : out std_logic_vector(2 downto 0);
    M_AXI_AWBURST : out std_logic_vector(1 downto 0);
    M_AXI_AWVALID : out std_logic;
    M_AXI_AWREADY : in  std_logic;

    M_AXI_WDATA   : out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    M_AXI_WVALID  : out std_logic;
    M_AXI_WLAST   : out std_logic;
    M_AXI_WREADY  : in  std_logic;

    M_AXI_BRESP   : in  std_logic_vector(1 downto 0);
    M_AXI_BVALID  : in  std_logic;
    M_AXI_BREADY  : out std_logic;

    -- Control signals
    user_led        : out std_logic_vector(7 downto 0);
    host_rd_addr    : out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    host_rd_len     : out std_logic_vector(C_M_AXI_DATA_WIDTH-1 downto 0);
    pbs_busy        : out std_logic;
    pbs_done        : out std_logic;
    start_pbs       : in  std_ulogic
  
  );
end entity;

architecture rtl of tfhe_pbs_accelerator_axi is

  --------------------------------------------------------------------
  -- Local constants for flattening HBM read ports
  --------------------------------------------------------------------
  constant NUM_AI_PORTS  : integer := ai_hbm_num_ps_ports;
  constant NUM_BSK_PORTS : integer := bsk_hbm_num_ps_ports;
  constant NUM_SCALAR    : integer := 3;  -- op, lut, b
  constant NUM_READ_PORTS: integer := NUM_AI_PORTS + NUM_BSK_PORTS + NUM_SCALAR;

  constant IDX_AI_START  : integer := 0;
  constant IDX_BSK_START : integer := IDX_AI_START + NUM_AI_PORTS;
  constant IDX_B_START   : integer := IDX_BSK_START + NUM_BSK_PORTS;
  constant IDX_LUT       : integer := IDX_B_START + 1;
  constant IDX_OP        : integer := IDX_LUT + 1;

  --------------------------------------------------------------------
  -- Signals between PBS accelerator and this wrapper
  --------------------------------------------------------------------
  signal ai_hbm_in   : hbm_ps_in_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);
  signal ai_hbm_out  : hbm_ps_out_read_pkg_arr(0 to ai_hbm_num_ps_ports - 1);

  signal bsk_hbm_in  : hbm_ps_in_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);
  signal bsk_hbm_out : hbm_ps_out_read_pkg_arr(0 to bsk_hbm_num_ps_ports - 1);

  signal op_hbm_in   : hbm_ps_in_read_pkg;
  signal op_hbm_out  : hbm_ps_out_read_pkg;

  signal lut_hbm_in  : hbm_ps_in_read_pkg;
  signal lut_hbm_out : hbm_ps_out_read_pkg;

  signal b_hbm_in    : hbm_ps_in_read_pkg;
  signal b_hbm_out   : hbm_ps_out_read_pkg;

  --------------------------------------------------------------------
  -- Flattened arrays for arbitration
  --------------------------------------------------------------------
  signal rd_req  : hbm_ps_in_read_pkg_arr(0 to NUM_READ_PORTS-1);
  signal rd_rsp  : hbm_ps_out_read_pkg_arr(0 to NUM_READ_PORTS-1);

  --------------------------------------------------------------------
  -- AXI read-channel control
  --------------------------------------------------------------------
  type axi_state_t is (AXI_IDLE, AXI_ADDR, AXI_DATA);
  signal axi_state      : axi_state_t := AXI_IDLE;

  signal axi_araddr     : std_logic_vector(C_M_AXI_ADDR_WIDTH-1 downto 0) := (others => '0');
  signal axi_arlen      : std_logic_vector(7 downto 0) := (others => '0');
  signal axi_arvalid    : std_logic := '0';
  signal axi_rready     : std_logic := '0';

  signal current_owner  : integer range 0 to NUM_READ_PORTS-1 := 0;
  signal last_grant     : integer range 0 to NUM_READ_PORTS-1 := 0;

  --------------------------------------------------------------------
  -- PBS result & write-to-HBM wiring
  --------------------------------------------------------------------
  signal pbs_out_data_s          : sub_polynom(0 to pbs_throughput - 1);
  signal pbs_out_valid_s         : std_ulogic;
  signal pbs_next_module_reset_s : std_ulogic;
  signal pbs_return_addr_s       : hbm_ps_port_memory_address;

  signal ram_coeff_idx_s         : unsigned(0 to write_blocks_in_lwe_n_ram_bit_length - 1);

  signal hbm_write_in_s          : hbm_ps_in_write_pkg;
  signal hbm_write_out_s         : hbm_ps_out_write_pkg;
  
  ---------------------------------------------------------------------
  -- PBS controller logic
  ---------------------------------------------------------------------
  
  type pbs_ctrl_state_t is (
  IDLE,
  RUN,
  DRAIN
  --,
  --DONE
  );

  signal led_cnt    : unsigned(23 downto 0) := (others => '0');
  signal led_shift : std_logic_vector(6 downto 0) := "0000001";
  signal led_cnt_bin : unsigned(6 downto 0) := (others => '0');

  signal temp_delay    : unsigned(23 downto 0) := (others => '0');

  signal pbs_state : pbs_ctrl_state_t := IDLE;
   
  -- signal start_pbs_d : std_ulogic := '0';
  -- signal start_pbs_pulse : std_ulogic;
  -- signal pbs_enable : std_ulogic := '0';

begin

  --------------------------------------------------------------------
  -- Constant AXI parameters (HBM-like)
  --------------------------------------------------------------------
  M_AXI_ARSIZE  <= std_logic_vector(hbm_burstsize);    -- e.g., "101" for 32 bytes (256 bits)
  M_AXI_ARBURST <= std_logic_vector(hbm_burstmode);    -- "01" = INCR

  M_AXI_ARADDR  <= axi_araddr;
  M_AXI_ARLEN   <= axi_arlen;

  
  M_AXI_ARVALID <= axi_arvalid when start_pbs = '1' else '0';
  M_AXI_RREADY  <= axi_rready  when start_pbs = '1' else '0';

  -- WRITE side: constant settings
  M_AXI_AWSIZE  <= std_logic_vector(hbm_burstsize);
  M_AXI_AWBURST <= std_logic_vector(hbm_burstmode);

  --------------------------------------------------------------------
  -- Instantiate the TFHE PBS accelerator
  --------------------------------------------------------------------
  u_pbs_accel : entity work.tfhe_pbs_accelerator
    port map (
      i_clk               => i_clk,
      i_reset_n           => i_reset_n and start_pbs, -- gated reset for now, better to do internal FSM
      i_ram_coeff_idx     => ram_coeff_idx_s,
      o_return_address    => pbs_return_addr_s,
      o_out_valid         => pbs_out_valid_s,
      o_out_data          => pbs_out_data_s,
      o_next_module_reset => pbs_next_module_reset_s,

      i_ai_hbm_out        => ai_hbm_out,
      i_bsk_hbm_out       => bsk_hbm_out,
      i_op_hbm_out        => op_hbm_out,
      i_lut_hbm_out       => lut_hbm_out,
      i_b_hbm_out         => b_hbm_out,
      o_ai_hbm_in         => ai_hbm_in,
      o_bsk_hbm_in        => bsk_hbm_in,
      o_op_hbm_in         => op_hbm_in,
      o_lut_hbm_in        => lut_hbm_in,
      o_b_hbm_in          => b_hbm_in
    );

  -- Expose PBS outputs to the outside 
  o_out_data          <= pbs_out_data_s;
  o_out_valid         <= pbs_out_valid_s;
  o_next_module_reset <= pbs_next_module_reset_s;
  o_return_address    <= pbs_return_addr_s;
  o_ram_coeff_idx     <= ram_coeff_idx_s;

  --------------------------------------------------------------------
  -- Integrate pbs_lwe_n_storage_read_to_hbm: PBS result to HBM write pkg
  --------------------------------------------------------------------
  u_pbs_lwe_to_hbm : entity work.pbs_lwe_n_storage_read_to_hbm
    port map (
      i_clk           => i_clk,
      i_coeffs        => pbs_out_data_s,
      i_coeffs_valid  => pbs_out_valid_s,
      i_reset         => pbs_next_module_reset_s,
      i_hbm_write_out => hbm_write_out_s,
      o_hbm_write_in  => hbm_write_in_s,
      o_ram_coeff_idx => ram_coeff_idx_s
    );

  --------------------------------------------------------------------
  -- Map HBM write package to AXI WRITE CHANNEL
  --------------------------------------------------------------------
  -- Address channel
  M_AXI_AWADDR  <= std_logic_vector(hbm_write_in_s.awaddr);
  M_AXI_AWLEN <= (others => '0');
  M_AXI_AWLEN(hbm_burstlen_bit_width-1 downto 0)
        <= std_logic_vector(hbm_write_in_s.awlen(hbm_burstlen_bit_width-1 downto 0));

  -- Simpler & explicit: extend burstlen to 8 bits
  M_AXI_AWLEN(hbm_burstlen_bit_width-1 downto 0) <= hbm_write_in_s.awlen;
  -- Upper bits remain '0' by default
  -- (we rely on initial value of M_AXI_AWLEN in reset or tool will warn if not)

  M_AXI_AWVALID <= hbm_write_in_s.awvalid;

  -- Write data channel
  M_AXI_WDATA   <= hbm_write_in_s.wdata;
  M_AXI_WVALID  <= hbm_write_in_s.wvalid;
  M_AXI_WLAST   <= hbm_write_in_s.wlast;

  -- Write response channel
  M_AXI_BREADY  <= hbm_write_in_s.bready;

  -- Feedback AXI handshake into HBM write_out_s
  hbm_write_out_s.awready <= M_AXI_AWREADY;
  hbm_write_out_s.wready  <= M_AXI_WREADY;
  hbm_write_out_s.bvalid  <= M_AXI_BVALID;
  hbm_write_out_s.bresp   <= M_AXI_BRESP;
  hbm_write_out_s.bid     <= (others => '0'); -- not used

  --------------------------------------------------------------------
  -- Flatten per-port HBM READ requests into single array rd_req
  --------------------------------------------------------------------
  gen_ai_flatten : for i in 0 to NUM_AI_PORTS-1 generate
  begin
    rd_req(IDX_AI_START + i) <= ai_hbm_in(i);
    ai_hbm_out(i)           <= rd_rsp(IDX_AI_START + i);
  end generate;

  gen_bsk_flatten : for i in 0 to NUM_BSK_PORTS-1 generate
  begin
    rd_req(IDX_BSK_START + i) <= bsk_hbm_in(i);
    bsk_hbm_out(i)           <= rd_rsp(IDX_BSK_START + i);
  end generate;

  -- b, lut, op are single ports
  rd_req(IDX_B_START) <= b_hbm_in;
  b_hbm_out           <= rd_rsp(IDX_B_START);

  rd_req(IDX_LUT)     <= lut_hbm_in;
  lut_hbm_out         <= rd_rsp(IDX_LUT);

  rd_req(IDX_OP)      <= op_hbm_in;
  op_hbm_out          <= rd_rsp(IDX_OP);

  ------------------

  ---------------------------------------------------------------------
  -- PBS controller logic
  ---------------------------------------------------------------------

  -- PBS status outputs
  pbs_busy <= '1' when (pbs_state = RUN or pbs_state = DRAIN) else '0';
  pbs_done <= '1' when (pbs_state = IDLE) else '0';


  -- -- Rising edge detector for the start_pbs signal
  -- -- Captures the previous state of start_pbs on each clock cycle
  -- -- Generates a single-cycle pulse when start_pbs transitions from low to high
  -- -- Used to create a synchronous, one-shot trigger for PBS accelerator initiation
  -- process(i_clk)
  -- begin
  --   if rising_edge(i_clk) then
  --     start_pbs_d <= start_pbs;
  --   end if;
  -- end process;

  -- start_pbs_pulse <= start_pbs and not start_pbs_d;



  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_reset_n = '0' then
        --------------------------------------------------
        -- Reset
        --------------------------------------------------
        pbs_state   <= IDLE;
        pbs_busy    <= '0';
        pbs_done    <= '1';

        led_cnt     <= (others => '0');
        led_shift   <= "0000001";
        user_led    <= (others => '0');

      else
        --------------------------------------------------
        -- Default registered behavior
        --------------------------------------------------
        led_cnt <= led_cnt + 1;

        case pbs_state is

          ------------------------------------------------
          -- IDLE
          ------------------------------------------------
          when IDLE =>
           
            -- LED: slow heartbeat on LED0
            if led_cnt(23) = '1' then
              user_led <= "10000001";
            else
              user_led <= "00000000";
            end if;

            if start_pbs = '1' then
              pbs_state  <= RUN;

              -- reset LED animation on start
              led_cnt   <= (others => '0');
              led_shift <= "1111111";
              pbs_busy <= '1';
              pbs_done <= '0';
            end if;

          ------------------------------------------------
          -- RUN
          ------------------------------------------------
          when RUN =>
  
            -- LED: pattern
            if led_cnt(23) = '1' then
              user_led <= "01010101";
            else
              user_led <= "10101010";
            end if;

            -- if pbs_next_module_reset_s = '1' then
            --   pbs_state <= DRAIN;
            -- end if;

            if temp_delay = x"FFFFFF" then
              temp_delay <= (others => '0');
              pbs_state  <= DRAIN;
              pbs_busy <= '1';
              pbs_done <= '0';
            else
              temp_delay <= temp_delay + 1;
            end if;

          ------------------------------------------------
          -- DRAIN
          ------------------------------------------------
          when DRAIN =>
            


            user_led <= "01111111";

            -- if hbm_write_in_s.awvalid = '0' and
            --   hbm_write_in_s.wvalid  = '0' then
            --   pbs_state <= DONE;
            -- end if;
            
            if temp_delay = x"FFFFFF" then
              pbs_state <= IDLE;
              pbs_busy   <= '0';
              pbs_done   <= '1';
              temp_delay <= (others => '0');
            else
              temp_delay <= temp_delay + 1;
            end if;

          ------------------------------------------------
          -- DONE
          ------------------------------------------------
          -- when DONE =>
          --   pbs_enable <= '0';
          --   pbs_busy   <= '0';
          --   pbs_done   <= '1';

          --   -- LED: all ON (7 LEDs)
          --   user_led <= "01111111";

          --   if start_pbs = '0' then
          --     pbs_state <= IDLE;
          --     pbs_done  <= '0';

          --     -- reset LEDs for next run
          --     led_cnt   <= (others => '0');
          --     led_shift <= "0000001";
          --   end if;

        end case;
      end if;
    end if;
  end process;

-----------------------------------------------------


  --------------------------------------------------------------------
  -- AXI Read Arbiter:
  --  - Round-robin over NUM_READ_PORTS
  --  - Single outstanding burst at a time
  --  - AR* taken from selected rd_req(port)
  --  - R* delivered to rd_rsp(port)
  --------------------------------------------------------------------
  axi_read_arbiter : process(i_clk)
    variable found   : boolean;
    variable cand    : integer;
    variable j       : integer;
  begin
    if rising_edge(i_clk) then
      if i_reset_n = '0' then
        axi_state   <= AXI_IDLE;
        axi_araddr  <= (others => '0');
        axi_arlen   <= (others => '0');
        axi_arvalid <= '0';
        axi_rready  <= '0';
        current_owner <= 0;
        last_grant    <= 0;

        -- Reset all rd_rsp control flags
        for i in 0 to NUM_READ_PORTS-1 loop
          rd_rsp(i).rdata        <= (others => '0');
          rd_rsp(i).rdata_parity <= (others => '0');
          rd_rsp(i).rlast        <= '0';
          rd_rsp(i).rresp        <= (others => '0');
          rd_rsp(i).rid          <= (others => '0');
          rd_rsp(i).rvalid       <= '0';
          rd_rsp(i).arready      <= '0';
        end loop;

      else
        -- Default: no arready / rvalid pulses unless set below
        for i in 0 to NUM_READ_PORTS-1 loop
          rd_rsp(i).rvalid  <= '0';
          rd_rsp(i).rlast   <= '0';
          rd_rsp(i).arready <= '0';
        end loop;

        case axi_state is

          ------------------------------------------------------
          -- IDLE: search for next requesting port (round-robin)
          ------------------------------------------------------
          when AXI_IDLE =>
            axi_arvalid <= '0';
            axi_rready  <= '0';

            found := false;
            cand  := last_grant;

            for offset in 1 to NUM_READ_PORTS loop
              j := (last_grant + offset) mod NUM_READ_PORTS;
              if rd_req(j).arvalid = '1' then
                cand  := j;
                found := true;
                exit;
              end if;
            end loop;

            if found then
              current_owner <= cand;
              last_grant    <= cand;

              -- Drive AXI AR from selected request
              axi_araddr <= std_logic_vector(rd_req(cand).araddr);

              -- Extend 4-bit (HBM) burstlen to 8-bit AXI LEN
              axi_arlen            <= (others => '0');
              axi_arlen(hbm_burstlen_bit_width-1 downto 0)
                                <= rd_req(cand).arlen;

              axi_arvalid <= '1';
              axi_state   <= AXI_ADDR;
            end if;

          ------------------------------------------------------
          -- AXI_ADDR: wait for AR handshake
          ------------------------------------------------------
          when AXI_ADDR =>
            if axi_arvalid = '1' and M_AXI_ARREADY = '1' then
              axi_arvalid <= '0';

              -- Pulse arready toward the selected port (one cycle)
              rd_rsp(current_owner).arready <= '1';

              -- Start accepting data; RREADY follows TFHE rready
              axi_rready <= std_logic(rd_req(current_owner).rready);
              axi_state  <= AXI_DATA;
            end if;

          ------------------------------------------------------
          -- AXI_DATA: route R channel to the current owner
          ------------------------------------------------------
          when AXI_DATA =>
            -- RREADY tracks TFHE rready
            axi_rready <= std_logic(rd_req(current_owner).rready);

            if M_AXI_RVALID = '1' then
              rd_rsp(current_owner).rdata        <= M_AXI_RDATA;
              rd_rsp(current_owner).rdata_parity <= (others => '0'); -- parity unused here
              rd_rsp(current_owner).rresp        <= M_AXI_RRESP;
              rd_rsp(current_owner).rid          <= (others => '0'); -- no ID tracking
              rd_rsp(current_owner).rvalid       <= '1';
              rd_rsp(current_owner).rlast        <= M_AXI_RLAST;

              -- Finish transaction only when handshake on last beat
              if (M_AXI_RLAST = '1') and (axi_rready = '1') then
                axi_rready <= '0';
                axi_state  <= AXI_IDLE;
              end if;
            end if;

        end case;
      end if;
    end if;
  end process;

end architecture;
