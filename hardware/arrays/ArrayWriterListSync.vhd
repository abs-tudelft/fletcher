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
use work.Arrays.all;

entity ArrayWriterListSync is
  generic (

    ---------------------------------------------------------------------------
    -- I/O streams
    ---------------------------------------------------------------------------
    -- Width of a data element.
    ELEMENT_WIDTH               : natural := 32;

    -- Width of the list length vector.
    LENGTH_WIDTH                : natural := 32;

    -- Maximum number of elements per clock.
    COUNT_MAX                   : natural := 1;

    -- The number of bits in the count vectors. This must be at least
    -- ceil(log2(COUNT_MAX)) and must be at least 1. If COUNT_MAX is a power of
    -- two and this value equals log2(COUNT_MAX), a zero count implies that all
    -- entries are valid (i.e., there is an implicit '1' bit in front).
    COUNT_WIDTH                 : natural := 1;

    ---------------------------------------------------------------------------
    -- Functional modifiers
    ---------------------------------------------------------------------------
    -- Whether to generate the length stream by the last signal of the element
    -- stream. If this is set to true, the inl_length data is don't care and
    -- outl_length will be generated based on the last signal of the element
    -- stream. If this is set to false, the outl_length data is equal to
    -- inl_length. Note that it is always necessary to generate a handshake
    -- on this stream for every list, and that its last signal will be used
    -- to terminate the offsets buffer and potentially the values buffer in case
    -- ELEM_LAST_FROM_LENGTH is true.
    GENERATE_LENGTH             : boolean := true;

    -- Whether to use the length stream to normalize the element stream output.
    -- This breaks up any element stream transfers that cross a list boundary.
    -- Can only be enabled when GENERATE_LENGTH = false. If this is set to
    -- false, the input element stream must not cross list boundaries. In other
    -- words, if there are only 2 more elements to stream in, and last is high,
    -- on the element stream, the logical count of elements cannot exceed 2 in
    -- that last cycle.
    NORMALIZE                   : boolean := false;

    -- Whether to only output last on the element stream when the input length
    -- stream last is asserted as well. Set this to false only if you want to
    -- terminate the command after every list for some reason (like sharing one
    -- BufferWriters with multiple index BufferWriters).
    ELEM_LAST_FROM_LENGTH       : boolean := true;

    -- Note: the combination of NORMALIZE=true and ELEM_LAST_FROM_LENGTH=false
    -- should probably not be used, but in case you want to save some resources
    -- it might be used to share a single values BufferWriter over multiple
    -- index BufferWriter.
    -- Note: set the latter three settings to false to make the length and 
    -- element stream completely disjoint.

    ---------------------------------------------------------------------------
    -- Optional slices
    ---------------------------------------------------------------------------
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
    inl_last                    : in  std_logic;

    -- List element input stream.
    ine_valid                   : in  std_logic;
    ine_ready                   : out std_logic;
    ine_dvalid                  : in  std_logic;
    ine_data                    : in  std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    ine_count                   : in  std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
    ine_last                    : in  std_logic;

    -- List length output stream.
    outl_valid                  : out std_logic;
    outl_ready                  : in  std_logic;
    outl_length                 : out std_logic_vector(LENGTH_WIDTH-1 downto 0);
    outl_last                   : out std_logic;

    -- Element output stream.
    oute_valid                  : out std_logic;
    oute_ready                  : in  std_logic;
    oute_last                   : out std_logic;
    oute_dvalid                 : out std_logic;
    oute_data                   : out std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    oute_count                  : out std_logic_vector(COUNT_WIDTH-1 downto 0)

  );
end ArrayWriterListSync;

