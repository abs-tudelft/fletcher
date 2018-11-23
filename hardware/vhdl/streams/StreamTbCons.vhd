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

-- This simulation-only unit generates a random ready signal for consuming a
-- stream. It checks, among other things, that valid is asserted irrespective
-- of whether ready is asserted, a property which is necessary to conform to
-- AXI streams. It also verifies that valid is not deasserted when ready is
-- low. It is intended to be used in conjunction with StreamTbProd to test
-- correctness of the stream primitives.

entity StreamTbCons is
  generic (

    -- Width of the stream data vector.
    DATA_WIDTH                  : natural := 4;

    -- Random seed. This should be different for every instantiation.
    SEED                        : positive;

    -- If specified, this unit will push received data into the simulation data
    -- queue with that name, allowing other actors to easily monitor the
    -- received data. If not specified, this unit just sends the data to the
    -- monitor signal and does nothing else with it.
    NAME                        : string := ""

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Monitor output. This is set to the data as it's being received, or 'Z'
    -- if the data is not valid or the stream is not ready.
    monitor                     : out std_logic_vector(DATA_WIDTH-1 downto 0)

  );
end StreamTbCons;

architecture Behavioral of StreamTbCons is
  signal in_ready_s             : std_logic;
begin

  cons: process is
    variable item_remain        : integer;
    variable stall_cycles       : integer;
    variable stall_remain       : integer;
    variable ignore_valid       : boolean;
    variable seed1              : positive := SEED;
    variable seed2              : positive := 1;
    variable rand               : real;
    variable error              : boolean := true;
  begin
    loop
      wait until rising_edge(clk);

      if stall_remain > 0 then

        if to_X01(in_valid) = '1' or ignore_valid then

          -- Count down number of stall cycles.
          stall_remain := stall_remain - 1;

        end if;

      else

        -- Wait for valid.
        if to_X01(in_valid) = '1' then

          if item_remain > 0 then

            -- Go to next item in same command.
            item_remain := item_remain - 1;

          else

            -- Randomize the next command.
            uniform(seed1, seed2, rand);
            if rand < 0.5 then
              uniform(seed1, seed2, rand);
              item_remain := integer(rand * 10.0);

              uniform(seed1, seed2, rand);
              if rand < 0.5 then
                stall_cycles := 0;
              else
                uniform(seed1, seed2, rand);
                stall_cycles := integer(rand * 50.0 / real(item_remain + 1));
              end if;
            else
              uniform(seed1, seed2, rand);
              stall_cycles := integer(rand * 50.0);
            end if;

            uniform(seed1, seed2, rand);
            ignore_valid := rand > 0.5;

          end if;

          stall_remain := stall_cycles;

        elsif to_X01(in_valid) = 'X' then

          -- Go to error state.
          error := true;

        end if;

      end if;

      -- Set output signals.
      if to_X01(reset) = '1' then
        in_ready_s <= '0';
      elsif error or to_X01(reset) = 'X' then
        in_ready_s <= 'X';
      elsif stall_remain = 0 then
        in_ready_s <= '1';
      else
        in_ready_s <= '0';
      end if;

      -- Reset state if reset is asserted or unknown.
      if to_X01(reset) /= '0' then
        item_remain := 0;
        uniform(seed1, seed2, rand);
        ignore_valid := true;
        stall_cycles := integer(rand * 50.0) + 1;
        stall_remain := stall_cycles;
        error := false;
      end if;

    end loop;
  end process;

  valid_deassert_check: process is
    variable valid_prev         : std_logic := '0';
    variable ready_prev         : std_logic := '0';
    variable reset_prev         : std_logic := '1';
  begin
    wait until rising_edge(clk);

    if    to_X01(ready_prev) = '0'
      and to_X01(valid_prev) = '1'
      and to_X01(in_valid) = '0'
      and to_X01(reset_prev) = '0'
    then
      stream_tb_fail("valid released while ready low for stream " & NAME);
    end if;

    valid_prev := in_valid;
    ready_prev := in_ready_s;
    reset_prev := reset;
  end process;

  in_ready <= in_ready_s;

  monitor <= in_data
        when to_X01(in_valid) = '1' and to_X01(in_ready_s) = '1'
        else (others => 'Z');

  monitor_proc: process (clk) is
  begin
    if rising_edge(clk) then
      if NAME /= "" then
        if to_X01(in_valid) = '1' and to_X01(in_ready_s) = '1' then
          stream_tb_push(NAME, in_data);
        end if;
      end if;
    end if;
  end process;

end Behavioral;

