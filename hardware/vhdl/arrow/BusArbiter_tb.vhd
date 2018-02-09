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
use work.Arrow.all;
use work.Utils.all;

entity BusArbiter_tb is
end BusArbiter_tb;

architecture Behavioral of BusArbiter_tb is

  constant BUS_ADDR_WIDTH       : natural := 32;
  constant BUS_LEN_WIDTH        : natural := 8;
  constant BUS_DATA_WIDTH       : natural := 32;

  signal clk                    : std_logic := '1';
  signal reset                  : std_logic;

  -- Master A to arbiter.
  signal ma2b_req_valid         : std_logic;
  signal ma2b_req_ready         : std_logic;
  signal ma2b_req_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal ma2b_req_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal ma2b_resp_valid        : std_logic;
  signal ma2b_resp_ready        : std_logic;
  signal ma2b_resp_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ma2b_resp_last         : std_logic;

  signal ma2b_resp_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ma2b_resp_last_m       : std_logic;

  signal ba2a_req_valid         : std_logic;
  signal ba2a_req_ready         : std_logic;
  signal ba2a_req_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal ba2a_req_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal ba2a_resp_valid        : std_logic;
  signal ba2a_resp_ready        : std_logic;
  signal ba2a_resp_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ba2a_resp_last         : std_logic;

  -- Master B to arbiter.
  signal mb2b_req_valid         : std_logic;
  signal mb2b_req_ready         : std_logic;
  signal mb2b_req_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal mb2b_req_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal mb2b_resp_valid        : std_logic;
  signal mb2b_resp_ready        : std_logic;
  signal mb2b_resp_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mb2b_resp_last         : std_logic;

  signal mb2b_resp_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mb2b_resp_last_m       : std_logic;

  signal bb2a_req_valid         : std_logic;
  signal bb2a_req_ready         : std_logic;
  signal bb2a_req_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bb2a_req_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bb2a_resp_valid        : std_logic;
  signal bb2a_resp_ready        : std_logic;
  signal bb2a_resp_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bb2a_resp_last         : std_logic;

  -- Master C to arbiter.
  signal mc2b_req_valid         : std_logic;
  signal mc2b_req_ready         : std_logic;
  signal mc2b_req_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal mc2b_req_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal mc2b_resp_valid        : std_logic;
  signal mc2b_resp_ready        : std_logic;
  signal mc2b_resp_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mc2b_resp_last         : std_logic;

  signal mc2b_resp_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mc2b_resp_last_m       : std_logic;

  signal bc2a_req_valid         : std_logic;
  signal bc2a_req_ready         : std_logic;
  signal bc2a_req_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bc2a_req_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bc2a_resp_valid        : std_logic;
  signal bc2a_resp_ready        : std_logic;
  signal bc2a_resp_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bc2a_resp_last         : std_logic;

  -- Arbiter to slave.
  signal a2s_req_valid          : std_logic;
  signal a2s_req_ready          : std_logic;
  signal a2s_req_addr           : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal a2s_req_len            : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal a2s_resp_valid         : std_logic;
  signal a2s_resp_ready         : std_logic;
  signal a2s_resp_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal a2s_resp_last          : std_logic;

