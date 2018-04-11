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

-- This unit generates first and last indices for index buffers, based on a
-- moving firstIdx
entity BufferWriterPreCmdGen is
  generic (
    ---------------------------------------------------------------------------
    -- Arrow metrics and configuration
    ---------------------------------------------------------------------------
    -- Index field width.
    INDEX_WIDTH                 : natural;

    -- Command stream control vector width.
    CMD_CTRL_WIDTH              : natural;

    -- Command stream tag width. This tag is propagated to the outgoing command
    -- stream and to the unlock stream. It is intended for chunk reference
    -- counting.
    CMD_TAG_WIDTH               : natural
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    cmdIn_valid                 : in  std_logic;
    cmdIn_ready                 : out std_logic;
    cmdIn_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdIn_implicit              : in  std_logic;
    cmdIn_ctrl                  : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    cmdIn_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    cmdOut_valid                : out std_logic;
    cmdOut_ready                : in  std_logic;
    cmdOut_firstIdx             : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdOut_lastIdx              : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmdOut_implicit             : out std_logic;
    cmdOut_ctrl                 : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    cmdOut_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0)
  );
end BufferWriterPreCmdGen;

architecture Behavioral of BufferWriterPreCmdGen is
  type reg_type is record
    valid                       : std_logic;
    firstIdx                    : std_logic_vector(INDEX_WIDTH-1 downto 0);
    lastIdx                     : std_logic_vector(INDEX_WIDTH-1 downto 0);
    implicit                    : std_logic;
    ctrl                        : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
    tag                         : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);


    first                       : std_logic;
  end record;

  type in_type is record
    ready                       : std_logic;
  end record;

  signal r : reg_type;
  signal d : reg_type;

begin

  seq_proc: process(clk) is
  begin
    if rising_edge(clk) then
      
      r <= d;
      
      -- Reset
      if reset = '1' then
        r.first <= '0';
        r.valid <= '0';
      end if;
      
    end if;
  end process;

  comb_proc: process(r,
    cmdIn_valid,
    cmdIn_firstIdx,
    cmdIn_implicit,
    cmdIn_ctrl,
    cmdIn_tag,
    cmdOut_ready)
  is
    variable v: reg_type;
    variable i: in_type;
  begin
    v                           := r;

    -- Default outputs

    -- Input is ready by default
    i.ready                     := '1';

    -- If the output is valid, but not handshaked, the input must be stalled
    -- immediately
    if v.valid = '1' and cmdOut_ready = '0' then
      i.ready                   := '0';
    end if;

    -- If the output is handshaked, but there is no new data
    if v.valid = '1' and cmdOut_ready = '1' and cmdIn_valid = '0' then
      -- Invalidate the output
      v.valid                   := '0';
    end if;

    -- If the input is valid, and the output has no data or is handshaked
    -- we may advance the stream
    if cmdIn_valid = '1' and
       (v.valid = '0' or (v.valid = '1' and cmdOut_ready = '1'))
    then
      -- Register the inputs, but take the first index from the previous 
      -- last index.
      v.firstIdx                := r.lastIdx;
      v.lastIdx                 := cmdIn_firstIdx;
      v.implicit                := cmdIn_implicit;
      v.ctrl                    := cmdIn_ctrl;
      v.tag                     := cmdIn_tag;

      -- Validate the output if this is not the first element
      if v.first = '1' then
        v.valid                 := '1';
      end if;
      
      v.first                   := '1';
    end if;

    -- Registered output
    d                           <= v;

    -- Combinatorial output
    cmdIn_ready                 <= i.ready;

  end process;
  
  -- Connect registered outputs
  cmdOut_valid                  <= r.valid;
  cmdOut_firstIdx               <= r.firstIdx;
  cmdOut_lastIdx                <= r.lastIdx;
  cmdOut_implicit               <= r.implicit;
  cmdOut_ctrl                   <= r.ctrl;
  cmdOut_tag                    <= r.tag;

end Behavioral;
