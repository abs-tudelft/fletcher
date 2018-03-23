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
use work.Arrow.all;

entity BufferWriterCmdGenBusReq is
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
    -- Command stream input.
    cmdIn_valid                 : in  std_logic;
    cmdIn_ready                 : out std_logic;
    cmdIn_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_baseAddr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    cmdIn_implicit              : in  std_logic;

    ---------------------------------------------------------------------------
    -- Data stream tracking signals
    ---------------------------------------------------------------------------
    -- This unit keeps track of how many words are loaded into the FIFO through
    -- the word_loaded signal which should be asserted whenever a transfer into
    -- the FIFO is handshaked. When word_last is asserted, a final burst step 
    -- will be made
    word_loaded                 : in  std_logic;
    word_last                   : in  std_logic;

    ---------------------------------------------------------------------------
    -- Output streams
    ---------------------------------------------------------------------------
    -- Bus write request (bus clock domain). addr represents the start address
    -- for the transfer, len is the amount of words to be written in the burst.
    -- The maximum for len is set by BUS_BURST_STEP_LEN. Bursts never cross
    -- BUS_BURST_STEP_LEN-sized alignment boundaries.
    busReq_valid                : out std_logic;
    busReq_ready                : in  std_logic;
    busReq_addr                 : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    busReq_len                  : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0)

  );
end BufferWriterCmdGenBusReq;

