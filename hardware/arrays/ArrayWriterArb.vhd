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

library work;
use work.Stream_pkg.all;
use work.ArrayConfig_pkg.all;
use work.ArrayConfigParse_pkg.all;
use work.Array_pkg.all;
use work.Interconnect_pkg.all;
use work.UtilInt_pkg.all;
use work.UtilMisc_pkg.all;

entity ArrayWriterArb is
  generic (

    ---------------------------------------------------------------------------
    -- Bus metrics and configuration
    ---------------------------------------------------------------------------
    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Number of beats in a burst step.
    BUS_BURST_STEP_LEN          : natural := 4;

    -- Maximum number of beats in a burst.
    BUS_BURST_MAX_LEN           : natural := 16;

    ---------------------------------------------------------------------------
    -- Arrow metrics and configuration
    ---------------------------------------------------------------------------
    -- Index field width.
    INDEX_WIDTH                 : natural := 32;

    ---------------------------------------------------------------------------
    -- Array metrics and configuration
    ---------------------------------------------------------------------------
    -- Configures this ArrayWriterLevel. Due to its complexity, the syntax of
    -- this string is documented centrally in ArrayReaderConfig.vhd.
    CFG                         : string;

    -- Enables or disables command stream tag system. When enabled, an
    -- additional output stream is created that returns tags supplied along
    -- with the command stream when all BufferWriters finish making bus
    -- requests for the command. This can be used to support chunking later.
    CMD_TAG_ENABLE              : boolean := false;

    -- Command stream tag width. Must be at least 1 to avoid null vectors.
    CMD_TAG_WIDTH               : natural := 1

  );
  port (

    ---------------------------------------------------------------------------
    -- Clock domains
    ---------------------------------------------------------------------------
    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    bcd_clk                     : in  std_logic;
    bcd_reset                   : in  std_logic;

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- accelerator side.
    kcd_clk                     : in  std_logic;
    kcd_reset                   : in  std_logic;

    ---------------------------------------------------------------------------
    -- Command streams
    ---------------------------------------------------------------------------
    -- Command stream input (bus clock domain). firstIdx and lastIdx represent
    -- a range of elements to be fetched from memory. firstIdx is inclusive,
    -- lastIdx is exclusive for normal buffers and inclusive for offsets buffers,
    -- in all cases resulting in lastIdx - firstIdx elements. The ctrl vector
    -- is a concatenation of the base address for each buffer and the null
    -- bitmap present flags, dependent on CFG.
    cmd_valid                   : in  std_logic;
    cmd_ready                   : out std_logic;
    cmd_firstIdx                : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmd_lastIdx                 : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmd_ctrl                    : in  std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
    cmd_tag                     : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

    -- Unlock stream (bus clock domain). Produces the chunk tags supplied by
    -- the command stream when all BufferReaders finish processing the command.
    unlock_valid                : out std_logic;
    unlock_ready                : in  std_logic := '1';
    unlock_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    ---------------------------------------------------------------------------
    -- Bus access ports
    ---------------------------------------------------------------------------
    -- Concatenation of all the bus masters at this level of hierarchy (bus
    -- clock domain).
    bus_wreq_valid              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_wreq_ready              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_wreq_addr               : out std_logic_vector(arcfg_busCount(CFG)*BUS_ADDR_WIDTH-1 downto 0);
    bus_wreq_len                : out std_logic_vector(arcfg_busCount(CFG)*BUS_LEN_WIDTH-1 downto 0);
    bus_wreq_last               : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_wdat_valid              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_wdat_ready              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_wdat_data               : out std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH-1 downto 0);
    bus_wdat_strobe             : out std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH/8-1 downto 0);
    bus_wdat_last               : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_wrep_valid              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_wrep_ready              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_wrep_ok                 : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);

    ---------------------------------------------------------------------------
    -- User streams
    ---------------------------------------------------------------------------
    -- Concatenation of all user output streams at this level of hierarchy
    -- (accelerator clock domain). The master stream starts at the side of the
    -- least significant bit.
    in_valid                    : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    in_ready                    : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    in_last                     : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    in_dvalid                   : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    in_data                     : in  std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)

  );
end ArrayWriterArb;

