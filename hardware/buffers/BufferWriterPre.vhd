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
use work.Utils.all;
use work.Streams.all;
use work.Buffers.all;
use work.Interconnect.all;

-- This unit converts a stream of elements to a stream of bus words and
-- write strobes.
entity BufferWriterPre is
  generic (
    ---------------------------------------------------------------------------
    -- Arrow metrics and configuration
    ---------------------------------------------------------------------------
    -- Index field width.
    INDEX_WIDTH                 : natural;

    ---------------------------------------------------------------------------
    -- Buffer metrics and configuration
    ---------------------------------------------------------------------------
    -- Bus data width.
    BUS_DATA_WIDTH              : natural;

    -- Bus strobe width
    BUS_STROBE_WIDTH            : natural;

    -- Number of beats in a burst step.
    BUS_BURST_STEP_LEN          : natural;

    -- Whether this is a normal buffer or an offsets buffer.
    IS_OFFSETS_BUFFER           : boolean;

    -- Buffer element width in bits.
    ELEMENT_WIDTH               : natural;

    -- Maximum number of elements per cycle.
    ELEMENT_COUNT_MAX           : natural := 1;

    -- Width of the vector indicating the number of valid elements. Must be at
    -- least 1 to prevent null ranges.
    ELEMENT_COUNT_WIDTH         : natural := 1;

    -- Command stream control vector width.
    CMD_CTRL_WIDTH              : natural;

    -- Command stream tag width. This tag is propagated to the outgoing command
    -- stream and to the unlock stream. It is intended for chunk reference
    -- counting.
    CMD_TAG_WIDTH               : natural;

    -- Optional synchronizer for the data and write strobe streams
    --SYNC_OUTPUT                 : boolean

    -- Optional register slice in the normalizers
    NORM_SLICE                  : boolean := true

  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    cmdIn_valid                 : in  std_logic;
    cmdIn_ready                 : out std_logic;
    cmdIn_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_implicit              : in  std_logic;
    cmdIn_ctrl                  : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    cmdIn_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_dvalid                   : in  std_logic;
    in_data                     : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    in_last                     : in  std_logic;

    cmdOut_valid                : out std_logic;
    cmdOut_ready                : in  std_logic := '1';
    cmdOut_firstIdx             : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdOut_lastIdx              : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdOut_ctrl                 : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0) := (others => '0');
    cmdOut_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    out_strobe                  : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
    out_last                    : out std_logic
  );
end BufferWriterPre;

