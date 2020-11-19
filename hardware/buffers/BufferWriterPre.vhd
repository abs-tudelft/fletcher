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

-- This unit converts a stream of values to a stream of bus words and
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
    CMD_TAG_WIDTH               : natural

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
  -----------------------------------------------------------------------------
  -- This unit is implemented in three stages
  --
  -- 1. Offsets stage : to convert lengths to offsets for Offsets Buffers and
  --                    generate a command for child buffers.
  -- 2. Padding stage : aligns input stream with the minimum bus burst size.
  -- 3. Reshape stage : normalize the output stream to the bus data width.
  -----------------------------------------------------------------------------

  -- Number of elements on a data bus word:
  constant BE_COUNT_MAX         : natural := BUS_DATA_WIDTH / ELEMENT_WIDTH;
  constant BE_COUNT_WIDTH       : natural := log2ceil(BE_COUNT_MAX);
  -- Number of bytes in a data bus word:
  constant BYTE_COUNT           : natural := BUS_DATA_WIDTH / 8;
  -- Bytes per element, clipped to 1.
  constant BYTES_PER_ELEM       : natural := imax(1, ELEMENT_WIDTH / 8);
  -- Elements per byte, resulting in 0 if the elements are larger than a byte.
  constant ELEMS_PER_BYTE       : natural := 8 / ELEMENT_WIDTH;

  -- Number of bits covered by a single strobe bit:
  constant STROBE_COVER         : natural := BUS_DATA_WIDTH / BUS_STROBE_WIDTH;

  -- Prefix summed stream
  signal pss_valid              : std_logic;
  signal pss_ready              : std_logic;
  signal pss_dvalid             : std_logic;
  signal pss_data               : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal pss_count              : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal pss_last               : std_logic;

  -- Padded stream
  signal pad_valid              : std_logic;
  signal pad_ready              : std_logic;
  signal pad_dvalid             : std_logic := '1';
  signal pad_data               : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal pad_strobe             : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
  signal pad_data_strobe        : std_logic_vector(ELEMENT_COUNT_MAX * (ELEMENT_WIDTH + 1) - 1 downto 0);
  signal pad_count              : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal pad_last               : std_logic;
  signal pad_clear              : std_logic;
  signal pad_implicit           : std_logic;
  signal pad_ctrl               : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
  signal pad_tag                : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal pad_last_npad          : std_logic;

  -- Valid/ready signals for padded stream splitter to reshaper and command gen
  signal pad_res_valid          : std_logic;
  signal pad_res_ready          : std_logic;
  signal pad_cmd_valid          : std_logic;
  signal pad_cmd_ready          : std_logic;
  signal pad_cmd_dvalid         : std_logic;

  -- Reshaped stream
  signal res_valid              : std_logic;
  signal res_ready              : std_logic;
  signal res_dvalid             : std_logic;
  signal res_data               : std_logic_vector(BE_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal res_strobe             : std_logic_vector(BE_COUNT_MAX-1 downto 0);
  signal res_byte_strobe        : std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
  signal res_data_strobe        : std_logic_vector(BE_COUNT_MAX * (ELEMENT_WIDTH + 1) - 1 downto 0);
  signal res_count              : std_logic_vector(BE_COUNT_WIDTH-1 downto 0);
  signal res_last               : std_logic;
  signal res_clear              : std_logic;
  signal res_implicit           : std_logic;
  signal res_ctrl               : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
  signal res_tag                : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal res_last_npad          : std_logic;

begin
  -----------------------------------------------------------------------------
  -- Prefix sum stage
  -----------------------------------------------------------------------------
  -- If this BufferWriter is writing to an Offsets Buffer, it must write
  -- offsets rather than lengths. This is done by calculating the prefix sum
  -- of the lengths that appear on the input stream. We do this before
  -- reshaping, because typically, length streams are less utilized than their
  -- child streams, so a designer will typically not require the length input
  -- stream to mach bus data width to obtain close-to-maximum bandwidth.
  -- When ELEMENT_COUNT_MAX is not that high, it becomes easier to time the
  -- prefix sum unit during synthesis, because a running prefix sum over
  -- multiple stream handshakes cannot be pipelined in a way that matches the
  -- input bandwidth. The prefix sum is therefore performed at the input, such
  -- that in most cases it is performed on a less wide stream.

  -- Don't do anything if this is not an Offsets Buffer.
  no_prefix_gen: if not IS_OFFSETS_BUFFER generate
    pss_valid  <= in_valid;
    in_ready   <= pss_ready;
    pss_dvalid <= in_dvalid;
    pss_data   <= in_data;
    pss_count  <= in_count;
    pss_last   <= in_last;
  end generate;

  -- Calculate the running prefix sum if this is an Offsets Buffer.
  prefix_gen: if IS_OFFSETS_BUFFER generate

    -- Instantiate the StreamPrefixSum unit. This unit will reset its running
    -- sum when last is asserted.
    prefix_sum_inst: StreamPrefixSum
      generic map (
        ELEMENT_WIDTH           => ELEMENT_WIDTH,
        COUNT_WIDTH             => ELEMENT_COUNT_WIDTH,
        COUNT_MAX               => ELEMENT_COUNT_MAX
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => in_valid,
        in_ready                => in_ready,
        in_data                 => in_data,
        in_count                => in_count,
        in_dvalid               => in_dvalid,
        in_last                 => in_last,

        out_valid               => pss_valid,
        out_ready               => pss_ready,
        out_data                => pss_data,
        out_count               => pss_count,
        out_dvalid              => pss_dvalid,
        out_last                => pss_last
      );

    -- TODO: insert a slice after prefix sum stage
  end generate;

  -----------------------------------------------------------------------------
  -- Padding stage
  -----------------------------------------------------------------------------
  -- In this stage of the BufferWriter, the incoming values stream is padded in
  -- such a way that it aligns in memory to a minimum sized burst. A write
  -- strobe for each value is also generated.

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

      in_valid                  => pss_valid,
      in_ready                  => pss_ready,
      in_data                   => pss_data,
      in_dvalid                 => pss_dvalid,
      in_count                  => pss_count,
      in_last                   => pss_last,

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

  -- If this is not an Offsets Buffer, just forward the padded stream straight
  -- to the reshape stage.
  no_command_gen: if not IS_OFFSETS_BUFFER generate
    pad_res_valid <= pad_valid;
    pad_ready     <= pad_res_ready;
    cmdOut_valid  <= '0';
  end generate;

  -- If this is an Offsets Buffer, generate a command stream for a child buffer
  -- based on the padded offsets.
  command_gen: if IS_OFFSETS_BUFFER generate

    -- Split the padded input stream into two streams. One stream will go to
    -- the reshaper, and one stream will go the the command generator for the
    -- child buffer.
    pad_split_inst: StreamSync
      generic map (
        NUM_INPUTS              => 1,
        NUM_OUTPUTS             => 2
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid(0)             => pad_valid,
        in_ready(0)             => pad_ready,
        out_valid(0)            => pad_cmd_valid,
        out_valid(1)            => pad_res_valid,
        out_ready(0)            => pad_cmd_ready,
        out_ready(1)            => pad_res_ready
      );

    -- Generate a special dvalid for the command generator. If all strobes are
    -- low, it shouldn't do anything.
    pad_cmd_dvalid <= or_reduce(pad_strobe);

    -- Instantiate the command generator. This unit will generate a command
    -- stream for child buffers based on the offsets generated in the Offsets
    -- stage, when this BufferWriter is an Offsets BufferWriter.
    out_cmd_gen: BufferWriterPreCmdGen
      generic map (
        OFFSET_WIDTH            => ELEMENT_WIDTH,
        COUNT_WIDTH             => ELEMENT_COUNT_WIDTH,
        COUNT_MAX               => ELEMENT_COUNT_MAX,
        CMD_CTRL_WIDTH          => CMD_CTRL_WIDTH,
        CMD_TAG_WIDTH           => CMD_TAG_WIDTH
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => pad_cmd_valid,
        in_ready                => pad_cmd_ready,
        in_offsets              => pad_data,
        in_count                => pad_count,
        in_dvalid               => pad_cmd_dvalid,
        in_last                 => pad_last_npad,
        in_ctrl                 => pad_ctrl,
        in_tag                  => pad_tag,
        cmdOut_valid            => cmdOut_valid,
        cmdOut_ready            => cmdOut_ready,
        cmdOut_firstIdx         => cmdOut_firstIdx,
        cmdOut_lastIdx          => cmdOut_lastIdx,
        --cmdOut_implicit         => cmdOut_implicit,
        cmdOut_ctrl             => cmdOut_ctrl,
        cmdOut_tag              => cmdOut_tag
      );
  end generate;

  -----------------------------------------------------------------------------
  -- Reshape stage
  -----------------------------------------------------------------------------
  -- The padded value stream and write strobes are reshaped to a stream that
  -- fills up a whole bus word per cycle.

  -- Generate input elements for the reshaper. Concatenate the values and the
  -- strobe bit of the padded stream.
  pad_data_strobe_concat_gen: for e in 0 to ELEMENT_COUNT_MAX-1 generate
    pad_data_strobe((e+1)*(ELEMENT_WIDTH+1)-1) <= pad_strobe(e);
    pad_data_strobe((e+1)*(ELEMENT_WIDTH+1)-2 downto e*(ELEMENT_WIDTH+1)) <=
      pad_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH);
  end generate;

  -- This reshaper will ensure the output elements exactly fit into a bus word.
  reshaper_inst: StreamReshaper
    generic map (
      ELEMENT_WIDTH           => ELEMENT_WIDTH+1, -- values plus strobe
      IN_COUNT_MAX            => ELEMENT_COUNT_MAX,
      IN_COUNT_WIDTH          => ELEMENT_COUNT_WIDTH,
      OUT_COUNT_MAX           => BE_COUNT_MAX,
      OUT_COUNT_WIDTH         => BE_COUNT_WIDTH
    )
    port map (
      clk                     => clk,
      reset                   => reset,
      din_valid               => pad_res_valid,
      din_ready               => pad_res_ready,
      din_dvalid              => pad_dvalid,
      din_data                => pad_data_strobe,
      din_count               => pad_count,
      din_last                => pad_last,
      out_valid               => res_valid,
      out_ready               => res_ready,
      out_dvalid              => res_dvalid,
      out_data                => res_data_strobe,
      out_count               => res_count,
      out_last                => res_last
    );

  -- Unconcatenate the values and strobe bit of the reshaped stream.
  res_data_strobe_concat_gen: for e in 0 to BE_COUNT_MAX-1 generate
    res_strobe(e) <= res_data_strobe((e+1)*(ELEMENT_WIDTH+1)-1);
    res_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) <=
      res_data_strobe((e+1)*(ELEMENT_WIDTH+1)-2 downto e*(ELEMENT_WIDTH+1));
  end generate;

  -- Convert the reshaped value strobes into a byte strobes
  byte_strobe_proc: process(res_strobe) is
  begin
    -- If elements are smaller than bytes, or-reduce the element strobes
    if ELEMENT_WIDTH < STROBE_COVER then
      for I in 0 to BYTE_COUNT-1 loop
        res_byte_strobe(I)  <= or_reduce(res_strobe((I+1)*ELEMS_PER_BYTE-1 downto I * ELEMS_PER_BYTE));
      end loop;
    end if;
    -- If elements are the same size as bytes, just pass through the element strobes
    if ELEMENT_WIDTH = STROBE_COVER then
      res_byte_strobe       <= res_strobe;
    end if;
    -- If elements are larger than bytes, duplicate the element strobes
    if ELEMENT_WIDTH > STROBE_COVER then
      for I in 0 to BYTE_COUNT-1 loop
        res_byte_strobe(I)  <= res_strobe(I / BYTES_PER_ELEM);
      end loop;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Output
  -----------------------------------------------------------------------------
  -- Connect the reshaped result to the output stream.

  out_valid  <= res_valid;
  res_ready  <= out_ready;
  out_data   <= res_data;
  out_strobe <= res_byte_strobe;
  out_last   <= res_last;

end Behavioral;
