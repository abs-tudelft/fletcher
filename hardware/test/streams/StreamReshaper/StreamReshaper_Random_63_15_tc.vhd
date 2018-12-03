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

entity StreamReshaper_Random_63_15_tc is
end StreamReshaper_Random_63_15_tc;

architecture TestCase of StreamReshaper_Random_63_15_tc is

  constant IN_COUNT_MAX         : natural := 63;
  constant OUT_COUNT_MAX        : natural := 15;
  constant SHIFTS_PER_STAGE     : natural := 2;

  signal clk                    : std_logic;
  signal reset                  : std_logic;
  signal error_strobe           : std_logic;

begin

  tv: entity work.StreamReshaper_Random_tv
    generic map (
      IN_COUNT_MAX              => IN_COUNT_MAX,
      OUT_COUNT_MAX             => OUT_COUNT_MAX
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      error_strobe              => error_strobe
    );

  tb: entity work.StreamReshaper_tb
    generic map (
      IN_COUNT_MAX              => IN_COUNT_MAX,
      OUT_COUNT_MAX             => OUT_COUNT_MAX,
      SHIFTS_PER_STAGE          => SHIFTS_PER_STAGE
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      error_strobe              => error_strobe
    );

end TestCase;

