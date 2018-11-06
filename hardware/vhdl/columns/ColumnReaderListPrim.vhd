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
use work.Streams.all;
use work.Utils.all;
use work.ColumnConfig.all;
use work.ColumnConfigParse.all;
use work.Columns.all;
use work.Buffers.all;

entity ColumnReaderListPrim is
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
    -- Column metrics and configuration
    ---------------------------------------------------------------------------
    -- Configures this ColumnReaderLevel. Due to its complexity, the syntax of
    -- this string is documented centrally in ColumnReaderConfig.vhd.
    CFG                         : string;

    -- Enables or disables command stream tag system. When enabled, an
    -- additional output stream is created that returns tags supplied along
    -- with the command stream when all BufferReaders finish making bus
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
    bus_clk                     : in  std_logic;
    bus_reset                   : in  std_logic;

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- accelerator side.
    acc_clk                     : in  std_logic;
    acc_reset                   : in  std_logic;

    ---------------------------------------------------------------------------
    -- Command streams
    ---------------------------------------------------------------------------
    -- Command stream input (bus clock domain). firstIdx and lastIdx represent
    -- a range of elements to be fetched from memory. firstIdx is inclusive,
    -- lastIdx is exclusive for normal buffers and inclusive for index buffers,
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
    bus_rreq_valid              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_rreq_ready              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_rreq_addr               : out std_logic_vector(arcfg_busCount(CFG)*BUS_ADDR_WIDTH-1 downto 0);
    bus_rreq_len                : out std_logic_vector(arcfg_busCount(CFG)*BUS_LEN_WIDTH-1 downto 0);
    bus_rdat_valid              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_rdat_ready              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_rdat_data               : in  std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH-1 downto 0);
    bus_rdat_last               : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);

    ---------------------------------------------------------------------------
    -- User streams
    ---------------------------------------------------------------------------
    -- Concatenation of all user output streams at this level of hierarchy
    -- (accelerator clock domain). The master stream starts at the side of the
    -- least significant bit.
    out_valid                   : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    out_ready                   : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    out_last                    : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    out_dvalid                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    out_data                    : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)

  );
end ColumnReaderListPrim;

architecture Behavioral of ColumnReaderListPrim is

  -- Output user stream serialization indices.
  constant OUI                  : nat_array := cumulative(arcfg_userWidths(CFG, INDEX_WIDTH));

  -- Determine the metrics of the count and data-per-transfer vectors.
  constant ELEMENT_WIDTH        : natural := strtoi(parse_arg(cfg, 0));
  constant COUNT_MAX            : natural := parse_param(CFG, "epc", 1);
  constant COUNT_WIDTH          : natural := log2ceil(COUNT_MAX+1);
  constant DATA_WIDTH           : natural := ELEMENT_WIDTH * COUNT_MAX;

  -- Signals for index buffer reader.
  signal a_unlock_valid         : std_logic;
  signal a_unlock_ready         : std_logic;
  signal a_unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal a_unlock_ignoreChild   : std_logic;

  signal a_out_valid            : std_logic;
  signal a_out_ready            : std_logic;
  signal a_out_last             : std_logic;
  signal a_out_length           : std_logic_vector(INDEX_WIDTH-1 downto 0);

  -- Metrics and signals for child.
  signal b_cmd_valid            : std_logic;
  signal b_cmd_ready            : std_logic;
  signal b_cmd_firstIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal b_cmd_lastIdx          : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal b_cmd_ctrl             : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal b_cmd_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal b_unlock_valid         : std_logic;
  signal b_unlock_ready         : std_logic;
  signal b_unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal b_out_valid            : std_logic;
  signal b_out_ready            : std_logic;
  signal b_out_data             : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal b_out_count            : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal b_out_last             : std_logic;

  -- Command stream deserialization indices.
  constant CSI : nat_array := cumulative((
    1 => BUS_ADDR_WIDTH, -- base address for data buffer
    0 => BUS_ADDR_WIDTH  -- base address for index/offsets buffer
  ));

  -- Length stream to the ListSync instance.
  signal len_valid              : std_logic;
  signal len_ready              : std_logic;

  -- Length stream to the user.
  signal ulen_valid             : std_logic;
  signal ulen_ready             : std_logic;

