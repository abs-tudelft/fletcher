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
use work.Stream_pkg.all;

entity ArrayReaderUnlockCombine is
  generic (

    -- Enables or disables command stream tag system. When disabled, this unit
    -- is no-op.
    CMD_TAG_ENABLE              : boolean;

    -- Command stream tag width. Must be at least 1 to avoid null vectors.
    CMD_TAG_WIDTH               : natural

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Incoming unlock streams.
    a_unlock_valid              : in  std_logic;
    a_unlock_ready              : out std_logic;
    a_unlock_tag                : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
    a_unlock_ignoreChild        : in  std_logic := '0';

    b_unlock_valid              : in  std_logic;
    b_unlock_ready              : out std_logic;
    b_unlock_tag                : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    -- Outgoing unlock stream.
    unlock_valid                : out std_logic;
    unlock_ready                : in  std_logic;
    unlock_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0)

  );
end ArrayReaderUnlockCombine;

architecture Behavioral of ArrayReaderUnlockCombine is
begin

  with_cmd_tag_gen: if CMD_TAG_ENABLE generate

    -- Whether we should expect an unlock tranfer from B.
    signal b_unlock_use         : std_logic;

    -- Internal version of unlock_valid so we can read from it on the assertion
    -- process.
    signal unlock_valid_int     : std_logic;

  begin

    -- Determine whether we should expect an unlock transfer from B.
    b_unlock_use <= not (a_unlock_ignoreChild and a_unlock_valid);

    -- Combine the streams with a StreamSync.
    sync_inst: StreamSync
      generic map (
        NUM_INPUTS                => 2,
        NUM_OUTPUTS               => 1
      )
      port map (
        clk                       => clk,
        reset                     => reset,

        in_valid(1)               => b_unlock_valid,
        in_valid(0)               => a_unlock_valid,
        in_ready(1)               => b_unlock_ready,
        in_ready(0)               => a_unlock_ready,
        in_use(1)                 => b_unlock_use,
        in_use(0)                 => '1',

        out_valid(0)              => unlock_valid_int,
        out_ready(0)              => unlock_ready
      );

    -- Both tags should be identical. In simulation we test for this, in
    -- hardware we just return one of them.
    unlock_tag <= a_unlock_tag;

    -- pragma translate_off
    -- Give assertion errors when the tags from the two unlock streams differ.
    tag_identity_proc: process (clk) is
    begin
      if rising_edge(clk) then
        if unlock_valid_int = '1' then
          if to_X01(b_unlock_use) = '1' then
            assert a_unlock_tag = b_unlock_tag
              report "Unlock stream tag mismatch! Something in the command "
                  & "stream path desynchronized!" severity FAILURE;
          elsif to_X01(b_unlock_use) = 'X' then
            assert false
              report "Undefined unlock_use!" severity FAILURE;
          end if;
        end if;
      end if;
    end process;

    -- pragma translate_on

    -- Forward the internal version of unlock_valid.
    unlock_valid <= unlock_valid_int;

  end generate;

  without_cmd_tag_gen: if not CMD_TAG_ENABLE generate
  begin

    -- Command tag system disabled. Just drive our outputs with constants.
    a_unlock_ready  <= '1';
    b_unlock_ready  <= '1';
    unlock_valid    <= '0';
    unlock_tag      <= (others => '0');

  end generate;

end Behavioral;
