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
use work.Interconnect.all;
use work.AXI.all;

use work.SimUtils.all;

use work.arrow_regexp_pkg.all;

-- This UserCore matches regular expressions stored in a string column
-- in the Apache Arrow format.
--
-- In our programming model it is required to have an interface to a
-- memory (host memory, wether or not copied, as long as it retains the
-- Arrow format) and a slave interface for the memory mapped registers.
--
-- This unit uses AXI interconnect to do both, where the slave interface
-- is AXI4-lite and the master interface an AXI4 full interface. For high
-- throughput, the master interface should support bursts.

entity arrow_regexp is
  generic (
    -- Number of Regexp units. Must be a natural multiple of 2
    CORES                       : natural :=  16;

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
    -- Read address channel
    m_axi_araddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    m_axi_arlen                 : out std_logic_vector(7 downto 0);
    m_axi_arvalid               : out std_logic;
    m_axi_arready               : in  std_logic;
    m_axi_arsize                : out std_logic_vector(2 downto 0);

    -- Read data channel
    m_axi_rdata                 : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    m_axi_rresp                 : in  std_logic_vector(1 downto 0);
    m_axi_rlast                 : in  std_logic;
    m_axi_rvalid                : in  std_logic;
    m_axi_rready                : out std_logic;

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
end entity arrow_regexp;

architecture rtl of arrow_regexp is

  signal reset                  : std_logic;

  -- Bottom buses
  constant BB                   : natural := 16;

  -- Number of regexes
  constant NUM_REGEX            : natural := 16;

  -----------------------------------------------------------------------------
  -- Memory Mapped Input/Output
  -----------------------------------------------------------------------------

  -----------------------------------
  -- Fletcher registers
  ----------------------------------- Default registers
  --   0   control  (uint32_t)  =  1
  --   1   status   (uint32_t)  =  1
  --   2   return0  (uint32_t)  =  1
  --   3   return1  (uint32_t)  =  1
  --   4   firstidx (uint32_t)  =  1
  --   5   lastidx  (uint32_t)  =  1
  ----------------------------------- Buffer addresses
  --   6 offsets buf address lo =  1
  --   7 offsets buf address hi =  1
  --   8 values buf address lo  =  1
  --   9 values buf address hi  =  1
  ----------------------------------- Custom registers
  --  10 custom first idx 16x   = 16
  --  26 custom last idx 16x    = 16
  --  42 regex results          = 16
  -----------------------------------
  -- Total:                       58 regs
  constant NUM_FLETCHER_REGS    : natural := 58;

  -- The LSB index in the slave address
  constant SLV_ADDR_LSB         : natural := log2floor(SLV_BUS_DATA_WIDTH/4) - 1;

  -- The MSB index in the slave address
  constant SLV_ADDR_MSB         : natural := SLV_ADDR_LSB + log2floor(NUM_FLETCHER_REGS);


  -- Fletcher register offsets
  
  constant REG_CONTROL          : natural := 0;
  -- The offsets of the bits to signal start and reset to each of the units
  constant CONTROL_START_OFFSET : natural := 0;
  constant CONTROL_RESET_OFFSET : natural := CORES;

  constant REG_STATUS           : natural := 1;
  -- The offsets of the bits to signal busy and done for each of the units
  constant STATUS_BUSY_OFFSET   : natural := 0;
  constant STATUS_DONE_OFFSET   : natural := CORES;

  -- Return register
  constant REG_RETURN0          : natural := 2;
  constant REG_RETURN1          : natural := 3;
  
  -- Fixed first and last index
  constant REG_FIRSTIDX         : natural := 4;
  constant REG_LASTIDX          : natural := 5;

  -- Offset buffer address
  constant REG_OFF_ADDR_LO      : natural := 6;
  constant REG_OFF_ADDR_HI      : natural := 7;

  -- Values buffer address
  constant REG_UTF8_ADDR_LO     : natural := 8;
  constant REG_UTF8_ADDR_HI     : natural := 9;

  -- Register offsets to indices for each RegExp unit to work on
  constant REG_CUST_FIRST_IDX   : natural := 10;
  constant REG_CUST_LAST_IDX    : natural := 26;

  -- Register offset for each RegExp unit to put its result
  constant REG_RESULT       	: natural := 42;

  -- Memory mapped register file
  type mm_regs_t is array (0 to NUM_FLETCHER_REGS-1) of std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
  signal mm_regs                : mm_regs_t;

  -- Helper signals to do handshaking on the slave port
  signal read_address           : natural range 0 to NUM_FLETCHER_REGS-1;
  signal write_valid            : std_logic;
  signal read_valid             : std_logic := '0';
  signal write_processed        : std_logic;

  -----------------------------------------------------------------------------
  -- AXI Interconnect Master Ports
  -----------------------------------------------------------------------------
  type bus_bottom_array_t       is array (0 to BB-1) of bus_bottom_t;
  type axi_mid_array_t          is array (0 to BB-1) of axi_mid_t;

  signal bus_bottom_array       : bus_bottom_array_t;
  signal axi_mid_array          : axi_mid_array_t;
  signal axi_top                : axi_top_t;

  -----------------------------------------------------------------------------
  -- Registers
  -----------------------------------------------------------------------------
  type reg_array_t is array (0 to CORES-1) of std_logic_vector(31 downto 0);

  signal reg_array_firstidx     : reg_array_t;
  signal reg_array_lastidx      : reg_array_t;
  signal reg_array_off_lo       : reg_array_t;
  signal reg_array_off_hi       : reg_array_t;
  signal reg_array_utf8_lo      : reg_array_t;
  signal reg_array_utf8_hi      : reg_array_t;

  signal bit_array_control_reset: std_logic_vector(CORES-1 downto 0);
  signal bit_array_control_start: std_logic_vector(CORES-1 downto 0);
  signal bit_array_reset_start  : std_logic_vector(CORES-1 downto 0);
  signal bit_array_busy         : std_logic_vector(CORES-1 downto 0);
  signal bit_array_done         : std_logic_vector(CORES-1 downto 0);

  -----------------------------------------------------------------------------
  -- Result adder tree
  -----------------------------------------------------------------------------

  type result_conv_t is array(0 to CORES-1) of std_logic_vector(NUM_REGEX*32-1 downto 0);
  signal result_conv            : result_conv_t;

  type result_array_t is array (0 to CORES-1) of std_logic_vector(31 downto 0);
  type regex_result_array_t is array (0 to NUM_REGEX-1) of result_array_t;
  signal result_array           : regex_result_array_t;

  -- The width of the innermost array is 2^log2ceil(cores) instead of cores-1
  -- such that even no. cores is possible vs. only powers of 2 no. cores.
  type result_add_t is array (0 to 2**log2ceil(CORES)) of unsigned(31 downto 0);

  type result_add_tree_t is array (0 to log2ceil(CORES)) of result_add_t;
  type regex_result_add_tree_t is array(0 to NUM_REGEX-1) of result_add_tree_t;

  signal result_add             : regex_result_add_tree_t;

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
    address                     := int(s_axi_araddr(SLV_ADDR_MSB downto SLV_ADDR_LSB));

    if rising_edge(clk) then
      if reset_n = '0' then
        read_valid              <= '0';
      else
        if s_axi_arvalid = '1' and read_valid = '0' then
          --dumpStdOut("Read request from MMIO: " & integer'image(address) & " value " & integer'image(int(mm_regs(address))));
          read_address          <= address;
          read_valid            <= '1';
        elsif s_axi_rready = '1' then
          read_valid            <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Writes
  -- We don't care about byte enables at the moment.
  write_to_regs: process(clk) is
    variable address            : natural range 0 to NUM_FLETCHER_REGS;
  begin

    address                     := int(s_axi_awaddr(SLV_ADDR_MSB downto SLV_ADDR_LSB));

    if rising_edge(clk) then
      if write_valid = '1' then
        --dumpStdOut("Write to MMIO: " & integer'image(address));

        case address is
          -- Read only addresses do nothing
          when REG_STATUS  =>
          when REG_RETURN0 =>
          when REG_RETURN1 =>
          when REG_RESULT to REG_RESULT + NUM_REGEX - 1 =>
          -- All others are writeable:
          when others =>
            mm_regs(address)  <= s_axi_wdata;
        end case;
      else
        -- Control register is also resettable by individual units
        for I in 0 to CORES-1 loop
          if bit_array_reset_start(I) = '1' then
            mm_regs(REG_CONTROL)(CONTROL_START_OFFSET + I) <= '0';
          end if;
        end loop;
      end if;

      -- Read only register values:

      if CORES /= 16 then
        mm_regs(REG_STATUS)(SLV_BUS_DATA_WIDTH-1 downto STATUS_DONE_OFFSET + CORES) <= (others => '0');
      end if;

      mm_regs(REG_STATUS)(STATUS_BUSY_OFFSET + CORES - 1 downto STATUS_BUSY_OFFSET) <= bit_array_busy;
      mm_regs(REG_STATUS)(STATUS_DONE_OFFSET + CORES - 1 downto STATUS_DONE_OFFSET) <= bit_array_done;

      -- Return registers
      mm_regs(REG_RETURN0) <= slv(result_add(0)(0)(0));
      mm_regs(REG_RETURN1) <= (others => '0');

      -- Result registers
      for R in 0 to NUM_REGEX-1 loop
        mm_regs(REG_RESULT + R) <= slv(result_add(R)(0)(0));
      end loop;

      if reset_n = '0' then
        mm_regs(REG_CONTROL) <= (others => '0');
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

  -- Some registers between paths to units
  reg_settings: process(clk)
  begin
    if rising_edge(clk) then
      -- Control bits
      bit_array_control_start <= mm_regs(REG_CONTROL)(CONTROL_START_OFFSET + CORES -1 downto CONTROL_START_OFFSET);
      bit_array_control_reset <= mm_regs(REG_CONTROL)(CONTROL_RESET_OFFSET + CORES -1 downto CONTROL_RESET_OFFSET);

      -- Registers
      reg_gen: for I in 0 to CORES-1 loop
        -- Local
        reg_array_firstidx(I) <= mm_regs(REG_CUST_FIRST_IDX + I);
        reg_array_lastidx(I) <= mm_regs(REG_CUST_LAST_IDX + I);
        -- Global
        reg_array_off_lo (I) <= mm_regs(REG_OFF_ADDR_LO);
        reg_array_off_hi (I) <= mm_regs(REG_OFF_ADDR_HI);
        reg_array_utf8_lo(I) <= mm_regs(REG_UTF8_ADDR_LO);
        reg_array_utf8_hi(I) <= mm_regs(REG_UTF8_ADDR_HI);
      end loop;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Master
  -----------------------------------------------------------------------------
  -- Read address channel
  axi_top.arready               <= m_axi_arready;

  m_axi_arvalid                 <= axi_top.arvalid;
  m_axi_araddr                  <= axi_top.araddr;

  m_axi_arlen                   <= axi_top.arlen;

  m_axi_arsize                  <= "110"; --6 for 2^6*8 bits = 512 bits

  -- Read data channel
  m_axi_rready                  <= axi_top.rready ;

  axi_top.rvalid                <= m_axi_rvalid;
  axi_top.rdata                 <= m_axi_rdata;
  axi_top.rresp                 <= m_axi_rresp;
  axi_top.rlast                 <= m_axi_rlast;

  regex_add_tree: for R in 0 to NUM_REGEX-1 generate
    -----------------------------------------------------------------------------
    -- Adder tree assuming CORES is even
    -----------------------------------------------------------------------------
    -- TODO: somehow make sure that when the result regs are read that there is
    -- nothing left in the adder tree pipeline.
    process(clk) is
    begin
      if rising_edge(clk) then
        -- Top level
        for I in 0 to CORES-1 loop
          result_add(R)(log2ceil(CORES))(I) <= u(result_array(R)(I));
        end loop;

        -- Other levels
        for L in log2ceil(CORES)-1 downto 0 loop -- 3,2,1,0
          for I in 0 to (2**L)-1 loop -- 8,4,2,1
            result_add(R)(L)(I) <= result_add(R)(L+1)(2*I) + result_add(R)(L+1)(2*I+1);
          end loop;
        end loop;
      end if;
    end process;
  end generate;

  -----------------------------------------------------------------------------
  -- Bottom layer
  -----------------------------------------------------------------------------
  bottom_regexp_gen: for I in 0 to CORES-1 generate

    -- Convert axi read address channel and read response channel
    -- Scales "len" and "size" according to the master data width
    -- and converts the Fletcher bus "len" to AXI bus "len"
    read_converter_inst: axi_read_converter generic map (
      ADDR_WIDTH                => BUS_ADDR_WIDTH,
      MASTER_DATA_WIDTH         => BUS_DATA_WIDTH,
      MASTER_LEN_WIDTH          => 8,
      SLAVE_DATA_WIDTH          => BOTTOM_DATA_WIDTH,
      SLAVE_LEN_WIDTH           => BOTTOM_LEN_WIDTH,
      SLAVE_MAX_BURST           => BOTTOM_BURST_MAX_LEN,
      ENABLE_FIFO               => BOTTOM_ENABLE_FIFO
    )
    port map (
      clk                       => clk,
      reset_n                   => reset_n,
      slv_bus_rreq_addr         => bus_bottom_array(I).rreq_addr,
      slv_bus_rreq_len          => bus_bottom_array(I).rreq_len,
      slv_bus_rreq_valid        => bus_bottom_array(I).rreq_valid,
      slv_bus_rreq_ready        => bus_bottom_array(I).rreq_ready,
      slv_bus_rdat_data         => bus_bottom_array(I).rdat_data,
      slv_bus_rdat_last         => bus_bottom_array(I).rdat_last,
      slv_bus_rdat_valid        => bus_bottom_array(I).rdat_valid,
      slv_bus_rdat_ready        => bus_bottom_array(I).rdat_ready,
      m_axi_araddr              => axi_mid_array(I).araddr,
      m_axi_arlen               => axi_mid_array(I).arlen,
      m_axi_arvalid             => axi_mid_array(I).arvalid,
      m_axi_arready             => axi_mid_array(I).arready,
      m_axi_arsize              => axi_mid_array(I).arsize,
      m_axi_rdata               => axi_mid_array(I).rdata,
      m_axi_rlast               => axi_mid_array(I).rlast,
      m_axi_rvalid              => axi_mid_array(I).rvalid,
      m_axi_rready              => axi_mid_array(I).rready
    );

    -- utf8 regular expression matcher generation
    regexp_inst: arrow_regexp_unit generic map (
      NUM_REGEX                 => NUM_REGEX,
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_DATA_WIDTH            => BOTTOM_DATA_WIDTH,
      BUS_LEN_WIDTH             => BOTTOM_LEN_WIDTH,
      BUS_BURST_STEP_LEN        => BOTTOM_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BOTTOM_BURST_MAX_LEN,
      REG_WIDTH                 => 32,
      ID                        => I
    ) port map (
      clk                       => clk,
      reset_n                   => reset_n,

      control_reset             => bit_array_control_reset(I),
      control_start             => bit_array_control_start(I),
      reset_start               => bit_array_reset_start  (I),
      busy                      => bit_array_busy         (I),
      done                      => bit_array_done         (I),

      firstidx                  => reg_array_firstidx     (I),
      lastidx                   => reg_array_lastidx      (I),
      off_hi                    => reg_array_off_hi       (I),
      off_lo                    => reg_array_off_lo       (I),
      utf8_hi                   => reg_array_utf8_hi      (I),
      utf8_lo                   => reg_array_utf8_lo      (I),

      matches                   => result_conv            (I),

      mst_bus_rreq_addr          => bus_bottom_array(I).rreq_addr ,
      mst_bus_rreq_len           => bus_bottom_array(I).rreq_len  ,
      mst_bus_rreq_valid         => bus_bottom_array(I).rreq_valid,
      mst_bus_rreq_ready         => bus_bottom_array(I).rreq_ready,
      mst_bus_rdat_data          => bus_bottom_array(I).rdat_data  ,
      mst_bus_rdat_last          => bus_bottom_array(I).rdat_last  ,
      mst_bus_rdat_valid         => bus_bottom_array(I).rdat_valid ,
      mst_bus_rdat_ready         => bus_bottom_array(I).rdat_ready
    );

    -- Pass through result to right result_array:
    result_conv_gen: for R in 0 to NUM_REGEX-1 generate
      result_array(R)(I) <= result_conv(I)(32*(R+1)-1 downto (32*R));
    end generate;
  end generate;

  -- Tie off unused ports, if any
  unused_gen: for I in CORES to BB-1 generate
    axi_mid_array(I).araddr     <= (others => '0');
    axi_mid_array(I).arlen      <= (others => '0');
    axi_mid_array(I).arvalid    <= '0';
    axi_mid_array(I).arsize     <= (others => '0');
    axi_mid_array(I).rready     <= '0';
    axi_mid_array(I).aclk       <= clk;
  end generate;

  -----------------------------------------------------------------------------
  -- Mid layer interconnect generation
  -----------------------------------------------------------------------------
  -- Interconnect

  mid_interconnect: BusReadArbiter generic map (
    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,
    BUS_LEN_WIDTH               => 8,
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
    NUM_SLAVE_PORTS             => CORES,
    ARB_METHOD                  => "ROUND-ROBIN",
    MAX_OUTSTANDING             => 32,
    RAM_CONFIG                  => "",
    SLV_REQ_SLICES              => false,
    MST_REQ_SLICE               => false,
    MST_DAT_SLICE               => false,
    SLV_DAT_SLICES              => false
  )
  port map (
    bus_clk                     => clk,
    bus_reset                   => reset,
    mst_rreq_valid              => axi_top.arvalid,
    mst_rreq_ready              => axi_top.arready,
    mst_rreq_addr               => axi_top.araddr,
    mst_rreq_len                => axi_top.arlen,
    mst_rdat_valid              => axi_top.rvalid,
    mst_rdat_ready              => axi_top.rready,
    mst_rdat_data               => axi_top.rdata,
    mst_rdat_last               => axi_top.rlast,
    bs00_rreq_valid             => axi_mid_array(0 ).arvalid,
    bs00_rreq_ready             => axi_mid_array(0 ).arready,
    bs00_rreq_addr              => axi_mid_array(0 ).araddr,
    bs00_rreq_len               => axi_mid_array(0 ).arlen,
    bs00_rdat_valid             => axi_mid_array(0 ).rvalid,
    bs00_rdat_ready             => axi_mid_array(0 ).rready,
    bs00_rdat_data              => axi_mid_array(0 ).rdata,
    bs00_rdat_last              => axi_mid_array(0 ).rlast,
    bs01_rreq_valid             => axi_mid_array(1 ).arvalid,
    bs01_rreq_ready             => axi_mid_array(1 ).arready,
    bs01_rreq_addr              => axi_mid_array(1 ).araddr,
    bs01_rreq_len               => axi_mid_array(1 ).arlen,
    bs01_rdat_valid             => axi_mid_array(1 ).rvalid,
    bs01_rdat_ready             => axi_mid_array(1 ).rready,
    bs01_rdat_data              => axi_mid_array(1 ).rdata,
    bs01_rdat_last              => axi_mid_array(1 ).rlast,
    bs02_rreq_valid             => axi_mid_array(2 ).arvalid,
    bs02_rreq_ready             => axi_mid_array(2 ).arready,
    bs02_rreq_addr              => axi_mid_array(2 ).araddr,
    bs02_rreq_len               => axi_mid_array(2 ).arlen,
    bs02_rdat_valid             => axi_mid_array(2 ).rvalid,
    bs02_rdat_ready             => axi_mid_array(2 ).rready,
    bs02_rdat_data              => axi_mid_array(2 ).rdata,
    bs02_rdat_last              => axi_mid_array(2 ).rlast,
    bs03_rreq_valid             => axi_mid_array(3 ).arvalid,
    bs03_rreq_ready             => axi_mid_array(3 ).arready,
    bs03_rreq_addr              => axi_mid_array(3 ).araddr,
    bs03_rreq_len               => axi_mid_array(3 ).arlen,
    bs03_rdat_valid             => axi_mid_array(3 ).rvalid,
    bs03_rdat_ready             => axi_mid_array(3 ).rready,
    bs03_rdat_data              => axi_mid_array(3 ).rdata,
    bs03_rdat_last              => axi_mid_array(3 ).rlast,
    bs04_rreq_valid             => axi_mid_array(4 ).arvalid,
    bs04_rreq_ready             => axi_mid_array(4 ).arready,
    bs04_rreq_addr              => axi_mid_array(4 ).araddr,
    bs04_rreq_len               => axi_mid_array(4 ).arlen,
    bs04_rdat_valid             => axi_mid_array(4 ).rvalid,
    bs04_rdat_ready             => axi_mid_array(4 ).rready,
    bs04_rdat_data              => axi_mid_array(4 ).rdata,
    bs04_rdat_last              => axi_mid_array(4 ).rlast,
    bs05_rreq_valid             => axi_mid_array(5 ).arvalid,
    bs05_rreq_ready             => axi_mid_array(5 ).arready,
    bs05_rreq_addr              => axi_mid_array(5 ).araddr,
    bs05_rreq_len               => axi_mid_array(5 ).arlen,
    bs05_rdat_valid             => axi_mid_array(5 ).rvalid,
    bs05_rdat_ready             => axi_mid_array(5 ).rready,
    bs05_rdat_data              => axi_mid_array(5 ).rdata,
    bs05_rdat_last              => axi_mid_array(5 ).rlast,
    bs06_rreq_valid             => axi_mid_array(6 ).arvalid,
    bs06_rreq_ready             => axi_mid_array(6 ).arready,
    bs06_rreq_addr              => axi_mid_array(6 ).araddr,
    bs06_rreq_len               => axi_mid_array(6 ).arlen,
    bs06_rdat_valid             => axi_mid_array(6 ).rvalid,
    bs06_rdat_ready             => axi_mid_array(6 ).rready,
    bs06_rdat_data              => axi_mid_array(6 ).rdata,
    bs06_rdat_last              => axi_mid_array(6 ).rlast,
    bs07_rreq_valid             => axi_mid_array(7 ).arvalid,
    bs07_rreq_ready             => axi_mid_array(7 ).arready,
    bs07_rreq_addr              => axi_mid_array(7 ).araddr,
    bs07_rreq_len               => axi_mid_array(7 ).arlen,
    bs07_rdat_valid             => axi_mid_array(7 ).rvalid,
    bs07_rdat_ready             => axi_mid_array(7 ).rready,
    bs07_rdat_data              => axi_mid_array(7 ).rdata,
    bs07_rdat_last              => axi_mid_array(7 ).rlast,
    bs08_rreq_valid             => axi_mid_array(8 ).arvalid,
    bs08_rreq_ready             => axi_mid_array(8 ).arready,
    bs08_rreq_addr              => axi_mid_array(8 ).araddr,
    bs08_rreq_len               => axi_mid_array(8 ).arlen,
    bs08_rdat_valid             => axi_mid_array(8 ).rvalid,
    bs08_rdat_ready             => axi_mid_array(8 ).rready,
    bs08_rdat_data              => axi_mid_array(8 ).rdata,
    bs08_rdat_last              => axi_mid_array(8 ).rlast,
    bs09_rreq_valid             => axi_mid_array(9 ).arvalid,
    bs09_rreq_ready             => axi_mid_array(9 ).arready,
    bs09_rreq_addr              => axi_mid_array(9 ).araddr,
    bs09_rreq_len               => axi_mid_array(9 ).arlen,
    bs09_rdat_valid             => axi_mid_array(9 ).rvalid,
    bs09_rdat_ready             => axi_mid_array(9 ).rready,
    bs09_rdat_data              => axi_mid_array(9 ).rdata,
    bs09_rdat_last              => axi_mid_array(9 ).rlast,
    bs10_rreq_valid             => axi_mid_array(10).arvalid,
    bs10_rreq_ready             => axi_mid_array(10).arready,
    bs10_rreq_addr              => axi_mid_array(10).araddr,
    bs10_rreq_len               => axi_mid_array(10).arlen,
    bs10_rdat_valid             => axi_mid_array(10).rvalid,
    bs10_rdat_ready             => axi_mid_array(10).rready,
    bs10_rdat_data              => axi_mid_array(10).rdata,
    bs10_rdat_last              => axi_mid_array(10).rlast,
    bs11_rreq_valid             => axi_mid_array(11).arvalid,
    bs11_rreq_ready             => axi_mid_array(11).arready,
    bs11_rreq_addr              => axi_mid_array(11).araddr,
    bs11_rreq_len               => axi_mid_array(11).arlen,
    bs11_rdat_valid             => axi_mid_array(11).rvalid,
    bs11_rdat_ready             => axi_mid_array(11).rready,
    bs11_rdat_data              => axi_mid_array(11).rdata,
    bs11_rdat_last              => axi_mid_array(11).rlast,
    bs12_rreq_valid             => axi_mid_array(12).arvalid,
    bs12_rreq_ready             => axi_mid_array(12).arready,
    bs12_rreq_addr              => axi_mid_array(12).araddr,
    bs12_rreq_len               => axi_mid_array(12).arlen,
    bs12_rdat_valid             => axi_mid_array(12).rvalid,
    bs12_rdat_ready             => axi_mid_array(12).rready,
    bs12_rdat_data              => axi_mid_array(12).rdata,
    bs12_rdat_last              => axi_mid_array(12).rlast,
    bs13_rreq_valid             => axi_mid_array(13).arvalid,
    bs13_rreq_ready             => axi_mid_array(13).arready,
    bs13_rreq_addr              => axi_mid_array(13).araddr,
    bs13_rreq_len               => axi_mid_array(13).arlen,
    bs13_rdat_valid             => axi_mid_array(13).rvalid,
    bs13_rdat_ready             => axi_mid_array(13).rready,
    bs13_rdat_data              => axi_mid_array(13).rdata,
    bs13_rdat_last              => axi_mid_array(13).rlast,
    bs14_rreq_valid             => axi_mid_array(14).arvalid,
    bs14_rreq_ready             => axi_mid_array(14).arready,
    bs14_rreq_addr              => axi_mid_array(14).araddr,
    bs14_rreq_len               => axi_mid_array(14).arlen,
    bs14_rdat_valid             => axi_mid_array(14).rvalid,
    bs14_rdat_ready             => axi_mid_array(14).rready,
    bs14_rdat_data              => axi_mid_array(14).rdata,
    bs14_rdat_last              => axi_mid_array(14).rlast,
    bs15_rreq_valid             => axi_mid_array(15).arvalid,
    bs15_rreq_ready             => axi_mid_array(15).arready,
    bs15_rreq_addr              => axi_mid_array(15).araddr,
    bs15_rreq_len               => axi_mid_array(15).arlen,
    bs15_rdat_valid             => axi_mid_array(15).rvalid,
    bs15_rdat_ready             => axi_mid_array(15).rready,
    bs15_rdat_data              => axi_mid_array(15).rdata,
    bs15_rdat_last              => axi_mid_array(15).rlast
  );

end architecture;
