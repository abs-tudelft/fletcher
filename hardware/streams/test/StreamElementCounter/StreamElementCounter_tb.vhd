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

entity StreamElementCounter_tb is
  generic (
    IN_COUNT_WIDTH              : positive;
    IN_COUNT_MAX                : positive;
    OUT_COUNT_WIDTH             : positive;
    OUT_COUNT_MAX               : positive;
    OUT_COUNT_MAX_CLAMP         : natural
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic
  );
end StreamElementCounter_tb;

architecture TestBench of StreamElementCounter_tb is

  signal data_a                 : std_logic_vector(IN_COUNT_WIDTH + 1 downto 0);
  signal count_a                : std_logic_vector(IN_COUNT_WIDTH - 1 downto 0);
  signal last_a                 : std_logic;
  signal dvalid_a               : std_logic;
  signal valid_a                : std_logic;
  signal ready_a                : std_logic;

  signal data_b                 : std_logic_vector(OUT_COUNT_WIDTH downto 0);
  signal count_b                : std_logic_vector(OUT_COUNT_WIDTH - 1 downto 0);
  signal last_b                 : std_logic;
  signal valid_b                : std_logic;
  signal ready_b                : std_logic;

begin

  prod_a: StreamTbProd
    generic map (
      DATA_WIDTH                => IN_COUNT_WIDTH + 2,
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

  count_a  <= data_a(IN_COUNT_WIDTH - 1 downto 0);
  dvalid_a <= data_a(IN_COUNT_WIDTH);
  last_a   <= data_a(IN_COUNT_WIDTH + 1);

  uut: StreamElementCounter
    generic map (
      IN_COUNT_WIDTH            => IN_COUNT_WIDTH,
      IN_COUNT_MAX              => IN_COUNT_MAX,
      OUT_COUNT_WIDTH           => OUT_COUNT_WIDTH,
      OUT_COUNT_MAX             => OUT_COUNT_MAX
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_a,
      in_ready                  => ready_a,
      in_last                   => last_a,
      in_count                  => count_a,
      in_dvalid                 => dvalid_a,
      out_valid                 => valid_b,
      out_ready                 => ready_b,
      out_count                 => count_b,
      out_last                  => last_b
    );

  data_b(OUT_COUNT_WIDTH - 1 downto 0) <= count_b;
  data_b(OUT_COUNT_WIDTH) <= last_b;

  cons_d: StreamTbCons
    generic map (
      DATA_WIDTH                => OUT_COUNT_WIDTH + 1,
      SEED                      => 1,
      NAME                      => "b"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_b,
      in_ready                  => ready_b,
      in_data                   => data_b
    );

end TestBench;

