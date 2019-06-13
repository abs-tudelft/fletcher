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

package Wrapper_pkg is
  -----------------------------------------------------------------------------
  -- Wrapper components
  -----------------------------------------------------------------------------
  component UserCoreController is
    generic (
      REG_WIDTH                 : natural := 32
    );
    port(
      kcd_clk                   : in std_logic;
      kcd_reset                 : in std_logic;
      bcd_clk                   : in std_logic;
      bcd_reset                 : in std_logic;
      status                    : out std_logic_vector(REG_WIDTH-1 downto 0);
      control                   : in std_logic_vector(REG_WIDTH-1 downto 0);
      start                     : out std_logic;
      stop                      : out std_logic;
      reset                     : out std_logic;
      idle                      : in std_logic;
      busy                      : in std_logic;
      done                      : in std_logic
    );
  end component;

  -----------------------------------------------------------------------------
  -- Wrapper simulation components
  -----------------------------------------------------------------------------
  --pragma translate off
  component UserCoreMock is
    generic (
      NUM_REQUESTS              : natural;
      NUM_ELEMENTS              : natural;
      RANDOMIZE_OFFSET          : boolean;
      RANDOMIZE_NUM_ELEMENTS    : boolean;
      RANDOMIZE_RESP_LATENCY    : boolean;
      MAX_LATENCY               : natural;
      DEFAULT_LATENCY           : natural;
      RESULT_LSHIFT             : natural;
      RESP_TIMEOUT              : natural;
      WAIT_FOR_PREV_LAST        : boolean;
      SEED                      : positive;
      IS_OFFSETS_BUFFER         : boolean;
      DATA_WIDTH                : natural;
      INDEX_WIDTH               : natural;
      ELEMENT_WIDTH             : natural;
      ELEMENT_COUNT_MAX         : natural;
      ELEMENT_COUNT_WIDTH       : natural
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      start                     : in  std_logic;
      done                      : out std_logic;
      req_resp_error            : out std_logic;
      incorrect                 : out std_logic;
      timeout                   : out std_logic;
      rows                      : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_valid                 : out std_logic;
      cmd_ready                 : in  std_logic;
      cmd_firstIdx              : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_lastIdx               : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      in_last                   : in  std_logic
    );
  end component;
  --pragma translate on
end Wrapper_pkg;
