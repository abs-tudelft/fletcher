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
use work.Utils.all;
use work.SimUtils.all;

entity StreamMaximizer_tb is
end StreamMaximizer_tb;

architecture Behavioral of StreamMaximizer_tb is

  constant ELEMENT_WIDTH        : natural := 4;
  constant COUNT_MAX            : natural := 4;
  constant COUNT_WIDTH          : natural := 2;

  signal clk                    : std_logic := '1';
  signal reset                  : std_logic;

  signal in_valid               : std_logic;
  signal in_ready               : std_logic;
  signal in_dvalid              : std_logic;
  signal in_data                : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal in_count               : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal in_last                : std_logic;

  signal out_valid              : std_logic;
  signal out_ready              : std_logic;
  signal out_data               : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal out_count              : std_logic_vector(COUNT_WIDTH-1 downto 0);
  signal out_last               : std_logic;

  signal clock_stop             : boolean := false;
begin

  clk_proc: process is
  begin
    if not clock_stop then
      clk <= '1';
      wait for 2 ns;
      clk <= '0';
      wait for 2 ns;
    else
      wait;
    end if;
  end process;

  reset_proc: process is
  begin
    reset <= '1';
    wait for 10 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait;
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
    variable data               : unsigned(ELEMENT_WIDTH-1 downto 0) := (others => '0');
    variable count              : natural;
  begin
      
    loop
      -- Randomize last signal.
      uniform(seed1, seed2, rand);
      last := rand < 0.05;
      if last then
        in_last <= '1';
      else
        in_last <= '0';
      end if;

      -- Randomize count.
      uniform(seed1, seed2, rand);
      count := work.Utils.min(COUNT_MAX, integer(floor(rand * real(COUNT_MAX))));
      if count = 0 then
        in_dvalid <= '0';
      else
        in_dvalid <= '1';
      end if;
      in_count <= std_logic_vector(to_unsigned(count, COUNT_WIDTH));
      
      -- Write data.
      for i in 0 to count-1 loop
        in_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) <= std_logic_vector(data);
        data := (data + 1);
      end loop;
      for i in count to COUNT_MAX-1 loop
        in_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) <= (others => 'U');
      end loop;
      
      -- Wait for acknowledgement.
      loop
        wait until rising_edge(clk);
        next when in_valid = '0';
        next when in_ready = '0';
        next when reset = '1';
        exit;
      end loop;

    end loop;
    
    wait;
  end process;
  
  uut: entity work.StreamMaximizer
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH
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
      out_valid                 => out_valid,
      out_ready                 => out_ready,
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
  
  check_proc: process is
    variable data               : unsigned(ELEMENT_WIDTH-1 downto 0) := (others => '0');
    variable count              : integer;
  begin

    loop
      loop
        wait until rising_edge(clk);
        next when out_valid = '0';
        next when out_ready = '0';
        next when reset = '1';
        exit;
      end loop;

      -- Figure out the count as an integer.
      count := to_integer(unsigned(resize_count(out_count, COUNT_WIDTH+1)));
      
      dumpStdOut("Out count: " & ii(count));
      
      -- Check count to be count max
      assert (count = COUNT_MAX and out_last = '0') or out_last = '1'
        report "Count is not COUNT_MAX in non-last transfer."
        severity failure;

      -- Check the data.
      for i in 0 to count-1 loop
        assert out_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) = std_logic_vector(data)
          report "Stream data integrity check failed (data not in sequence)" severity failure;
        data := (data + 1);
      end loop;
      
    end loop;
  end process;

end Behavioral;

