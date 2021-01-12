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

    -- Whether a register slice should be inserted into the slave data ports
    SLV_DAT_SLICES              : boolean := true;

    -- Whether a register slice should be inserted into the master data port
    MST_DAT_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the master response port
    MST_REP_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the slave response ports
    SLV_REP_SLICES              : boolean := true
  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferWriter.
    bcd_clk                     : in  std_logic;
    bcd_reset                   : in  std_logic;

    -- Master port.
    mst_wreq_valid              : out std_logic;
    mst_wreq_ready              : in  std_logic;
    mst_wreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_wreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_wreq_last               : out std_logic;
    mst_wdat_valid              : out std_logic;
    mst_wdat_ready              : in  std_logic;
    mst_wdat_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_wdat_strobe             : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
    mst_wdat_last               : out std_logic;
    mst_wrep_valid              : in  std_logic;
    mst_wrep_ready              : out std_logic;
    mst_wrep_ok                 : in  std_logic;

    -- Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn

    -- Slave port 0.
    bs00_wreq_valid             : in  std_logic := '0';
    bs00_wreq_ready             : out std_logic;
    bs00_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs00_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs00_wreq_last              : in  std_logic := '0';
    bs00_wdat_valid             : in  std_logic := '0';
    bs00_wdat_ready             : out std_logic;
    bs00_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs00_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs00_wdat_last              : in  std_logic := 'U';
    bs00_wrep_valid             : out std_logic;
    bs00_wrep_ready             : in  std_logic := '1';
    bs00_wrep_ok                : out std_logic;

    -- Slave port 1.
    bs01_wreq_valid             : in  std_logic := '0';
    bs01_wreq_ready             : out std_logic;
    bs01_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs01_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs01_wreq_last              : in  std_logic := '0';
    bs01_wdat_valid             : in  std_logic := '0';
    bs01_wdat_ready             : out std_logic;
    bs01_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs01_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs01_wdat_last              : in  std_logic := 'U';
    bs01_wrep_valid             : out std_logic;
    bs01_wrep_ready             : in  std_logic := '1';
    bs01_wrep_ok                : out std_logic;

    -- Slave port 2.
    bs02_wreq_valid             : in  std_logic := '0';
    bs02_wreq_ready             : out std_logic;
    bs02_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs02_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs02_wreq_last              : in  std_logic := '0';
    bs02_wdat_valid             : in  std_logic := '0';
    bs02_wdat_ready             : out std_logic;
    bs02_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs02_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs02_wdat_last              : in  std_logic := 'U';
    bs02_wrep_valid             : out std_logic;
    bs02_wrep_ready             : in  std_logic := '1';
    bs02_wrep_ok                : out std_logic;

    -- Slave port 3.
    bs03_wreq_valid             : in  std_logic := '0';
    bs03_wreq_ready             : out std_logic;
    bs03_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs03_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs03_wreq_last              : in  std_logic := '0';
    bs03_wdat_valid             : in  std_logic := '0';
    bs03_wdat_ready             : out std_logic;
    bs03_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs03_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs03_wdat_last              : in  std_logic := 'U';
    bs03_wrep_valid             : out std_logic;
    bs03_wrep_ready             : in  std_logic := '1';
    bs03_wrep_ok                : out std_logic;

    -- Slave port 4.
    bs04_wreq_valid             : in  std_logic := '0';
    bs04_wreq_ready             : out std_logic;
    bs04_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs04_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs04_wreq_last              : in  std_logic := '0';
    bs04_wdat_valid             : in  std_logic := '0';
    bs04_wdat_ready             : out std_logic;
    bs04_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs04_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs04_wdat_last              : in  std_logic := 'U';
    bs04_wrep_valid             : out std_logic;
    bs04_wrep_ready             : in  std_logic := '1';
    bs04_wrep_ok                : out std_logic;

    -- Slave port 5.
    bs05_wreq_valid             : in  std_logic := '0';
    bs05_wreq_ready             : out std_logic;
    bs05_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs05_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs05_wreq_last              : in  std_logic := '0';
    bs05_wdat_valid             : in  std_logic := '0';
    bs05_wdat_ready             : out std_logic;
    bs05_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs05_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs05_wdat_last              : in  std_logic := 'U';
    bs05_wrep_valid             : out std_logic;
    bs05_wrep_ready             : in  std_logic := '1';
    bs05_wrep_ok                : out std_logic;

    -- Slave port 6.
    bs06_wreq_valid             : in  std_logic := '0';
    bs06_wreq_ready             : out std_logic;
    bs06_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs06_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs06_wreq_last              : in  std_logic := '0';
    bs06_wdat_valid             : in  std_logic := '0';
    bs06_wdat_ready             : out std_logic;
    bs06_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs06_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs06_wdat_last              : in  std_logic := 'U';
    bs06_wrep_valid             : out std_logic;
    bs06_wrep_ready             : in  std_logic := '1';
    bs06_wrep_ok                : out std_logic;

    -- Slave port 7.
    bs07_wreq_valid             : in  std_logic := '0';
    bs07_wreq_ready             : out std_logic;
    bs07_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs07_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs07_wreq_last              : in  std_logic := '0';
    bs07_wdat_valid             : in  std_logic := '0';
    bs07_wdat_ready             : out std_logic;
    bs07_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs07_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs07_wdat_last              : in  std_logic := 'U';
    bs07_wrep_valid             : out std_logic;
    bs07_wrep_ready             : in  std_logic := '1';
    bs07_wrep_ok                : out std_logic;

    -- Slave port 8.
    bs08_wreq_valid             : in  std_logic := '0';
    bs08_wreq_ready             : out std_logic;
    bs08_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs08_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs08_wreq_last              : in  std_logic := '0';
    bs08_wdat_valid             : in  std_logic := '0';
    bs08_wdat_ready             : out std_logic;
    bs08_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs08_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs08_wdat_last              : in  std_logic := 'U';
    bs08_wrep_valid             : out std_logic;
    bs08_wrep_ready             : in  std_logic := '1';
    bs08_wrep_ok                : out std_logic;

    -- Slave port 9.
    bs09_wreq_valid             : in  std_logic := '0';
    bs09_wreq_ready             : out std_logic;
    bs09_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs09_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs09_wreq_last              : in  std_logic := '0';
    bs09_wdat_valid             : in  std_logic := '0';
    bs09_wdat_ready             : out std_logic;
    bs09_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs09_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs09_wdat_last              : in  std_logic := 'U';
    bs09_wrep_valid             : out std_logic;
    bs09_wrep_ready             : in  std_logic := '1';
    bs09_wrep_ok                : out std_logic;

    -- Slave port 10.
    bs10_wreq_valid             : in  std_logic := '0';
    bs10_wreq_ready             : out std_logic;
    bs10_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs10_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs10_wreq_last              : in  std_logic := '0';
    bs10_wdat_valid             : in  std_logic := '0';
    bs10_wdat_ready             : out std_logic;
    bs10_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs10_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs10_wdat_last              : in  std_logic := 'U';
    bs10_wrep_valid             : out std_logic;
    bs10_wrep_ready             : in  std_logic := '1';
    bs10_wrep_ok                : out std_logic;

    -- Slave port 11.
    bs11_wreq_valid             : in  std_logic := '0';
    bs11_wreq_ready             : out std_logic;
    bs11_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs11_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs11_wreq_last              : in  std_logic := '0';
    bs11_wdat_valid             : in  std_logic := '0';
    bs11_wdat_ready             : out std_logic;
    bs11_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs11_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs11_wdat_last              : in  std_logic := 'U';
    bs11_wrep_valid             : out std_logic;
    bs11_wrep_ready             : in  std_logic := '1';
    bs11_wrep_ok                : out std_logic;

    -- Slave port 12.
    bs12_wreq_valid             : in  std_logic := '0';
    bs12_wreq_ready             : out std_logic;
    bs12_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs12_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs12_wreq_last              : in  std_logic := '0';
    bs12_wdat_valid             : in  std_logic := '0';
    bs12_wdat_ready             : out std_logic;
    bs12_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs12_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs12_wdat_last              : in  std_logic := 'U';
    bs12_wrep_valid             : out std_logic;
    bs12_wrep_ready             : in  std_logic := '1';
    bs12_wrep_ok                : out std_logic;

    -- Slave port 13.
    bs13_wreq_valid             : in  std_logic := '0';
    bs13_wreq_ready             : out std_logic;
    bs13_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs13_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs13_wreq_last              : in  std_logic := '0';
    bs13_wdat_valid             : in  std_logic := '0';
    bs13_wdat_ready             : out std_logic;
    bs13_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs13_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs13_wdat_last              : in  std_logic := 'U';
    bs13_wrep_valid             : out std_logic;
    bs13_wrep_ready             : in  std_logic := '1';
    bs13_wrep_ok                : out std_logic;

    -- Slave port 14.
    bs14_wreq_valid             : in  std_logic := '0';
    bs14_wreq_ready             : out std_logic;
    bs14_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs14_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs14_wreq_last              : in  std_logic := '0';
    bs14_wdat_valid             : in  std_logic := '0';
    bs14_wdat_ready             : out std_logic;
    bs14_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs14_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs14_wdat_last              : in  std_logic := 'U';
    bs14_wrep_valid             : out std_logic;
    bs14_wrep_ready             : in  std_logic := '1';
    bs14_wrep_ok                : out std_logic;

    -- Slave port 15.
    bs15_wreq_valid             : in  std_logic := '0';
    bs15_wreq_ready             : out std_logic;
    bs15_wreq_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bs15_wreq_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bs15_wreq_last              : in  std_logic := '0';
    bs15_wdat_valid             : in  std_logic := '0';
    bs15_wdat_ready             : out std_logic;
    bs15_wdat_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
    bs15_wdat_strobe            : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0) := (others => 'U');
    bs15_wdat_last              : in  std_logic := 'U';
    bs15_wrep_valid             : out std_logic;
    bs15_wrep_ready             : in  std_logic := '1';
    bs15_wrep_ok                : out std_logic
  );
