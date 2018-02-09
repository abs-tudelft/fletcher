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
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

library work;
use work.Utils.all;

entity BufferReaderCmdGenBusReq is
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
    
    -- Number of beats in a burst.
    BUS_BURST_LENGTH            : natural;

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

    -- Whether this is a normal buffer or an index buffer.
    IS_INDEX_BUFFER             : boolean;

    -- Wether or not this component should check if the first and last index
    -- are not equal
    CHECK_INDEX                 : boolean

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
    -- for normal buffers and inclusive for index buffers, in all cases
    -- resulting in lastIdx - firstIdx elements. baseAddr is the pointer to the
    -- first element in the buffer. implicit may be set for null bitmap readers
    -- if null count is zero; if it is set, no bus requests will be made, and
    -- the unit will behave as if it receives all-one bus responses.
    cmdIn_valid                 : in  std_logic;
    cmdIn_ready                 : out std_logic;
    cmdIn_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_baseAddr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    cmdIn_implicit              : in  std_logic;

    ---------------------------------------------------------------------------
    -- Output streams
    ---------------------------------------------------------------------------
    -- Bus read request (bus clock domain). addr represents the start address
    -- for the transfer, len is the amount of requested words requested in the
    -- burst. The maximum for len is set by BUS_BURST_LEN. Bursts never cross
    -- BUS_BURST_LEN-sized alignment boundaries.
    busReq_valid                : out std_logic;
    busReq_ready                : in  std_logic;
    busReq_addr                 : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    busReq_len                  : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0)

  );
end BufferReaderCmdGenBusReq;

architecture rtl of BufferReaderCmdGenBusReq is

  type state_type is (IDLE, INDEX, ALIGN, REST);

  type input_record is record
    ready                       : std_logic;
  end record;

  constant input_reset : input_record := (ready => '0');

  type master_record is record
    addr                        : unsigned(BUS_ADDR_WIDTH-1 downto 0);
    len                         : unsigned(BUS_LEN_WIDTH-1 downto 0);
    valid                       : std_logic;
  end record;

  constant master_reset : master_record := (
    addr                        => (others => '0'),
    len                         => (others => '0'),
    valid                       => '0'
  );

  type index_record is record
    first                       : unsigned(INDEX_WIDTH-1 downto 0);
    last                        : unsigned(INDEX_WIDTH-1 downto 0);
    current                     : unsigned(INDEX_WIDTH-1 downto 0);
  end record;

  constant index_reset : index_record := (others => (others => '0'));

  type regs_record is record
    state                       : state_type;
    input                       : input_record;
    index                       : index_record;
    master                      : master_record;
    base_address                : unsigned(BUS_ADDR_WIDTH-1 downto 0);
  end record;

  constant r_reset : regs_record := (
    state                       => IDLE,
    input                       => input_reset,
    index                       => index_reset,
    master                      => master_reset,
    base_address                => (others => '0')
  );

  signal r                      : regs_record;
  signal d                      : regs_record;

  -----------------------------------------------------------------------------
  -- Address calculation helper constants & signals
  -----------------------------------------------------------------------------

  -- Index shift required to calculate the byte address of an element,
  -- It depends on the number of bits of the element type as follows:
  -- Elem bits| log2(bits)  | shift left amount
  --        1 |           0 |                -3
  --        2 |           1 |                -2
  --        4 |           2 |                -1
  --        8 |           3 |                 0
  --       16 |           4 |                 1
  --       32 |           5 |                 2
  --       64 |           6 |                 3
  --      128 |           7 |                 4
  --      ... |         ... |               ...  
  --  Thus, we must shift left with -3 + log2(ELEMENT_WIDTH)
  constant B_LSHIFT             : integer                               := -3 + log2ceil(ELEMENT_WIDTH);
    
  -- Amount of byes in a burst
  constant BA_BYTES             : natural                               := BUS_BURST_LENGTH * BUS_DATA_WIDTH / 8;
  
  -- The number of bits we can drop from the byte address of an element to align it to a burst
  constant BA_BYTE_BITS         : natural                               := log2ceil(BA_BYTES);
  constant BA_BYTE_ZEROS        : unsigned(BA_BYTE_BITS-1 downto 0)     := (others => '0');
  
  -- Amount of elements in a burst
  constant BA_ELEMENTS          : natural                               := BA_BYTES * 8 / ELEMENT_WIDTH;
  
  -- The number of bits we can drop from an index to align it to a burst
  constant BA_IDX_BITS          : natural                               := log2ceil(BA_ELEMENTS);
  constant BA_IDX_ZEROS         : unsigned(BA_IDX_BITS-1 downto 0)      := (others => '0');
  
  -- Maximum burst length
  constant MAX_BURST            : unsigned(BUS_LEN_WIDTH-1 downto 0)    := u(BUS_BURST_LENGTH, BUS_LEN_WIDTH);
  
  -- Byte addresses
  signal b_address              : unsigned(BUS_ADDR_WIDTH-1 downto 0)   := (others => '0');
  signal b_last_idx_address     : unsigned(BUS_ADDR_WIDTH-1 downto 0)   := (others => '0');

  -- Burst aligned address
  signal ba_address             : unsigned(BUS_ADDR_WIDTH-1 downto 0)   := (others => '0');
  signal ba_last_idx_address    : unsigned(BUS_ADDR_WIDTH-1 downto 0)   := (others => '0');

  -----------------------------------------------------------------------------
  -- Other signals
  -----------------------------------------------------------------------------

  -- Last burst signaling to state machine
  signal last                   : std_logic := '0';

  -- Next index adder
  signal next_index             : unsigned(INDEX_WIDTH-1 downto 0)        := (others => '0');

