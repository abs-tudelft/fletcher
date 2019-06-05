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
use work.Interconnect_pkg.all;

-- This unit acts as an arbiter for the bus system utilized by the
-- BufferReaders.

entity BusReadArbiter is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Number of bus masters to arbitrate between.
    NUM_SLAVE_PORTS             : natural := 2;

    -- Arbitration method. Must be "ROUND-ROBIN" or "FIXED". If fixed,
    -- lower-indexed masters take precedence.
    ARB_METHOD                  : string := "ROUND-ROBIN";

    -- Maximum number of outstanding requests. This is rounded upward to
    -- whatever is convenient internally.
    MAX_OUTSTANDING             : natural := 2;

    -- RAM configuration string for the outstanding request FIFO.
    RAM_CONFIG                  : string := "";

    -- Whether a register slice should be inserted into the slave request ports
    SLV_REQ_SLICES              : boolean := true;

    -- Whether a register slice should be inserted into the master request port
    MST_REQ_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the master data port
    MST_DAT_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the slave data ports
    SLV_DAT_SLICES              : boolean := true
    
  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    bcd_clk                     : in  std_logic;
    bcd_reset                   : in  std_logic;

    -- Slave port.
    mst_rreq_valid              : out std_logic;
    mst_rreq_ready              : in  std_logic;
    mst_rreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_rreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_rdat_valid              : in  std_logic;
    mst_rdat_ready              : out std_logic;
    mst_rdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_rdat_last               : in  std_logic;

    -- Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn

    -- Master port 0.
    bs00_rreq_valid             : in  std_logic := '0';
    bs00_rreq_ready             : out std_logic;
    bs00_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs00_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs00_rdat_valid             : out std_logic;
    bs00_rdat_ready             : in  std_logic := '1';
    bs00_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs00_rdat_last              : out std_logic;

    -- Master port 1.
    bs01_rreq_valid             : in  std_logic := '0';
    bs01_rreq_ready             : out std_logic;
    bs01_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs01_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs01_rdat_valid             : out std_logic;
    bs01_rdat_ready             : in  std_logic := '1';
    bs01_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs01_rdat_last              : out std_logic;

    -- Master port 2.
    bs02_rreq_valid             : in  std_logic := '0';
    bs02_rreq_ready             : out std_logic;
    bs02_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs02_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs02_rdat_valid             : out std_logic;
    bs02_rdat_ready             : in  std_logic := '1';
    bs02_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs02_rdat_last              : out std_logic;

    -- Master port 3.
    bs03_rreq_valid             : in  std_logic := '0';
    bs03_rreq_ready             : out std_logic;
    bs03_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs03_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs03_rdat_valid             : out std_logic;
    bs03_rdat_ready             : in  std_logic := '1';
    bs03_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs03_rdat_last              : out std_logic;

    -- Master port 4.
    bs04_rreq_valid             : in  std_logic := '0';
    bs04_rreq_ready             : out std_logic;
    bs04_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs04_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs04_rdat_valid             : out std_logic;
    bs04_rdat_ready             : in  std_logic := '1';
    bs04_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs04_rdat_last              : out std_logic;

    -- Master port 5.
    bs05_rreq_valid             : in  std_logic := '0';
    bs05_rreq_ready             : out std_logic;
    bs05_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs05_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs05_rdat_valid             : out std_logic;
    bs05_rdat_ready             : in  std_logic := '1';
    bs05_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs05_rdat_last              : out std_logic;

    -- Master port 6.
    bs06_rreq_valid             : in  std_logic := '0';
    bs06_rreq_ready             : out std_logic;
    bs06_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs06_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs06_rdat_valid             : out std_logic;
    bs06_rdat_ready             : in  std_logic := '1';
    bs06_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs06_rdat_last              : out std_logic;

    -- Master port 7.
    bs07_rreq_valid             : in  std_logic := '0';
    bs07_rreq_ready             : out std_logic;
    bs07_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs07_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs07_rdat_valid             : out std_logic;
    bs07_rdat_ready             : in  std_logic := '1';
    bs07_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs07_rdat_last              : out std_logic;

    -- Master port 8.
    bs08_rreq_valid             : in  std_logic := '0';
    bs08_rreq_ready             : out std_logic;
    bs08_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs08_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs08_rdat_valid             : out std_logic;
    bs08_rdat_ready             : in  std_logic := '1';
    bs08_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs08_rdat_last              : out std_logic;

    -- Master port 9.
    bs09_rreq_valid             : in  std_logic := '0';
    bs09_rreq_ready             : out std_logic;
    bs09_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs09_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs09_rdat_valid             : out std_logic;
    bs09_rdat_ready             : in  std_logic := '1';
    bs09_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs09_rdat_last              : out std_logic;

    -- Master port 10.
    bs10_rreq_valid             : in  std_logic := '0';
    bs10_rreq_ready             : out std_logic;
    bs10_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs10_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs10_rdat_valid             : out std_logic;
    bs10_rdat_ready             : in  std_logic := '1';
    bs10_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs10_rdat_last              : out std_logic;

    -- Master port 11.
    bs11_rreq_valid             : in  std_logic := '0';
    bs11_rreq_ready             : out std_logic;
    bs11_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs11_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs11_rdat_valid             : out std_logic;
    bs11_rdat_ready             : in  std_logic := '1';
    bs11_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs11_rdat_last              : out std_logic;

    -- Master port 12.
    bs12_rreq_valid             : in  std_logic := '0';
    bs12_rreq_ready             : out std_logic;
    bs12_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs12_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs12_rdat_valid             : out std_logic;
    bs12_rdat_ready             : in  std_logic := '1';
    bs12_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs12_rdat_last              : out std_logic;

    -- Master port 13.
    bs13_rreq_valid             : in  std_logic := '0';
    bs13_rreq_ready             : out std_logic;
    bs13_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs13_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs13_rdat_valid             : out std_logic;
    bs13_rdat_ready             : in  std_logic := '1';
    bs13_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs13_rdat_last              : out std_logic;

    -- Master port 14.
    bs14_rreq_valid             : in  std_logic := '0';
    bs14_rreq_ready             : out std_logic;
    bs14_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs14_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs14_rdat_valid             : out std_logic;
    bs14_rdat_ready             : in  std_logic := '1';
    bs14_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs14_rdat_last              : out std_logic;

    -- Master port 15.
    bs15_rreq_valid             : in  std_logic := '0';
    bs15_rreq_ready             : out std_logic;
    bs15_rreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs15_rreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs15_rdat_valid             : out std_logic;
    bs15_rdat_ready             : in  std_logic := '1';
    bs15_rdat_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bs15_rdat_last              : out std_logic

  );
