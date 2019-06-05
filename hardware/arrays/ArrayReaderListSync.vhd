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
use work.Array_pkg.all;
use work.UtilInt_pkg.all;
use work.UtilMisc_pkg.all;

entity ArrayReaderListSync is
  generic (

    -- Width of a data element.
    ELEMENT_WIDTH               : natural;

    -- Width of the list length vector.
    LENGTH_WIDTH                : natural;

    -- Maximum number of elements per clock.
    COUNT_MAX                   : natural := 1;

    -- The number of bits in the count vectors. This must be at least
    -- ceil(log2(COUNT_MAX)) and must be at least 1. If COUNT_MAX is a power of
    -- two and this value equals log2(COUNT_MAX), a zero count implies that all
    -- entries are valid (i.e., there is an implicit '1' bit in front).
    COUNT_WIDTH                 : natural := 1;

    -- Whether a register slice should be inserted in the data element input
    -- stream.
    DATA_IN_SLICE               : boolean := false;

    -- Whether a register slice should be inserted in the length input stream.
    LEN_IN_SLICE                : boolean := false;

    -- Whether a register slice should be inserted in the output stream.
    OUT_SLICE                   : boolean := true

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- List length input stream.
    inl_valid                   : in  std_logic;
    inl_ready                   : out std_logic;
    inl_length                  : in  std_logic_vector(LENGTH_WIDTH-1 downto 0);

    -- List element input stream.
    ind_valid                   : in  std_logic;
    ind_ready                   : out std_logic;
    ind_data                    : in  std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    ind_count                   : in  std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));

    -- List output stream. last indicates whether this transfer contains the
    -- last set of list elements for the current list. dvalid indicates whether
    -- data is valid (in addition to the handshake); it is always high, unless
    -- the list is empty. data represents list data elements, starting from the
    -- LSB. count indicates how many list data elements are valid. The
    -- following things are guaranteed:
    --  - When multiple elements are returned simultaneously, these elements
    --    belong to the same list.
    --  - This unit always outputs the maximum amount of items possible. Thus,
    --    count != COUNT_MAX only if not enough elements remain for the current
    --    list. In other words, count != COUNT_MAX implies last = '1'.
    --  - Zero-length lists result in one beat at the output, with:
    --     * last = '1'
    --     * dvalid = '0'
    --     * data = undefined
    --     * count = 0, although this is only significant if
    --       COUNT_WIDTH >= ceil(log2(COUNT_MAX+1)), because otherwise 0 would
    --       imply all data elements are valid, requiring dvalid for
    --       disambiguation.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_last                    : out std_logic;
    out_dvalid                  : out std_logic;
    out_data                    : out std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(COUNT_WIDTH-1 downto 0)

  );
end ArrayReaderListSync;

