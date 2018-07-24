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
use work.Utils.all;

package Wrapper is
  -----------------------------------------------------------------------------
  -- Wrapper components
  -----------------------------------------------------------------------------
  component UserCoreController is
  generic (
    REG_WIDTH                   : natural := 32
  );
  port(
    acc_clk                     : in std_logic;
    acc_reset                   : in std_logic;
    bus_clk                     : in std_logic;
    bus_reset                   : in std_logic;
    status                      : out std_logic_vector(REG_WIDTH-1 downto 0);
    control                     : in std_logic_vector(REG_WIDTH-1 downto 0);
    start                       : out std_logic;
    stop                        : out std_logic;
    reset                       : out std_logic;
    idle                        : in std_logic;
    busy                        : in std_logic;
    done                        : in std_logic
  );
  end component;
  
end Wrapper;

package body Wrapper is
end Wrapper;
