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
use work.Streams.all;
use work.StreamSim.all;
use work.Utils.all;

--pragma simulation timeout 5 ms

entity StreamNormalizer_8_6_4_6_tc is
end StreamNormalizer_8_6_4_6_tc;

architecture TestCase of StreamNormalizer_8_6_4_6_tc is
begin

  tb: entity work.StreamNormalizer_tb
    generic map (
      ELEMENT_WIDTH             => 8,
      COUNT_MAX                 => 6,
      COUNT_WIDTH               => 4,
      REQ_COUNT_WIDTH           => 6
    );

end TestCase;