end BusReadArbiter;

architecture Behavioral of BusReadArbiter is

  -- Serialized slave ports.
  signal bsv_rreq_valid         : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_rreq_ready         : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_rreq_addr          : std_logic_vector(NUM_SLAVE_PORTS*BUS_ADDR_WIDTH-1 downto 0);
  signal bsv_rreq_len           : std_logic_vector(NUM_SLAVE_PORTS*BUS_LEN_WIDTH-1 downto 0);
  signal bsv_rdat_valid         : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_rdat_ready         : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_rdat_data          : std_logic_vector(NUM_SLAVE_PORTS*BUS_DATA_WIDTH-1 downto 0);
  signal bsv_rdat_last          : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);

begin

  -- Connect bus master 0 to internal signal.
  bs00_connect_gen: if NUM_SLAVE_PORTS > 0 generate
  begin
    bsv_rreq_valid(0)                                           <= bs00_rreq_valid;
    bs00_rreq_ready                                             <= bsv_rreq_ready(0);
    bsv_rreq_addr(1*BUS_ADDR_WIDTH-1 downto 0*BUS_ADDR_WIDTH)   <= bs00_rreq_addr;
    bsv_rreq_len(1*BUS_LEN_WIDTH-1 downto 0*BUS_LEN_WIDTH)      <= bs00_rreq_len;
    bs00_rdat_valid                                             <= bsv_rdat_valid(0);
    bsv_rdat_ready(0)                                           <= bs00_rdat_ready;
    bs00_rdat_data                                              <= bsv_rdat_data(1*BUS_DATA_WIDTH-1 downto 0*BUS_DATA_WIDTH);
    bs00_rdat_last                                              <= bsv_rdat_last(0);
  end generate;

  -- Connect bus master 1 to internal signal.
  bs01_connect_gen: if NUM_SLAVE_PORTS > 1 generate
  begin
    bsv_rreq_valid(1)                                           <= bs01_rreq_valid;
    bs01_rreq_ready                                             <= bsv_rreq_ready(1);
    bsv_rreq_addr(2*BUS_ADDR_WIDTH-1 downto 1*BUS_ADDR_WIDTH)   <= bs01_rreq_addr;
    bsv_rreq_len(2*BUS_LEN_WIDTH-1 downto 1*BUS_LEN_WIDTH)      <= bs01_rreq_len;
    bs01_rdat_valid                                             <= bsv_rdat_valid(1);
    bsv_rdat_ready(1)                                           <= bs01_rdat_ready;
    bs01_rdat_data                                              <= bsv_rdat_data(2*BUS_DATA_WIDTH-1 downto 1*BUS_DATA_WIDTH);
    bs01_rdat_last                                              <= bsv_rdat_last(1);
  end generate;

  -- Connect bus master 2 to internal signal.
  bs02_connect_gen: if NUM_SLAVE_PORTS > 2 generate
  begin
    bsv_rreq_valid(2)                                           <= bs02_rreq_valid;
    bs02_rreq_ready                                             <= bsv_rreq_ready(2);
    bsv_rreq_addr(3*BUS_ADDR_WIDTH-1 downto 2*BUS_ADDR_WIDTH)   <= bs02_rreq_addr;
    bsv_rreq_len(3*BUS_LEN_WIDTH-1 downto 2*BUS_LEN_WIDTH)      <= bs02_rreq_len;
    bs02_rdat_valid                                             <= bsv_rdat_valid(2);
    bsv_rdat_ready(2)                                           <= bs02_rdat_ready;
    bs02_rdat_data                                              <= bsv_rdat_data(3*BUS_DATA_WIDTH-1 downto 2*BUS_DATA_WIDTH);
    bs02_rdat_last                                              <= bsv_rdat_last(2);
  end generate;

  -- Connect bus master 3 to internal signal.
  bs03_connect_gen: if NUM_SLAVE_PORTS > 3 generate
  begin
    bsv_rreq_valid(3)                                           <= bs03_rreq_valid;
    bs03_rreq_ready                                             <= bsv_rreq_ready(3);
    bsv_rreq_addr(4*BUS_ADDR_WIDTH-1 downto 3*BUS_ADDR_WIDTH)   <= bs03_rreq_addr;
    bsv_rreq_len(4*BUS_LEN_WIDTH-1 downto 3*BUS_LEN_WIDTH)      <= bs03_rreq_len;
    bs03_rdat_valid                                             <= bsv_rdat_valid(3);
    bsv_rdat_ready(3)                                           <= bs03_rdat_ready;
    bs03_rdat_data                                              <= bsv_rdat_data(4*BUS_DATA_WIDTH-1 downto 3*BUS_DATA_WIDTH);
    bs03_rdat_last                                              <= bsv_rdat_last(3);
  end generate;

  -- Connect bus master 4 to internal signal.
  bs04_connect_gen: if NUM_SLAVE_PORTS > 4 generate
  begin
    bsv_rreq_valid(4)                                           <= bs04_rreq_valid;
    bs04_rreq_ready                                             <= bsv_rreq_ready(4);
    bsv_rreq_addr(5*BUS_ADDR_WIDTH-1 downto 4*BUS_ADDR_WIDTH)   <= bs04_rreq_addr;
    bsv_rreq_len(5*BUS_LEN_WIDTH-1 downto 4*BUS_LEN_WIDTH)      <= bs04_rreq_len;
    bs04_rdat_valid                                             <= bsv_rdat_valid(4);
    bsv_rdat_ready(4)                                           <= bs04_rdat_ready;
    bs04_rdat_data                                              <= bsv_rdat_data(5*BUS_DATA_WIDTH-1 downto 4*BUS_DATA_WIDTH);
    bs04_rdat_last                                              <= bsv_rdat_last(4);
  end generate;

  -- Connect bus master 5 to internal signal.
  bs05_connect_gen: if NUM_SLAVE_PORTS > 5 generate
  begin
    bsv_rreq_valid(5)                                           <= bs05_rreq_valid;
    bs05_rreq_ready                                             <= bsv_rreq_ready(5);
    bsv_rreq_addr(6*BUS_ADDR_WIDTH-1 downto 5*BUS_ADDR_WIDTH)   <= bs05_rreq_addr;
    bsv_rreq_len(6*BUS_LEN_WIDTH-1 downto 5*BUS_LEN_WIDTH)      <= bs05_rreq_len;
    bs05_rdat_valid                                             <= bsv_rdat_valid(5);
    bsv_rdat_ready(5)                                           <= bs05_rdat_ready;
    bs05_rdat_data                                              <= bsv_rdat_data(6*BUS_DATA_WIDTH-1 downto 5*BUS_DATA_WIDTH);
    bs05_rdat_last                                              <= bsv_rdat_last(5);
  end generate;

  -- Connect bus master 6 to internal signal.
  bs06_connect_gen: if NUM_SLAVE_PORTS > 6 generate
  begin
    bsv_rreq_valid(6)                                           <= bs06_rreq_valid;
    bs06_rreq_ready                                             <= bsv_rreq_ready(6);
    bsv_rreq_addr(7*BUS_ADDR_WIDTH-1 downto 6*BUS_ADDR_WIDTH)   <= bs06_rreq_addr;
    bsv_rreq_len(7*BUS_LEN_WIDTH-1 downto 6*BUS_LEN_WIDTH)      <= bs06_rreq_len;
    bs06_rdat_valid                                             <= bsv_rdat_valid(6);
    bsv_rdat_ready(6)                                           <= bs06_rdat_ready;
    bs06_rdat_data                                              <= bsv_rdat_data(7*BUS_DATA_WIDTH-1 downto 6*BUS_DATA_WIDTH);
    bs06_rdat_last                                              <= bsv_rdat_last(6);
  end generate;

  -- Connect bus master 7 to internal signal.
  bs07_connect_gen: if NUM_SLAVE_PORTS > 7 generate
  begin
    bsv_rreq_valid(7)                                           <= bs07_rreq_valid;
    bs07_rreq_ready                                             <= bsv_rreq_ready(7);
    bsv_rreq_addr(8*BUS_ADDR_WIDTH-1 downto 7*BUS_ADDR_WIDTH)   <= bs07_rreq_addr;
    bsv_rreq_len(8*BUS_LEN_WIDTH-1 downto 7*BUS_LEN_WIDTH)      <= bs07_rreq_len;
    bs07_rdat_valid                                             <= bsv_rdat_valid(7);
    bsv_rdat_ready(7)                                           <= bs07_rdat_ready;
    bs07_rdat_data                                              <= bsv_rdat_data(8*BUS_DATA_WIDTH-1 downto 7*BUS_DATA_WIDTH);
    bs07_rdat_last                                              <= bsv_rdat_last(7);
  end generate;

  -- Connect bus master 8 to internal signal.
  bs08_connect_gen: if NUM_SLAVE_PORTS > 8 generate
  begin
    bsv_rreq_valid(8)                                           <= bs08_rreq_valid;
    bs08_rreq_ready                                             <= bsv_rreq_ready(8);
    bsv_rreq_addr(9*BUS_ADDR_WIDTH-1 downto 8*BUS_ADDR_WIDTH)   <= bs08_rreq_addr;
    bsv_rreq_len(9*BUS_LEN_WIDTH-1 downto 8*BUS_LEN_WIDTH)      <= bs08_rreq_len;
    bs08_rdat_valid                                             <= bsv_rdat_valid(8);
    bsv_rdat_ready(8)                                           <= bs08_rdat_ready;
    bs08_rdat_data                                              <= bsv_rdat_data(9*BUS_DATA_WIDTH-1 downto 8*BUS_DATA_WIDTH);
    bs08_rdat_last                                              <= bsv_rdat_last(8);
  end generate;

  -- Connect bus master 9 to internal signal.
  bs09_connect_gen: if NUM_SLAVE_PORTS > 9 generate
  begin
    bsv_rreq_valid(9)                                           <= bs09_rreq_valid;
    bs09_rreq_ready                                             <= bsv_rreq_ready(9);
    bsv_rreq_addr(10*BUS_ADDR_WIDTH-1 downto 9*BUS_ADDR_WIDTH)  <= bs09_rreq_addr;
    bsv_rreq_len(10*BUS_LEN_WIDTH-1 downto 9*BUS_LEN_WIDTH)     <= bs09_rreq_len;
    bs09_rdat_valid                                             <= bsv_rdat_valid(9);
    bsv_rdat_ready(9)                                           <= bs09_rdat_ready;
    bs09_rdat_data                                              <= bsv_rdat_data(10*BUS_DATA_WIDTH-1 downto 9*BUS_DATA_WIDTH);
    bs09_rdat_last                                              <= bsv_rdat_last(9);
  end generate;

  -- Connect bus master 10 to internal signal.
  bs10_connect_gen: if NUM_SLAVE_PORTS > 10 generate
  begin
    bsv_rreq_valid(10)                                          <= bs10_rreq_valid;
    bs10_rreq_ready                                             <= bsv_rreq_ready(10);
    bsv_rreq_addr(11*BUS_ADDR_WIDTH-1 downto 10*BUS_ADDR_WIDTH) <= bs10_rreq_addr;
    bsv_rreq_len(11*BUS_LEN_WIDTH-1 downto 10*BUS_LEN_WIDTH)    <= bs10_rreq_len;
    bs10_rdat_valid                                             <= bsv_rdat_valid(10);
    bsv_rdat_ready(10)                                          <= bs10_rdat_ready;
    bs10_rdat_data                                              <= bsv_rdat_data(11*BUS_DATA_WIDTH-1 downto 10*BUS_DATA_WIDTH);
    bs10_rdat_last                                              <= bsv_rdat_last(10);
  end generate;

  -- Connect bus master 11 to internal signal.
  bs11_connect_gen: if NUM_SLAVE_PORTS > 11 generate
  begin
    bsv_rreq_valid(11)                                          <= bs11_rreq_valid;
    bs11_rreq_ready                                             <= bsv_rreq_ready(11);
    bsv_rreq_addr(12*BUS_ADDR_WIDTH-1 downto 11*BUS_ADDR_WIDTH) <= bs11_rreq_addr;
    bsv_rreq_len(12*BUS_LEN_WIDTH-1 downto 11*BUS_LEN_WIDTH)    <= bs11_rreq_len;
    bs11_rdat_valid                                             <= bsv_rdat_valid(11);
    bsv_rdat_ready(11)                                          <= bs11_rdat_ready;
    bs11_rdat_data                                              <= bsv_rdat_data(12*BUS_DATA_WIDTH-1 downto 11*BUS_DATA_WIDTH);
    bs11_rdat_last                                              <= bsv_rdat_last(11);
  end generate;

  -- Connect bus master 12 to internal signal.
  bs12_connect_gen: if NUM_SLAVE_PORTS > 12 generate
  begin
    bsv_rreq_valid(12)                                          <= bs12_rreq_valid;
    bs12_rreq_ready                                             <= bsv_rreq_ready(12);
    bsv_rreq_addr(13*BUS_ADDR_WIDTH-1 downto 12*BUS_ADDR_WIDTH) <= bs12_rreq_addr;
    bsv_rreq_len(13*BUS_LEN_WIDTH-1 downto 12*BUS_LEN_WIDTH)    <= bs12_rreq_len;
    bs12_rdat_valid                                             <= bsv_rdat_valid(12);
    bsv_rdat_ready(12)                                          <= bs12_rdat_ready;
    bs12_rdat_data                                              <= bsv_rdat_data(13*BUS_DATA_WIDTH-1 downto 12*BUS_DATA_WIDTH);
    bs12_rdat_last                                              <= bsv_rdat_last(12);
  end generate;

  -- Connect bus master 13 to internal signal.
  bs13_connect_gen: if NUM_SLAVE_PORTS > 13 generate
  begin
    bsv_rreq_valid(13)                                          <= bs13_rreq_valid;
    bs13_rreq_ready                                             <= bsv_rreq_ready(13);
    bsv_rreq_addr(14*BUS_ADDR_WIDTH-1 downto 13*BUS_ADDR_WIDTH) <= bs13_rreq_addr;
    bsv_rreq_len(14*BUS_LEN_WIDTH-1 downto 13*BUS_LEN_WIDTH)    <= bs13_rreq_len;
    bs13_rdat_valid                                             <= bsv_rdat_valid(13);
    bsv_rdat_ready(13)                                          <= bs13_rdat_ready;
    bs13_rdat_data                                              <= bsv_rdat_data(14*BUS_DATA_WIDTH-1 downto 13*BUS_DATA_WIDTH);
    bs13_rdat_last                                              <= bsv_rdat_last(13);
  end generate;

  -- Connect bus master 14 to internal signal.
  bs14_connect_gen: if NUM_SLAVE_PORTS > 14 generate
  begin
    bsv_rreq_valid(14)                                          <= bs14_rreq_valid;
    bs14_rreq_ready                                             <= bsv_rreq_ready(14);
    bsv_rreq_addr(15*BUS_ADDR_WIDTH-1 downto 14*BUS_ADDR_WIDTH) <= bs14_rreq_addr;
    bsv_rreq_len(15*BUS_LEN_WIDTH-1 downto 14*BUS_LEN_WIDTH)    <= bs14_rreq_len;
    bs14_rdat_valid                                             <= bsv_rdat_valid(14);
    bsv_rdat_ready(14)                                          <= bs14_rdat_ready;
    bs14_rdat_data                                              <= bsv_rdat_data(15*BUS_DATA_WIDTH-1 downto 14*BUS_DATA_WIDTH);
    bs14_rdat_last                                              <= bsv_rdat_last(14);
  end generate;

  -- Connect bus master 15 to internal signal.
  bs15_connect_gen: if NUM_SLAVE_PORTS > 15 generate
  begin
    bsv_rreq_valid(15)                                          <= bs15_rreq_valid;
    bs15_rreq_ready                                             <= bsv_rreq_ready(15);
    bsv_rreq_addr(16*BUS_ADDR_WIDTH-1 downto 15*BUS_ADDR_WIDTH) <= bs15_rreq_addr;
    bsv_rreq_len(16*BUS_LEN_WIDTH-1 downto 15*BUS_LEN_WIDTH)    <= bs15_rreq_len;
    bs15_rdat_valid                                             <= bsv_rdat_valid(15);
    bsv_rdat_ready(15)                                          <= bs15_rdat_ready;
    bs15_rdat_data                                              <= bsv_rdat_data(16*BUS_DATA_WIDTH-1 downto 15*BUS_DATA_WIDTH);
    bs15_rdat_last                                              <= bsv_rdat_last(15);
  end generate;

  arb_inst: BusReadArbiterVec
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      NUM_SLAVE_PORTS           => NUM_SLAVE_PORTS,
      ARB_METHOD                => ARB_METHOD,
      MAX_OUTSTANDING           => MAX_OUTSTANDING,
      RAM_CONFIG                => RAM_CONFIG,
      SLV_REQ_SLICES            => SLV_REQ_SLICES,
      MST_REQ_SLICE             => MST_REQ_SLICE,
      MST_DAT_SLICE             => MST_DAT_SLICE,
      SLV_DAT_SLICES            => SLV_DAT_SLICES
    )
    port map (
      bcd_clk                   => bcd_clk,
      bcd_reset                 => bcd_reset,

      mst_rreq_valid            => mst_rreq_valid,
      mst_rreq_ready            => mst_rreq_ready,
      mst_rreq_addr             => mst_rreq_addr,
      mst_rreq_len              => mst_rreq_len,
      mst_rdat_valid            => mst_rdat_valid,
      mst_rdat_ready            => mst_rdat_ready,
      mst_rdat_data             => mst_rdat_data,
      mst_rdat_last             => mst_rdat_last,

      bsv_rreq_valid            => bsv_rreq_valid,
      bsv_rreq_ready            => bsv_rreq_ready,
      bsv_rreq_addr             => bsv_rreq_addr,
      bsv_rreq_len              => bsv_rreq_len,
      bsv_rdat_valid            => bsv_rdat_valid,
      bsv_rdat_ready            => bsv_rdat_ready,
      bsv_rdat_data             => bsv_rdat_data,
      bsv_rdat_last             => bsv_rdat_last
    );

end Behavioral;

