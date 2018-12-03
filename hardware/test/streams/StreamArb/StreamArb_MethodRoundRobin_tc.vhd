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
use work.StreamSim.all;
use work.Utils.all;
use work.SimUtils.all;

--pragma simulation timeout 1 ms

entity StreamArb_MethodRoundRobin_tc is
end StreamArb_MethodRoundRobin_tc;

architecture TestCase of StreamArb_MethodRoundRobin_tc is
  signal clk          : std_logic := '1';
  signal reset        : std_logic;
  signal valid        : std_logic_vector(7 downto 0);
  signal index        : std_logic_vector(2 downto 0);
begin

  clk_proc: process is
  begin
    stream_tb_gen_clock(clk, 10 ns);
    wait;
  end process;

  stimulus: process is
    variable seed1      : positive := 1;
    variable seed2      : positive := 2;
    variable rand       : real;
    variable valid_v    : std_logic_vector(7 downto 0);
    variable j          : natural;
    variable exp_index  : natural;
  begin
    reset <= '1';
    valid <= (others => '0');
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait for 10 us;
    wait until rising_edge(clk);
    valid_v := X"01";
    exp_index := 0;
    for i in 1 to 10000 loop
      valid <= valid_v;
      wait until rising_edge(clk);
      if valid_v /= X"00" then
        for i in 0 to 7 loop
          j := (i + exp_index + 1) mod 8;
          if valid_v(j) = '1' then
            exp_index := j;
            exit;
          end if;
        end loop;
        if std_logic_vector(to_unsigned(exp_index, 3)) /= index then
          stream_tb_fail("received unexpected index from arbiter, got " & sim_uint(index) & ", expected " & integer'image(exp_index));
        end if;
      end if;
      uniform(seed1, seed2, rand);
      if rand < 0.05 then
        valid_v := (others => '0');
      elsif rand < 0.1 then
        valid_v := (others => '1');
      else
        sim_randomVect(seed1, seed2, valid_v);
      end if;
    end loop;
    stream_tb_complete;
    wait;
  end process;

  tb: entity work.StreamArb_Method_tb
    generic map (
      ARB_METHOD  => "ROUND-ROBIN"
    )
    port map (
      clk         => clk,
      reset       => reset,
      valid       => valid,
      index       => index
    );

end TestCase;

