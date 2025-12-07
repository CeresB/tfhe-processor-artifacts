entity hbm_read_to_axi is
  generic (
    C_AXI_ADDR_WIDTH : integer := 34;
    C_AXI_DATA_WIDTH : integer := 256
  );
  port (
    i_clk       : in  std_logic;
    i_reset_n   : in  std_logic;

    -- Custom HBM-style read port
    i_req       : in  hbm_ps_in_read_pkg;
    o_rsp       : out hbm_ps_out_read_pkg;

    -- AXI read address channel
    M_AXI_ARADDR  : out std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);
    M_AXI_ARLEN   : out std_logic_vector(7 downto 0);
    M_AXI_ARSIZE  : out std_logic_vector(2 downto 0);
    M_AXI_ARBURST : out std_logic_vector(1 downto 0);
    M_AXI_ARVALID : out std_logic;
    M_AXI_ARREADY : in  std_logic;

    -- AXI read data channel
    M_AXI_RDATA   : in  std_logic_vector(C_AXI_DATA_WIDTH-1 downto 0);
    M_AXI_RRESP   : in  std_logic_vector(1 downto 0);
    M_AXI_RLAST   : in  std_logic;
    M_AXI_RVALID  : in  std_logic;
    M_AXI_RREADY  : out std_logic
  );
end entity;

architecture rtl of hbm_read_to_axi is
  type state_t is (IDLE, SEND_AR, READ_DATA);
  signal state : state_t;

  signal araddr_reg  : std_logic_vector(C_AXI_ADDR_WIDTH-1 downto 0);
  signal arlen_reg   : std_logic_vector(7 downto 0);
begin

  process(i_clk)
  begin
    if rising_edge(i_clk) then
      if i_reset_n = '0' then
        state          <= IDLE;
        M_AXI_ARVALID  <= '0';
        M_AXI_RREADY   <= '0';
        o_rsp.valid    <= '0';
        -- init others...
      else
        case state is
          when IDLE =>
            o_rsp.valid <= '0';
            M_AXI_RREADY <= '0';

            if i_req.valid = '1' then
              -- Map record fields:
              araddr_reg   <= std_logic_vector(i_req.addr); -- adjust type/resizing
              arlen_reg    <= std_logic_vector(i_req.len);  -- beats-1

              M_AXI_ARADDR  <= std_logic_vector(i_req.addr);
              M_AXI_ARLEN   <= std_logic_vector(i_req.len);
              M_AXI_ARSIZE  <= "101"; -- log2(bytes per beat): 2^5 = 32 bytes for 256b, adjust
              M_AXI_ARBURST <= "01";  -- INCR
              M_AXI_ARVALID <= '1';
              state         <= SEND_AR;
            end if;

          when SEND_AR =>
            if M_AXI_ARVALID = '1' and M_AXI_ARREADY = '1' then
              M_AXI_ARVALID <= '0';
              M_AXI_RREADY  <= '1';
              state         <= READ_DATA;
            end if;

          when READ_DATA =>
            if M_AXI_RVALID = '1' then
              -- Drive HBM response record
              o_rsp.data  <= M_AXI_RDATA;
              o_rsp.valid <= '1';
              o_rsp.last  <= M_AXI_RLAST;  -- if field exists 
              if M_AXI_RLAST = '1' then
                M_AXI_RREADY <= '0';
                state        <= IDLE;
              end if;
            else
              o_rsp.valid <= '0';
            end if;

        end case;
      end if;
    end if;
  end process;
end architecture;
