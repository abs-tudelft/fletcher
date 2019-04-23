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

-- Counter for FIFO read/write pointers, including cross-clock synchronization
-- logic.

entity StreamFIFOCounter is
  generic (

    -- FIFO depth represented as log2(depth).
    DEPTH_LOG2                  : natural;

    -- The amount of clock domain crossing synchronization registers required.
    -- If this is zero, the input and output clocks are assumed to be
    -- synchronous and the gray-code codecs are omitted.
    XCLK_STAGES                 : natural := 0

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- clock domain that increments the counter.
    a_clk                       : in  std_logic;
    a_reset                     : in  std_logic;

    -- Increment flag for the counter in the a_clk domain.
    a_increment                 : in  std_logic;

    -- Counter value synchronized to the a_clk domain.
    a_counter                   : out std_logic_vector(DEPTH_LOG2 downto 0);

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- other clock domain.
    b_clk                       : in  std_logic;
    b_reset                     : in  std_logic;

    -- Counter value synchronized to the b_clk domain.
    b_counter                   : out std_logic_vector(DEPTH_LOG2 downto 0)

  );
end StreamFIFOCounter;

architecture Behavioral of StreamFIFOCounter is

  -- Internal "copy" of a_counter.
  signal a_counter_s            : std_logic_vector(DEPTH_LOG2 downto 0);

begin

  -- Instantiate the binary counter.
  cntr_proc: process (a_clk) is
  begin
    if rising_edge(a_clk) then
      if a_reset = '1' then
        a_counter_s <= (others => '0');
      elsif a_increment = '1' then
        a_counter_s <= std_logic_vector(unsigned(a_counter_s) + 1);
      end if;
    end if;
  end process;

  -- Forward the internal copy of the counter in the a_clk domain.
  a_counter <= a_counter_s;

  -- If no asynchronous clock crossing is required, a_counter and b_counter are
  -- identical.
  no_xclk: if XCLK_STAGES = 0 generate
  begin
    b_counter <= a_counter_s;
  end generate;

  -- Otherwise, generate a gray-coded CDC.
  with_xclk: if XCLK_STAGES > 0 generate

    -- Type declarations for the clock domain crossing registers, so we can
    -- make an array of them for the synchronization stages.
    subtype sync_reg_type is std_logic_vector(DEPTH_LOG2 downto 0);
    type sync_reg_array is array (natural range <>) of sync_reg_type;

    -- Registered gray-encoded counter value in the a_clk domain.
    signal a_gray               : sync_reg_type;

    -- Synchronization registers in the b_clk domain. The path from a_gray to
    -- b_gray should be timed using the source clock; the frequency and phase
    -- of the destination clock does not matter.
    signal b_gray               : sync_reg_array(1 to XCLK_STAGES);

    -- ASYNC_REG attribute for Xilinx tools to force CDC registers to be placed
    -- in the same slice as their driver.
    attribute async_reg : string;
    attribute async_reg of b_gray : signal is "TRUE";

  begin

    -- Convert binary to gray code and register the result.
    b2g_proc: process (a_clk) is
    begin
      if rising_edge(a_clk) then
        if a_reset = '1' then
          a_gray <= (others => '0');
        else
          a_gray <= a_counter_s xor
                    ("0" & a_counter_s(DEPTH_LOG2 downto 1));
        end if;
      end if;
    end process;

    -- Generate the synchronization registers.
    sync_proc: process (b_clk) is
    begin
      if rising_edge(b_clk) then
        if b_reset = '1' then
          b_gray <= (others => (others => '0'));
        else

          -- First register.
          b_gray(1) <= a_gray;

          -- Additional registers, enclosed in an if and a loop to prevent
          -- problems due to flaky synthesis tool null range support.
          if XCLK_STAGES > 1 then
            for i in 2 to XCLK_STAGES loop
              b_gray(i) <= b_gray(i-1);
            end loop;
          end if;

        end if;
      end if;
    end process;

    -- Convert the gray code back to binary.
    g2b_proc: process (b_gray(XCLK_STAGES)) is
    begin
      for i in DEPTH_LOG2 downto 0 loop
        b_counter(i) <= xor_reduce(b_gray(XCLK_STAGES)(DEPTH_LOG2 downto i));
      end loop;
    end process;

  end generate;

end Behavioral;

