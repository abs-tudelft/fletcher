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

entity ColumnWriterListPrim is
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

    -- Bus strobe width.
    BUS_STROBE_WIDTH            : natural := 32/8;

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
    -- a range of elements to be written to memory. firstIdx is inclusive,
    -- lastIdx is exclusive for normal buffers and inclusive for index buffers,
    -- in all cases resulting from lastIdx - firstIdx elements. The ctrl vector
    -- is a concatenation of the base address for each buffer and the null
    -- bitmap present flags, depending on CFG.
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

    bus_wdat_valid              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_wdat_ready              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_wdat_data               : out std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH-1 downto 0);
    bus_wdat_strobe             : out std_logic_vector(arcfg_busCount(CFG)*BUS_STROBE_WIDTH-1 downto 0);
    bus_wdat_last               : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);

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
end ColumnWriterListPrim;

architecture Behavioral of ColumnWriterListPrim is

  -- Input user stream serialization indices.
  constant IUI                  : nat_array := cumulative(arcfg_userWidths(CFG, INDEX_WIDTH));

  -- Determine the metrics of the count and data-per-transfer vectors.
  constant ELEMENT_WIDTH        : natural := strtoi(parse_arg(cfg, 0));
  constant COUNT_MAX            : natural := parse_param(CFG, "epc", 1);
  constant COUNT_WIDTH          : natural := log2ceil(COUNT_MAX+1);
  constant DATA_WIDTH           : natural := ELEMENT_WIDTH * COUNT_MAX;
  
  -- Determine whether to generate the child stream last signal from the length
  -- stream last signal. If this is false, every list will generate a new 
  -- command on the child buffer.
  constant LAST_FROM_LENGTH     : boolean := parse_param(CFG, "last_from_length", true);
  
  -- Determine whether to generate the length stream based on the last signal
  -- of the element stream. In this mode, the length stream last signal is still 
  -- used to finalize both buffers. The length stream data is ignored but
  -- should still be handshaked for every list.
  constant GENERATE_LENGTH      : boolean := parse_param(CFG, "generate_lengths", false);
  
  -- Determine if the element stream should be normalized according to the
  -- length stream. Can only be used if length stream is not generated. Will
  -- split up multiple element-per-cycle element streams and their valid count
  -- properly based on length stream. If length stream is used and normalize is
  -- false, user must make sure boundaries are not crossed when last is
  -- asserted on multiple element-per-cycle element stream during a single 
  -- transfer.
  constant NORMALIZE            : boolean := parse_param(CFG, "normalize", false);

  -- Signals for index buffer writer.
  signal a_unlock_valid         : std_logic;
  signal a_unlock_ready         : std_logic;
  signal a_unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal a_unlock_ignoreChild   : std_logic := '1'; -- TODO: fix unlock streams

  signal a_valid                : std_logic;
  signal a_ready                : std_logic;
  signal a_last                 : std_logic;
  signal a_length               : std_logic_vector(INDEX_WIDTH-1 downto 0);

  -- Metrics and signals for values buffer writer.
  signal b_cmd_valid            : std_logic;
  signal b_cmd_ready            : std_logic;
  signal b_cmd_firstIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal b_cmd_lastIdx          : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal b_cmd_baseaddr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal b_cmd_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal b_unlock_valid         : std_logic;
  signal b_unlock_ready         : std_logic := '1'; -- TODO: fix unlock streams
  signal b_unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal b_valid                : std_logic;
  signal b_ready                : std_logic;
  signal b_data                 : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal b_count                : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal b_last                 : std_logic;
  signal b_dvalid               : std_logic;

  -- Command stream deserialization indices.
  constant CSI : nat_array := cumulative((
    1 => BUS_ADDR_WIDTH, -- base address for data buffer
    0 => BUS_ADDR_WIDTH  -- base address for index/offsets buffer
  ));

