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
-- BufferReaders.

entity BusArbiter is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Number of bus masters to arbitrate between.
    NUM_MASTERS                 : natural := 2;

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
    -- bus and control logic side of the BufferReader.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Slave port.
    slv_req_valid               : out std_logic;
    slv_req_ready               : in  std_logic;
    slv_req_addr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    slv_req_len                 : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    slv_resp_valid              : in  std_logic;
    slv_resp_ready              : out std_logic;
    slv_resp_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    slv_resp_last               : in  std_logic;

    -- Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn

    -- Master port 0.
    bm0_req_valid               : in  std_logic := '0';
    bm0_req_ready               : out std_logic;
    bm0_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm0_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm0_resp_valid              : out std_logic;
    bm0_resp_ready              : in  std_logic := '1';
    bm0_resp_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm0_resp_last               : out std_logic;

    -- Master port 1.
    bm1_req_valid               : in  std_logic := '0';
    bm1_req_ready               : out std_logic;
    bm1_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm1_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm1_resp_valid              : out std_logic;
    bm1_resp_ready              : in  std_logic := '1';
    bm1_resp_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm1_resp_last               : out std_logic;

    -- Master port 2.
    bm2_req_valid               : in  std_logic := '0';
    bm2_req_ready               : out std_logic;
    bm2_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm2_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm2_resp_valid              : out std_logic;
    bm2_resp_ready              : in  std_logic := '1';
    bm2_resp_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm2_resp_last               : out std_logic;

    -- Master port 3.
    bm3_req_valid               : in  std_logic := '0';
    bm3_req_ready               : out std_logic;
    bm3_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm3_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm3_resp_valid              : out std_logic;
    bm3_resp_ready              : in  std_logic := '1';
    bm3_resp_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm3_resp_last               : out std_logic;

    -- Master port 4.
    bm4_req_valid               : in  std_logic := '0';
    bm4_req_ready               : out std_logic;
    bm4_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm4_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm4_resp_valid              : out std_logic;
    bm4_resp_ready              : in  std_logic := '1';
    bm4_resp_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm4_resp_last               : out std_logic;

    -- Master port 5.
    bm5_req_valid               : in  std_logic := '0';
    bm5_req_ready               : out std_logic;
    bm5_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm5_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm5_resp_valid              : out std_logic;
    bm5_resp_ready              : in  std_logic := '1';
    bm5_resp_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm5_resp_last               : out std_logic;

    -- Master port 6.
    bm6_req_valid               : in  std_logic := '0';
    bm6_req_ready               : out std_logic;
    bm6_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm6_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm6_resp_valid              : out std_logic;
    bm6_resp_ready              : in  std_logic := '1';
    bm6_resp_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm6_resp_last               : out std_logic;

    -- Master port 7.
    bm7_req_valid               : in  std_logic := '0';
    bm7_req_ready               : out std_logic;
    bm7_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm7_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm7_resp_valid              : out std_logic;
    bm7_resp_ready              : in  std_logic := '1';
    bm7_resp_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm7_resp_last               : out std_logic;

    -- Master port 8.
    bm8_req_valid               : in  std_logic := '0';
    bm8_req_ready               : out std_logic;
    bm8_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm8_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm8_resp_valid              : out std_logic;
    bm8_resp_ready              : in  std_logic := '1';
    bm8_resp_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm8_resp_last               : out std_logic;

    -- Master port 9.
    bm9_req_valid               : in  std_logic := '0';
    bm9_req_ready               : out std_logic;
    bm9_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm9_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm9_resp_valid              : out std_logic;
    bm9_resp_ready              : in  std_logic := '1';
    bm9_resp_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm9_resp_last               : out std_logic;

    -- Master port 10.
    bm10_req_valid              : in  std_logic := '0';
    bm10_req_ready              : out std_logic;
    bm10_req_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm10_req_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm10_resp_valid             : out std_logic;
    bm10_resp_ready             : in  std_logic := '1';
    bm10_resp_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm10_resp_last              : out std_logic;

    -- Master port 11.
    bm11_req_valid              : in  std_logic := '0';
    bm11_req_ready              : out std_logic;
    bm11_req_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm11_req_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm11_resp_valid             : out std_logic;
    bm11_resp_ready             : in  std_logic := '1';
    bm11_resp_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm11_resp_last              : out std_logic;

    -- Master port 12.
    bm12_req_valid              : in  std_logic := '0';
    bm12_req_ready              : out std_logic;
    bm12_req_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm12_req_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm12_resp_valid             : out std_logic;
    bm12_resp_ready             : in  std_logic := '1';
    bm12_resp_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm12_resp_last              : out std_logic;

    -- Master port 13.
    bm13_req_valid              : in  std_logic := '0';
    bm13_req_ready              : out std_logic;
    bm13_req_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm13_req_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm13_resp_valid             : out std_logic;
    bm13_resp_ready             : in  std_logic := '1';
    bm13_resp_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm13_resp_last              : out std_logic;

    -- Master port 14.
    bm14_req_valid              : in  std_logic := '0';
    bm14_req_ready              : out std_logic;
    bm14_req_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm14_req_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm14_resp_valid             : out std_logic;
    bm14_resp_ready             : in  std_logic := '1';
    bm14_resp_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm14_resp_last              : out std_logic;

    -- Master port 15.
    bm15_req_valid              : in  std_logic := '0';
    bm15_req_ready              : out std_logic;
    bm15_req_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
    bm15_req_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
    bm15_resp_valid             : out std_logic;
    bm15_resp_ready             : in  std_logic := '1';
    bm15_resp_data              : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bm15_resp_last              : out std_logic

  );
