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

entity StreamReshaper_Random_tv is
  generic (
    IN_COUNT_MAX                : natural;
    OUT_COUNT_MAX               : natural
  );
  port (
    clk                         : inout std_logic;
    reset                       : inout std_logic;
    error_strobe                : in    std_logic
  );
end StreamReshaper_Random_tv;

architecture TestVector of StreamReshaper_Random_tv is

  signal error_strobe_count     : natural := 0;

begin

  clk_proc: process is
  begin
    stream_tb_gen_clock(clk, 10 ns);
    wait;
  end process;

  stimulus: process is
    variable seed1              : positive := 1;
    variable seed2              : positive := 1;
    variable rand               : real;

    variable send_data_counter  : std_logic_vector(7 downto 0) := (others => '0');
    variable send_ctrl_counter  : std_logic_vector(7 downto 0) := (others => '0');
    variable expect_data_counter: std_logic_vector(7 downto 0) := (others => '0');
    variable expected_errors    : natural := 0;

    procedure send_data(count: natural; last: std_logic) is
      variable count_slv        : std_logic_vector(7 downto 0);
      variable data_slv         : std_logic_vector(IN_COUNT_MAX*8 - 1 downto 0);
      variable ctrl_slv         : std_logic_vector(1 downto 0);
    begin
      data_slv := (others => 'U');
      count_slv := (others => 'U');
      ctrl_slv(1) := last;
      if count = 0 then
        ctrl_slv(0) := '0';
      else
        ctrl_slv(0) := '1';
        count_slv := std_logic_vector(to_unsigned(count, 8));
      end if;
      for i in 1 to count loop
        data_slv(i*8-1 downto i*8-8) := send_data_counter;
        send_data_counter := std_logic_vector(unsigned(send_data_counter) + 1);
      end loop;
      stream_tb_push("din", ctrl_slv & data_slv & count_slv);
    end procedure;

    procedure send_ctrl(count: natural; last: std_logic; exp_count: natural; exp_last: std_logic) is
      variable count_slv        : std_logic_vector(7 downto 0);
      variable data_slv         : std_logic_vector(OUT_COUNT_MAX*8 - 1 downto 0);
      variable ctrl_slv         : std_logic_vector(1 downto 0);
    begin
      count_slv := (others => 'U');
      ctrl_slv(1) := last;
      if count = 0 then
        ctrl_slv(0) := '0';
      else
        ctrl_slv(0) := '1';
        count_slv := std_logic_vector(to_unsigned(count, 8));
      end if;
      stream_tb_push("cin", ctrl_slv & send_ctrl_counter & count_slv);

      data_slv := (others => '-');
      count_slv := (others => '-');
      ctrl_slv(1) := exp_last;
      if exp_count = 0 then
        ctrl_slv(0) := '0';
      else
        ctrl_slv(0) := '1';
        count_slv := std_logic_vector(to_unsigned(exp_count, 8));
      end if;
      for i in 1 to exp_count loop
        data_slv(i*8-1 downto i*8-8) := expect_data_counter;
        expect_data_counter := std_logic_vector(unsigned(expect_data_counter) + 1);
      end loop;
      stream_tb_push("exp", ctrl_slv & data_slv & send_ctrl_counter & count_slv);

      send_ctrl_counter := std_logic_vector(unsigned(send_ctrl_counter) + 1);
    end procedure;

    procedure send_packet(length: natural) is
      variable remaining        : integer;
      variable count            : natural;
      variable exp_count        : natural;
      variable last             : std_logic;
      variable exp_last         : std_logic;
    begin
      -- Send the data packet.
      remaining := length;
      loop

        -- Randomize shape.
        uniform(seed1, seed2, rand);
        count := integer(floor(rand * real(IN_COUNT_MAX + 1)));

        -- Constrain shape.
        if count > remaining then
          count := remaining;
        end if;

        remaining := remaining - count;
        if remaining > 0 then
          send_data(count, '0');
        else
          send_data(count, '1');
          exit;
        end if;
      end loop;

      -- Send multiple control packets.
      remaining := length;
      loop

        -- Randomize shape.
        uniform(seed1, seed2, rand);
        count := integer(floor(rand * real(OUT_COUNT_MAX + 1)));
        exp_count := count;
        uniform(seed1, seed2, rand);
        if rand > 0.8 then
          last := '1';
        else
          last := '0';
        end if;
        exp_last := last;

        -- Constrain shape.
        if count >= remaining then
          uniform(seed1, seed2, rand);
          exp_last := '1';
          exp_count := remaining;
          if rand > 0.7 then
            -- Follow along with the data stream.
            last := exp_last;
            count := exp_count;
          elsif (count /= exp_count) or (last /= exp_last) then
            -- Generate an error.
            expected_errors := expected_errors + 1;
          end if;
        end if;

        send_ctrl(count, last, exp_count, exp_last);

        remaining := remaining - exp_count;
        exit when remaining = 0;
      end loop;

    end procedure;

  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait for 50 us;
    wait until rising_edge(clk);

    for i in 1 to 100 loop
      uniform(seed1, seed2, rand);
      send_packet(natural(rand * real(work.utils.max(IN_COUNT_MAX, OUT_COUNT_MAX) * 20)));
    end loop;

    stream_tb_expect_stream("out", "exp", 2 + OUT_COUNT_MAX*8 + 8 + 8, 5 us);

    wait for 10 us;

    stream_tb_complete;
  end process;

end TestVector;

