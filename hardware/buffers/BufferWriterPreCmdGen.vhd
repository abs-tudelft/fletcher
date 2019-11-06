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

entity BufferWriterPreCmdGen is

  -- Generates a command stream for the child buffer of an offsets buffer.

  generic (

    -- Width of an offset.
    OFFSET_WIDTH                : natural := 32;

    -- Maximum number of offsets per clock in the data input stream.
    COUNT_MAX                   : natural := 1;

    -- The number of bits in the count vectors. This must be at least
    -- ceil(log2(COUNT_MAX)) and must be at least 1. If COUNT_MAX is a power of
    -- two and this value equals log2(COUNT_MAX), a zero count implies that all
    -- entries are valid (i.e., there is an implicit '1' bit in front).
    COUNT_WIDTH                 : natural := 1;

      -- Command stream control vector width.
    CMD_CTRL_WIDTH              : natural := 1;

    -- Command stream tag width. This tag is propagated to the outgoing command
    -- stream and to the unlock stream. It is intended for chunk reference
    -- counting.
    CMD_TAG_WIDTH               : natural := 1;

    ---------------------------------------------------------------------------
    -- Command generation mode.
    ---------------------------------------------------------------------------
    -- If MODE is not set, the first handshake will produce a single output
    -- command with:
    --
    --   cmdOut_firstIdx[0] = in_data[least significant element]
    --   cmdOut_lastIdx[0]  = 0
    --
    -- After that, all other input data is accepted but ignored, until in_last
    -- is asserted.
    --
    -- BufferWriter commands may have a last index set to zero, if at time of
    -- command issue, the number of values that will be written are still
    -- unknown (i.e. we don't know when we will "close" the buffer).
    --
    -- If MODE is set to "cthulhu", for whatever exotic reason, this unit
    -- applies a two-value sliding window over the input stream to generate an
    -- output command with:
    --
    --   cmdOut_firstIdx = in_data[i-1]
    --   cmdOut_lastIdx  = in_data[i]
    --
    -- This implies that the input stream must always deliver at least two
    -- offsets at the input before this unit can generate an output command.
    --
    -- Since command streams do not support multiple commands per cycle, this
    -- unit will first serialize any multiple-offsets-per-cycle input streams,
    -- backpressuring the input stream and probably cause terrible performance,
    -- not only because its own bandwidth might be limited but more importantly
    -- because the child buffer will receive a new command for every list item.
    --
    -- Needless to say, "cthulhu" mode is not recommended unless you have a
    -- very very good reason to do so.
    MODE                        : string := ""

  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_offsets                  : in  std_logic_vector(COUNT_MAX*OFFSET_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(COUNT_WIDTH-1 downto 0);
    in_dvalid                   : in  std_logic;
    in_last                     : in  std_logic;
    in_ctrl                     : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    in_tag                      : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    cmdOut_valid                : out std_logic;
    cmdOut_ready                : in  std_logic;
    cmdOut_firstIdx             : out std_logic_vector(OFFSET_WIDTH-1 downto 0);
    cmdOut_lastIdx              : out std_logic_vector(OFFSET_WIDTH-1 downto 0);
    cmdOut_implicit             : out std_logic;
    cmdOut_ctrl                 : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    cmdOut_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0)
  );
end BufferWriterPreCmdGen;

architecture Behavioral of BufferWriterPreCmdGen is
  type reg_type is record
    valid                       : std_logic;
    firstIdx                    : std_logic_vector(OFFSET_WIDTH-1 downto 0);
    lastIdx                     : std_logic_vector(OFFSET_WIDTH-1 downto 0);
    implicit                    : std_logic;
    ctrl                        : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    tag                         : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
    had_first                   : std_logic;
  end record;

  type comb_type is record
    ready                       : std_logic;
  end record;

  signal r : reg_type;
  signal d : reg_type;
  signal c : comb_type;

  -- Concatenate ctrl and tag
  signal in_ctrl_tag            : std_logic_vector(CMD_CTRL_WIDTH + CMD_TAG_WIDTH -1 downto 0);
  signal sin_ctrl_tag           : std_logic_vector(CMD_CTRL_WIDTH + CMD_TAG_WIDTH -1 downto 0);

  -- Serialized input
  signal sin_valid              : std_logic;
  signal sin_ready              : std_logic;
  signal sin_offset             : std_logic_vector(OFFSET_WIDTH-1 downto 0);
  signal sin_dvalid             : std_logic;
  signal sin_last               : std_logic;
  signal sin_ctrl               : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
  signal sin_tag                : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Input stream serialization
  -----------------------------------------------------------------------------
  reshape_gen: if MODE = "cthulhu" and COUNT_MAX > 1 generate
  
    -- Concatenate ctrl and tag
    in_ctrl_tag <= in_ctrl & in_tag;
    
    reshaper_inst: StreamReshaper
      generic map (
        ELEMENT_WIDTH             => OFFSET_WIDTH,
        IN_COUNT_MAX              => COUNT_MAX,
        IN_COUNT_WIDTH            => COUNT_WIDTH,
        OUT_COUNT_MAX             => 1,
        OUT_COUNT_WIDTH           => 1,
        CTRL_WIDTH                => CMD_CTRL_WIDTH + CMD_TAG_WIDTH
      )
      port map (
        clk                       => clk,
        reset                     => reset,
        din_valid                 => in_valid,
        din_ready                 => in_ready,
        din_dvalid                => in_dvalid,
        din_data                  => in_offsets,
        din_count                 => in_count,
        din_last                  => in_last,
        cin_ctrl                  => in_ctrl_tag,
        out_valid                 => sin_valid,
        out_ready                 => sin_ready,
        out_dvalid                => sin_dvalid,
        out_data                  => sin_offset,
        out_last                  => sin_last,
        out_ctrl                  => sin_ctrl_tag
      );
    
    -- Unconcatenate ctrl and tag
    sin_ctrl <= sin_ctrl_tag(CMD_CTRL_WIDTH + CMD_TAG_WIDTH - 1 downto CMD_TAG_WIDTH);
    sin_tag <= sin_ctrl_tag(CMD_TAG_WIDTH - 1 downto 0);
    
  end generate;
  no_reshape_gen: if MODE /= "cthulhu" or COUNT_MAX = 1 generate
    sin_valid   <= in_valid;
    in_ready    <= sin_ready;
    sin_offset  <= in_offsets(OFFSET_WIDTH-1 downto 0);
    sin_dvalid  <= in_dvalid;
    sin_last    <= in_last;
    sin_ctrl    <= in_ctrl;
    sin_tag     <= in_tag;
  end generate;
  
  -----------------------------------------------------------------------------
  seq_proc: process(clk) is
  begin
    if rising_edge(clk) then
      r <= d;
      -- Reset
      if reset = '1' then
        r.had_first <= '0';
        r.valid <= '0';
        r.lastIdx <= (others => '0');
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  comb_proc: process(r,
    sin_valid, sin_offset, sin_dvalid, sin_last, sin_ctrl, sin_tag,
    cmdOut_ready)
  is
    variable v: reg_type;
  begin
    v := r;

    -- Default outputs
    v.valid := '0';

    -- Input is ready by default
    c.ready <= '1';

    -- If the output is valid, but not handshaked, the input must be stalled
    -- immediately
    if v.valid = '1' and cmdOut_ready = '0' then
      c.ready <= '0';
    end if;

    -- If the output is handshaked, but there is no new data
    if v.valid = '1' and cmdOut_ready = '1' and sin_valid = '0' then
      -- Invalidate the output
      v.valid := '0';
    end if;

    -- If the input is valid, and the output has no data or is handshaked we 
    -- may advance the stream. Furthermore, this unit only operates when dvalid 
    -- is asserted.
    if sin_valid = '1' and
       (v.valid = '0' or (v.valid = '1' and cmdOut_ready = '1')) and
       sin_dvalid = '1'
    then
      -- Register control and tag information.
      v.ctrl := sin_ctrl;
      v.tag  := sin_tag;
      
      -- Remember we have gotten at least one offset
      v.had_first := '1';

      -------------------------------------------------------------------------
      -- Default operation
      -------------------------------------------------------------------------
      if MODE = "" then
        if r.had_first = '0' then
          -- This is the first offset. Pass through the first offset, and 
          -- validate a single command with lastIdx = 0. In this case, the 
          -- child buffer will finish the command based on the last signal of 
          -- the input stream and not the lastIdx.
          v.firstIdx := sin_offset;
          v.lastIdx := (others => '0');
          v.valid := '1';
        else
          v.valid := '0';
        end if;
        
        -- When we have received the last offset, we may generate a new output
        -- command.
        if sin_last = '1' then
          v.had_first := '0';
        end if;
        
      -------------------------------------------------------------------------
      -- Cthulhu mode
      -------------------------------------------------------------------------
      elsif MODE = "cthulhu" then
        -- Validate the output if this is not the first element, we first need
        -- two valid offsets to determine the first range.
        if r.had_first = '1' then          
          v.firstIdx := r.lastIdx;
          v.lastIdx := sin_offset;
          v.valid := '1';
        end if;
      end if;

    end if;

    -- Registered output
    d                           <= v;

  end process;

  -- Connect combinatorial output
  sin_ready                     <= c.ready;

  -- Connect registered outputs
  cmdOut_valid                  <= r.valid;
  cmdOut_firstIdx               <= r.firstIdx;
  cmdOut_lastIdx                <= r.lastIdx;
  cmdOut_implicit               <= r.implicit;
  cmdOut_ctrl                   <= r.ctrl;
  cmdOut_tag                    <= r.tag;

end Behavioral;