end BusArbiter;

architecture Behavioral of BusArbiter is

  -- Serialized master busses.
  signal bmv_req_valid          : std_logic_vector(NUM_MASTERS-1 downto 0);
  signal bmv_req_ready          : std_logic_vector(NUM_MASTERS-1 downto 0);
  signal bmv_req_addr           : std_logic_vector(NUM_MASTERS*BUS_ADDR_WIDTH-1 downto 0);
  signal bmv_req_len            : std_logic_vector(NUM_MASTERS*BUS_LEN_WIDTH-1 downto 0);
  signal bmv_resp_valid         : std_logic_vector(NUM_MASTERS-1 downto 0);
  signal bmv_resp_ready         : std_logic_vector(NUM_MASTERS-1 downto 0);
  signal bmv_resp_data          : std_logic_vector(NUM_MASTERS*BUS_DATA_WIDTH-1 downto 0);
  signal bmv_resp_last          : std_logic_vector(NUM_MASTERS-1 downto 0);

begin

  -- Connect bus master 0 to internal signal.
  bm0_connect_gen: if NUM_MASTERS > 0 generate
  begin
    bmv_req_valid(0)    <= bm0_req_valid;
    bm0_req_ready       <= bmv_req_ready(0);
    bmv_req_addr(1*BUS_ADDR_WIDTH-1 downto 0*BUS_ADDR_WIDTH)
                        <= bm0_req_addr;
    bmv_req_len(1*BUS_LEN_WIDTH-1 downto 0*BUS_LEN_WIDTH)
                        <= bm0_req_len;
    bm0_resp_valid      <= bmv_resp_valid(0);
    bmv_resp_ready(0)   <= bm0_resp_ready;
    bm0_resp_data       <= bmv_resp_data(1*BUS_DATA_WIDTH-1 downto 0*BUS_DATA_WIDTH);
    bm0_resp_last       <= bmv_resp_last(0);
  end generate;

  -- Connect bus master 1 to internal signal.
  bm1_connect_gen: if NUM_MASTERS > 1 generate
  begin
    bmv_req_valid(1)    <= bm1_req_valid;
    bm1_req_ready       <= bmv_req_ready(1);
    bmv_req_addr(2*BUS_ADDR_WIDTH-1 downto 1*BUS_ADDR_WIDTH)
                        <= bm1_req_addr;
    bmv_req_len(2*BUS_LEN_WIDTH-1 downto 1*BUS_LEN_WIDTH)
                        <= bm1_req_len;
    bm1_resp_valid      <= bmv_resp_valid(1);
    bmv_resp_ready(1)   <= bm1_resp_ready;
    bm1_resp_data       <= bmv_resp_data(2*BUS_DATA_WIDTH-1 downto 1*BUS_DATA_WIDTH);
    bm1_resp_last       <= bmv_resp_last(1);
  end generate;

  -- Connect bus master 2 to internal signal.
  bm2_connect_gen: if NUM_MASTERS > 2 generate
  begin
    bmv_req_valid(2)    <= bm2_req_valid;
    bm2_req_ready       <= bmv_req_ready(2);
    bmv_req_addr(3*BUS_ADDR_WIDTH-1 downto 2*BUS_ADDR_WIDTH)
                        <= bm2_req_addr;
    bmv_req_len(3*BUS_LEN_WIDTH-1 downto 2*BUS_LEN_WIDTH)
                        <= bm2_req_len;
    bm2_resp_valid      <= bmv_resp_valid(2);
    bmv_resp_ready(2)   <= bm2_resp_ready;
    bm2_resp_data       <= bmv_resp_data(3*BUS_DATA_WIDTH-1 downto 2*BUS_DATA_WIDTH);
    bm2_resp_last       <= bmv_resp_last(2);
  end generate;

  -- Connect bus master 3 to internal signal.
  bm3_connect_gen: if NUM_MASTERS > 3 generate
  begin
    bmv_req_valid(3)    <= bm3_req_valid;
    bm3_req_ready       <= bmv_req_ready(3);
    bmv_req_addr(4*BUS_ADDR_WIDTH-1 downto 3*BUS_ADDR_WIDTH)
                        <= bm3_req_addr;
    bmv_req_len(4*BUS_LEN_WIDTH-1 downto 3*BUS_LEN_WIDTH)
                        <= bm3_req_len;
    bm3_resp_valid      <= bmv_resp_valid(3);
    bmv_resp_ready(3)   <= bm3_resp_ready;
    bm3_resp_data       <= bmv_resp_data(4*BUS_DATA_WIDTH-1 downto 3*BUS_DATA_WIDTH);
    bm3_resp_last       <= bmv_resp_last(3);
  end generate;

  -- Connect bus master 4 to internal signal.
  bm4_connect_gen: if NUM_MASTERS > 4 generate
  begin
    bmv_req_valid(4)    <= bm4_req_valid;
    bm4_req_ready       <= bmv_req_ready(4);
    bmv_req_addr(5*BUS_ADDR_WIDTH-1 downto 4*BUS_ADDR_WIDTH)
                        <= bm4_req_addr;
    bmv_req_len(5*BUS_LEN_WIDTH-1 downto 4*BUS_LEN_WIDTH)
                        <= bm4_req_len;
    bm4_resp_valid      <= bmv_resp_valid(4);
    bmv_resp_ready(4)   <= bm4_resp_ready;
    bm4_resp_data       <= bmv_resp_data(5*BUS_DATA_WIDTH-1 downto 4*BUS_DATA_WIDTH);
    bm4_resp_last       <= bmv_resp_last(4);
  end generate;

  -- Connect bus master 5 to internal signal.
  bm5_connect_gen: if NUM_MASTERS > 5 generate
  begin
    bmv_req_valid(5)    <= bm5_req_valid;
    bm5_req_ready       <= bmv_req_ready(5);
    bmv_req_addr(6*BUS_ADDR_WIDTH-1 downto 5*BUS_ADDR_WIDTH)
                        <= bm5_req_addr;
    bmv_req_len(6*BUS_LEN_WIDTH-1 downto 5*BUS_LEN_WIDTH)
                        <= bm5_req_len;
    bm5_resp_valid      <= bmv_resp_valid(5);
    bmv_resp_ready(5)   <= bm5_resp_ready;
    bm5_resp_data       <= bmv_resp_data(6*BUS_DATA_WIDTH-1 downto 5*BUS_DATA_WIDTH);
    bm5_resp_last       <= bmv_resp_last(5);
  end generate;

  -- Connect bus master 6 to internal signal.
  bm6_connect_gen: if NUM_MASTERS > 6 generate
  begin
    bmv_req_valid(6)    <= bm6_req_valid;
    bm6_req_ready       <= bmv_req_ready(6);
    bmv_req_addr(7*BUS_ADDR_WIDTH-1 downto 6*BUS_ADDR_WIDTH)
                        <= bm6_req_addr;
    bmv_req_len(7*BUS_LEN_WIDTH-1 downto 6*BUS_LEN_WIDTH)
                        <= bm6_req_len;
    bm6_resp_valid      <= bmv_resp_valid(6);
    bmv_resp_ready(6)   <= bm6_resp_ready;
    bm6_resp_data       <= bmv_resp_data(7*BUS_DATA_WIDTH-1 downto 6*BUS_DATA_WIDTH);
    bm6_resp_last       <= bmv_resp_last(6);
  end generate;

  -- Connect bus master 7 to internal signal.
  bm7_connect_gen: if NUM_MASTERS > 7 generate
  begin
    bmv_req_valid(7)    <= bm7_req_valid;
    bm7_req_ready       <= bmv_req_ready(7);
    bmv_req_addr(8*BUS_ADDR_WIDTH-1 downto 7*BUS_ADDR_WIDTH)
                        <= bm7_req_addr;
    bmv_req_len(8*BUS_LEN_WIDTH-1 downto 7*BUS_LEN_WIDTH)
                        <= bm7_req_len;
    bm7_resp_valid      <= bmv_resp_valid(7);
    bmv_resp_ready(7)   <= bm7_resp_ready;
    bm7_resp_data       <= bmv_resp_data(8*BUS_DATA_WIDTH-1 downto 7*BUS_DATA_WIDTH);
    bm7_resp_last       <= bmv_resp_last(7);
  end generate;

  -- Connect bus master 8 to internal signal.
  bm8_connect_gen: if NUM_MASTERS > 8 generate
  begin
    bmv_req_valid(8)    <= bm8_req_valid;
    bm8_req_ready       <= bmv_req_ready(8);
    bmv_req_addr(9*BUS_ADDR_WIDTH-1 downto 8*BUS_ADDR_WIDTH)
                        <= bm8_req_addr;
    bmv_req_len(9*BUS_LEN_WIDTH-1 downto 8*BUS_LEN_WIDTH)
                        <= bm8_req_len;
    bm8_resp_valid      <= bmv_resp_valid(8);
    bmv_resp_ready(8)   <= bm8_resp_ready;
    bm8_resp_data       <= bmv_resp_data(9*BUS_DATA_WIDTH-1 downto 8*BUS_DATA_WIDTH);
    bm8_resp_last       <= bmv_resp_last(8);
  end generate;

  -- Connect bus master 9 to internal signal.
  bm9_connect_gen: if NUM_MASTERS > 9 generate
  begin
    bmv_req_valid(9)    <= bm9_req_valid;
    bm9_req_ready       <= bmv_req_ready(9);
    bmv_req_addr(10*BUS_ADDR_WIDTH-1 downto 9*BUS_ADDR_WIDTH)
                        <= bm9_req_addr;
    bmv_req_len(10*BUS_LEN_WIDTH-1 downto 9*BUS_LEN_WIDTH)
                        <= bm9_req_len;
    bm9_resp_valid      <= bmv_resp_valid(9);
    bmv_resp_ready(9)   <= bm9_resp_ready;
    bm9_resp_data       <= bmv_resp_data(10*BUS_DATA_WIDTH-1 downto 9*BUS_DATA_WIDTH);
    bm9_resp_last       <= bmv_resp_last(9);
  end generate;

  -- Connect bus master 10 to internal signal.
  bm10_connect_gen: if NUM_MASTERS > 10 generate
  begin
    bmv_req_valid(10)   <= bm10_req_valid;
    bm10_req_ready      <= bmv_req_ready(10);
    bmv_req_addr(11*BUS_ADDR_WIDTH-1 downto 10*BUS_ADDR_WIDTH)
                        <= bm10_req_addr;
    bmv_req_len(11*BUS_LEN_WIDTH-1 downto 10*BUS_LEN_WIDTH)
                        <= bm10_req_len;
    bm10_resp_valid     <= bmv_resp_valid(10);
    bmv_resp_ready(10)  <= bm10_resp_ready;
    bm10_resp_data      <= bmv_resp_data(11*BUS_DATA_WIDTH-1 downto 10*BUS_DATA_WIDTH);
    bm10_resp_last      <= bmv_resp_last(10);
  end generate;

  -- Connect bus master 11 to internal signal.
  bm11_connect_gen: if NUM_MASTERS > 11 generate
  begin
    bmv_req_valid(11)   <= bm11_req_valid;
    bm11_req_ready      <= bmv_req_ready(11);
    bmv_req_addr(12*BUS_ADDR_WIDTH-1 downto 11*BUS_ADDR_WIDTH)
                        <= bm11_req_addr;
    bmv_req_len(12*BUS_LEN_WIDTH-1 downto 11*BUS_LEN_WIDTH)
                        <= bm11_req_len;
    bm11_resp_valid     <= bmv_resp_valid(11);
    bmv_resp_ready(11)  <= bm11_resp_ready;
    bm11_resp_data      <= bmv_resp_data(12*BUS_DATA_WIDTH-1 downto 11*BUS_DATA_WIDTH);
    bm11_resp_last      <= bmv_resp_last(11);
  end generate;

  -- Connect bus master 12 to internal signal.
  bm12_connect_gen: if NUM_MASTERS > 12 generate
  begin
    bmv_req_valid(12)   <= bm12_req_valid;
    bm12_req_ready      <= bmv_req_ready(12);
    bmv_req_addr(13*BUS_ADDR_WIDTH-1 downto 12*BUS_ADDR_WIDTH)
                        <= bm12_req_addr;
    bmv_req_len(13*BUS_LEN_WIDTH-1 downto 12*BUS_LEN_WIDTH)
                        <= bm12_req_len;
    bm12_resp_valid     <= bmv_resp_valid(12);
    bmv_resp_ready(12)  <= bm12_resp_ready;
    bm12_resp_data      <= bmv_resp_data(13*BUS_DATA_WIDTH-1 downto 12*BUS_DATA_WIDTH);
    bm12_resp_last      <= bmv_resp_last(12);
  end generate;

  -- Connect bus master 13 to internal signal.
  bm13_connect_gen: if NUM_MASTERS > 13 generate
  begin
    bmv_req_valid(13)   <= bm13_req_valid;
    bm13_req_ready      <= bmv_req_ready(13);
    bmv_req_addr(14*BUS_ADDR_WIDTH-1 downto 13*BUS_ADDR_WIDTH)
                        <= bm13_req_addr;
    bmv_req_len(14*BUS_LEN_WIDTH-1 downto 13*BUS_LEN_WIDTH)
                        <= bm13_req_len;
    bm13_resp_valid     <= bmv_resp_valid(13);
    bmv_resp_ready(13)  <= bm13_resp_ready;
    bm13_resp_data      <= bmv_resp_data(14*BUS_DATA_WIDTH-1 downto 13*BUS_DATA_WIDTH);
    bm13_resp_last      <= bmv_resp_last(13);
  end generate;

  -- Connect bus master 14 to internal signal.
  bm14_connect_gen: if NUM_MASTERS > 14 generate
  begin
    bmv_req_valid(14)   <= bm14_req_valid;
    bm14_req_ready      <= bmv_req_ready(14);
    bmv_req_addr(15*BUS_ADDR_WIDTH-1 downto 14*BUS_ADDR_WIDTH)
                        <= bm14_req_addr;
    bmv_req_len(15*BUS_LEN_WIDTH-1 downto 14*BUS_LEN_WIDTH)
                        <= bm14_req_len;
    bm14_resp_valid     <= bmv_resp_valid(14);
    bmv_resp_ready(14)  <= bm14_resp_ready;
    bm14_resp_data      <= bmv_resp_data(15*BUS_DATA_WIDTH-1 downto 14*BUS_DATA_WIDTH);
    bm14_resp_last      <= bmv_resp_last(14);
  end generate;

  -- Connect bus master 15 to internal signal.
  bm15_connect_gen: if NUM_MASTERS > 15 generate
  begin
    bmv_req_valid(15)   <= bm15_req_valid;
    bm15_req_ready      <= bmv_req_ready(15);
    bmv_req_addr(16*BUS_ADDR_WIDTH-1 downto 15*BUS_ADDR_WIDTH)
                        <= bm15_req_addr;
    bmv_req_len(16*BUS_LEN_WIDTH-1 downto 15*BUS_LEN_WIDTH)
                        <= bm15_req_len;
    bm15_resp_valid     <= bmv_resp_valid(15);
    bmv_resp_ready(15)  <= bm15_resp_ready;
    bm15_resp_data      <= bmv_resp_data(16*BUS_DATA_WIDTH-1 downto 15*BUS_DATA_WIDTH);
    bm15_resp_last      <= bmv_resp_last(15);
  end generate;

  arb_inst: BusArbiterVec
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      NUM_MASTERS               => NUM_MASTERS,
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

      slv_req_valid             => slv_req_valid,
      slv_req_ready             => slv_req_ready,
      slv_req_addr              => slv_req_addr,
      slv_req_len               => slv_req_len,
      slv_resp_valid            => slv_resp_valid,
      slv_resp_ready            => slv_resp_ready,
      slv_resp_data             => slv_resp_data,
      slv_resp_last             => slv_resp_last,

      bmv_req_valid             => bmv_req_valid,
      bmv_req_ready             => bmv_req_ready,
      bmv_req_addr              => bmv_req_addr,
      bmv_req_len               => bmv_req_len,
      bmv_resp_valid            => bmv_resp_valid,
      bmv_resp_ready            => bmv_resp_ready,
      bmv_resp_data             => bmv_resp_data,
      bmv_resp_last             => bmv_resp_last
    );

end Behavioral;

