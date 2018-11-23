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

entity StreamPseudoRandomGenerator_tb is
  generic (
    DATA_WIDTH                  : natural := 8
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic
  );
end StreamPseudoRandomGenerator_tb;

architecture TestBench of StreamPseudoRandomGenerator_tb is

  signal seed                   : std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

  signal out_valid              : std_logic;
  signal out_ready              : std_logic;
  signal out_data               : std_logic_vector(DATA_WIDTH-1 downto 0);

begin

  uut: StreamPseudoRandomGenerator
    generic map (
      DATA_WIDTH                => DATA_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      seed                      => seed,
      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_data                  => out_data
    );

  cons: StreamTbCons
    generic map (
      DATA_WIDTH                => DATA_WIDTH,
      SEED                      => 1,
      NAME                      => "out"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => out_valid,
      in_ready                  => out_ready,
      in_data                   => out_data
    );

end TestBench;

