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
use work.StreamSim.all;

--pragma simulation timeout 1 ms

entity StreamFIFO_Reduce_tc is
end StreamFIFO_Reduce_tc;

architecture TestCase of StreamFIFO_Reduce_tc is

  signal in_clk                 : std_logic;
  signal in_reset               : std_logic;
  signal out_clk                : std_logic;
  signal out_reset              : std_logic;

begin

  tv: entity work.StreamFIFO_tv
    generic map (
      IN_CLK_PERIOD             => 2.2 ns,
      OUT_CLK_PERIOD            => 10 ns
    )
    port map (
      in_clk                    => in_clk,
      in_reset                  => in_reset,
      out_clk                   => out_clk,
      out_reset                 => out_reset
    );

  tb: entity work.StreamFIFO_tb
    port map (
      in_clk                    => in_clk,
      in_reset                  => in_reset,
      out_clk                   => out_clk,
      out_reset                 => out_reset
    );

end TestCase;

