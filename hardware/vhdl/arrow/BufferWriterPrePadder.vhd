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

-- This unit pads stream head and tail with non-valid elements and generates
-- write strobes on a per-element basis. The padding is done in such a way that
-- the stream will eventually hold exactly as many bytes as a burst step.
entity BufferWriterPrePadder is
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

    -- Command stream control vector width. This vector is propagated to the
    -- outgoing command stream, but isn't used otherwise. It is intended for
    -- control flags and base addresses for BufferReaders reading buffers that
    -- are indexed by this index buffer.
    CMD_CTRL_WIDTH              : natural;

    -- Command stream tag width. This tag is propagated to the outgoing command
    -- stream and to the unlock stream. It is intended for chunk reference
    -- counting.
    CMD_TAG_WIDTH               : natural;
    
    CHECK_LAST_EXCEED           : boolean := true

  );
  port (

    ---------------------------------------------------------------------------
    -- Clock domains
    ---------------------------------------------------------------------------
    -- Rising-edge sensitive clock and active-high synchronous reset.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    ---------------------------------------------------------------------------
    -- Command stream
    ---------------------------------------------------------------------------
    cmdIn_valid                 : in  std_logic;
    cmdIn_ready                 : out std_logic;
    cmdIn_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_implicit              : in  std_logic;

    ---------------------------------------------------------------------------
    -- Data stream
    ---------------------------------------------------------------------------
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    in_last                     : in  std_logic;

    ---------------------------------------------------------------------------
    -- Output stream
    ---------------------------------------------------------------------------
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    out_strobe                  : out std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
    out_last                    : out std_logic
  );
end BufferWriterPrePadder;

architecture rtl of BufferWriterPrePadder is

  constant ELEM_PER_BURST_STEP  : natural := (BUS_BURST_STEP_LEN * BUS_DATA_WIDTH) / ELEMENT_WIDTH;

  constant INDEX_ZERO           : unsigned(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0) := (others => '0');

  constant STROBE_NONE          : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0) := (others => '0');
  constant STROBE_FIRST         : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0) := (0 => '1', others => '0');
  constant STROBE_ALL           : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0) := (others => '1');

  constant COUNT_ONE            : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0) := (0 => '1', others => '0');
  
  -- A count of all zeros is equal to the max count
  constant COUNT_ALL            : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0) := (others => '0');

  type index_record is record
    first                       : unsigned(INDEX_WIDTH-1 downto 0);
    current                     : unsigned(INDEX_WIDTH-1 downto 0);
    last                        : unsigned(INDEX_WIDTH-1 downto 0);
    final                       : unsigned(INDEX_WIDTH-1 downto 0);
  end record;

  type state_type is (IDLE, INDEX, PRE, PASS, POST);

  type regs_record is record
    state                       : state_type;
    index                       : index_record;
  end record;

  signal r                      : regs_record;
  signal d                      : regs_record;

  type outputs_record is record
    cmdIn_ready                 : std_logic;

    in_ready                    : std_logic;

    out_valid                   : std_logic;
    out_data                    : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    out_count                   : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    out_strobe                  : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
    out_last                    : std_logic;
  end record;

