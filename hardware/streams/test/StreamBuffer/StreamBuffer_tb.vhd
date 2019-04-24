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
use work.StreamSim.all;

entity StreamBuffer_tb is
  generic (
    MIN_DEPTH                   : natural
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic
  );
end StreamBuffer_tb;

architecture TestBench of StreamBuffer_tb is

  constant DATA_WIDTH           : natural := 8;

  signal valid_a                : std_logic;
  signal ready_a                : std_logic;
  signal data_a                 : std_logic_vector(DATA_WIDTH-1 downto 0);

  signal valid_b                : std_logic;
  signal ready_b                : std_logic;
  signal data_b                 : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  prod_a: StreamTbProd
    generic map (
      DATA_WIDTH                => DATA_WIDTH,
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

  uut: StreamBuffer
    generic map (
      MIN_DEPTH                 => MIN_DEPTH,
      DATA_WIDTH                => DATA_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_a,
      in_ready                  => ready_a,
      in_data                   => data_a,
      out_valid                 => valid_b,
      out_ready                 => ready_b,
      out_data                  => data_b
    );

  cons_b: StreamTbCons
    generic map (
      DATA_WIDTH                => DATA_WIDTH,
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

