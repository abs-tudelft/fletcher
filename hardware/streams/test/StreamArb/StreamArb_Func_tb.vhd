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

entity StreamArb_Func_tb is
  generic (
    ARB_METHOD                  : string
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic
  );
end StreamArb_Func_tb;

architecture TestBench of StreamArb_Func_tb is

  signal data_a                 : std_logic_vector(7 downto 0);
  signal last_a                 : std_logic;
  signal valid_a                : std_logic;
  signal ready_a                : std_logic;

  signal data_b                 : std_logic_vector(7 downto 0);
  signal last_b                 : std_logic;
  signal valid_b                : std_logic;
  signal ready_b                : std_logic;

  signal data_c                 : std_logic_vector(7 downto 0);
  signal last_c                 : std_logic;
  signal valid_c                : std_logic;
  signal ready_c                : std_logic;

  signal data_d                 : std_logic_vector(7 downto 0);
  signal last_d                 : std_logic;
  signal index_d                : std_logic_vector(1 downto 0);
  signal valid_d                : std_logic;
  signal ready_d                : std_logic;

  signal enable_e               : std_logic;
  signal data_e                 : std_logic_vector(7 downto 0);
  signal valid_e                : std_logic;
  signal ready_e                : std_logic;

  signal enable_f               : std_logic;
  signal data_f                 : std_logic_vector(7 downto 0);
  signal valid_f                : std_logic;
  signal ready_f                : std_logic;

  signal enable_g               : std_logic;
  signal data_g                 : std_logic_vector(7 downto 0);
  signal valid_g                : std_logic;
  signal ready_g                : std_logic;

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

  prod_b: StreamTbProd
    generic map (
      DATA_WIDTH                => 8,
      SEED                      => 2,
      NAME                      => "b"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => valid_b,
      out_ready                 => ready_b,
      out_data                  => data_b
    );

  prod_c: StreamTbProd
    generic map (
      DATA_WIDTH                => 8,
      SEED                      => 3,
      NAME                      => "c"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => valid_c,
      out_ready                 => ready_c,
      out_data                  => data_c
    );

  -- Note: a decimal (.) should be marked as last. Decimal is binary 00101110.
  last_a <= data_a(2) and data_a(1) and not data_a(0);
  last_b <= data_b(2) and data_b(1) and not data_b(0);
  last_c <= data_c(2) and data_c(1) and not data_c(0);

  uut: StreamArb
    generic map (
      NUM_INPUTS                => 3,
      INDEX_WIDTH               => 2,
      DATA_WIDTH                => 8,
      ARB_METHOD                => ARB_METHOD
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid(2)               => valid_c,
      in_valid(1)               => valid_b,
      in_valid(0)               => valid_a,
      in_ready(2)               => ready_c,
      in_ready(1)               => ready_b,
      in_ready(0)               => ready_a,
      in_data(23 downto 16)     => data_c,
      in_data(15 downto 8)      => data_b,
      in_data(7 downto 0)       => data_a,
      in_last(2)                => last_c,
      in_last(1)                => last_b,
      in_last(0)                => last_a,
      out_valid                 => valid_d,
      out_ready                 => ready_d,
      out_data                  => data_d,
      out_last                  => last_d,
      out_index                 => index_d
    );

  mon_d: StreamTbMon
    generic map (
      DATA_WIDTH                => 3,
      NAME                      => "d"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_d,
      in_ready                  => ready_d,
      in_data(2)                => last_d,
      in_data(1 downto 0)       => index_d
    );

  split: StreamSync
    generic map (
      NUM_INPUTS                => 1,
      NUM_OUTPUTS               => 3
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid(0)               => valid_d,
      in_ready(0)               => ready_d,
      out_valid(2)              => valid_g,
      out_valid(1)              => valid_f,
      out_valid(0)              => valid_e,
      out_ready(2)              => ready_g,
      out_ready(1)              => ready_f,
      out_ready(0)              => ready_e,
      out_enable(2)             => enable_g,
      out_enable(1)             => enable_f,
      out_enable(0)             => enable_e
    );

  enable_e <= '1' when index_d = "00" else '0';
  enable_f <= '1' when index_d = "01" else '0';
  enable_g <= '1' when index_d = "10" else '0';
  data_e <= data_d;
  data_f <= data_d;
  data_g <= data_d;

  cons_e: StreamTbCons
    generic map (
      DATA_WIDTH                => 8,
      SEED                      => 4,
      NAME                      => "e"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_e,
      in_ready                  => ready_e,
      in_data                   => data_e
    );

  cons_f: StreamTbCons
    generic map (
      DATA_WIDTH                => 8,
      SEED                      => 5,
      NAME                      => "f"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_f,
      in_ready                  => ready_f,
      in_data                   => data_f
    );

  cons_g: StreamTbCons
    generic map (
      DATA_WIDTH                => 8,
      SEED                      => 6,
      NAME                      => "g"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_g,
      in_ready                  => ready_g,
      in_data                   => data_g
    );

end TestBench;

