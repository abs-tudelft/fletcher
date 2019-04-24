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

-- This unit represents a 1-read 1-write memory with separate clock domains for
-- the read and write port. It is described behaviorally in a way that
-- synthesis tools should infer the memory correctly, but modifications may
-- need to be made for some tools.

entity Ram1R1W is
  generic (

    -- Width of a data word.
    WIDTH                       : natural;

    -- Depth of the memory as log2(depth in words).
    DEPTH_LOG2                  : natural;

    -- RAM configuration parameter. Unused by this default implementation. May
    -- be used to give different optimization options for different RAMs in the
    -- design if this unit is ported to exotic architectures (e.g. ASIC) or if
    -- more control over the implementation style is desired by the user.
    RAM_CONFIG                  : string := ""

  );
  port (

    -- Write port. All signals are synchronized to the same rising edge of
    -- w_clk. w_ena is active-high, indicating validity of w_addr and w_data.
    w_clk                       : in  std_logic;
    w_ena                       : in  std_logic;
    w_addr                      : in  std_logic_vector(DEPTH_LOG2-1 downto 0);
    w_data                      : in  std_logic_vector(WIDTH-1 downto 0);

    -- Read port. All signals are synchronized to the rising edge of r_clk,
    -- r_data being delayed by one cycle with respect to r_ena and r_addr. If
    -- r_ena is low, the corresponding r_data must be considered to be invalid
    -- by users of this block. r_ena is not implemented in this default
    -- implementation.
    r_clk                       : in  std_logic;
    r_ena                       : in  std_logic := '1';
    r_addr                      : in  std_logic_vector(DEPTH_LOG2-1 downto 0);
    r_data                      : out std_logic_vector(WIDTH-1 downto 0)

  );
end Ram1R1W;

architecture Behavioral of Ram1R1W is

  -- Shared variable to represent the memory.
  type mem_type is array (2**DEPTH_LOG2-1 downto 0) of std_logic_vector(WIDTH-1 downto 0);
  -- Shared variable needs to be protected for synthesis by vivado.
  -- Use a signal instead.
  signal mem : mem_type;
  
  -- RAM style pragmas:
  
  -- Vivado RAM style
  attribute ram_style : string;
  attribute ram_style of mem : signal is RAM_CONFIG;
  
  -- Quartus RAM style
  
  -- ... RAM style

begin

  -- Write port.
  write_proc: process (w_clk) is
  begin
    if rising_edge(w_clk) then
      if w_ena = '1' then
        mem(to_integer(unsigned(w_addr))) <= w_data;
      end if;
    end if;
  end process;

  -- Read port.
  read_proc: process (r_clk) is
  begin
    if rising_edge(r_clk) then
      r_data <= mem(to_integer(unsigned(r_addr)));
    end if;
  end process;

end Behavioral;