end BusWriteArbiter;
  
architecture Behavioral of BusWriteArbiter is

  -- Serialized slave ports.
  signal bsv_wreq_valid          : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_wreq_ready          : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_wreq_addr           : std_logic_vector(NUM_SLAVE_PORTS*BUS_ADDR_WIDTH-1 downto 0);
  signal bsv_wreq_len            : std_logic_vector(NUM_SLAVE_PORTS*BUS_LEN_WIDTH-1 downto 0);
  signal bsv_wreq_last           : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_wdat_valid          : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_wdat_ready          : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_wdat_data           : std_logic_vector(NUM_SLAVE_PORTS*BUS_DATA_WIDTH-1 downto 0);
  signal bsv_wdat_strobe         : std_logic_vector(NUM_SLAVE_PORTS*BUS_DATA_WIDTH/8-1 downto 0);
  signal bsv_wdat_last           : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_wrep_valid          : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_wrep_ready          : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
  signal bsv_wrep_ok             : std_logic_vector(NUM_SLAVE_PORTS-1 downto 0);
begin

  -- Connect bus slave  0 to internal signal.                                                              
  bs00_connect_gen: if NUM_SLAVE_PORTS >  0 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid ( 0)                                               <= bs00_wreq_valid;        
    bs00_wreq_ready                                                   <= bsv_wreq_ready( 0);     
    bsv_wreq_addr  ( 1*BUS_ADDR_WIDTH-1 downto  0*BUS_ADDR_WIDTH)     <= bs00_wreq_addr;        
    bsv_wreq_len   ( 1*BUS_LEN_WIDTH-1 downto  0*BUS_LEN_WIDTH)       <= bs00_wreq_len;         
    bsv_wreq_last  ( 0)                                               <= bs00_wreq_last;
    bsv_wdat_valid ( 0)                                               <= bs00_wdat_valid;        
    bs00_wdat_ready                                                   <= bsv_wdat_ready( 0);     
    bsv_wdat_data  ( 1*BUS_DATA_WIDTH-1 downto  0*BUS_DATA_WIDTH)     <= bs00_wdat_data;        
    bsv_wdat_strobe( 1*BUS_DATA_WIDTH/8-1 downto  0*BUS_DATA_WIDTH/8) <= bs00_wdat_strobe;      
    bsv_wdat_last  ( 0)                                               <= bs00_wdat_last;         
    bs00_wrep_valid                                                   <= bsv_wrep_valid( 0);     
    bsv_wrep_ready ( 0)                                               <= bs00_wrep_ready;         
    bs00_wrep_ok                                                      <= bsv_wrep_ok( 0);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave  1 to internal signal.                                                              
  bs01_connect_gen: if NUM_SLAVE_PORTS >  1 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid ( 1)                                               <= bs01_wreq_valid;        
    bs01_wreq_ready                                                   <= bsv_wreq_ready( 1);     
    bsv_wreq_addr  ( 2*BUS_ADDR_WIDTH-1 downto  1*BUS_ADDR_WIDTH)     <= bs01_wreq_addr;        
    bsv_wreq_len   ( 2*BUS_LEN_WIDTH-1 downto  1*BUS_LEN_WIDTH)       <= bs01_wreq_len;         
    bsv_wreq_last  ( 1)                                               <= bs01_wreq_last;
    bsv_wdat_valid ( 1)                                               <= bs01_wdat_valid;        
    bs01_wdat_ready                                                   <= bsv_wdat_ready( 1);     
    bsv_wdat_data  ( 2*BUS_DATA_WIDTH-1 downto  1*BUS_DATA_WIDTH)     <= bs01_wdat_data;        
    bsv_wdat_strobe( 2*BUS_DATA_WIDTH/8-1 downto  1*BUS_DATA_WIDTH/8) <= bs01_wdat_strobe;      
    bsv_wdat_last  ( 1)                                               <= bs01_wdat_last;         
    bs01_wrep_valid                                                   <= bsv_wrep_valid( 1);     
    bsv_wrep_ready ( 1)                                               <= bs01_wrep_ready;         
    bs01_wrep_ok                                                      <= bsv_wrep_ok( 1);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave  2 to internal signal.                                                              
  bs02_connect_gen: if NUM_SLAVE_PORTS >  2 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid ( 2)                                               <= bs02_wreq_valid;        
    bs02_wreq_ready                                                   <= bsv_wreq_ready( 2);     
    bsv_wreq_addr  ( 3*BUS_ADDR_WIDTH-1 downto  2*BUS_ADDR_WIDTH)     <= bs02_wreq_addr;        
    bsv_wreq_len   ( 3*BUS_LEN_WIDTH-1 downto  2*BUS_LEN_WIDTH)       <= bs02_wreq_len;         
    bsv_wreq_last  ( 2)                                               <= bs02_wreq_last;
    bsv_wdat_valid ( 2)                                               <= bs02_wdat_valid;        
    bs02_wdat_ready                                                   <= bsv_wdat_ready( 2);     
    bsv_wdat_data  ( 3*BUS_DATA_WIDTH-1 downto  2*BUS_DATA_WIDTH)     <= bs02_wdat_data;        
    bsv_wdat_strobe( 3*BUS_DATA_WIDTH/8-1 downto  2*BUS_DATA_WIDTH/8) <= bs02_wdat_strobe;      
    bsv_wdat_last  ( 2)                                               <= bs02_wdat_last;         
    bs02_wrep_valid                                                   <= bsv_wrep_valid( 2);     
    bsv_wrep_ready ( 2)                                               <= bs02_wrep_ready;         
    bs02_wrep_ok                                                      <= bsv_wrep_ok( 2);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave  3 to internal signal.                                                              
  bs03_connect_gen: if NUM_SLAVE_PORTS >  3 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid ( 3)                                               <= bs03_wreq_valid;        
    bs03_wreq_ready                                                   <= bsv_wreq_ready( 3);     
    bsv_wreq_addr  ( 4*BUS_ADDR_WIDTH-1 downto  3*BUS_ADDR_WIDTH)     <= bs03_wreq_addr;        
    bsv_wreq_len   ( 4*BUS_LEN_WIDTH-1 downto  3*BUS_LEN_WIDTH)       <= bs03_wreq_len;         
    bsv_wreq_last  ( 3)                                               <= bs03_wreq_last;
    bsv_wdat_valid ( 3)                                               <= bs03_wdat_valid;        
    bs03_wdat_ready                                                   <= bsv_wdat_ready( 3);     
    bsv_wdat_data  ( 4*BUS_DATA_WIDTH-1 downto  3*BUS_DATA_WIDTH)     <= bs03_wdat_data;        
    bsv_wdat_strobe( 4*BUS_DATA_WIDTH/8-1 downto  3*BUS_DATA_WIDTH/8) <= bs03_wdat_strobe;      
    bsv_wdat_last  ( 3)                                               <= bs03_wdat_last;         
    bs03_wrep_valid                                                   <= bsv_wrep_valid( 3);     
    bsv_wrep_ready ( 3)                                               <= bs03_wrep_ready;         
    bs03_wrep_ok                                                      <= bsv_wrep_ok( 3);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave  4 to internal signal.                                                              
  bs04_connect_gen: if NUM_SLAVE_PORTS >  4 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid ( 4)                                               <= bs04_wreq_valid;        
    bs04_wreq_ready                                                   <= bsv_wreq_ready( 4);     
    bsv_wreq_addr  ( 5*BUS_ADDR_WIDTH-1 downto  4*BUS_ADDR_WIDTH)     <= bs04_wreq_addr;        
    bsv_wreq_len   ( 5*BUS_LEN_WIDTH-1 downto  4*BUS_LEN_WIDTH)       <= bs04_wreq_len;         
    bsv_wreq_last  ( 4)                                               <= bs04_wreq_last;
    bsv_wdat_valid ( 4)                                               <= bs04_wdat_valid;        
    bs04_wdat_ready                                                   <= bsv_wdat_ready( 4);     
    bsv_wdat_data  ( 5*BUS_DATA_WIDTH-1 downto  4*BUS_DATA_WIDTH)     <= bs04_wdat_data;        
    bsv_wdat_strobe( 5*BUS_DATA_WIDTH/8-1 downto  4*BUS_DATA_WIDTH/8) <= bs04_wdat_strobe;      
    bsv_wdat_last  ( 4)                                               <= bs04_wdat_last;         
    bs04_wrep_valid                                                   <= bsv_wrep_valid( 4);     
    bsv_wrep_ready ( 4)                                               <= bs04_wrep_ready;         
    bs04_wrep_ok                                                      <= bsv_wrep_ok( 4);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave  5 to internal signal.                                                              
  bs05_connect_gen: if NUM_SLAVE_PORTS >  5 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid ( 5)                                               <= bs05_wreq_valid;        
    bs05_wreq_ready                                                   <= bsv_wreq_ready( 5);     
    bsv_wreq_addr  ( 6*BUS_ADDR_WIDTH-1 downto  5*BUS_ADDR_WIDTH)     <= bs05_wreq_addr;        
    bsv_wreq_len   ( 6*BUS_LEN_WIDTH-1 downto  5*BUS_LEN_WIDTH)       <= bs05_wreq_len;         
    bsv_wreq_last  ( 5)                                               <= bs05_wreq_last;
    bsv_wdat_valid ( 5)                                               <= bs05_wdat_valid;        
    bs05_wdat_ready                                                   <= bsv_wdat_ready( 5);     
    bsv_wdat_data  ( 6*BUS_DATA_WIDTH-1 downto  5*BUS_DATA_WIDTH)     <= bs05_wdat_data;        
    bsv_wdat_strobe( 6*BUS_DATA_WIDTH/8-1 downto  5*BUS_DATA_WIDTH/8) <= bs05_wdat_strobe;      
    bsv_wdat_last  ( 5)                                               <= bs05_wdat_last;         
    bs05_wrep_valid                                                   <= bsv_wrep_valid( 5);     
    bsv_wrep_ready ( 5)                                               <= bs05_wrep_ready;         
    bs05_wrep_ok                                                      <= bsv_wrep_ok( 5);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave  6 to internal signal.                                                              
  bs06_connect_gen: if NUM_SLAVE_PORTS >  6 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid ( 6)                                               <= bs06_wreq_valid;        
    bs06_wreq_ready                                                   <= bsv_wreq_ready( 6);     
    bsv_wreq_addr  ( 7*BUS_ADDR_WIDTH-1 downto  6*BUS_ADDR_WIDTH)     <= bs06_wreq_addr;        
    bsv_wreq_len   ( 7*BUS_LEN_WIDTH-1 downto  6*BUS_LEN_WIDTH)       <= bs06_wreq_len;         
    bsv_wreq_last  ( 6)                                               <= bs06_wreq_last;
    bsv_wdat_valid ( 6)                                               <= bs06_wdat_valid;        
    bs06_wdat_ready                                                   <= bsv_wdat_ready( 6);     
    bsv_wdat_data  ( 7*BUS_DATA_WIDTH-1 downto  6*BUS_DATA_WIDTH)     <= bs06_wdat_data;        
    bsv_wdat_strobe( 7*BUS_DATA_WIDTH/8-1 downto  6*BUS_DATA_WIDTH/8) <= bs06_wdat_strobe;      
    bsv_wdat_last  ( 6)                                               <= bs06_wdat_last;         
    bs06_wrep_valid                                                   <= bsv_wrep_valid( 6);     
    bsv_wrep_ready ( 6)                                               <= bs06_wrep_ready;         
    bs06_wrep_ok                                                      <= bsv_wrep_ok( 6);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave  7 to internal signal.                                                              
  bs07_connect_gen: if NUM_SLAVE_PORTS >  7 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid ( 7)                                               <= bs07_wreq_valid;        
    bs07_wreq_ready                                                   <= bsv_wreq_ready( 7);     
    bsv_wreq_addr  ( 8*BUS_ADDR_WIDTH-1 downto  7*BUS_ADDR_WIDTH)     <= bs07_wreq_addr;        
    bsv_wreq_len   ( 8*BUS_LEN_WIDTH-1 downto  7*BUS_LEN_WIDTH)       <= bs07_wreq_len;         
    bsv_wreq_last  ( 7)                                               <= bs07_wreq_last;
    bsv_wdat_valid ( 7)                                               <= bs07_wdat_valid;        
    bs07_wdat_ready                                                   <= bsv_wdat_ready( 7);     
    bsv_wdat_data  ( 8*BUS_DATA_WIDTH-1 downto  7*BUS_DATA_WIDTH)     <= bs07_wdat_data;        
    bsv_wdat_strobe( 8*BUS_DATA_WIDTH/8-1 downto  7*BUS_DATA_WIDTH/8) <= bs07_wdat_strobe;      
    bsv_wdat_last  ( 7)                                               <= bs07_wdat_last;         
    bs07_wrep_valid                                                   <= bsv_wrep_valid( 7);     
    bsv_wrep_ready ( 7)                                               <= bs07_wrep_ready;         
    bs07_wrep_ok                                                      <= bsv_wrep_ok( 7);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave  8 to internal signal.                                                              
  bs08_connect_gen: if NUM_SLAVE_PORTS >  8 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid ( 8)                                               <= bs08_wreq_valid;        
    bs08_wreq_ready                                                   <= bsv_wreq_ready( 8);     
    bsv_wreq_addr  ( 9*BUS_ADDR_WIDTH-1 downto  8*BUS_ADDR_WIDTH)     <= bs08_wreq_addr;        
    bsv_wreq_len   ( 9*BUS_LEN_WIDTH-1 downto  8*BUS_LEN_WIDTH)       <= bs08_wreq_len;         
    bsv_wreq_last  ( 8)                                               <= bs08_wreq_last;
    bsv_wdat_valid ( 8)                                               <= bs08_wdat_valid;        
    bs08_wdat_ready                                                   <= bsv_wdat_ready( 8);     
    bsv_wdat_data  ( 9*BUS_DATA_WIDTH-1 downto  8*BUS_DATA_WIDTH)     <= bs08_wdat_data;        
    bsv_wdat_strobe( 9*BUS_DATA_WIDTH/8-1 downto  8*BUS_DATA_WIDTH/8) <= bs08_wdat_strobe;      
    bsv_wdat_last  ( 8)                                               <= bs08_wdat_last;         
    bs08_wrep_valid                                                   <= bsv_wrep_valid( 8);     
    bsv_wrep_ready ( 8)                                               <= bs08_wrep_ready;         
    bs08_wrep_ok                                                      <= bsv_wrep_ok( 8);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave  9 to internal signal.                                                              
  bs09_connect_gen: if NUM_SLAVE_PORTS >  9 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid ( 9)                                               <= bs09_wreq_valid;        
    bs09_wreq_ready                                                   <= bsv_wreq_ready( 9);     
    bsv_wreq_addr  (10*BUS_ADDR_WIDTH-1 downto  9*BUS_ADDR_WIDTH)     <= bs09_wreq_addr;        
    bsv_wreq_len   (10*BUS_LEN_WIDTH-1 downto  9*BUS_LEN_WIDTH)       <= bs09_wreq_len;         
    bsv_wreq_last  ( 9)                                               <= bs09_wreq_last;
    bsv_wdat_valid ( 9)                                               <= bs09_wdat_valid;        
    bs09_wdat_ready                                                   <= bsv_wdat_ready( 9);     
    bsv_wdat_data  (10*BUS_DATA_WIDTH-1 downto  9*BUS_DATA_WIDTH)     <= bs09_wdat_data;        
    bsv_wdat_strobe(10*BUS_DATA_WIDTH/8-1 downto  9*BUS_DATA_WIDTH/8) <= bs09_wdat_strobe;      
    bsv_wdat_last  ( 9)                                               <= bs09_wdat_last;         
    bs09_wrep_valid                                                   <= bsv_wrep_valid( 9);     
    bsv_wrep_ready ( 9)                                               <= bs09_wrep_ready;         
    bs09_wrep_ok                                                      <= bsv_wrep_ok( 9);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave 10 to internal signal.                                                              
  bs10_connect_gen: if NUM_SLAVE_PORTS > 10 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid (10)                                               <= bs10_wreq_valid;        
    bs10_wreq_ready                                                   <= bsv_wreq_ready(10);     
    bsv_wreq_addr  (11*BUS_ADDR_WIDTH-1 downto 10*BUS_ADDR_WIDTH)     <= bs10_wreq_addr;        
    bsv_wreq_len   (11*BUS_LEN_WIDTH-1 downto 10*BUS_LEN_WIDTH)       <= bs10_wreq_len;         
    bsv_wreq_last  (10)                                               <= bs10_wreq_last;
    bsv_wdat_valid (10)                                               <= bs10_wdat_valid;        
    bs10_wdat_ready                                                   <= bsv_wdat_ready(10);     
    bsv_wdat_data  (11*BUS_DATA_WIDTH-1 downto 10*BUS_DATA_WIDTH)     <= bs10_wdat_data;        
    bsv_wdat_strobe(11*BUS_DATA_WIDTH/8-1 downto 10*BUS_DATA_WIDTH/8) <= bs10_wdat_strobe;      
    bsv_wdat_last  (10)                                               <= bs10_wdat_last;         
    bs10_wrep_valid                                                   <= bsv_wrep_valid(10);     
    bsv_wrep_ready (10)                                               <= bs10_wrep_ready;         
    bs10_wrep_ok                                                      <= bsv_wrep_ok(10);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave 11 to internal signal.                                                              
  bs11_connect_gen: if NUM_SLAVE_PORTS > 11 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid (11)                                               <= bs11_wreq_valid;        
    bs11_wreq_ready                                                   <= bsv_wreq_ready(11);     
    bsv_wreq_addr  (12*BUS_ADDR_WIDTH-1 downto 11*BUS_ADDR_WIDTH)     <= bs11_wreq_addr;        
    bsv_wreq_len   (12*BUS_LEN_WIDTH-1 downto 11*BUS_LEN_WIDTH)       <= bs11_wreq_len;         
    bsv_wreq_last  (11)                                               <= bs11_wreq_last;
    bsv_wdat_valid (11)                                               <= bs11_wdat_valid;        
    bs11_wdat_ready                                                   <= bsv_wdat_ready(11);     
    bsv_wdat_data  (12*BUS_DATA_WIDTH-1 downto 11*BUS_DATA_WIDTH)     <= bs11_wdat_data;        
    bsv_wdat_strobe(12*BUS_DATA_WIDTH/8-1 downto 11*BUS_DATA_WIDTH/8) <= bs11_wdat_strobe;      
    bsv_wdat_last  (11)                                               <= bs11_wdat_last;         
    bs11_wrep_valid                                                   <= bsv_wrep_valid(11);     
    bsv_wrep_ready (11)                                               <= bs11_wrep_ready;         
    bs11_wrep_ok                                                      <= bsv_wrep_ok(11);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave 12 to internal signal.                                                              
  bs12_connect_gen: if NUM_SLAVE_PORTS > 12 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid (12)                                               <= bs12_wreq_valid;        
    bs12_wreq_ready                                                   <= bsv_wreq_ready(12);     
    bsv_wreq_addr  (13*BUS_ADDR_WIDTH-1 downto 12*BUS_ADDR_WIDTH)     <= bs12_wreq_addr;        
    bsv_wreq_len   (13*BUS_LEN_WIDTH-1 downto 12*BUS_LEN_WIDTH)       <= bs12_wreq_len;         
    bsv_wreq_last  (12)                                               <= bs12_wreq_last;
    bsv_wdat_valid (12)                                               <= bs12_wdat_valid;        
    bs12_wdat_ready                                                   <= bsv_wdat_ready(12);     
    bsv_wdat_data  (13*BUS_DATA_WIDTH-1 downto 12*BUS_DATA_WIDTH)     <= bs12_wdat_data;        
    bsv_wdat_strobe(13*BUS_DATA_WIDTH/8-1 downto 12*BUS_DATA_WIDTH/8) <= bs12_wdat_strobe;      
    bsv_wdat_last  (12)                                               <= bs12_wdat_last;         
    bs12_wrep_valid                                                   <= bsv_wrep_valid(12);     
    bsv_wrep_ready (12)                                               <= bs12_wrep_ready;         
    bs12_wrep_ok                                                      <= bsv_wrep_ok(12);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave 13 to internal signal.                                                              
  bs13_connect_gen: if NUM_SLAVE_PORTS > 13 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid (13)                                               <= bs13_wreq_valid;        
    bs13_wreq_ready                                                   <= bsv_wreq_ready(13);     
    bsv_wreq_addr  (14*BUS_ADDR_WIDTH-1 downto 13*BUS_ADDR_WIDTH)     <= bs13_wreq_addr;        
    bsv_wreq_len   (14*BUS_LEN_WIDTH-1 downto 13*BUS_LEN_WIDTH)       <= bs13_wreq_len;         
    bsv_wreq_last  (13)                                               <= bs13_wreq_last;
    bsv_wdat_valid (13)                                               <= bs13_wdat_valid;        
    bs13_wdat_ready                                                   <= bsv_wdat_ready(13);     
    bsv_wdat_data  (14*BUS_DATA_WIDTH-1 downto 13*BUS_DATA_WIDTH)     <= bs13_wdat_data;        
    bsv_wdat_strobe(14*BUS_DATA_WIDTH/8-1 downto 13*BUS_DATA_WIDTH/8) <= bs13_wdat_strobe;      
    bsv_wdat_last  (13)                                               <= bs13_wdat_last;         
    bs13_wrep_valid                                                   <= bsv_wrep_valid(13);     
    bsv_wrep_ready (13)                                               <= bs13_wrep_ready;         
    bs13_wrep_ok                                                      <= bsv_wrep_ok(13);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave 14 to internal signal.                                                              
  bs14_connect_gen: if NUM_SLAVE_PORTS > 14 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid (14)                                               <= bs14_wreq_valid;        
    bs14_wreq_ready                                                   <= bsv_wreq_ready(14);     
    bsv_wreq_addr  (15*BUS_ADDR_WIDTH-1 downto 14*BUS_ADDR_WIDTH)     <= bs14_wreq_addr;        
    bsv_wreq_len   (15*BUS_LEN_WIDTH-1 downto 14*BUS_LEN_WIDTH)       <= bs14_wreq_len;         
    bsv_wreq_last  (14)                                               <= bs14_wreq_last;
    bsv_wdat_valid (14)                                               <= bs14_wdat_valid;        
    bs14_wdat_ready                                                   <= bsv_wdat_ready(14);     
    bsv_wdat_data  (15*BUS_DATA_WIDTH-1 downto 14*BUS_DATA_WIDTH)     <= bs14_wdat_data;        
    bsv_wdat_strobe(15*BUS_DATA_WIDTH/8-1 downto 14*BUS_DATA_WIDTH/8) <= bs14_wdat_strobe;      
    bsv_wdat_last  (14)                                               <= bs14_wdat_last;         
    bs14_wrep_valid                                                   <= bsv_wrep_valid(14);     
    bsv_wrep_ready (14)                                               <= bs14_wrep_ready;         
    bs14_wrep_ok                                                      <= bsv_wrep_ok(14);     
  end generate;                                                                                             
                                                                                                            
  -- Connect bus slave 15 to internal signal.                                                              
  bs15_connect_gen: if NUM_SLAVE_PORTS > 15 generate                                                          
  begin                                                                                                     
    bsv_wreq_valid (15)                                               <= bs15_wreq_valid;        
    bs15_wreq_ready                                                   <= bsv_wreq_ready(15);     
    bsv_wreq_addr  (16*BUS_ADDR_WIDTH-1 downto 15*BUS_ADDR_WIDTH)     <= bs15_wreq_addr;        
    bsv_wreq_len   (16*BUS_LEN_WIDTH-1 downto 15*BUS_LEN_WIDTH)       <= bs15_wreq_len;         
    bsv_wreq_last  (15)                                               <= bs15_wreq_last;
    bsv_wdat_valid (15)                                               <= bs15_wdat_valid;        
    bs15_wdat_ready                                                   <= bsv_wdat_ready(15);     
    bsv_wdat_data  (16*BUS_DATA_WIDTH-1 downto 15*BUS_DATA_WIDTH)     <= bs15_wdat_data;        
    bsv_wdat_strobe(16*BUS_DATA_WIDTH/8-1 downto 15*BUS_DATA_WIDTH/8) <= bs15_wdat_strobe;      
    bsv_wdat_last  (15)                                               <= bs15_wdat_last;         
    bs15_wrep_valid                                                   <= bsv_wrep_valid(15);     
    bsv_wrep_ready (15)                                               <= bs15_wrep_ready;         
    bs15_wrep_ok                                                      <= bsv_wrep_ok(15);     
  end generate;

  -- Instantiate the vectorized version
  arb_inst: BusWriteArbiterVec
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
      SLV_DAT_SLICES            => SLV_DAT_SLICES,
      MST_DAT_SLICE             => MST_DAT_SLICE,
      MST_REP_SLICE             => MST_REP_SLICE,
      SLV_REP_SLICES            => SLV_REP_SLICES
    )
    port map (
      bcd_clk                   => bcd_clk,
      bcd_reset                 => bcd_reset,

      mst_wreq_valid            => mst_wreq_valid,
      mst_wreq_ready            => mst_wreq_ready,
      mst_wreq_addr             => mst_wreq_addr,
      mst_wreq_len              => mst_wreq_len,
      mst_wreq_last             => mst_wreq_last,
      mst_wdat_valid            => mst_wdat_valid,
      mst_wdat_ready            => mst_wdat_ready,
      mst_wdat_data             => mst_wdat_data,
      mst_wdat_strobe           => mst_wdat_strobe,
      mst_wdat_last             => mst_wdat_last,
      mst_wrep_valid            => mst_wrep_valid,
      mst_wrep_ready            => mst_wrep_ready,
      mst_wrep_ok               => mst_wrep_ok,

      bsv_wreq_valid            => bsv_wreq_valid,
      bsv_wreq_ready            => bsv_wreq_ready,
      bsv_wreq_addr             => bsv_wreq_addr,
      bsv_wreq_len              => bsv_wreq_len,
      bsv_wreq_last             => bsv_wreq_last,
      bsv_wdat_valid            => bsv_wdat_valid,
      bsv_wdat_ready            => bsv_wdat_ready,
      bsv_wdat_data             => bsv_wdat_data,
      bsv_wdat_strobe           => bsv_wdat_strobe,
      bsv_wdat_last             => bsv_wdat_last,
      bsv_wrep_valid            => bsv_wrep_valid,
      bsv_wrep_ready            => bsv_wrep_ready,
      bsv_wrep_ok               => bsv_wrep_ok
    );

end Behavioral;

