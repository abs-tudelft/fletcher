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

entity sum is
  generic(
    TAG_WIDTH                                  : natural;
    BUS_ADDR_WIDTH                             : natural;
    INDEX_WIDTH                                : natural;
    REG_WIDTH                                  : natural
  );
  port(
    weight_unlock_valid                        : in std_logic;
    weight_unlock_tag                          : in std_logic_vector(TAG_WIDTH-1 downto 0);
    weight_unlock_ready                        : out std_logic := '1';
    weight_cmd_weight_values_addr              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    weight_cmd_tag                             : out std_logic_vector(TAG_WIDTH-1 downto 0);
    weight_cmd_lastIdx                         : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    weight_cmd_firstIdx                        : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    weight_cmd_ready                           : in std_logic;
    weight_cmd_valid                           : out std_logic;
    weight_out_data                            : in std_logic_vector(63 downto 0);
    weight_out_valid                           : in std_logic;
    weight_out_ready                           : out std_logic;
    weight_out_last                            : in std_logic;
    -------------------------------------------------------------------------
    acc_reset                                  : in std_logic;
    acc_clk                                    : in std_logic;
    -------------------------------------------------------------------------
    ctrl_done                                  : out std_logic;
    ctrl_busy                                  : out std_logic;
    ctrl_idle                                  : out std_logic;
    ctrl_reset                                 : in std_logic;
    ctrl_stop                                  : in std_logic;
    ctrl_start                                 : in std_logic;
    -------------------------------------------------------------------------
    idx_first                                  : in std_logic_vector(REG_WIDTH-1 downto 0);
    idx_last                                   : in std_logic_vector(REG_WIDTH-1 downto 0);
    reg_return0                                : out std_logic_vector(REG_WIDTH-1 downto 0);
    reg_return1                                : out std_logic_vector(REG_WIDTH-1 downto 0);
    -------------------------------------------------------------------------
    reg_weight_values_addr                     : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)
  );
end entity sum;


architecture rtl of sum is

  type haf_state_t IS (RESET, WAITING, SETUP, RUNNING, DONE);
	signal state, state_next : haf_state_t;

  -- Accumulate the total sum here
  signal accumulator, accumulator_next : signed(2*REG_WIDTH-1 downto 0);

begin

  -- Module output is the accumulator value
  reg_return0 <= std_logic_vector(accumulator(1*REG_WIDTH-1 downto 0*REG_WIDTH));
  reg_return1 <= std_logic_vector(accumulator(2*REG_WIDTH-1 downto 1*REG_WIDTH));

  -- Provide base address to ArrayReader
  weight_cmd_weight_values_addr <= reg_weight_values_addr;
  weight_cmd_tag <= (others => '0');

  -- Set the first and last index on our array
  weight_cmd_firstIdx <= idx_first;
  weight_cmd_lastIdx  <= idx_last;

  logic_p: process (state, ctrl_start, accumulator,
    weight_cmd_ready, weight_out_valid, weight_out_data, weight_out_last)
  begin
    -- Default values
    -- No command to ArrayReader
    weight_cmd_valid <= '0';
    -- Do not accept values from the ArrayReader
    weight_out_ready <= '0';
    -- Retain accumulator value
    accumulator_next <= accumulator;
    -- Stay in same state
    state_next <= state;

    case state is
      when RESET =>
        ctrl_done <= '0';
        ctrl_busy <= '0';
        ctrl_idle <= '0';
        state_next <= WAITING;
        -- Start sum at 0
        accumulator_next <= (others => '0');

      when WAITING =>
        ctrl_done <= '0';
        ctrl_busy <= '0';
        ctrl_idle <= '1';
        -- Wait for start signal from UserCore (initiated by software)
        if ctrl_start = '1' then
          state_next <= SETUP;
        end if;

      when SETUP =>
        ctrl_done <= '0';
        ctrl_busy <= '1';
        ctrl_idle <= '0';
        -- Send address and row indices to the ArrayReader
        weight_cmd_valid <= '1';
        if weight_cmd_ready = '1' then
          -- ArrayReader has received the command
          state_next <= RUNNING;
        end if;

      when RUNNING =>
        ctrl_done <= '0';
        ctrl_busy <= '1';
        ctrl_idle <= '0';
        -- Always ready to accept input
        weight_out_ready <= '1';
        if weight_out_valid = '1' then
          -- Sum the record to the accumulator
          accumulator_next <= accumulator + signed(weight_out_data);
          -- Wait for last element from ArrayReader
          if weight_out_last = '1' then
            state_next <= DONE;
          end if;
        end if;

      when DONE =>
        ctrl_done <= '1';
        ctrl_busy <= '0';
        ctrl_idle <= '1';

      when others =>
        ctrl_done <= '0';
        ctrl_busy <= '0';
        ctrl_idle <= '0';
    end case;
  end process;


  state_p: process (acc_clk)
  begin
    -- Control state machine
    if rising_edge(acc_clk) then
      if acc_reset = '1' or ctrl_reset = '1' then
        state <= RESET;
        accumulator <= (others => '0');
      else
        state <= state_next;
        accumulator <= accumulator_next;
      end if;
    end if;
  end process;

end architecture;

