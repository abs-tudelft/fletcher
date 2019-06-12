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
use work.UtilConv_pkg.all;
use work.UtilMisc_pkg.all;

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

    -- Whether this is a normal buffer or an offsets buffer.
    IS_OFFSETS_BUFFER           : boolean;

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
    -- are indexed by this offsets buffer.
    CMD_CTRL_WIDTH              : natural;

    -- Command stream tag width. This tag is propagated to the outgoing command
    -- stream and to the unlock stream. It is intended for chunk reference
    -- counting.
    CMD_TAG_WIDTH               : natural;
    
    -- Whether to check if the last index is exceeded by the user input stream.
    -- Currently works in simulation only.
    CHECK_LAST_EXCEED           : boolean := false;
    
    -- Whether to insert a slice at the output stream
    OUT_SLICE                   : boolean := true

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
    cmdIn_ctrl                  : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    cmdIn_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    ---------------------------------------------------------------------------
    -- Data stream
    ---------------------------------------------------------------------------
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    in_dvalid                   : in  std_logic;
    in_count                    : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    in_last                     : in  std_logic;

    ---------------------------------------------------------------------------
    -- Output stream
    ---------------------------------------------------------------------------
    -- If this is an offsets buffer;
    -- * out_clear is used to clear the accumulator ahead in the stream 
    -- * out_last_npad (last not padded) is used to assert the cmd_last signal
    --   of the command stream generator
    
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    out_strobe                  : out std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
    out_last                    : out std_logic;
    out_clear                   : out std_logic;
    out_implicit                : out std_logic;
    out_ctrl                    : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    out_tag                     : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
    out_last_npad               : out std_logic
  );
end BufferWriterPrePadder;

