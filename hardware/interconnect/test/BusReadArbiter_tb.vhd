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

entity BusReadArbiter_tb is
end BusReadArbiter_tb;

architecture Behavioral of BusReadArbiter_tb is

  constant BUS_ADDR_WIDTH       : natural := 32;
  constant BUS_LEN_WIDTH        : natural := 8;
  constant BUS_DATA_WIDTH       : natural := 32;

  signal clk                    : std_logic := '1';
  signal reset                  : std_logic;

  -- Master A to arbiter.
  signal ma2b_rreq_valid        : std_logic;
  signal ma2b_rreq_ready        : std_logic;
  signal ma2b_rreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal ma2b_rreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal ma2b_rdat_valid        : std_logic;
  signal ma2b_rdat_ready        : std_logic;
  signal ma2b_rdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ma2b_rdat_last         : std_logic;

  signal ma2b_rdat_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ma2b_rdat_last_m       : std_logic;

  signal ba2a_rreq_valid        : std_logic;
  signal ba2a_rreq_ready        : std_logic;
  signal ba2a_rreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal ba2a_rreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal ba2a_rdat_valid        : std_logic;
  signal ba2a_rdat_ready        : std_logic;
  signal ba2a_rdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ba2a_rdat_last         : std_logic;

  -- Master B to arbiter.
  signal mb2b_rreq_valid        : std_logic;
  signal mb2b_rreq_ready        : std_logic;
  signal mb2b_rreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal mb2b_rreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal mb2b_rdat_valid        : std_logic;
  signal mb2b_rdat_ready        : std_logic;
  signal mb2b_rdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mb2b_rdat_last         : std_logic;

  signal mb2b_rdat_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mb2b_rdat_last_m       : std_logic;

  signal bb2a_rreq_valid        : std_logic;
  signal bb2a_rreq_ready        : std_logic;
  signal bb2a_rreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bb2a_rreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bb2a_rdat_valid        : std_logic;
  signal bb2a_rdat_ready        : std_logic;
  signal bb2a_rdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bb2a_rdat_last         : std_logic;

  -- Master C to arbiter.
  signal mc2b_rreq_valid        : std_logic;
  signal mc2b_rreq_ready        : std_logic;
  signal mc2b_rreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal mc2b_rreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal mc2b_rdat_valid        : std_logic;
  signal mc2b_rdat_ready        : std_logic;
  signal mc2b_rdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mc2b_rdat_last         : std_logic;

  signal mc2b_rdat_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mc2b_rdat_last_m       : std_logic;

  signal bc2a_rreq_valid        : std_logic;
  signal bc2a_rreq_ready        : std_logic;
  signal bc2a_rreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bc2a_rreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bc2a_rdat_valid        : std_logic;
  signal bc2a_rdat_ready        : std_logic;
  signal bc2a_rdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bc2a_rdat_last         : std_logic;

  -- Arbiter to slave.
  signal a2s_rreq_valid         : std_logic;
  signal a2s_rreq_ready         : std_logic;
  signal a2s_rreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal a2s_rreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal a2s_rdat_valid         : std_logic;
  signal a2s_rdat_ready         : std_logic;
  signal a2s_rdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal a2s_rdat_last          : std_logic;

