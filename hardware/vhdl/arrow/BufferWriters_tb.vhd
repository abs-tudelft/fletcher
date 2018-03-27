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
use work.Streams.all;
use work.Utils.all;
use work.SimUtils.all;
use work.Arrow.all;

entity BufferWriters_tb is
end BufferWriters_tb;

architecture tb of BufferWriters_tb is
begin
  inst0: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "32 in, 32 out",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        32,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRESHOLD_SHIFT    =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>     false,
    ELEMENT_WIDTH               =>        32,
    ELEMENT_COUNT_MAX           =>         1,
    ELEMENT_COUNT_WIDTH         =>         1,
    AVG_RANGE_LEN               => 2.0 ** 12,
    NUM_COMMANDS                =>      4096,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>     false,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );

  inst1: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "32 in, 32 out, burst step 4",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        32,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         4,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRESHOLD_SHIFT    =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>      true,
    ELEMENT_WIDTH               =>        32,
    ELEMENT_COUNT_MAX           =>         1,
    ELEMENT_COUNT_WIDTH         =>         1,
    AVG_RANGE_LEN               => 2.0 ** 12,
    NUM_COMMANDS                =>      4096,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>     false,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );

  inst2: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "32 in, 64 out",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        64,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRESHOLD_SHIFT    =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>     false,
    ELEMENT_WIDTH               =>        32,
    ELEMENT_COUNT_MAX           =>         1,
    ELEMENT_COUNT_WIDTH         =>         1,
    AVG_RANGE_LEN               => 2.0 ** 12,
    NUM_COMMANDS                =>      4096,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>     false,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );

  inst3: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "4x16 in, 64 out",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        64,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRESHOLD_SHIFT    =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>     false,
    ELEMENT_WIDTH               =>        16,
    ELEMENT_COUNT_MAX           =>         4,
    ELEMENT_COUNT_WIDTH         =>         2,
    AVG_RANGE_LEN               => 2.0 ** 12,
    NUM_COMMANDS                =>      4096,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>     false,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );

  inst4: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "8x1 in, 64 out",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        64,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRESHOLD_SHIFT    =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>     false,
    ELEMENT_WIDTH               =>         1,
    ELEMENT_COUNT_MAX           =>         8,
    ELEMENT_COUNT_WIDTH         =>         3,
    AVG_RANGE_LEN               => 2.0 ** 12,
    NUM_COMMANDS                =>      1024,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>     false,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );

  inst5: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "32x2 in, 64 out, burst max 1",
    BUS_ADDR_WIDTH              =>        32,
    BUS_DATA_WIDTH              =>        64,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>         1,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRESHOLD_SHIFT    =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>     false,
    ELEMENT_WIDTH               =>         2,
    ELEMENT_COUNT_MAX           =>        32,
    ELEMENT_COUNT_WIDTH         =>         5,
    AVG_RANGE_LEN               => 2.0 ** 12,
    NUM_COMMANDS                =>       256,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>     false,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );
  
  inst6: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "index buffer",
    BUS_ADDR_WIDTH              =>        64,
    BUS_DATA_WIDTH              =>       128,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         1,
    BUS_BURST_MAX_LEN           =>         1,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRESHOLD_SHIFT    =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>      true,
    ELEMENT_WIDTH               =>        32,
    ELEMENT_COUNT_MAX           =>         1,
    ELEMENT_COUNT_WIDTH         =>         1,
    AVG_RANGE_LEN               => 2.0 ** 11,
    NUM_COMMANDS                =>      1024,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>     false,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );
  
  inst7: entity work.BufferWriter_tb generic map (
    TEST_NAME                   => "known last index 8x64 in 512 out",
    BUS_ADDR_WIDTH              =>        64,
    BUS_DATA_WIDTH              =>       512,
    BUS_LEN_WIDTH               =>         9,
    BUS_BURST_STEP_LEN          =>         4,
    BUS_BURST_MAX_LEN           =>        16,
    BUS_FIFO_DEPTH              =>         1,
    BUS_FIFO_THRESHOLD_SHIFT    =>         0,
    INDEX_WIDTH                 =>        32,
    IS_INDEX_BUFFER             =>     false,
    ELEMENT_WIDTH               =>        64,
    ELEMENT_COUNT_MAX           =>         8,
    ELEMENT_COUNT_WIDTH         =>         3,
    AVG_RANGE_LEN               => 2.0 ** 14,
    NUM_COMMANDS                =>       256,
    WAIT_FOR_UNLOCK             =>     false,
    KNOWN_LAST_INDEX            =>      true,
    CMD_CTRL_WIDTH              =>         1,
    CMD_TAG_WIDTH               =>        16,
    VERBOSE                     =>     false,
    SEED                        =>  16#0123#
  );


  --baw_gen: for BAW in 3 to 6 generate
  --  bdw_gen: for BDW in 3 to 10 generate
  --    ew_gen: for EW in 0 to BDW generate
  --      ecm_gen: for ECM in 0 to 7 generate
  --        test: BufferWriter_tb generic map (
  --          TEST_NAME                   => "BAW: " & ii(BAW) & "BDW: " & ii(BDW) & "EW: " & ii(EW),
  --          BUS_ADDR_WIDTH              =>    2**BAW,
  --          BUS_DATA_WIDTH              =>    2**BDW,
  --          BUS_LEN_WIDTH               =>         9,
  --          BUS_BURST_STEP_LEN          =>         1,
  --          BUS_BURST_MAX_LEN           =>         1,
  --          BUS_FIFO_DEPTH              =>         1,
  --          BUS_FIFO_THRESHOLD_SHIFT    =>         0,
  --          INDEX_WIDTH                 =>        32,
  --          IS_INDEX_BUFFER             =>     false,
  --          ELEMENT_WIDTH               =>     2**EW,
  --          ELEMENT_COUNT_MAX           =>    2**ECM,
  --          ELEMENT_COUNT_WIDTH         => max(1,ECM),
  --          AVG_RANGE_LEN               => 2.0 ** 12,
  --          NUM_COMMANDS                =>       256,
  --          WAIT_FOR_UNLOCK             =>     false,
  --          KNOWN_LAST_INDEX            =>     false,
  --          CMD_CTRL_WIDTH              =>         1,
  --          CMD_TAG_WIDTH               =>        16,
  --          VERBOSE                     =>     false,
  --          SEED                        =>  16#0123#
  --        );
  --      end generate;
  --    end generate;
  --  end generate;
  --end generate;

end tb;