begin

  seq: process(clk) is
  begin
    if rising_edge(clk) then
      -- Registers
      r                         <= d;

      -- Reset
      if reset = '1' then
        r.state                 <= idle;
      end if;
    end if;
  end process;

  comb: process(r, cmdIn_valid, cmdIn_firstIdx, out_ready, in_data, in_count, in_valid, in_last) is
    variable vr                 : regs_record;
    variable vo                 : outputs_record;
    
    variable new_index          : unsigned(index_width-1 downto 0);
  begin
    -- Registered output defaults
    vr                          := r;

    -- Combinational output defaults:
    vo.cmdIn_ready              := '0';
    vo.in_ready                 := '0';
    vo.out_valid                := '0';
    vo.out_last                 := '0';

    -- In simulation, make data, count and strobe unkown by default
    --pragma translate off
    vo.out_data                 := (others => 'U');
    vo.out_count                := (others => 'U');
    vo.out_strobe               := (others => 'U');
    -- pragma translate on

    case vr.state is
      -------------------------------------------------------------------------
      when IDLE =>
      -------------------------------------------------------------------------
        -- Ready to receive a command
        vo.cmdIn_ready          := '1';
          
        if cmdIn_valid = '1' then
          -- Clock in the first index
          vr.index.first        := u(cmdIn_firstIdx);
          vr.index.current      := align_beq(u(cmdIn_firstIdx), log2ceil(ELEM_PER_BURST_STEP));
          vr.index.last         := u(cmdIn_lastIdx);

          -- Advance state without backpressure
          if IS_INDEX_BUFFER then
            assert vr.index.first = 0 
              report "ERROR: Index BufferWriter command first index is not 0."
              severity failure;
            vr.state            := INDEX;
          else
            vr.state            := PRE;
          end if;
        end if;

      -------------------------------------------------------------------------
      when INDEX =>
      -------------------------------------------------------------------------
        -- For index buffers, we insert one element
        vo.out_data             := slv(INDEX_ZERO);
        vo.out_count            := COUNT_ONE;
        vo.out_strobe           := STROBE_FIRST;
        vo.out_valid            := '1';

        -- Advance state if no backpressure
        if out_ready = '1' then
          vr.index.current    := vr.index.current + 1;
          -- Index buffer should never have to prepend, so skip to pass
          vr.state              := PASS;
        end if;

      -------------------------------------------------------------------------
      when PRE =>
      -------------------------------------------------------------------------
        -- Insert single elements until first index is reached

        -- All inserted elements are disabled through the write strobe
        vo.out_count            := COUNT_ONE;
        vo.out_strobe           := STROBE_NONE;
        
        -- Only validate if we actually have to prepend
        if vr.index.current /= vr.index.first then
          vo.out_valid          := '1';
          -- Advance state if no backpressure
          if out_ready = '1' then
            vr.index.current    := vr.index.current + 1;
          end if;
        else
          vo.out_valid          := '0';
        end if;
        
        if vr.index.current = vr.index.first then
          vr.state              := PASS;
        end if;
      -------------------------------------------------------------------------
      when PASS =>
      -------------------------------------------------------------------------
        -- Pass through input
        vo.in_ready             := out_ready;
        vo.out_valid            := in_valid;
        vo.out_data             := in_data;
        vo.out_last             := '0';
        vo.out_count            := in_count;
        -- All strobes are enabled since count will cause the normalizer to 
        -- drop invalid elements.
        vo.out_strobe           := STROBE_ALL; 
        
        -- Determine the new index
        new_index               := vr.index.current+u(resize_count(
                                                      in_count,
                                                      ELEMENT_COUNT_WIDTH+1));
        
        -- Only accept the input if it will not exceed the last_index
        -- pragma translate off
        -- TODO: generate some sort of error signal to the user core and take
        --       this out of simulation-only, although it's costly
        if CHECK_LAST_EXCEED and
           vr.index.last /= INDEX_ZERO and
           new_index > vr.index.last
        then
          report "ERROR: BufferWriter input stream count causes last index "
               & "to be exceeded."
            severity failure;
          vo.in_ready           := '0';
          vo.out_valid          := '0';
        end if;
        -- pragma translate on
        
        -- This last transfer might already be aligned; assert last if so
        if in_last = '1' then
          if is_aligned(new_index, log2ceil(ELEM_PER_BURST_STEP)) then
            vo.out_last       := '1';
          end if;
        end if;

        -- Advance state if no backpressure and a valid input was passed
        if out_ready = '1' and vo.out_valid = '1' then
          vr.index.current      := new_index;
          
          -- Determine the final index based on the current index, so it will
          -- be ready for the next state
          vr.index.final        := align_aeq(vr.index.current, 
                                             log2ceil(ELEM_PER_BURST_STEP));
          
          -- If the last input has arrived, let the POST state handle the rest
          if in_last = '1' then
            vr.state            := POST;
          end if;
        end if;

      -------------------------------------------------------------------------
      when POST =>
      -------------------------------------------------------------------------
        -- Insert single elements until last index is reached

        -- All inserted elements are disabled through the write strobe
        vo.out_count            := COUNT_ONE;
        vo.out_strobe           := STROBE_NONE;
        vo.out_last             := '0';
        
        -- Only validate if we actually have to append
        if vr.index.current /= vr.index.final then
          
          vo.out_valid          := '1';
          
          -- Advance state if no backpressure
          if out_ready = '1' then
            vr.index.current    := vr.index.current + 1;
          end if;
        else
          vo.out_valid          := '0';
        end if;
        
        -- Only assert last if the current index is aligned
        if is_aligned(vr.index.current, log2ceil(ELEM_PER_BURST_STEP)) then
          vo.out_last           := '1';
          vr.state              := IDLE;
        end if;
    end case;
    
    -- Outputs to be registered
    d                           <= vr;

    -- Combinatorial outputs
    cmdIn_ready                 <= vo.cmdIn_ready;
    in_ready                    <= vo.in_ready;
    out_valid                   <= vo.out_valid;
    out_data                    <= vo.out_data;
    out_count                   <= vo.out_count;
    out_strobe                  <= vo.out_strobe;
    out_last                    <= vo.out_last;

  end process;

end rtl;

