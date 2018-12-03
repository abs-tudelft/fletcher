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
use IEEE.numeric_std.all;

library work;

entity axi_funnel is
    generic(
      SLAVES          : natural;
      DATA_WIDTH      : natural
    );
    port(
      reset           : in  std_logic;
      clk             : in  std_logic;
      -------------------------------------------------------------------------
      in_data         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      in_valid        : in  std_logic;
      in_ready        : out std_logic;
      in_last         : in  std_logic;
      out_data        : out std_logic_vector(DATA_WIDTH-1 downto 0);
      out_valid       : out std_logic_vector(SLAVES-1 downto 0);
      out_ready       : in  std_logic_vector(SLAVES-1 downto 0);
      out_last        : out std_logic_vector(SLAVES-1 downto 0)
    );
end entity axi_funnel;


architecture behavior of axi_funnel is

  type axi_state_t IS (THROUGH, WAIT_CONFIRM);
	signal state, state_next : axi_state_t;
  signal slave_read, slave_read_next : std_logic_vector(SLAVES-1 downto 0);

begin
  out_data <= in_data;
  out_last <= (others => in_last);

  logic_p: process (state, in_valid, out_ready, slave_read_next, slave_read)
  begin
    case state is
      when THROUGH =>
        slave_read_next <= out_ready;
        out_valid <= (others => in_valid);
        if (unsigned(not out_ready) = 0) then
          -- All slaves ready
          in_ready <= '1';
          state_next <= THROUGH;
        elsif (in_valid = '1') then
          -- Not all slaves ready, and input data is valid
          in_ready <= '0';
          state_next <= WAIT_CONFIRM;
        else
          -- Not all slaves ready, but also no valid input data
          in_ready <= '0';
          state_next <= THROUGH;
        end if;

      when WAIT_CONFIRM =>
        slave_read_next <= slave_read or out_ready;
        out_valid <= not slave_read;
        if (unsigned(not slave_read_next) = 0) then
          in_ready <= '1';
          state_next <= THROUGH;
        else
          in_ready <= '0';
          state_next <= WAIT_CONFIRM;
        end if;
    end case;
  end process;

  state_p: process (clk)
  begin
    if (rising_edge(clk)) then
      slave_read <= slave_read_next;
      if (reset = '1') then
        state <= THROUGH;
      else
        state <= state_next;
      end if;
    end if;
  end process;

end architecture;

