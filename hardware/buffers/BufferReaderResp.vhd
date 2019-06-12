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
use work.UtilMisc_pkg.all;

entity BufferReaderResp is
  generic (

    ---------------------------------------------------------------------------
    -- Signal widths and functional configuration
    ---------------------------------------------------------------------------
    -- Bus data width.
    BUS_DATA_WIDTH              : natural;
    
    -- Number of beats in a burst step.
    BUS_BURST_STEP_LEN          : natural;

    -- Index field width.
    INDEX_WIDTH                 : natural;

    -- Buffer element width in bits.
    ELEMENT_WIDTH               : natural;

    -- Whether this is a normal buffer or an offsets buffer.
    IS_OFFSETS_BUFFER           : boolean;

    -- Width of the internal command stream shift vector. Should equal
    -- max(1, log2(BUS_WIDTH / ELEMENT_WIDTH))
    ICS_SHIFT_WIDTH             : natural;

    -- Width of the internal command stream count vector. Should equal
    -- max(1, log2(BUS_WIDTH / ELEMENT_WIDTH) + 1)
    ICS_COUNT_WIDTH             : natural;

    -- Maximum amount of elements per FIFO entry.
    ELEMENT_FIFO_COUNT_MAX      : natural;

    -- Width of the FIFO element count vector. Should equal
    -- max(1, ceil(log2(FIFO_COUNT_MAX)))
    ELEMENT_FIFO_COUNT_WIDTH    : natural;

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
    -- output.
    CMD_OUT_SLICE               : boolean;

    -- Whether a register slice should be inserted between the LSB-alignment
    -- right-shift unit and the bus to FIFO gearbox.
    SHR2GB_SLICE                : boolean;

    -- Whether a register slice should be inserted between the bus to FIFO
    -- gearbox and the FIFO input.
    GB2FIFO_SLICE               : boolean;

    -- Whether a register slice should be inserted in the unlock stream output.
    UNLOCK_SLICE                : boolean

  );
  port (

    ---------------------------------------------------------------------------
    -- Clock domains
    ---------------------------------------------------------------------------
    -- Rising-edge sensitive clock and active-high synchronous reset.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    ---------------------------------------------------------------------------
    -- Input streams
    ---------------------------------------------------------------------------
    -- Bus read response (bus clock domain).
    busResp_valid               : in  std_logic;
    busResp_ready               : out std_logic;
    busResp_data                : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

    -- Internal command stream.
    intCmd_valid                : in  std_logic;
    intCmd_ready                : out std_logic;
    intCmd_firstIdx             : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    intCmd_lastIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    intCmd_implicit             : in  std_logic;
    intCmd_ctrl                 : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    intCmd_tag                  : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    ---------------------------------------------------------------------------
    -- Output streams
    ---------------------------------------------------------------------------
    -- Command stream output. This stream is only used for offsets buffers. For
    -- each command received at the input, an output command is also generated,
    -- using indices translated by the indices in the buffer:
    --   cmdout_firstIdx = cmdin_baseAddr[cmdin_firstIdx]
    --   cmdout_lastIdx = cmdin_baseAddr[cmdin_lastIdx]
    cmdOut_valid                : out std_logic;
    cmdOut_ready                : in  std_logic := '1';
    cmdOut_firstIdx             : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdOut_lastIdx              : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdOut_ctrl                 : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    cmdOut_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    -- Unlock stream. When all bus accesses for a command complete, the tag of
    -- that command will be outputted here. If ignoreChild is set, no command
    -- was sent out to the child reader through the cmdOut stream (this happens
    -- when only empty lists were requested). In that case, the StreamSync that
    -- combines the unlock streams should not wait for its unlock transfer.
    unlock_valid                : out std_logic;
    unlock_ready                : in  std_logic := '1';
    unlock_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
    unlock_ignoreChild          : out std_logic;

    -- Data stream to the FIFO. fifo_data contains FIFO_COUNT_MAX elements,
    -- each ELEMENT_WIDTH in size. The first element is LSB aligned. fifo_count
    -- indicates how many elements are valid. There is always at least 1
    -- element valid; the MSB of this signal is 1 implicitly when count is zero
    -- (that is, if count is "00", all "100" = 4 elements are valid). fifo_last
    -- indicates that the last word for the current command is present in this
    -- bundle.
    fifoIn_valid                : out std_logic;
    fifoIn_ready                : in  std_logic;
    fifoIn_data                 : out std_logic_vector(ELEMENT_FIFO_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    fifoIn_count                : out std_logic_vector(ELEMENT_FIFO_COUNT_WIDTH-1 downto 0);
    fifoIn_last                 : out std_logic

  );
end BufferReaderResp;

architecture Behavioral of BufferReaderResp is

  -- Amount of bus beats per element.
  constant BUS_BPE              : natural := imax(1, ELEMENT_WIDTH / BUS_DATA_WIDTH);
  
  -- Amount of elements per bus beat (= the amount of elements we handle at a
  -- time in most of this unit).
  constant BUS_EPB              : natural := imax(1, BUS_DATA_WIDTH / ELEMENT_WIDTH);

  -- Bus response stream after the optional parallelizer.
  signal busRespP_valid         : std_logic;
  signal busRespP_ready         : std_logic;

  -- Bus response stream handshake masked by the implicit flag.
  signal busRespI_valid         : std_logic;
  signal busRespI_ready         : std_logic;

  -- Control signal stream handshake.
  signal ctrl_valid             : std_logic;
  signal ctrl_ready             : std_logic;

  -- Stage A data and control information. This stage LSB-aligns the valid
  -- elements in the incoming bus word and synchronizes all relevant streams.
  -- Payload is synchronized with busRespP, ctrl, unlockB, and also cmdOutFirst
  -- and cmdOutLast for offsets buffer readers.
  signal stageA_valid           : std_logic;
  signal stageA_ready           : std_logic;
  signal stageA_data            : std_logic_vector(BUS_EPB*ELEMENT_WIDTH-1 downto 0);
  signal stageA_data_aligned    : std_logic_vector(BUS_EPB*ELEMENT_WIDTH-1 downto 0);
  signal stageA_implicit        : std_logic;
  signal stageA_shift           : std_logic_vector(ICS_SHIFT_WIDTH-1 downto 0);
  signal stageA_count           : std_logic_vector(ICS_COUNT_WIDTH-1 downto 0);
  signal stageA_init            : std_logic;
  signal stageA_last            : std_logic;
  signal stageA_ctrl            : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
  signal stageA_tag             : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal stageA_ignoreChild     : std_logic;

  -- Register-sliced version of stage A.
  signal stageB_valid           : std_logic;
  signal stageB_ready           : std_logic;
  signal stageB_data            : std_logic_vector(BUS_EPB*ELEMENT_WIDTH-1 downto 0);
  signal stageB_count           : std_logic_vector(imax(0, ICS_COUNT_WIDTH-2) downto 0);
  signal stageB_last            : std_logic;

  -- Stage B serialization indices.
  constant SBI : nat_array := cumulative((
    2 => stageB_data'length,
    1 => stageB_count'length,
    0 => 1 -- stageB_last
  ));

  signal sbi_sData              : std_logic_vector(SBI(SBI'high)-1 downto 0);
  signal sbo_sData              : std_logic_vector(SBI(SBI'high)-1 downto 0);

  -- Serialized/parallelized version of stage B.
  signal stageC_valid           : std_logic;
  signal stageC_ready           : std_logic;
  signal stageC_data            : std_logic_vector(ELEMENT_FIFO_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal stageC_count           : std_logic_vector(ELEMENT_FIFO_COUNT_WIDTH-1 downto 0);
  signal stageC_last            : std_logic;

  -- Stage C serialization indices.
  constant SCI : nat_array := cumulative((
    2 => stageC_data'length,
    1 => stageC_count'length,
    0 => 1 -- stageC_last
  ));

  signal sci_sData              : std_logic_vector(SCI(SCI'high)-1 downto 0);
  signal sco_sData              : std_logic_vector(SCI(SCI'high)-1 downto 0);

  -- Unlock stream serialization indices.
  constant UNI : nat_array := cumulative((
    1 => stageA_tag'length,
    0 => 1 -- stageA_ignoreChild
  ));

  -- Unlock stream before its buffer.
  signal unlockB_valid          : std_logic;
  signal unlockB_ready          : std_logic;
  signal unlockB_sData          : std_logic_vector(UNI(UNI'high)-1 downto 0);

  -- Unlock stream after its buffer.
  signal unlock_sData           : std_logic_vector(UNI(UNI'high)-1 downto 0);

begin

  -- Bus response parallelizer. This is only used when the bus is narrower than
  -- a single element.
  bus_para_gen: if BUS_BPE > 1 generate
  begin
    inst: StreamGearboxParallelizer
      generic map (
        ELEMENT_WIDTH                   => BUS_DATA_WIDTH,
        OUT_COUNT_MAX                   => BUS_BPE,
        OUT_COUNT_WIDTH                 => log2ceil(BUS_BPE)
      )
      port map (
        clk                             => clk,
        reset                           => reset,

        in_valid                        => busResp_valid,
        in_ready                        => busResp_ready,
        in_data                         => busResp_data,

        out_valid                       => busRespP_valid,
        out_ready                       => busRespP_ready,
        out_data                        => stageA_data
      );
  end generate;
  no_bus_para_gen: if BUS_BPE = 1 generate
  begin
    busRespP_valid  <= busResp_valid;
    busResp_ready   <= busRespP_ready;
    stageA_data     <= busResp_data;
  end generate;

  -- In simulation, check requirement on BUS_BURST_STEP_LEN
  --pragma translate off
  assert BUS_BURST_STEP_LEN / BUS_BPE > 0 
    report "Elements are wider than the bus data width. To accomodate this, " &
           "BUS_BURST_STEP_LEN must be a multiple of " & 
           "ELEMENT_WIDTH / BUS_DATA_WIDTH."
    severity failure;
  --pragma translate on

  -- Instantiate control signal generator.
  ctrl_inst: BufferReaderRespCtrl
    generic map (
      INDEX_WIDTH                       => INDEX_WIDTH,
      IS_OFFSETS_BUFFER                 => IS_OFFSETS_BUFFER,
      ICS_SHIFT_WIDTH                   => ICS_SHIFT_WIDTH,
      ICS_COUNT_WIDTH                   => ICS_COUNT_WIDTH,
      BUS_DATA_WIDTH                    => BUS_DATA_WIDTH * BUS_BPE,
      BUS_BURST_STEP_LEN                => BUS_BURST_STEP_LEN / BUS_BPE,
      ELEMENT_WIDTH                     => ELEMENT_WIDTH,
      CMD_CTRL_WIDTH                    => CMD_CTRL_WIDTH,
      CMD_TAG_WIDTH                     => CMD_TAG_WIDTH,
      CHECK_INDEX                       => true
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      cmdIn_valid                       => intCmd_valid,
      cmdIn_ready                       => intCmd_ready,
      cmdIn_firstIdx                    => intCmd_firstIdx,
      cmdIn_lastIdx                     => intCmd_lastIdx,
      cmdIn_implicit                    => intCmd_implicit,
      cmdIn_ctrl                        => intCmd_ctrl,
      cmdIn_tag                         => intCmd_tag,

      intCmd_valid                      => ctrl_valid,
      intCmd_ready                      => ctrl_ready,
      intCmd_implicit                   => stageA_implicit,
      intCmd_shift                      => stageA_shift,
      intCmd_count                      => stageA_count,
      intCmd_init                       => stageA_init,
      intCmd_last                       => stageA_last,
      intCmd_ctrl                       => stageA_ctrl,
      intCmd_tag                        => stageA_tag
    );

  -- Alignment unit. This block LSB-aligns incoming bundles of data elements,
  -- for the case where a bus word is larger than an element. This unit also
  -- overrides the incoming word with all ones when the implicit flag is set
  -- (in which case stageA_data is invalid, because we didn't actually do a bus
  -- request).
  alignment_gen: if BUS_EPB > 1 generate
  begin
    stageA_data_aligned <= std_logic_vector(
      shift_right(unsigned(stageA_data),
      ELEMENT_WIDTH * to_integer(unsigned(stageA_shift))))
      when stageA_implicit = '0'
      else (others => '1');
  end generate;
  no_alignment_gen: if BUS_EPB = 1 generate
  begin
    stageA_data_aligned <= stageA_data
                      when stageA_implicit = '0'
                      else (others => '1');
  end generate;

  -- Mask out the bus response handshake when implicit is set, so we neither
  -- acknowledge nor wait for bus transfers that we didn't actually request
  -- because this is an implicit command.
  busRespI_valid <= busRespP_valid or (stageA_implicit and ctrl_valid);
  busRespP_ready <= busRespI_ready and not (stageA_implicit and ctrl_valid);

  -- Generate the synchronization logic and outgoing command stream if this is
  -- an offsets buffer.
  offsets_buffer_cmd_stream_gen: if IS_OFFSETS_BUFFER generate

    -- Copy of the first element in stageA_data_aligned, resized to the width
    -- of an index.
    signal stageA_index         : std_logic_vector(INDEX_WIDTH-1 downto 0);

    -- Stream representing the outgoing command stream before the register
    -- slice at the output. When this stream is valid, cmdOutLast_dataReg
    -- contains the last index (latched earlier) and the first element in
    -- stageA_data_aligned (= stageA_index) represents the first index.
    signal cmdOutFirst_valid    : std_logic;
    signal cmdOutFirst_ready    : std_logic;

    -- Last index data register.
    signal cmdOutLast_valid     : std_logic;
    signal cmdOutLast_dataReg   : std_logic_vector(INDEX_WIDTH-1 downto 0);

    -- Control signals indicating which stream outputs should be enabled
    -- based on the internal command stream control signals.
    signal cmdOutFirst_enable   : std_logic;
    signal cmdOutLast_enable    : std_logic;
    signal stageA_enable        : std_logic;

    -- Indicates whether the outgoing command is null, i.e. first >= last. This
    -- is valid when stageA_init, stageA_enable, and stageA_valid are high.
    signal cmdOut_null          : std_logic;

    -- Registered version of cmdOut_null, valid one cycle after the first real
    -- transfer is validated until the end of the execution of the command.
    signal cmdOut_null_r        : std_logic;

    constant CSI : nat_array := cumulative((
      3 => cmdOut_firstIdx'length,
      2 => cmdOut_lastIdx'length,
      1 => cmdOut_ctrl'length,
      0 => cmdOut_tag'length
    ));

    signal csi_sData            : std_logic_vector(CSI(CSI'high)-1 downto 0);
    signal cso_sData            : std_logic_vector(CSI(CSI'high)-1 downto 0);

  begin

    -- Extract the first element in the current bus word and resize it to the
    -- width of an index.
    stageA_index <= std_logic_vector(resize(
      unsigned(stageA_data_aligned(ELEMENT_WIDTH-1 downto 0)), INDEX_WIDTH));

    -- stageA output stream is enabled whenever there is at least one valid
    -- element in the current bus word.
    stageA_enable <= or_reduce(stageA_count);

    -- Determine whether the outgoing command is null or not.
    cmdOut_null <= '1'
              when to_01(unsigned(stageA_index)) >= to_01(unsigned(cmdOutLast_dataReg))
              else '0';

    --pragma translate off
    assert unsigned(cmdOutLast_dataReg) > 0
      report "Last index is 0 for list reader, you might be reading data out of bounds."
      severity warning;
    --pragma translate on

    -- The first index output stream is enabled when init is set, there is
    -- incoming data, and last > first.
    cmdOutFirst_enable <= stageA_init and stageA_enable and not cmdOut_null;

    -- The last index output stream is enabled when init is set but there is no
    -- incoming data. Note that, implicitly, at least one element is valid in
    -- the bus word.
    cmdOutLast_enable <= stageA_init and not stageA_enable;

    -- Stage A data synchronizer without outgoing command stream.
    stageA_sync_inst: StreamSync
      generic map (
        NUM_INPUTS                      => 2,
        NUM_OUTPUTS                     => 4
      )
      port map (
        clk                             => clk,
        reset                           => reset,

        in_valid(1)                     => busRespI_valid,
        in_valid(0)                     => ctrl_valid,
        in_ready(1)                     => busRespI_ready,
        in_ready(0)                     => ctrl_ready,

        out_valid(3)                    => cmdOutFirst_valid,
        out_valid(2)                    => cmdOutLast_valid,
        out_valid(1)                    => unlockB_valid,
        out_valid(0)                    => stageA_valid,
        out_ready(3)                    => cmdOutFirst_ready,
        out_ready(2)                    => '1',
        out_ready(1)                    => unlockB_ready,
        out_ready(0)                    => stageA_ready,
        out_enable(3)                   => cmdOutFirst_enable,
        out_enable(2)                   => cmdOutLast_enable,
        out_enable(1)                   => stageA_last,
        out_enable(0)                   => stageA_enable
      );

    -- Instantiate the holding register for the last index and unlockChild.
    reg_proc: process (clk) is
    begin
      if rising_edge(clk) then

        -- Save the last index.
        if cmdOutLast_valid = '1' then
          cmdOutLast_dataReg <= stageA_index;
        end if;

        -- Save the ignoreChild flag.
        if stageA_init = '1' and stageA_valid = '1' then
          cmdOut_null_r <= cmdOut_null;
        end if;

        -- pragma translate_off

        -- Make the register contents undefined after a reset.
        if reset = '1' then
          cmdOutLast_dataReg <= (others => 'U');
          cmdOut_null_r <= 'U';
        end if;

        -- pragma translate_on

      end if;
    end process;

    -- The cmdOut_null_r signal is one cycle late when the first and last index
    -- can be retrieved in a single bus transfer, because in that case the
    -- timing is aligned to cmdOut_null.
    stageA_ignoreChild <= cmdOut_null
                     when stageA_init = '1' and stageA_valid = '1'
                     else cmdOut_null_r;

    -- Serialize the outgoing command stream signals for the buffer.
    csi_sData(CSI(4)-1 downto CSI(3))   <= stageA_index;
    csi_sData(CSI(3)-1 downto CSI(2))   <= cmdOutLast_dataReg;
    csi_sData(CSI(2)-1 downto CSI(1))   <= stageA_ctrl;
    csi_sData(CSI(1)-1 downto CSI(0))   <= stageA_tag;

    -- Buffer the outgoing command stream.
    cmd_out_buffer_inst: StreamBuffer
      generic map (
        MIN_DEPTH                       => sel(CMD_OUT_SLICE, 2, 0),
        DATA_WIDTH                      => CSI(CSI'high)
      )
      port map (
        clk                             => clk,
        reset                           => reset,

        in_valid                        => cmdOutFirst_valid,
        in_ready                        => cmdOutFirst_ready,
        in_data                         => csi_sData,

        out_valid                       => cmdOut_valid,
        out_ready                       => cmdOut_ready,
        out_data                        => cso_sData
      );

    -- Deserialize the outgoing command stream signals after the buffer.
    cmdOut_firstIdx                     <= cso_sData(CSI(4)-1 downto CSI(3));
    cmdOut_lastIdx                      <= cso_sData(CSI(3)-1 downto CSI(2));
    cmdOut_ctrl                         <= cso_sData(CSI(2)-1 downto CSI(1));
    cmdOut_tag                          <= cso_sData(CSI(1)-1 downto CSI(0));

  end generate;

  -- Generate the synchronization logic if this is not an offsets buffer.
  no_offsets_buffer_cmd_stream_gen: if not IS_OFFSETS_BUFFER generate
    
    -- Control signal indicating whether we need to push this item into the
    -- FIFO.
    signal stageA_enable                : std_logic;
    
  begin

    -- stageA output stream is enabled whenever there is at least one valid
    -- element in the current bus word.
    stageA_enable <= or_reduce(stageA_count);
    
    -- Stage A data synchronizer without outgoing command stream.
    stageA_sync_inst: StreamSync
      generic map (
        NUM_INPUTS                      => 2,
        NUM_OUTPUTS                     => 2
      )
      port map (
        clk                             => clk,
        reset                           => reset,

        in_valid(1)                     => busRespI_valid,
        in_valid(0)                     => ctrl_valid,
        in_ready(1)                     => busRespI_ready,
        in_ready(0)                     => ctrl_ready,

        out_valid(1)                    => unlockB_valid,
        out_valid(0)                    => stageA_valid,
        out_ready(1)                    => unlockB_ready,
        out_ready(0)                    => stageA_ready,
        out_enable(1)                   => stageA_last,
        out_enable(0)                   => stageA_enable
      );

    -- Tie the unused outgoing command stream to constants.
    cmdOut_valid        <= '0';
    cmdOut_firstIdx     <= (others => '0');
    cmdOut_lastIdx      <= (others => '0');

    -- The child unlock stream can always be ignored, because it doesn't exist.
    stageA_ignoreChild  <= '1';

  end generate;

  -- Generate an optional register slice between datapath stage A and B. This
  -- is primarily to break the path from the LSB-aligning right-shifter to the
  -- gearbox (or FIFO, if the gearbox is no-op).
  sbi_sData(SBI(3)-1 downto SBI(2))     <= stageA_data_aligned;
  sbi_sData(SBI(2)-1 downto SBI(1))     <= stageA_count(stageB_count'range);
  sbi_sData(SBI(0))                     <= stageA_last;

  stage_a2b_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(SHR2GB_SLICE, 2, 0),
      DATA_WIDTH                        => SBI(SBI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => stageA_valid,
      in_ready                          => stageA_ready,
      in_data                           => sbi_sData,

      out_valid                         => stageB_valid,
      out_ready                         => stageB_ready,
      out_data                          => sbo_sData
    );

  stageB_data                           <= sbo_sData(SBI(3)-1 downto SBI(2));
  stageB_count                          <= sbo_sData(SBI(2)-1 downto SBI(1));
  stageB_last                           <= sbo_sData(SBI(0));

  -- Optionally serialize or parallelize the data stream before it goes into
  -- the FIFO. Serialization should be used with caution, as it may cause the
  -- bus to back up if the bus FIFO is not deep enough to take the hit.
  -- Parallelization can be used to make the FIFO wider in case more elements
  -- per cycle than there are elements per bus word are desired in the
  -- accelerator clock domain (and the accelerator clock runs slower than the
  -- bus clock).
  stage_b2c_gearbox_inst: StreamGearbox
    generic map (
      ELEMENT_WIDTH                     => ELEMENT_WIDTH,
      IN_COUNT_MAX                      => BUS_EPB,
      IN_COUNT_WIDTH                    => stageB_count'length,
      OUT_COUNT_MAX                     => ELEMENT_FIFO_COUNT_MAX,
      OUT_COUNT_WIDTH                   => ELEMENT_FIFO_COUNT_WIDTH
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => stageB_valid,
      in_ready                          => stageB_ready,
      in_data                           => stageB_data,
      in_count                          => stageB_count,
      in_last                           => stageB_last,

      out_valid                         => stageC_valid,
      out_ready                         => stageC_ready,
      out_data                          => stageC_data,
      out_count                         => stageC_count,
      out_last                          => stageC_last
    );

  -- Generate an optional register slice between datapath stage C and D. This
  -- breaks the path between the gearbox and the FIFO.
  sci_sData(SCI(3)-1 downto SCI(2))     <= stageC_data;
  sci_sData(SCI(2)-1 downto SCI(1))     <= stageC_count;
  sci_sData(                SCI(0))     <= stageC_last;

  stage_c2d_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(GB2FIFO_SLICE, 2, 0),
      DATA_WIDTH                        => SCI(SCI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => stageC_valid,
      in_ready                          => stageC_ready,
      in_data                           => sci_sData,

      out_valid                         => fifoIn_valid,
      out_ready                         => fifoIn_ready,
      out_data                          => sco_sData
    );

  fifoIn_data                           <= sco_sData(SCI(3)-1 downto SCI(2));
  fifoIn_count                          <= sco_sData(SCI(2)-1 downto SCI(1));
  fifoIn_last                           <= sco_sData(                SCI(0));

  -- Generate an optional register slice in the unlock output stream.
  unlockB_sData(UNI(2)-1 downto UNI(1)) <= stageA_tag;
  unlockB_sData(                UNI(0)) <= stageA_ignoreChild;

  unlock_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(UNLOCK_SLICE, 2, 0),
      DATA_WIDTH                        => UNI(UNI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => unlockB_valid,
      in_ready                          => unlockB_ready,
      in_data                           => unlockB_sData,

      out_valid                         => unlock_valid,
      out_ready                         => unlock_ready,
      out_data                          => unlock_sData
    );

  unlock_tag                            <= unlock_sData(UNI(2)-1 downto UNI(1));
  unlock_ignoreChild                    <= unlock_sData(                UNI(0));

end Behavioral;

