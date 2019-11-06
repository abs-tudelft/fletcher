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
use ieee.std_logic_misc.all;

library work;
use work.UTF8StringGen_pkg.all;
use work.Stream_pkg.all;
use work.UtilStr_pkg.all;
use work.UtilConv_pkg.all;

entity UTF8StringGen_tc is
end entity;

architecture Behavorial of UTF8StringGen_tc is

  constant INDEX_WIDTH               : natural := 32;
  constant ELEMENT_WIDTH             : natural := 8;
  constant ELEMENT_COUNT_MAX         : natural := 8;
  constant ELEMENT_COUNT_WIDTH       : natural := 4;
  constant LEN_WIDTH                 : natural := 8;
  constant LENGTH_BUFFER_DEPTH       : natural := 8;
  constant LEN_SLICE                 : boolean := true;
  constant UTF8_SLICE                : boolean := true;

  constant NUM_STRINGS               : natural := 1024;

  signal clk                         : std_logic;
  signal reset                       : std_logic;
  signal cmd_valid                   : std_logic;
  signal cmd_ready                   : std_logic;
  signal cmd_len                     : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_strlen_min              : std_logic_vector(LEN_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(0, LEN_WIDTH));
  signal cmd_prng_mask               : std_logic_vector(LEN_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(2**LEN_WIDTH-1, LEN_WIDTH));
  signal len_valid                   : std_logic;
  signal len_ready                   : std_logic;
  signal len_data                    : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal len_last                    : std_logic;
  signal len_dvalid                  : std_logic;
  signal utf8_valid                  : std_logic;
  signal utf8_ready                  : std_logic;
  signal utf8_data                   : std_logic_vector(ELEMENT_COUNT_MAX * ELEMENT_WIDTH-1 downto 0);
  signal utf8_count                  : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal utf8_last                   : std_logic;
  signal utf8_dvalid                 : std_logic;

  signal clock_stop                 : boolean := false;
begin

  clk_proc: process is
  begin
    loop
      clk <= '1';
      wait for 2 ns;
      clk <= '0';
      wait for 2 ns;
      exit when clock_stop;
    end loop;
    wait;
  end process;

  reset_proc: process is
  begin
    reset <= '1';
    wait for 10 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait;
  end process;

  cmd_proc: process is
  begin
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    cmd_len <= std_logic_vector(to_unsigned(NUM_STRINGS, INDEX_WIDTH));
    cmd_valid <= '1';

    loop
      wait until rising_edge(clk);
      exit when cmd_ready = '1';
    end loop;

    cmd_valid <= '0';

    wait;
  end process;

  len_check_proc: process is
  begin
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;
    
    loop
      exit when clock_stop;
      loop
        wait until rising_edge(clk);
        exit when len_ready = '1' and len_valid = '1';
      end loop;

      println(slvToUDec(len_data));
    end loop;
    
  end process;

  utf_check_proc: process is
    variable num_last : integer := 0;
  begin
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop

      loop
        wait until rising_edge(clk);
        exit when utf8_last = '1' and utf8_valid = '1';
      end loop;

      num_last := num_last + 1;

      exit when num_last = NUM_STRINGS;

    end loop;
    wait for 10 ns;
    clock_stop <= true;
    wait;
  end process;

  -- Always ready
  len_ready  <= '1';
  utf8_ready <= '1';

  uut: UTF8StringGen
    generic map (
      INDEX_WIDTH           => INDEX_WIDTH,
      ELEMENT_WIDTH         => ELEMENT_WIDTH,
      ELEMENT_COUNT_MAX     => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH   => ELEMENT_COUNT_WIDTH,
      LEN_WIDTH             => LEN_WIDTH,
      LENGTH_BUFFER_DEPTH   => LENGTH_BUFFER_DEPTH,
      LEN_SLICE             => LEN_SLICE,
      UTF8_SLICE            => UTF8_SLICE
    )
    port map (
      clk                   => clk,
      reset                 => reset,
      cmd_valid             => cmd_valid,
      cmd_ready             => cmd_ready,
      cmd_len               => cmd_len,
      cmd_strlen_min        => cmd_strlen_min,
      cmd_strlen_mask       => cmd_prng_mask,
      len_valid             => len_valid,
      len_ready             => len_ready,
      len_data              => len_data,
      len_last              => len_last,
      len_dvalid            => len_dvalid,
      utf8_valid            => utf8_valid,
      utf8_ready            => utf8_ready,
      utf8_data             => utf8_data,
      utf8_count            => utf8_count,
      utf8_last             => utf8_last,
      utf8_dvalid           => utf8_dvalid
    );

end architecture;