architecture Behavioral of BufferWriterPre is
  -- Number of elements on a data bus word:
  constant BE_COUNT_MAX         : natural := BUS_DATA_WIDTH / ELEMENT_WIDTH;
  constant BE_COUNT_WIDTH       : natural := log2ceil(BE_COUNT_MAX);
  constant BYTE_COUNT           : natural := BUS_DATA_WIDTH / 8;
  constant BYTES_PER_ELEM       : natural := work.Utils.max(1, ELEMENT_WIDTH / 8);
  constant ELEMS_PER_BYTE       : natural := 8 / ELEMENT_WIDTH;

  -- Number of bits covered by a single strobe bit:
  constant STROBE_COVER         : natural := BUS_DATA_WIDTH / BUS_STROBE_WIDTH;

  -- Padded stream
  signal pad_valid              : std_logic;
  signal pad_ready              : std_logic;
  signal pad_dvalid             : std_logic;
  signal pad_data               : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal pad_strobe             : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
  signal pad_count              : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal pad_last               : std_logic;
  signal pad_clear              : std_logic;
  signal pad_implicit           : std_logic;
  signal pad_ctrl               : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
  signal pad_tag                : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal pad_last_npad          : std_logic;

  -- Optional Index buffer length value Accumulation stream
  signal oia_valid              : std_logic;
  signal oia_ready              : std_logic;
  signal oia_dvalid             : std_logic;
  signal oia_data               : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal oia_strobe             : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
  signal oia_count              : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal oia_last               : std_logic;
  signal oia_implicit           : std_logic;
  signal oia_ctrl               : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
  signal oia_tag                : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal oia_last_npad          : std_logic;

  -- Signals to split the OIA stream
  signal oia_data_ready         : std_logic;
  signal oia_strobe_ready       : std_logic;
  signal oia_data_valid         : std_logic;
  signal oia_strobe_valid       : std_logic;
  
  -- Signals to normalizer
  signal norm_in_valid          : std_logic;
  signal norm_in_ready          : std_logic;
  signal norm_in_dvalid         : std_logic;
  signal norm_in_data           : std_logic_vector(ELEMENT_COUNT_MAX*(ELEMENT_WIDTH+1)-1 downto 0);
  signal norm_in_count          : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal norm_in_last           : std_logic;
  
  -- Signals from normalizer
  signal norm_out_valid         : std_logic;
  signal norm_out_ready         : std_logic;
  signal norm_out_dvalid        : std_logic;
  signal norm_out_data          : std_logic_vector(ELEMENT_COUNT_MAX*(ELEMENT_WIDTH+1)-1 downto 0);
  signal norm_out_count         : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal norm_out_last          : std_logic;
  

  -- Normalized stream
  signal norm_valid             : std_logic;
  signal norm_ready             : std_logic;
  signal norm_dvalid            : std_logic;
  signal norm_strobe            : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
  signal norm_data              : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal norm_count             : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal norm_last              : std_logic;

  -- Gearbox input
  signal gb_in_valid            : std_logic;
  signal gb_in_ready            : std_logic;
  signal gb_in_data             : std_logic_vector(ELEMENT_COUNT_MAX*(ELEMENT_WIDTH+1)-1 downto 0);
  signal gb_in_count            : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal gb_in_last             : std_logic;

  -- Gearbox output
  signal gb_out_valid           : std_logic;
  signal gb_out_ready           : std_logic;
  signal gb_out_data            : std_logic_vector(BUS_DATA_WIDTH+BE_COUNT_MAX-1 downto 0);
  signal gb_out_count           : std_logic_vector(BE_COUNT_WIDTH-1 downto 0);
  signal gb_out_last            : std_logic;

  -- Shaped output
  signal shaped_valid           : std_logic;
  signal shaped_ready           : std_logic;
  signal shaped_data            : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal shaped_count           : std_logic_vector(BE_COUNT_WIDTH-1 downto 0);
  signal shaped_strobe          : std_logic_vector(BE_COUNT_MAX-1 downto 0);
  signal shaped_last            : std_logic;

  -- Output buffer
  signal int_out_valid          : std_logic;
  signal int_out_ready          : std_logic;
  signal int_out_data           : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal int_out_strobe         : std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
  signal int_out_last           : std_logic;

