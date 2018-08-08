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
use work.Columns.all;

entity ColumnReaderListSyncDecoder_tb is
end ColumnReaderListSyncDecoder_tb;

architecture Behavioral of ColumnReaderListSyncDecoder_tb is

  constant LENGTH_WIDTH         : natural := 4;
  constant COUNT_MAX            : natural := 3;
  constant COUNT_WIDTH          : natural := 2;

  signal clk                    : std_logic := '1';
  signal reset                  : std_logic;

  signal inl_valid              : std_logic;
  signal inl_ready              : std_logic;
  signal inl_length             : std_logic_vector(LENGTH_WIDTH-1 downto 0);

  signal ctrl_valid             : std_logic;
  signal ctrl_ready             : std_logic;
  signal ctrl_last              : std_logic;
  signal ctrl_dvalid            : std_logic;
  signal ctrl_count             : std_logic_vector(COUNT_WIDTH-1 downto 0);

  signal ctrl_last_mon          : std_logic;
  signal ctrl_dvalid_mon        : std_logic;
  signal ctrl_count_mon         : std_logic_vector(COUNT_WIDTH-1 downto 0);

begin

  clk_proc: process is
  begin
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;

  reset_proc: process is
  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait for 100 us;
    wait until rising_edge(clk);
  end process;

  prod_len: StreamTbProd
    generic map (
      DATA_WIDTH                => LENGTH_WIDTH,
      SEED                      => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => inl_valid,
      out_ready                 => inl_ready,
      out_data                  => inl_length
    );

  uut: ColumnReaderListSyncDecoder
    generic map (
      LENGTH_WIDTH              => LENGTH_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH,
      LEN_IN_SLICE              => false
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      inl_valid                 => inl_valid,
      inl_ready                 => inl_ready,
      inl_length                => inl_length,
      ctrl_valid                => ctrl_valid,
      ctrl_ready                => ctrl_ready,
      ctrl_last                 => ctrl_last,
      ctrl_dvalid               => ctrl_dvalid,
      ctrl_count                => ctrl_count
    );

  cons_ctrl: StreamTbCons
    generic map (
      DATA_WIDTH                => 1,
      SEED                      => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => ctrl_valid,
      in_ready                  => ctrl_ready,
      in_data                   => "0"
    );

  ctrl_last_mon   <= ctrl_last   when ctrl_valid = '1' and ctrl_ready = '1' else 'Z';
  ctrl_dvalid_mon <= ctrl_dvalid when ctrl_valid = '1' and ctrl_ready = '1' else 'Z';
  ctrl_count_mon  <= ctrl_count  when ctrl_valid = '1' and ctrl_ready = '1' else (others => 'Z');

  check_ctrl: process is
    variable len                : unsigned(LENGTH_WIDTH-1 downto 0);
    variable remain             : integer;
  begin
    len := (others => '0');
    remain := 0;
    loop
      wait until rising_edge(clk);
      exit when reset = '1';
      next when ctrl_last_mon = 'Z';

      if ctrl_dvalid_mon = '1' then
        remain := remain - to_integer(unsigned(resize_count(ctrl_count_mon, COUNT_WIDTH+1)));
      else
        assert ctrl_count_mon = (COUNT_WIDTH-1 downto 0 => '0')
          report "Stream data integrity check failed (count != 0)" severity failure;
      end if;
      if ctrl_last_mon = '1' then
        assert remain = 0
          report "Stream data integrity check failed (remain = " & integer'image(remain) & ")" severity failure;
        len := len + 1;
        remain := to_integer(len);
      else
        assert ctrl_count_mon = std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH))
          report "Stream data integrity check failed (count not max)" severity failure;
      end if;

    end loop;
  end process;

end Behavioral;

