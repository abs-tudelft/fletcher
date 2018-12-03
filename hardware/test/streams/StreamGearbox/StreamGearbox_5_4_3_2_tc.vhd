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

--pragma simulation timeout 1 ms

entity StreamGearbox_5_4_3_2_tc is
end StreamGearbox_5_4_3_2_tc;

architecture TestCase of StreamGearbox_5_4_3_2_tc is

  constant COUNT_MAX_B          : natural := 5;
  constant COUNT_WIDTH_B        : natural := 4;
  constant COUNT_MAX_C          : natural := 3;
  constant COUNT_WIDTH_C        : natural := 2;

  signal clk                    : std_logic;
  signal reset                  : std_logic;

begin

  tv: entity work.StreamGearbox_tv
    generic map (
      COUNT_MAX_B               => COUNT_MAX_B,
      COUNT_WIDTH_B             => COUNT_WIDTH_B,
      COUNT_MAX_C               => COUNT_MAX_C,
      COUNT_WIDTH_C             => COUNT_WIDTH_C
    )
    port map (
      clk                       => clk,
      reset                     => reset
    );

  tb: entity work.StreamGearbox_tb
    generic map (
      COUNT_MAX_B               => COUNT_MAX_B,
      COUNT_WIDTH_B             => COUNT_WIDTH_B,
      COUNT_MAX_C               => COUNT_MAX_C,
      COUNT_WIDTH_C             => COUNT_WIDTH_C
    )
    port map (
      clk                       => clk,
      reset                     => reset
    );

end TestCase;

