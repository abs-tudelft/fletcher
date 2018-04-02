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

entity BusWriteArbiter_tb is
end BusWriteArbiter_tb;

architecture Behavioral of BusWriteArbiter_tb is

  constant BUS_ADDR_WIDTH       : natural := 32;
  constant BUS_LEN_WIDTH        : natural := 8;
  constant BUS_DATA_WIDTH       : natural := 32;

  signal clk                    : std_logic := '1';
  signal reset                  : std_logic;

  -- Master A to arbiter.
  signal ma2b_wreq_valid        : std_logic := '0';
  signal ma2b_wreq_ready        : std_logic;
  signal ma2b_wreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal ma2b_wreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal ma2b_wdat_valid        : std_logic := '0';
  signal ma2b_wdat_ready        : std_logic;
  signal ma2b_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ma2b_wdat_last         : std_logic;

  signal ma2b_wdat_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ma2b_wdat_last_m       : std_logic;
  
  -- Master B to arbiter.
  signal mb2b_wreq_valid        : std_logic := '0';
  signal mb2b_wreq_ready        : std_logic;
  signal mb2b_wreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal mb2b_wreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal mb2b_wdat_valid        : std_logic := '0';
  signal mb2b_wdat_ready        : std_logic;
  signal mb2b_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mb2b_wdat_last         : std_logic;

  signal mb2b_wdat_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mb2b_wdat_last_m       : std_logic;

  -- Master C to arbiter.
  signal mc2b_wreq_valid        : std_logic := '0';
  signal mc2b_wreq_ready        : std_logic;
  signal mc2b_wreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal mc2b_wreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal mc2b_wdat_valid        : std_logic := '0';
  signal mc2b_wdat_ready        : std_logic;
  signal mc2b_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mc2b_wdat_last         : std_logic;

  signal mc2b_wdat_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mc2b_wdat_last_m       : std_logic;

  -- Buffers to arbiters

  signal bb2a_wreq_valid        : std_logic := '0';
  signal bb2a_wreq_ready        : std_logic;
  signal bb2a_wreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bb2a_wreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bb2a_wdat_valid        : std_logic := '0';
  signal bb2a_wdat_ready        : std_logic;
  signal bb2a_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bb2a_wdat_last         : std_logic;
  
  signal ba2a_wreq_valid        : std_logic := '0';
  signal ba2a_wreq_ready        : std_logic;
  signal ba2a_wreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal ba2a_wreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal ba2a_wdat_valid        : std_logic := '0';
  signal ba2a_wdat_ready        : std_logic;
  signal ba2a_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ba2a_wdat_last         : std_logic;

  signal bc2a_wreq_valid        : std_logic := '0';
  signal bc2a_wreq_ready        : std_logic;
  signal bc2a_wreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bc2a_wreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bc2a_wdat_valid        : std_logic := '0';
  signal bc2a_wdat_ready        : std_logic;
  signal bc2a_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bc2a_wdat_last         : std_logic;

  -- Arbiter to slave.
  signal a2s_wreq_valid          : std_logic := '0';
  signal a2s_wreq_ready          : std_logic;
  signal a2s_wreq_addr           : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal a2s_wreq_len            : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal a2s_wdat_valid         : std_logic := '0';
  signal a2s_wdat_ready         : std_logic;
  signal a2s_wdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal a2s_wdat_last          : std_logic;

