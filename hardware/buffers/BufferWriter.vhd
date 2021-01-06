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

entity BufferWriter is
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
    -- Datapath timing configuration
    ---------------------------------------------------------------------------
    -- Bus write buffer FIFO depth. The maximum number of outstanding requests
    -- is approximately this number divided by the burst length. If set to 2,
    -- a register slice is inserted instead of a FIFO. If set to 0, the buffers
    -- are omitted.
    BUS_FIFO_DEPTH              : natural := 16;

    -- Be safe, don't touch this.
    BUS_FIFO_THRES_SHIFT        : natural := 0;

    ---------------------------------------------------------------------------
    -- Buffer metrics and configuration
    ---------------------------------------------------------------------------
    -- Buffer element width in bits.
    ELEMENT_WIDTH               : natural := 8;

    -- Whether this is a normal buffer or an offsets buffer. If this is an
    -- offsets buffer, the input elements are lengths that will be accumulated.
    -- The accumulated value provides the index to the list element in the
    -- corresponding values buffer. If the first index is zero the offsets
    -- buffer will insert the initial zero itself.
    IS_OFFSETS_BUFFER           : boolean := false;

    -- Maximum number of elements returned per cycle. When more than 1,
    -- elements are returned LSB-aligned and LSB-first, along with a count
    -- field that indicates how many elementss are valid. A best-effort
    -- approach is utilized; no guarantees are made about how many elements
    -- are actually returned per cycle. This feature is not supported for
    -- offsets buffers.
    ELEMENT_COUNT_MAX           : natural := 1;

    -- Width of the vector indicating the number of valid elements. Must be at
    -- least 1 to prevent null ranges.
    ELEMENT_COUNT_WIDTH         : natural := 1;

    -- Command stream control vector width. This vector is propagated to the
    -- outgoing command stream, but isn't used otherwise. It is intended for
    -- control flags and base addresses for BufferWriters reading buffers that
    -- are indexed by this offsets buffer.
    CMD_CTRL_WIDTH              : natural := 1;

    -- Command stream tag width. This tag is propagated to the outgoing command
    -- stream and to the unlock stream. It is intended for chunk reference
    -- counting.
    CMD_TAG_WIDTH               : natural := 1

  );
  port (

    ---------------------------------------------------------------------------
    -- Clock domains
    ---------------------------------------------------------------------------
    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferWriter.
    bcd_clk                     : in  std_logic;
    bcd_reset                   : in  std_logic;

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- accelerator side.
    kcd_clk                     : in  std_logic;
    kcd_reset                   : in  std_logic;

    ---------------------------------------------------------------------------
    -- Command streams
    ---------------------------------------------------------------------------
    -- If lastIdx is not zero, it is implied that the size of the buffer is
    -- known.
    cmdIn_valid                 : in  std_logic;
    cmdIn_ready                 : out std_logic;
    cmdIn_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_baseAddr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    cmdIn_implicit              : in  std_logic;
    cmdIn_ctrl                  : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    cmdIn_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    -- Unlock stream output (accelerator clock domain). The tags received on
    -- the incoming command stream are returned by this stream in order when
    -- all bus requests assocated with the command have finished processing.
    unlock_valid                : out std_logic;
    unlock_ready                : in  std_logic := '1';
    unlock_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    ---------------------------------------------------------------------------
    -- Input from accelerator
    ---------------------------------------------------------------------------
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    in_last                     : in  std_logic;

    ---------------------------------------------------------------------------
    -- Command stream output generated by offsets buffers.
    ---------------------------------------------------------------------------
    cmdOut_valid                : out std_logic;
    cmdOut_ready                : in  std_logic := '1';
    cmdOut_firstIdx             : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdOut_lastIdx              : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdOut_ctrl                 : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0) := (others => '0');
    cmdOut_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

    ---------------------------------------------------------------------------
    -- Bus write channels
    ---------------------------------------------------------------------------
    -- Request channel
    bus_wreq_valid              : out std_logic;
    bus_wreq_ready              : in  std_logic;
    bus_wreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_wreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    bus_wreq_last               : out std_logic;

    -- Data channel
    bus_wdat_valid              : out std_logic;
    bus_wdat_ready              : in  std_logic;
    bus_wdat_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_wdat_strobe             : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
    bus_wdat_last               : out std_logic;

    -- Response channel
    bus_wrep_valid              : in  std_logic;
    bus_wrep_ready              : out std_logic;
    bus_wrep_ok                 : in  std_logic

  );