begin

  ---- Combine the unlock streams.
  --unlock_inst: ColumnReaderUnlockCombine
  --  generic map (
  --    CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
  --    CMD_TAG_WIDTH             => CMD_TAG_WIDTH
  --  )
  --  port map (
  --    clk                       => bus_clk,
  --    reset                     => bus_reset,
  --
  --    a_unlock_valid            => a_unlock_valid,
  --    a_unlock_ready            => a_unlock_ready,
  --    a_unlock_tag              => a_unlock_tag,
  --    a_unlock_ignoreChild      => a_unlock_ignoreChild,
  --
  --    b_unlock_valid            => b_unlock_valid,
  --    b_unlock_ready            => b_unlock_ready,
  --    b_unlock_tag              => b_unlock_tag,
  --
  --    unlock_valid              => unlock_valid,
  --    unlock_ready              => unlock_ready,
  --    unlock_tag                => unlock_tag
  --  );

  -- Instantiate the list synchronizer
  sync_inst: ColumnWriterListSync
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      LENGTH_WIDTH              => INDEX_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH,
      GENERATE_LENGTH           => GENERATE_LENGTH,
      NORMALIZE                 => NORMALIZE,
      ELEM_LAST_FROM_LENGTH     => LAST_FROM_LENGTH,
      DATA_IN_SLICE             => false,
      LEN_IN_SLICE              => false,
      OUT_SLICE                 => false
    )
    port map (
      clk                       => acc_clk,
      reset                     => acc_reset,
      inl_valid                 => in_valid(0),
      inl_ready                 => in_ready(0),
      inl_length                => in_data(IUI(1)-1 downto IUI(0)),
      inl_last                  => in_last(0),
      ine_valid                 => in_valid(1),
      ine_ready                 => in_ready(1),
      ine_last                  => in_last(1),
      ine_dvalid                => in_dvalid(1),
      ine_data                  => in_data(IUI(2)-COUNT_WIDTH-1 downto IUI(1)),
      ine_count                 => in_data(IUI(2)-1 downto IUI(2)-COUNT_WIDTH),
      outl_valid                => a_valid,
      outl_ready                => a_ready,
      outl_length               => a_length,
      outl_last                 => a_last,
      oute_valid                => b_valid,
      oute_ready                => b_ready,
      oute_last                 => b_last,
      oute_dvalid               => b_dvalid,
      oute_data                 => b_data,
      oute_count                => b_count
    );

  -- Instantiate index buffer writer.
  a_inst: BufferWriter
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_STROBE_WIDTH          => BUS_STROBE_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_FIFO_DEPTH            => parse_param(CFG, "idx_bus_fifo_depth", 16),
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => INDEX_WIDTH,
      IS_INDEX_BUFFER           => true,
      ELEMENT_COUNT_MAX         => 1,
      ELEMENT_COUNT_WIDTH       => 1,
      CMD_CTRL_WIDTH            => BUS_ADDR_WIDTH,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
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
      cmdIn_implicit            => '0',

      cmdOut_valid              => b_cmd_valid,
      cmdOut_ready              => b_cmd_ready,
      cmdOut_firstIdx           => b_cmd_firstIdx,
      cmdOut_lastIdx            => b_cmd_lastIdx,
      cmdOut_ctrl               => b_cmd_baseaddr,
      cmdOut_tag                => b_cmd_tag,
      -- TODO: fix unlock stream:
      unlock_valid              => a_unlock_valid,  --a_unlock_valid
      unlock_ready              => a_unlock_ready,  --a_unlock_ready
      unlock_tag                => a_unlock_tag,    --a_unlock_tag,
      
      in_valid                  => a_valid,
      in_ready                  => a_ready,
      in_data                   => a_length,
      in_count                  => "1",
      in_last                   => a_last,

      bus_wreq_valid            => bus_wreq_valid(0),
      bus_wreq_ready            => bus_wreq_ready(0),
      bus_wreq_addr             => bus_wreq_addr(BUS_ADDR_WIDTH-1 downto 0),
      bus_wreq_len              => bus_wreq_len(BUS_LEN_WIDTH-1 downto 0),

      bus_wdat_valid            => bus_wdat_valid(0),
      bus_wdat_ready            => bus_wdat_ready(0),
      bus_wdat_data             => bus_wdat_data(BUS_DATA_WIDTH-1 downto 0),
      bus_wdat_strobe           => bus_wdat_strobe(BUS_STROBE_WIDTH-1 downto 0),
      bus_wdat_last             => bus_wdat_last(0)
    );

  -- Instantiate primitive element buffer reader.
  b_inst: BufferWriter
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_STROBE_WIDTH          => BUS_STROBE_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_FIFO_DEPTH            => parse_param(CFG, "bus_fifo_depth", 16),
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      IS_INDEX_BUFFER           => false,
      ELEMENT_COUNT_MAX         => COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => COUNT_WIDTH,
      CMD_CTRL_WIDTH            => 1,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
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
      cmdIn_baseAddr            => b_cmd_baseAddr,
      cmdIn_ctrl                => "0",
      cmdIn_tag                 => b_cmd_tag,
      cmdIn_implicit            => '0',

      unlock_valid              => b_unlock_valid,
      unlock_ready              => b_unlock_ready,
      unlock_tag                => b_unlock_tag,

      in_valid                  => b_valid,
      in_ready                  => b_ready,
      in_data                   => b_data,
      in_count                  => b_count,
      in_last                   => b_last,

      bus_wreq_valid            => bus_wreq_valid(1),
      bus_wreq_ready            => bus_wreq_ready(1),
      bus_wreq_addr             => bus_wreq_addr(2*BUS_ADDR_WIDTH-1 downto BUS_ADDR_WIDTH),
      bus_wreq_len              => bus_wreq_len(2*BUS_LEN_WIDTH-1 downto BUS_LEN_WIDTH),

      bus_wdat_valid            => bus_wdat_valid(1),
      bus_wdat_ready            => bus_wdat_ready(1),
      bus_wdat_data             => bus_wdat_data(2*BUS_DATA_WIDTH-1 downto BUS_DATA_WIDTH),
      bus_wdat_strobe           => bus_wdat_strobe(2*BUS_STROBE_WIDTH-1 downto BUS_STROBE_WIDTH),
      bus_wdat_last             => bus_wdat_last(1)
    );

end Behavioral;
