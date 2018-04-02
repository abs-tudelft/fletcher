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
use work.Streams.all;
use work.Utils.all;
use work.Arrow.all;

-- This unit acts as an arbiter for the bus system utilized by the
-- BufferWriters.

entity BusWriteArbiter is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Number of bus masters to arbitrate between.
    NUM_SLAVES                 : natural := 2;

    -- Arbitration method. Must be "ROUND-ROBIN" or "FIXED". If fixed,
    -- lower-indexed masters take precedence.
    ARB_METHOD                  : string := "ROUND-ROBIN";

    -- Maximum number of outstanding requests. This is rounded upward to
    -- whatever is convenient internally.
    MAX_OUTSTANDING             : natural := 2;

    -- RAM configuration string for the outstanding request FIFO.
    RAM_CONFIG                  : string := "";

    -- Whether a register slice should be inserted into the bus request input
    -- streams.
    REQ_IN_SLICES               : boolean := false;

    -- Whether a register slice should be inserted into the bus request output
    -- stream.
    REQ_OUT_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the bus response input
    -- stream.
    RESP_IN_SLICE               : boolean := false;

    -- Whether a register slice should be inserted into the bus response output
    -- streams.
    RESP_OUT_SLICES             : boolean := true

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferWriter.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Master port.
    mst_wreq_valid              : out std_logic;
    mst_wreq_ready              : in  std_logic;
    mst_wreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_wreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_wdat_valid              : out std_logic;
    mst_wdat_ready              : in  std_logic;
    mst_wdat_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_wdat_last               : out std_logic;

    -- Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn

    -- Slave port 0.
    bs0_wreq_valid              : in  std_logic := '0';
    bs0_wreq_ready              : out std_logic;
    bs0_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs0_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs0_wdat_valid              : in  std_logic := '0';
    bs0_wdat_ready              : out std_logic := '1';
    bs0_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs0_wdat_last               : in  std_logic := 'U';

    -- Slave port 1.
    bs1_wreq_valid              : in  std_logic := '0';
    bs1_wreq_ready              : out std_logic;
    bs1_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs1_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs1_wdat_valid              : in  std_logic := '0';
    bs1_wdat_ready              : out std_logic := '1';
    bs1_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs1_wdat_last               : in  std_logic := 'U';

    -- Slave port 2.
    bs2_wreq_valid              : in  std_logic := '0';
    bs2_wreq_ready              : out std_logic;
    bs2_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs2_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs2_wdat_valid              : in  std_logic := '0';
    bs2_wdat_ready              : out std_logic := '1';
    bs2_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs2_wdat_last               : in  std_logic := 'U';

    -- Slave port 3.
    bs3_wreq_valid              : in  std_logic := '0';
    bs3_wreq_ready              : out std_logic;
    bs3_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs3_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs3_wdat_valid              : in  std_logic := '0';
    bs3_wdat_ready              : out std_logic := '1';
    bs3_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs3_wdat_last               : in  std_logic := 'U';

    -- Slave port 4.
    bs4_wreq_valid              : in  std_logic := '0';
    bs4_wreq_ready              : out std_logic;
    bs4_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs4_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs4_wdat_valid              : in  std_logic := '0';
    bs4_wdat_ready              : out std_logic := '1';
    bs4_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs4_wdat_last               : in  std_logic := 'U';

    -- Slave port 5.
    bs5_wreq_valid              : in  std_logic := '0';
    bs5_wreq_ready              : out std_logic;
    bs5_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs5_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs5_wdat_valid              : in  std_logic := '0';
    bs5_wdat_ready              : out std_logic := '1';
    bs5_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs5_wdat_last               : in  std_logic := 'U';

    -- Slave port 6.
    bs6_wreq_valid              : in  std_logic := '0';
    bs6_wreq_ready              : out std_logic;
    bs6_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs6_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs6_wdat_valid              : in  std_logic := '0';
    bs6_wdat_ready              : out std_logic := '1';
    bs6_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs6_wdat_last               : in  std_logic := 'U';

    -- Slave port 7.
    bs7_wreq_valid              : in  std_logic := '0';
    bs7_wreq_ready              : out std_logic;
    bs7_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs7_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs7_wdat_valid              : in  std_logic := '0';
    bs7_wdat_ready              : out std_logic := '1';
    bs7_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs7_wdat_last               : in  std_logic := 'U';

    -- Slave port 8.
    bs8_wreq_valid              : in  std_logic := '0';
    bs8_wreq_ready              : out std_logic;
    bs8_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs8_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs8_wdat_valid              : in  std_logic := '0';
    bs8_wdat_ready              : out std_logic := '1';
    bs8_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs8_wdat_last               : in  std_logic := 'U';

    -- Slave port 9.
    bs9_wreq_valid              : in  std_logic := '0';
    bs9_wreq_ready              : out std_logic;
    bs9_wreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs9_wreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs9_wdat_valid              : in  std_logic := '0';
    bs9_wdat_ready              : out std_logic := '1';
    bs9_wdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs9_wdat_last               : in  std_logic := 'U';

    -- Slave port 10.
    bs10_wreq_valid             : in  std_logic := '0';
    bs10_wreq_ready             : out std_logic;
    bs10_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs10_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs10_wdat_valid             : in  std_logic := '0';
    bs10_wdat_ready             : out std_logic := '1';
    bs10_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs10_wdat_last              : in  std_logic := 'U';

    -- Slave port 11.
    bs11_wreq_valid             : in  std_logic := '0';
    bs11_wreq_ready             : out std_logic;
    bs11_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs11_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs11_wdat_valid             : in  std_logic := '0';
    bs11_wdat_ready             : out std_logic := '1';
    bs11_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs11_wdat_last              : in  std_logic := 'U';

    -- Slave port 12.
    bs12_wreq_valid             : in  std_logic := '0';
    bs12_wreq_ready             : out std_logic;
    bs12_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs12_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs12_wdat_valid             : in  std_logic := '0';
    bs12_wdat_ready             : out std_logic := '1';
    bs12_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs12_wdat_last              : in  std_logic := 'U';

    -- Slave port 13.
    bs13_wreq_valid             : in  std_logic := '0';
    bs13_wreq_ready             : out std_logic;
    bs13_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs13_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs13_wdat_valid             : in  std_logic := '0';
    bs13_wdat_ready             : out std_logic := '1';
    bs13_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs13_wdat_last              : in  std_logic := 'U';

    -- Slave port 14.
    bs14_wreq_valid             : in  std_logic := '0';
    bs14_wreq_ready             : out std_logic;
    bs14_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs14_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs14_wdat_valid             : in  std_logic := '0';
    bs14_wdat_ready             : out std_logic := '1';
    bs14_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs14_wdat_last              : in  std_logic := 'U';

    -- Slave port 15.
    bs15_wreq_valid             : in  std_logic := '0';
    bs15_wreq_ready             : out std_logic;
    bs15_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs15_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs15_wdat_valid             : in  std_logic := '0';
    bs15_wdat_ready             : out std_logic := '1';
    bs15_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs15_wdat_last              : in  std_logic := 'U'

  );
