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

-- This unit accumulates the data input stream and outputs the accumulated value
--
-- Symbol: --->(+)--->

entity StreamAccumulator is
  generic (

    -- Width of the stream data vector. The data is considered SIGNED or
    -- UNSIGNED.
    DATA_WIDTH                  : positive := 32;

    -- Width of control information present on the MSB side of the input data
    -- vector.
    CTRL_WIDTH                  : natural  := 0;

    -- Wether or not the data is a signed or unsigned integer
    IS_SIGNED                   : boolean  := false

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    -- If in_skip is high, accumulation will not take place
    -- If in_clear is high, accumulate that element to zero
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(CTRL_WIDTH + DATA_WIDTH-1 downto 0);
    in_skip                     : in  std_logic;
    in_clear                    : in  std_logic;

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(CTRL_WIDTH + DATA_WIDTH-1 downto 0)

  );
end StreamAccumulator;

architecture Behavioral of StreamAccumulator is

  function max(a: natural; b: natural) return natural is
  begin
    if a > b then
      return a;
    else
      return b;
    end if;
  end function;

  type reg_type is record
    ctrl                        : std_logic_vector(max(1,CTRL_WIDTH)-1 downto 0);
    sum                         : std_logic_vector(DATA_WIDTH-1 downto 0);
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
        r.valid                 <= '0';
        r.sum                   <= (others => '0');

        -- In simulation, make control data unknown
        --pragma translate off
        r.ctrl                  <= (others => 'U');
        --pragma translate on
      end if;
    end if;
  end process;

  comb_proc: process(in_valid, in_data, in_skip, in_clear,
    out_ready,
    r
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

    -- If the output is handshaked, but there is no new data
    if v.valid = '1' and out_ready = '1' and in_valid = '0' then
      -- Invalidate the output
      v.valid                   := '0';
    end if;

    -- If the input is valid, and the output has no data or is handshaked
    -- we may advance the stream
    if in_valid = '1' and
       (v.valid = '0' or (v.valid = '1' and out_ready = '1'))
    then
      -- Set the sum to zero if clear is high
      if in_clear = '1' then
        v.sum                   := (others => '0');
      end if;

      -- Increase the sum, if not skipped
      if in_skip = '0' then
        if IS_SIGNED then
          v.sum                 := std_logic_vector(signed(v.sum) + signed(in_data(DATA_WIDTH-1 downto 0)));
        else
          v.sum                 := std_logic_vector(unsigned(v.sum) + unsigned(in_data(DATA_WIDTH-1 downto 0)));
        end if;
      end if;

      -- Register any control data
      if CTRL_WIDTH > 0 then
        v.ctrl                  := in_data(CTRL_WIDTH + DATA_WIDTH - 1 downto DATA_WIDTH);
      end if;

      -- Validate the output
      v.valid                   := '1';
    end if;

    -- Registered output
    d                           <= v;

    -- Combinatorial output
    in_ready                    <= i.ready;

  end process;

  -- Connect the output valid to the registered valid
  out_valid                     <= r.valid;

  -- Connect the output data depending on if there is any control in the stream
  ctrl_gen: if CTRL_WIDTH > 0 generate
    out_data                    <= r.ctrl & r.sum;
  end generate;
  no_ctrl_gen: if CTRL_WIDTH = 0 generate
    out_data                    <= r.sum;
  end generate;

end Behavioral;

