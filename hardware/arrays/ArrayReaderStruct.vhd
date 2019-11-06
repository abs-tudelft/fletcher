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
use work.UtilInt_pkg.all;
use work.UtilMisc_pkg.all;

entity ArrayReaderStruct is
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
    bus_rreq_valid                : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_rreq_ready                : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_rreq_addr                 : out std_logic_vector(arcfg_busCount(CFG)*BUS_ADDR_WIDTH-1 downto 0);
    bus_rreq_len                  : out std_logic_vector(arcfg_busCount(CFG)*BUS_LEN_WIDTH-1 downto 0);
    bus_rdat_valid               : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_rdat_ready               : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
    bus_rdat_data                : in  std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH-1 downto 0);
    bus_rdat_last                : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);

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
end ArrayReaderStruct;

architecture Behavioral of ArrayReaderStruct is

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
  signal a_cmd_ctrl             : std_logic_vector(A_CTRL_WIDTH-1 downto 0);

  signal a_unlock_valid         : std_logic;
  signal a_unlock_ready         : std_logic;
  signal a_unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal a_out_valid            : std_logic_vector(A_USER_COUNT-1 downto 0);
  signal a_out_ready            : std_logic_vector(A_USER_COUNT-1 downto 0);
  signal a_out_last             : std_logic_vector(A_USER_COUNT-1 downto 0);
  signal a_out_dvalid           : std_logic_vector(A_USER_COUNT-1 downto 0);
  signal a_out_data             : std_logic_vector(A_USER_WIDTH-1 downto 0);

  -- Metrics and signals for child B.
  constant B_CFG                : string    := parse_arg(cfg, 1);
  constant B_CTRL_WIDTH         : natural   := arcfg_ctrlWidth(B_CFG, BUS_ADDR_WIDTH);
  constant B_BUS_COUNT          : natural   := arcfg_busCount(B_CFG);
  constant B_USER_WIDTHS        : nat_array := arcfg_userWidths(B_CFG, INDEX_WIDTH);
  constant B_USER_WIDTH         : natural   := sum(B_USER_WIDTHS);
  constant B_USER_COUNT         : natural   := B_USER_WIDTHS'length;
  constant BUI                  : nat_array := cumulative(B_USER_WIDTHS);

  signal b_cmd_valid            : std_logic;
  signal b_cmd_ready            : std_logic;
  signal b_cmd_ctrl             : std_logic_vector(B_CTRL_WIDTH-1 downto 0);

  signal b_unlock_valid         : std_logic;
  signal b_unlock_ready         : std_logic;
  signal b_unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal b_out_valid            : std_logic_vector(B_USER_COUNT-1 downto 0);
  signal b_out_ready            : std_logic_vector(B_USER_COUNT-1 downto 0);
  signal b_out_last             : std_logic_vector(B_USER_COUNT-1 downto 0);
  signal b_out_dvalid           : std_logic_vector(B_USER_COUNT-1 downto 0);
  signal b_out_data             : std_logic_vector(B_USER_WIDTH-1 downto 0);

  -- Metrics for A and B combined.
  constant BUS_COUNT            : natural   := A_BUS_COUNT + B_BUS_COUNT;
  constant OUI                  : nat_array := cumulative(arcfg_userWidths(CFG, INDEX_WIDTH));

  -- Command stream deserialization indices.
  constant CSI : nat_array := cumulative((
    1 => a_cmd_ctrl'length,
    0 => b_cmd_ctrl'length
  ));