architecture Behavioral of ArrayWriterListSync is

  -- Width of the requested count vector.
  constant REQ_COUNT_WIDTH      : natural := log2ceil(COUNT_MAX+1);

  -- Internal length output
  signal int_len_valid          : std_logic;
  signal int_len_ready          : std_logic;
  signal int_len_length         : std_logic_vector(LENGTH_WIDTH-1 downto 0);
  signal int_len_last           : std_logic;

  -- Internal element output
  signal int_dat_valid          : std_logic;
  signal int_dat_ready          : std_logic;
  signal int_dat_dvalid         : std_logic;
  signal int_dat_last           : std_logic;
  signal int_dat_data           : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal int_dat_count          : std_logic_vector(COUNT_WIDTH-1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Generic checking in simulation
  -----------------------------------------------------------------------------
  --pragma translate off
  assert not(GENERATE_LENGTH and NORMALIZE)
    report "GENERATE_LENGTH and NORMALIZE cannot be enabled at the same time"
    severity failure;
  --pragma translate on

  -----------------------------------------------------------------------------
  -- External length and element stream
  -----------------------------------------------------------------------------
  ext_len_elem: if not(GENERATE_LENGTH) and not(NORMALIZE) generate
    -- Internal length output
    int_len_valid               <= inl_valid;
    inl_ready                   <= int_len_ready;
    int_len_length              <= inl_length;
    int_len_last                <= inl_last;

    -- Internal element output
    int_dat_valid               <= ine_valid;
    ine_ready                   <= int_dat_ready;
    int_dat_dvalid              <= ine_dvalid;
    int_dat_last                <= ine_last;
    int_dat_data                <= ine_data;
    int_dat_count               <= ine_count;
  end generate;


  -----------------------------------------------------------------------------
  -- Generated length stream
  -----------------------------------------------------------------------------
  -- We do not want to use the lengths in the length stream input. Thus, we
  -- must determine the length stream based on the element stream and its last
  -- signal. A StreamElementCounter is used for this.
  generate_length_gen: if GENERATE_LENGTH generate
    -- Input to the element counter
    signal eci_valid            : std_logic;
    signal eci_ready            : std_logic;
    signal eci_last             : std_logic;
    signal eci_count            : std_logic_vector(COUNT_WIDTH-1 downto 0);
    signal eci_dvalid           : std_logic;

    signal eco_valid            : std_logic;
    signal eco_ready            : std_logic;
    signal eco_last             : std_logic;
    signal eco_count            : std_logic_vector(LENGTH_WIDTH-1 downto 0);
  begin

    -- Split up the element stream to go to:
    -- * The element counter
    -- * The output
    values_split_inst: StreamSync
      generic map (
        NUM_INPUTS => 1,
        NUM_OUTPUTS => 2
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid(0)             => ine_valid,
        in_ready(0)             => ine_ready,
        out_valid(0)            => eci_valid,
        out_valid(1)            => int_dat_valid,
        out_ready(0)            => eci_ready,
        out_ready(1)            => int_dat_ready
      );

    eci_count                   <= ine_count;
    eci_dvalid                  <= ine_dvalid;
    eci_last                    <= ine_last;

    int_dat_dvalid              <= ine_dvalid;
    int_dat_data                <= ine_data;
    int_dat_count               <= ine_count;
    int_dat_last                <= ine_last;

    -- Count the number of elements in the input stream to generate the length
    -- stream.
    element_count_inst: StreamElementCounter
      generic map (
        IN_COUNT_WIDTH          => COUNT_WIDTH,
        IN_COUNT_MAX            => COUNT_MAX,
        OUT_COUNT_WIDTH         => LENGTH_WIDTH,
        OUT_COUNT_MAX           => 2**(LENGTH_WIDTH-1)-1
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => eci_valid,
        in_ready                => eci_ready,
        in_last                 => eci_last,
        in_count                => eci_count,
        in_dvalid               => eci_dvalid,
        out_valid               => eco_valid,
        out_ready               => eco_ready,
        out_count               => eco_count,
        out_last                => eco_last
      );

    -- The last signal of the length stream is used to indicate the final list,
    -- so even though the lengths are generated, we still use this to know when
    -- a user wants to finalize the command. Thus, we must merge the streams
    -- and borrow the last signal from the externally provided length stream.
    len_split_inst: StreamSync
      generic map (
        NUM_INPUTS => 2,
        NUM_OUTPUTS => 1
      )
      port map (
        clk                     => clk,
        reset                   => reset,

        in_valid(0)             => inl_valid,
        in_valid(1)             => eco_valid,

        in_ready(0)             => inl_ready,
        in_ready(1)             => eco_ready,

        out_valid(0)            => int_len_valid,
        out_ready(0)            => int_len_ready
      );

    int_len_length              <= eco_count;
    int_len_last                <= inl_last;

  end generate;

  -----------------------------------------------------------------------------
  -- Externally provided length stream
  -----------------------------------------------------------------------------
  -- We want to use the lengths in the length stream input. A ListSyncDecoder
  -- is instantiated that pulls a number of elements from a StreamNormalizer
  -- so when the element input stream contains a group of elements that cross
  -- a list boundary, they get split up into two transfers, with the first
  -- transfer of the new list being aligned and of maximum count (if possible).
  normalize_gen: if NORMALIZE generate

    -- ListSyncDecoder input length stream
    signal lsd_valid            : std_logic;
    signal lsd_ready            : std_logic;
    signal lsd_length           : std_logic_vector(LENGTH_WIDTH-1 downto 0);

    -- Normalizer input element stream
    signal normi_valid          : std_logic;
    signal normi_ready          : std_logic;
    signal normi_dvalid         : std_logic;
    signal normi_data           : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    signal normi_count          : std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
    signal normi_last           : std_logic;

    -- Normalizer input control stream
    signal norm_ctrl_valid      : std_logic;
    signal norm_ctrl_ready      : std_logic;
    signal norm_ctrl_last       : std_logic;
    signal norm_ctrl_dvalid     : std_logic;
    signal norm_ctrl_count      : std_logic_vector(REQ_COUNT_WIDTH-1 downto 0);

    -- Normalizer output element stream
    signal normo_valid          : std_logic;
    signal normo_ready          : std_logic;
    signal normo_dvalid         : std_logic;
    signal normo_last           : std_logic;
    signal normo_data           : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    signal normo_count          : std_logic_vector(COUNT_WIDTH-1 downto 0);

  begin

    -- Combine the length and element stream and output:
    -- * length to the internal length ouput
    -- * length to the ListSyncDecoder
    length_split_inst: StreamSync
      generic map (
        NUM_INPUTS => 1,
        NUM_OUTPUTS => 2
      )
      port map (
        clk                     => clk,
        reset                   => reset,

        in_valid(0)             => inl_valid,

        in_ready(0)             => inl_ready,

        out_valid(0)            => int_len_valid,
        out_valid(1)            => lsd_valid,

        out_ready(0)            => int_len_ready,
        out_ready(1)            => lsd_ready
      );

    -- List Sync Decoder length stream
    lsd_length                  <= inl_length;

    -- Internal length stream
    int_len_length              <= inl_length;
    int_len_last                <= inl_last;

    -- Normalizer input stream
    normi_valid                 <= ine_valid;
    ine_ready                   <= normi_ready;
    normi_dvalid                <= ine_dvalid;
    normi_data                  <= ine_data;
    normi_count                 <= ine_count;
    normi_last                  <= ine_last;

    -- Generate a control stream to the normalizer.
    list_sync_decoder_inst : ArrayReaderListSyncDecoder
      generic map (
        LENGTH_WIDTH            => LENGTH_WIDTH,
        COUNT_MAX               => COUNT_MAX,
        COUNT_WIDTH             => REQ_COUNT_WIDTH,
        LEN_IN_SLICE            => LEN_IN_SLICE
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        inl_valid               => lsd_valid,
        inl_ready               => lsd_ready,
        inl_length              => lsd_length,
        ctrl_valid              => norm_ctrl_valid,
        ctrl_ready              => norm_ctrl_ready,
        ctrl_last               => norm_ctrl_last,
        ctrl_dvalid             => norm_ctrl_dvalid,
        ctrl_count              => norm_ctrl_count
      );

    -- Normalize the output stream. This is done to mainly to prevent the
    -- crossing of list boundaries in case the values BufferWriter receives
    -- a new command for each list.
    normalizer_inst: StreamNormalizer
      generic map (
        ELEMENT_WIDTH           => ELEMENT_WIDTH,
        COUNT_MAX               => COUNT_MAX,
        COUNT_WIDTH             => COUNT_WIDTH,
        REQ_COUNT_WIDTH         => REQ_COUNT_WIDTH
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => normi_valid,
        in_ready                => normi_ready,
        in_dvalid               => normi_dvalid,
        in_data                 => normi_data,
        in_count                => normi_count,
        in_last                 => normi_last,
        req_count               => norm_ctrl_count,
        out_valid               => normo_valid,
        out_ready               => normo_ready,
        out_dvalid              => normo_dvalid,
        out_data                => normo_data,
        out_count               => normo_count,
        out_last                => normo_last
      );

    -- Synchronize the normalizer control stream to the normalized stream
    data_normo_sync_inst: StreamSync
      generic map (
        NUM_INPUTS => 2,
        NUM_OUTPUTS => 1
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid(0)             => norm_ctrl_valid,
        in_valid(1)             => normo_valid,
        in_ready(0)             => norm_ctrl_ready,
        in_ready(1)             => normo_ready,
        out_valid(0)            => int_dat_valid,
        out_ready(0)            => int_dat_ready
      );

    int_dat_dvalid              <= normo_dvalid;
    int_dat_data                <= normo_data;
    int_dat_count               <= normo_count;
    int_dat_last                <= norm_ctrl_last;

  end generate;

  -----------------------------------------------------------------------------
  -- Element output stream last signal
  -----------------------------------------------------------------------------
  -- Now that the appropriate length and element streams are generated
  -- internally, all that is left is to generate the proper last signaling on
  -- the element output stream.

  -- We want to close element stream only when the length stream has its last
  -- signal asserted as well.
  use_length_last_gen: if ELEM_LAST_FROM_LENGTH generate
    signal both_last : std_logic;
  begin

    -- Synchronize length and output stream.
    last_sync_inst: StreamSync
      generic map (
        NUM_INPUTS => 2,
        NUM_OUTPUTS => 2
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid(0)             => int_len_valid,
        in_valid(1)             => int_dat_valid,

        in_ready(0)             => int_len_ready,
        in_ready(1)             => int_dat_ready,

        -- Only use the length stream when the data last signal is asserted.
        in_use(0)               => int_dat_last,
        in_use(1)               => '1',
        
        -- Only enable the length stream when the data last signal is asserted.
        out_enable(0)           => int_dat_last,
        out_enable(1)           => '1',
        
        out_valid(0)            => outl_valid,
        out_valid(1)            => oute_valid,

        out_ready(0)            => outl_ready,
        out_ready(1)            => oute_ready
      );
    
    -- Only enable the list output and advance it if both are last
    both_last                 <= int_dat_last and int_len_last;

    -- Connect the element stream output
    oute_count                <= int_dat_count;
    oute_dvalid               <= int_dat_dvalid;
    oute_data                 <= int_dat_data;
    -- Use the last signal from the length stream
    oute_last                 <= both_last;

    -- Connect the length stream output
    outl_last                 <= int_len_last;
    outl_length               <= int_len_length;

  end generate;

  -- We want to use the element stream last signal on the element stream
  -- output. We can simply pass the internal streams.
  use_elem_last_gen: if not ELEM_LAST_FROM_LENGTH generate
    -- Connect element stream output
    oute_valid                <= int_dat_valid;
    int_dat_ready             <= oute_ready;
    oute_count                <= int_dat_count;
    oute_dvalid               <= int_dat_dvalid;
    oute_data                 <= int_dat_data;
    oute_last                 <= int_dat_last;

    -- Connect the length stream output
    outl_valid                <= int_len_valid;
    int_len_ready             <= outl_ready;
    outl_last                 <= int_len_last;
    outl_length               <= int_len_length;
  end generate;

end Behavioral;