architecture Behavioral of ArrayWriterArb is

  -- Metrics and signals for child A.
  constant A_CFG                : string    := parse_arg(cfg, 0);
  constant A_CTRL_WIDTH         : natural   := arcfg_ctrlWidth(A_CFG, BUS_ADDR_WIDTH);
  constant A_BUS_COUNT          : natural   := arcfg_busCount(A_CFG);
  constant A_USER_WIDTHS        : nat_array := arcfg_userWidths(A_CFG, INDEX_WIDTH);
  constant A_USER_WIDTH         : natural   := sum(A_USER_WIDTHS);
  constant A_USER_COUNT         : natural   := A_USER_WIDTHS'length;
  constant AUI                  : nat_array := cumulative(A_USER_WIDTHS);

  signal a_cmd_valid            : std_logic;
  signal a_cmd_ready            : std_logic;
  signal a_cmd_firstIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal a_cmd_lastIdx          : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal a_cmd_ctrl             : std_logic_vector(A_CTRL_WIDTH-1 downto 0);
  signal a_cmd_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal a_unlock_valid         : std_logic;
  signal a_unlock_ready         : std_logic;
  signal a_unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal a_bus_wreq_valid       : std_logic_vector(A_BUS_COUNT-1 downto 0);
  signal a_bus_wreq_ready       : std_logic_vector(A_BUS_COUNT-1 downto 0);
  signal a_bus_wreq_addr        : std_logic_vector(A_BUS_COUNT*BUS_ADDR_WIDTH-1 downto 0);
  signal a_bus_wreq_len         : std_logic_vector(A_BUS_COUNT*BUS_LEN_WIDTH-1 downto 0);
  signal a_bus_wreq_last        : std_logic_vector(A_BUS_COUNT-1 downto 0);
  signal a_bus_wdat_valid       : std_logic_vector(A_BUS_COUNT-1 downto 0);
  signal a_bus_wdat_ready       : std_logic_vector(A_BUS_COUNT-1 downto 0);
  signal a_bus_wdat_data        : std_logic_vector(A_BUS_COUNT*BUS_DATA_WIDTH-1 downto 0);
  signal a_bus_wdat_strobe      : std_logic_vector(A_BUS_COUNT*BUS_DATA_WIDTH/8-1 downto 0);
  signal a_bus_wdat_last        : std_logic_vector(A_BUS_COUNT-1 downto 0);
  signal a_bus_wrep_valid       : std_logic_vector(A_BUS_COUNT-1 downto 0);
  signal a_bus_wrep_ready       : std_logic_vector(A_BUS_COUNT-1 downto 0);
  signal a_bus_wrep_ok          : std_logic_vector(A_BUS_COUNT-1 downto 0);

  signal a_in_valid             : std_logic_vector(A_USER_COUNT-1 downto 0);
  signal a_in_ready             : std_logic_vector(A_USER_COUNT-1 downto 0);
  signal a_in_last              : std_logic_vector(A_USER_COUNT-1 downto 0);
  signal a_in_dvalid            : std_logic_vector(A_USER_COUNT-1 downto 0);
  signal a_in_data              : std_logic_vector(A_USER_WIDTH-1 downto 0);

