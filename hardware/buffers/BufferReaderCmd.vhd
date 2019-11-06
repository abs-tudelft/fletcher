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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.Stream_pkg.all;
use work.Buffer_pkg.all;
use work.UtilInt_pkg.all;
use work.UtilConv_pkg.all;
use work.UtilMisc_pkg.all;

entity BufferReaderCmd is
  generic (

    ---------------------------------------------------------------------------
    -- Bus metrics and configuration
    ---------------------------------------------------------------------------
    -- Bus address width.
    BUS_ADDR_WIDTH              : natural;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural;

    -- Number of beats in a burst step.
    BUS_BURST_STEP_LEN          : natural;
    
    -- Maximum number of beats in a burst.
    BUS_BURST_MAX_LEN           : natural;

    ---------------------------------------------------------------------------
    -- Arrow metrics and configuration
    ---------------------------------------------------------------------------
    -- Index field width.
    INDEX_WIDTH                 : natural;

    ---------------------------------------------------------------------------
    -- Buffer metrics and configuration
    ---------------------------------------------------------------------------
    -- Buffer element width in bits.
    ELEMENT_WIDTH               : natural;

    -- Whether this is a normal buffer or an offsets buffer.
    IS_OFFSETS_BUFFER           : boolean;

    -- Command stream control vector width. This vector is propagated to the
    -- outgoing command stream, but isn't used otherwise. It is intended for
    -- control flags and base addresses for BufferReaders reading buffers that
    -- are indexed by this offsets buffer.
    CMD_CTRL_WIDTH              : natural;

    -- Command stream tag width. This tag is propagated to the outgoing command
    -- stream and to the unlock stream. It is intended for chunk reference
    -- counting.
    CMD_TAG_WIDTH               : natural;

    ---------------------------------------------------------------------------
    -- Timing configuration
    ---------------------------------------------------------------------------
    -- Whether a register slice should be inserted into the command stream
    -- input.
    CMD_IN_SLICE                : boolean;

    -- Whether a register slice should be inserted into the bus request output.
    BUS_REQ_SLICE               : boolean

  );
  port (

    ---------------------------------------------------------------------------
    -- Clock domains
    ---------------------------------------------------------------------------
    -- Rising-edge sensitive clock and active-high synchronous reset.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    ---------------------------------------------------------------------------
    -- Command stream input
    ---------------------------------------------------------------------------
    -- Command stream input. firstIdx and lastIdx represent a range of elements
    -- to be fetched from memory. firstIdx is inclusive, lastIdx is exclusive
    -- for normal buffers and inclusive for offsets buffers, in all cases
    -- resulting in lastIdx - firstIdx elements. baseAddr is the pointer to the
    -- first element in the buffer.
    cmdIn_valid                 : in  std_logic;
    cmdIn_ready                 : out std_logic;
    cmdIn_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_baseAddr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    cmdIn_implicit              : in  std_logic;
    cmdIn_ctrl                  : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    cmdIn_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    ---------------------------------------------------------------------------
    -- Output streams
    ---------------------------------------------------------------------------
    -- Bus read request. addr represents the start address for the transfer,
    -- len is the amount of requested words requested in the burst. The maximum
    -- for len is set by BUS_BURST_LEN. Bursts never cross BUS_BURST_LEN-sized
    -- alignment boundaries.
    busReq_valid                : out std_logic;
    busReq_ready                : in  std_logic;
    busReq_addr                 : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    busReq_len                  : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

    -- Command stream to the bus response block.
    intCmd_valid                : out std_logic;
    intCmd_ready                : in  std_logic;
    intCmd_firstIdx             : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    intCmd_lastIdx              : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    intCmd_implicit             : out std_logic;
    intCmd_ctrl                 : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    intCmd_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0)

  );
end BufferReaderCmd;

