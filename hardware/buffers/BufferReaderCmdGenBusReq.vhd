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
use work.Stream_pkg.all;
use work.Buffer_pkg.all;
use work.Interconnect_pkg.all;
use work.UtilInt_pkg.all;
use work.UtilConv_pkg.all;
use work.UtilMisc_pkg.all;

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

    -- Number of beats in a burst step.
    BUS_BURST_STEP_LEN          : natural;

    -- Maximum number of beats in a burst.
    BUS_BURST_MAX_LEN           : natural;

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

    -- Whether this is a normal buffer or an offsets buffer.
    IS_OFFSETS_BUFFER           : boolean;

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
    -- for normal buffers and inclusive for offsets buffers, in all cases
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
    -- burst. The maximum for len is set by BUS_BURST_STEP_LEN. Bursts never cross
    -- BUS_BURST_STEP_LEN-sized alignment boundaries.
    busReq_valid                : out std_logic;
    busReq_ready                : in  std_logic;
    busReq_addr                 : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    busReq_len                  : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0)

  );
end BufferReaderCmdGenBusReq;

architecture rtl of BufferReaderCmdGenBusReq is

  type state_type is (IDLE, INDEX, PRE_STEP, MAX, POST_STEP);

  type input_record is record
    ready                       : std_logic;
  end record;

  constant input_reset : input_record := (ready => '0');

  type master_record is record
    addr                        : unsigned(BUS_ADDR_WIDTH-1 downto 0);
    len                         : unsigned(BUS_LEN_WIDTH-1 downto 0);
    valid                       : std_logic;
  end record;

  type index_record is record
    first                       : unsigned(INDEX_WIDTH-1 downto 0);
    last                        : unsigned(INDEX_WIDTH-1 downto 0);
    current                     : unsigned(INDEX_WIDTH-1 downto 0);
  end record;

  type regs_record is record
    state                       : state_type;
    input                       : input_record;
    index                       : index_record;
    master                      : master_record;
    base_address                : unsigned(BUS_ADDR_WIDTH-1 downto 0);
  end record;

  signal r                      : regs_record;
  signal d                      : regs_record;

  -- Helper functions and constants
  
  -- The pre-alignment state will end when we've reached either the global
  -- maximum for the bus_burst_boundary or a maximum burst boundary.
  -- However, this operates on the byte level.
  constant BYTE_ALIGN           : natural := imin(BUS_BURST_BOUNDARY, BUS_BURST_MAX_LEN * BUS_DATA_WIDTH / 8);

  constant ELEMS_PER_STEP       : natural := BUS_DATA_WIDTH * BUS_BURST_STEP_LEN / ELEMENT_WIDTH;
  constant ELEMS_PER_MAX        : natural := BUS_DATA_WIDTH * BUS_BURST_MAX_LEN / ELEMENT_WIDTH;

  -- Index shift required to calculate the byte offset of an element,
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
  -- Index to Byte Address Left Shift Amount
  constant ITOBA_LSHIFT         : integer := -3 + log2ceil(ELEMENT_WIDTH);

  constant STEP_LEN             : unsigned(BUS_LEN_WIDTH-1 downto 0) := u(BUS_BURST_STEP_LEN, BUS_LEN_WIDTH);
  constant MAX_LEN              : unsigned(BUS_LEN_WIDTH-1 downto 0) := u(BUS_BURST_MAX_LEN, BUS_LEN_WIDTH);

  constant BYTES_PER_STEP       : natural := BUS_DATA_WIDTH * BUS_BURST_STEP_LEN / 8;
  constant BYTES_PER_MAX        : natural := BUS_DATA_WIDTH * BUS_BURST_MAX_LEN / 8;

  signal first_index            : unsigned(INDEX_WIDTH-1 downto 0);
  signal last_index             : unsigned(INDEX_WIDTH-1 downto 0);

  signal byte_address           : unsigned(BUS_ADDR_WIDTH-1 downto 0);

