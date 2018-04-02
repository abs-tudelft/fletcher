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
use work.Arrow.all;
use work.ColumnReaderConfig.all;
use work.ColumnReaderConfigParse.all;

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
    busReq_valid                : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    busReq_ready                : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    busReq_addr                 : out std_logic_vector(arcfg_busCount(CFG)*BUS_ADDR_WIDTH-1 downto 0);
    busReq_len                  : out std_logic_vector(arcfg_busCount(CFG)*BUS_LEN_WIDTH-1 downto 0);
    busResp_valid               : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    busResp_ready               : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    busResp_data                : in  std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH-1 downto 0);
    busResp_last                : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);

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
end ColumnWriterListPrim;

architecture Behavioral of ColumnWriterListPrim is

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

  signal a_in_valid             : std_logic;
  signal a_in_ready             : std_logic;
  signal a_in_last              : std_logic;
  signal a_in_length            : std_logic_vector(INDEX_WIDTH-1 downto 0);

  -- Metrics and signals for child.
  signal b_cmd_valid            : std_logic;
  signal b_cmd_ready            : std_logic;
  signal b_cmd_firstIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal b_cmd_ctrl             : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal b_cmd_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal b_unlock_valid         : std_logic;
  signal b_unlock_ready         : std_logic;
  signal b_unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal b_in_valid             : std_logic;
  signal b_in_ready             : std_logic;
  signal b_in_data              : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal b_in_count             : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal b_in_last              : std_logic;

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

  -- Instantiate index buffer writer.
  a_inst: BufferWriter
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_FIFO_DEPTH            => BUS_FIFO_DEPTH,
      BUS_FIFO_THRESHOLD_SHIFT  => BUS_FIFO_THRESHOLD_SHIFT,
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => INDEX_WIDTH,
      IS_INDEX_BUFFER           => true,
      ELEMENT_COUNT_MAX         => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => ELEMENT_COUNT_WIDTH,
      CMD_CTRL_WIDTH            => CMD_CTRL_WIDTH,
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
      cmdIn_baseAddr            => cmd_baseAddr,
      cmdIn_implicit            => cmd_implicit,
      cmdIn_tag                 => cmd_tag,
      
      unlock_valid              => a_unlock_valid,
      unlock_ready              => a_unlock_ready,
      unlock_tag                => a_unlock_tag,
      
      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_data                   => in_data,
      in_count                  => in_count,
      in_last                   => in_last,
      
      bus_req_valid             => bus_req_valid,
      bus_req_ready             => bus_req_ready,
      bus_req_addr              => bus_req_addr,
      bus_req_len               => bus_req_len,
      
      bus_wrd_valid             => bus_wrd_valid,
      bus_wrd_ready             => bus_wrd_ready,
      bus_wrd_data              => bus_wrd_data,
      bus_wrd_strobe            => bus_wrd_strobe,
      bus_wrd_last              => bus_wrd_last
    );

  -- Instantiate primitive element buffer reader.
  b_inst: BufferWriter
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_FIFO_DEPTH            => BUS_FIFO_DEPTH,
      BUS_FIFO_THRESHOLD_SHIFT  => BUS_FIFO_THRESHOLD_SHIFT,
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      IS_INDEX_BUFFER           => IS_INDEX_BUFFER,
      ELEMENT_COUNT_MAX         => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => ELEMENT_COUNT_WIDTH,
      CMD_CTRL_WIDTH            => CMD_CTRL_WIDTH,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      acc_clk                   => acc_clk,
      acc_reset                 => acc_reset,
      
      cmdIn_valid               => cmdIn_valid, 
      cmdIn_ready               => cmdIn_ready,   
      cmdIn_firstIdx            => cmdIn_firstIdx,
      cmdIn_lastIdx             => cmdIn_lastIdx, 
      cmdIn_baseAddr            => cmdIn_baseAddr,
      cmdIn_implicit            => cmdIn_implicit,
      cmdIn_tag                 => cmdIn_tag,
      
      unlock_valid              => unlock_valid,
      unlock_ready              => unlock_ready,
      unlock_tag                => unlock_tag,
      
      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_data                   => in_data,
      in_count                  => in_count,
      in_last                   => in_last,
      
      bus_req_valid             => bus_req_valid,
      bus_req_ready             => bus_req_ready,
      bus_req_addr              => bus_req_addr,
      bus_req_len               => bus_req_len,
      
      bus_wrd_valid             => bus_wrd_valid,
      bus_wrd_ready             => bus_wrd_ready,
      bus_wrd_data              => bus_wrd_data,
      bus_wrd_strobe            => bus_wrd_strobe,
      bus_wrd_last              => bus_wrd_last
    );

end Behavioral;
