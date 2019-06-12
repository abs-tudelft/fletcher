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

entity BufferReaderRespCtrl is
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

    -- Width of the internal command stream shift vector. Should equal
    -- max(1, log2(BUS_WIDTH / ELEMENT_WIDTH))
    ICS_SHIFT_WIDTH             : natural;

    -- Width of the internal command stream count vector. Should equal
    -- max(1, log2(BUS_WIDTH / ELEMENT_WIDTH) + 1)
    ICS_COUNT_WIDTH             : natural;
       
    -- Buffer element width in bits.
    ELEMENT_WIDTH               : natural;

    -- Command stream control vector width. This vector is propagated to the
    -- outgoing command stream, but isn't used otherwise. It is intended for
    -- control flags and base addresses for BufferReaders reading buffers that
    -- are indexed by this offsets buffer.
    CMD_CTRL_WIDTH              : natural;

    -- Command stream tag width. This tag is propagated to the outgoing command
    -- stream and to the unlock stream. It is intended for chunk reference
    -- counting.
    CMD_TAG_WIDTH               : natural;

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
    -- Command stream input (bus clock domain). firstIdx and lastIdx represent
    -- a range of elements to be fetched from memory. firstIdx is inclusive,
    -- lastIdx is exclusive for normal buffers and inclusive for offsets 
    -- buffers, in all cases resulting in lastIdx - firstIdx elements. 
    -- baseAddr is the pointer to the first element in the buffer.
    cmdIn_valid                 : in  std_logic;
    cmdIn_ready                 : out std_logic;
    cmdIn_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_implicit              : in  std_logic;
    cmdIn_ctrl                  : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    cmdIn_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    ---------------------------------------------------------------------------
    -- Output stream
    ---------------------------------------------------------------------------
    -- Internal command stream with control signals for the bus response data
    -- path. One word will be transmitted for each bus burst beat or for each
    -- element, whichever is less frequent.
    intCmd_valid                : out std_logic;
    intCmd_ready                : in  std_logic;
    intCmd_implicit             : out std_logic;
    intCmd_shift                : out std_logic_vector(ICS_SHIFT_WIDTH-1 downto 0);
    intCmd_count                : out std_logic_vector(ICS_COUNT_WIDTH-1 downto 0);
    intCmd_init                 : out std_logic;
    intCmd_last                 : out std_logic;
    intCmd_ctrl                 : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    intCmd_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0)

  );
end BufferReaderRespCtrl;