begin
  -----------------------------------------------------------------------------
  -- Burst step / index / address calculation
  -----------------------------------------------------------------------------
  -- Floor align the first index to the no. elements per step.
  first_index                   <= alignDown(r.index.first, log2floor(ELEMS_PER_STEP));
  -- Ceil align the last index to the no. elements per step.
  last_index                    <= alignUp(r.index.last, log2floor(ELEMS_PER_STEP));

  -- Get the byte address of this index
  byte_address                  <= resize(r.base_address + shift(
      resize(r.index.current, r.index.current'length + imax(0, ITOBA_LSHIFT)),
      ITOBA_LSHIFT), r.base_address'length);

  -----------------------------------------------------------------------------
  -- State machine sequential part
  -----------------------------------------------------------------------------
  sm_seq: process (clk) is
  begin
    if rising_edge(clk) then
      r                         <= d;    
      if reset = '1' then
        r.state                 <= IDLE;
        r.master.valid          <= '0';
        r.input.ready           <= '0';
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
    byte_address, first_index, last_index
  ) is
    variable v                  : regs_record;
  begin
    v                           := r;

    -- Default values:
    v.input.ready               := '0';
    v.master.addr               := byte_address;
    v.master.len                := STEP_LEN;
    v.master.valid              := '0';

    case v.state is
      -------------------------------------------------------------------------
      when IDLE =>
      -------------------------------------------------------------------------
        -- We are ready to receive some new input
        v.input.ready           := '1';

        if cmdIn_valid = '1' then
          -- Accept command & clock in data, if the first and last index are not the same
          if cmdIn_firstIdx /= cmdIn_lastIdx or not CHECK_INDEX then

            v.index.first       := unsigned(cmdIn_firstIdx);
            v.index.last        := unsigned(cmdIn_lastIdx);
            v.base_address      := unsigned(cmdIn_baseAddr);

            -- Determine what is to be loaded first
            if (IS_OFFSETS_BUFFER) then
              v.index.current   := alignDown(unsigned(cmdIn_lastIdx), log2floor(ELEMS_PER_STEP));
            else
              v.index.current   := alignDown(unsigned(cmdIn_firstIdx), log2floor(ELEMS_PER_STEP));
            end if;
          end if;
        end if;

        -- Getting out of idle requires no backpressure
        -- Ignore commands with the "implicit" flag set; in this case we don't
        -- want to generate any bus requests
        if cmdIn_valid = '1' then
          if cmdIn_implicit = '0' then
            if cmdIn_firstIdx /= cmdIn_lastIdx or not CHECK_INDEX then
              if IS_OFFSETS_BUFFER then
                v.state         := INDEX;
              else
                v.state         := PRE_STEP;
              end if;
            end if;
          end if;
        end if;

      -------------------------------------------------------------------------
      when INDEX =>
      -------------------------------------------------------------------------
        -- State to fetch the last index, this is used for variable length lists,
        -- where the user core needs to know the length of the whole variable
        -- length List<Type> element that it will receive
      
        v.master.addr           := byte_address;
        -- Assuming an index element fits in a burst step, the burst length is
        -- always one step for the index state
        v.master.len            := STEP_LEN;
        v.master.valid          := '1';

        -- Back-pressure
        if busReq_ready = '1' then
          -- Increase last index by 1 for offsets buffers
          v.index.last          := v.index.last + 1;
          v.index.current       := first_index;
          v.state               := PRE_STEP;
        end if;

      -------------------------------------------------------------------------
      when PRE_STEP =>
      -------------------------------------------------------------------------
        -- State to step to first max burst aligned index or last index
        
        v.master.addr           := byte_address;
        v.master.len            := STEP_LEN;

        -- Make bus request valid
        v.master.valid          := '1';

        -- Invalidate if we've reached the alignment boundary
        if isAligned(byte_address, log2floor(BYTE_ALIGN)) then
          v.master.valid        := '0';
          v.state               := MAX;
        end if;

        -- Invalidate if we've reached the last index
        if (v.index.current = last_index) then
          v.master.valid        := '0';
          v.state               := IDLE;
        end if;

        -- Back-pressure
        if busReq_ready = '1' and v.master.valid = '1' then
          v.index.current       := v.index.current + ELEMS_PER_STEP;
        end if;

      -------------------------------------------------------------------------
      when MAX =>
      -------------------------------------------------------------------------
        -- State to burst maximum lengths
        
        v.master.addr           := byte_address;
        v.master.len            := MAX_LEN;

        -- Make bus request valid
        v.master.valid          := '1';

        -- Invalidate if this burst would go over the last index
        if v.index.current + ELEMS_PER_MAX >= last_index then
          v.master.valid        := '0';
          v.state               := POST_STEP;
        end if;

        -- Invalidate if we've reached the last index
        if (v.index.current = last_index) then
          v.master.valid        := '0';
          v.state               := IDLE;
        end if;

        -- Back-pressure
        if busReq_ready = '1' and v.master.valid = '1' then
          v.index.current       := v.index.current + ELEMS_PER_MAX;
        end if;

      -------------------------------------------------------------------------
      when POST_STEP =>
      -------------------------------------------------------------------------
        -- State to step to last index
        
        v.master.addr           := byte_address;
        v.master.len            := STEP_LEN;

        -- Make bus request valid
        v.master.valid          := '1';

        -- Invalidate if we've reached the last index
        if (v.index.current = last_index) then
          v.master.valid        := '0';
          v.state               := IDLE;
        end if;

        -- Back-pressure
        if busReq_ready = '1' and v.master.valid = '1' then
          v.index.current       := v.index.current + ELEMS_PER_STEP;
        end if;

    end case;

    d                           <= v;

  end process;

  cmdIn_ready                   <= d.input.ready;

  busReq_addr                   <= slv(d.master.addr);
  busReq_len                    <= slv(d.master.len);
  busReq_valid                  <= d.master.valid;

end rtl;

