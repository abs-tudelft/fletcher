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

entity BufferReaderPost is
  generic (

    ---------------------------------------------------------------------------
    -- Signal widths and functional configuration
    ---------------------------------------------------------------------------
    -- Buffer element width in bits.
    ELEMENT_WIDTH               : natural;

    -- Whether this is a normal buffer or an offsets buffer.
    IS_OFFSETS_BUFFER           : boolean;

    -- Maximum amount of elements per FIFO entry.
    ELEMENT_FIFO_COUNT_MAX      : natural;

    -- Width of the FIFO element count vector. Should equal
    -- max(1, ceil(log2(FIFO_COUNT_MAX)))
    ELEMENT_FIFO_COUNT_WIDTH    : natural;

    -- Maximum number of elements returned per cycle. When more than 1,
    -- elements are returned LSB-aligned and LSB-first, along with a count
    -- field that indicates how many elements are valid. A best-effort approach
    -- is utilized; no guarantees are made about how many elements are actually
    -- returned per cycle. This feature is not supported for offsets buffers.
    ELEMENT_COUNT_MAX           : natural;

    -- Width of the vector indicating the number of valid elements. Must be at
    -- least 1 to prevent null ranges.
    ELEMENT_COUNT_WIDTH         : natural;

    ---------------------------------------------------------------------------
    -- Timing configuration
    ---------------------------------------------------------------------------
    -- Whether a register slice should be inserted between the FIFO and the
    -- post-processing logic (differential encoder for offsets buffers and
    -- optional serialization).
    FIFO2POST_SLICE             : boolean;

    -- Whether a register slice should be inserted into the output stream.
    OUT_SLICE                   : boolean

  );
  port (

    ---------------------------------------------------------------------------
    -- Clock domains
    ---------------------------------------------------------------------------
    -- Rising-edge sensitive clock and active-high synchronous reset.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    ---------------------------------------------------------------------------
    -- Input stream
    ---------------------------------------------------------------------------
    -- Data stream from the FIFO. fifo_data contains FIFO_COUNT_MAX elements,
    -- each ELEMENT_WIDTH in size. The first element is LSB aligned.
    -- fifoOut_count indicates how many elements are valid. There is always at
    -- least 1 element valid; the MSB of this signal is 1 implicitly when count
    -- is zero (that is, if count is "00", all "100" = 4 elements are valid).
    -- fifoOut_last indicates that the last word for the current command is
    -- present in this bundle.
    fifoOut_valid               : in  std_logic;
    fifoOut_ready               : out std_logic;
    fifoOut_data                : in  std_logic_vector(ELEMENT_FIFO_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    fifoOut_count               : in  std_logic_vector(ELEMENT_FIFO_COUNT_WIDTH-1 downto 0);
    fifoOut_last                : in  std_logic;

    ---------------------------------------------------------------------------
    -- Output stream
    ---------------------------------------------------------------------------
    -- Buffer element stream output. element contains the data element for
    -- normal buffers and the length for offsets buffers. last is asserted when
    -- this is the last element for the current command.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    out_last                    : out std_logic

  );
end BufferReaderPost;

architecture Behavioral of BufferReaderPost is

  -- FIFO stream after the optional register slice.
  signal fifoOutB_valid         : std_logic;
  signal fifoOutB_ready         : std_logic;
  signal fifoOutB_data          : std_logic_vector(ELEMENT_FIFO_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal fifoOutB_count         : std_logic_vector(ELEMENT_FIFO_COUNT_WIDTH-1 downto 0);
  signal fifoOutB_last          : std_logic;

  -- Serialized stream.
  signal outS_valid             : std_logic;
  signal outS_ready             : std_logic;
  signal outS_data              : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal outS_count             : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal outS_last              : std_logic;

  -- Serialized and differentially-encoded (if required) stream.
  signal outD_valid             : std_logic;
  signal outD_ready             : std_logic;
  signal outD_data              : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal outD_count             : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal outD_last              : std_logic;

  -- FIFO output stream serialization indices.
  constant FOI : nat_array := cumulative((
    2 => fifoOut_data'length,
    1 => fifoOut_count'length,
    0 => 1 -- fifoOut_last
  ));

  signal fifoOut_sData          : std_logic_vector(FOI(FOI'high)-1 downto 0);
  signal fifoOutB_sData         : std_logic_vector(FOI(FOI'high)-1 downto 0);

  -- Element output stream serialization indices.
  constant IOI : nat_array := cumulative((
    2 => out_data'length,
    1 => out_count'length,
    0 => 1 -- out_last
  ));

  signal outD_sData             : std_logic_vector(IOI(IOI'high)-1 downto 0);
  signal out_sData              : std_logic_vector(IOI(IOI'high)-1 downto 0);

begin

  -- Generate an optional register slice between FIFO and the gearbox and
  -- optional differential encoder.
  fifo_to_post_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(FIFO2POST_SLICE, 2, 0),
      DATA_WIDTH                        => FOI(FOI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => fifoOut_valid,
      in_ready                          => fifoOut_ready,
      in_data                           => fifoOut_sData,

      out_valid                         => fifoOutB_valid,
      out_ready                         => fifoOutB_ready,
      out_data                          => fifoOutB_sData
    );

  fifoOut_sData(FOI(3)-1 downto FOI(2)) <= fifoOut_data;
  fifoOut_sData(FOI(2)-1 downto FOI(1)) <= fifoOut_count;
  fifoOut_sData(FOI(0))                 <= fifoOut_last;

  fifoOutB_data                         <= fifoOutB_sData(FOI(3)-1 downto FOI(2));
  fifoOutB_count                        <= fifoOutB_sData(FOI(2)-1 downto FOI(1));
  fifoOutB_last                         <= fifoOutB_sData(FOI(0));

  -- Gearbox between FIFO and output stream.
  post_gearbox_inst: StreamGearbox
    generic map (
      ELEMENT_WIDTH                     => ELEMENT_WIDTH,
      IN_COUNT_MAX                      => ELEMENT_FIFO_COUNT_MAX,
      IN_COUNT_WIDTH                    => ELEMENT_FIFO_COUNT_WIDTH,
      OUT_COUNT_MAX                     => ELEMENT_COUNT_MAX,
      OUT_COUNT_WIDTH                   => ELEMENT_COUNT_WIDTH
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => fifoOutB_valid,
      in_ready                          => fifoOutB_ready,
      in_data                           => fifoOutB_data,
      in_count                          => fifoOutB_count,
      in_last                           => fifoOutB_last,

      out_valid                         => outS_valid,
      out_ready                         => outS_ready,
      out_data                          => outS_data,
      out_count                         => outS_count,
      out_last                          => outS_last
    );

  -- Connect the outS and outD streams directly for normal buffers.
  normal_buffer_gen: if not IS_OFFSETS_BUFFER generate
  begin
    outD_valid  <= outS_valid;
    outS_ready  <= outD_ready;
    outD_data   <= outS_data;
    outD_count  <= outS_count;
    outD_last   <= outS_last;
  end generate;

  -- Differentially encode the stream for offsets buffers to turn offset pairs
  -- into lengths.
  offsets_buffer_gen: if IS_OFFSETS_BUFFER generate

    -- Previous entry storage.
    signal prev_valid : std_logic;
    signal prev_data  : std_logic_vector(ELEMENT_WIDTH-1 downto 0);

  begin

    -- Differential encoding is only supported for one element per clock. The
    -- code below will not synthesize correctly due to incorrect vector widths
    -- if this assertion fails.
    assert ELEMENT_COUNT_MAX = 1
      report "Offsets buffers currently do not support multiple elements per cycle."
      severity FAILURE;

    -- Save the previous entry.
    prev_data_proc: process (clk) is
    begin
      if rising_edge(clk) then

        if outS_valid = '1' and outS_ready = '1' then
          prev_valid <= not outS_last;
          prev_data <= outS_data;
        end if;

        if reset = '1' then
          prev_valid <= '0';
          -- pragma translate_off
          prev_data <= (others => 'U');
          -- pragma translate_on
        end if;

      end if;
    end process;

    -- Gobble up the first entry in every burst.
    outD_valid <= outS_valid and prev_valid;
    outS_ready <= outD_ready or not prev_valid;

    -- Differentially encode the data.
    outD_data <= std_logic_vector(unsigned(outS_data) - unsigned(prev_data));

    -- Forward the "last" flag without modification.
    outD_last   <= outS_last;

  end generate;

  -- Generate an optional register slice in the output stream.
  out_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(OUT_SLICE, 2, 0),
      DATA_WIDTH                        => IOI(IOI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => outD_valid,
      in_ready                          => outD_ready,
      in_data                           => outD_sdata,

      out_valid                         => out_valid,
      out_ready                         => out_ready,
      out_data                          => out_sData
    );

  outD_sData(IOI(3)-1 downto IOI(2))    <= outD_data;
  outD_sData(IOI(2)-1 downto IOI(1))    <= outD_count;
  outD_sData(IOI(0))                    <= outD_last;

  out_data                              <= out_sData(IOI(3)-1 downto IOI(2));
  out_count                             <= out_sData(IOI(2)-1 downto IOI(1));
  out_last                              <= out_sData(IOI(0));

end Behavioral;