architecture rtl of BufferWriterPrePadder is

  -- Pre-sliced output stream
  signal int_out_valid          : std_logic;
  signal int_out_ready          : std_logic;
  signal int_out_data           : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal int_out_count          : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal int_out_strobe         : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
  signal int_out_clear          : std_logic;
  signal int_out_last           : std_logic;
  signal int_out_implicit       : std_logic;
  signal int_out_ctrl           : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
  signal int_out_tag            : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal int_out_last_npad      : std_logic;
  
  -- Output stream serialization indices.
  constant OSI : nat_array := cumulative((
    8 => 1,
    7 => ELEMENT_COUNT_MAX*ELEMENT_WIDTH,
    6 => ELEMENT_COUNT_WIDTH,
    5 => ELEMENT_COUNT_MAX,
    4 => 1,
    3 => 1,
    2 => 1,
    1 => CMD_CTRL_WIDTH,
    0 => CMD_TAG_WIDTH
  ));
  
  signal out_all                : std_logic_vector(OSI(9)-1 downto 0);
  signal int_out_all            : std_logic_vector(OSI(9)-1 downto 0);
  
  -- Helper constants
  constant ELEM_PER_BURST_STEP  : natural := (BUS_BURST_STEP_LEN * BUS_DATA_WIDTH) / ELEMENT_WIDTH;

  constant INDEX_ZERO           : unsigned(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0) := (others => '0');

  constant STROBE_NONE          : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0) := (others => '0');
  constant STROBE_FIRST         : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0) := std_logic_vector(to_unsigned(1, ELEMENT_COUNT_MAX));
  constant STROBE_ALL           : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0) := (others => '1');

  constant COUNT_ONE            : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(1, ELEMENT_COUNT_WIDTH));
  
  -- A count of all zeros is equal to the max count, because of the implicit '1' bit in front
  constant COUNT_ALL            : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0) := (others => '0');

  type state_type is (IDLE, INDEX, PRE, PASS, POST);

  type index_record is record
    first                       : unsigned(INDEX_WIDTH-1 downto 0);
    current                     : unsigned(INDEX_WIDTH-1 downto 0);
    last                        : unsigned(INDEX_WIDTH-1 downto 0);
    final                       : unsigned(INDEX_WIDTH-1 downto 0);
  end record;

  type tags_record is record
    implicit                    : std_logic;
    ctrl                        : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    tag                         : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  end record;

  type regs_record is record
    state                       : state_type;
    index                       : index_record;
    tags                        : tags_record;
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
    out_clear                   : std_logic;
    out_last_npad               : std_logic;
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

  comb: process(r, 
    cmdIn_valid, cmdIn_firstIdx, cmdIn_lastIdx, cmdIn_implicit, cmdIn_ctrl, cmdIn_tag,
    int_out_ready, 
    in_data, in_count, in_valid, in_last
  ) is
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
    vo.out_clear                := '0';
    vo.out_strobe               := STROBE_ALL;
    vo.out_count                := COUNT_ALL;
    vo.out_data                 := in_data;
    vo.out_last_npad            := '0';

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
          -- Register the first index and last index.
          vr.index.first        := u(cmdIn_firstIdx);
          vr.index.last         := u(cmdIn_lastIdx);
          
          -- The first index to work on is the aligned below or equal of the 
          -- first index.
          vr.index.current      := alignDown(u(cmdIn_firstIdx), log2ceil(ELEM_PER_BURST_STEP));
          
          -- Register the tags
          vr.tags.implicit      := cmdIn_implicit;
          vr.tags.ctrl          := cmdIn_ctrl;
          vr.tags.tag           := cmdIn_tag;

          -- Go to the next state
          vr.state            := PRE;
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
          if int_out_ready = '1' then
            vr.index.current    := vr.index.current + 1;
          end if;
        else
          vo.out_valid          := '0';
        end if;
        
        if vr.index.current = vr.index.first then
          -- Advance state depending if this is an offsets buffer or not
          if IS_OFFSETS_BUFFER then
            -- If the first index is zero, then we are streaming in at the
            -- start of the offsets buffer. If a user for whatever reason wants
            -- to write to some other index in the buffer, we don't prepepend
            -- a "zero", so the INDEX state can be skipped.
            if vr.index.first = 0 then
              vr.state            := INDEX;
            end if;
          else
            vr.state              := PASS;
          end if;
        end if;
        
      -------------------------------------------------------------------------
      when INDEX =>
      -------------------------------------------------------------------------
        -- For offsets buffers, we insert one element
        vo.out_data             := slv(INDEX_ZERO);
        vo.out_count            := COUNT_ONE;
        vo.out_strobe           := STROBE_FIRST;
        vo.out_valid            := '1';
        vo.out_clear            := '1';

        -- Advance state if no backpressure
        if int_out_ready = '1' then
          vr.index.current    := vr.index.current + 1;
          vr.state              := PASS;
        end if;
        
      -------------------------------------------------------------------------
      when PASS =>
      -------------------------------------------------------------------------
        -- Pass through input
        vo.in_ready             := int_out_ready;
        vo.out_valid            := in_valid;
        vo.out_data             := in_data;
        vo.out_last             := '0';
        vo.out_count            := in_count;
        vo.out_last_npad        := in_last;
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
           in_valid = '1' and  int_out_ready = '1' and
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
          if isAligned(new_index, log2ceil(ELEM_PER_BURST_STEP)) then
            vo.out_last         := '1';
          end if;
        end if;
        
        -- Determine the final index based on the current index, so it will
          -- be ready for the next state
        vr.index.final          := alignUp(new_index,
                                           log2ceil(ELEM_PER_BURST_STEP));

        -- Advance state if no backpressure and a valid input was passed
        if int_out_ready = '1' and vo.out_valid = '1' then
          vr.index.current      := new_index;
          
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
        
        -- Make data unkown in simulation
        --pragma translate off
        vo.out_data             := (others => 'U');
        --pragma translate on
                
        -- Only validate if we actually have to append
        if vr.index.current /= vr.index.final then
          
          vo.out_valid          := '1';
          
          -- Advance state if no backpressure
          if int_out_ready = '1' then
            vr.index.current    := vr.index.current + 1;
          end if;
        else
          vo.out_valid          := '0';
        end if;
        
        -- Only assert last if the current index is aligned
        if isAligned(vr.index.current, log2ceil(ELEM_PER_BURST_STEP)) then
          vo.out_last           := '1';
          vr.state              := IDLE;
        end if;
    end case;
    
    -- Outputs to be registered
    d                           <= vr;

    -- Connect outputs to the input streams
    cmdIn_ready                 <= vo.cmdIn_ready;
    in_ready                    <= vo.in_ready;

    -- Connect outputs to the output stream
    int_out_valid               <= vo.out_valid;
    int_out_data                <= vo.out_data;
    int_out_count               <= vo.out_count;
    int_out_strobe              <= vo.out_strobe;
    int_out_last                <= vo.out_last;
    int_out_clear               <= vo.out_clear;
    int_out_last_npad           <= vo.out_last_npad;
    
    -- The tags can be taken from the register as they are determined only in
    -- idle, when the output is not valid
    int_out_implicit            <= vr.tags.implicit;
    int_out_ctrl                <= vr.tags.ctrl;
    int_out_tag                 <= vr.tags.tag;    

  end process;
  
  -- Insert a register slice
  
  int_out_all(                OSI(8)) <= int_out_last_npad;
  int_out_all(OSI(8)-1 downto OSI(7)) <= int_out_data;
  int_out_all(OSI(7)-1 downto OSI(6)) <= int_out_count;
  int_out_all(OSI(6)-1 downto OSI(5)) <= int_out_strobe;
  int_out_all(                OSI(4)) <= int_out_last;
  int_out_all(                OSI(3)) <= int_out_clear;
  int_out_all(                OSI(2)) <= int_out_implicit;
  int_out_all(OSI(2)-1 downto OSI(1)) <= int_out_ctrl;
  int_out_all(OSI(1)-1 downto OSI(0)) <= int_out_tag;
  
  out_slice_inst : StreamBuffer
    generic map (
      MIN_DEPTH                 => sel(OUT_SLICE, 2, 0),
      DATA_WIDTH                => OSI(9)
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => int_out_valid,
      in_ready                  => int_out_ready,
      in_data                   => int_out_all,
      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_data                  => out_all
    );
  out_last_npad                 <= out_all(                OSI(8));
  out_data                      <= out_all(OSI(8)-1 downto OSI(7));
  out_count                     <= out_all(OSI(7)-1 downto OSI(6));
  out_strobe                    <= out_all(OSI(6)-1 downto OSI(5));
  out_last                      <= out_all(                OSI(4));
  out_clear                     <= out_all(                OSI(3));
  out_implicit                  <= out_all(                OSI(2));
  out_ctrl                      <= out_all(OSI(2)-1 downto OSI(1));
  out_tag                       <= out_all(OSI(1)-1 downto OSI(0));

end rtl;

