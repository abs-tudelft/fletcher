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
use work.Utils.all;
use work.SimUtils.all;
use work.Interconnect.all;
use work.Streams.all;

entity BusReadBenchmarker_tb is
  generic (
    BUS_ADDR_WIDTH              : natural := 64;
    BUS_DATA_WIDTH              : natural := 512;
    BUS_LEN_WIDTH               : natural := 9;
    BUS_MAX_BURST_LENGTH        : natural := 256;
    BUS_BURST_BOUNDARY          : natural := 4096
  );
end BusReadBenchmarker_tb;

architecture Behavioral of BusReadBenchmarker_tb is
    signal bus_clk              : std_logic;
    signal bus_reset            : std_logic;
    signal bus_rreq_valid       : std_logic;
    signal bus_rreq_ready       : std_logic;
    signal bus_rreq_addr        : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    signal bus_rreq_len         : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    signal bus_rdat_valid       : std_logic;
    signal bus_rdat_ready       : std_logic;
    signal bus_rdat_data        : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    signal bus_rdat_last        : std_logic;
    
    signal reg_control          : std_logic_vector(31 downto 0) := (others => '0');
    signal reg_status           : std_logic_vector(31 downto 0);
    
    signal reg_burst_length     : std_logic_vector(31 downto 0) := X"00000001";
    signal reg_max_bursts       : std_logic_vector(31 downto 0) := X"00000001";
    signal reg_base_addr_lo     : std_logic_vector(31 downto 0) := X"00000000";
    signal reg_base_addr_hi     : std_logic_vector(31 downto 0) := X"00000000";
    signal reg_addr_mask_lo     : std_logic_vector(31 downto 0) := X"00FFF000";
    signal reg_addr_mask_hi     : std_logic_vector(31 downto 0) := X"00000000";
    
    signal reg_cycles           : std_logic_vector(31 downto 0);
    
    signal simulation_done      : boolean := false;
begin

  clk_proc: process is
  begin
    loop
      bus_clk <= '1';
      wait for 5 ns;
      bus_clk <= '0';
      wait for 5 ns;
      exit when simulation_done;
    end loop;
    wait;
  end process;

  reset_proc: process is
  begin
    bus_reset <= '1';
    wait for 50 ns;
    wait until rising_edge(bus_clk);
    bus_reset <= '0';
    wait;
  end process;
  
  control_proc: process is
  begin
    wait until rising_edge(bus_clk);
    
    reg_burst_length <= X"00000040";
    reg_max_bursts   <= X"00001000";
    reg_control      <= X"00000001";
    
    loop 
      wait until rising_edge(bus_clk);
      exit when reg_status = X"00000004";
    end loop;
    
    simulation_done <= true;
    
    dumpStdOut("Transfers               : " & integer'image(int(reg_max_bursts)));
    dumpStdOut("Cycles                  : " & integer'image(int(reg_cycles)));
    dumpStdOut("Throughput (bits/cycle) : " & integer'image((int(reg_max_bursts)  * BUS_DATA_WIDTH * int(reg_burst_length)) / int(reg_cycles)));
    
    wait;
    
  end process;

  slave_inst: BusReadSlaveMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 1337,
      RANDOM_REQUEST_TIMING     => true,
      RANDOM_RESPONSE_TIMING    => false
    )
    port map (
      clk                       => bus_clk,
      reset                     => bus_reset,
      rreq_valid                => bus_rreq_valid,
      rreq_ready                => bus_rreq_ready,
      rreq_addr                 => bus_rreq_addr,
      rreq_len                  => bus_rreq_len,
      rdat_valid                => bus_rdat_valid,
      rdat_ready                => bus_rdat_ready,
      rdat_data                 => bus_rdat_data,
      rdat_last                 => bus_rdat_last
  );

  uut : BusReadBenchmarker
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_MAX_BURST_LENGTH      => BUS_MAX_BURST_LENGTH,
      BUS_BURST_BOUNDARY        => BUS_BURST_BOUNDARY
    )
    port map (
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      bus_rreq_valid            => bus_rreq_valid,
      bus_rreq_ready            => bus_rreq_ready,
      bus_rreq_addr             => bus_rreq_addr,
      bus_rreq_len              => bus_rreq_len,
      bus_rdat_valid            => bus_rdat_valid,
      bus_rdat_ready            => bus_rdat_ready,
      bus_rdat_data             => bus_rdat_data,
      bus_rdat_last             => bus_rdat_last,
      reg_control               => reg_control,
      reg_status                => reg_status,
      reg_burst_length          => reg_burst_length,
      reg_max_bursts            => reg_max_bursts,
      reg_base_addr_lo          => reg_base_addr_lo,
      reg_base_addr_hi          => reg_base_addr_hi,
      reg_addr_mask_lo          => reg_addr_mask_lo,
      reg_addr_mask_hi          => reg_addr_mask_hi,
      reg_cycles                => reg_cycles
    );
    
    
end architecture;


