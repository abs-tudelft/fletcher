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
use work.Buffer_pkg.all;
use work.UtilInt_pkg.all;
use work.UtilMisc_pkg.all;

entity ArrayReaderList is
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
end ArrayReaderList;

architecture Behavioral of ArrayReaderList is

  -- Output user stream serialization indices.
  constant OUI                  : nat_array := cumulative(arcfg_userWidths(CFG, INDEX_WIDTH));

  -- Signals for offsets buffer reader.
  signal a_unlock_valid         : std_logic;
  signal a_unlock_ready         : std_logic;
  signal a_unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal a_unlock_ignoreChild   : std_logic;

  signal a_out_valid            : std_logic;
  signal a_out_ready            : std_logic;
  signal a_out_last             : std_logic;
  signal a_out_length           : std_logic_vector(INDEX_WIDTH-1 downto 0);

  -- Metrics and signals for child.
  constant B_CFG                : string    := parse_arg(cfg, 0);
  constant B_CTRL_WIDTH         : natural   := arcfg_ctrlWidth(B_CFG, BUS_ADDR_WIDTH);
  constant B_BUS_COUNT          : natural   := arcfg_busCount(B_CFG);
  constant B_USER_WIDTHS        : nat_array := arcfg_userWidths(B_CFG, INDEX_WIDTH);
  constant B_USER_WIDTH         : natural   := sum(B_USER_WIDTHS);
  constant B_USER_COUNT         : natural   := B_USER_WIDTHS'length;
  constant BUI                  : nat_array := cumulative(B_USER_WIDTHS);

  signal b_cmd_valid            : std_logic;
  signal b_cmd_ready            : std_logic;
  signal b_cmd_firstIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal b_cmd_lastIdx          : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal b_cmd_ctrl             : std_logic_vector(B_CTRL_WIDTH-1 downto 0);
  signal b_cmd_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal b_unlock_valid         : std_logic;
  signal b_unlock_ready         : std_logic;
  signal b_unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal b_out_valid            : std_logic_vector(B_USER_COUNT-1 downto 0);
  signal b_out_ready            : std_logic_vector(B_USER_COUNT-1 downto 0);
  signal b_out_last             : std_logic_vector(B_USER_COUNT-1 downto 0);
  signal b_out_dvalid           : std_logic_vector(B_USER_COUNT-1 downto 0);
  signal b_out_data             : std_logic_vector(B_USER_WIDTH-1 downto 0);

  -- Command stream deserialization indices.
  constant CSI : nat_array := cumulative((
	1 => b_cmd_ctrl'length, -- base address for offsets buffer
    0 => BUS_ADDR_WIDTH
  ));

  -- Length stream to the ListSync instance.
  signal len_valid              : std_logic;
  signal len_ready              : std_logic;

  -- Length stream to the user.
  signal ulen_valid             : std_logic;
  signal ulen_ready             : std_logic;