end BufferWriter;

architecture Behavioral of BufferWriter is
  signal pre_valid              : std_logic;
  signal pre_ready              : std_logic;
  signal pre_data               : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal pre_strobe             : std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
  signal pre_last               : std_logic;

  signal writebuf_valid         : std_logic;
  signal writebuf_ready         : std_logic;
  signal writebuf_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal writebuf_strobe        : std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);

  signal req_valid              : std_logic;
  signal req_ready              : std_logic;
  signal req_addr               : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal req_len                : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal req_last               : std_logic;
  signal req_valid_A            : std_logic;
  signal req_ready_A            : std_logic;
  signal req_valid_B            : std_logic;
  signal req_ready_B            : std_logic;

  signal req_done_valid         : std_logic;
  signal req_done_ready         : std_logic;
  signal req_done_last          : std_logic;

  signal rep_valid              : std_logic;
  signal rep_ready              : std_logic;
  signal rep_ok                 : std_logic;

  signal cmdIn_ready_pre        : std_logic;
  signal cmdIn_ready_bus        : std_logic;
  signal cmdIn_ready_unl        : std_logic;
  signal cmdIn_valid_pre        : std_logic;
  signal cmdIn_valid_bus        : std_logic;
  signal cmdIn_valid_unl        : std_logic;

  signal word_valid             : std_logic;
  signal word_ready             : std_logic;
  signal word_last              : std_logic;
  signal word_count             : std_logic_vector(0 downto 0) := "1";
  signal word_dvalid            : std_logic := '1';

  signal step_valid             : std_logic;
  signal step_ready             : std_logic;
  signal step_count             : std_logic_vector(0 downto 0);
  signal step_last              : std_logic;
  signal step_dvalid            : std_logic := '1';

  constant STEPS_COUNT_WIDTH    : natural := imax(1,log2ceil(BUS_BURST_MAX_LEN/BUS_BURST_STEP_LEN+1));

  signal steps_valid            : std_logic;
  signal steps_ready            : std_logic;
  signal steps_count            : std_logic_vector(STEPS_COUNT_WIDTH-1 downto 0);
  signal steps_last             : std_logic;

  constant WRITE_BUFFER_DEPTH   : natural := imax(BUS_FIFO_DEPTH, BUS_BURST_MAX_LEN)+1;

  signal buffer_full            : std_logic;
  signal buffer_empty           : std_logic;
  signal buffer_count           : std_logic_vector(log2ceil(WRITE_BUFFER_DEPTH) downto 0);

  signal unl_i_valid            : std_logic;
  signal unl_i_ready            : std_logic := '1';
  signal unl_i_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal unl_o_valid            : std_logic;
  signal unl_o_ready            : std_logic := '1';
  signal unl_o_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
