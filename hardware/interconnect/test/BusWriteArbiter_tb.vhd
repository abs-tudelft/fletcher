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
  signal ma2b_wreq_last         : std_logic;
  signal ma2b_wdat_valid        : std_logic := '0';
  signal ma2b_wdat_ready        : std_logic;
  signal ma2b_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ma2b_wdat_strobe       : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal ma2b_wdat_last         : std_logic;
  signal ma2b_wrep_valid        : std_logic := '0';
  signal ma2b_wrep_ready        : std_logic;
  signal ma2b_wrep_ok           : std_logic;

  signal ma2b_wdat_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ma2b_wdat_last_m       : std_logic;
  
  -- Master B to arbiter.
  signal mb2b_wreq_valid        : std_logic := '0';
  signal mb2b_wreq_ready        : std_logic;
  signal mb2b_wreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal mb2b_wreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal mb2b_wreq_last         : std_logic;
  signal mb2b_wdat_valid        : std_logic := '0';
  signal mb2b_wdat_ready        : std_logic;
  signal mb2b_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mb2b_wdat_strobe       : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal mb2b_wdat_last         : std_logic;
  signal mb2b_wrep_valid        : std_logic := '0';
  signal mb2b_wrep_ready        : std_logic;
  signal mb2b_wrep_ok           : std_logic;

  signal mb2b_wdat_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mb2b_wdat_last_m       : std_logic;

  -- Master C to arbiter.
  signal mc2b_wreq_valid        : std_logic := '0';
  signal mc2b_wreq_ready        : std_logic;
  signal mc2b_wreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal mc2b_wreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal mc2b_wreq_last         : std_logic;
  signal mc2b_wdat_valid        : std_logic := '0';
  signal mc2b_wdat_ready        : std_logic;
  signal mc2b_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mc2b_wdat_strobe       : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal mc2b_wdat_last         : std_logic;
  signal mc2b_wrep_valid        : std_logic := '0';
  signal mc2b_wrep_ready        : std_logic;
  signal mc2b_wrep_ok           : std_logic;

  signal mc2b_wdat_data_m       : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mc2b_wdat_last_m       : std_logic;

  -- Buffers to arbiters

  signal ba2a_wreq_valid        : std_logic := '0';
  signal ba2a_wreq_ready        : std_logic;
  signal ba2a_wreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal ba2a_wreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal ba2a_wreq_last         : std_logic;
  signal ba2a_wdat_valid        : std_logic := '0';
  signal ba2a_wdat_ready        : std_logic;
  signal ba2a_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal ba2a_wdat_strobe       : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal ba2a_wdat_last         : std_logic;
  signal ba2a_wrep_valid        : std_logic := '0';
  signal ba2a_wrep_ready        : std_logic;
  signal ba2a_wrep_ok           : std_logic;

  signal bb2a_wreq_valid        : std_logic := '0';
  signal bb2a_wreq_ready        : std_logic;
  signal bb2a_wreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bb2a_wreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bb2a_wreq_last         : std_logic;
  signal bb2a_wdat_valid        : std_logic := '0';
  signal bb2a_wdat_ready        : std_logic;
  signal bb2a_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bb2a_wdat_strobe       : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal bb2a_wdat_last         : std_logic;
  signal bb2a_wrep_valid        : std_logic := '0';
  signal bb2a_wrep_ready        : std_logic;
  signal bb2a_wrep_ok           : std_logic;

  signal bc2a_wreq_valid        : std_logic := '0';
  signal bc2a_wreq_ready        : std_logic;
  signal bc2a_wreq_addr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bc2a_wreq_len          : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bc2a_wreq_last         : std_logic;
  signal bc2a_wdat_valid        : std_logic := '0';
  signal bc2a_wdat_ready        : std_logic;
  signal bc2a_wdat_data         : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bc2a_wdat_strobe       : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal bc2a_wdat_last         : std_logic;
  signal bc2a_wrep_valid        : std_logic := '0';
  signal bc2a_wrep_ready        : std_logic;
  signal bc2a_wrep_ok           : std_logic;

  -- Arbiter to slave.
  signal a2s_wreq_valid          : std_logic := '0';
  signal a2s_wreq_ready          : std_logic;
  signal a2s_wreq_addr           : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal a2s_wreq_len            : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal a2s_wreq_last           : std_logic;
  signal a2s_wdat_valid          : std_logic := '0';
  signal a2s_wdat_ready          : std_logic;
  signal a2s_wdat_data           : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal a2s_wdat_strobe         : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal a2s_wdat_last           : std_logic;
  signal a2s_wrep_valid          : std_logic := '0';
  signal a2s_wrep_ready          : std_logic;
  signal a2s_wrep_ok             : std_logic;

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
      wreq_last                 => ma2b_wreq_last,
      wdat_valid                => ma2b_wdat_valid,
      wdat_ready                => ma2b_wdat_ready,
      wdat_data                 => ma2b_wdat_data,
      wdat_strobe               => ma2b_wdat_strobe,
      wdat_last                 => ma2b_wdat_last,
      wrep_valid                => ma2b_wrep_valid,
      wrep_ready                => ma2b_wrep_ready,
      wrep_ok                   => ma2b_wrep_ok
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
      slv_wreq_last             => ma2b_wreq_last,
      slv_wdat_valid            => ma2b_wdat_valid,
      slv_wdat_ready            => ma2b_wdat_ready,
      slv_wdat_data             => ma2b_wdat_data,
      slv_wdat_strobe           => ma2b_wdat_strobe,
      slv_wdat_last             => ma2b_wdat_last,
      slv_wrep_valid            => ma2b_wrep_valid,
      slv_wrep_ready            => ma2b_wrep_ready,
      slv_wrep_ok               => ma2b_wrep_ok,

      mst_wreq_valid            => ba2a_wreq_valid,
      mst_wreq_ready            => ba2a_wreq_ready,
      mst_wreq_addr             => ba2a_wreq_addr,
      mst_wreq_len              => ba2a_wreq_len,
      mst_wreq_last             => ba2a_wreq_last,
      mst_wdat_valid            => ba2a_wdat_valid,
      mst_wdat_ready            => ba2a_wdat_ready,
      mst_wdat_data             => ba2a_wdat_data,
      mst_wdat_strobe           => ba2a_wdat_strobe,
      mst_wdat_last             => ba2a_wdat_last,
      mst_wrep_valid            => ba2a_wrep_valid,
      mst_wrep_ready            => ba2a_wrep_ready,
      mst_wrep_ok               => ba2a_wrep_ok
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
      wreq_last                 => mb2b_wreq_last,
      wdat_valid                => mb2b_wdat_valid,
      wdat_ready                => mb2b_wdat_ready,
      wdat_data                 => mb2b_wdat_data,
      wdat_strobe               => mb2b_wdat_strobe,
      wdat_last                 => mb2b_wdat_last,
      wrep_valid                => mb2b_wrep_valid,
      wrep_ready                => mb2b_wrep_ready,
      wrep_ok                   => mb2b_wrep_ok
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
      slv_wreq_last             => mb2b_wreq_last,
      slv_wdat_valid            => mb2b_wdat_valid,
      slv_wdat_ready            => mb2b_wdat_ready,
      slv_wdat_data             => mb2b_wdat_data,
      slv_wdat_strobe           => mb2b_wdat_strobe,
      slv_wdat_last             => mb2b_wdat_last,
      slv_wrep_valid            => mb2b_wrep_valid,
      slv_wrep_ready            => mb2b_wrep_ready,
      slv_wrep_ok               => mb2b_wrep_ok,

      mst_wreq_valid            => bb2a_wreq_valid,
      mst_wreq_ready            => bb2a_wreq_ready,
      mst_wreq_addr             => bb2a_wreq_addr,
      mst_wreq_len              => bb2a_wreq_len,
      mst_wreq_last             => bb2a_wreq_last,
      mst_wdat_valid            => bb2a_wdat_valid,
      mst_wdat_ready            => bb2a_wdat_ready,
      mst_wdat_data             => bb2a_wdat_data,
      mst_wdat_strobe           => bb2a_wdat_strobe,
      mst_wdat_last             => bb2a_wdat_last,
      mst_wrep_valid            => bb2a_wrep_valid,
      mst_wrep_ready            => bb2a_wrep_ready,
      mst_wrep_ok               => bb2a_wrep_ok
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
      wreq_last                 => mc2b_wreq_last,
      wdat_valid                => mc2b_wdat_valid,
      wdat_ready                => mc2b_wdat_ready,
      wdat_data                 => mc2b_wdat_data,
      wdat_strobe               => mc2b_wdat_strobe,
      wdat_last                 => mc2b_wdat_last,
      wrep_valid                => mc2b_wrep_valid,
      wrep_ready                => mc2b_wrep_ready,
      wrep_ok                   => mc2b_wrep_ok
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
      slv_wreq_last             => mc2b_wreq_last,
      slv_wdat_valid            => mc2b_wdat_valid,
      slv_wdat_ready            => mc2b_wdat_ready,
      slv_wdat_data             => mc2b_wdat_data,
      slv_wdat_strobe           => mc2b_wdat_strobe,
      slv_wdat_last             => mc2b_wdat_last,
      slv_wrep_valid            => mc2b_wrep_valid,
      slv_wrep_ready            => mc2b_wrep_ready,
      slv_wrep_ok               => mc2b_wrep_ok,

      mst_wreq_valid            => bc2a_wreq_valid,
      mst_wreq_ready            => bc2a_wreq_ready,
      mst_wreq_addr             => bc2a_wreq_addr,
      mst_wreq_len              => bc2a_wreq_len,
      mst_wreq_last             => bc2a_wreq_last,
      mst_wdat_valid            => bc2a_wdat_valid,
      mst_wdat_ready            => bc2a_wdat_ready,
      mst_wdat_data             => bc2a_wdat_data,
      mst_wdat_strobe           => bc2a_wdat_strobe,
      mst_wdat_last             => bc2a_wdat_last,
      mst_wrep_valid            => bc2a_wrep_valid,
      mst_wrep_ready            => bc2a_wrep_ready,
      mst_wrep_ok               => bc2a_wrep_ok
    );

  uut: BusWriteArbiter
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      NUM_SLAVE_PORTS           => 3,
      ARB_METHOD                => "ROUND-ROBIN",
      MAX_OUTSTANDING           => 4,
      RAM_CONFIG                => "",
      SLV_REQ_SLICES            => true,
      MST_REQ_SLICE             => true,
      MST_DAT_SLICE             => true,
      SLV_DAT_SLICES            => true
    )
    port map (
      bcd_clk                   => clk,
      bcd_reset                 => reset,

      mst_wreq_valid            => a2s_wreq_valid,
      mst_wreq_ready            => a2s_wreq_ready,
      mst_wreq_addr             => a2s_wreq_addr,
      mst_wreq_len              => a2s_wreq_len,
      mst_wreq_last             => a2s_wreq_last,
      mst_wdat_valid            => a2s_wdat_valid,
      mst_wdat_ready            => a2s_wdat_ready,
      mst_wdat_data             => a2s_wdat_data,
      mst_wdat_strobe           => a2s_wdat_strobe,
      mst_wdat_last             => a2s_wdat_last,
      mst_wrep_valid            => a2s_wrep_valid,
      mst_wrep_ready            => a2s_wrep_ready,
      mst_wrep_ok               => a2s_wrep_ok,

      bs00_wreq_valid           => ba2a_wreq_valid,
      bs00_wreq_ready           => ba2a_wreq_ready,
      bs00_wreq_addr            => ba2a_wreq_addr,
      bs00_wreq_len             => ba2a_wreq_len,
      bs00_wreq_last            => ba2a_wreq_last,
      bs00_wdat_valid           => ba2a_wdat_valid,
      bs00_wdat_ready           => ba2a_wdat_ready,
      bs00_wdat_data            => ba2a_wdat_data,
      bs00_wdat_strobe          => ba2a_wdat_strobe,
      bs00_wdat_last            => ba2a_wdat_last,
      bs00_wrep_valid           => ba2a_wrep_valid,
      bs00_wrep_ready           => ba2a_wrep_ready,
      bs00_wrep_ok              => ba2a_wrep_ok,

      bs01_wreq_valid           => bb2a_wreq_valid,
      bs01_wreq_ready           => bb2a_wreq_ready,
      bs01_wreq_addr            => bb2a_wreq_addr,
      bs01_wreq_len             => bb2a_wreq_len,
      bs01_wreq_last            => bb2a_wreq_last,
      bs01_wdat_valid           => bb2a_wdat_valid,
      bs01_wdat_ready           => bb2a_wdat_ready,
      bs01_wdat_data            => bb2a_wdat_data,
      bs01_wdat_strobe          => bb2a_wdat_strobe,
      bs01_wdat_last            => bb2a_wdat_last,
      bs01_wrep_valid           => bb2a_wrep_valid,
      bs01_wrep_ready           => bb2a_wrep_ready,
      bs01_wrep_ok              => bb2a_wrep_ok,

      bs02_wreq_valid           => bc2a_wreq_valid,
      bs02_wreq_ready           => bc2a_wreq_ready,
      bs02_wreq_addr            => bc2a_wreq_addr,
      bs02_wreq_len             => bc2a_wreq_len,
      bs02_wreq_last            => bc2a_wreq_last,
      bs02_wdat_valid           => bc2a_wdat_valid,
      bs02_wdat_ready           => bc2a_wdat_ready,
      bs02_wdat_data            => bc2a_wdat_data,
      bs02_wdat_strobe          => bc2a_wdat_strobe,
      bs02_wdat_last            => bc2a_wdat_last,
      bs02_wrep_valid           => bc2a_wrep_valid,
      bs02_wrep_ready           => bc2a_wrep_ready,
      bs02_wrep_ok              => bc2a_wrep_ok
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
      wreq_last                 => a2s_wreq_last,
      wdat_valid                => a2s_wdat_valid,
      wdat_ready                => a2s_wdat_ready,
      wdat_data                 => a2s_wdat_data,
      wdat_strobe               => a2s_wdat_strobe,
      wdat_last                 => a2s_wdat_last,
      wrep_valid                => a2s_wrep_valid,
      wrep_ready                => a2s_wrep_ready,
      wrep_ok                   => a2s_wrep_ok
    );

end Behavioral;

