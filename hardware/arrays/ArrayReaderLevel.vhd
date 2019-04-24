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
use work.ArrayConfig.all;
use work.ArrayConfigParse.all;
use work.Arrays.all;
use work.Buffers.all;

entity ArrayReaderLevel is
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
    -- Configures this ArrayReaderLevel. Due to its complexity, the syntax of
    -- this string is documented centrally in ArrayReaderConfig.vhd.
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
end ArrayReaderLevel;

architecture Behavioral of ArrayReaderLevel is

  -- Determine what the command is for this level of hierarchy.
  constant CMD                  : string  := parse_command(CFG);

begin

  -----------------------------------------------------------------------------
  -- Primitive reader
  -----------------------------------------------------------------------------
  prim_gen: if CMD = "prim" generate
  begin

    -- Instantiate the data buffer reader.
    buffer_reader_inst: BufferReader
      generic map (
        BUS_ADDR_WIDTH          => BUS_ADDR_WIDTH,
        BUS_LEN_WIDTH           => BUS_LEN_WIDTH,
        BUS_DATA_WIDTH          => BUS_DATA_WIDTH,
        BUS_BURST_MAX_LEN       => BUS_BURST_MAX_LEN,
        BUS_BURST_STEP_LEN      => BUS_BURST_STEP_LEN,
        INDEX_WIDTH             => INDEX_WIDTH,
        ELEMENT_WIDTH           => strtoi(parse_arg(CFG, 0)),
        IS_OFFSETS_BUFFER       => false,
        ELEMENT_COUNT_MAX       => 1,
        ELEMENT_COUNT_WIDTH     => 1,
        CMD_CTRL_WIDTH          => 1,
        CMD_TAG_WIDTH           => CMD_TAG_WIDTH,
        CMD_IN_SLICE            => parse_param(CFG, "cmd_in_slice", false),
        BUS_REQ_SLICE           => parse_param(CFG, "bus_req_slice", true),
        BUS_FIFO_DEPTH          => parse_param(CFG, "bus_fifo_depth", 16),
        BUS_FIFO_RAM_CONFIG     => parse_param(CFG, "bus_fifo_ram_config", ""),
        CMD_OUT_SLICE           => false,
        UNLOCK_SLICE            => parse_param(CFG, "unlock_slice", true),
        SHR2GB_SLICE            => parse_param(CFG, "shr2gb_slice", false),
        GB2FIFO_SLICE           => parse_param(CFG, "gb2fifo_slice", false),
        ELEMENT_FIFO_SIZE       => parse_param(CFG, "fifo_size", 64),
        ELEMENT_FIFO_RAM_CONFIG => parse_param(CFG, "fifo_ram_config", ""),
        ELEMENT_FIFO_XCLK_STAGES=> parse_param(CFG, "fifo_xclk_stages", 0),
        FIFO2POST_SLICE         => parse_param(CFG, "fifo2post_slice", false),
        OUT_SLICE               => parse_param(CFG, "out_slice", true)
      )
      port map (
        bus_clk                 => bus_clk,
        bus_reset               => bus_reset,
        acc_clk                 => acc_clk,
        acc_reset               => acc_reset,

        cmdIn_valid             => cmd_valid,
        cmdIn_ready             => cmd_ready,
        cmdIn_firstIdx          => cmd_firstIdx,
        cmdIn_lastIdx           => cmd_lastIdx,
        cmdIn_baseAddr          => cmd_ctrl,
        cmdIn_tag               => cmd_tag,

        unlock_valid            => unlock_valid,
        unlock_ready            => unlock_ready,
        unlock_tag              => unlock_tag,

        bus_rreq_valid          => bus_rreq_valid(0),
        bus_rreq_ready          => bus_rreq_ready(0),
        bus_rreq_addr           => bus_rreq_addr,
        bus_rreq_len            => bus_rreq_len,
        bus_rdat_valid          => bus_rdat_valid(0),
        bus_rdat_ready          => bus_rdat_ready(0),
        bus_rdat_data           => bus_rdat_data,
        bus_rdat_last           => bus_rdat_last(0),

        out_valid               => out_valid(0),
        out_ready               => out_ready(0),
        out_data                => out_data,
        out_last                => out_last(0)
      );

    -- Null ranges in the command stream are illegal, so dvalid is always
    -- asserted.
    out_dvalid(0) <= '1';

  end generate;

  -----------------------------------------------------------------------------
  -- Bus arbiter
  -----------------------------------------------------------------------------
  arb_gen: if CMD = "arb" generate
  begin
    arb_inst: ArrayReaderArb
      generic map (
        BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
        BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
        BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
        BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
        BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
        INDEX_WIDTH               => INDEX_WIDTH,
        CFG                       => CFG,
        CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
        CMD_TAG_WIDTH             => CMD_TAG_WIDTH
      )
      port map (
        bus_clk                   => bus_clk,
        bus_reset                 => bus_reset,
        acc_clk                   => acc_clk,
        acc_reset                 => acc_reset,

        cmd_valid                 => cmd_valid,
        cmd_ready                 => cmd_ready,
        cmd_firstIdx              => cmd_firstIdx,
        cmd_lastIdx               => cmd_lastIdx,
        cmd_ctrl                  => cmd_ctrl,
        cmd_tag                   => cmd_tag,

        unlock_valid              => unlock_valid,
        unlock_ready              => unlock_ready,
        unlock_tag                => unlock_tag,

        bus_rreq_valid            => bus_rreq_valid,
        bus_rreq_ready            => bus_rreq_ready,
        bus_rreq_addr             => bus_rreq_addr,
        bus_rreq_len              => bus_rreq_len,
        bus_rdat_valid            => bus_rdat_valid,
        bus_rdat_ready            => bus_rdat_ready,
        bus_rdat_data             => bus_rdat_data,
        bus_rdat_last             => bus_rdat_last,

        out_valid                 => out_valid,
        out_ready                 => out_ready,
        out_last                  => out_last,
        out_dvalid                => out_dvalid,
        out_data                  => out_data
      );
  end generate;

  -----------------------------------------------------------------------------
  -- Null bitmap reader
  -----------------------------------------------------------------------------
  null_gen: if CMD = "null" generate
  begin
    null_inst: ArrayReaderNull
      generic map (
        BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
        BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
        BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
        BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
        BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
        INDEX_WIDTH               => INDEX_WIDTH,
        CFG                       => CFG,
        CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
        CMD_TAG_WIDTH             => CMD_TAG_WIDTH
      )
      port map (
        bus_clk                   => bus_clk,
        bus_reset                 => bus_reset,
        acc_clk                   => acc_clk,
        acc_reset                 => acc_reset,

        cmd_valid                 => cmd_valid,
        cmd_ready                 => cmd_ready,
        cmd_firstIdx              => cmd_firstIdx,
        cmd_lastIdx               => cmd_lastIdx,
        cmd_ctrl                  => cmd_ctrl,
        cmd_tag                   => cmd_tag,

        unlock_valid              => unlock_valid,
        unlock_ready              => unlock_ready,
        unlock_tag                => unlock_tag,

        bus_rreq_valid            => bus_rreq_valid,
        bus_rreq_ready            => bus_rreq_ready,
        bus_rreq_addr             => bus_rreq_addr,
        bus_rreq_len              => bus_rreq_len,
        bus_rdat_valid            => bus_rdat_valid,
        bus_rdat_ready            => bus_rdat_ready,
        bus_rdat_data             => bus_rdat_data,
        bus_rdat_last             => bus_rdat_last,

        out_valid                 => out_valid,
        out_ready                 => out_ready,
        out_last                  => out_last,
        out_dvalid                => out_dvalid,
        out_data                  => out_data
      );
  end generate;

  -----------------------------------------------------------------------------
  -- List reader
  -----------------------------------------------------------------------------
  list_gen: if CMD = "list" generate
  begin
    list_inst: ArrayReaderList
      generic map (
        BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
        BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
        BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
        BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
        BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
        INDEX_WIDTH               => INDEX_WIDTH,
        CFG                       => CFG,
        CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
        CMD_TAG_WIDTH             => CMD_TAG_WIDTH
      )
      port map (
        bus_clk                   => bus_clk,
        bus_reset                 => bus_reset,
        acc_clk                   => acc_clk,
        acc_reset                 => acc_reset,

        cmd_valid                 => cmd_valid,
        cmd_ready                 => cmd_ready,
        cmd_firstIdx              => cmd_firstIdx,
        cmd_lastIdx               => cmd_lastIdx,
        cmd_ctrl                  => cmd_ctrl,
        cmd_tag                   => cmd_tag,

        unlock_valid              => unlock_valid,
        unlock_ready              => unlock_ready,
        unlock_tag                => unlock_tag,

        bus_rreq_valid            => bus_rreq_valid,
        bus_rreq_ready            => bus_rreq_ready,
        bus_rreq_addr             => bus_rreq_addr,
        bus_rreq_len              => bus_rreq_len,
        bus_rdat_valid            => bus_rdat_valid,
        bus_rdat_ready            => bus_rdat_ready,
        bus_rdat_data             => bus_rdat_data,
        bus_rdat_last             => bus_rdat_last,

        out_valid                 => out_valid,
        out_ready                 => out_ready,
        out_last                  => out_last,
        out_dvalid                => out_dvalid,
        out_data                  => out_data
      );
  end generate;

  -----------------------------------------------------------------------------
  -- List of primitives reader
  -----------------------------------------------------------------------------
  listprim_gen: if CMD = "listprim" generate
  begin
    list_inst: ArrayReaderListPrim
      generic map (
        BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
        BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
        BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
        BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
        BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
        INDEX_WIDTH               => INDEX_WIDTH,
        CFG                       => CFG,
        CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
        CMD_TAG_WIDTH             => CMD_TAG_WIDTH
      )
      port map (
        bus_clk                   => bus_clk,
        bus_reset                 => bus_reset,
        acc_clk                   => acc_clk,
        acc_reset                 => acc_reset,

        cmd_valid                 => cmd_valid,
        cmd_ready                 => cmd_ready,
        cmd_firstIdx              => cmd_firstIdx,
        cmd_lastIdx               => cmd_lastIdx,
        cmd_ctrl                  => cmd_ctrl,
        cmd_tag                   => cmd_tag,

        unlock_valid              => unlock_valid,
        unlock_ready              => unlock_ready,
        unlock_tag                => unlock_tag,

        bus_rreq_valid            => bus_rreq_valid,
        bus_rreq_ready            => bus_rreq_ready,
        bus_rreq_addr             => bus_rreq_addr,
        bus_rreq_len              => bus_rreq_len,
        bus_rdat_valid            => bus_rdat_valid,
        bus_rdat_ready            => bus_rdat_ready,
        bus_rdat_data             => bus_rdat_data,
        bus_rdat_last             => bus_rdat_last,

        out_valid                 => out_valid,
        out_ready                 => out_ready,
        out_last                  => out_last,
        out_dvalid                => out_dvalid,
        out_data                  => out_data
      );
  end generate;

  -----------------------------------------------------------------------------
  -- Struct reader
  -----------------------------------------------------------------------------
  struct_gen: if CMD = "struct" generate
  begin
    struct_inst: ArrayReaderStruct
      generic map (
        BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
        BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
        BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
        BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
        BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
        INDEX_WIDTH               => INDEX_WIDTH,
        CFG                       => CFG,
        CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
        CMD_TAG_WIDTH             => CMD_TAG_WIDTH
      )
      port map (
        bus_clk                   => bus_clk,
        bus_reset                 => bus_reset,
        acc_clk                   => acc_clk,
        acc_reset                 => acc_reset,

        cmd_valid                 => cmd_valid,
        cmd_ready                 => cmd_ready,
        cmd_firstIdx              => cmd_firstIdx,
        cmd_lastIdx               => cmd_lastIdx,
        cmd_ctrl                  => cmd_ctrl,
        cmd_tag                   => cmd_tag,

        unlock_valid              => unlock_valid,
        unlock_ready              => unlock_ready,
        unlock_tag                => unlock_tag,

        bus_rreq_valid            => bus_rreq_valid,
        bus_rreq_ready            => bus_rreq_ready,
        bus_rreq_addr             => bus_rreq_addr,
        bus_rreq_len              => bus_rreq_len,
        bus_rdat_valid            => bus_rdat_valid,
        bus_rdat_ready            => bus_rdat_ready,
        bus_rdat_data             => bus_rdat_data,
        bus_rdat_last             => bus_rdat_last,

        out_valid                 => out_valid,
        out_ready                 => out_ready,
        out_last                  => out_last,
        out_dvalid                => out_dvalid,
        out_data                  => out_data
      );
  end generate;

end Behavioral;
