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

entity UserCoreController is
  generic (
    REG_WIDTH                 : natural := 32
  );
  port (
    kcd_clk                   : in  std_logic;
    kcd_reset                 : in  std_logic;
    bcd_clk                   : in  std_logic;
    bcd_reset                 : in  std_logic;
    status                    : out  std_logic_vector(REG_WIDTH-1 downto 0);
    control                   : in  std_logic_vector(REG_WIDTH-1 downto 0);
    start                     : out std_logic;
    stop                      : out std_logic;
    reset                     : out std_logic;
    idle                      : in  std_logic;
    busy                      : in  std_logic;
    done                      : in  std_logic
  );
end UserCoreController;

architecture Behavioral of UserCoreController is

  constant CONTROL_START : natural := 0;
  constant CONTROL_STOP  : natural := 1;
  constant CONTROL_RESET : natural := 2;
  
  constant STATUS_IDLE : natural := 0;
  constant STATUS_BUSY : natural := 1;
  constant STATUS_DONE : natural := 2;

  type state_type is record
    start         : std_logic;
    start_lowered : std_logic;
    stop          : std_logic;
    reset         : std_logic;
  end record;
  
  constant state_init : state_type := ('0', '1', '0', '0');
  
  signal r : state_type;
  signal d : state_type;
  
begin
  --TODO: implement clock crossings
  ctrl_seq_proc: process(bcd_clk) is
  begin
    if rising_edge(bcd_clk) then
      r <= d;
      if kcd_reset = '1' then
        r <= state_init;
      end if;
    end if;
  end process;
  
  ctrl_comb_proc: process(r, control, idle, busy, done) is
    variable v : state_type;
  begin
      v := r;
      
      ----------------------------------------------------------
      -- Start:
      ----------------------------------------------------------
      -- One cycle start assertion. Host must lower start after
      -- asserting before the usercore can start again.
      if control(CONTROL_START) = '1' and r.start_lowered = '1' then
        v.start := '1';
        v.start_lowered := '0';
      end if;
      if r.start = '1' and r.start_lowered = '0' then
        v.start := '0';
      end if;
      if control(CONTROL_START) = '0' then
        v.start_lowered := '1';
      end if;
      
      ----------------------------------------------------------      
      -- Stop:
      ----------------------------------------------------------
      v.stop := control(CONTROL_STOP);
      
      ----------------------------------------------------------
      -- Reset:
      ----------------------------------------------------------
      v.reset := control(CONTROL_RESET);
      
      ----------------------------------------------------------
      -- Outputs:
      ----------------------------------------------------------
      -- Registered outputs:
      d <= v;
      
      -- Combinatorial outputs:
      status(STATUS_IDLE) <= idle;
      status(STATUS_BUSY) <= busy;
      status(STATUS_DONE) <= done;
      
  end process;
  
  start <= r.start;
  stop <= r.stop;
  reset <= r.reset;
  
end Behavioral;
