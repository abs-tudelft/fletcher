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
use work.Interconnect_pkg.all;
use work.UtilInt_pkg.all;

entity BufferReader is
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
    -- Buffer metrics and configuration
    ---------------------------------------------------------------------------
    -- Buffer element width in bits.
    ELEMENT_WIDTH               : natural := 8;

    -- Whether this is a normal buffer or an offsets buffer.
    IS_OFFSETS_BUFFER           : boolean := false;

    -- Maximum number of elements returned per cycle. When more than 1,
    -- elements are returned LSB-aligned and LSB-first, along with a count
    -- field that indicates how many elementss are valid. A best-effort
    -- approach is utilized; no guarantees are made about how many elements
    -- are actually returned per cycle. This feature is not supported for index
    -- buffers.
    ELEMENT_COUNT_MAX           : natural := 1;

    -- Width of the vector indicating the number of valid elements. Must be at
    -- least 1 to prevent null ranges.
    ELEMENT_COUNT_WIDTH         : natural := 1;

    -- Command stream control vector width. This vector is propagated to the
    -- outgoing command stream, but isn't used otherwise. It is intended for
    -- control flags and base addresses for BufferReaders reading buffers that
    -- are indexed by this offsets buffer.
    CMD_CTRL_WIDTH              : natural := 1;

    -- Command stream tag width. This tag is propagated to the outgoing command
    -- stream and to the unlock stream. It is intended for chunk reference
    -- counting.
    CMD_TAG_WIDTH               : natural := 1;

    ---------------------------------------------------------------------------
    -- Datapath timing configuration
    ---------------------------------------------------------------------------
    -- Whether a register slice should be inserted into the command stream
    -- input.
    CMD_IN_SLICE                : boolean := true;

    -- Whether a register slice should be inserted into the bus request output.
    BUS_REQ_SLICE               : boolean := true;

    -- Bus response and internal command stream FIFO depth. The maximum number
    -- of outstanding requests is approximately this number divided by the
    -- burst length. If set to 2, a register slice is inserted instead of a
    -- FIFO. If set to 0, the buffers are omitted.
    BUS_FIFO_DEPTH              : natural := 16;

    -- RAM configuration string for the bus FIFOs.
    BUS_FIFO_RAM_CONFIG         : string := "";

    -- Whether a register slice should be inserted into the command stream
    -- output.
    CMD_OUT_SLICE               : boolean := true;

    -- Whether a register slice should be inserted in the unlock stream output.
    UNLOCK_SLICE                : boolean := true;

    -- Whether a register slice should be inserted between the LSB-alignment
    -- right-shift unit and the bus to FIFO gearbox.
    SHR2GB_SLICE                : boolean := true;

    -- Whether a register slice should be inserted between the bus to FIFO
    -- gearbox and the FIFO input.
    GB2FIFO_SLICE               : boolean := true;

    -- Element FIFO size in number of elements.
    ELEMENT_FIFO_SIZE           : natural := 64;

    -- RAM configuration string for the element FIFO.
    ELEMENT_FIFO_RAM_CONFIG     : string := "";

    -- The amount of clock domain crossing synchronization registers required
    -- for the element FIFO. If this is zero, the bus and accelerator clocks
    -- are assumed to be synchronous and the gray-code codecs are omitted.
    ELEMENT_FIFO_XCLK_STAGES    : natural := 0;

    -- Whether a register slice should be inserted between the FIFO and the
    -- post-processing logic (differential encoder for offsets buffers and
    -- optional serialization).
    FIFO2POST_SLICE             : boolean := true;

    -- Whether a register slice should be inserted into the output stream.
    OUT_SLICE                   : boolean := true

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
    -- a range of elementss to be fetched from memory. firstIdx is inclusive,
    -- lastIdx is exclusive for normal buffers and inclusive for offsets 
    -- buffers, in all cases resulting in lastIdx - firstIdx elements. baseAddr 
    -- is the pointer to the first element in the buffer. implicit may be set 
    -- for null bitmap readers if null count is zero; if it is set, no bus 
    -- requests will be made, and the unit will behave as if it receives all-one
    -- bus responses. ctrl is passed to the outgoing command stream, and may
    -- therefore be used for the base address and control information for
    -- indexed buffers. tag is passed to the unlock stream for chunk reference
    -- counting purposes.
    cmdIn_valid                 : in  std_logic;
    cmdIn_ready                 : out std_logic;
    cmdIn_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_baseAddr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    cmdIn_implicit              : in  std_logic := '0';
    cmdIn_ctrl                  : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0) := (others => '0');
    cmdIn_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

    -- Command stream output (bus clock domain). This stream is only used for
    -- offsets buffers. For each command received at the input, an output 
    -- command is also generated, using indices translated by the indices in the
    -- buffer:
    --   cmdout_firstIdx = cmdin_baseAddr[cmdin_firstIdx]
    --   cmdout_lastIdx = cmdin_baseAddr[cmdin_lastIdx]
    cmdOut_valid                : out std_logic;
    cmdOut_ready                : in  std_logic := '1';
    cmdOut_firstIdx             : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdOut_lastIdx              : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdOut_ctrl                 : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0) := (others => '0');
    cmdOut_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

    -- Unlock stream output (bus clock domain). The tags received on the
    -- incoming command stream are returned by this stream in order when all
    -- bus requests assocated with the command have finished processing.
    unlock_valid                : out std_logic;
    unlock_ready                : in  std_logic := '1';
    unlock_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
    unlock_ignoreChild          : out std_logic;

    ---------------------------------------------------------------------------
    -- Bus interconnect
    ---------------------------------------------------------------------------
    -- Bus read request (bus clock domain). addr represents the start address
    -- for the transfer, len is the amount of requested words requested in the
    -- burst. The maximum for len is set by BUS_BURST_LEN. Bursts never cross
    -- BUS_BURST_LEN-sized alignment boundaries.
    bus_rreq_valid              : out std_logic;
    bus_rreq_ready              : in  std_logic;
    bus_rreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_rreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

    -- Bus read response (bus clock domain). last is an active high signal that
    -- indicates the last beat in the requested burst.
    bus_rdat_valid              : in  std_logic;
    bus_rdat_ready              : out std_logic;
    bus_rdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_rdat_last               : in  std_logic;

    ---------------------------------------------------------------------------
    -- Output to accelerator
    ---------------------------------------------------------------------------
    -- Buffer element stream output (acc clock domain). element contains the
    -- data element for normal buffers and the length for offsets buffers. last
    -- is asserted when this is the last element for the current command.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    out_last                    : out std_logic

    -- TODO in entity:
    --  - status/error flags

  );
