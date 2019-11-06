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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.Stream_pkg.all;
use work.Buffer_pkg.all;

--pragma simulation timeout 1 ms

entity BufferWriter_32in64out_tc is
end BufferWriter_32in64out_tc;

architecture TestCase of BufferWriter_32in64out_tc is
begin
  tb: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "32IN_64OUT",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        64,
    BUS_STROBE_WIDTH            =>      64/8,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRES_SHIFT        =>         0,
    INDEX_WIDTH                 =>        32,
    IS_OFFSETS_BUFFER           =>     false,
    ELEMENT_WIDTH               =>        32,
    ELEMENT_COUNT_MAX           =>         1,
    ELEMENT_COUNT_WIDTH         =>         1,
    AVG_RANGE_LEN               => 2.0 ** 12,
    LAST_PROBABILITY            => 1.0/128.0,
    NUM_COMMANDS                =>       256,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>     false,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );
end TestCase;