architecture Behavioral of ArrayReaderListSync is

  -- Width of the requested count vector.
  constant REQ_COUNT_WIDTH      : natural := log2ceil(COUNT_MAX+1);

  -- Decoder output handshake.
  signal ctrl_valid             : std_logic;
  signal ctrl_ready             : std_logic;

  -- Serialized vectors for the input buffer.
  constant DII : nat_array := cumulative((
    1 => ind_data'length,
    0 => ind_count'length
  ));
  signal ind_sData              : std_logic_vector(DII(DII'high)-1 downto 0);
  signal indB_sData             : std_logic_vector(DII(DII'high)-1 downto 0);

  -- Element input stream after the optional buffer.
  signal indB_valid             : std_logic;
  signal indB_ready             : std_logic;
  signal indB_data              : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal indB_count             : std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));

  -- Normalizer output handshake.
  signal norm_valid             : std_logic;
  signal norm_ready             : std_logic;

  -- Synchronized output stream before the optional buffer.
  signal sync_valid             : std_logic;
  signal sync_ready             : std_logic;
  signal sync_req_count         : std_logic_vector(REQ_COUNT_WIDTH-1 downto 0);
  signal sync_last              : std_logic;
  signal sync_dvalid            : std_logic;
  signal sync_data              : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal sync_count             : std_logic_vector(COUNT_WIDTH-1 downto 0);

  -- Serialized vectors for the output buffer.
  constant DOI : nat_array := cumulative((
    3 => 1, -- sync_last
    2 => 1, -- sync_dvalid
    1 => sync_data'length,
    0 => sync_count'length
  ));
  signal sync_sData             : std_logic_vector(DOI(DOI'high)-1 downto 0);
  signal out_sData              : std_logic_vector(DOI(DOI'high)-1 downto 0);

begin

  -- Decode the length input stream into a stream of element counts and last
  -- flags, as these things are determined only by the list length.
  decoder_inst: ArrayReaderListSyncDecoder
    generic map (
      LENGTH_WIDTH              => LENGTH_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => REQ_COUNT_WIDTH,
      LEN_IN_SLICE              => LEN_IN_SLICE
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      inl_valid                 => inl_valid,
      inl_ready                 => inl_ready,
      inl_length                => inl_length,

      ctrl_valid                => ctrl_valid,
      ctrl_ready                => ctrl_ready,
      ctrl_last                 => sync_last,
      ctrl_count                => sync_req_count
    );

  -- Serialize the element input stream for the optional register slice.
  ind_sData(DII(2)-1 downto DII(1)) <= ind_data;
  ind_sData(DII(1)-1 downto DII(0)) <= ind_count;

  -- Generate an optional register slice in the element input stream.
  data_in_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                 => sel(DATA_IN_SLICE, 2, 0),
      DATA_WIDTH                => DII(DII'high)
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => ind_valid,
      in_ready                  => ind_ready,
      in_data                   => ind_sData,

      out_valid                 => indB_valid,
      out_ready                 => indB_ready,
      out_data                  => indB_sData
    );

  -- Deserialize the element input stream from the optional register slice.
  indB_data   <= indB_sData(DII(2)-1 downto DII(1));
  indB_count  <= indB_sData(DII(1)-1 downto DII(0));

  -- Normalize the element input stream such that each transfer at the output
  -- has exactly the item count requested by the list length decoder.
  normalizer_inst: StreamNormalizer
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH,
      REQ_COUNT_WIDTH           => REQ_COUNT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => indB_valid,
      in_ready                  => indB_ready,
      in_data                   => indB_data,
      in_count                  => indB_count,

      req_count                 => sync_req_count,

      out_valid                 => norm_valid,
      out_ready                 => norm_ready,
      out_dvalid                => sync_dvalid,
      out_data                  => sync_data,
      out_count                 => sync_count
    );

  -- Synchronize the decoder and normalizer streams.
  sync_inst: StreamSync
    generic map (
      NUM_INPUTS                => 2,
      NUM_OUTPUTS               => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid(1)               => ctrl_valid,
      in_valid(0)               => norm_valid,
      in_ready(1)               => ctrl_ready,
      in_ready(0)               => norm_ready,

      out_valid(0)              => sync_valid,
      out_ready(0)              => sync_ready
    );

  -- Serialize the output stream for the optional register slice.
  sync_sData(                DOI(3)) <= sync_last;
  sync_sData(                DOI(2)) <= sync_dvalid;
  sync_sData(DOI(2)-1 downto DOI(1)) <= sync_data;
  sync_sData(DOI(1)-1 downto DOI(0)) <= sync_count;

  -- Generate an optional register slice in the output stream.
  out_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                 => sel(OUT_SLICE, 2, 0),
      DATA_WIDTH                => DOI(DOI'high)
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => sync_valid,
      in_ready                  => sync_ready,
      in_data                   => sync_sData,

      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_data                  => out_sData
    );

  -- Deserialize the element input stream from the optional register slice.
  out_last   <= out_sData(                DOI(3));
  out_dvalid <= out_sData(                DOI(2));
  out_data   <= out_sData(DOI(2)-1 downto DOI(1));
  out_count  <= out_sData(DOI(1)-1 downto DOI(0));

end Behavioral;