begin

  ma2b_rdat_data_m <= ma2b_rdat_data when ma2b_rdat_valid = '1' and ma2b_rdat_ready = '1' else (others => 'Z');
  ma2b_rdat_last_m <= ma2b_rdat_last when ma2b_rdat_valid = '1' and ma2b_rdat_ready = '1' else 'Z';

  mb2b_rdat_data_m <= mb2b_rdat_data when mb2b_rdat_valid = '1' and mb2b_rdat_ready = '1' else (others => 'Z');
  mb2b_rdat_last_m <= mb2b_rdat_last when mb2b_rdat_valid = '1' and mb2b_rdat_ready = '1' else 'Z';

  mc2b_rdat_data_m <= mc2b_rdat_data when mc2b_rdat_valid = '1' and mc2b_rdat_ready = '1' else (others => 'Z');
  mc2b_rdat_last_m <= mc2b_rdat_last when mc2b_rdat_valid = '1' and mc2b_rdat_ready = '1' else 'Z';

  clk_proc: process is
  begin
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;

  reset_proc: process is
  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait for 100 us;
    wait until rising_edge(clk);
  end process;

  mst_a_inst: BusReadMasterMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      rreq_valid                => ma2b_rreq_valid,
      rreq_ready                => ma2b_rreq_ready,
      rreq_addr                 => ma2b_rreq_addr,
      rreq_len                  => ma2b_rreq_len,
      rdat_valid                => ma2b_rdat_valid,
      rdat_ready                => ma2b_rdat_ready,
      rdat_data                 => ma2b_rdat_data,
      rdat_last                 => ma2b_rdat_last
    );

  mst_a_buffer_inst: BusReadBuffer
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      FIFO_DEPTH                => 16,
      RAM_CONFIG                => "",
      SLV_REQ_SLICE             => false,
      MST_REQ_SLICE             => false,
      MST_DAT_SLICE             => false,
      SLV_DAT_SLICE             => false
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      slv_rreq_valid            => ma2b_rreq_valid,
      slv_rreq_ready            => ma2b_rreq_ready,
      slv_rreq_addr             => ma2b_rreq_addr,
      slv_rreq_len              => ma2b_rreq_len,
      slv_rdat_valid            => ma2b_rdat_valid,
      slv_rdat_ready            => ma2b_rdat_ready,
      slv_rdat_data             => ma2b_rdat_data,
      slv_rdat_last             => ma2b_rdat_last,

      mst_rreq_valid            => ba2a_rreq_valid,
      mst_rreq_ready            => ba2a_rreq_ready,
      mst_rreq_addr             => ba2a_rreq_addr,
      mst_rreq_len              => ba2a_rreq_len,
      mst_rdat_valid            => ba2a_rdat_valid,
      mst_rdat_ready            => ba2a_rdat_ready,
      mst_rdat_data             => ba2a_rdat_data,
      mst_rdat_last             => ba2a_rdat_last
    );

  mst_b_inst: BusReadMasterMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      rreq_valid                => mb2b_rreq_valid,
      rreq_ready                => mb2b_rreq_ready,
      rreq_addr                 => mb2b_rreq_addr,
      rreq_len                  => mb2b_rreq_len,
      rdat_valid                => mb2b_rdat_valid,
      rdat_ready                => mb2b_rdat_ready,
      rdat_data                 => mb2b_rdat_data,
      rdat_last                 => mb2b_rdat_last
    );

  mst_b_buffer_inst: BusReadBuffer
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      FIFO_DEPTH                => 16,
      RAM_CONFIG                => "",
      SLV_REQ_SLICE             => false,
      MST_REQ_SLICE             => false,
      MST_DAT_SLICE             => false,
      SLV_DAT_SLICE             => false
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      slv_rreq_valid            => mb2b_rreq_valid,
      slv_rreq_ready            => mb2b_rreq_ready,
      slv_rreq_addr             => mb2b_rreq_addr,
      slv_rreq_len              => mb2b_rreq_len,
      slv_rdat_valid            => mb2b_rdat_valid,
      slv_rdat_ready            => mb2b_rdat_ready,
      slv_rdat_data             => mb2b_rdat_data,
      slv_rdat_last             => mb2b_rdat_last,

      mst_rreq_valid            => bb2a_rreq_valid,
      mst_rreq_ready            => bb2a_rreq_ready,
      mst_rreq_addr             => bb2a_rreq_addr,
      mst_rreq_len              => bb2a_rreq_len,
      mst_rdat_valid            => bb2a_rdat_valid,
      mst_rdat_ready            => bb2a_rdat_ready,
      mst_rdat_data             => bb2a_rdat_data,
      mst_rdat_last             => bb2a_rdat_last
    );

  mst_c_inst: BusReadMasterMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 3
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      rreq_valid                => mc2b_rreq_valid,
      rreq_ready                => mc2b_rreq_ready,
      rreq_addr                 => mc2b_rreq_addr,
      rreq_len                  => mc2b_rreq_len,
      rdat_valid                => mc2b_rdat_valid,
      rdat_ready                => mc2b_rdat_ready,
      rdat_data                 => mc2b_rdat_data,
      rdat_last                 => mc2b_rdat_last
    );

  mst_c_buffer_inst: BusReadBuffer
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      FIFO_DEPTH                => 16,
      RAM_CONFIG                => "",
      SLV_REQ_SLICE             => false,
      MST_REQ_SLICE             => false,
      MST_DAT_SLICE             => false,
      SLV_DAT_SLICE             => false
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      slv_rreq_valid            => mc2b_rreq_valid,
      slv_rreq_ready            => mc2b_rreq_ready,
      slv_rreq_addr             => mc2b_rreq_addr,
      slv_rreq_len              => mc2b_rreq_len,
      slv_rdat_valid            => mc2b_rdat_valid,
      slv_rdat_ready            => mc2b_rdat_ready,
      slv_rdat_data             => mc2b_rdat_data,
      slv_rdat_last             => mc2b_rdat_last,

      mst_rreq_valid            => bc2a_rreq_valid,
      mst_rreq_ready            => bc2a_rreq_ready,
      mst_rreq_addr             => bc2a_rreq_addr,
      mst_rreq_len              => bc2a_rreq_len,
      mst_rdat_valid            => bc2a_rdat_valid,
      mst_rdat_ready            => bc2a_rdat_ready,
      mst_rdat_data             => bc2a_rdat_data,
      mst_rdat_last             => bc2a_rdat_last
    );

  uut: BusReadArbiter
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      NUM_SLAVE_PORTS           => 3,
      ARB_METHOD                => "ROUND-ROBIN",
      MAX_OUTSTANDING           => 4,
      RAM_CONFIG                => "",
      SLV_REQ_SLICES            => false,
      MST_REQ_SLICE             => false,
      MST_DAT_SLICE             => false,
      SLV_DAT_SLICES            => false
    )
    port map (
      bcd_clk                   => clk,
      bcd_reset                 => reset,

      mst_rreq_valid            => a2s_rreq_valid,
      mst_rreq_ready            => a2s_rreq_ready,
      mst_rreq_addr             => a2s_rreq_addr,
      mst_rreq_len              => a2s_rreq_len,
      mst_rdat_valid            => a2s_rdat_valid,
      mst_rdat_ready            => a2s_rdat_ready,
      mst_rdat_data             => a2s_rdat_data,
      mst_rdat_last             => a2s_rdat_last,

      bs00_rreq_valid           => ba2a_rreq_valid,
      bs00_rreq_ready           => ba2a_rreq_ready,
      bs00_rreq_addr            => ba2a_rreq_addr,
      bs00_rreq_len             => ba2a_rreq_len,
      bs00_rdat_valid           => ba2a_rdat_valid,
      bs00_rdat_ready           => ba2a_rdat_ready,
      bs00_rdat_data            => ba2a_rdat_data,
      bs00_rdat_last            => ba2a_rdat_last,
                                
      bs01_rreq_valid           => bb2a_rreq_valid,
      bs01_rreq_ready           => bb2a_rreq_ready,
      bs01_rreq_addr            => bb2a_rreq_addr,
      bs01_rreq_len             => bb2a_rreq_len,
      bs01_rdat_valid           => bb2a_rdat_valid,
      bs01_rdat_ready           => bb2a_rdat_ready,
      bs01_rdat_data            => bb2a_rdat_data,
      bs01_rdat_last            => bb2a_rdat_last,
                                
      bs02_rreq_valid           => bc2a_rreq_valid,
      bs02_rreq_ready           => bc2a_rreq_ready,
      bs02_rreq_addr            => bc2a_rreq_addr,
      bs02_rreq_len             => bc2a_rreq_len,
      bs02_rdat_valid           => bc2a_rdat_valid,
      bs02_rdat_ready           => bc2a_rdat_ready,
      bs02_rdat_data            => bc2a_rdat_data,
      bs02_rdat_last            => bc2a_rdat_last
    );

  slave_inst: BusReadSlaveMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 4
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      rreq_valid                => a2s_rreq_valid,
      rreq_ready                => a2s_rreq_ready,
      rreq_addr                 => a2s_rreq_addr,
      rreq_len                  => a2s_rreq_len,
      rdat_valid                => a2s_rdat_valid,
      rdat_ready                => a2s_rdat_ready,
      rdat_data                 => a2s_rdat_data,
      rdat_last                 => a2s_rdat_last
    );

end Behavioral;

