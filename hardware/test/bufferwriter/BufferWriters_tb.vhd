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
use work.Utils.all;
use work.Streams.all;
use work.Buffers.all;
use work.SimUtils.all;

entity BufferWriters_tb is
end BufferWriters_tb;

architecture tb of BufferWriters_tb is
begin
  inst0: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "32IN_32OUT",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        32,
    BUS_STROBE_WIDTH            =>      32/8,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRES_SHIFT        =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>     false,
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

  inst1: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "INDEX_BS4",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        32,
    BUS_STROBE_WIDTH            =>      32/8,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         4,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRES_SHIFT        =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>      true,
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

  inst2: entity work.BufferWriter_tb generic map (
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
    IS_INDEX_BUFFER             =>     false,
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

  inst3: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "4x16IN_64OUT",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        64,
    BUS_STROBE_WIDTH            =>      64/8,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRES_SHIFT        =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>     false,
    ELEMENT_WIDTH               =>        16,
    ELEMENT_COUNT_MAX           =>         4,
    ELEMENT_COUNT_WIDTH         =>         2,
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

  inst4: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "8x1IN_64OUT",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        64,
    BUS_STROBE_WIDTH            =>      64/8,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRES_SHIFT        =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>     false,
    ELEMENT_WIDTH               =>         1,
    ELEMENT_COUNT_MAX           =>         8,
    ELEMENT_COUNT_WIDTH         =>         3,
    AVG_RANGE_LEN               => 2.0 ** 12,
    LAST_PROBABILITY            => 1.0/128.0,
    NUM_COMMANDS                =>        32,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>     false,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );

  inst5: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "2x32IN_64OUT_MB1",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        64,
    BUS_STROBE_WIDTH            =>      64/8,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>         1,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRES_SHIFT        =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>     false,
    ELEMENT_WIDTH               =>         2,
    ELEMENT_COUNT_MAX           =>        32,
    ELEMENT_COUNT_WIDTH         =>         5,
    AVG_RANGE_LEN               => 2.0 ** 12,
    LAST_PROBABILITY            => 1.0/128.0,
    NUM_COMMANDS                =>        32,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>     false,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );
  
  inst6: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "INDEX_BUF",
    BUS_ADDR_WIDTH              =>        64,
    BUS_DATA_WIDTH              =>       128,
    BUS_STROBE_WIDTH            =>     128/8,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>         1,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRES_SHIFT        =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>      true,
    ELEMENT_WIDTH               =>        32,
    ELEMENT_COUNT_MAX           =>         1,
    ELEMENT_COUNT_WIDTH         =>         1,
    AVG_RANGE_LEN               => 2.0 ** 11,
    LAST_PROBABILITY            => 1.0/128.0,
    NUM_COMMANDS                =>        64,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>     false,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );
  
  inst7: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "8x64IN_512OUT",
    BUS_ADDR_WIDTH              =>        64,
    BUS_DATA_WIDTH              =>       512,
    BUS_STROBE_WIDTH            =>     512/8,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         4,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRES_SHIFT        =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>     false,
    ELEMENT_WIDTH               =>        64,
    ELEMENT_COUNT_MAX           =>         8,
    ELEMENT_COUNT_WIDTH         =>         3,
    AVG_RANGE_LEN               => 2.0 ** 14,
    LAST_PROBABILITY            => 1.0/128.0,
    NUM_COMMANDS                =>        64,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>      true,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );

end tb;
