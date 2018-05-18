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

library work;
use work.Streams.all;

-- This unit counts the number of elements that have been handshaked. If the
-- last signal is asserted or the maixmum output count has been reached, the
-- output is validated.

-- Symbol: --->(+count)--->

entity StreamElementCounter is
  generic (
    -- Width of the count input. Must be at least one to prevent null ranges.
    IN_COUNT_WIDTH              : positive := 1;
    
    -- Maximum input count
    IN_COUNT_MAX                : positive := 1;
    
    -- Width of the count output.
    OUT_COUNT_WIDTH             : positive := 8;
    
    -- Maximum output count. Must be a power of 2
    OUT_COUNT_MAX               : positive := 256
  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_last                     : in  std_logic;
    in_count                    : in  std_logic_vector(IN_COUNT_WIDTH-1 downto 0);
    in_dvalid                   : in  std_logic;

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_count                   : out std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
    out_last                    : out std_logic
    
  );
end StreamElementCounter;

architecture Behavioral of StreamElementCounter is

  type reg_type is record
    count                       : unsigned(OUT_COUNT_WIDTH downto 0);
    last                        : std_logic;
    valid                       : std_logic;
  end record;

  type in_type is record
    ready                       : std_logic;
  end record;

  signal r                      : reg_type;
  signal d                      : reg_type;

begin

  reg_proc: process (clk) is
  begin
    if rising_edge(clk) then
      r                         <= d;

      if reset = '1' then
        r.last                  <= '0';
        r.valid                 <= '0';
        r.count                 <= (others => '0');
      end if;
    end if;
  end process;

  comb_proc: process(r,
    in_valid, in_last, in_count,
    out_ready
  ) is
    variable v: reg_type;
    variable i: in_type;
  begin
    v                           := r;

    -- Default outputs

    -- Input is ready by default
    i.ready                     := '1';

    -- If the output is valid, but not handshaked, the input must be stalled
    -- immediately
    if v.valid = '1' and out_ready = '0' then
      i.ready                   := '0';
    end if;
   
    -- If the output is handshaked, reset the count
    if v.valid = '1' and out_ready = '1' then
      -- Invalidate the output and last, and reset the count
      v.count                   := (others => '0');
      v.valid                   := '0';
      v.last                    := '0';
    end if;

    -- If the input is valid, and the output has no data or was handshaked
    -- we may advance the stream.
    if in_valid = '1' and v.valid = '0' then      
      -- Increase the output count if the data is valid
      if in_dvalid = '1' then
        v.count                 := v.count + unsigned(resize_count(in_count, IN_COUNT_MAX));
      end if;
      
      -- If the frontmost bit flipped, we reached OUT_COUNT_MAX. Validate the
      -- output.
      if v.count(OUT_COUNT_WIDTH) /= r.count(OUT_COUNT_WIDTH) then
        v.valid                 := '1';
        -- Set the bit to 0 again.
        v.count(OUT_COUNT_WIDTH):= '0';
      end if;
      
      -- If the last signal is asserted, validate the output. Only in this case,
      -- the output last signal is asserted as well.
      if in_last = '1' then
        v.valid                 := '1';
        v.last                  := '1';
      end if;

    end if;

    -- Registered output
    d                           <= v;

    -- Combinatorial output
    in_ready                    <= i.ready;

  end process;

  -- Connect the outputs
  out_valid                     <= r.valid;
  out_last                      <= r.last;
  out_count                     <= std_logic_vector(resize(r.count, OUT_COUNT_WIDTH));

end Behavioral;

