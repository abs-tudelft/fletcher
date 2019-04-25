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
use work.Utils.all;

entity StreamNormalizer_tb is
  generic (
    ELEMENT_WIDTH               : natural := 4;
    COUNT_MAX                   : natural := 4;
    COUNT_WIDTH                 : natural := 2;
    REQ_COUNT_WIDTH             : natural := 3
  );
end StreamNormalizer_tb;

architecture TestBench of StreamNormalizer_tb is

  signal clk                    : std_logic := '1';
  signal reset                  : std_logic;

  signal in_valid               : std_logic;
  signal in_ready               : std_logic;
  signal in_dvalid              : std_logic;
  signal in_data                : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal in_count               : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal in_last                : std_logic;

  signal req_count              : std_logic_vector(REQ_COUNT_WIDTH-1 downto 0);

  signal out_valid              : std_logic;
  signal out_ready              : std_logic;
  signal out_dvalid             : std_logic;
  signal out_data               : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal out_count              : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal out_last               : std_logic;

  signal out_dvalid_mon         : std_logic;
  signal out_data_mon           : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal out_count_mon          : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal out_last_mon           : std_logic;

begin

  clk_proc: process is
  begin
    stream_tb_gen_clock(clk, 10 ns);
    wait;
  end process;

  reset_proc: process is
  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait for 100 us;
    wait until rising_edge(clk);
    wait for 3 ms;
    stream_tb_complete;
  end process;

  prod_handshake_inst: StreamTbProd
    generic map (
      DATA_WIDTH                => 1,
      SEED                      => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => in_valid,
      out_ready                 => in_ready
    );

  prod_data_proc: process is
    variable seed1              : positive := 1;
    variable seed2              : positive := 1;
    variable rand               : real;
    variable last               : boolean;
    variable data               : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable count              : natural;
  begin
    data := (others => '0');

    state: loop

      -- Randomize last signal.
      uniform(seed1, seed2, rand);
      last := rand > 0.8;
      if last then
        in_last <= '1';
      else
        in_last <= '0';
      end if;

      -- Randomize count.
      uniform(seed1, seed2, rand);
      if last then
        count := integer(floor(rand * real(COUNT_MAX + 1)));
      else
        count := COUNT_MAX;
      end if;
      if count = 0 then
        in_dvalid <= '0';
      else
        in_dvalid <= '1';
      end if;
      in_count <= std_logic_vector(to_unsigned(count mod 2**COUNT_WIDTH, COUNT_WIDTH));

      -- Write data.
      for i in 0 to count-1 loop
        in_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) <= std_logic_vector(data);
        data := data + 1;
      end loop;
      for i in count to COUNT_MAX-1 loop
        in_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) <= (others => 'U');
      end loop;

      -- Wait for acknowledgement.
      loop
        wait until rising_edge(clk);
        exit state when reset = '1';
        next when in_valid = '0';
        next when in_ready = '0';
        exit;
      end loop;

    end loop;
  end process;

  req_count_proc: process is
    variable seed1              : positive := 3;
    variable seed2              : positive := 1;
    variable rand               : real;
  begin
    loop

      -- Randomize last signal.
      uniform(seed1, seed2, rand);
      req_count <= std_logic_vector(to_unsigned(
        work.Utils.min(
          COUNT_MAX,
          integer(floor(rand * real(COUNT_MAX * 5)))
        ), REQ_COUNT_WIDTH));

      -- Wait for acknowledgement.
      loop
        wait until rising_edge(clk);
        next when out_valid = '0';
        next when out_ready = '0';
        exit;
      end loop;

    end loop;
  end process;

  uut: entity work.StreamNormalizer
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH,
      REQ_COUNT_WIDTH           => REQ_COUNT_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_dvalid                 => in_dvalid,
      in_data                   => in_data,
      in_count                  => in_count,
      in_last                   => in_last,
      req_count                 => req_count,
      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_dvalid                => out_dvalid,
      out_data                  => out_data,
      out_count                 => out_count,
      out_last                  => out_last
    );

  cons_data_inst: StreamTbCons
    generic map (
      DATA_WIDTH                => 1,
      SEED                      => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => out_valid,
      in_ready                  => out_ready,
      in_data                   => "0"
    );

  out_dvalid_mon <= out_dvalid when out_valid = '1' and out_ready = '1' else 'Z';
  out_data_mon   <= out_data   when out_valid = '1' and out_ready = '1' else (others => 'Z');
  out_count_mon  <= out_count  when out_valid = '1' and out_ready = '1' else (others => 'Z');
  out_last_mon   <= out_last   when out_valid = '1' and out_ready = '1' else 'Z';

  check_proc: process is
    variable data               : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable count              : integer;
  begin
    data := (others => '0');
    loop
      wait until rising_edge(clk);
      exit when reset = '1';
      next when out_last_mon = 'Z';

      -- Figure out the count as an integer.
      if out_dvalid = '1' then
        count := to_integer(unsigned(resize_count(out_count, COUNT_WIDTH+1)));
      else
        count := 0;
      end if;

      -- Check the data.
      for i in 0 to count-1 loop
        if out_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) /= std_logic_vector(data) then
          stream_tb_fail("Stream data integrity check failed (data not in sequence)");
        end if;
        data := data + 1;
      end loop;

      -- Check the count. It must equal the requested count if last = '0', and
      -- must be less than or equal to the requested count if last = '1'.
      if out_last = '1' then
        if count > to_integer(unsigned(req_count)) then
          stream_tb_fail("stream data integrity check failed (too many elements returned)");
        end if;
      else
        if count /= to_integer(unsigned(req_count)) then
          stream_tb_fail("stream data integrity check failed (incorrect amount of elements returned)");
        end if;
      end if;

    end loop;
  end process;

end TestBench;