begin
  -----------------------------------------------------------------------------
  -- Address calculation
  -----------------------------------------------------------------------------
  -- The byte address of the item and for index buffers
  b_address                     <= unsigned(r.base_address) + shift_left_with_neg(r.index.current , B_LSHIFT);
  b_last_idx_address            <= unsigned(r.base_address) + shift_left_with_neg(r.index.last    , B_LSHIFT);
  
  -- The burst address of the item and index buffers
  ba_address                    <= b_address(BUS_ADDR_WIDTH-1 downto BA_BYTE_BITS) & BA_BYTE_ZEROS;
  ba_last_idx_address           <= b_last_idx_address(BUS_ADDR_WIDTH-1 downto BA_BYTE_BITS) & BA_BYTE_ZEROS;

  -- Check for last burst, this must be a greather than or equal comparison, in
  -- case the first and last indices are in the same burst
  -- TODO: could probably be optimized
  check_last: process (next_index, r) is
  begin
    if next_index >= r.index.last then
      last                      <= '1';
    else
      last                      <= '0';
    end if;
  end process;
  
  -- Next index adder, it adds 1 to the MSBs above the next burst address,
  -- and pads them with zeros. This causes the next index to always be aligned to a burst.
  next_index                    <= (r.index.current(INDEX_WIDTH-1 downto BA_IDX_BITS) + 1) & BA_IDX_ZEROS;
  
  -----------------------------------------------------------------------------
  -- State machine sequential part
  -----------------------------------------------------------------------------
  sm_seq: process (clk) is
  begin
    if rising_edge(clk) then
      if reset = '1' then
        r                       <= r_reset;
      else
        r                       <= d;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- State machine combinatorial part
  -----------------------------------------------------------------------------
  sm_comb : process (
    r, 
    cmdIn_valid, cmdIn_firstIdx, cmdIn_lastIdx, cmdIn_baseAddr, cmdIn_implicit, 
    busReq_ready,
    ba_address, ba_last_idx_address, last, next_index
  ) is
    variable v                  : regs_record;
  begin
    v                           := r;

    -- Default values:
    v.input.ready               := '0';
    v.master.addr               := ba_address;
    v.master.len                := MAX_BURST;
    v.master.valid              := '0';

    case v.state is
      when IDLE =>
        -- We are ready to receive some new input
        v.input.ready           := '1';
        
        if cmdIn_valid = '1' then
          -- Accept command & clock in data, if the first and last index are not the same
          if cmdIn_firstIdx /= cmdIn_lastIdx or not CHECK_INDEX then
            v.index.first       := unsigned(cmdIn_firstIdx);
            v.index.last        := unsigned(cmdIn_lastIdx);
            v.index.current     := unsigned(cmdIn_firstIdx);
            v.base_address      := unsigned(cmdIn_baseAddr);
          end if;
        end if;

        -- Getting out of idle requires no backpressure
        -- Ignore commands with the "implicit" flag set; in this case we don't
        -- want to generate any bus requests
        if cmdIn_valid = '1' then
          if cmdIn_implicit = '0' then
            if cmdIn_firstIdx /= cmdIn_lastIdx or not CHECK_INDEX then
              if IS_INDEX_BUFFER then
                v.state         := INDEX;
              else
                v.state         := ALIGN;
              end if;
            end if;
          end if;
        end if;

      -- State to fetch the last index, this is used for variable length lists, where the user core needs to know
      -- the length of the whole variable length List<Type> element that it will receive
      when INDEX =>
        v.master.addr           := ba_last_idx_address;
        -- Assuming an index element fits in a word, the burst length is always one word for the index state
        v.master.len            := MAX_BURST;
        v.master.valid          := '1';

        -- Back-pressure
        if busReq_ready = '1' then
          v.index.last          := v.index.last + 1;
          v.state               := ALIGN;
        end if;

      -- State to align to max burst length
      when ALIGN =>
        v.master.addr           := ba_address;
        v.master.len            := MAX_BURST;
        v.master.valid          := '1';

        -- Back-pressure
        if busReq_ready = '1' then
          v.state               := REST;
          v.index.current       := next_index;
          if last = '1' then
            v.state             := IDLE;
          end if;
        end if;

      -- State to request bursts for which the start address is aligned
      when REST =>
        v.master.addr           := ba_address;
        v.master.len            := MAX_BURST;
        v.master.valid          := '1';

        -- Back-pressure
        if busReq_ready = '1' then
          if last = '1' then
            v.state             := IDLE;
          else
            v.index.current     := next_index;
          end if;
        end if;
    end case;

    d                           <= v;

  end process;

  cmdIn_ready                   <= d.input.ready;

  busReq_addr                   <= slv(d.master.addr);
  busReq_len                    <= slv(d.master.len);
  busReq_valid                  <= d.master.valid;

end rtl;

