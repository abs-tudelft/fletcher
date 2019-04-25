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

entity StreamArb_Method_tb is
  generic (
    ARB_METHOD                  : string
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic;
    valid                       : in  std_logic_vector(7 downto 0);
    index                       : out std_logic_vector(2 downto 0)
  );
end StreamArb_Method_tb;

architecture TestBench of StreamArb_Method_tb is
begin

  uut: StreamArb
    generic map (
      NUM_INPUTS                => 8,
      INDEX_WIDTH               => 3,
      DATA_WIDTH                => 1,
      ARB_METHOD                => ARB_METHOD
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid,
      in_data                   => (others => '0'),
      out_ready                 => '1',
      out_index                 => index
    );

end TestBench;