begin

  -- Split the command stream.
  cmd_split_inst: StreamSync
    generic map (
      NUM_INPUTS                => 1,
      NUM_OUTPUTS               => 2
    )
    port map (
      clk                       => bcd_clk,
      reset                     => bcd_reset,

      in_valid(0)               => cmd_valid,
      in_ready(0)               => cmd_ready,

      out_valid(1)              => b_cmd_valid,
      out_valid(0)              => a_cmd_valid,
      out_ready(1)              => b_cmd_ready,
      out_ready(0)              => a_cmd_ready
    );

  a_cmd_ctrl <= cmd_ctrl(CSI(2)-1 downto CSI(1));
  b_cmd_ctrl <= cmd_ctrl(CSI(1)-1 downto CSI(0));

  -- Combine the unlock streams.
  unlock_inst: ArrayReaderUnlockCombine
    generic map (
      CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      clk                       => bcd_clk,
      reset                     => bcd_reset,

      a_unlock_valid            => a_unlock_valid,
      a_unlock_ready            => a_unlock_ready,
      a_unlock_tag              => a_unlock_tag,

      b_unlock_valid            => b_unlock_valid,
      b_unlock_ready            => b_unlock_ready,
      b_unlock_tag              => b_unlock_tag,

      unlock_valid              => unlock_valid,
      unlock_ready              => unlock_ready,
      unlock_tag                => unlock_tag
    );

  -- Combine master user stream handshake signals.
  master_user_stream_sync_inst: StreamSync
    generic map (
      NUM_INPUTS                => 2,
      NUM_OUTPUTS               => 1
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,

      in_valid(1)               => b_out_valid(0),
      in_valid(0)               => a_out_valid(0),
      in_ready(1)               => b_out_ready(0),
      in_ready(0)               => a_out_ready(0),

      out_valid(0)              => out_valid(0),
      out_ready(0)              => out_ready(0)
    );

  -- The control signals from the two master streams should be identical. In
  -- simulation, use the std_logic resolution function to generate Xs if they
  -- aren't.
  out_last(0)   <= a_out_last(0);
  out_dvalid(0) <= a_out_dvalid(0);
  -- pragma translate_off
  out_last(0)   <= b_out_last(0);
  out_dvalid(0) <= b_out_dvalid(0);
  -- pragma translate_on

  -- Propagate secondary user stream handshake and control signals from the
  -- children. We do this in a generate instead of using slice notation to
  -- prevent null range assignments in case the child only has 1 user stream.
  secondary_user_stream_sync_a_gen: for i in 1 to A_USER_COUNT-1 generate
  begin
    out_valid(i)   <= a_out_valid(i);
    a_out_ready(i) <= out_ready(i);
    out_last(i)    <= a_out_last(i);
    out_dvalid(i)  <= a_out_dvalid(i);
  end generate;
  secondary_user_stream_sync_b_gen: for i in 1 to B_USER_COUNT-1 generate
  begin
    out_valid(A_USER_COUNT+i-1)   <= b_out_valid(i);
    b_out_ready(i)                <= out_ready(A_USER_COUNT+i-1);
    out_last(A_USER_COUNT+i-1)    <= b_out_last(i);
    out_dvalid(A_USER_COUNT+i-1)  <= b_out_dvalid(i);
  end generate;

  -- Propagate the user stream data signals from the children.
  child_a_user_data_propagate_gen: for i in 0 to A_USER_COUNT-1 generate

    -- The master stream (i=0) needs to be put on the MSB side of the merged
    -- output master stream, so we need to add the width of child B's master
    -- stream to the index. Then we insert A's secondary streams in order.
    constant idx  : natural := sel(i=0, OUI(0) + B_USER_WIDTHS(0), OUI(i));

  begin
    out_data(idx+A_USER_WIDTHS(i)-1 downto idx)
      <= a_out_data(AUI(i+1)-1 downto AUI(i));
  end generate;
  child_b_user_data_propagate_gen: for i in 0 to B_USER_COUNT-1 generate

    -- The master stream (i=0) needs to be put on the LSB side of the merged
    -- output master stream, so it starts at 0. Then we insert B's secondary
    -- streams in order after A's secondary streams.
    constant idx  : natural := sel(i=0, OUI(0), OUI(A_USER_COUNT+i-1));

  begin
    out_data(idx+B_USER_WIDTHS(i)-1 downto idx)
      <= b_out_data(BUI(i+1)-1 downto BUI(i));
  end generate;

  -- Instantiate child A.
  a_inst: ArrayReaderLevel
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
      cmd_firstIdx              => cmd_firstIdx,
      cmd_lastIdx               => cmd_lastIdx,
      cmd_ctrl                  => a_cmd_ctrl,
      cmd_tag                   => cmd_tag,

      unlock_valid              => a_unlock_valid,
      unlock_ready              => a_unlock_ready,
      unlock_tag                => a_unlock_tag,

      bus_rreq_valid            => bus_rreq_valid(A_BUS_COUNT-1 downto 0),
      bus_rreq_ready            => bus_rreq_ready(A_BUS_COUNT-1 downto 0),
      bus_rreq_addr             => bus_rreq_addr(A_BUS_COUNT*BUS_ADDR_WIDTH-1 downto 0),
      bus_rreq_len              => bus_rreq_len(A_BUS_COUNT*BUS_LEN_WIDTH-1 downto 0),
      bus_rdat_valid            => bus_rdat_valid(A_BUS_COUNT-1 downto 0),
      bus_rdat_ready            => bus_rdat_ready(A_BUS_COUNT-1 downto 0),
      bus_rdat_data             => bus_rdat_data(A_BUS_COUNT*BUS_DATA_WIDTH-1 downto 0),
      bus_rdat_last             => bus_rdat_last(A_BUS_COUNT-1 downto 0),

      out_valid                 => a_out_valid,
      out_ready                 => a_out_ready,
      out_last                  => a_out_last,
      out_dvalid                => a_out_dvalid,
      out_data                  => a_out_data
    );

  -- Instantiate child B.
  b_inst: ArrayReaderLevel
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      CFG                       => B_CFG,
      CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      bcd_clk                   => bcd_clk,
      bcd_reset                 => bcd_reset,
      kcd_clk                   => kcd_clk,
      kcd_reset                 => kcd_reset,

      cmd_valid                 => b_cmd_valid,
      cmd_ready                 => b_cmd_ready,
      cmd_firstIdx              => cmd_firstIdx,
      cmd_lastIdx               => cmd_lastIdx,
      cmd_ctrl                  => b_cmd_ctrl,
      cmd_tag                   => cmd_tag,

      unlock_valid              => b_unlock_valid,
      unlock_ready              => b_unlock_ready,
      unlock_tag                => b_unlock_tag,

      bus_rreq_valid            => bus_rreq_valid(BUS_COUNT-1 downto A_BUS_COUNT),
      bus_rreq_ready            => bus_rreq_ready(BUS_COUNT-1 downto A_BUS_COUNT),
      bus_rreq_addr             => bus_rreq_addr(BUS_COUNT*BUS_ADDR_WIDTH-1 downto A_BUS_COUNT*BUS_ADDR_WIDTH),
      bus_rreq_len              => bus_rreq_len(BUS_COUNT*BUS_LEN_WIDTH-1 downto A_BUS_COUNT*BUS_LEN_WIDTH),
      bus_rdat_valid            => bus_rdat_valid(BUS_COUNT-1 downto A_BUS_COUNT),
      bus_rdat_ready            => bus_rdat_ready(BUS_COUNT-1 downto A_BUS_COUNT),
      bus_rdat_data             => bus_rdat_data(BUS_COUNT*BUS_DATA_WIDTH-1 downto A_BUS_COUNT*BUS_DATA_WIDTH),
      bus_rdat_last             => bus_rdat_last(BUS_COUNT-1 downto A_BUS_COUNT),

      out_valid                 => b_out_valid,
      out_ready                 => b_out_ready,
      out_last                  => b_out_last,
      out_dvalid                => b_out_dvalid,
      out_data                  => b_out_data
    );

end Behavioral;
