-- Copyright 2018 Delft University of Technology
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.Streams.all;
use work.Utils.all;
use work.Arrow.all;
use work.Columns.all;

use work.SimUtils.all;

use work.stringwrite_pkg.all;

-- This UserCore generates random strings to be stored in a string column in
-- the Apache Arrow format.
--
-- In our programming model it is required to have an interface to a
-- memory (host memory, wether or not copied, as long as it retains the
-- Arrow format) and a slave interface for the memory mapped registers.
--
-- This unit uses AXI interconnect to do both, where the slave interface
-- is AXI4-lite and the master interface an AXI4 full interface. For high
-- throughput, the master interface should support bursts.

entity stringwrite is
  generic (
    -- Host bus properties
    BUS_ADDR_WIDTH              : natural :=  64;
    BUS_DATA_WIDTH              : natural := 512;

    -- MMIO bus properties
    SLV_BUS_ADDR_WIDTH          : natural :=  32;
    SLV_BUS_DATA_WIDTH          : natural :=  32

    -- (Generic defaults are set for SystemVerilog compatibility)
  );

  port (
    clk                         : in  std_logic;
    reset_n                     : in  std_logic;

    ---------------------------------------------------------------------------
    -- AXI4 master
    ---------------------------------------------------------------------------
    -- Write address channel
    m_axi_awvalid               : out std_logic;
    m_axi_awready               : in  std_logic;
    m_axi_awaddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    m_axi_awlen                 : out std_logic_vector(7 downto 0);
    m_axi_awsize                : out std_logic_vector(2 downto 0);

    -- Write data channel
    m_axi_wvalid                : out std_logic;
    m_axi_wready                : in  std_logic;
    m_axi_wdata                 : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    m_axi_wlast                 : out std_logic;
    m_axi_wstrb                 : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);

    ---------------------------------------------------------------------------
    -- AXI4-lite slave
    ---------------------------------------------------------------------------
    -- Write adress
    s_axi_awvalid               : in std_logic;
    s_axi_awready               : out std_logic;
    s_axi_awaddr                : in std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);

    -- Write data
    s_axi_wvalid                : in std_logic;
    s_axi_wready                : out std_logic;
    s_axi_wdata                 : in std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
    s_axi_wstrb                 : in std_logic_vector((SLV_BUS_DATA_WIDTH/8)-1 downto 0);

    -- Write response
    s_axi_bvalid                : out std_logic;
    s_axi_bready                : in std_logic;
    s_axi_bresp                 : out std_logic_vector(1 downto 0);

    -- Read address
    s_axi_arvalid               : in std_logic;
    s_axi_arready               : out std_logic;
    s_axi_araddr                : in std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);

    -- Read data
    s_axi_rvalid                : out std_logic;
    s_axi_rready                : in std_logic;
    s_axi_rdata                 : out std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
    s_axi_rresp                 : out std_logic_vector(1 downto 0)
  );
end entity stringwrite;