architecture rtl of BufferReaderRespCtrl is

  -- Sliced output
  signal intCmd_s_valid         : std_logic;
  signal intCmd_s_ready         : std_logic;
  signal intCmd_s_implicit      : std_logic;
  signal intCmd_s_shift         : std_logic_vector(ICS_SHIFT_WIDTH-1 downto 0);
  signal intCmd_s_count         : std_logic_vector(ICS_COUNT_WIDTH-1 downto 0);
  signal intCmd_s_init          : std_logic;
  signal intCmd_s_last          : std_logic;
  signal intCmd_s_ctrl          : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
  signal intCmd_s_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
   
  constant ICI : nat_array := cumulative((
    6 => 1,
    5 => intCmd_shift'length,
    4 => intCmd_count'length,
    3 => 1,
    2 => 1,
    1 => intCmd_ctrl'length,
    0 => intCmd_tag'length
  ));

  signal intCmd_s               : std_logic_vector(ICI(ICI'high)-1 downto 0);
  signal intCmd                 : std_logic_vector(ICI(ICI'high)-1 downto 0);

  -- Word alignment helper constants:
  
  -- Number of elements in a word
  constant WA_ELEMENTS          : natural := BUS_DATA_WIDTH / ELEMENT_WIDTH;
  
  constant SHIFT_ZERO           : unsigned(ICS_SHIFT_WIDTH-1 downto 0)  := (others => '0');
  constant SHIFT_MAX            : unsigned(ICS_SHIFT_WIDTH-1 downto 0)  := (others => '1');
  constant COUNT_ALL            : unsigned(ICS_COUNT_WIDTH-1 downto 0)  := to_unsigned(WA_ELEMENTS, ICS_COUNT_WIDTH);
  constant COUNT_NONE           : unsigned(ICS_COUNT_WIDTH-1 downto 0)  := (others => '0');
  constant COUNT_ONE            : unsigned(ICS_COUNT_WIDTH-1 downto 0)  := to_unsigned(1, ICS_COUNT_WIDTH);
  
  -- Burst alignment helper constants:
    
  -- Number of elements in a burst
  constant BA_ELEMENTS          : natural := BUS_BURST_STEP_LEN * WA_ELEMENTS;
  
  -- Number of bits to drop from an index to get the burst aligned index
  constant BA_IDX_BITS          : natural := imax(1, log2ceil(BA_ELEMENTS));
  constant BA_IDX_ZEROS         : unsigned(BA_IDX_BITS-1 downto 0) := (others => '0');
  

  type state_type is (IDLE, INDEX_PRE, INDEX, INDEX_POST, DATA_PRE, DATA, DATA_POST);

  type input_record is record
    ready                       : std_logic;
  end record;

  constant input_reset : input_record := (ready => '0');

  type command_record is record
    implicit                    : std_logic;
    shift                       : unsigned(ICS_SHIFT_WIDTH-1 downto 0);
    count                       : unsigned(ICS_COUNT_WIDTH-1 downto 0);
    last                        : std_logic;
    init                        : std_logic;
    ctrl                        : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    tag                         : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
    valid                       : std_logic;
  end record;

  constant command_reset : command_record := (
    implicit                    => '0',
    shift                       => (others => '0'),
    count                       => (others => '0'),
    last                        => '0',
    init                        => '0',
    ctrl                        => (others => '0'),
    tag                         => (others => '0'),
    valid                       => '0'
  );

  type element_record is record
    first                       : unsigned(INDEX_WIDTH-1 downto 0);
    last                        : unsigned(INDEX_WIDTH-1 downto 0);
    
    ba_first                    : unsigned(INDEX_WIDTH-1 downto 0);
    ba_last                     : unsigned(INDEX_WIDTH-1 downto 0);
    
    wa_first                    : unsigned(INDEX_WIDTH-1 downto 0);
    wa_last                     : unsigned(INDEX_WIDTH-1 downto 0);
    
    real_last                   : unsigned(INDEX_WIDTH-1 downto 0);
    
    -- Index Burst Element
    ibe                         : unsigned(BA_IDX_BITS-1 downto 0);
    idx_wa_last                 : unsigned(INDEX_WIDTH-1 downto 0);
    
    current                     : unsigned(INDEX_WIDTH-1 downto 0);
  end record;

  constant element_reset : element_record := (others => (others => '0'));

  type tags_record is record
    implicit                    : std_logic;
    ctrl                        : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    tag                         : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  end record;

  constant tags_reset : tags_record := (
    implicit                    => '0',
    ctrl                        => (others => '0'),
    tag                         => (others => '0')
  );

  type regs_record is record
    state                       : state_type;
    element                     : element_record;
    tags                        : tags_record;
    input                       : input_record;
    command                     : command_record;
  end record;

  signal r                      : regs_record;
  signal d                      : regs_record;
    
begin

  -----------------------------------------------------------------------------
  -- State machine sequential part
  -----------------------------------------------------------------------------
  sm_seq: process (clk) is
  begin
    if rising_edge(clk) then
    
      r                         <= d;
      
      if reset = '1' then
        r.state                 <= IDLE;
        r.tags                  <= tags_reset;
        r.input                 <= input_reset;
        r.command               <= command_reset;
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- State machine combinatorial part
  -----------------------------------------------------------------------------
  sm_comb: process (
    r, 
    cmdIn_valid, cmdIn_firstIdx, cmdIn_lastIdx, cmdIn_implicit, cmdIn_ctrl, cmdIn_tag, 
    intCmd_s_ready
  ) is
    variable v                  : regs_record;
  begin
    v                           := r;

    -- Handshaking defaults:
    v.input.ready               := '0';

    -- Internal Command Stream defaults
    v.command.valid             := '0';
    v.command.init              := '0';
    v.command.shift             := SHIFT_ZERO;
    v.command.count             := COUNT_NONE;
    v.command.last              := '0';
    v.command.ctrl              := v.tags.ctrl;
    v.command.tag               := v.tags.tag;
    v.command.implicit          := v.tags.implicit;

    -- States:
    case v.state is
      when IDLE =>
        -- We are ready to receive some new input
        v.input.ready           := '1';
        
        if (cmdIn_Valid = '1') and (cmdIn_firstIdx /= cmdIn_lastIdx) then
          -- Get the tags
          v.tags.ctrl           := cmdIn_ctrl;
          v.tags.tag            := cmdIn_tag; 
          v.tags.implicit       := cmdIn_implicit; 
          
          -- Set the first and last index
          v.element.first       := u(cmdIn_firstIdx);
          v.element.last        := u(cmdIn_lastIdx);

          v.element.real_last   := u(cmdIn_lastIdx);
                   
          if IS_OFFSETS_BUFFER then
            if ICS_COUNT_WIDTH = 1 then
              v.element.idx_wa_Last := v.element.last;
            else
              v.element.idx_wa_Last := v.element.last(INDEX_WIDTH-1 downto ICS_SHIFT_WIDTH) & SHIFT_ZERO;
            end if;
            
            v.element.last      := v.element.last + 1;
          end if;
          
          -- Burst alignment: figure out the burst aligned index --------------
          
          -- Set the burst aligned first element index
          if BA_ELEMENTS = 1 then
            v.element.ba_first  := v.element.first;
          else
            v.element.ba_first  := v.element.first(INDEX_WIDTH-1 downto BA_IDX_BITS) & BA_IDX_ZEROS;
          end if;
          
          -- Set the burst aligned last element index
          if (v.element.last(BA_IDX_BITS-1 downto 0) = BA_IDX_ZEROS) or (BA_ELEMENTS = 1) then 
            -- The last index is already aligned to a burst
            v.element.ba_last   := v.element.last;
          else 
            -- The last index is not yet aligned to a burst, align it and round up
            v.element.ba_last   := (v.element.last(INDEX_WIDTH-1 downto BA_IDX_BITS) + 1) & BA_IDX_ZEROS;
          end if;
          
          -- Word alignment: figure out the word aligned index ----------------
          
          -- Set the word aligned first and last element indices
          if ICS_COUNT_WIDTH = 1 then
            v.element.wa_first  := v.element.first;
          else
            v.element.wa_first  := v.element.first(INDEX_WIDTH-1 downto ICS_SHIFT_WIDTH) & SHIFT_ZERO;
          end if;
          
          -- Set the word aligned last element index
          if (v.element.last(ICS_SHIFT_WIDTH-1 downto 0) = SHIFT_ZERO) or (ICS_COUNT_WIDTH = 1) then
            -- The last index is already aligned to a word
            v.element.wa_last   := v.element.last;
          else
            -- The last index is not yet aligned to a word, align it and round up
            v.element.wa_last   := (v.element.last(INDEX_WIDTH-1 downto ICS_SHIFT_WIDTH) + 1) & SHIFT_ZERO;
          end if;
          
          
          -- Set the current element to the first element in the burst
          v.element.current     := v.element.ba_first;
          
          -- Go to state to throw away useless data before useful data in the 
          -- burst
          v.state               := DATA_PRE;

          -- If the word aligned element is also the burst aligned element, 
          -- then we don't have to throw away data and we can skip the DATA_PRE
          -- state.
          if (v.element.current = v.element.wa_first) or (BA_ELEMENTS = 1) then
            v.state             := DATA;
          end if;
          
          -- Offsets buffers ----------------------------------------------------
          
          if IS_OFFSETS_BUFFER then
            -- Set index burst element to 0
            v.element.ibe       := (others => '0');
            
            v.state             := INDEX_PRE;
            
            -- If the last element index is already aligned with a burst 
            -- aligned index, we don't have to throw away data and we can skip
            -- the INDEX_PRE state
            -- Check if we are at the last index word yet
            if (v.element.ibe = v.element.idx_wa_last(BA_IDX_BITS-1 downto 0)) or (BA_ELEMENTS = 1) then
              v.state           := INDEX;
            end if;
          end if;
          
        end if;
        
      -- State for words that don't contain requested indices but are being 
      -- streamed in before due to burst alignment
      when INDEX_PRE =>
        -- The command is valid, but other signals are zeroed as this word 
        -- doesn't contain any useful data
        v.command.valid         := '1';
        
        -- Back-pressure
        if intCmd_s_ready = '1' then
          v.element.ibe         := v.element.ibe + WA_ELEMENTS;
          -- Check if we are at the last index word yet
          if v.element.ibe = v.element.idx_wa_last(BA_IDX_BITS-1 downto 0) then
            v.state             := INDEX;
          end if;
        end if;
      
      -- State for the last index word
      when INDEX =>
        v.command.valid         := '1';
        v.command.last          := '0';
        v.command.init          := '1';
        v.command.count         := COUNT_NONE;
        
        if ICS_COUNT_WIDTH > 1 then
          v.command.shift       := v.element.real_last(intCmd_shift'range);
        else
          v.command.shift       := SHIFT_ZERO;
        end if;
                
        if intCmd_s_ready = '1' then
          v.element.ibe         := v.element.ibe + WA_ELEMENTS;
          v.state               := INDEX_POST;
          
          -- If the counter wrapped, we are done with the index burst, or if there is only
          -- one element in a burst
          if (v.element.ibe = BA_IDX_ZEROS) or (BA_ELEMENTS = 1) then
            -- Go to state to throw away useless data before useful data in the burst
            v.state             := DATA_PRE;
            -- If the word aligned element is also the burst aligned element, 
            -- then we don't have to throw away data and we can skip the DATA_PRE state.
            if (v.element.current = v.element.wa_first) or (BA_ELEMENTS = 1) then
              v.state           := DATA;
            end if;
          end if;
        end if;
        
      -- State for the rest of the index words in the burst
      when INDEX_POST =>
        -- The command is valid, but other signals are zeroed as this word 
        -- doesn't contain any useful data
        v.command.valid         := '1';
        
        if intCmd_s_ready = '1' then
          v.element.ibe         := v.element.ibe + WA_ELEMENTS;
          
          -- If the counter wrapped, we are done with the index burst
          if v.element.ibe = BA_IDX_ZEROS then
          
            -- Go to state to throw away useless data before useful data in the burst
            v.state             := DATA_PRE;

            -- If the word aligned element is also the burst aligned element, 
            -- then we don't have to throw away data and we can skip the DATA_PRE state.
            if v.element.current = v.element.wa_first then
              v.state           := DATA;
            end if;
            
          end if;
        end if;       
      
      -- State for words that don't contain requested elements but are being
      -- streamed in before due to burst alignment
      when DATA_PRE =>
        -- The command is valid, but other signals are zeroed as this word 
        -- doesn't contain any useful data
        v.command.valid         := '1';

        -- Back-pressure
        if intCmd_s_ready = '1' then 
          -- Increment the current element
          v.element.current     := v.element.current + WA_ELEMENTS;
                  
          -- Check if the next word is the last burst pre-alignment word
          if v.element.current = v.element.wa_first then
            v.state             := DATA;
          end if;
        end if;
        
      -- Words that contain requested elements
      when DATA =>
        -- The command is valid
        v.command.valid         := '1';
        
        -- All elements are valid by default
        v.command.count         := COUNT_ALL;        
        -- Not shifting by default
        v.command.shift         := SHIFT_ZERO;
        -- Not the last word by default
        v.command.last          := '0';
        
        -- Special case: this is the first word -------------------------------
        if v.element.current = v.element.wa_first then
          v.command.init        := '1';
          
          if ICS_COUNT_WIDTH > 1 then 
            -- The shift amount is equal to the LSBs of the first word.
            v.command.shift     := v.element.first(intCmd_shift'range); 
            -- No. valid elements for first request are the number of elements per 
            -- word minus the number of elements to shift. 
            v.command.count     := COUNT_ALL - v.command.shift; 
          else
            v.command.shift     := SHIFT_ZERO;
            v.command.count     := COUNT_ONE;
          end if;          
        end if;
        
        -- Special case: this is the last word --------------------------------
        if v.element.current + WA_ELEMENTS = v.element.wa_last then
          v.command.last        := '1';
          
          if ICS_COUNT_WIDTH > 1 then 
            -- Because the start of the requests in this state is aligned with 
            -- word boundaries, the count is simply the LSBs of the last element. 
            v.command.count     := "0" & r.element.last(intCmd_shift'range); 

            -- If this resulted in zero, then we are requesting a full word. 
            if v.command.count = COUNT_NONE then 
              v.command.count   := COUNT_ALL - v.command.shift;
            end if;
          
            -- Special special case: this is the first AND last word ----------
            -- Note the use of the r.element and not v.element
            if r.element.current = v.element.wa_first then
              -- The count is the difference in element index within this 
              -- single word. 
              v.command.count   := "0" & (v.element.last(intCmd_shift'range) 
                                   - v.element.first(intCmd_shift'range)); 

              -- If the subtraction resulted in zero, then we are requesting 
              -- a full word. 
              if v.command.count = COUNT_NONE then 
                v.command.count := COUNT_ALL; 
              end if;
            end if;
          end if;
        end if;

        -- Back-pressure, only advance when intCmd is ready
        if intCmd_s_ready = '1' then 
          -- Increment the current element
          v.element.current     := v.element.current + WA_ELEMENTS;
        
          -- Special case: last word ------------------------------------------
          if v.element.current = v.element.wa_last then                          
            v.state             := DATA_POST;
            
            -- Check if the next word is the last burst post-alignment word
            if v.element.current = v.element.ba_last then
              v.state           := IDLE;
            end if;
          end if;
        end if;
        
      -- Words that don't contain requested elements but are being
      -- streamed in afterwards due to burst alignment
      when DATA_POST =>
        -- The command is valid, but other signals are zeroed as this word 
        -- doesn't contain any useful data
        v.command.valid         := '1';
        
        -- Back-pressure
        if intCmd_s_ready = '1' then 
        
          -- Increment the current element
          v.element.current     := v.element.current + WA_ELEMENTS;
          
          -- Check if the next word is the last burst post-alignment word
          if v.element.current = v.element.ba_last then
            v.state             := IDLE;
          end if;
        end if;

    end case;

    d                           <= v;

  end process;
  
  cmdIn_ready                   <= d.input.ready;
  
  -- Output slice inputs
  intCmd_s_implicit             <= d.command.implicit;
  intCmd_s_shift                <= std_logic_vector(d.command.shift);
  intCmd_s_count                <= std_logic_vector(d.command.count);
  intCmd_s_init                 <= d.command.init;
  intCmd_s_last                 <= d.command.last;
  intCmd_s_ctrl                 <= d.command.ctrl;
  intCmd_s_tag                  <= d.command.tag;
  intCmd_s_valid                <= d.command.valid;
  
  intCmd_s(                ICI(6)) <= intCmd_s_implicit;
  intCmd_s(ICI(6)-1 downto ICI(5)) <= intCmd_s_shift   ;
  intCmd_s(ICI(5)-1 downto ICI(4)) <= intCmd_s_count   ;
  intCmd_s(                ICI(3)) <= intCmd_s_init    ;
  intCmd_s(                ICI(2)) <= intCmd_s_last    ;
  intCmd_s(ICI(2)-1 downto ICI(1)) <= intCmd_s_ctrl    ;
  intCmd_s(ICI(1)-1 downto ICI(0)) <= intCmd_s_tag     ;
  --
  -- Output slice
  out_slice : StreamSlice generic map (
      DATA_WIDTH                => ICI(ICI'high)
    ) port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => intCmd_s_valid,
      in_ready                  => intCmd_s_ready,
      in_data                   => intCmd_s,
      out_valid                 => intCmd_valid,
      out_ready                 => intCmd_ready,
      out_data                  => intCmd
    );
  
  --intCmd_valid <= intCmd_s_valid;
  --intCmd_s_ready <= intCmd_ready;
  --intCmd <= intCmd_s;
  
  -- Output
  intCmd_implicit               <= intCmd(                ICI(6));
  intCmd_shift                  <= intCmd(ICI(6)-1 downto ICI(5));
  intCmd_count                  <= intCmd(ICI(5)-1 downto ICI(4));
  intCmd_init                   <= intCmd(                ICI(3));
  intCmd_last                   <= intCmd(                ICI(2));
  intCmd_ctrl                   <= intCmd(ICI(2)-1 downto ICI(1));
  intCmd_tag                    <= intCmd(ICI(1)-1 downto ICI(0));
  
  -- pragma translate_off
  valid_deassert_check: process is
    variable valid_prev         : std_logic := '0';
    variable ready_prev         : std_logic := '0';
    variable reset_prev         : std_logic := '1';
    variable data_prev          : std_logic_vector(ICI(ICI'high)-1 downto 0);
  begin
    wait until rising_edge(clk);

    if    to_X01(ready_prev) = '0'
      and to_X01(valid_prev) = '1'
      and to_X01(intCmd_s_valid) = '0'
      and to_X01(reset_prev) = '0'
    then
      report "Valid released while ready low" severity FAILURE;
    end if;
    
    if to_X01(valid_prev) = '1' and to_X01(ready_prev) = '0' then
      assert intCmd_s = data_prev report "Data changed!" severity FAILURE;
    end if;

    valid_prev := intCmd_s_valid;
    ready_prev := intCmd_s_ready;
    reset_prev := reset;
    data_prev  := intCmd_s;
  end process;
  -- pragma translate_on
  
end rtl;

