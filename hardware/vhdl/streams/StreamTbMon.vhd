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

-- This simulation-only unit monitors a stream, teeing data that passes through
-- it to a simulation queue.

entity StreamTbMon is
  generic (

    -- Width of the stream data vector.
    DATA_WIDTH                  : natural := 4;

    -- Name of the simulation data queue to tee the data to.
    NAME                        : string

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    in_valid                    : in  std_logic;
    in_ready                    : in  std_logic;
    in_data                     : in  std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Monitor output. This is set to the data as it's being received, or 'Z'
    -- if the data is not valid or the stream is not ready.
    monitor                     : out std_logic_vector(DATA_WIDTH-1 downto 0)

  );
end StreamTbMon;

architecture Behavioral of StreamTbMon is
begin

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
      stream_tb_fail("valid released while ready low for stream ");
    end if;

    valid_prev := in_valid;
    ready_prev := in_ready;
    reset_prev := reset;
  end process;

  monitor <= in_data
        when to_X01(in_valid) = '1' and to_X01(in_ready) = '1'
        else (others => 'Z');

  monitor_proc: process (clk) is
  begin
    if rising_edge(clk) then
      if to_X01(reset) = '0' then
        if to_X01(in_valid) = '1' and to_X01(in_ready) = '1' then
          stream_tb_push(NAME, in_data);
        end if;
      end if;
    end if;
  end process;

end Behavioral;