begin

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
      a_unlock_ignoreChild      => a_unlock_ignoreChild,

      b_unlock_valid            => b_unlock_valid,
      b_unlock_ready            => b_unlock_ready,
      b_unlock_tag              => b_unlock_tag,

      unlock_valid              => unlock_valid,
      unlock_ready              => unlock_ready,
      unlock_tag                => unlock_tag
    );

  -- Split the length stream from the offsets buffer reader in two. One will be
  -- passed to the user, the other is passed to the ListSync instance.
  len_split_inst: StreamSync
    generic map (
      NUM_INPUTS                => 1,
      NUM_OUTPUTS               => 2
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,

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
        clk                     => kcd_clk,
        reset                   => kcd_reset,

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
  list_sync_inst: ArrayReaderListSync
    generic map (
      ELEMENT_WIDTH             => B_USER_WIDTHS(0),
      LENGTH_WIDTH              => INDEX_WIDTH,
      COUNT_MAX                 => 1,
      COUNT_WIDTH               => 1,
      DATA_IN_SLICE             => parse_param(CFG, "data_in_slice", false),
      LEN_IN_SLICE              => parse_param(CFG, "len_sync_slice", true),
      OUT_SLICE                 => parse_param(CFG, "data_out_slice", true)
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,

      inl_valid                 => len_valid,
      inl_ready                 => len_ready,
      inl_length                => a_out_length,

      ind_valid                 => b_out_valid(0),
      ind_ready                 => b_out_ready(0),
      ind_data                  => b_out_data(BUI(1)-1 downto BUI(0)),

      out_valid                 => out_valid(1),
      out_ready                 => out_ready(1),
      out_last                  => out_last(1),
      out_dvalid                => out_dvalid(1),
      out_data                  => out_data(OUI(2)-1 downto OUI(1))
    );

  -- Forward secondary user streams from the child to our output. We do this in
  -- a generate instead of using slice notation to prevent null range
  -- assignments in case the child only has 1 user stream.
  tertiary_user_stream_propagate_gen: for i in 1 to B_USER_COUNT-1 generate
  begin
    out_valid(i+1)    <= b_out_valid(i);
    b_out_ready(i)    <= out_ready(i+1);
    out_last(i+1)     <= b_out_last(i);
    out_dvalid(i+1)   <= b_out_dvalid(i);
    out_data(OUI(i+2)-1 downto OUI(i+1))
                      <= b_out_data(BUI(i+1)-1 downto BUI(i));
  end generate;

  -- Instantiate offsets buffer reader.
  a_inst: BufferReader
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => INDEX_WIDTH,
      IS_OFFSETS_BUFFER         => true,
      ELEMENT_COUNT_MAX         => 1,
      ELEMENT_COUNT_WIDTH       => 1,
      CMD_CTRL_WIDTH            => B_CTRL_WIDTH,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH,
      CMD_IN_SLICE              => parse_param(CFG, "cmd_in_slice", false),
      BUS_REQ_SLICE             => parse_param(CFG, "bus_req_slice", true),
      BUS_FIFO_DEPTH            => parse_param(CFG, "bus_fifo_depth", 16),
      BUS_FIFO_RAM_CONFIG       => parse_param(CFG, "bus_fifo_ram_config", ""),
      CMD_OUT_SLICE             => parse_param(CFG, "cmd_out_slice", true),
      UNLOCK_SLICE              => parse_param(CFG, "unlock_slice", true),
      SHR2GB_SLICE              => parse_param(CFG, "shr2gb_slice", false),
      GB2FIFO_SLICE             => parse_param(CFG, "gb2fifo_slice", false),
      ELEMENT_FIFO_SIZE         => parse_param(CFG, "fifo_size", 64),
      ELEMENT_FIFO_RAM_CONFIG   => parse_param(CFG, "fifo_ram_config", ""),
      ELEMENT_FIFO_XCLK_STAGES  => parse_param(CFG, "fifo_xclk_stages", 0),
      FIFO2POST_SLICE           => parse_param(CFG, "fifo2post_slice", false),
      OUT_SLICE                 => false
    )
    port map (
      bcd_clk                   => bcd_clk,
      bcd_reset                 => bcd_reset,
      kcd_clk                   => kcd_clk,
      kcd_reset                 => kcd_reset,

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

  -- Instantiate child.
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
      cmd_firstIdx              => b_cmd_firstIdx,
      cmd_lastIdx               => b_cmd_lastIdx,
      cmd_ctrl                  => b_cmd_ctrl,
      cmd_tag                   => b_cmd_tag,

      unlock_valid              => b_unlock_valid,
      unlock_ready              => b_unlock_ready,
      unlock_tag                => b_unlock_tag,

      bus_rreq_valid            => bus_rreq_valid(B_BUS_COUNT downto 1),
      bus_rreq_ready            => bus_rreq_ready(B_BUS_COUNT downto 1),
      bus_rreq_addr             => bus_rreq_addr((B_BUS_COUNT+1)*BUS_ADDR_WIDTH-1 downto BUS_ADDR_WIDTH),
      bus_rreq_len              => bus_rreq_len((B_BUS_COUNT+1)*BUS_LEN_WIDTH-1 downto BUS_LEN_WIDTH),
      bus_rdat_valid            => bus_rdat_valid(B_BUS_COUNT downto 1),
      bus_rdat_ready            => bus_rdat_ready(B_BUS_COUNT downto 1),
      bus_rdat_data             => bus_rdat_data((B_BUS_COUNT+1)*BUS_DATA_WIDTH-1 downto BUS_DATA_WIDTH),
      bus_rdat_last             => bus_rdat_last(B_BUS_COUNT downto 1),

      out_valid                 => b_out_valid,
      out_ready                 => b_out_ready,
      out_last                  => b_out_last,
      out_dvalid                => b_out_dvalid,
      out_data                  => b_out_data
    );

end Behavioral;