begin

  ma2b_wdat_data_m <= ma2b_wdat_data when ma2b_wdat_valid = '1' and ma2b_wdat_ready = '1' else (others => 'Z');
  ma2b_wdat_last_m <= ma2b_wdat_last when ma2b_wdat_valid = '1' and ma2b_wdat_ready = '1' else 'Z';

  mb2b_wdat_data_m <= mb2b_wdat_data when mb2b_wdat_valid = '1' and mb2b_wdat_ready = '1' else (others => 'Z');
  mb2b_wdat_last_m <= mb2b_wdat_last when mb2b_wdat_valid = '1' and mb2b_wdat_ready = '1' else 'Z';

  mc2b_wdat_data_m <= mc2b_wdat_data when mc2b_wdat_valid = '1' and mc2b_wdat_ready = '1' else (others => 'Z');
  mc2b_wdat_last_m <= mc2b_wdat_last when mc2b_wdat_valid = '1' and mc2b_wdat_ready = '1' else 'Z';

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

  mst_a_inst: BusWriteMasterMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      wreq_valid                => ma2b_wreq_valid,
      wreq_ready                => ma2b_wreq_ready,
      wreq_addr                 => ma2b_wreq_addr,
      wreq_len                  => ma2b_wreq_len,
      wdat_valid                => ma2b_wdat_valid,
      wdat_ready                => ma2b_wdat_ready,
      wdat_data                 => ma2b_wdat_data,
      wdat_last                 => ma2b_wdat_last
    );

  mst_a_buffer_inst: BusWriteBuffer
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      FIFO_DEPTH                => 16,
      RAM_CONFIG                => "",
      LEN_SHIFT                 => 0,
      SLV_LAST_MODE             => "burst"
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      slv_wreq_valid            => ma2b_wreq_valid,
      slv_wreq_ready            => ma2b_wreq_ready,
      slv_wreq_addr             => ma2b_wreq_addr,
      slv_wreq_len              => ma2b_wreq_len,
      slv_wdat_valid            => ma2b_wdat_valid,
      slv_wdat_ready            => ma2b_wdat_ready,
      slv_wdat_data             => ma2b_wdat_data,
      slv_wdat_last             => ma2b_wdat_last,

      mst_wreq_valid            => ba2a_wreq_valid,
      mst_wreq_ready            => ba2a_wreq_ready,
      mst_wreq_addr             => ba2a_wreq_addr,
      mst_wreq_len              => ba2a_wreq_len,
      mst_wdat_valid            => ba2a_wdat_valid,
      mst_wdat_ready            => ba2a_wdat_ready,
      mst_wdat_data             => ba2a_wdat_data,
      mst_wdat_last             => ba2a_wdat_last
    );

  mst_b_inst: BusWriteMasterMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      wreq_valid                => mb2b_wreq_valid,
      wreq_ready                => mb2b_wreq_ready,
      wreq_addr                 => mb2b_wreq_addr,
      wreq_len                  => mb2b_wreq_len,
      wdat_valid                => mb2b_wdat_valid,
      wdat_ready                => mb2b_wdat_ready,
      wdat_data                 => mb2b_wdat_data,
      wdat_last                 => mb2b_wdat_last
    );

  mst_b_buffer_inst: BusWriteBuffer
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      FIFO_DEPTH                => 16,
      RAM_CONFIG                => "",
      LEN_SHIFT                 => 0,
      SLV_LAST_MODE             => "stream"
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      slv_wreq_valid            => mb2b_wreq_valid,
      slv_wreq_ready            => mb2b_wreq_ready,
      slv_wreq_addr             => mb2b_wreq_addr,
      slv_wreq_len              => mb2b_wreq_len,
      slv_wdat_valid            => mb2b_wdat_valid,
      slv_wdat_ready            => mb2b_wdat_ready,
      slv_wdat_data             => mb2b_wdat_data,
      slv_wdat_last             => mb2b_wdat_last,

      mst_wreq_valid            => bb2a_wreq_valid,
      mst_wreq_ready            => bb2a_wreq_ready,
      mst_wreq_addr             => bb2a_wreq_addr,
      mst_wreq_len              => bb2a_wreq_len,
      mst_wdat_valid            => bb2a_wdat_valid,
      mst_wdat_ready            => bb2a_wdat_ready,
      mst_wdat_data             => bb2a_wdat_data,
      mst_wdat_last             => bb2a_wdat_last
    );

  mst_c_inst: BusWriteMasterMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 3
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      wreq_valid                => mc2b_wreq_valid,
      wreq_ready                => mc2b_wreq_ready,
      wreq_addr                 => mc2b_wreq_addr,
      wreq_len                  => mc2b_wreq_len,
      wdat_valid                => mc2b_wdat_valid,
      wdat_ready                => mc2b_wdat_ready,
      wdat_data                 => mc2b_wdat_data,
      wdat_last                 => mc2b_wdat_last
    );

  mst_c_buffer_inst: BusWriteBuffer
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      FIFO_DEPTH                => 16,
      RAM_CONFIG                => "",
      LEN_SHIFT                 => 0,
      SLV_LAST_MODE             => "stream"
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      slv_wreq_valid            => mc2b_wreq_valid,
      slv_wreq_ready            => mc2b_wreq_ready,
      slv_wreq_addr             => mc2b_wreq_addr,
      slv_wreq_len              => mc2b_wreq_len,
      slv_wdat_valid            => mc2b_wdat_valid,
      slv_wdat_ready            => mc2b_wdat_ready,
      slv_wdat_data             => mc2b_wdat_data,
      slv_wdat_last             => mc2b_wdat_last,

      mst_wreq_valid            => bc2a_wreq_valid,
      mst_wreq_ready            => bc2a_wreq_ready,
      mst_wreq_addr             => bc2a_wreq_addr,
      mst_wreq_len              => bc2a_wreq_len,
      mst_wdat_valid            => bc2a_wdat_valid,
      mst_wdat_ready            => bc2a_wdat_ready,
      mst_wdat_data             => bc2a_wdat_data,
      mst_wdat_last             => bc2a_wdat_last
    );

  uut: BusWriteArbiter
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      NUM_SLAVES                => 3,
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

      mst_wreq_valid            => a2s_wreq_valid,
      mst_wreq_ready            => a2s_wreq_ready,
      mst_wreq_addr             => a2s_wreq_addr,
      mst_wreq_len              => a2s_wreq_len,
      mst_wdat_valid            => a2s_wdat_valid,
      mst_wdat_ready            => a2s_wdat_ready,
      mst_wdat_data             => a2s_wdat_data,
      mst_wdat_last             => a2s_wdat_last,

      bs0_wreq_valid            => ba2a_wreq_valid,
      bs0_wreq_ready            => ba2a_wreq_ready,
      bs0_wreq_addr             => ba2a_wreq_addr,
      bs0_wreq_len              => ba2a_wreq_len,
      bs0_wdat_valid            => ba2a_wdat_valid,
      bs0_wdat_ready            => ba2a_wdat_ready,
      bs0_wdat_data             => ba2a_wdat_data,
      bs0_wdat_last             => ba2a_wdat_last,

      bs1_wreq_valid            => bb2a_wreq_valid,
      bs1_wreq_ready            => bb2a_wreq_ready,
      bs1_wreq_addr             => bb2a_wreq_addr,
      bs1_wreq_len              => bb2a_wreq_len,
      bs1_wdat_valid            => bb2a_wdat_valid,
      bs1_wdat_ready            => bb2a_wdat_ready,
      bs1_wdat_data             => bb2a_wdat_data,
      bs1_wdat_last             => bb2a_wdat_last,

      bs2_wreq_valid            => bc2a_wreq_valid,
      bs2_wreq_ready            => bc2a_wreq_ready,
      bs2_wreq_addr             => bc2a_wreq_addr,
      bs2_wreq_len              => bc2a_wreq_len,
      bs2_wdat_valid            => bc2a_wdat_valid,
      bs2_wdat_ready            => bc2a_wdat_ready,
      bs2_wdat_data             => bc2a_wdat_data,
      bs2_wdat_last             => bc2a_wdat_last
    );

  slave_inst: BusWriteSlaveMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 4
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      wreq_valid                => a2s_wreq_valid,
      wreq_ready                => a2s_wreq_ready,
      wreq_addr                 => a2s_wreq_addr,
      wreq_len                  => a2s_wreq_len,
      wdat_valid                => a2s_wdat_valid,
      wdat_ready                => a2s_wdat_ready,
      wdat_data                 => a2s_wdat_data,
      wdat_last                 => a2s_wdat_last
    );

end Behavioral;