architecture Behavioral of BufferReaderCmd is

  -- Amount of bus beats per element.
  constant BUS_BPE              : natural := imax(1, ELEMENT_WIDTH / BUS_DATA_WIDTH);

  -- Logarithm of the amount of bus beats per element. This is the amount by
  -- which the len field of the bus request should be left-shifted to account
  -- for the parallelization factor in the BufferReaderResp unit.
  constant BUS_BPE_LOG2         : natural := log2ceil(BUS_BPE);

  -- Amount of elements per bus beat.
  constant BUS_EPB              : natural := imax(1, BUS_DATA_WIDTH / ELEMENT_WIDTH);

  -- Command input stream serialization indices.
  constant CSI : nat_array := cumulative((
    5 => cmdIn_baseAddr'length,
    4 => cmdIn_firstIdx'length,
    3 => cmdIn_lastIdx'length,
    2 => 1, -- cmdIn_implicit
    1 => cmdIn_ctrl'length,
    0 => cmdIn_tag'length
  ));

  -- Serialized data for the incoming command stream.
  signal cmdIn_sData            : std_logic_vector(CSI(CSI'high)-1 downto 0);

  -- Command input stream after the optional register slice.
  signal cmdInB_valid           : std_logic;
  signal cmdInB_ready           : std_logic;
  signal cmdInB_firstIdx        : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmdInB_lastIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmdInB_baseAddr        : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal cmdInB_implicit        : std_logic;
  signal cmdInB_ctrl            : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
  signal cmdInB_tag             : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal cmdInB_sData           : std_logic_vector(CSI(CSI'high)-1 downto 0);

  -- Handshake signals for the bus request generator.
  signal cmdInB_BRG_valid       : std_logic;
  signal cmdInB_BRG_ready       : std_logic;

  -- Handshake signals for the control signal generator.
  signal cmdInB_CSG_valid       : std_logic;
  signal cmdInB_CSG_ready       : std_logic;

  -- Serialized data for the outgoing command stream.
  signal intCmd_sData           : std_logic_vector(CSI(5)-1 downto 0);

  -- Bus request stream before the optional register slice.
  signal busReqB_valid          : std_logic;
  signal busReqB_ready          : std_logic;
  signal busReqB_addr           : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal busReqB_len            : std_logic_vector(BUS_LEN_WIDTH-BUS_BPE_LOG2-1 downto 0);

  -- Bus request stream serialization indices.
  constant BRI : nat_array := cumulative((
    1 => busReqB_addr'length,
    0 => busReqB_len'length
  ));
  signal busReqB_sData          : std_logic_vector(BRI(BRI'high)-1 downto 0);

  -- Serialized data for the bus request stream.
  signal busReq_sData           : std_logic_vector(BRI(BRI'high)-1 downto 0);

begin

  -- Serialize the incoming command stream for the StreamBuffer.
  cmdIn_sData(CSI(6)-1 downto CSI(5))   <= cmdIn_baseAddr;
  cmdIn_sData(CSI(5)-1 downto CSI(4))   <= cmdIn_firstIdx;
  cmdIn_sData(CSI(4)-1 downto CSI(3))   <= cmdIn_lastIdx;
  cmdIn_sData(                CSI(2))   <= cmdIn_implicit;
  cmdIn_sData(CSI(2)-1 downto CSI(1))   <= cmdIn_ctrl;
  cmdIn_sData(CSI(1)-1 downto CSI(0))   <= cmdIn_tag;

  -- Generate an optional register slice in the command stream.
  cmd_in_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(CMD_IN_SLICE, 2, 0),
      DATA_WIDTH                        => CSI(CSI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => cmdIn_valid,
      in_ready                          => cmdIn_ready,
      in_data                           => cmdIn_sData,

      out_valid                         => cmdInB_valid,
      out_ready                         => cmdInB_ready,
      out_data                          => cmdInB_sData
    );

  cmdInB_baseAddr                       <= cmdInB_sData(CSI(6)-1 downto CSI(5));
  cmdInB_firstIdx                       <= cmdInB_sData(CSI(5)-1 downto CSI(4));
  cmdInB_lastIdx                        <= cmdInB_sData(CSI(4)-1 downto CSI(3));
  cmdInB_implicit                       <= cmdInB_sData(                CSI(2));
  cmdInB_ctrl                           <= cmdInB_sData(CSI(2)-1 downto CSI(1));
  cmdInB_tag                            <= cmdInB_sData(CSI(1)-1 downto CSI(0));

  -- Split the command stream to the bus command generator and the control
  -- signal generator.
  cmd_stream_split_inst: StreamSync
    generic map (
      NUM_INPUTS                        => 1,
      NUM_OUTPUTS                       => 2
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid(0)                       => cmdInB_valid,
      in_ready(0)                       => cmdInB_ready,

      out_valid(1)                      => cmdInB_BRG_valid,
      out_valid(0)                      => cmdInB_CSG_valid,
      out_ready(1)                      => cmdInB_BRG_ready,
      out_ready(0)                      => cmdInB_CSG_ready
    );

  -- Instantiate bus command generator.
  bus_request_gen_inst: BufferReaderCmdGenBusReq
    generic map (
      BUS_ADDR_WIDTH                    => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH                     => BUS_LEN_WIDTH - BUS_BPE_LOG2,
      BUS_DATA_WIDTH                    => BUS_DATA_WIDTH * BUS_BPE,
      BUS_BURST_STEP_LEN                => BUS_BURST_STEP_LEN / BUS_BPE,
      BUS_BURST_MAX_LEN                 => BUS_BURST_MAX_LEN / BUS_BPE,
      INDEX_WIDTH                       => INDEX_WIDTH,
      ELEMENT_WIDTH                     => ELEMENT_WIDTH,
      IS_OFFSETS_BUFFER                 => IS_OFFSETS_BUFFER,
      CHECK_INDEX                       => true
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      cmdIn_valid                       => cmdInB_BRG_valid,
      cmdIn_ready                       => cmdInB_BRG_ready,
      cmdIn_firstIdx                    => cmdInB_firstIdx,
      cmdIn_lastIdx                     => cmdInB_lastIdx,
      cmdIn_baseAddr                    => cmdInB_baseAddr,
      cmdIn_implicit                    => cmdInB_implicit,

      busReq_valid                      => busReqB_valid,
      busReq_ready                      => busReqB_ready,
      busReq_addr                       => busReqB_addr,
      busReq_len                        => busReqB_len
    );

  -- Generate a register slice in the command stream as a buffer between the
  -- bus request and bus response domain. This allows outstanding requests to
  -- cross command boundaries.
  cmd_stream_slice: StreamSlice
    generic map (
      DATA_WIDTH                        => CSI(5)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => cmdInB_CSG_valid,
      in_ready                          => cmdInB_CSG_ready,
      in_data                           => cmdInB_sData(CSI(5)-1 downto CSI(0)),

      out_valid                         => intCmd_valid,
      out_ready                         => intCmd_ready,
      out_data                          => intCmd_sData
    );

  intCmd_firstIdx                       <= intCmd_sData(CSI(5)-1 downto CSI(4));
  intCmd_lastIdx                        <= intCmd_sData(CSI(4)-1 downto CSI(3));
  intCmd_implicit                       <= intCmd_sData(                CSI(2));
  intCmd_ctrl                           <= intCmd_sData(CSI(2)-1 downto CSI(1));
  intCmd_tag                            <= intCmd_sData(CSI(1)-1 downto CSI(0));

  -- Generate an optional register slice in the bus request stream.
  busReqB_sData(BRI(2)-1 downto BRI(1)) <= busReqB_addr;
  busReqB_sData(BRI(1)-1 downto BRI(0)) <= busReqB_len;

  bus_req_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(BUS_REQ_SLICE, 2, 0),
      DATA_WIDTH                        => BRI(BRI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => busReqB_valid,
      in_ready                          => busReqB_ready,
      in_data                           => busReqB_sData,

      out_valid                         => busReq_valid,
      out_ready                         => busReq_ready,
      out_data                          => busReq_sData
    );

  busReq_addr                                     <= busReq_sData(BRI(2)-1 downto BRI(1));
  busReq_len(BUS_LEN_WIDTH-1 downto BUS_BPE_LOG2) <= busReq_sData(BRI(1)-1 downto BRI(0));

  -- Assign zeros to the LSBs of the length field. This is in a generate to
  -- avoid null assignments.
  bus_len_lsb_driver_gen: if BUS_BPE_LOG2 > 0 generate
  begin
    busReq_len(BUS_BPE_LOG2-1 downto 0) <= (others => '0');
  end generate;

end Behavioral;