end BufferReader;

architecture Behavioral of BufferReader is

  -- Determine internal command stream metrics.
  constant ICS_SHIFT_WIDTH      : natural := imax(1, log2ceil(BUS_DATA_WIDTH / ELEMENT_WIDTH));
  constant ICS_COUNT_WIDTH      : natural := imax(1, log2ceil(BUS_DATA_WIDTH / ELEMENT_WIDTH) + 1);

  -- Amount of elements per bus beat.
  constant BUS_EPB              : natural := imax(1, BUS_DATA_WIDTH / ELEMENT_WIDTH);

  -- Width of the element FIFO in number of elements.
  constant ELEMENT_FIFO_COUNT_MAX  : natural := imax(BUS_EPB, ELEMENT_COUNT_MAX);

  -- Width of the vector signifying how many elements are valid in a FIFO entry.
  constant ELEMENT_FIFO_COUNT_USED : natural := log2ceil(ELEMENT_FIFO_COUNT_MAX);
  constant ELEMENT_FIFO_COUNT_WIDTH: natural := imax(1, ELEMENT_FIFO_COUNT_USED);

  -- Depth of the FIFO. Need at least 2 entries or things will break.
  constant ELEMENT_FIFO_DEPTH   : natural := imax(2, ELEMENT_FIFO_SIZE / ELEMENT_FIFO_COUNT_MAX);

  -- Internal bus, between the request/response handling logic and the buffer
  -- that prevents backpressure on the response stream from reaching the slave.
  signal intBusReq_valid        : std_logic;
  signal intBusReq_ready        : std_logic;
  signal intBusReq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal intBusReq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal intBusResp_valid       : std_logic;
  signal intBusResp_ready       : std_logic;
  signal intBusResp_data        : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal intBusResp_last        : std_logic;

  -- Internal command stream.
  signal intCmd_valid           : std_logic;
  signal intCmd_ready           : std_logic;
  signal intCmd_firstIdx        : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal intCmd_lastIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal intCmd_implicit        : std_logic;
  signal intCmd_ctrl            : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
  signal intCmd_tag             : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  -- Input stream for the FIFO.
  signal fifoIn_valid           : std_logic;
  signal fifoIn_ready           : std_logic;
  signal fifoIn_data            : std_logic_vector(ELEMENT_FIFO_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal fifoIn_count           : std_logic_vector(ELEMENT_FIFO_COUNT_WIDTH-1 downto 0);
  signal fifoIn_last            : std_logic;

  -- Output stream for the FIFO.
  signal fifoOut_valid          : std_logic;
  signal fifoOut_ready          : std_logic;
  signal fifoOut_data           : std_logic_vector(ELEMENT_FIFO_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal fifoOut_count          : std_logic_vector(ELEMENT_FIFO_COUNT_WIDTH-1 downto 0);
  signal fifoOut_last           : std_logic;

  -- FIFO entry serialization indices.
  constant FEI : nat_array := cumulative((
    2 => fifoIn_data'length,
    1 => ELEMENT_FIFO_COUNT_USED, -- fifoIn_count
    0 => 1 -- fifoIn_last
  ));

  signal fei_sData              : std_logic_vector(FEI(FEI'high)-1 downto 0);
  signal feo_sData              : std_logic_vector(FEI(FEI'high)-1 downto 0);

begin

  -- Instantiate bus command generation logic.
  cmd_inst: BufferReaderCmd
    generic map (
      BUS_ADDR_WIDTH                    => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH                     => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH                    => BUS_DATA_WIDTH,
      BUS_BURST_MAX_LEN                 => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN                => BUS_BURST_STEP_LEN,
      INDEX_WIDTH                       => INDEX_WIDTH,
      ELEMENT_WIDTH                     => ELEMENT_WIDTH,
      IS_OFFSETS_BUFFER                 => IS_OFFSETS_BUFFER,
      CMD_CTRL_WIDTH                    => CMD_CTRL_WIDTH,
      CMD_TAG_WIDTH                     => CMD_TAG_WIDTH,
      CMD_IN_SLICE                      => CMD_IN_SLICE,
      BUS_REQ_SLICE                     => BUS_REQ_SLICE
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      cmdIn_valid                       => cmdIn_valid,
      cmdIn_ready                       => cmdIn_ready,
      cmdIn_firstIdx                    => cmdIn_firstIdx,
      cmdIn_lastIdx                     => cmdIn_lastIdx,
      cmdIn_baseAddr                    => cmdIn_baseAddr,
      cmdIn_implicit                    => cmdIn_implicit,
      cmdIn_ctrl                        => cmdIn_ctrl,
      cmdIn_tag                         => cmdIn_tag,

      busReq_valid                      => intBusReq_valid,
      busReq_ready                      => intBusReq_ready,
      busReq_addr                       => intBusReq_addr,
      busReq_len                        => intBusReq_len,

      intCmd_valid                      => intCmd_valid,
      intCmd_ready                      => intCmd_ready,
      intCmd_firstIdx                   => intCmd_firstIdx,
      intCmd_lastIdx                    => intCmd_lastIdx,
      intCmd_implicit                   => intCmd_implicit,
      intCmd_ctrl                       => intCmd_ctrl,
      intCmd_tag                        => intCmd_tag
    );

  -- Instantiate bus buffer. This unit prevents the BufferReader from making
  -- bus requests with a burst size longer than what is currently available in
  -- the response FIFO inside this unit.
  buffer_inst: BusReadBuffer
    generic map (
      BUS_ADDR_WIDTH                    => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH                     => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH                    => BUS_DATA_WIDTH,
      FIFO_DEPTH                        => imax(BUS_FIFO_DEPTH, BUS_BURST_MAX_LEN+1),
      RAM_CONFIG                        => BUS_FIFO_RAM_CONFIG,
      SLV_REQ_SLICE                     => false,
      MST_REQ_SLICE                     => BUS_REQ_SLICE,
      MST_DAT_SLICE                     => false,
      SLV_DAT_SLICE                     => false
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      slv_rreq_valid                    => intBusReq_valid,
      slv_rreq_ready                    => intBusReq_ready,
      slv_rreq_addr                     => intBusReq_addr,
      slv_rreq_len                      => intBusReq_len,
      slv_rdat_valid                    => intBusResp_valid,
      slv_rdat_ready                    => intBusResp_ready,
      slv_rdat_data                     => intBusResp_data,
      slv_rdat_last                     => intBusResp_last,

      mst_rreq_valid                    => bus_rreq_valid,
      mst_rreq_ready                    => bus_rreq_ready,
      mst_rreq_addr                     => bus_rreq_addr,
      mst_rreq_len                      => bus_rreq_len,
      mst_rdat_valid                    => bus_rdat_valid,
      mst_rdat_ready                    => bus_rdat_ready,
      mst_rdat_data                     => bus_rdat_data,
      mst_rdat_last                     => bus_rdat_last
    );

  -- Instantiate bus response handling logic and datapath.
  resp_inst: BufferReaderResp
    generic map (
      BUS_DATA_WIDTH                    => BUS_DATA_WIDTH,
      BUS_BURST_STEP_LEN                => BUS_BURST_STEP_LEN,
      INDEX_WIDTH                       => INDEX_WIDTH,
      ELEMENT_WIDTH                     => ELEMENT_WIDTH,
      IS_OFFSETS_BUFFER                 => IS_OFFSETS_BUFFER,
      ICS_SHIFT_WIDTH                   => ICS_SHIFT_WIDTH,
      ICS_COUNT_WIDTH                   => ICS_COUNT_WIDTH,
      ELEMENT_FIFO_COUNT_MAX            => ELEMENT_FIFO_COUNT_MAX,
      ELEMENT_FIFO_COUNT_WIDTH          => ELEMENT_FIFO_COUNT_WIDTH,
      CMD_CTRL_WIDTH                    => CMD_CTRL_WIDTH,
      CMD_TAG_WIDTH                     => CMD_TAG_WIDTH,
      CMD_OUT_SLICE                     => CMD_OUT_SLICE,
      SHR2GB_SLICE                      => SHR2GB_SLICE,
      GB2FIFO_SLICE                     => GB2FIFO_SLICE,
      UNLOCK_SLICE                      => UNLOCK_SLICE
    )
    port map (
      clk                               => bcd_clk,
      reset                             => bcd_reset,

      busResp_valid                     => intBusResp_valid,
      busResp_ready                     => intBusResp_ready,
      busResp_data                      => intBusResp_data,

      intCmd_valid                      => intCmd_valid,
      intCmd_ready                      => intCmd_ready,
      intCmd_firstIdx                   => intCmd_firstIdx,
      intCmd_lastIdx                    => intCmd_lastIdx,
      intCmd_implicit                   => intCmd_implicit,
      intCmd_ctrl                       => intCmd_ctrl,
      intCmd_tag                        => intCmd_tag,

      cmdOut_valid                      => cmdOut_valid,
      cmdOut_ready                      => cmdOut_ready,
      cmdOut_firstIdx                   => cmdOut_firstIdx,
      cmdOut_lastIdx                    => cmdOut_lastIdx,
      cmdOut_ctrl                       => cmdOut_ctrl,
      cmdOut_tag                        => cmdOut_tag,

      unlock_valid                      => unlock_valid,
      unlock_ready                      => unlock_ready,
      unlock_tag                        => unlock_tag,
      unlock_ignoreChild                => unlock_ignoreChild,

      fifoIn_valid                      => fifoIn_valid,
      fifoIn_ready                      => fifoIn_ready,
      fifoIn_data                       => fifoIn_data,
      fifoIn_count                      => fifoIn_count,
      fifoIn_last                       => fifoIn_last
    );

  -- Instantiate the element FIFO. We do this in a generate in order to not
  -- instantiate one bit for the valid count whenever we don't need a valid
  -- count bit. Without the generate, this would result in null ranges.
  fifo_with_count_gen: if ELEMENT_FIFO_COUNT_USED > 0 generate
  begin
    fifo_inst: StreamFIFO
      generic map (
        DEPTH_LOG2                      => log2ceil(ELEMENT_FIFO_DEPTH),
        DATA_WIDTH                      => FEI(FEI'high),
        XCLK_STAGES                     => ELEMENT_FIFO_XCLK_STAGES,
        RAM_CONFIG                      => ELEMENT_FIFO_RAM_CONFIG
      )
      port map (
        in_clk                          => bcd_clk,
        in_reset                        => bcd_reset,

        in_valid                        => fifoIn_valid,
        in_ready                        => fifoIn_ready,
        in_data                         => fei_sData,

        out_clk                         => kcd_clk,
        out_reset                       => kcd_reset,

        out_valid                       => fifoOut_valid,
        out_ready                       => fifoOut_ready,
        out_data                        => feo_sData
      );

    fei_sData(FEI(3)-1 downto FEI(2))   <= fifoIn_data;
    fei_sData(FEI(2)-1 downto FEI(1))   <= fifoIn_count;
    fei_sData(FEI(0))                   <= fifoIn_last;

    fifoOut_data                        <= feo_sData(FEI(3)-1 downto FEI(2));
    fifoOut_count                       <= feo_sData(FEI(2)-1 downto FEI(1));
    fifoOut_last                        <= feo_sData(FEI(0));

  end generate;
  fifo_without_count_gen: if ELEMENT_FIFO_COUNT_USED = 0 generate
  begin
    fifo_inst: StreamFIFO
      generic map (
        DEPTH_LOG2                      => log2ceil(ELEMENT_FIFO_DEPTH),
        DATA_WIDTH                      => FEI(FEI'high),
        XCLK_STAGES                     => ELEMENT_FIFO_XCLK_STAGES,
        RAM_CONFIG                      => ELEMENT_FIFO_RAM_CONFIG
      )
      port map (
        in_clk                          => bcd_clk,
        in_reset                        => bcd_reset,

        in_valid                        => fifoIn_valid,
        in_ready                        => fifoIn_ready,
        in_data                         => fei_sData,

        out_clk                         => kcd_clk,
        out_reset                       => kcd_reset,

        out_valid                       => fifoOut_valid,
        out_ready                       => fifoOut_ready,
        out_data                        => feo_sData
      );

    fei_sData(FEI(3)-1 downto FEI(2))   <= fifoIn_data;
    fei_sData(FEI(0))                   <= fifoIn_last;

    fifoOut_data                        <= feo_sData(FEI(3)-1 downto FEI(2));
    fifoOut_last                        <= feo_sData(FEI(0));

    -- Make sure the count field is assigned to the right constant when it it
    -- omitted in the FIFO.
    fifoOut_count <= std_logic_vector(to_unsigned(1,ELEMENT_FIFO_COUNT_WIDTH));

  end generate;

  -- Instantiate post-processing logic.
  post_inst: BufferReaderPost
    generic map (
      ELEMENT_WIDTH                     => ELEMENT_WIDTH,
      IS_OFFSETS_BUFFER                 => IS_OFFSETS_BUFFER,
      ELEMENT_FIFO_COUNT_MAX            => ELEMENT_FIFO_COUNT_MAX,
      ELEMENT_FIFO_COUNT_WIDTH          => ELEMENT_FIFO_COUNT_WIDTH,
      ELEMENT_COUNT_MAX                 => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH               => ELEMENT_COUNT_WIDTH,
      FIFO2POST_SLICE                   => FIFO2POST_SLICE,
      OUT_SLICE                         => OUT_SLICE
    )
    port map (
      clk                               => kcd_clk,
      reset                             => kcd_reset,

      fifoOut_valid                     => fifoOut_valid,
      fifoOut_ready                     => fifoOut_ready,
      fifoOut_data                      => fifoOut_data,
      fifoOut_count                     => fifoOut_count,
      fifoOut_last                      => fifoOut_last,

      out_valid                         => out_valid,
      out_ready                         => out_ready,
      out_data                          => out_data,
      out_count                         => out_count,
      out_last                          => out_last
    );

end Behavioral;

