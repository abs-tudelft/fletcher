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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.Utils.all;
use work.Streams.all;
use work.StreamSim.all;

entity StreamPrefixSum_tb is
  generic (
    DATA_WIDTH           : natural := 8;
    COUNT_MAX            : natural := 4
  );
  port (
    signal clk  : in std_logic;  
    signal reset : in std_logic
  );
end StreamPrefixSum_tb;

architecture TestBench of StreamPrefixSum_tb is
  signal valid_a                : std_logic;
  signal ready_a                : std_logic;
  signal data_a                 : std_logic_vector(COUNT_MAX*DATA_WIDTH-1 downto 0);

  signal valid_b                : std_logic;
  signal ready_b                : std_logic;
  signal data_b                 : std_logic_vector(COUNT_MAX*DATA_WIDTH-1 downto 0);
  
begin

  prod_a: StreamTbProd
    generic map (
      DATA_WIDTH                => COUNT_MAX*DATA_WIDTH,
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

  uut: StreamPrefixSum
    generic map (
      DATA_WIDTH                => DATA_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => log2ceil(COUNT_MAX),
      LOOPBACK                  => true,
      INPUT_NORMALIZED          => false
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_initial                => (others => '0'),
      in_valid                  => valid_a,
      in_ready                  => ready_a,
      in_data                   => data_a,
      in_count                  => "10",
      in_last                   => '0',
      out_valid                 => valid_b,
      out_ready                 => ready_b,
      out_data                  => data_b,
      out_count                 => open,
      out_last                  => open
    );

  cons_b: StreamTbCons
    generic map (
      DATA_WIDTH                => COUNT_MAX*DATA_WIDTH,
      SEED                      => 2,
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
