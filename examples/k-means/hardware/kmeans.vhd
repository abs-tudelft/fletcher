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

entity kmeans is
  generic(
    TAG_WIDTH                                  : natural;
    BUS_ADDR_WIDTH                             : natural;
    INDEX_WIDTH                                : natural;
    REG_WIDTH                                  : natural
  );
  port(
    point_out_valid                            : in std_logic;
    point_out_dimension_out_data               : in std_logic_vector(63 downto 0);
    point_out_dimension_out_dvalid             : in std_logic;
    point_out_dimension_out_last               : in std_logic;
    point_out_dimension_out_ready              : out std_logic;
    point_out_dimension_out_valid              : in std_logic;
    point_out_length                           : in std_logic_vector(INDEX_WIDTH-1 downto 0);
    point_out_last                             : in std_logic;
    point_out_ready                            : out std_logic;
    point_cmd_valid                            : out std_logic;
    point_cmd_ready                            : in std_logic;
    point_cmd_firstIdx                         : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    point_cmd_lastIdx                          : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    point_cmd_tag                              : out std_logic_vector(TAG_WIDTH-1 downto 0);
    point_cmd_point_dimension_values_addr      : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    point_cmd_point_offsets_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
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
    reg_point_dimension_values_addr            : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    reg_point_offsets_addr                     : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)
  );
end entity kmeans;


architecture behavior of kmeans is

  type haf_state_t IS (RESET, WAITING, SETUP, RUNNING, DONE);
	signal state, state_next : haf_state_t;

begin

  -- Provide base address to ColumnReader
  point_cmd_point_dimension_values_addr <= reg_point_dimension_values_addr;
  point_cmd_point_offsets_addr <= reg_point_offsets_addr;
  point_cmd_tag <= (others => '0');

  -- Set the first and last index on our column
  point_cmd_firstIdx <= idx_first;
  point_cmd_lastIdx  <= idx_last;

  logic_p: process (state, ctrl_start,
    point_cmd_ready, point_out_valid, point_out_last, point_out_length,
    point_out_dimension_out_data, point_out_dimension_out_dvalid,
    point_out_dimension_out_last, point_out_dimension_out_valid)
  begin
    -- Default values
    -- No command to ColumnReader
    point_cmd_valid <= '0';
    -- Do not accept values from the ColumnReader
    point_out_ready <= '0';
    point_out_dimension_out_ready <= '0';
    -- Stay in same state
    state_next <= state;

    case state is
      when RESET =>
        ctrl_done <= '0';
        ctrl_busy <= '0';
        ctrl_idle <= '0';
        state_next <= WAITING;

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
        -- Send address and row indices to the ColumnReader
        point_cmd_valid <= '1';
        if point_cmd_ready = '1' then
          -- ColumnReader has received the command
          state_next <= RUNNING;
        end if;

      when RUNNING =>
        ctrl_done <= '0';
        ctrl_busy <= '1';
        ctrl_idle <= '0';
        -- Always ready to accept input
        point_out_dimension_out_ready <= '1';
        if point_out_dimension_out_valid = '1' then
          if point_out_dimension_out_last = '1' then
            point_out_ready <= '1';
            -- Exit on last element
            if point_out_last = '1' then
              state_next <= DONE;
            end if;
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
      else
        state <= state_next;
      end if;
    end if;
  end process;

end architecture;

