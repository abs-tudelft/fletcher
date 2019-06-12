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
use work.Stream_pkg.all;
use work.ArrayConfig_pkg.all;
use work.ArrayConfigParse_pkg.all;
use work.Array_pkg.all;

entity ArrayReaderPrimEpc_tb is
end ArrayReaderPrimEpc_tb;

architecture Behavioral of ArrayReaderPrimEpc_tb is
  signal bcd_clk                : std_logic;
  signal bcd_reset              : std_logic;
  signal kcd_clk                : std_logic;
  signal kcd_reset              : std_logic;
  signal cmd_valid              : std_logic;
  signal cmd_ready              : std_logic;
  signal cmd_firstIdx           : std_logic_vector(31 downto 0);
  signal cmd_lastIdx            : std_logic_vector(31 downto 0);
  signal cmd_ctrl               : std_logic_vector(63 downto 0);
  signal cmd_tag                : std_logic_vector(0 downto 0) := (others => '0');
  signal unl_valid              : std_logic;
  signal unl_ready              : std_logic := '1';
  signal unl_tag                : std_logic_vector(0 downto 0);
  signal bus_rreq_valid         : std_logic;
  signal bus_rreq_ready         : std_logic;
  signal bus_rreq_addr          : std_logic_vector(63 downto 0);
  signal bus_rreq_len           : std_logic_vector(7 downto 0);
  signal bus_rdat_valid         : std_logic;
  signal bus_rdat_ready         : std_logic;
  signal bus_rdat_data          : std_logic_vector(63 downto 0);
  signal bus_rdat_last          : std_logic;
  signal out_valid              : std_logic_vector(0 downto 0);
  signal out_ready              : std_logic_vector(0 downto 0);
  signal out_last               : std_logic_vector(0 downto 0);
  signal out_dvalid             : std_logic_vector(0 downto 0);
  signal out_data               : std_logic_vector(7 downto 0);
  
  signal clock_stop : boolean := false;
begin

  clk_proc: process is
  begin
    if not clock_stop then
      kcd_clk <= '1';
      bcd_clk <= '1';
      wait for 5 ns;
      kcd_clk <= '0';
      bcd_clk <= '0';
      wait for 5 ns;
    else
      wait;
    end if;
  end process;

  reset_proc: process is
  begin
    kcd_reset <= '1';
    bcd_reset <= '1';
    wait for 50 ns;
    wait until rising_edge(kcd_clk);
    kcd_reset <= '0';
    bcd_reset <= '0';
    wait;
  end process;

  uut: ArrayReader
    generic map (
      BUS_ADDR_WIDTH            => 64,
      BUS_LEN_WIDTH             => 8,
      BUS_DATA_WIDTH            => 64,
      BUS_BURST_STEP_LEN        => 4,
      BUS_BURST_MAX_LEN         => 16,
      INDEX_WIDTH               => 32,
      CFG                       => "arb(prim(8))",
      CMD_TAG_ENABLE            => false,
      CMD_TAG_WIDTH             => 1
    )
    port map (
      bcd_clk                   => bcd_clk ,
      bcd_reset                 => bcd_reset,
      kcd_clk                   => kcd_clk,
      kcd_reset                 => kcd_reset,
      cmd_valid                 => cmd_valid,
      cmd_ready                 => cmd_ready,
      cmd_firstIdx              => cmd_firstIdx,
      cmd_lastIdx               => cmd_lastIdx,
      cmd_ctrl                  => cmd_ctrl,
      cmd_tag                   => cmd_tag,
      unl_valid                 => unl_valid,
      unl_ready                 => unl_ready,
      unl_tag                   => unl_tag,
      bus_rreq_valid            => bus_rreq_valid,
      bus_rreq_ready            => bus_rreq_ready,
      bus_rreq_addr             => bus_rreq_addr,
      bus_rreq_len              => bus_rreq_len,
      bus_rdat_valid            => bus_rdat_valid,
      bus_rdat_ready            => bus_rdat_ready,
      bus_rdat_data             => bus_rdat_data,
      bus_rdat_last             => bus_rdat_last,
      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_last                  => out_last,
      out_dvalid                => out_dvalid,
      out_data                  => out_data
    );

end architecture;