architecture rtl of stringwrite is

  signal reset                  : std_logic;

  -----------------------------------------------------------------------------
  -- Memory Mapped Input/Output
  -----------------------------------------------------------------------------

  -----------------------------------
  -- Fletcher registers
  ----------------------------------- Default registers
  --   1 status (uint64)        =  2
  --   1 control (uint64)       =  2
  --   1 return (uint64)        =  2
  ----------------------------------- Buffer addresses
  --   1 offsets buf address    =  2
  --   1 values  buf address    =  2
  ----------------------------------- Custom registers
  --   1 first idx              =  1
  --   1 last idx               =  1
  --   1 strlen                 =  1
  --   1 prng mask              =  1
  -----------------------------------
  -- Total:                       14 regs
  constant NUM_FLETCHER_REGS    : natural := 14;

  -- The LSB index in the slave address
  constant SLV_ADDR_LSB        : natural := log2floor(SLV_BUS_DATA_WIDTH/4) - 1;

  -- The MSB index in the slave address
  constant SLV_ADDR_MSB         : natural := SLV_ADDR_LSB + log2floor(NUM_FLETCHER_REGS);

  -- Fletcher status register offsets
  constant REG_STATUS_HI        : natural := 0;
  constant REG_STATUS_LO        : natural := 1;

  -- Fletcher control register offsets
  constant REG_CONTROL_HI       : natural := 2;
  constant REG_CONTROL_LO       : natural := 3;

  -- Fletcher return register offsets
  constant REG_RETURN_HI        : natural := 4;
  constant REG_RETURN_LO        : natural := 5;

  -- Offset buffer address
  constant REG_OFF_ADDR_HI      : natural := 6;
  constant REG_OFF_ADDR_LO      : natural := 7;

  -- Data buffer address
  constant REG_UTF8_ADDR_HI     : natural := 8;
  constant REG_UTF8_ADDR_LO     : natural := 9;

  -- First & last index
  constant REG_FIRST_IDX        : natural := 10;
  constant REG_LAST_IDX         : natural := 11;

  -- String minimum length and mask
  constant REG_STRLEN_MIN       : natural := 12;
  constant REG_PRNG_MASK        : natural := 13;

  -- Memory mapped register file
  type mm_regs_t is array (0 to NUM_FLETCHER_REGS-1) of std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
  signal mm_regs                : mm_regs_t;

  -- Helper signals to do handshaking on the slave port
  signal read_address           : natural range 0 to NUM_FLETCHER_REGS-1;
  signal write_valid            : std_logic;
  signal read_valid             : std_logic := '0';
  signal write_processed        : std_logic;

  -----------------------------------------------------------------------------
  -- Application constants
  -----------------------------------------------------------------------------
  constant INDEX_WIDTH          : natural := 32;
  constant ELEMENT_WIDTH        : natural := 8;
  constant ELEMENT_COUNT_MAX    : natural := 64;
  constant ELEMENT_COUNT_WIDTH  : natural := log2ceil(ELEMENT_COUNT_MAX+1);

  constant BUS_BURST_STEP_LEN   : natural := 1;
  constant BUS_BURST_MAX_LEN    : natural := 16;
  -----------------------------------------------------------------------------
  -- String stream generator helper constants and signals
  -----------------------------------------------------------------------------
  constant LEN_WIDTH            : natural := 8;

  signal ssg_cmd_valid          : std_logic;
  signal ssg_cmd_ready          : std_logic;
  signal ssg_cmd_len            : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal ssg_cmd_strlen_min     : std_logic_vector(LEN_WIDTH-1 downto 0);
  signal ssg_cmd_prng_mask      : std_logic_vector(LEN_WIDTH-1 downto 0);
  signal ssg_len_valid          : std_logic;
  signal ssg_len_ready          : std_logic;
  signal ssg_len_data           : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal ssg_len_last           : std_logic;
  signal ssg_len_dvalid         : std_logic;
  signal ssg_utf8_valid         : std_logic;
  signal ssg_utf8_ready         : std_logic;
  signal ssg_utf8_data          : std_logic_vector(ELEMENT_COUNT_MAX * ELEMENT_WIDTH-1 downto 0);
  signal ssg_utf8_count         : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal ssg_utf8_last          : std_logic;
  signal ssg_utf8_dvalid        : std_logic;

  -----------------------------------------------------------------------------
  -- ColumnWriter helper constants and signals
  -----------------------------------------------------------------------------
  constant CW_DATA_WIDTH        : natural := INDEX_WIDTH +
                                             ELEMENT_WIDTH*ELEMENT_COUNT_MAX +
                                             ELEMENT_COUNT_WIDTH;

  -- Get the serialization indices for in_data
  constant ISI : nat_array := cumulative((
    2 => ELEMENT_COUNT_WIDTH,               --
    1 => ELEMENT_WIDTH * ELEMENT_COUNT_MAX, -- utf8 data
    0 => INDEX_WIDTH                        -- len data
  ));

  constant BUS_LEN_WIDTH        : natural := 9; -- 1 more than AXI

  constant CTRL_WIDTH           : natural := 2*BUS_ADDR_WIDTH;
  constant TAG_WIDTH            : natural := 1;

  signal cmd_valid              : std_logic;
  signal cmd_ready              : std_logic;
  signal cmd_firstIdx           : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_lastIdx            : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_ctrl               : std_logic_vector(CTRL_WIDTH-1 downto 0);
  signal cmd_tag                : std_logic_vector(TAG_WIDTH-1 downto 0);
  signal unlock_valid           : std_logic;
  signal unlock_ready           : std_logic;
  signal unlock_tag             : std_logic_vector(TAG_WIDTH-1 downto 0);
  signal bus_wreq_valid         : std_logic;
  signal bus_wreq_ready         : std_logic;
  signal bus_wreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_wreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_wdat_valid         : std_logic;
  signal bus_wdat_ready         : std_logic;
  signal bus_wdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_wdat_strobe        : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal bus_wdat_last          : std_logic;
  signal in_valid               : std_logic_vector(1 downto 0);
  signal in_ready               : std_logic_vector(1 downto 0);
  signal in_last                : std_logic_vector(1 downto 0);
  signal in_dvalid              : std_logic_vector(1 downto 0);
  signal in_data                : std_logic_vector(ISI(3)-1 downto 0);

  signal usercore_start         : std_logic;
  signal usercore_busy          : std_logic;
  signal usercore_done          : std_logic;
  signal usercore_reset         : std_logic;
  signal usercore_reset_start   : std_logic;