begin

  -- Combine the unlock streams.
  unlock_inst: ColumnReaderUnlockCombine
    generic map (
      CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      clk                       => bus_clk,
      reset                     => bus_reset,

      a_unlock_valid            => a_unlock_valid,
      a_unlock_ready            => a_unlock_ready,
      a_unlock_tag              => a_unlock_tag,
      a_unlock_ignoreChild      => a_unlock_ignoreChild,

      b_unlock_valid            => b_unlock_valid,
      b_unlock_ready            => b_unlock_ready,
      b_unlock_tag              => b_unlock_tag,

      unlock_valid              => unlock_valid,
      unlock_ready              => unlock_ready,
      unlock_tag                => unlock_tag
    );

  -- Split the length stream from the index buffer reader in two. One will be
  -- passed to the user, the other is passed to the ListSync instance.
  len_split_inst: StreamSync
    generic map (
      NUM_INPUTS                => 1,
      NUM_OUTPUTS               => 2
    )
    port map (
      clk                       => acc_clk,
      reset                     => acc_reset,

      in_valid(0)               => a_out_valid,
      in_ready(0)               => a_out_ready,

      out_valid(1)              => len_valid,
      out_valid(0)              => ulen_valid,
      out_ready(1)              => len_ready,
      out_ready(0)              => ulen_ready
    );

  -- Optionally buffer the length stream to make the master user stream.
  len_buffer_block: block is

    -- Serialization indices for the buffer.
    constant LSI : nat_array := cumulative((
      1 => 1, -- a_out_last
      0 => a_out_length'length
    ));

    signal ulen_serialized      : std_logic_vector(LSI(LSI'high)-1 downto 0);
    signal out_serialized       : std_logic_vector(LSI(LSI'high)-1 downto 0);

  begin

    -- Serialize the input.
    ulen_serialized(                LSI(1)) <= a_out_last;
    ulen_serialized(LSI(1)-1 downto LSI(0)) <= a_out_length;

    -- Instantiate the buffer.
    len_buffer_inst: StreamBuffer
      generic map (
        MIN_DEPTH               => sel(parse_param(CFG, "len_out_slice", true), 2, 0),
        DATA_WIDTH              => LSI(LSI'high)
      )
      port map (
        clk                     => acc_clk,
        reset                   => acc_reset,

        in_valid                => ulen_valid,
        in_ready                => ulen_ready,
        in_data                 => ulen_serialized,

        out_valid               => out_valid(0),
        out_ready               => out_ready(0),
        out_data                => out_serialized
      );

    -- Deserialize the output.
    out_last(0)                      <= out_serialized(                LSI(1));
    out_data(OUI(1)-1 downto OUI(0)) <= out_serialized(LSI(1)-1 downto LSI(0));

    -- The element count for the length stream is always 1.
    out_dvalid(0) <= '1';

  end block;

  -- Instantiate the list synchronizer. This combines the length stream with
  -- the list element stream (= the master user stream of child B) such that
  -- the last and dvalid flags are correct. The resulting stream is the second
  -- user stream we output.
  list_sync_inst: ColumnReaderListSync
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      LENGTH_WIDTH              => INDEX_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH,
      DATA_IN_SLICE             => parse_param(CFG, "data_in_slice", false),
      LEN_IN_SLICE              => parse_param(CFG, "len_sync_slice", true),
      OUT_SLICE                 => parse_param(CFG, "data_out_slice", true)
    )
    port map (
      clk                       => acc_clk,
      reset                     => acc_reset,

      inl_valid                 => len_valid,
      inl_ready                 => len_ready,
      inl_length                => a_out_length,

      ind_valid                 => b_out_valid,
      ind_ready                 => b_out_ready,
      ind_data                  => b_out_data,
      ind_count                 => b_out_count,

      out_valid                 => out_valid(1),
      out_ready                 => out_ready(1),
      out_last                  => out_last(1),
      out_dvalid                => out_dvalid(1),
      out_data                  => out_data(OUI(2)-COUNT_WIDTH-1 downto OUI(1)),
      out_count                 => out_data(OUI(2)-1 downto OUI(2)-COUNT_WIDTH)
    );

  -- Instantiate index buffer reader.
  a_inst: BufferReader
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => INDEX_WIDTH,
      IS_INDEX_BUFFER           => true,
      ELEMENT_COUNT_MAX         => 1,
      ELEMENT_COUNT_WIDTH       => 1,
      CMD_CTRL_WIDTH            => BUS_ADDR_WIDTH,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH,
      CMD_IN_SLICE              => parse_param(CFG, "idx_cmd_in_slice", true),
      BUS_REQ_SLICE             => parse_param(CFG, "idx_bus_req_slice", true),
      BUS_FIFO_DEPTH            => parse_param(CFG, "idx_bus_fifo_depth", 16),
      BUS_FIFO_RAM_CONFIG       => parse_param(CFG, "idx_bus_fifo_ram_config", ""),
      CMD_OUT_SLICE             => parse_param(CFG, "idx_cmd_out_slice", true),
      UNLOCK_SLICE              => parse_param(CFG, "idx_unlock_slice", true),
      SHR2GB_SLICE              => parse_param(CFG, "idx_shr2gb_slice", true),
      GB2FIFO_SLICE             => parse_param(CFG, "idx_gb2fifo_slice", true),
      ELEMENT_FIFO_SIZE         => parse_param(CFG, "idx_fifo_size", 64),
      ELEMENT_FIFO_RAM_CONFIG   => parse_param(CFG, "idx_fifo_ram_config", ""),
      ELEMENT_FIFO_XCLK_STAGES  => parse_param(CFG, "idx_fifo_xclk_stages", 0),
      FIFO2POST_SLICE           => parse_param(CFG, "idx_fifo2post_slice", true),
      OUT_SLICE                 => false
    )
    port map (
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      acc_clk                   => acc_clk,
      acc_reset                 => acc_reset,

      cmdIn_valid               => cmd_valid,
      cmdIn_ready               => cmd_ready,
      cmdIn_firstIdx            => cmd_firstIdx,
      cmdIn_lastIdx             => cmd_lastIdx,
      cmdIn_baseAddr            => cmd_ctrl(CSI(1)-1 downto CSI(0)),
      cmdIn_ctrl                => cmd_ctrl(CSI(2)-1 downto CSI(1)),
      cmdIn_tag                 => cmd_tag,

      cmdOut_valid              => b_cmd_valid,
      cmdOut_ready              => b_cmd_ready,
      cmdOut_firstIdx           => b_cmd_firstIdx,
      cmdOut_lastIdx            => b_cmd_lastIdx,
      cmdOut_ctrl               => b_cmd_ctrl,
      cmdOut_tag                => b_cmd_tag,

      unlock_valid              => a_unlock_valid,
      unlock_ready              => a_unlock_ready,
      unlock_tag                => a_unlock_tag,
      unlock_ignoreChild        => a_unlock_ignoreChild,

      bus_rreq_valid            => bus_rreq_valid(0),
      bus_rreq_ready            => bus_rreq_ready(0),
      bus_rreq_addr             => bus_rreq_addr(BUS_ADDR_WIDTH-1 downto 0),
      bus_rreq_len              => bus_rreq_len(BUS_LEN_WIDTH-1 downto 0),
      bus_rdat_valid            => bus_rdat_valid(0),
      bus_rdat_ready            => bus_rdat_ready(0),
      bus_rdat_data             => bus_rdat_data(BUS_DATA_WIDTH-1 downto 0),
      bus_rdat_last             => bus_rdat_last(0),

      out_valid                 => a_out_valid,
      out_ready                 => a_out_ready,
      out_data                  => a_out_length,
      out_last                  => a_out_last
    );

  -- Instantiate primitive element buffer reader.
  b_inst: BufferReader
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      IS_INDEX_BUFFER           => false,
      ELEMENT_COUNT_MAX         => COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => COUNT_WIDTH,
      CMD_CTRL_WIDTH            => 1,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH,
      CMD_IN_SLICE              => parse_param(CFG, "cmd_in_slice", true),
      BUS_REQ_SLICE             => parse_param(CFG, "bus_req_slice", true),
      BUS_FIFO_DEPTH            => parse_param(CFG, "bus_fifo_depth", 16),
      BUS_FIFO_RAM_CONFIG       => parse_param(CFG, "bus_fifo_ram_config", ""),
      CMD_OUT_SLICE             => false, -- not required for non-index buffer
      UNLOCK_SLICE              => parse_param(CFG, "unlock_slice", true),
      SHR2GB_SLICE              => parse_param(CFG, "shr2gb_slice", true),
      GB2FIFO_SLICE             => parse_param(CFG, "gb2fifo_slice", true),
      ELEMENT_FIFO_SIZE         => parse_param(CFG, "fifo_size", 64),
      ELEMENT_FIFO_RAM_CONFIG   => parse_param(CFG, "fifo_ram_config", ""),
      ELEMENT_FIFO_XCLK_STAGES  => parse_param(CFG, "fifo_xclk_stages", 0),
      FIFO2POST_SLICE           => parse_param(CFG, "fifo2post_slice", true),
      OUT_SLICE                 => parse_param(CFG, "out_slice", true)
    )
    port map (
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      acc_clk                   => acc_clk,
      acc_reset                 => acc_reset,

      cmdIn_valid               => b_cmd_valid,
      cmdIn_ready               => b_cmd_ready,
      cmdIn_firstIdx            => b_cmd_firstIdx,
      cmdIn_lastIdx             => b_cmd_lastIdx,
      cmdIn_baseAddr            => b_cmd_ctrl,
      cmdIn_tag                 => b_cmd_tag,

      unlock_valid              => b_unlock_valid,
      unlock_ready              => b_unlock_ready,
      unlock_tag                => b_unlock_tag,

      bus_rreq_valid            => bus_rreq_valid(1),
      bus_rreq_ready            => bus_rreq_ready(1),
      bus_rreq_addr             => bus_rreq_addr(2*BUS_ADDR_WIDTH-1 downto BUS_ADDR_WIDTH),
      bus_rreq_len              => bus_rreq_len(2*BUS_LEN_WIDTH-1 downto BUS_LEN_WIDTH),
      bus_rdat_valid            => bus_rdat_valid(1),
      bus_rdat_ready            => bus_rdat_ready(1),
      bus_rdat_data             => bus_rdat_data(2*BUS_DATA_WIDTH-1 downto BUS_DATA_WIDTH),
      bus_rdat_last             => bus_rdat_last(1),

      out_valid                 => b_out_valid,
      out_ready                 => b_out_ready,
      out_data                  => b_out_data,
      out_count                 => b_out_count,
      out_last                  => b_out_last
    );

end Behavioral;
