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

entity StreamReshaper_tb is
  generic (
    IN_COUNT_MAX                : natural;
    OUT_COUNT_MAX               : natural;
    SHIFTS_PER_STAGE            : natural
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic;
    error_strobe                : out std_logic
  );
end StreamReshaper_tb;

architecture TestBench of StreamReshaper_tb is

  signal din_valid              : std_logic;
  signal din_ready              : std_logic;
  signal din_dvalid             : std_logic;
  signal din_data               : std_logic_vector(IN_COUNT_MAX*8-1 downto 0);
  signal din_count              : std_logic_vector(7 downto 0);
  signal din_last               : std_logic;
  signal din_concat             : std_logic_vector(IN_COUNT_MAX*8+9 downto 0);

  signal cin_valid              : std_logic;
  signal cin_ready              : std_logic;
  signal cin_dvalid             : std_logic;
  signal cin_count              : std_logic_vector(7 downto 0);
  signal cin_last               : std_logic;
  signal cin_ctrl               : std_logic_vector(7 downto 0);
  signal cin_concat             : std_logic_vector(17 downto 0);

  signal out_valid              : std_logic;
  signal out_ready              : std_logic;
  signal out_dvalid             : std_logic;
  signal out_data               : std_logic_vector(OUT_COUNT_MAX*8-1 downto 0);
  signal out_count              : std_logic_vector(7 downto 0);
  signal out_last               : std_logic;
  signal out_ctrl               : std_logic_vector(7 downto 0);
  signal out_concat             : std_logic_vector(OUT_COUNT_MAX*8+17 downto 0);

begin

  din_prod: StreamTbProd
    generic map (
      DATA_WIDTH                => din_concat'length,
      SEED                      => 1,
      NAME                      => "din"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => din_valid,
      out_ready                 => din_ready,
      out_data                  => din_concat
    );

  din_last   <= din_concat(IN_COUNT_MAX*8+9);
  din_dvalid <= din_concat(IN_COUNT_MAX*8+8);
  din_data   <= din_concat(IN_COUNT_MAX*8+7 downto 8);
  din_count  <= din_concat(7 downto 0);

  cin_prod: StreamTbProd
    generic map (
      DATA_WIDTH                => cin_concat'length,
      SEED                      => 1,
      NAME                      => "cin"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => cin_valid,
      out_ready                 => cin_ready,
      out_data                  => cin_concat
    );

  cin_last   <= cin_concat(17);
  cin_dvalid <= cin_concat(16);
  cin_ctrl   <= cin_concat(15 downto 8);
  cin_count  <= cin_concat(7 downto 0);

  uut: StreamReshaper
    generic map (
      ELEMENT_WIDTH             => 8,
      IN_COUNT_MAX              => IN_COUNT_MAX,
      IN_COUNT_WIDTH            => 8,
      OUT_COUNT_MAX             => OUT_COUNT_MAX,
      OUT_COUNT_WIDTH           => 8,
      CTRL_WIDTH                => 8,
      SHIFTS_PER_STAGE          => SHIFTS_PER_STAGE
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      din_valid                 => din_valid,
      din_ready                 => din_ready,
      din_dvalid                => din_dvalid,
      din_data                  => din_data,
      din_count                 => din_count,
      din_last                  => din_last,
      cin_valid                 => cin_valid,
      cin_ready                 => cin_ready,
      cin_dvalid                => cin_dvalid,
      cin_count                 => cin_count,
      cin_last                  => cin_last,
      cin_ctrl                  => cin_ctrl,
      error_strobe              => error_strobe,
      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_dvalid                => out_dvalid,
      out_data                  => out_data,
      out_count                 => out_count,
      out_last                  => out_last,
      out_ctrl                  => out_ctrl
    );

  out_concat(OUT_COUNT_MAX*8+17)           <= out_last;
  out_concat(OUT_COUNT_MAX*8+16)           <= out_dvalid;
  out_concat(OUT_COUNT_MAX*8+15 downto 16) <= out_data;
  out_concat(15 downto 8)                  <= out_ctrl;
  out_concat(7 downto 0)                   <= out_count;

  out_cons: StreamTbCons
    generic map (
      DATA_WIDTH                => out_concat'length,
      SEED                      => 2,
      NAME                      => "out"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => out_valid,
      in_ready                  => out_ready,
      in_data                   => out_concat
    );

end TestBench;