architecture rtl of BufferWriterCmdGenBusReq is

  -- Burst step counter
  type counter_record is record
    word                        : unsigned(log2ceil(BUS_BURST_STEP_LEN)-1 downto 0);
    -- This counter must be able to hold the number of steps in a maximum burst
    step                        : unsigned(log2ceil(BUS_BURST_MAX_LEN/BUS_BURST_STEP_LEN+1) downto 0);
  end record;

  constant WORD_ZERO            : unsigned(log2ceil(BUS_BURST_STEP_LEN)-1 downto 0) := (others => '0');
  constant MAX_STEPS            : natural := BUS_BURST_MAX_LEN / BUS_BURST_STEP_LEN;

  type counter_control_record is record
    reset                       : std_logic;
    step_sub                    : std_logic;
    max_sub                     : std_logic;
  end record;
  
  signal cnt_ctrl        : counter_control_record;
  
  signal counter                : counter_record;
  signal counter_d              : counter_record;
  
  -- 

  type state_type is (IDLE, PRE_STEP, MAX, POST_STEP);

  type master_record is record
    addr                        : unsigned(BUS_ADDR_WIDTH-1 downto 0);
    len                         : unsigned(BUS_LEN_WIDTH-1 downto 0);
    valid                       : std_logic;
  end record;

  type index_record is record
    first                       : unsigned(INDEX_WIDTH-1 downto 0);
    current                     : unsigned(INDEX_WIDTH-1 downto 0);
    last                        : unsigned(INDEX_WIDTH-1 downto 0);
  end record;

  type regs_record is record
    state                       : state_type;
    index                       : index_record;
    base_address                : unsigned(BUS_ADDR_WIDTH-1 downto 0);
    last                        : std_logic;
  end record;

  type output_record is record
    master                      : master_record;
    cmdIn_ready                 : std_logic;
    cnt_ctrl                    : counter_control_record;
  end record;

  signal r                      : regs_record;
  signal d                      : regs_record;

  -- Helper functions and constants

  -- The pre-alignment state will end when we've reached either the global
  -- maximum for the bus_burst_boundary or a maximum burst boundary.
  -- However, this operates on the byte level.
  constant BYTE_ALIGN           : natural := work.Utils.min(BUS_BURST_BOUNDARY, BUS_BURST_MAX_LEN * BUS_DATA_WIDTH / 8);

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

  signal byte_address           : unsigned(BUS_ADDR_WIDTH-1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Steps loaded counter
  -----------------------------------------------------------------------------
  -- Count the number of words loaded in the FIFO such that we know when
  -- another burst step is ready to be written.

  counter_reg_proc: process(clk) is
  begin
    if rising_edge(clk) then
      counter                   <= counter_d;

      if reset = '1' then
        counter.word            <= (others => '0');
        counter.step            <= (others => '0');
      end if;
    end if;
  end process;

  counter_comb_proc: process(counter, word_loaded, word_last, cnt_ctrl) is
    variable v                  : counter_record;
  begin
    v                           := counter;

    if word_loaded = '1' then
      if BUS_BURST_STEP_LEN /= 1 then
        v.word                  := v.word + 1;
        -- If word wraps around we've loaded a step.
        if v.word = WORD_ZERO then
          v.step                := v.step + 1;
        end if;
      else
        -- If burst step len is 1, then every word is a step
        v.step                  := v.step + 1;
      end if;
    end if;
    
    -- Check if there is a step subtraction request
    if cnt_ctrl.step_sub = '1' then
      v.step                    := v.step - 1;
    elsif cnt_ctrl.max_sub = '1' then
      v.step                    := v.step - MAX_STEPS;
    end if;

    -- pragma translate off
    if cnt_ctrl.step_sub = '1' and cnt_ctrl.max_sub = '1' then
      report "Step counter subtraction request for both one burst step and maximum burst step."
        severity failure;
    end if;
    -- pragma translate on

    counter_d                   <= v;
  end process;

  -----------------------------------------------------------------------------
  -- Burst step / index / address calculation
  -----------------------------------------------------------------------------
  -- Get the byte address of this index
  byte_address                  <= r.base_address + shift_left_with_neg(r.index.current, ITOBA_LSHIFT);

  -----------------------------------------------------------------------------
  -- State machine sequential part
  -----------------------------------------------------------------------------
  seq_proc: process (clk) is
  begin
    if rising_edge(clk) then
      r                         <= d;
      if reset = '1' then
        r.state                 <= IDLE;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- State machine combinatorial part
  -----------------------------------------------------------------------------
  comb_proc : process (
    r,
    cmdIn_valid, cmdIn_firstIdx, cmdIn_baseAddr, cmdIn_implicit,
    busReq_ready,
    byte_address,
    word_last, word_loaded,
    counter
  ) is
    variable vr                 : regs_record;
    variable vo                 : output_record;
  begin
    -- Default registered values:
    vr                          := r;

    -- Default combinatorial values:
    vo.cmdIn_ready              := '0';
    vo.master.addr              := byte_address;
    vo.master.len               := STEP_LEN;
    vo.master.valid             := '0';
    vo.cnt_ctrl.step_sub        := '0';
    vo.cnt_ctrl.max_sub         := '0';
    vo.cnt_ctrl.reset           := '0';

    case vr.state is
      -------------------------------------------------------------------------
      when IDLE =>
      -------------------------------------------------------------------------
        -- We are ready to receive some new input
        vo.cmdIn_ready          := '1';
                
        -- Last value was not asserted
        vr.last                 := '0';

        if cmdIn_valid = '1' then
          vr.index.first        := unsigned(cmdIn_firstIdx);
          vr.base_address       := unsigned(cmdIn_baseAddr);
          vr.index.current      := align_beq(unsigned(cmdIn_firstIdx), log2floor(ELEMS_PER_STEP));
          vr.index.last         := align_aeq(unsigned(cmdIn_lastIdx), log2floor(ELEMS_PER_STEP));
        end if;

        -- Getting out of idle requires no backpressure
        -- Ignore commands with the "implicit" flag set; in this case we don't
        -- want to generate any bus requests
        if cmdIn_valid = '1' then
          if cmdIn_implicit = '0' then
            vr.state            := PRE_STEP;
          end if;
        end if;

      -------------------------------------------------------------------------
      when PRE_STEP =>
      -------------------------------------------------------------------------
        -- State to step to first max burst aligned index or last index
        
        -- We write one step
        vo.master.len           := STEP_LEN;

        -- Make bus request valid
        vo.master.valid         := '1';

        -- Invalidate if we've reached the alignment boundary
        if is_aligned(byte_address, log2floor(BYTE_ALIGN)) then
          vo.master.valid       := '0';
          vr.state              := MAX;
        end if;
       
        -- Invalidate if there is no burst step in the FIFO
        if counter.step = 0 then
          vo.master.valid       := '0';
        end if;
        
        -- Invalidate if this is the last word; the POST_STEP state should
        -- handle this
        if word_last = '1' then
          vo.master.valid       := '0';
          vr.last               := '1';
          vr.state              := POST_STEP;
          -- Redetermine last index
          vr.index.last         := align_aeq(vr.index.current, log2floor(ELEMS_PER_STEP));
        end if;

        -- Back-pressure
        if busReq_ready = '1' and vo.master.valid = '1' then
          vo.cnt_ctrl.step_sub  := '1';
          vr.index.current      := vr.index.current + ELEMS_PER_STEP;
        end if;

      -------------------------------------------------------------------------
      when MAX =>
      -------------------------------------------------------------------------
        -- State to burst maximum lengths

        -- We write a maximum burst
        vo.master.len           := MAX_LEN;

        -- Make bus request valid
        vo.master.valid         := '1';
       
       -- Invalidate if there is no max burst step in the FIFO
        if counter.step < MAX_STEPS then
          vo.master.valid       := '0';
        end if;
       
        -- Invalidate if this is the last word; the POST_STEP state should
        -- handle this
        if word_last = '1' then
          vo.master.valid       := '0';
          vr.last               := '1';
          vr.state              := POST_STEP;
          
          vr.index.last         := align_aeq(vr.index.current, log2floor(ELEMS_PER_STEP));
        end if;

        -- Back-pressure
        if busReq_ready = '1' and vo.master.valid = '1' then
          vo.cnt_ctrl.max_sub   := '1';
          vr.index.current      := vr.index.current + ELEMS_PER_MAX;
        end if;

      -------------------------------------------------------------------------
      when POST_STEP =>
      -------------------------------------------------------------------------
        -- State to step until steps counter is zero.

        -- We write one step
        vo.master.len           := STEP_LEN;

        -- Make bus request valid
        vo.master.valid         := '1';

        -- Stop when all steps have been requested.
        if vr.index.current /= vr.index.last then
          vo.master.valid       := '0';
          vr.state              := IDLE;
        end if;

        -- Back-pressure
        if busReq_ready = '1' and vo.master.valid = '1' then
          vo.cnt_ctrl.step_sub  := '1';
          vr.index.current      := vr.index.current + ELEMS_PER_STEP;
        end if;

    end case;

    d                           <= vr;

    cmdIn_ready                 <= vo.cmdIn_ready;

    busReq_addr                 <= slv(vo.master.addr);
    busReq_len                  <= slv(vo.master.len);
    busReq_valid                <= vo.master.valid;
    cnt_ctrl                    <= vo.cnt_ctrl;

  end process;

end rtl;

