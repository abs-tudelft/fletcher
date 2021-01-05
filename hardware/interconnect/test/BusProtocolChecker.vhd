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
use work.Interconnect_pkg.all;
use work.BusChecking_pkg.all;

-- This unit checks for violations of any bus protocols.
entity BusProtocolChecker is
  generic (
    BUS_ADDR_WIDTH              : natural;
    BUS_DATA_WIDTH              : natural;
    BUS_LEN_WIDTH               : natural;
    BUS_BURST_MAX_LEN           : natural;
    BUS_BURST_STEP_LEN          : natural;
    BUS_BURST_BOUNDARY          : natural
  );
  port (
    bcd_clk                     : in std_logic;
    bcd_reset                   : in std_logic;
    bus_rreq_valid              : in std_logic;
    bus_rreq_ready              : in std_logic;
    bus_rreq_addr               : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_rreq_len                : in std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    bus_rdat_valid              : in std_logic;
    bus_rdat_ready              : in std_logic;
    bus_rdat_data               : in std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_rdat_last               : in std_logic;
    bus_wreq_valid              : in std_logic;
    bus_wreq_ready              : in std_logic;
    bus_wreq_addr               : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_wreq_len                : in std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    bus_wreq_last               : in std_logic;
    bus_wdat_valid              : in std_logic;
    bus_wdat_ready              : in std_logic;
    bus_wdat_data               : in std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_wdat_strobe             : in std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
    bus_wdat_last               : in std_logic;
    bus_wrep_valid              : in std_logic;
    bus_wrep_ready              : in std_logic;
    bus_wrep_ok                 : in std_logic
  );
end BusProtocolChecker;

architecture Behavioral of BusProtocolChecker is
begin
  
  check_read_req_boundary_proc: process is 
  begin
    wait until rising_edge(bcd_clk) and bus_rreq_valid='1' and bus_rreq_valid ='1';
    bus_check_boundary(BUS_DATA_WIDTH, BUS_BURST_BOUNDARY, bus_rreq_addr, bus_rreq_len);
  end process;
  
  check_write_req_boundary_proc: process is 
  begin
    wait until rising_edge(bcd_clk) and bus_wreq_valid='1' and bus_wreq_valid ='1';
    bus_check_boundary(BUS_DATA_WIDTH, BUS_BURST_BOUNDARY, bus_wreq_addr, bus_wreq_len);
  end process;
  
end Behavioral;
