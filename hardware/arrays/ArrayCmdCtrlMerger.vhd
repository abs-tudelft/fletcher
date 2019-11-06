-- Copyright 2018-2019 Delft University of Technology
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

-- Merges the ctrl field of an ArrayReader/Writer command into a command stream.
-- Used in Fletchgen for kernels where the addresses are abstracted from the 
-- hardware developer. Once some functionality to drive a single node with
-- non-overlapping flattened type mappers from multiple nodes is implemented,
-- this component can be removed.

entity ArrayCmdCtrlMerger is
  generic (
    -- Address width.
    BUS_ADDR_WIDTH              : positive := 64;
    -- Number of addresses.
    NUM_ADDR                    : positive := 1;
    -- Width of the command stream tag field.
    TAG_WIDTH                   : positive := 1;
    -- Width of the indices
    INDEX_WIDTH                 : positive := 32
  );
  port (
    -- Nucleus side output stream
    nucleus_cmd_valid           : out std_logic;
    nucleus_cmd_ready           : in  std_logic;
    nucleus_cmd_firstIdx        : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    nucleus_cmd_lastidx         : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    nucleus_cmd_ctrl            : out std_logic_vector(NUM_ADDR * BUS_ADDR_WIDTH-1 downto 0);
    nucleus_cmd_tag             : out std_logic_vector(TAG_WIDTH-1 downto 0);
    
    -- Kernel side input stream
    kernel_cmd_valid            : in  std_logic;
    kernel_cmd_ready            : out std_logic;
    kernel_cmd_firstIdx         : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    kernel_cmd_lastidx          : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    kernel_cmd_tag              : in  std_logic_vector(TAG_WIDTH-1 downto 0);
    
    -- MMIO side buffer address inputs
    ctrl                        : in  std_logic_vector(NUM_ADDR * BUS_ADDR_WIDTH-1 downto 0)
  );
end ArrayCmdCtrlMerger;

architecture Behavioral of ArrayCmdCtrlMerger is
begin

  nucleus_cmd_valid    <= kernel_cmd_valid;
  kernel_cmd_ready     <= nucleus_cmd_ready;
  nucleus_cmd_firstIdx <= kernel_cmd_firstIdx;
  nucleus_cmd_lastidx  <= kernel_cmd_lastidx;
  nucleus_cmd_ctrl     <= ctrl;
  nucleus_cmd_tag      <= kernel_cmd_tag;

end Behavioral;