begin
  -----------------------------------------------------------------------------
  -- Padding and write strobe generation
  -----------------------------------------------------------------------------
  -- We pad the incoming stream with elements such that they align to a burst
  -- step. Also, element-based write strobes are generated

  padder_inst: BufferWriterPrePadder
    generic map (
      INDEX_WIDTH               => INDEX_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      IS_OFFSETS_BUFFER         => IS_OFFSETS_BUFFER,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      ELEMENT_COUNT_MAX         => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => ELEMENT_COUNT_WIDTH,
      CMD_CTRL_WIDTH            => CMD_CTRL_WIDTH,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH,
      OUT_SLICE                 => true
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      cmdIn_valid               => cmdIn_valid,
      cmdIn_ready               => cmdIn_ready,
      cmdIn_firstIdx            => cmdIn_firstIdx,
      cmdIn_lastIdx             => cmdIn_lastIdx,
      cmdIn_implicit            => cmdIn_implicit,
      cmdIn_ctrl                => cmdIn_ctrl,
      cmdIn_tag                 => cmdIn_tag,

      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_data                   => in_data,
      in_count                  => in_count,
      in_last                   => in_last,

      out_valid                 => pad_valid,
      out_ready                 => pad_ready,
      out_data                  => pad_data,
      out_strobe                => pad_strobe,
      out_count                 => pad_count,
      out_last                  => pad_last,
      out_clear                 => pad_clear,
      out_implicit              => pad_implicit,
      out_ctrl                  => pad_ctrl,
      out_tag                   => pad_tag,
      out_last_npad             => pad_last_npad
    );

  -----------------------------------------------------------------------------
  -- Length accumulator for offsets buffers
  -----------------------------------------------------------------------------

  -- For offsets buffers, the input is a length, which should be accumulated into
  -- an offset. It should be reset when a new command is accepted.
  offs_gen: if IS_OFFSETS_BUFFER generate

    -- Length stream serialization indices
    constant LSI : nat_array := cumulative((
      7 => 1,
      6 => ELEMENT_COUNT_WIDTH,
      5 => ELEMENT_COUNT_MAX,
      4 => 1,
      3 => 1,
      2 => CMD_CTRL_WIDTH,
      1 => CMD_TAG_WIDTH,
      0 => ELEMENT_WIDTH
    ));

    signal pad_acc_all          : std_logic_vector(LSI(8)-1 downto 0);
    signal pad_acc_skip         : std_logic;

    signal oia_acc_valid        : std_logic;
    signal oia_acc_ready        : std_logic;
    signal oia_acc_all          : std_logic_vector(LSI(8)-1 downto 0);

    signal cmd_valid            : std_logic;
    signal cmd_ready            : std_logic;
    signal cmd_firstIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
    signal cmd_implicit         : std_logic;
    signal cmd_last             : std_logic;
    signal cmd_ctrl             : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0) := (others => '0');
    signal cmd_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

  begin

    pad_acc_skip                <= not(pad_strobe(0));

    pad_acc_all(                LSI(7)) <= pad_last_npad;
    pad_acc_all(LSI(7)-1 downto LSI(6)) <= pad_count;
    pad_acc_all(LSI(6)-1 downto LSI(5)) <= pad_strobe;
    pad_acc_all(                LSI(4)) <= pad_last;
    pad_acc_all(                LSI(3)) <= pad_implicit;
    pad_acc_all(LSI(3)-1 downto LSI(2)) <= pad_ctrl;
    pad_acc_all(LSI(2)-1 downto LSI(1)) <= pad_tag;
    pad_acc_all(LSI(1)-1 downto LSI(0)) <= pad_data;

    -- Instantiate a stream accumulator. If this is an offsets buffer,
    -- ELEMENT_COUNT_MAX should be 1, the strobe should be one bit and we
    -- have one last bit. Skip accumulating if the strobe is low; this is
    -- padded data and not an actual length that we should use.
    accumulator_inst: StreamAccumulator
      generic map (
        DATA_WIDTH              => ELEMENT_WIDTH,
        CTRL_WIDTH              => LSI(8) - ELEMENT_WIDTH,
        IS_SIGNED               => false
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => pad_valid,
        in_ready                => pad_ready,
        in_data                 => pad_acc_all,
        in_skip                 => pad_acc_skip,
        in_clear                => pad_clear,
        out_valid               => oia_acc_valid,
        out_ready               => oia_acc_ready,
        out_data                => oia_acc_all
      );

    oia_last_npad               <= oia_acc_all(                LSI(7));
    oia_count                   <= oia_acc_all(LSI(7)-1 downto LSI(6));
    oia_strobe                  <= oia_acc_all(LSI(6)-1 downto LSI(5));
    oia_last                    <= oia_acc_all(                LSI(4));
    oia_implicit                <= oia_acc_all(                LSI(3));
    oia_ctrl                    <= oia_acc_all(LSI(3)-1 downto LSI(2));
    oia_tag                     <= oia_acc_all(LSI(2)-1 downto LSI(1));
    oia_data                    <= oia_acc_all(LSI(1)-1 downto LSI(0));

    oia_dvalid                  <= '1';

    -- Split the offset to the output command stream
    -- Only enable the cmdOut stream if its strobe is high
    length_split: StreamSync
      generic map (
        NUM_INPUTS => 1,
        NUM_OUTPUTS => 2
      )
      port map (
        clk                     => clk,
        reset                   => reset,

        in_valid(0)             => oia_acc_valid,
        in_ready(0)             => oia_acc_ready,

        out_valid(0)            => cmd_valid,
        out_valid(1)            => oia_valid,

        out_ready(0)            => cmd_ready,
        out_ready(1)            => oia_ready,

        out_enable(0)           => oia_strobe(0),
        out_enable(1)           => '1'
      );


    cmd_firstIdx                <= oia_data;
    cmd_ctrl                    <= oia_ctrl;
    cmd_tag                     <= oia_tag;
    cmd_last                    <= oia_last_npad;

    -- Generate the command output stream
    out_cmd_gen: BufferWriterPreCmdGen
      generic map (
        INDEX_WIDTH             => ELEMENT_WIDTH,
        CMD_CTRL_WIDTH          => CMD_CTRL_WIDTH,
        CMD_TAG_WIDTH           => CMD_TAG_WIDTH
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        cmdIn_valid             => cmd_valid,
        cmdIn_ready             => cmd_ready,
        cmdIn_firstIdx          => cmd_firstIdx,
        cmdIn_implicit          => cmd_implicit,
        cmdIn_ctrl              => cmd_ctrl,
        cmdIn_tag               => cmd_tag,
        cmdIn_last              => cmd_last,
        cmdOut_valid            => cmdOut_valid,
        cmdOut_ready            => cmdOut_ready,
        cmdOut_firstIdx         => cmdOut_firstIdx,
        cmdOut_lastIdx          => cmdOut_lastIdx,
        --cmdOut_implicit         => cmdOut_implicit,
        cmdOut_ctrl             => cmdOut_ctrl,
        cmdOut_tag              => cmdOut_tag
      );

  end generate;

  -- For non-offsets buffers, we don't have to do anything, just forward the
  -- stream and invalidate the offset output forever.
  not_offs_gen: if not(IS_OFFSETS_BUFFER) generate
    pad_ready                   <= oia_ready;
    oia_valid                   <= pad_valid;
    oia_dvalid                  <= '1';
    oia_data                    <= pad_data;
    oia_strobe                  <= pad_strobe;
    oia_count                   <= pad_count;
    oia_last                    <= pad_last;

    cmdOut_valid                <= '0';
  end generate;

  -----------------------------------------------------------------------------
  -- Normalizers
  -----------------------------------------------------------------------------

  -- Only generate normalizers if there can be more than one element per cycle
  norm_gen: if ELEMENT_COUNT_MAX > 1 generate
  
    norm_in_valid   <= oia_valid;
    oia_ready       <= norm_in_ready;
    norm_in_dvalid  <= oia_dvalid;
    norm_in_last    <= oia_last;
    norm_in_count   <= oia_count;
    
    norm_in_connect: for e in 0 to ELEMENT_COUNT_MAX-1 generate
      norm_in_data((e+1)*(ELEMENT_WIDTH+1)-1)                            <= oia_strobe(e);
      norm_in_data((e+1)*(ELEMENT_WIDTH+1)-2 downto e*(ELEMENT_WIDTH+1)) <= oia_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH);
    end generate;

    ---------------------------------------------------------------------------
    -- Data stream maximizer; maximizes the elements per cycle on the output.
    -- count is always ELEMENT_COUNT_MAX unless last is asserted.

    data_normalizer_inst: StreamReshaper
      generic map (
        ELEMENT_WIDTH           => ELEMENT_WIDTH+1,
        IN_COUNT_MAX            => ELEMENT_COUNT_MAX,
        IN_COUNT_WIDTH          => ELEMENT_COUNT_WIDTH,
        OUT_COUNT_MAX           => ELEMENT_COUNT_MAX,
        OUT_COUNT_WIDTH         => ELEMENT_COUNT_WIDTH,
        DIN_BUFFER_DEPTH        => sel(NORM_SLICE, 2, 0)
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        din_valid               => norm_in_valid,
        din_ready               => norm_in_ready,
        din_dvalid              => norm_in_dvalid,
        din_data                => norm_in_data,
        din_count               => norm_in_count,
        din_last                => norm_in_last,
        out_valid               => norm_out_valid,
        out_ready               => norm_out_ready,
        out_dvalid              => norm_out_dvalid,
        out_data                => norm_out_data,
        out_count               => norm_out_count,
        out_last                => norm_out_last
      );

    norm_valid      <= norm_out_valid;
    norm_out_ready  <= norm_ready;
    norm_count      <= norm_out_count;
    norm_last       <= norm_out_last;
    norm_dvalid     <= norm_out_dvalid;

    norm_out_connect: for e in 0 to ELEMENT_COUNT_MAX-1 generate
      norm_strobe(e) <= norm_out_data((e+1)*(ELEMENT_WIDTH+1)-1);
      norm_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) <= norm_out_data((e+1)*(ELEMENT_WIDTH+1)-2 downto e*(ELEMENT_WIDTH+1));
    end generate;

  end generate;

  -- No normalizer is required
  no_norm_gen: if ELEMENT_COUNT_MAX = 1 generate
    oia_ready                   <= norm_ready;
    norm_valid                  <= oia_valid;
    norm_dvalid                 <= '1';
    norm_data                   <= oia_data;
    norm_count                  <= oia_count;
    norm_last                   <= oia_last;
    norm_strobe                 <= oia_strobe;
  end generate;

  -----------------------------------------------------------------------------
  -- Gearboxes
  -----------------------------------------------------------------------------
  -- Reshape (parallelize or serialize) the stream such that it fits in a
  -- single bus word.

  -- Interleave strobes with elements
  gb_in_valid                   <= norm_valid;
  norm_ready                    <= gb_in_ready;
  gb_in_count                   <= norm_count;
  gb_in_last                    <= norm_last;

  gb_connect: for e in 0 to ELEMENT_COUNT_MAX-1 generate
    gb_in_data((e+1)*(ELEMENT_WIDTH+1)-1)                            <= norm_strobe(e);
    gb_in_data((e+1)*(ELEMENT_WIDTH+1)-2 downto e*(ELEMENT_WIDTH+1)) <= norm_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH);
  end generate;

  gearbox_inst: StreamGearbox
    generic map (
      DATA_WIDTH                => ELEMENT_WIDTH+1,
      CTRL_WIDTH                => 0,
      IN_COUNT_MAX              => ELEMENT_COUNT_MAX,
      IN_COUNT_WIDTH            => ELEMENT_COUNT_WIDTH,
      OUT_COUNT_MAX             => BE_COUNT_MAX,
      OUT_COUNT_WIDTH           => BE_COUNT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => gb_in_valid,
      in_ready                  => gb_in_ready,
      in_data                   => gb_in_data,
      in_count                  => gb_in_count,
      in_last                   => gb_in_last,
      out_valid                 => gb_out_valid,
      out_ready                 => gb_out_ready,
      out_data                  => gb_out_data,
      out_count                 => gb_out_count,
      out_last                  => gb_out_last
    );

  shaped_valid  <= gb_out_valid;
  gb_out_ready  <= shaped_ready;
  shaped_count  <= gb_out_count;
  shaped_last   <= gb_out_last;

  shaped_connect: for e in 0 to BE_COUNT_MAX-1 generate
    shaped_strobe(e) <= gb_out_data((e+1)*(ELEMENT_WIDTH+1)-1);
    shaped_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) <= gb_out_data((e+1)*(ELEMENT_WIDTH+1)-2 downto e*(ELEMENT_WIDTH+1));
  end generate;


  -- placeholder for a slice
  int_out_valid <= shaped_valid;
  shaped_ready <= int_out_ready;
  int_out_data <= shaped_data;
  int_out_last <= shaped_last;

  -- Convert the element strobe into a byte strobe
  byte_strobe_proc: process(shaped_strobe) is
  begin
    -- If elements are smaller than bytes, or-reduce the element strobes
    if ELEMENT_WIDTH < STROBE_COVER then
      for I in 0 to BYTE_COUNT-1 loop
        int_out_strobe(I)       <= or_reduce(shaped_strobe((I+1)*ELEMS_PER_BYTE-1 downto I * ELEMS_PER_BYTE));
      end loop;
    end if;
    -- If elements are the same size as bytes, just pass through the element strobes
    if ELEMENT_WIDTH = STROBE_COVER then
      int_out_strobe            <= shaped_strobe;
    end if;
    -- If elements are larger than bytes, duplicate the element strobes
    if ELEMENT_WIDTH > STROBE_COVER then
      for I in 0 to BYTE_COUNT-1 loop
        int_out_strobe(I)       <= shaped_strobe(I / BYTES_PER_ELEM);
      end loop;
    end if;
  end process;

  -- In simulation, make any data unkown if the strobe is low.
  -- This is mainly done for offsets buffers which accumulate unkown and still
  -- generate a valid output.
  --pragma translate off
  process(shaped_data, int_out_strobe) is
  begin
    for I in 0 to BUS_STROBE_WIDTH-1 loop
      if int_out_strobe(I) = '1' then
        int_out_data((I+1)*BUS_STROBE_COVER-1 downto I*BUS_STROBE_COVER)
          <= shaped_data((I+1)*BUS_STROBE_COVER-1 downto I*BUS_STROBE_COVER);
      end if;
      if int_out_strobe(I) /= '1' then
        int_out_data((I+1)*BUS_STROBE_COVER-1 downto I*BUS_STROBE_COVER)
          <= shaped_data((I+1)*BUS_STROBE_COVER-1 downto I*BUS_STROBE_COVER);

        int_out_data((I+1)*BUS_STROBE_COVER-1 downto I*BUS_STROBE_COVER)
          <= (others => 'U');

      end if;
    end loop;
  end process;
  --pragma translate on

  -- TODO: insert some slices

  out_valid                     <= int_out_valid;
  int_out_ready                 <= out_ready;
  out_data                      <= int_out_data;
  out_strobe                    <= int_out_strobe;
  out_last                      <= int_out_last;

end Behavioral;

