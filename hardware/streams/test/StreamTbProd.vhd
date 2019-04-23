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
use ieee.math_real.all;

library work;
use work.StreamSim.all;

-- This simulation-only unit generates a stream of incrementing numbers using
-- randomized handshake timing. It is intended to be used in conjunction with
-- StreamTbCons to test correctness of the stream primitives.

entity StreamTbProd is
  generic (

    -- Width of the stream data vector.
    DATA_WIDTH                  : natural := 4;

    -- Random seed. This should be different for every instantiation.
    SEED                        : positive;

    -- If specified, this unit will send data from the simulation data
    -- queue with that name. If not specified, sequential data is generated
    -- and sent with randomized handshaking.
    NAME                        : string := ""

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(DATA_WIDTH-1 downto 0)

  );
end StreamTbProd;

architecture Behavioral of StreamTbProd is
begin

  prod: process is
    variable data_waiting       : boolean;
    variable data               : std_logic_vector(DATA_WIDTH-1 downto 0);
    variable invalid_remain     : integer;
    variable timing             : integer;
    variable seed1              : positive := SEED;
    variable seed2              : positive := 1;
    variable rand               : real;
    variable rand_item_remain   : integer;
    variable rand_invalid_cycles: integer;
    variable error              : boolean := true;
  begin
    loop
      wait until rising_edge(clk);

      if invalid_remain > 0 then

        -- Count down number of invalid cycles.
        invalid_remain := invalid_remain - 1;

      else

        -- Wait for ready.
        if to_X01(out_ready) = '1' then

          -- Randomize timing. To get more representative behavior, we send a
          -- random number of beats with the same timing (referred to as a
          -- burst). This improves the odds of testing steady-state behavior of
          -- the unit under test under various conditions.
          if rand_item_remain > 0 then

            -- Go to next item in same burst.
            rand_item_remain := rand_item_remain - 1;

          else

            -- Randomize the next burst.
            uniform(seed1, seed2, rand);
            if rand < 0.5 then
              uniform(seed1, seed2, rand);
              rand_item_remain := integer(rand * 10.0);

              uniform(seed1, seed2, rand);
              if rand < 0.5 then
                rand_invalid_cycles := 0;
              else
                uniform(seed1, seed2, rand);
                rand_invalid_cycles := integer(rand * 50.0 / real(rand_item_remain + 1));
              end if;
            else
              uniform(seed1, seed2, rand);
              rand_invalid_cycles := integer(rand * 50.0);
            end if;

          end if;

          -- Mark the data we just transfered as invalid, to remember that we
          -- need to figure out a new data item.
          data_waiting := false;

        elsif to_X01(out_ready) = 'X' then

          -- Go to error state.
          error := true;

        end if;

      end if;

      -- Look for new data to transmit if nothing is waiting.
      if not data_waiting then
        if NAME = "" then
          -- Generate some basic data.
          invalid_remain := rand_invalid_cycles;
          data := std_logic_vector(unsigned(data) + 1);
          data_waiting := true;
        else
          -- Try to pull data from our queue.
          stream_tb_pop(NAME, data, timing, data_waiting);
          if timing >= 0 then
            invalid_remain := timing;
          else
            invalid_remain := rand_invalid_cycles;
          end if;
        end if;
      end if;

      -- Set output signals.
      if to_X01(reset) = '1' then
        out_data <= (others => 'U');
        out_valid <= '0';
      elsif error or to_X01(reset) = 'X' then
        out_valid <= 'X';
        out_data <= (others => 'X');
      elsif not data_waiting or invalid_remain > 0 then
        out_valid <= '0';
        out_data <= (others => 'U');
      else
        out_valid <= '1';
        out_data <= data;
      end if;

      -- Reset state if reset is asserted or unknown.
      if to_X01(reset) /= '0' then

        -- Reset pending data only when we're generating it here. If we do it
        -- when we're configured to pull from a queue, we'd empty the queue out
        -- during a reset contrary to intuition.
        if NAME = "" then
          data := (others => '0');
          data_waiting := true;
          rand_item_remain := 0;
          uniform(seed1, seed2, rand);
          rand_invalid_cycles := integer(rand * 50.0) + 1;
          invalid_remain := rand_invalid_cycles;
        end if;

        error := false;
      end if;

    end loop;
  end process;

end Behavioral;

