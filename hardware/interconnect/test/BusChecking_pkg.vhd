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
use work.Interconnect_pkg.all;

package BusChecking_pkg is

  component BusProtocolChecker is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_BURST_MAX_LEN         : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_BOUNDARY        : natural
    );
    port (
      bcd_clk                   : in std_logic;
      bcd_reset                 : in std_logic;
      bus_rreq_valid            : in std_logic;
      bus_rreq_ready            : in std_logic;
      bus_rreq_addr             : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      bus_rreq_len              : in std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      bus_rdat_valid            : in std_logic;
      bus_rdat_ready            : in std_logic;
      bus_rdat_data             : in std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bus_rdat_last             : in std_logic;
      bus_wreq_valid            : in std_logic;
      bus_wreq_ready            : in std_logic;
      bus_wreq_addr             : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      bus_wreq_len              : in std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      bus_wreq_last             : in std_logic;
      bus_wdat_valid            : in std_logic;
      bus_wdat_ready            : in std_logic;
      bus_wdat_data             : in std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bus_wdat_strobe           : in std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
      bus_wdat_last             : in std_logic;
      bus_wrep_valid            : in std_logic;
      bus_wrep_ready            : in std_logic;
      bus_wrep_ok               : in std_logic
    );
  end component;

  -- Check for requests crossing burst boundaries.
  procedure bus_check_boundary (
    BUS_DATA_WIDTH : in natural;
    BUS_BURST_BOUNDARY : in natural;
    addr : in std_logic_vector;
    len  : in std_logic_vector
  );

end BusChecking_pkg;

package body BusChecking_pkg is

  procedure bus_check_boundary (
    BUS_DATA_WIDTH : in natural;
    BUS_BURST_BOUNDARY : in natural;
    addr : in std_logic_vector;
    len  : in std_logic_vector
  ) is
    variable iaddr        : integer;
    variable ilen         : integer;
    variable end_addr     : integer;
    variable start_bound  : integer;
    variable end_bound    : integer;
  begin
    iaddr := to_integer(unsigned(addr));
    ilen := to_integer(unsigned(len));
    end_addr := iaddr + (ilen-1) * BUS_DATA_WIDTH/8 + (BUS_DATA_WIDTH/8-1);
    start_bound := iaddr / BUS_BURST_BOUNDARY;
    end_bound := end_addr / BUS_BURST_BOUNDARY;
    assert start_bound = end_bound
      report "Burst request crosses burst boundary. " &
             "Bytes written: "   & integer'image(iaddr) &
             "..."               & integer'image(end_addr) &
             " Burst length : "  & integer'image(ilen) &
             " Start/Bound : "   & integer'image(start_bound) &
             " End  /Bound : "   & integer'image(end_bound)
      severity failure;
  end bus_check_boundary;

end BusChecking_pkg;
