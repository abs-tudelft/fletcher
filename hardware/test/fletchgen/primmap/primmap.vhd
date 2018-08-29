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

library work;
use work.SimUtils.all;

entity primmap is
  generic(
    TAG_WIDTH                                   : natural;
    BUS_ADDR_WIDTH                              : natural;
    INDEX_WIDTH                                 : natural;
    REG_WIDTH                                   : natural
  );
  port(
    primread_out_last                           : in std_logic;
    primwrite_in_last                           : out std_logic;
    primwrite_in_ready                          : in std_logic;
    primwrite_in_valid                          : out std_logic;
    primread_cmd_primread_values_addr           : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    primread_cmd_tag                            : out std_logic_vector(TAG_WIDTH-1 downto 0);
    primread_cmd_lastIdx                        : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    primread_cmd_firstIdx                       : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    primread_cmd_ready                          : in std_logic;
    primread_cmd_valid                          : out std_logic;
    primread_out_data                           : in std_logic_vector(7 downto 0);
    primread_out_ready                          : out std_logic;
    primread_out_valid                          : in std_logic;
    primwrite_in_data                           : out std_logic_vector(7 downto 0);
    primwrite_cmd_valid                         : out std_logic;
    primwrite_cmd_ready                         : in std_logic;
    primwrite_cmd_firstIdx                      : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    primwrite_cmd_lastIdx                       : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    primwrite_cmd_tag                           : out std_logic_vector(TAG_WIDTH-1 downto 0);
    primwrite_cmd_primwrite_values_addr         : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    -------------------------------------------------------------------------
    acc_reset                                   : in std_logic;
    acc_clk                                     : in std_logic;
    -------------------------------------------------------------------------
    ctrl_done                                   : out std_logic;
    ctrl_busy                                   : out std_logic;
    ctrl_idle                                   : out std_logic;
    ctrl_reset                                  : in std_logic;
    ctrl_stop                                   : in std_logic;
    ctrl_start                                  : in std_logic;
    -------------------------------------------------------------------------
    reg_return0                                 : out std_logic_vector(REG_WIDTH-1 downto 0);
    reg_return1                                 : out std_logic_vector(REG_WIDTH-1 downto 0);
    reg_primread_values_addr                    : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    reg_primwrite_values_addr                   : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)
  );
end entity;

architecture Behavioral of primmap is
begin

end Behavioral;
