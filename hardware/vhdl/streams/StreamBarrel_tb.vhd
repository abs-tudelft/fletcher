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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.StreamBarrel;
use work.Utils.all;

entity StreamBarrel_tb is
end StreamBarrel_tb;

architecture tb of StreamBarrel_tb is
  constant ELEMENT_WIDTH        : natural := 8;
  constant COUNT_MAX            : natural := 4;
  constant AMOUNT_WIDTH         : natural := 3;
  constant DIRECTION            : string  := "left";
  constant OPERATION            : string  := "shift";
  constant CTRL_WIDTH           : natural := 1;

  signal clk                    : std_logic;
  signal reset                  : std_logic;
  signal in_valid               : std_logic;
  signal in_ready               : std_logic;
  signal in_rotate              : std_logic_vector(AMOUNT_WIDTH-1 downto 0);
  signal in_data                : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal in_ctrl                : std_logic_vector(CTRL_WIDTH-1 downto 0);
  signal out_valid              : std_logic;
  signal out_ready              : std_logic;
  signal out_data               : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal out_ctrl               : std_logic_vector(CTRL_WIDTH-1 downto 0);
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
    wait;
  end process;

  out_ready <= '1';

  input_proc: process is
    variable x : integer := 0;
  begin

    in_valid <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    loop
      for i in 0 to COUNT_MAX-1 loop
        in_data((i+1)*ELEMENT_WIDTH-1 downto i * ELEMENT_WIDTH) <= std_logic_vector(to_unsigned(i, ELEMENT_WIDTH));
      end loop;

      in_rotate <= std_logic_vector(to_unsigned(x mod COUNT_MAX, AMOUNT_WIDTH));
      in_ctrl <= "0";
      in_valid <= '1';

      loop
        wait until rising_edge(clk);
        exit when in_ready = '1';
      end loop;

      x := x + 1;

    end loop;
  end process;

  uut: entity StreamBarrel
    generic map (
      ELEMENT_WIDTH   => ELEMENT_WIDTH,
      COUNT_MAX       => COUNT_MAX,
      AMOUNT_WIDTH    => AMOUNT_WIDTH,
      DIRECTION       => DIRECTION,
      OPERATION       => OPERATION,
      CTRL_WIDTH      => CTRL_WIDTH
    )
    port map (
      clk             => clk,
      reset           => reset,
      in_valid        => in_valid,
      in_ready        => in_ready,
      in_rotate       => in_rotate,
      in_data         => in_data,
      in_ctrl         => in_ctrl,
      out_valid       => out_valid,
      out_ready       => out_ready,
      out_data        => out_data,
      out_ctrl        => out_ctrl
    );

end tb;
