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

entity StreamSync_tb is
  generic (
    DATA_WIDTH                  : natural := 4
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic
  );
end StreamSync_tb;

architecture TestBench of StreamSync_tb is

  signal valid_a                : std_logic;
  signal ready_a                : std_logic;
  signal data_a                 : std_logic_vector(DATA_WIDTH-1 downto 0);

  signal valid_b                : std_logic;
  signal ready_b                : std_logic;
  signal data_b                 : std_logic_vector(DATA_WIDTH-1 downto 0);

  signal valid_c                : std_logic;
  signal ready_c                : std_logic;
  signal data_c                 : std_logic_vector(DATA_WIDTH*2-1 downto 0);
  signal monitor_c              : std_logic_vector(DATA_WIDTH*2-1 downto 0);

  signal valid_d                : std_logic;
  signal ready_d                : std_logic;
  signal data_d                 : std_logic_vector(DATA_WIDTH*2-1 downto 0);
  signal monitor_d              : std_logic_vector(DATA_WIDTH*2-1 downto 0);

begin

  prod_a: StreamTbProd
    generic map (
      DATA_WIDTH                => DATA_WIDTH,
      SEED                      => 1
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
      DATA_WIDTH                => DATA_WIDTH,
      SEED                      => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => valid_b,
      out_ready                 => ready_b,
      out_data                  => data_b
    );

  uut: StreamSync
    generic map (
      NUM_INPUTS                => 2,
      NUM_OUTPUTS               => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid(1)               => valid_a,
      in_valid(0)               => valid_b,
      in_ready(1)               => ready_a,
      in_ready(0)               => ready_b,
      in_advance(1)             => data_b(1),
      in_advance(0)             => '1',
      out_valid(1)              => valid_c,
      out_valid(0)              => valid_d,
      out_ready(1)              => ready_c,
      out_ready(0)              => ready_d,
      out_enable(1)             => data_a(2),
      out_enable(0)             => '1'
    );

  data_c <= data_a & data_b;
  data_d <= data_a & data_b;

  cons_c: StreamTbCons
    generic map (
      DATA_WIDTH                => DATA_WIDTH*2,
      SEED                      => 3
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_c,
      in_ready                  => ready_c,
      in_data                   => data_c,
      monitor                   => monitor_c
    );

  check_c: process is
    variable data               : unsigned(3 downto 0);
    variable check              : std_logic_vector(7 downto 0);
  begin
    data := (others => '0');
    loop
      wait until rising_edge(clk);
      exit when reset = '1';
      next when monitor_c(0) = 'Z';

      check := (
        7 => data(3),
        6 => '1',
        5 => data(2),
        4 => data(0) and data(1),
        3 => '1',
        2 => data(2),
        1 => data(1),
        0 => data(0)
      );

      if monitor_c /= check then
        stream_tb_fail("got unexpected data on stream c");
      end if;
      data := data + 1;

    end loop;
  end process;

  cons_d: StreamTbCons
    generic map (
      DATA_WIDTH                => DATA_WIDTH*2,
      SEED                      => 4
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_d,
      in_ready                  => ready_d,
      in_data                   => data_d,
      monitor                   => monitor_d
    );

  check_d: process is
    variable data               : unsigned(4 downto 0);
    variable check              : std_logic_vector(7 downto 0);
  begin
    data := (others => '0');
    loop
      wait until rising_edge(clk);
      exit when reset = '1';
      next when monitor_d(0) = 'Z';

      check := (
        7 => data(4),
        6 => data(3),
        5 => data(2),
        4 => data(0) and data(1),
        3 => data(3),
        2 => data(2),
        1 => data(1),
        0 => data(0)
      );

      if monitor_d /= check then
        stream_tb_fail("got unexpected data on stream d");
      end if;
      data := data + 1;

    end loop;
  end process;

end TestBench;