begin

  -----------------------------------------------------------------------------
  -- Constant checks
  -----------------------------------------------------------------------------
  -- pragma translate off
  -- Check maximum element count and signal width
  assert ELEMENT_COUNT_MAX <= 2 ** ELEMENT_COUNT_WIDTH
    report "ELEMENT_COUNT_MAX and ELEMENT_COUNT_WIDTH mismatch."
    severity failure;
  -- pragma translate on

  -----------------------------------------------------------------------------
  -- Command stream input
  -----------------------------------------------------------------------------
  -- The command stream is split into three. The output streams go to:
  -- * Input stream pre-processing
  -- * Bus request generation
  -- * Unlock buffer
  cmd_in_split_inst: StreamSync
    generic map (
      NUM_INPUTS => 1,
      NUM_OUTPUTS => 3
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,
      in_valid(0)               => cmdIn_valid,
      in_ready(0)               => cmdIn_ready,
      out_valid(0)              => cmdIn_valid_pre,
      out_valid(1)              => cmdIn_valid_bus,
      out_valid(2)              => cmdIn_valid_unl,
      out_ready(0)              => cmdIn_ready_pre,
      out_ready(1)              => cmdIn_ready_bus,
      out_ready(2)              => cmdIn_ready_unl
    );

  -----------------------------------------------------------------------------
  -- Input stream pre-processing
  -----------------------------------------------------------------------------
  -- Pre-processes the stream to align to burst steps and generates write
  -- strobes. For offsets buffers, this unit also generates offsets for the
  -- child buffer (if required).

  pre_inst: BufferWriterPre
    generic map (
      INDEX_WIDTH               => INDEX_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_STROBE_WIDTH          => BUS_STROBE_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      IS_OFFSETS_BUFFER         => IS_OFFSETS_BUFFER,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      ELEMENT_COUNT_MAX         => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => ELEMENT_COUNT_WIDTH,
      CMD_CTRL_WIDTH            => CMD_CTRL_WIDTH,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,

      cmdIn_valid               => cmdIn_valid_pre,
      cmdIn_ready               => cmdIn_ready_pre,
      cmdIn_firstIdx            => cmdIn_firstIdx,
      cmdIn_lastIdx             => cmdIn_lastIdx,
      cmdIn_implicit            => cmdIn_implicit,
      cmdIn_ctrl                => cmdIn_ctrl,
      cmdIn_tag                 => cmdIn_tag,

      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_dvalid                 => '1',
      in_data                   => in_data,
      in_count                  => in_count,
      in_last                   => in_last,

      cmdOut_valid              => cmdOut_valid,
      cmdOut_ready              => cmdOut_ready,
      cmdOut_firstIdx           => cmdOut_firstIdx,
      cmdOut_lastIdx            => cmdOut_lastIdx,
      cmdOut_ctrl               => cmdOut_ctrl,
      cmdOut_tag                => cmdOut_tag,

      out_valid                 => pre_valid,
      out_ready                 => pre_ready,
      out_data                  => pre_data,
      out_strobe                => pre_strobe,
      out_last                  => pre_last
    );

  writebuf_strobe               <= pre_strobe;
  writebuf_data                 <= pre_data;

  -- Generate signals for word_last to Write Buffer
  word_last                     <= pre_last;

  -- Split the preprocessed output stream into a data and word signaling stream
  pre_split_inst: StreamSync
    generic map (
      NUM_INPUTS => 1,
      NUM_OUTPUTS => 2
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,
      in_valid(0)               => pre_valid,
      in_ready(0)               => pre_ready,
      out_valid(0)              => writebuf_valid,
      out_valid(1)              => word_valid,
      out_ready(0)              => writebuf_ready,
      out_ready(1)              => word_ready
    );

  -----------------------------------------------------------------------------
  -- Burst step / maximum burst counting
  -----------------------------------------------------------------------------
  -- Words that have been accepted by the bus write buffer are counted, and
  -- converted into a stream for the bus request generator that is only valid
  -- when a whole burst step has been written in the bus write buffer. Thus,
  -- the PrePadder must make sure to always output an integer multiple of
  -- a burst step length number of words, otherwise the system will deadlock.
  -- A second counter outputs the number of steps loaded when a maximum burst
  -- length has been reached or when the last signal is asserted.
  -- These counters prevent stalling the bus and indirectly the input stream,
  -- because if word handshakes are buffered while the request generator
  -- was not accepting them, it can only accept one each cycle after it's not
  -- busy anymore, while many words might already be present in the write
  -- buffer.

  -- Burst steps span multiple words, insert a bus word / beat counter
  word_count_gen: if BUS_BURST_STEP_LEN /= 1 generate
    word_count_inst : StreamElementCounter
      generic map (
        IN_COUNT_WIDTH              => 1,
        IN_COUNT_MAX                => 1,
        OUT_COUNT_WIDTH             => log2ceil(BUS_BURST_STEP_LEN+1),
        OUT_COUNT_MAX               => BUS_BURST_STEP_LEN
      )
      port map (
        clk                         => kcd_clk,
        reset                       => kcd_reset,
        in_valid                    => word_valid,
        in_ready                    => word_ready,
        in_last                     => word_last,
        in_count                    => word_count,
        in_dvalid                   => word_dvalid,
        out_valid                   => step_valid,
        out_ready                   => step_ready,
        out_count                   => open,
        out_last                    => step_last
      );

      -- We can make step_count 1, since the word stream should always
      -- contain some multiple of BUS_BURST_STEP_LEN elements. The next
      -- counter wants to count steps, not words.
      step_count                    <= "1";
  end generate;

  -- Burst steps are equal to one word. Pass through to the step stream.
  no_word_count_gen: if BUS_BURST_STEP_LEN = 1 generate
    word_ready                      <= step_ready;
    step_valid                      <= word_valid;
    step_last                       <= word_last;
    step_count                      <= "1";
  end generate;

  -- Count burst steps only if the maximum burst length is not equal to the step length
  steps_count_gen: if BUS_BURST_MAX_LEN /= BUS_BURST_STEP_LEN generate
    steps_count_inst : StreamElementCounter
      generic map (
        IN_COUNT_WIDTH              => 1,
        IN_COUNT_MAX                => 1,
        OUT_COUNT_WIDTH             => STEPS_COUNT_WIDTH,
        OUT_COUNT_MAX               => BUS_BURST_MAX_LEN / BUS_BURST_STEP_LEN
      )
      port map (
        clk                         => kcd_clk,
        reset                       => kcd_reset,
        in_valid                    => step_valid,
        in_ready                    => step_ready,
        in_last                     => step_last,
        in_count                    => step_count,
        in_dvalid                   => step_dvalid,
        out_valid                   => steps_valid,
        out_ready                   => steps_ready,
        out_count                   => steps_count,
        out_last                    => steps_last
      );
  end generate;

  -- Burst steps are equal to one word. Pass through to the steps stream.
  no_steps_count_gen: if BUS_BURST_MAX_LEN = BUS_BURST_STEP_LEN generate
    step_ready                      <= steps_ready;
    steps_valid                     <= step_valid;
    steps_last                      <= step_last;
    steps_count                     <= std_logic_vector(to_unsigned(1, STEPS_COUNT_WIDTH));
  end generate;

  -----------------------------------------------------------------------------
  -- Bus Request Generation
  -----------------------------------------------------------------------------
  cmdgen_inst: BufferWriterCmdGenBusReq
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      STEPS_COUNT_WIDTH         => STEPS_COUNT_WIDTH,
      STEPS_COUNT_MAX           => BUS_BURST_MAX_LEN/BUS_BURST_STEP_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      IS_OFFSETS_BUFFER         => IS_OFFSETS_BUFFER,
      CHECK_INDEX               => false
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,
      cmdIn_valid               => cmdIn_valid_bus,
      cmdIn_ready               => cmdIn_ready_bus,
      cmdIn_firstIdx            => cmdIn_firstIdx,
      cmdIn_lastIdx             => cmdIn_lastIdx,
      cmdIn_baseAddr            => cmdIn_baseAddr,
      cmdIn_implicit            => cmdIn_implicit,
      steps_ready               => steps_ready,
      steps_valid               => steps_valid,
      steps_count               => steps_count,
      steps_last                => steps_last,
      busReq_valid              => req_valid,
      busReq_ready              => req_ready,
      busReq_addr               => req_addr,
      busReq_len                => req_len,
      busReq_last               => req_last
    );

  -----------------------------------------------------------------------------
  -- Request to response buffer and sync
  -----------------------------------------------------------------------------
  -- We need the request last signal synchronized with the response channel
  -- to determine when to unlock.
  req_sync_inst: StreamSync
    generic map (
      NUM_INPUTS => 1,
      NUM_OUTPUTS => 2
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,
      in_valid(0)               => req_valid,
      in_ready(0)               => req_ready,
      out_valid(0)              => req_valid_A,
      out_valid(1)              => req_valid_B,
      out_ready(0)              => req_ready_A,
      out_ready(1)              => req_ready_B
    );

  req_to_rep_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                 => 16, -- TODO: should probably be configurable
      DATA_WIDTH                => 1
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,

      in_valid                  => req_valid_B,
      in_ready                  => req_ready_B,
      in_data(0)                => req_last,

      out_valid                 => req_done_valid,
      out_ready                 => req_done_ready,
      out_data(0)               => req_done_last
    );

  -----------------------------------------------------------------------------
  -- Bus Write Buffer
  -----------------------------------------------------------------------------
  buffer_inst: BusWriteBuffer
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      FIFO_DEPTH                => WRITE_BUFFER_DEPTH,
      LEN_SHIFT                 => BUS_FIFO_THRES_SHIFT,
      RAM_CONFIG                => "",
      SLV_LAST_MODE             => "generate"
    )
    port map (
      clk                       => bcd_clk,
      reset                     => bcd_reset,
      
      full                      => buffer_full,
      empty                     => buffer_empty,
      count                     => buffer_count,

      slv_wreq_valid            => req_valid_A,
      slv_wreq_ready            => req_ready_A,
      slv_wreq_addr             => req_addr,
      slv_wreq_len              => req_len,
      slv_wreq_last             => req_last,
      slv_wdat_valid            => writebuf_valid,
      slv_wdat_ready            => writebuf_ready,
      slv_wdat_data             => writebuf_data,
      slv_wdat_strobe           => writebuf_strobe,
      slv_wrep_valid            => rep_valid,
      slv_wrep_ready            => rep_ready,
      slv_wrep_ok               => rep_ok,

      mst_wreq_valid            => bus_wreq_valid,
      mst_wreq_ready            => bus_wreq_ready,
      mst_wreq_addr             => bus_wreq_addr,
      mst_wreq_len              => bus_wreq_len,
      mst_wreq_last             => bus_wreq_last,
      mst_wdat_valid            => bus_wdat_valid,
      mst_wdat_ready            => bus_wdat_ready,
      mst_wdat_data             => bus_wdat_data,
      mst_wdat_strobe           => bus_wdat_strobe,
      mst_wdat_last             => bus_wdat_last,
      mst_wrep_valid            => bus_wrep_valid,
      mst_wrep_ready            => bus_wrep_ready,
      mst_wrep_ok               => bus_wrep_ok
    );

  -- Input buffer for the unlock stream to prevent blocking the command stream
  unlock_input_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                 => 2,
      DATA_WIDTH                => CMD_TAG_WIDTH
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,

      in_valid                  => cmdIn_valid_unl,
      in_ready                  => cmdIn_ready_unl,
      in_data                   => cmdIn_tag,

      out_valid                 => unl_i_valid,
      out_ready                 => unl_i_ready,
      out_data                  => unl_i_tag
    );

  -- Let the unlock output buffer and the bus last_in_cmd signal backpressure
  -- both the data and command stream.
  unlock_bus_sync_inst: StreamSync
    generic map (
      NUM_INPUTS => 3,
      NUM_OUTPUTS => 1
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,

      in_valid(2)               => req_done_valid,
      in_valid(1)               => rep_valid,
      in_valid(0)               => unl_i_valid,

      in_ready(2)               => req_done_ready,
      in_ready(1)               => rep_ready,
      in_ready(0)               => unl_i_ready,

      in_advance(2)             => '1',
      in_advance(1)             => '1',
      in_advance(0)             => req_done_last,

      out_valid(0)              => unl_o_valid,
      out_ready(0)              => unl_o_ready,
      out_enable(0)             => req_done_last

    );

  -- Connect the input buffer to the output buffer.
  unl_o_tag                     <= unl_i_tag;

  -- Output buffer for the unlock stream to prevent blocking the bus
  unlock_output_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                 => 2,
      DATA_WIDTH                => CMD_TAG_WIDTH
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,

      in_valid                  => unl_o_valid,
      in_ready                  => unl_o_ready,
      in_data                   => unl_o_tag,

      out_valid                 => unlock_valid,
      out_ready                 => unlock_ready,
      out_data                  => unlock_tag
    );

end Behavioral;