begin

  -- Optional command stream buffer.
  cmd_buf_block: block is

    -- Serialization indices for the command stream.
    constant CSI : nat_array := cumulative((
      3 => cmd_firstIdx'length,
      2 => cmd_lastIdx'length,
      1 => cmd_ctrl'length,
      0 => cmd_tag'length
    ));

    -- Serialized versions of the command streams.
    signal cmd_sData            : std_logic_vector(CSI(CSI'high)-1 downto 0);
    signal a_cmd_sData          : std_logic_vector(CSI(CSI'high)-1 downto 0);

  begin

    -- Serialize the command stream for the optional register slice.
    cmd_sData(CSI(4)-1 downto CSI(3)) <= cmd_firstIdx;
    cmd_sData(CSI(3)-1 downto CSI(2)) <= cmd_lastIdx;
    cmd_sData(CSI(2)-1 downto CSI(1)) <= cmd_ctrl;
    cmd_sData(CSI(1)-1 downto CSI(0)) <= cmd_tag;

    -- Generate an optional register slice in the command stream.
    buffer_inst: StreamBuffer
      generic map (
        MIN_DEPTH               => sel(parse_param(CFG, "cmd_stream_slice", true), 2, 0),
        DATA_WIDTH              => CSI(CSI'high)
      )
      port map (
        clk                     => bcd_clk,
        reset                   => bcd_reset,
  
        in_valid                => cmd_valid,
        in_ready                => cmd_ready,
        in_data                 => cmd_sData,

        out_valid               => a_cmd_valid,
        out_ready               => a_cmd_ready,
        out_data                => a_cmd_sData
      );

    -- Deserialize the command stream from the optional register slice.
    a_cmd_firstIdx  <= a_cmd_sData(CSI(4)-1 downto CSI(3));
    a_cmd_lastIdx   <= a_cmd_sData(CSI(3)-1 downto CSI(2));
    a_cmd_ctrl      <= a_cmd_sData(CSI(2)-1 downto CSI(1));
    a_cmd_tag       <= a_cmd_sData(CSI(1)-1 downto CSI(0));

  end block;

  -- Generate an optional register slice in the command stream.
  unlock_stream_gen: if CMD_TAG_ENABLE generate
  begin
    buffer_inst: StreamBuffer
      generic map (
        MIN_DEPTH                 => sel(parse_param(CFG, "unlock_stream_slice", true), 2, 0),
        DATA_WIDTH                => CMD_TAG_WIDTH
      )
      port map (
        clk                       => bcd_clk,
        reset                     => bcd_reset,
  
        in_valid                  => a_unlock_valid,
        in_ready                  => a_unlock_ready,
        in_data                   => a_unlock_tag,

        out_valid                 => unlock_valid,
        out_ready                 => unlock_ready,
        out_data                  => unlock_tag
      );
  end generate;
  no_unlock_stream_gen: if not CMD_TAG_ENABLE generate
  begin
    unlock_valid    <= '0';
    a_unlock_ready  <= '1';
    unlock_tag      <= (others => '0');
  end generate;

  -- Optional arbiter.
  arb_gen: if A_BUS_COUNT > 1 generate
  begin

    -- Instantiate the actual arbiter.
    arb_inst: BusWriteArbiterVec
      generic map (
        BUS_ADDR_WIDTH          => BUS_ADDR_WIDTH,
        BUS_LEN_WIDTH           => BUS_LEN_WIDTH,
        BUS_DATA_WIDTH          => BUS_DATA_WIDTH,
        NUM_SLAVE_PORTS         => A_BUS_COUNT,

        ARB_METHOD              => parse_param(CFG, "method", "ROUND-ROBIN"),
        MAX_OUTSTANDING         => parse_param(CFG, "max_outstanding", 2),
        RAM_CONFIG              => parse_param(CFG, "ram_config", ""),

        -- TODO: change config parameters:
        SLV_REQ_SLICES          => parse_param(CFG, "req_in_slices", false),
        MST_REQ_SLICE           => parse_param(CFG, "req_out_slice", true),
        MST_DAT_SLICE           => parse_param(CFG, "dat_in_slice", false),
        SLV_DAT_SLICES          => parse_param(CFG, "dat_out_slices", true)
      )
      port map (
        bcd_clk                 => bcd_clk,
        bcd_reset               => bcd_reset,
  
        -- Slave ports (input)
        bsv_wreq_valid          => a_bus_wreq_valid,
        bsv_wreq_ready          => a_bus_wreq_ready,
        bsv_wreq_addr           => a_bus_wreq_addr,
        bsv_wreq_len            => a_bus_wreq_len,
        bsv_wreq_last           => a_bus_wreq_last,
        bsv_wdat_valid          => a_bus_wdat_valid,
        bsv_wdat_ready          => a_bus_wdat_ready,
        bsv_wdat_data           => a_bus_wdat_data,
        bsv_wdat_strobe         => a_bus_wdat_strobe,
        bsv_wdat_last           => a_bus_wdat_last,
        bsv_wrep_valid          => a_bus_wrep_valid,
        bsv_wrep_ready          => a_bus_wrep_ready,
        bsv_wrep_ok             => a_bus_wrep_ok,

        -- Master port (output)
        mst_wreq_valid          => bus_wreq_valid(0),
        mst_wreq_ready          => bus_wreq_ready(0),
        mst_wreq_addr           => bus_wreq_addr,
        mst_wreq_len            => bus_wreq_len,
        mst_wreq_last           => bus_wreq_last(0),
        mst_wdat_valid          => bus_wdat_valid(0),
        mst_wdat_ready          => bus_wdat_ready(0),
        mst_wdat_data           => bus_wdat_data,
        mst_wdat_strobe         => bus_wdat_strobe,
        mst_wdat_last           => bus_wdat_last(0),
        mst_wrep_valid          => bus_wrep_valid(0),
        mst_wrep_ready          => bus_wrep_ready(0),
        mst_wrep_ok             => bus_wrep_ok(0)
      );
  end generate;
  no_arb_gen: if A_BUS_COUNT = 1 generate
  begin
    -- Only one bus, so no arbiter needed. Connect everything directly instead.
    -- TODO: should maybe still insert slices here upon request.
      bus_wreq_valid  <= a_bus_wreq_valid;
    a_bus_wreq_ready  <=   bus_wreq_ready;
      bus_wreq_addr   <= a_bus_wreq_addr;
      bus_wreq_len    <= a_bus_wreq_len;
      bus_wreq_last   <= a_bus_wreq_last;
      bus_wdat_valid  <= a_bus_wdat_valid;
    a_bus_wdat_ready  <=   bus_wdat_ready;
      bus_wdat_data   <= a_bus_wdat_data;
      bus_wdat_strobe <= a_bus_wdat_strobe;
      bus_wdat_last   <= a_bus_wdat_last;
    a_bus_wrep_valid  <=   bus_wrep_valid;
      bus_wrep_ready  <= a_bus_wrep_ready;
    a_bus_wrep_ok     <=   bus_wrep_ok;
  end generate;

  -- Optional user stream slices.
  user_slice_gen: for i in 0 to A_USER_COUNT-1 generate

    -- Serialized vector containing the last flag, dvalid flag, and data vector
    -- for this user stream.
    signal in_sData            : std_logic_vector(A_USER_WIDTHS(i) + 1 downto 0);
    signal a_in_sData          : std_logic_vector(A_USER_WIDTHS(i) + 1 downto 0);

  begin

    -- Deserialize the stream data and flags.
    in_sData(0)                             <= in_last(i);
    in_sData(1)                             <= in_dvalid(i);
    in_sData(A_USER_WIDTHS(i) + 1 downto 2) <= in_data(AUI(i+1)-1 downto AUI(i));

    -- Generate an optional register slice in the user stream.
    buffer_inst: StreamBuffer
      generic map (
        MIN_DEPTH               => sel(parse_param(CFG, "out_stream_slice", true), 2, 0),
        DATA_WIDTH              => A_USER_WIDTHS(i) + 2
      )
      port map (
        clk                     => kcd_clk,
        reset                   => kcd_reset,
  
        in_valid                => in_valid(i),
        in_ready                => in_ready(i),
        in_data                 => in_sData,

        out_valid               => a_in_valid(i),
        out_ready               => a_in_ready(i),
        out_data                => a_in_sData
      );

    -- Serialize the stream data and flags.
    a_in_last(i)                            <= a_in_sData(0);
    a_in_dvalid(i)                          <= a_in_sData(1);
    a_in_data(AUI(i+1)-1 downto AUI(i))     <= a_in_sData(A_USER_WIDTHS(i) + 1 downto 2);

  end generate;

  -- Instantiate child.
  a_inst: ArrayWriterLevel
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      CFG                       => A_CFG,
      CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      bcd_clk                   => bcd_clk,
      bcd_reset                 => bcd_reset,
      kcd_clk                   => kcd_clk,
      kcd_reset                 => kcd_reset,
  
      cmd_valid                 => a_cmd_valid,
      cmd_ready                 => a_cmd_ready,
      cmd_firstIdx              => a_cmd_firstIdx,
      cmd_lastIdx               => a_cmd_lastIdx,
      cmd_ctrl                  => a_cmd_ctrl,
      cmd_tag                   => a_cmd_tag,

      unlock_valid              => a_unlock_valid,
      unlock_ready              => a_unlock_ready,
      unlock_tag                => a_unlock_tag,

      bus_wreq_valid            => a_bus_wreq_valid,
      bus_wreq_ready            => a_bus_wreq_ready,
      bus_wreq_addr             => a_bus_wreq_addr,
      bus_wreq_len              => a_bus_wreq_len,
      bus_wreq_last             => a_bus_wreq_last,
      bus_wdat_valid            => a_bus_wdat_valid,
      bus_wdat_ready            => a_bus_wdat_ready,
      bus_wdat_data             => a_bus_wdat_data,
      bus_wdat_strobe           => a_bus_wdat_strobe,
      bus_wdat_last             => a_bus_wdat_last,
      bus_wrep_valid            => a_bus_wrep_valid,
      bus_wrep_ready            => a_bus_wrep_ready,
      bus_wrep_ok               => a_bus_wrep_ok,

      in_valid                  => a_in_valid,
      in_ready                  => a_in_ready,
      in_last                   => a_in_last,
      in_dvalid                 => a_in_dvalid,
      in_data                   => a_in_data
    );

end Behavioral;
