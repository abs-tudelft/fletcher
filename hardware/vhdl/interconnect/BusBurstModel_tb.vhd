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

entity BusBurstModel_tb is
  generic (
    ----------------------------------------------------------------------------    
    D : nat_array := ( 6000,  3000);
    T : nat_array := (    1,     2);
    B : nat_array := (    3,     3);
    
    NUM_CONSUMERS               : natural  :=     2;
    REQUEST_LATENCY             : positive :=     4;
    PIPELINE_DEPTH              : positive :=     2;
    ----------------------------------------- -----------------------------------
    BUS_ADDR_WIDTH              : natural  :=    64;
    BUS_DATA_WIDTH              : natural  :=    32;
    BUS_LEN_WIDTH               : natural  :=     9;
    BUS_MAX_BURST_LENGTH        : natural  :=   129;
    BUS_BURST_BOUNDARY          : natural  :=  4096;
    PATTERN                     : string   :=  "SEQUENTIAL"
  );
end BusBurstModel_tb;

architecture Behavioral of BusBurstModel_tb is
  -- Register array
  type reg_array is array(0 to NUM_CONSUMERS-1) of std_logic_vector(31 downto 0);

  -- Top level interface
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

  -- Buffer interfaces
  signal buf_rreq_valid       : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal buf_rreq_ready       : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal buf_rreq_addr        : std_logic_vector(NUM_CONSUMERS*BUS_ADDR_WIDTH-1 downto 0);
  signal buf_rreq_len         : std_logic_vector(NUM_CONSUMERS*BUS_LEN_WIDTH-1 downto 0);
  signal buf_rdat_valid       : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal buf_rdat_ready       : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal buf_rdat_data        : std_logic_vector(NUM_CONSUMERS*BUS_DATA_WIDTH-1 downto 0);
  signal buf_rdat_last        : std_logic_vector(NUM_CONSUMERS-1 downto 0);

  -- Arbiter interfaces
  signal bsv_rreq_valid       : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal bsv_rreq_ready       : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal bsv_rreq_addr        : std_logic_vector(NUM_CONSUMERS*BUS_ADDR_WIDTH-1 downto 0);
  signal bsv_rreq_len         : std_logic_vector(NUM_CONSUMERS*BUS_LEN_WIDTH-1 downto 0);
  signal bsv_rdat_valid       : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal bsv_rdat_ready       : std_logic_vector(NUM_CONSUMERS-1 downto 0);
  signal bsv_rdat_data        : std_logic_vector(NUM_CONSUMERS*BUS_DATA_WIDTH-1 downto 0);
  signal bsv_rdat_last        : std_logic_vector(NUM_CONSUMERS-1 downto 0);

  -- Registers
  signal reg_control          : reg_array;
  signal reg_status           : reg_array;
  signal reg_burst_length     : reg_array;
  signal reg_max_bursts       : reg_array;
  signal reg_base_addr_lo     : reg_array;
  signal reg_base_addr_hi     : reg_array;
  signal reg_addr_mask_lo     : reg_array;
  signal reg_addr_mask_hi     : reg_array;
  signal reg_cycles_per_word  : reg_array;
  
  signal reg_cycles           : reg_array;
  signal reg_checksum         : reg_array;

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
    wait for 10 ns;
    wait until rising_edge(bus_clk);
    bus_reset <= '0';
    wait;
  end process;

  control_proc: process is
    variable done : boolean := false;
    variable cycles : natural := 0;
    variable total_data : natural := 0;
  begin
    wait until rising_edge(bus_clk);

    for I in 0 to NUM_CONSUMERS-1 loop
      reg_burst_length(I) <= X"00000010";
      reg_max_bursts(I)   <= X"00000004";
      reg_control(I)      <= X"00000001";

      reg_base_addr_lo(I) <= X"00000000";
      reg_base_addr_hi(I) <= X"00000000";
      reg_addr_mask_lo(I) <= X"00FFF000";
      reg_addr_mask_hi(I) <= X"00000000";
      
      reg_max_bursts(I)      <= slv(u(D(I) / B(I), 32));
      reg_cycles_per_word(I) <= slv(u(T(I), 32));
      reg_burst_length(I)    <= slv(u(B(I), 32));
    end loop;
    
    wait until rising_edge(bus_clk);
    
    -- Lower start to actually start
    for I in 0 to NUM_CONSUMERS-1 loop
      reg_control(I)      <= X"00000000";
    end loop;
    
    wait until rising_edge(bus_clk);

    loop
      wait until rising_edge(bus_clk);
      next when bus_reset = '1';
      cycles := cycles + 1;
      done := true;
      for I in 0 to NUM_CONSUMERS-1 loop
        if reg_status(I) /= X"00000004" then
          done := false;
        end if;
      end loop;
      exit when done = true;
    end loop;

    simulation_done <= true;

    for I in 0 to NUM_CONSUMERS-1 loop
      dumpStdOut(
          "C"
        & ii(I) & ":"
        & ii(int(reg_burst_length(I)) * int(reg_max_bursts(I))) & "," 
        & ii(int(reg_max_bursts(I))) & ","
        & ii(int(reg_burst_length(I)))  & ","
        & ii(int(reg_cycles(I)))  & ","
        & ii((int(reg_max_bursts(I))  * BUS_DATA_WIDTH * int(reg_burst_length(I))) / int(reg_cycles(I)))
      );

      total_data := total_data + int(reg_burst_length(I)) * int(reg_max_bursts(I));
    end loop;

    dumpStdOut(" A:" & ii(cycles) & ", " & ii(total_data) & ", " & (real'image((real(total_data) / real(cycles)))));

    wait;

  end process;

  -- Consumers
  cons_gen: for I in 0 to NUM_CONSUMERS-1 generate
    buf : BusReadBuffer
      generic map (
        BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
        BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
        BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
        FIFO_DEPTH                => B(I) + 1,
        RAM_CONFIG                => "",
        SLV_REQ_SLICE             => false,
        MST_REQ_SLICE             => false,
        MST_DAT_SLICE             => false,
        SLV_DAT_SLICE             => false
      )
      port map (
        clk                       => bus_clk,
        reset                     => bus_reset,
        slv_rreq_valid            => buf_rreq_valid(I),
        slv_rreq_ready            => buf_rreq_ready(I),
        slv_rreq_addr             => buf_rreq_addr((I+1)*BUS_ADDR_WIDTH-1 downto I*BUS_ADDR_WIDTH),
        slv_rreq_len              => buf_rreq_len((I+1)*BUS_LEN_WIDTH-1 downto I*BUS_LEN_WIDTH),
        slv_rdat_valid            => buf_rdat_valid(I),
        slv_rdat_ready            => buf_rdat_ready(I),
        slv_rdat_data             => buf_rdat_data((I+1)*BUS_DATA_WIDTH-1 downto I*BUS_DATA_WIDTH),
        slv_rdat_last             => buf_rdat_last(I),
        mst_rreq_valid            => bsv_rreq_valid(I),
        mst_rreq_ready            => bsv_rreq_ready(I),
        mst_rreq_addr             => bsv_rreq_addr((I+1)*BUS_ADDR_WIDTH-1 downto I*BUS_ADDR_WIDTH),
        mst_rreq_len              => bsv_rreq_len((I+1)*BUS_LEN_WIDTH-1 downto I*BUS_LEN_WIDTH),
        mst_rdat_valid            => bsv_rdat_valid(I),
        mst_rdat_ready            => bsv_rdat_ready(I),
        mst_rdat_data             => bsv_rdat_data((I+1)*BUS_DATA_WIDTH-1 downto I*BUS_DATA_WIDTH),
        mst_rdat_last             => bsv_rdat_last(I)
      );
      
    uut : BusReadBenchmarker
      generic map (
        BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
        BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
        BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
        BUS_MAX_BURST_LENGTH      => BUS_MAX_BURST_LENGTH,
        BUS_BURST_BOUNDARY        => BUS_BURST_BOUNDARY,
        PATTERN                   => PATTERN
      )
      port map (
        bus_clk                   => bus_clk,
        bus_reset                 => bus_reset,

        bus_rreq_valid            => buf_rreq_valid(I),
        bus_rreq_ready            => buf_rreq_ready(I),
        bus_rreq_addr             => buf_rreq_addr((I+1)*BUS_ADDR_WIDTH-1 downto I*BUS_ADDR_WIDTH),
        bus_rreq_len              => buf_rreq_len((I+1)*BUS_LEN_WIDTH-1 downto I*BUS_LEN_WIDTH),
        bus_rdat_valid            => buf_rdat_valid(I),
        bus_rdat_ready            => buf_rdat_ready(I),
        bus_rdat_data             => buf_rdat_data((I+1)*BUS_DATA_WIDTH-1 downto I*BUS_DATA_WIDTH),
        bus_rdat_last             => buf_rdat_last(I),

        reg_control               => reg_control(I),
        reg_status                => reg_status(I),
        reg_burst_length          => reg_burst_length(I),
        reg_max_bursts            => reg_max_bursts(I),
        reg_base_addr_lo          => reg_base_addr_lo(I),
        reg_base_addr_hi          => reg_base_addr_hi(I),
        reg_addr_mask_lo          => reg_addr_mask_lo(I),
        reg_addr_mask_hi          => reg_addr_mask_hi(I),
        reg_cycles_per_word       => reg_cycles_per_word(I),
        reg_cycles                => reg_cycles(I)
      );
    end generate;

  -- Arbiter
  arb_inst: BusReadArbiterVec
    generic map (
      NUM_SLAVE_PORTS           => NUM_CONSUMERS,
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      ARB_METHOD                => "ROUND-ROBIN",
      MAX_OUTSTANDING           => 2*PIPELINE_DEPTH,
      RAM_CONFIG                => "",
      SLV_REQ_SLICES            => false,
      MST_REQ_SLICE             => false,
      MST_DAT_SLICE             => false,
      SLV_DAT_SLICES            => false
    )
    port map (
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      mst_rreq_valid            => bus_rreq_valid,
      mst_rreq_ready            => bus_rreq_ready,
      mst_rreq_addr             => bus_rreq_addr,
      mst_rreq_len              => bus_rreq_len,
      mst_rdat_valid            => bus_rdat_valid,
      mst_rdat_ready            => bus_rdat_ready,
      mst_rdat_data             => bus_rdat_data,
      mst_rdat_last             => bus_rdat_last,
      bsv_rreq_valid            => bsv_rreq_valid,
      bsv_rreq_ready            => bsv_rreq_ready,
      bsv_rreq_addr             => bsv_rreq_addr,
      bsv_rreq_len              => bsv_rreq_len,
      bsv_rdat_valid            => bsv_rdat_valid,
      bsv_rdat_ready            => bsv_rdat_ready,
      bsv_rdat_data             => bsv_rdat_data,
      bsv_rdat_last             => bsv_rdat_last
    );

  -- Memory
  slave_inst: BusReadSlaveMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      REQUEST_LATENCY           => REQUEST_LATENCY,
      PIPELINE_DEPTH            => PIPELINE_DEPTH,
      SEED                      => 1337,
      RANDOM_REQUEST_TIMING     => false,
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

end architecture;


