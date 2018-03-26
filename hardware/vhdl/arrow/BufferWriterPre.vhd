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
use work.Streams.all;
use work.Utils.all;
use work.Arrow.all;

-- This unit converts a stream of elements to a stream of bus words and write strobes.
-- Depending
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

    -- Number of beats in a burst step.
    BUS_BURST_STEP_LEN          : natural;

    -- Whether this is a normal buffer or an index buffer.
    IS_INDEX_BUFFER             : boolean;

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

    -- Optional synchronizer for the data and write strobe streams
    --SYNC_OUTPUT                 : boolean

  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    cmdIn_valid                 : in  std_logic;
    cmdIn_ready                 : out std_logic;
    cmdIn_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_implicit              : in  std_logic;

    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_dvalid                   : in  std_logic;
    in_data                     : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    in_last                     : in  std_logic;

    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    out_strobe                  : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
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

  signal pad_data_ready         : std_logic;
  signal pad_strobe_ready       : std_logic;
  signal pad_data_valid         : std_logic;
  signal pad_strobe_valid       : std_logic;

  -- Padded stream
  signal pad_valid              : std_logic;
  signal pad_ready              : std_logic;
  signal pad_dvalid             : std_logic;
  signal pad_data               : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal pad_strobe             : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
  signal pad_count              : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal pad_last               : std_logic;

  -- Normalized stream
  signal norm_valid             : std_logic;
  signal norm_ready             : std_logic;
  signal norm_dvalid            : std_logic;
  signal norm_data              : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal norm_count             : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal norm_last              : std_logic;

  -- Normalized write strobe stream
  signal strobe_norm_valid      : std_logic;
  signal strobe_norm_ready      : std_logic;
  signal strobe_norm_dvalid     : std_logic;
  signal strobe_norm_data       : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
  signal strobe_norm_count      : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal strobe_norm_last       : std_logic;

  -- Reshaped data stream
  signal shaped_valid           : std_logic;
  signal shaped_ready           : std_logic := '1';
  signal shaped_data            : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal shaped_count           : std_logic_vector(BE_COUNT_WIDTH-1 downto 0);
  signal shaped_last            : std_logic;

  -- Reshaped write strobe stream
  signal strobe_shaped_valid    : std_logic;
  signal strobe_shaped_ready    : std_logic := '1';
  signal strobe_shaped_data     : std_logic_vector(BE_COUNT_MAX-1 downto 0);
  signal strobe_shaped_count    : std_logic_vector(BE_COUNT_WIDTH-1 downto 0);
  signal strobe_shaped_last     : std_logic;

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
      IS_INDEX_BUFFER           => IS_INDEX_BUFFER,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      ELEMENT_COUNT_MAX         => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => ELEMENT_COUNT_WIDTH,
      CMD_CTRL_WIDTH            => CMD_CTRL_WIDTH,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      cmdIn_valid               => cmdIn_valid,
      cmdIn_ready               => cmdIn_ready,
      cmdIn_firstIdx            => cmdIn_firstIdx,
      cmdIn_lastIdx             => cmdIn_lastIdx,
      cmdIn_implicit            => cmdIn_implicit,

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
      out_last                  => pad_last
    );

  -----------------------------------------------------------------------------
  -- Normalizers
  -----------------------------------------------------------------------------
  -- The padded stream is split into a data and a write strobe stream and
  -- normalized. That is, the output of the normalizers always contains
  -- the maximum number of elements per cycle
  
  pad_split_inst: StreamSync
    generic map (
      NUM_INPUTS => 1,
      NUM_OUTPUTS => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid(0)               => pad_valid,
      in_ready(0)               => pad_ready,
      out_valid(0)              => pad_data_valid,
      out_valid(1)              => pad_strobe_valid,
      out_ready(0)              => pad_data_ready,
      out_ready(1)              => pad_strobe_ready
    );

  -- Only generate normalizers if there can be more than one element per cycle
  norm_gen: if ELEMENT_COUNT_MAX > 1 generate
    data_normalizer_inst: StreamNormalizer
      generic map (
        ELEMENT_WIDTH           => ELEMENT_WIDTH,
        COUNT_MAX               => ELEMENT_COUNT_MAX,
        COUNT_WIDTH             => ELEMENT_COUNT_WIDTH,
        REQ_COUNT_WIDTH         => ELEMENT_COUNT_WIDTH+1
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => pad_data_valid,
        in_ready                => pad_data_ready,
        in_dvalid               => '1',
        in_data                 => pad_data,
        in_count                => pad_count,
        in_last                 => pad_last,
        req_count               => slv(to_unsigned(ELEMENT_COUNT_MAX, ELEMENT_COUNT_WIDTH+1)),
        out_valid               => norm_valid,
        out_ready               => norm_ready,
        out_dvalid              => norm_dvalid,
        out_data                => norm_data,
        out_count               => norm_count,
        out_last                => norm_last
      );

    strobe_normalizer_inst: StreamNormalizer
      generic map (
        ELEMENT_WIDTH           => 1,
        COUNT_MAX               => ELEMENT_COUNT_MAX,
        COUNT_WIDTH             => ELEMENT_COUNT_WIDTH,
        REQ_COUNT_WIDTH         => ELEMENT_COUNT_WIDTH+1
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => pad_strobe_valid,
        in_ready                => pad_strobe_ready,
        in_dvalid               => '1',
        in_data                 => pad_strobe,
        in_count                => pad_count,
        in_last                 => pad_last,
        req_count               => slv(to_unsigned(ELEMENT_COUNT_MAX, ELEMENT_COUNT_WIDTH+1)),
        out_valid               => strobe_norm_valid,
        out_ready               => strobe_norm_ready,
        out_dvalid              => strobe_norm_dvalid,
        out_data                => strobe_norm_data,
        out_count               => strobe_norm_count,
        out_last                => strobe_norm_last
      );
  end generate;
  
  -- No normalizer is required
  no_norm_gen: if ELEMENT_COUNT_MAX = 1 generate
    pad_data_ready              <= norm_ready;
    norm_valid                  <= pad_data_valid;
    norm_dvalid                 <= '1';
    norm_data                   <= pad_data;
    norm_count                  <= pad_count;
    norm_last                   <= pad_last;
    
    pad_strobe_ready            <= strobe_norm_ready;
    strobe_norm_valid           <= pad_strobe_valid;
    strobe_norm_dvalid          <= '1';
    strobe_norm_data            <= pad_strobe;
    strobe_norm_count           <= pad_count;
    strobe_norm_last            <= pad_last;
  end generate;

  -----------------------------------------------------------------------------
  -- Gearboxes
  -----------------------------------------------------------------------------
  -- Here the streams are reshaped (parallelized or serialized) such that they
  -- fit in a single bus word

  data_gearbox_inst: StreamGearbox
    generic map (
      DATA_WIDTH                => ELEMENT_WIDTH,
      CTRL_WIDTH                => 0,
      IN_COUNT_MAX              => ELEMENT_COUNT_MAX,
      IN_COUNT_WIDTH            => ELEMENT_COUNT_WIDTH,
      OUT_COUNT_MAX             => BE_COUNT_MAX,
      OUT_COUNT_WIDTH           => BE_COUNT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => norm_valid,
      in_ready                  => norm_ready,
      in_data                   => norm_data,
      in_count                  => norm_count,
      in_last                   => norm_last,
      out_valid                 => shaped_valid,
      out_ready                 => shaped_ready,
      out_data                  => shaped_data,
      out_count                 => shaped_count,
      out_last                  => shaped_last
    );

  strobe_gearbox_inst: StreamGearbox
    generic map (
      DATA_WIDTH                => 1,
      CTRL_WIDTH                => 0,
      IN_COUNT_MAX              => ELEMENT_COUNT_MAX,
      IN_COUNT_WIDTH            => ELEMENT_COUNT_WIDTH,
      OUT_COUNT_MAX             => BE_COUNT_MAX,
      OUT_COUNT_WIDTH           => BE_COUNT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => strobe_norm_valid,
      in_ready                  => strobe_norm_ready,
      in_data                   => strobe_norm_data,
      in_count                  => strobe_norm_count,
      in_last                   => strobe_norm_last,
      out_valid                 => strobe_shaped_valid,
      out_ready                 => strobe_shaped_ready,
      out_data                  => strobe_shaped_data,
      out_count                 => strobe_shaped_count,
      out_last                  => strobe_shaped_last
    );

    -- It -shouldn't- be required to synchronize the streams as the control 
    -- characteristics and backpressure of the gearboxes are exactly the same.
    
    --sync_gen: if SYNC_OUTPUT generate
    --end generate;

    strobe_shaped_ready         <= out_ready;
    shaped_ready                <= out_ready;

    out_valid                   <= shaped_valid and strobe_shaped_valid;
    out_data                    <= shaped_data;
    out_last                    <= shaped_last and strobe_shaped_last;

    -- Convert the element strobe into a byte strobe
    byte_strobe_proc: process(strobe_shaped_data)
    begin
      -- If elements are smaller than bytes, or-reduce the element strobes
      if ELEMENT_WIDTH < 8 then
        for I in 0 to BYTE_COUNT-1 loop
          out_strobe(I)         <= or_reduce(strobe_shaped_data((I+1)*ELEMS_PER_BYTE-1 downto I * ELEMS_PER_BYTE));
        end loop;
      end if;
      -- If elements are the same size as bytes, just pass through the element strobes
      if ELEMENT_WIDTH = 8 then
        out_strobe              <= strobe_shaped_data;
      end if;
      -- If elements are larger than bytes, duplicate the element strobes
      if ELEMENT_WIDTH > 8 then
        for I in 0 to BYTE_COUNT-1 loop
          out_strobe(I)         <= strobe_shaped_data(I / BYTES_PER_ELEM);
        end loop;
      end if;
    end process;


end Behavioral;