end BusWriteArbiter;

architecture Behavioral of BusWriteArbiter is

  -- Serialized master busses.
  signal bsv_wreq_valid          : std_logic_vector(NUM_SLAVES-1 downto 0);
  signal bsv_wreq_ready          : std_logic_vector(NUM_SLAVES-1 downto 0);
  signal bsv_wreq_addr           : std_logic_vector(NUM_SLAVES*BUS_ADDR_WIDTH-1 downto 0);
  signal bsv_wreq_len            : std_logic_vector(NUM_SLAVES*BUS_LEN_WIDTH-1 downto 0);
  signal bsv_wdat_valid         : std_logic_vector(NUM_SLAVES-1 downto 0);
  signal bsv_wdat_ready         : std_logic_vector(NUM_SLAVES-1 downto 0);
  signal bsv_wdat_data          : std_logic_vector(NUM_SLAVES*BUS_DATA_WIDTH-1 downto 0);
  signal bsv_wdat_last          : std_logic_vector(NUM_SLAVES-1 downto 0);

begin

  -- Connect bus slave 0 to internal signal.
  bs0_connect_gen: if NUM_SLAVES > 0 generate
  begin
    bsv_wreq_valid (0)                                          <= bs0_wreq_valid;
    bs0_wreq_ready                                              <= bsv_wreq_ready (0);
    bsv_wreq_addr  (1*BUS_ADDR_WIDTH-1 downto 0*BUS_ADDR_WIDTH) <= bs0_wreq_addr;
    bsv_wreq_len   (1*BUS_LEN_WIDTH-1 downto 0*BUS_LEN_WIDTH)   <= bs0_wreq_len;
    bsv_wdat_valid (0)                                          <= bs0_wdat_valid;
    bs0_wdat_ready                                              <= bsv_wdat_ready(0);
    bsv_wdat_data  (1*BUS_DATA_WIDTH-1 downto 0*BUS_DATA_WIDTH) <= bs0_wdat_data;
    bsv_wdat_last  (0)                                          <= bs0_wdat_last;
  end generate;

  -- Connect bus slave 1 to internal signal.
  bs1_connect_gen: if NUM_SLAVES > 1 generate
  begin
    bsv_wreq_valid (1)                                          <= bs1_wreq_valid;
    bs1_wreq_ready                                              <= bsv_wreq_ready(1);
    bsv_wreq_addr  (2*BUS_ADDR_WIDTH-1 downto 1*BUS_ADDR_WIDTH) <= bs1_wreq_addr;
    bsv_wreq_len   (2*BUS_LEN_WIDTH-1  downto 1*BUS_LEN_WIDTH)  <= bs1_wreq_len;
    bsv_wdat_valid (1)                                          <= bs1_wdat_valid;
    bs1_wdat_ready                                              <= bsv_wdat_ready(1);
    bsv_wdat_data  (2*BUS_DATA_WIDTH-1 downto 1*BUS_DATA_WIDTH) <= bs1_wdat_data;
    bsv_wdat_last  (1)                                          <= bs1_wdat_last;
  end generate;

  -- Connect bus slave 2 to internal signal.
  bs2_connect_gen: if NUM_SLAVES > 2 generate
  begin
    bsv_wreq_valid (2)                                          <= bs2_wreq_valid;
    bs2_wreq_ready                                              <= bsv_wreq_ready(2);
    bsv_wreq_addr  (3*BUS_ADDR_WIDTH-1 downto 2*BUS_ADDR_WIDTH) <= bs2_wreq_addr;
    bsv_wreq_len   (3*BUS_LEN_WIDTH-1 downto  2*BUS_LEN_WIDTH)  <= bs2_wreq_len;
    bsv_wdat_valid (2)                                          <= bs2_wdat_valid;
    bs2_wdat_ready                                              <= bsv_wdat_ready(2);
    bsv_wdat_data  (3*BUS_DATA_WIDTH-1 downto 2*BUS_DATA_WIDTH) <= bs2_wdat_data;
    bsv_wdat_last  (2)                                          <= bs2_wdat_last;
  end generate;

  -- Connect bus slave 3 to internal signal.
  bs3_connect_gen: if NUM_SLAVES > 3 generate
  begin
    bsv_wreq_valid (3)                                          <= bs3_wreq_valid;
    bs3_wreq_ready                                              <= bsv_wreq_ready(3);
    bsv_wreq_addr  (4*BUS_ADDR_WIDTH-1 downto 3*BUS_ADDR_WIDTH) <= bs3_wreq_addr;
    bsv_wreq_len   (4*BUS_LEN_WIDTH-1 downto  3*BUS_LEN_WIDTH)  <= bs3_wreq_len;
    bsv_wdat_valid (3)                                          <= bs3_wdat_valid;
    bs3_wdat_ready                                              <= bsv_wdat_ready(3);
    bsv_wdat_data  (4*BUS_DATA_WIDTH-1 downto 3*BUS_DATA_WIDTH) <= bs3_wdat_data;
    bsv_wdat_last  (3)                                          <= bs3_wdat_last;
  end generate;

  -- Connect bus slave 4 to internal signal.
  bs4_connect_gen: if NUM_SLAVES > 4 generate
  begin
    bsv_wreq_valid (4)                                          <= bs4_wreq_valid;
    bs4_wreq_ready                                              <= bsv_wreq_ready(4);
    bsv_wreq_addr  (5*BUS_ADDR_WIDTH-1 downto 4*BUS_ADDR_WIDTH) <= bs4_wreq_addr;
    bsv_wreq_len   (5*BUS_LEN_WIDTH-1 downto  4*BUS_LEN_WIDTH)  <= bs4_wreq_len;
    bsv_wdat_valid (4)                                          <= bs4_wdat_valid;
    bs4_wdat_ready                                              <= bsv_wdat_ready(4);
    bsv_wdat_data  (5*BUS_DATA_WIDTH-1 downto 4*BUS_DATA_WIDTH) <= bs4_wdat_data;
    bsv_wdat_last  (4)                                          <= bs4_wdat_last;
  end generate;

  -- Connect bus slave 5 to internal signal.
  bs5_connect_gen: if NUM_SLAVES > 5 generate
  begin
    bsv_wreq_valid (5)                                          <= bs5_wreq_valid;
    bs5_wreq_ready                                              <= bsv_wreq_ready(5);
    bsv_wreq_addr  (6*BUS_ADDR_WIDTH-1 downto 5*BUS_ADDR_WIDTH) <= bs5_wreq_addr;
    bsv_wreq_len   (6*BUS_LEN_WIDTH-1 downto  5*BUS_LEN_WIDTH)  <= bs5_wreq_len;
    bsv_wdat_valid (5)                                          <= bs5_wdat_valid;
    bs5_wdat_ready                                              <= bsv_wdat_ready(5);
    bsv_wdat_data  (6*BUS_DATA_WIDTH-1 downto 5*BUS_DATA_WIDTH) <= bs5_wdat_data;
    bsv_wdat_last  (5)                                          <= bs5_wdat_last;
  end generate;

  -- Connect bus slave 6 to internal signal.
  bs6_connect_gen: if NUM_SLAVES > 6 generate
  begin
    bsv_wreq_valid (6)                                          <= bs6_wreq_valid;
    bs6_wreq_ready                                              <= bsv_wreq_ready(6);
    bsv_wreq_addr  (7*BUS_ADDR_WIDTH-1 downto 7*BUS_ADDR_WIDTH) <= bs6_wreq_addr;
    bsv_wreq_len   (7*BUS_LEN_WIDTH-1 downto  7*BUS_LEN_WIDTH)  <= bs6_wreq_len;
    bsv_wdat_valid (6)                                          <= bs6_wdat_valid;
    bs6_wdat_ready                                              <= bsv_wdat_ready(6);
    bsv_wdat_data  (7*BUS_DATA_WIDTH-1 downto 7*BUS_DATA_WIDTH) <= bs6_wdat_data;
    bsv_wdat_last  (6)                                          <= bs6_wdat_last;
  end generate;

  -- Connect bus slave 7 to internal signal.
  bs7_connect_gen: if NUM_SLAVES > 7 generate
  begin
    bsv_wreq_valid (7)                                          <= bs7_wreq_valid;
    bs7_wreq_ready                                              <= bsv_wreq_ready(7);
    bsv_wreq_addr  (8*BUS_ADDR_WIDTH-1 downto 8*BUS_ADDR_WIDTH) <= bs7_wreq_addr;
    bsv_wreq_len   (8*BUS_LEN_WIDTH-1 downto  8*BUS_LEN_WIDTH)  <= bs7_wreq_len;
    bsv_wdat_valid (7)                                          <= bs7_wdat_valid;
    bs7_wdat_ready                                              <= bsv_wdat_ready(7);
    bsv_wdat_data  (8*BUS_DATA_WIDTH-1 downto 8*BUS_DATA_WIDTH) <= bs7_wdat_data;
    bsv_wdat_last  (7)                                          <= bs7_wdat_last;
  end generate;

  -- Connect bus slave 8 to internal signal.
  bs8_connect_gen: if NUM_SLAVES > 8 generate
  begin
    bsv_wreq_valid (8)                                          <= bs8_wreq_valid;
    bs8_wreq_ready                                              <= bsv_wreq_ready(8);
    bsv_wreq_addr  (9*BUS_ADDR_WIDTH-1 downto 9*BUS_ADDR_WIDTH) <= bs8_wreq_addr;
    bsv_wreq_len   (9*BUS_LEN_WIDTH-1 downto  9*BUS_LEN_WIDTH)  <= bs8_wreq_len;
    bsv_wdat_valid (8)                                          <= bs8_wdat_valid;
    bs8_wdat_ready                                              <= bsv_wdat_ready(8);
    bsv_wdat_data  (9*BUS_DATA_WIDTH-1 downto 9*BUS_DATA_WIDTH) <= bs8_wdat_data;
    bsv_wdat_last  (8)                                          <= bs8_wdat_last;
  end generate;

  -- Connect bus slave 9 to internal signal.
  bs9_connect_gen: if NUM_SLAVES > 9 generate
  begin
    bsv_wreq_valid (9)                                            <= bs9_wreq_valid;
    bs9_wreq_ready                                                <= bsv_wreq_ready(9);
    bsv_wreq_addr  (10*BUS_ADDR_WIDTH-1 downto 10*BUS_ADDR_WIDTH) <= bs9_wreq_addr;
    bsv_wreq_len   (10*BUS_LEN_WIDTH-1 downto  10*BUS_LEN_WIDTH)  <= bs9_wreq_len;
    bsv_wdat_valid (9)                                            <= bs9_wdat_valid;
    bs9_wdat_ready                                                <= bsv_wdat_ready(9);
    bsv_wdat_data  (10*BUS_DATA_WIDTH-1 downto 10*BUS_DATA_WIDTH) <= bs9_wdat_data;
    bsv_wdat_last  (9)                                            <= bs9_wdat_last;
  end generate;

  -- Connect bus slave 10 to internal signal.
  bs10_connect_gen: if NUM_SLAVES > 10 generate
  begin
    bsv_wreq_valid (10)                                           <= bs10_wreq_valid;
    bs10_wreq_ready                                               <= bsv_wreq_ready(10);
    bsv_wreq_addr  (11*BUS_ADDR_WIDTH-1 downto 10*BUS_ADDR_WIDTH) <= bs10_wreq_addr;
    bsv_wreq_len   (11*BUS_LEN_WIDTH-1 downto  10*BUS_LEN_WIDTH)  <= bs10_wreq_len;
    bsv_wdat_valid (10)                                           <= bs10_wdat_valid;
    bs10_wdat_ready                                               <= bsv_wdat_ready(10);
    bsv_wdat_data  (11*BUS_DATA_WIDTH-1 downto 10*BUS_DATA_WIDTH) <= bs10_wdat_data;
    bsv_wdat_last  (10)                                           <= bs10_wdat_last;
  end generate;

  -- Connect bus slave 11 to internal signal.
  bs11_connect_gen: if NUM_SLAVES > 11 generate
  begin
    bsv_wreq_valid (11)                                           <= bs11_wreq_valid;
    bs11_wreq_ready                                               <= bsv_wreq_ready(11);
    bsv_wreq_addr  (12*BUS_ADDR_WIDTH-1 downto 11*BUS_ADDR_WIDTH) <= bs11_wreq_addr;
    bsv_wreq_len   (12*BUS_LEN_WIDTH-1 downto  11*BUS_LEN_WIDTH)  <= bs11_wreq_len;
    bsv_wdat_valid (11)                                           <= bs11_wdat_valid;
    bs11_wdat_ready                                               <= bsv_wdat_ready(11);
    bsv_wdat_data  (12*BUS_DATA_WIDTH-1 downto 11*BUS_DATA_WIDTH) <= bs11_wdat_data;
    bsv_wdat_last  (11)                                           <= bs11_wdat_last;
  end generate;

  -- Connect bus slave 12 to internal signal.
  bs12_connect_gen: if NUM_SLAVES > 12 generate
  begin
    bsv_wreq_valid (12)                                           <= bs12_wreq_valid;
    bs12_wreq_ready                                               <= bsv_wreq_ready(12);
    bsv_wreq_addr  (13*BUS_ADDR_WIDTH-1 downto 11*BUS_ADDR_WIDTH) <= bs12_wreq_addr;
    bsv_wreq_len   (13*BUS_LEN_WIDTH-1 downto  11*BUS_LEN_WIDTH)  <= bs12_wreq_len;
    bsv_wdat_valid (12)                                           <= bs12_wdat_valid;
    bs12_wdat_ready                                               <= bsv_wdat_ready(12);
    bsv_wdat_data  (13*BUS_DATA_WIDTH-1 downto 11*BUS_DATA_WIDTH) <= bs12_wdat_data;
    bsv_wdat_last  (12)                                           <= bs12_wdat_last;
  end generate;

  -- Connect bus slave 13 to internal signal.
  bs13_connect_gen: if NUM_SLAVES > 13 generate
  begin
    bsv_wreq_valid (13)                                           <= bs13_wreq_valid;
    bs13_wreq_ready                                               <= bsv_wreq_ready(13);
    bsv_wreq_addr  (14*BUS_ADDR_WIDTH-1 downto 12*BUS_ADDR_WIDTH) <= bs13_wreq_addr;
    bsv_wreq_len   (14*BUS_LEN_WIDTH-1 downto  12*BUS_LEN_WIDTH)  <= bs13_wreq_len;
    bsv_wdat_valid (13)                                           <= bs13_wdat_valid;
    bs13_wdat_ready                                               <= bsv_wdat_ready(13);
    bsv_wdat_data  (14*BUS_DATA_WIDTH-1 downto 12*BUS_DATA_WIDTH) <= bs13_wdat_data;
    bsv_wdat_last  (13)                                           <= bs13_wdat_last;
  end generate;

  -- Connect bus slave 14 to internal signal.
  bs14_connect_gen: if NUM_SLAVES > 14 generate
  begin
    bsv_wreq_valid (14)                                           <= bs14_wreq_valid;
    bs14_wreq_ready                                               <= bsv_wreq_ready(14);
    bsv_wreq_addr  (15*BUS_ADDR_WIDTH-1 downto 13*BUS_ADDR_WIDTH) <= bs14_wreq_addr;
    bsv_wreq_len   (15*BUS_LEN_WIDTH-1 downto  13*BUS_LEN_WIDTH)  <= bs14_wreq_len;
    bsv_wdat_valid (14)                                           <= bs14_wdat_valid;
    bs14_wdat_ready                                               <= bsv_wdat_ready(14);
    bsv_wdat_data  (15*BUS_DATA_WIDTH-1 downto 13*BUS_DATA_WIDTH) <= bs14_wdat_data;
    bsv_wdat_last  (14)                                           <= bs14_wdat_last;
  end generate;

  -- Connect bus slave 15 to internal signal.
  bs15_connect_gen: if NUM_SLAVES > 15 generate
  begin
    bsv_wreq_valid (15)                                           <= bs15_wreq_valid;
    bs15_wreq_ready                                               <= bsv_wreq_ready(15);
    bsv_wreq_addr  (16*BUS_ADDR_WIDTH-1 downto 14*BUS_ADDR_WIDTH) <= bs15_wreq_addr;
    bsv_wreq_len   (16*BUS_LEN_WIDTH-1 downto  14*BUS_LEN_WIDTH)  <= bs15_wreq_len;
    bsv_wdat_valid (15)                                           <= bs15_wdat_valid;
    bs15_wdat_ready                                               <= bsv_wdat_ready(15);
    bsv_wdat_data  (16*BUS_DATA_WIDTH-1 downto 14*BUS_DATA_WIDTH) <= bs15_wdat_data;
    bsv_wdat_last  (15)                                           <= bs15_wdat_last;
  end generate;

  arb_inst: BusWriteArbiterVec
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      NUM_SLAVES               => NUM_SLAVES,
      ARB_METHOD                => ARB_METHOD,
      MAX_OUTSTANDING           => MAX_OUTSTANDING,
      RAM_CONFIG                => RAM_CONFIG,
      REQ_IN_SLICES             => REQ_IN_SLICES,
      REQ_OUT_SLICE             => REQ_OUT_SLICE,
      RESP_IN_SLICE             => RESP_IN_SLICE,
      RESP_OUT_SLICES           => RESP_OUT_SLICES
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      mst_wreq_valid            => mst_wreq_valid,
      mst_wreq_ready            => mst_wreq_ready,
      mst_wreq_addr             => mst_wreq_addr,
      mst_wreq_len              => mst_wreq_len,
      mst_wdat_valid            => mst_wdat_valid,
      mst_wdat_ready            => mst_wdat_ready,
      mst_wdat_data             => mst_wdat_data,
      mst_wdat_last             => mst_wdat_last,

      bsv_wreq_valid            => bsv_wreq_valid,
      bsv_wreq_ready            => bsv_wreq_ready,
      bsv_wreq_addr             => bsv_wreq_addr,
      bsv_wreq_len              => bsv_wreq_len,
      bsv_wdat_valid            => bsv_wdat_valid,
      bsv_wdat_ready            => bsv_wdat_ready,
      bsv_wdat_data             => bsv_wdat_data,
      bsv_wdat_last             => bsv_wdat_last
    );

end Behavioral;