begin

  ma2b_resp_data_m <= ma2b_resp_data when ma2b_resp_valid = '1' and ma2b_resp_ready = '1' else (others => 'Z');
  ma2b_resp_last_m <= ma2b_resp_last when ma2b_resp_valid = '1' and ma2b_resp_ready = '1' else 'Z';

  mb2b_resp_data_m <= mb2b_resp_data when mb2b_resp_valid = '1' and mb2b_resp_ready = '1' else (others => 'Z');
  mb2b_resp_last_m <= mb2b_resp_last when mb2b_resp_valid = '1' and mb2b_resp_ready = '1' else 'Z';

  mc2b_resp_data_m <= mc2b_resp_data when mc2b_resp_valid = '1' and mc2b_resp_ready = '1' else (others => 'Z');
  mc2b_resp_last_m <= mc2b_resp_last when mc2b_resp_valid = '1' and mc2b_resp_ready = '1' else 'Z';

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

  mst_a_inst: BusMasterMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      req_valid                 => ma2b_req_valid,
      req_ready                 => ma2b_req_ready,
      req_addr                  => ma2b_req_addr,
      req_len                   => ma2b_req_len,
      resp_valid                => ma2b_resp_valid,
      resp_ready                => ma2b_resp_ready,
      resp_data                 => ma2b_resp_data,
      resp_last                 => ma2b_resp_last
    );

  mst_a_buffer_inst: BusBuffer
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      FIFO_DEPTH                => 16,
      RAM_CONFIG                => "",
      REQ_IN_SLICE              => false,
      REQ_OUT_SLICE             => true,
      RESP_IN_SLICE             => false,
      RESP_OUT_SLICE            => true
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      mst_req_valid             => ma2b_req_valid,
      mst_req_ready             => ma2b_req_ready,
      mst_req_addr              => ma2b_req_addr,
      mst_req_len               => ma2b_req_len,
      mst_resp_valid            => ma2b_resp_valid,
      mst_resp_ready            => ma2b_resp_ready,
      mst_resp_data             => ma2b_resp_data,
      mst_resp_last             => ma2b_resp_last,

      slv_req_valid             => ba2a_req_valid,
      slv_req_ready             => ba2a_req_ready,
      slv_req_addr              => ba2a_req_addr,
      slv_req_len               => ba2a_req_len,
      slv_resp_valid            => ba2a_resp_valid,
      slv_resp_ready            => ba2a_resp_ready,
      slv_resp_data             => ba2a_resp_data,
      slv_resp_last             => ba2a_resp_last
    );

  mst_b_inst: BusMasterMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      req_valid                 => mb2b_req_valid,
      req_ready                 => mb2b_req_ready,
      req_addr                  => mb2b_req_addr,
      req_len                   => mb2b_req_len,
      resp_valid                => mb2b_resp_valid,
      resp_ready                => mb2b_resp_ready,
      resp_data                 => mb2b_resp_data,
      resp_last                 => mb2b_resp_last
    );

  mst_b_buffer_inst: BusBuffer
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      FIFO_DEPTH                => 16,
      RAM_CONFIG                => "",
      REQ_IN_SLICE              => false,
      REQ_OUT_SLICE             => true,
      RESP_IN_SLICE             => false,
      RESP_OUT_SLICE            => true
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      mst_req_valid             => mb2b_req_valid,
      mst_req_ready             => mb2b_req_ready,
      mst_req_addr              => mb2b_req_addr,
      mst_req_len               => mb2b_req_len,
      mst_resp_valid            => mb2b_resp_valid,
      mst_resp_ready            => mb2b_resp_ready,
      mst_resp_data             => mb2b_resp_data,
      mst_resp_last             => mb2b_resp_last,

      slv_req_valid             => bb2a_req_valid,
      slv_req_ready             => bb2a_req_ready,
      slv_req_addr              => bb2a_req_addr,
      slv_req_len               => bb2a_req_len,
      slv_resp_valid            => bb2a_resp_valid,
      slv_resp_ready            => bb2a_resp_ready,
      slv_resp_data             => bb2a_resp_data,
      slv_resp_last             => bb2a_resp_last
    );

  mst_c_inst: BusMasterMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 3
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      req_valid                 => mc2b_req_valid,
      req_ready                 => mc2b_req_ready,
      req_addr                  => mc2b_req_addr,
      req_len                   => mc2b_req_len,
      resp_valid                => mc2b_resp_valid,
      resp_ready                => mc2b_resp_ready,
      resp_data                 => mc2b_resp_data,
      resp_last                 => mc2b_resp_last
    );

  mst_c_buffer_inst: BusBuffer
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      FIFO_DEPTH                => 16,
      RAM_CONFIG                => "",
      REQ_IN_SLICE              => false,
      REQ_OUT_SLICE             => true,
      RESP_IN_SLICE             => false,
      RESP_OUT_SLICE            => true
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      mst_req_valid             => mc2b_req_valid,
      mst_req_ready             => mc2b_req_ready,
      mst_req_addr              => mc2b_req_addr,
      mst_req_len               => mc2b_req_len,
      mst_resp_valid            => mc2b_resp_valid,
      mst_resp_ready            => mc2b_resp_ready,
      mst_resp_data             => mc2b_resp_data,
      mst_resp_last             => mc2b_resp_last,

      slv_req_valid             => bc2a_req_valid,
      slv_req_ready             => bc2a_req_ready,
      slv_req_addr              => bc2a_req_addr,
      slv_req_len               => bc2a_req_len,
      slv_resp_valid            => bc2a_resp_valid,
      slv_resp_ready            => bc2a_resp_ready,
      slv_resp_data             => bc2a_resp_data,
      slv_resp_last             => bc2a_resp_last
    );

  uut: BusArbiter
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      NUM_MASTERS               => 3,
      ARB_METHOD                => "ROUND-ROBIN",
      MAX_OUTSTANDING           => 4,
      RAM_CONFIG                => "",
      REQ_IN_SLICES             => true,
      REQ_OUT_SLICE             => true,
      RESP_IN_SLICE             => true,
      RESP_OUT_SLICES           => true
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      slv_req_valid             => a2s_req_valid,
      slv_req_ready             => a2s_req_ready,
      slv_req_addr              => a2s_req_addr,
      slv_req_len               => a2s_req_len,
      slv_resp_valid            => a2s_resp_valid,
      slv_resp_ready            => a2s_resp_ready,
      slv_resp_data             => a2s_resp_data,
      slv_resp_last             => a2s_resp_last,

      bm0_req_valid             => ba2a_req_valid,
      bm0_req_ready             => ba2a_req_ready,
      bm0_req_addr              => ba2a_req_addr,
      bm0_req_len               => ba2a_req_len,
      bm0_resp_valid            => ba2a_resp_valid,
      bm0_resp_ready            => ba2a_resp_ready,
      bm0_resp_data             => ba2a_resp_data,
      bm0_resp_last             => ba2a_resp_last,

      bm1_req_valid             => bb2a_req_valid,
      bm1_req_ready             => bb2a_req_ready,
      bm1_req_addr              => bb2a_req_addr,
      bm1_req_len               => bb2a_req_len,
      bm1_resp_valid            => bb2a_resp_valid,
      bm1_resp_ready            => bb2a_resp_ready,
      bm1_resp_data             => bb2a_resp_data,
      bm1_resp_last             => bb2a_resp_last,

      bm2_req_valid             => bc2a_req_valid,
      bm2_req_ready             => bc2a_req_ready,
      bm2_req_addr              => bc2a_req_addr,
      bm2_req_len               => bc2a_req_len,
      bm2_resp_valid            => bc2a_resp_valid,
      bm2_resp_ready            => bc2a_resp_ready,
      bm2_resp_data             => bc2a_resp_data,
      bm2_resp_last             => bc2a_resp_last
    );

  slave_inst: BusSlaveMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 4
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      req_valid                 => a2s_req_valid,
      req_ready                 => a2s_req_ready,
      req_addr                  => a2s_req_addr,
      req_len                   => a2s_req_len,
      resp_valid                => a2s_resp_valid,
      resp_ready                => a2s_resp_ready,
      resp_data                 => a2s_resp_data,
      resp_last                 => a2s_resp_last
    );

end Behavioral;

