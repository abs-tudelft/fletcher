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
use ieee.math_real.all;

library work;
use work.Streams.all;
use work.StreamSim.all;

entity StreamGearbox_tb is
  generic (
    COUNT_MAX_B                 : natural;
    COUNT_WIDTH_B               : natural;
    COUNT_MAX_C                 : natural;
    COUNT_WIDTH_C               : natural
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic
  );
end StreamGearbox_tb;

architecture TestBench of StreamGearbox_tb is

  signal data_a                 : std_logic_vector(7 downto 0);
  signal count_a                : std_logic_vector(0 downto 0);
  signal last_a                 : std_logic;
  signal valid_a                : std_logic;
  signal ready_a                : std_logic;

  signal data_b                 : std_logic_vector(COUNT_MAX_B*6 + 1 downto 0);
  signal count_b                : std_logic_vector(COUNT_WIDTH_B - 1 downto 0);
  signal last_b                 : std_logic;
  signal valid_b                : std_logic;
  signal ready_b                : std_logic;

  signal data_c                 : std_logic_vector(COUNT_MAX_C*6 + 1 downto 0);
  signal count_c                : std_logic_vector(COUNT_WIDTH_C - 1 downto 0);
  signal last_c                 : std_logic;
  signal valid_c                : std_logic;
  signal ready_c                : std_logic;

  signal data_d                 : std_logic_vector(7 downto 0);
  signal fixed_d                : std_logic_vector(7 downto 0);
  signal count_d                : std_logic_vector(0 downto 0);
  signal last_d                 : std_logic;
  signal valid_d                : std_logic;
  signal ready_d                : std_logic;

begin

  prod_a: StreamTbProd
    generic map (
      DATA_WIDTH                => 8,
      SEED                      => 1,
      NAME                      => "a"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => valid_a,
      out_ready                 => ready_a,
      out_data                  => data_a
    );

  -- ASCII 0..63 (numbers, some symbols, space, control chars) = normal data, last
  -- ASCII 64..127 (alphas, some symbols) = normal data, not last
  -- ASCII C128 = null packet; that is, a packet with 0 length
  count_a <= not data_a(7 downto 7);
  last_a <= not data_a(6);

  a_to_b: StreamGearbox
    generic map (
      DATA_WIDTH                => 6,
      CTRL_WIDTH                => 2,
      OUT_COUNT_MAX             => COUNT_MAX_B,
      OUT_COUNT_WIDTH           => COUNT_WIDTH_B
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => valid_a,
      in_ready                  => ready_a,
      in_data                   => data_a,
      in_count                  => count_a,
      in_last                   => last_a,

      out_valid                 => valid_b,
      out_ready                 => ready_b,
      out_data                  => data_b,
      out_count                 => count_b,
      out_last                  => last_b
    );

  uut: StreamGearbox
    generic map (
      DATA_WIDTH                => 6,
      CTRL_WIDTH                => 2,
      IN_COUNT_MAX              => COUNT_MAX_B,
      IN_COUNT_WIDTH            => COUNT_WIDTH_B,
      OUT_COUNT_MAX             => COUNT_MAX_C,
      OUT_COUNT_WIDTH           => COUNT_WIDTH_C
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => valid_b,
      in_ready                  => ready_b,
      in_data                   => data_b,
      in_count                  => count_b,
      in_last                   => last_b,

      out_valid                 => valid_c,
      out_ready                 => ready_c,
      out_data                  => data_c,
      out_count                 => count_c,
      out_last                  => last_c
    );

  c_to_d: StreamGearbox
    generic map (
      DATA_WIDTH                => 6,
      CTRL_WIDTH                => 2,
      IN_COUNT_MAX              => COUNT_MAX_C,
      IN_COUNT_WIDTH            => COUNT_WIDTH_C
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => valid_c,
      in_ready                  => ready_c,
      in_data                   => data_c,
      in_count                  => count_c,
      in_last                   => last_c,

      out_valid                 => valid_d,
      out_ready                 => ready_d,
      out_data                  => data_d,
      out_count                 => count_d,
      out_last                  => last_d
    );

  fixed_d(7) <= data_d(7);
  fixed_d(6) <= data_d(6) or not last_d;
  fixed_d(5 downto 0) <= data_d(5 downto 0);

  cons_d: StreamTbCons
    generic map (
      DATA_WIDTH                => 8,
      SEED                      => 1,
      NAME                      => "d"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_d,
      in_ready                  => ready_d,
      in_data                   => fixed_d
    );

end TestBench;

