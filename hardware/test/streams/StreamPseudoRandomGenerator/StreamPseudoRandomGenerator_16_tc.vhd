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

--pragma simulation timeout 5 ms

entity StreamPseudoRandomGenerator_16_tc is
end StreamPseudoRandomGenerator_16_tc;

architecture TestCase of StreamPseudoRandomGenerator_16_tc is

  constant DATA_WIDTH           : positive := 16;

  signal clk                    : std_logic;
  signal reset                  : std_logic;

begin

  tv: entity work.StreamPseudoRandomGenerator_tv
    generic map (
      DATA_WIDTH                => DATA_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset
    );

  tb: entity work.StreamPseudoRandomGenerator_tb
    generic map (
      DATA_WIDTH                => DATA_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset
    );

end TestCase;