begin

  reset                         <= '1' when reset_n = '0' else '0';

  -----------------------------------------------------------------------------
  -- Memory Mapped Slave Registers
  -----------------------------------------------------------------------------
  write_valid                   <= s_axi_awvalid and s_axi_wvalid and not write_processed;

  s_axi_awready                 <= write_valid;
  s_axi_wready                  <= write_valid;
  s_axi_bresp                   <= "00"; -- Always OK
  s_axi_bvalid                  <= write_processed;

  s_axi_arready                 <= not read_valid;

  -- Mux for reading
  -- Might want to insert a reg slice before getting it to the ColumnReaders
  -- and UserCore
  s_axi_rdata                   <= mm_regs(read_address);
  s_axi_rvalid                  <= read_valid;
  s_axi_rresp                   <= "00"; -- Always OK

  -- Reads
  read_from_regs: process(clk) is
    variable address : natural range 0 to NUM_FLETCHER_REGS-1;
  begin
    if rising_edge(clk) then
      address                     := int(s_axi_araddr(SLV_ADDR_MSB downto SLV_ADDR_LSB));
      if reset_n = '0' then
        read_valid              <= '0';
      else
        if s_axi_arvalid = '1' and read_valid = '0' then
          --pragma translate off
          dumpStdOut("Read request from MMIO: " & integer'image(address) & " value " & integer'image(int(mm_regs(address))));
          --pragma translate on
          read_address          <= address;
          read_valid            <= '1';
        elsif s_axi_rready = '1' then
          read_valid            <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Writes

  -- TODO: For registers that are split up over two addresses, this is not
  -- very pretty. There should probably be some synchronization mechanism
  -- to only apply the write after both HI and LO addresses have been
  -- written.
  -- Also we don't care about byte enables at the moment.
  write_to_regs: process(clk) is
    variable address            : natural range 0 to NUM_FLETCHER_REGS;
  begin
    if rising_edge(clk) then
      address := int(s_axi_awaddr(SLV_ADDR_MSB downto SLV_ADDR_LSB));
      if write_valid = '1' then
        --pragma translate off
        dumpStdOut("Write to MMIO: " & integer'image(address));
        --pragma translate on

        case address is
          -- Read only addresses do nothing
          when REG_STATUS_HI  => -- no-op
          when REG_STATUS_LO  => -- no-op
          when REG_RETURN_HI  => -- no-op
          when REG_RETURN_LO  => -- no-op

          -- All others are writeable:
          when others         =>
            mm_regs(address)  <= s_axi_wdata;
        end case;
      else
        if usercore_reset_start = '1' then
          mm_regs(REG_CONTROL_LO)(0) <= '0';
        end if;
      end if;

      -- Read only register values:

      -- Status registers
      mm_regs(REG_STATUS_HI)    <= (others => '0');
      mm_regs(REG_STATUS_LO)(0) <= usercore_busy;
      mm_regs(REG_STATUS_LO)(1) <= usercore_done;

      -- Return registers
      mm_regs(REG_RETURN_HI)    <= (others => '0');
      mm_regs(REG_RETURN_LO)    <= (others => '0');

      -- Control register reset
      if reset_n = '0' then
        mm_regs(REG_CONTROL_LO) <= (others => '0');
        mm_regs(REG_CONTROL_HI) <= (others => '0');
      end if;

    end if;
  end process;

  -- Write response
  write_resp_proc: process(clk) is
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        write_processed <= '0';
      else
        if write_valid = '1' then
          write_processed <= '1';
        elsif s_axi_bready = '1' then
          write_processed <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Slice up (without backpressure) the control signals
  reg_settings: process(clk)
  begin
    if rising_edge(clk) then
      -- Control bits
      usercore_start <= mm_regs(REG_CONTROL_LO)(0);
      usercore_reset <= mm_regs(REG_CONTROL_LO)(1);
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Global control state machine
  -----------------------------------------------------------------------------
  global_sm: block is
    type state_type is (IDLE, STRINGGEN, COLUMNWRITER, UNLOCK);

    type reg_record is record
      busy                      : std_logic;
      done                      : std_logic;
      reset_start               : std_logic;
      state                     : state_type;
    end record;

    type cmd_record is record
      valid                     : std_logic;
      firstIdx                  : std_logic_vector(INDEX_WIDTH-1 downto 0);
      lastIdx                   : std_logic_vector(INDEX_WIDTH-1 downto 0);
      ctrl                      : std_logic_vector(CTRL_WIDTH-1 downto 0);
      tag                       : std_logic_vector(TAG_WIDTH-1 downto 0);
    end record;

    type str_record is record
      valid                     : std_logic;
      len                       : std_logic_vector(INDEX_WIDTH-1 downto 0);
      min                       : std_logic_vector(LEN_WIDTH-1 downto 0);
      mask                      : std_logic_vector(LEN_WIDTH-1 downto 0);
    end record;

    type unl_record is record
      ready                     : std_logic;
    end record;

    type out_record is record
      cmd                       : cmd_record;
      str                       : str_record;
      unl                       : unl_record;
    end record;

    signal r : reg_record;
    signal d : reg_record;
  begin
    seq_proc: process(clk) is
    begin
      if rising_edge(clk) then
        r <= d;

        -- Reset
        if reset = '1' then
          r.state         <= IDLE;
          r.reset_start   <= '0';
          r.busy          <= '0';
          r.done          <= '0';
        end if;
      end if;
    end process;

    comb_proc: process(r,
      usercore_start,
      mm_regs(REG_OFF_ADDR_HI), mm_regs(REG_OFF_ADDR_LO),
      mm_regs(REG_UTF8_ADDR_HI), mm_regs(REG_UTF8_ADDR_LO),
      cmd_ready,
      ssg_cmd_ready,
      unlock_valid, unlock_tag
    ) is
      variable v : reg_record;
      variable o : out_record;
    begin
      v := r;

      -- Disable command streams by default
      o.cmd.valid               := '0';
      o.str.valid               := '0';
      o.unl.ready               := '0';

      -- Default outputs
      o.cmd.firstIdx            := mm_regs(REG_FIRST_IDX);
      o.cmd.lastIdx             := mm_regs(REG_LAST_IDX);
      -- Values buffer at LSBs
      o.cmd.ctrl(BUS_ADDR_WIDTH-1 downto 0)
        := mm_regs(REG_UTF8_ADDR_HI) & mm_regs(REG_UTF8_ADDR_LO);
      -- Index buffer at MSBs
      o.cmd.ctrl(2*BUS_ADDR_WIDTH-1 downto BUS_ADDR_WIDTH)
        := mm_regs(REG_OFF_ADDR_HI) & mm_regs(REG_OFF_ADDR_LO);

      o.cmd.tag                 := (0 => '1', others => '0');

      -- We use the last index to determine how many strings have to be
      -- generated. This assumes firstIdx is 0.
      o.str.len  := mm_regs(REG_LAST_IDX);
      o.str.min  := mm_regs(REG_STRLEN_MIN)(LEN_WIDTH-1 downto 0);
      o.str.mask := mm_regs(REG_PRNG_MASK)(LEN_WIDTH-1 downto 0);
      -- Note: string lengths that are generated will be:
      -- (minimum string length) + ((PRNG output) bitwise and (PRNG mask))
      -- Set STRLEN_MIN to 0 and PRNG_MASK to all 1's (strongly not
      -- recommended) to generate all possible string lengths.

      -- Reset start is low by default.
      v.reset_start := '0';
      
      case r.state is
        when IDLE =>
          if usercore_start = '1' then
            v.reset_start := '1';
            v.state := STRINGGEN;
            v.busy := '1';
            v.done := '0';
          end if;

        when STRINGGEN =>
          -- Validate command:
          o.str.valid := '1';

          if ssg_cmd_ready = '1' then
            -- Command is accepted, start the ColumnWriter
            v.state := COLUMNWRITER;
          end if;

        when COLUMNWRITER =>
          -- Validate command:
          o.cmd.valid    := '1';

          if cmd_ready = '1' then
            -- Command is accepted, wait for unlock.
            v.state := UNLOCK;
          end if;

        when UNLOCK =>
          o.unl.ready := '1';

          if unlock_valid = '1' then
            v.state := IDLE;
            -- Make done and reset busy
            v.done := '1';
            v.busy := '0';
          end if;

      end case;

      -- Registered outputs
      d                         <= v;

      -- Combinatorial outputs
      cmd_valid                 <= o.cmd.valid;
      cmd_firstIdx              <= o.cmd.firstIdx;
      cmd_lastIdx               <= o.cmd.lastIdx;
      cmd_ctrl                  <= o.cmd.ctrl;
      cmd_tag                   <= o.cmd.tag;

      ssg_cmd_valid             <= o.str.valid;
      ssg_cmd_len               <= o.str.len;
      ssg_cmd_prng_mask         <= o.str.mask;
      ssg_cmd_strlen_min        <= o.str.min;

      unlock_ready              <= o.unl.ready;

    end process;

    -- Registered output
    usercore_reset_start      <= r.reset_start;
    usercore_busy             <= r.busy;
    usercore_done             <= r.done;

  end block;

  -----------------------------------------------------------------------------
  -- String generator unit
  -----------------------------------------------------------------------------
  -- Generates a pseudorandom stream of lengths and characters with appropriate
  -- last signals and counts

  stream_gen_inst: UTF8StringGen
    generic map (
      INDEX_WIDTH           => INDEX_WIDTH,
      ELEMENT_WIDTH         => ELEMENT_WIDTH,
      ELEMENT_COUNT_MAX     => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH   => ELEMENT_COUNT_WIDTH,
      LEN_WIDTH             => LEN_WIDTH,
      LENGTH_BUFFER_DEPTH   => 32,
      LEN_SLICE             => true,
      UTF8_SLICE            => true
    )
    port map (
      clk                   => clk,
      reset                 => reset,
      cmd_valid             => ssg_cmd_valid,
      cmd_ready             => ssg_cmd_ready,
      cmd_len               => ssg_cmd_len,
      cmd_strlen_min        => ssg_cmd_strlen_min,
      cmd_prng_mask         => ssg_cmd_prng_mask,
      len_valid             => ssg_len_valid,
      len_ready             => ssg_len_ready,
      len_data              => ssg_len_data,
      len_last              => ssg_len_last,
      len_dvalid            => ssg_len_dvalid,
      utf8_valid            => ssg_utf8_valid,
      utf8_ready            => ssg_utf8_ready,
      utf8_data             => ssg_utf8_data,
      utf8_count            => ssg_utf8_count,
      utf8_last             => ssg_utf8_last,
      utf8_dvalid           => ssg_utf8_dvalid
    );

  -----------------------------------------------------------------------------
  -- AXI write converter
  -----------------------------------------------------------------------------
  -- Converts Fletcher bus write signals to AXI
  axi_write_conv_inst: axi_write_converter
    generic map (
      ADDR_WIDTH                => BUS_ADDR_WIDTH,
      MASTER_DATA_WIDTH         => BUS_DATA_WIDTH,
      MASTER_LEN_WIDTH          => 8,
      SLAVE_DATA_WIDTH          => BUS_DATA_WIDTH,
      SLAVE_LEN_WIDTH           => BUS_LEN_WIDTH,
      SLAVE_MAX_BURST           => BUS_BURST_MAX_LEN,
      ENABLE_FIFO               => false
    )
    port map (
      clk                       => clk,
      reset_n                   => reset_n,
      slv_bus_wreq_valid        => bus_wreq_valid,
      slv_bus_wreq_ready        => bus_wreq_ready,
      slv_bus_wreq_addr         => bus_wreq_addr,
      slv_bus_wreq_len          => bus_wreq_len,
      slv_bus_wdat_valid        => bus_wdat_valid,
      slv_bus_wdat_ready        => bus_wdat_ready,
      slv_bus_wdat_data         => bus_wdat_data,
      slv_bus_wdat_strobe       => bus_wdat_strobe,
      slv_bus_wdat_last         => bus_wdat_last,
      m_axi_awaddr              => m_axi_awaddr,
      m_axi_awlen               => m_axi_awlen,
      m_axi_awvalid             => m_axi_awvalid,
      m_axi_awready             => m_axi_awready,
      m_axi_awsize              => m_axi_awsize,
      m_axi_wvalid              => m_axi_wvalid,
      m_axi_wready              => m_axi_wready,
      m_axi_wdata               => m_axi_wdata,
      m_axi_wstrb               => m_axi_wstrb,
      m_axi_wlast               => m_axi_wlast
    );

  -----------------------------------------------------------------------------
  -- ColumnWriter
  -----------------------------------------------------------------------------
  -- Converts the stream of lengths and strings to Apache Arrow format in the
  -- host memory.

  -- Serialize the inputs for the length stream
  in_valid(0)                     <= ssg_len_valid;
  ssg_len_ready                   <= in_ready(0);
  in_data(ISI(1)-1 downto ISI(0)) <= ssg_len_data;
  in_last(0)                      <= ssg_len_last;
  in_dvalid(0)                    <= ssg_len_dvalid;

  -- Serialize the inputs for the data stream
  in_valid(1)                     <= ssg_utf8_valid;
  ssg_utf8_ready                  <= in_ready(1);
  in_data(ISI(2)-1 downto ISI(1)) <= ssg_utf8_data;
  in_data(ISI(3)-1 downto ISI(2)) <= ssg_utf8_count;
  in_last(1)                      <= ssg_utf8_last;
  in_dvalid(1)                    <= ssg_utf8_dvalid;

  -- Instantiate ColumnWriter
  cw_inst : ColumnWriter
    generic map (
      BUS_ADDR_WIDTH      => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH       => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH      => BUS_DATA_WIDTH,
      BUS_STROBE_WIDTH    => BUS_DATA_WIDTH/8,
      BUS_BURST_STEP_LEN  => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN   => BUS_BURST_MAX_LEN,
      INDEX_WIDTH         => INDEX_WIDTH,
      CFG                 => "listprim(8;epc=" & ii(ELEMENT_COUNT_MAX) & ")",
      CMD_TAG_ENABLE      => true,
      CMD_TAG_WIDTH       => TAG_WIDTH
    )
    port map (
      bus_clk             => clk,
      bus_reset           => reset,
      acc_clk             => clk,
      acc_reset           => reset,
      cmd_valid           => cmd_valid,
      cmd_ready           => cmd_ready,
      cmd_firstIdx        => cmd_firstIdx,
      cmd_lastIdx         => cmd_lastIdx,
      cmd_ctrl            => cmd_ctrl,
      cmd_tag             => cmd_tag,
      unlock_valid        => unlock_valid,
      unlock_ready        => unlock_ready,
      unlock_tag          => unlock_tag,
      bus_wreq_valid      => bus_wreq_valid,
      bus_wreq_ready      => bus_wreq_ready,
      bus_wreq_addr       => bus_wreq_addr,
      bus_wreq_len        => bus_wreq_len,
      bus_wdat_valid      => bus_wdat_valid,
      bus_wdat_ready      => bus_wdat_ready,
      bus_wdat_data       => bus_wdat_data,
      bus_wdat_strobe     => bus_wdat_strobe,
      bus_wdat_last       => bus_wdat_last,
      in_valid            => in_valid,
      in_ready            => in_ready,
      in_last             => in_last,
      in_dvalid           => in_dvalid,
      in_data             => in_data
    );

end architecture;
