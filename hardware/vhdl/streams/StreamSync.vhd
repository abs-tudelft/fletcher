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

-- This unit synchronizes the control signals for multiple input and output
-- streams, such that the data vectors can be interconnected/concatenated/etc.
--
--             .---.
--         --->|   |--->
-- Symbol: --->| S |--->
--         --->|   |--->
--             '---'

entity StreamSync is
  generic (

    -- Number of input streams.
    NUM_INPUTS                  : natural := 1;

    -- Number of output streams.
    NUM_OUTPUTS                 : natural := 1

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input streams. The data vector is not needed within the unit and can
    -- just be connected to the output streams outside of it.
    in_valid                    : in  std_logic_vector(NUM_INPUTS-1 downto 0);
    in_ready                    : out std_logic_vector(NUM_INPUTS-1 downto 0);

    -- Input stream advance flags. These flags can be tied to anything that is
    -- valid whenever all of the input streams are valid. When a flag for a
    -- stream is low, its ready pulse is blocked, causing it to not pull in the
    -- next word along with the other streams. This can be used to synchronize
    -- a stream with multiple words per transfer to a one word per transfer
    -- stream, by tying the "last" flag of the former to the advance flag for
    -- the latter.
    in_advance                  : in  std_logic_vector(NUM_INPUTS-1 downto 0) := (others => '1');

    -- Similar behavior to in_advance, except if a bit is low here the valid
    -- signal of the associated stream is also ignored.
    in_use                      : in  std_logic_vector(NUM_INPUTS-1 downto 0) := (others => '1');

    -- Output streams. The data vector is not needed within the unit and can
    -- just be connected to the input streams outside of it.
    out_valid                   : out std_logic_vector(NUM_OUTPUTS-1 downto 0);
    out_ready                   : in  std_logic_vector(NUM_OUTPUTS-1 downto 0);

    -- Output stream enable flags. These flags can be tied to anything that is
    -- valid whenever all of the input streams are valid. When a flag for a
    -- stream is low, the current data word is not sent to that stream.
    out_enable                  : in  std_logic_vector(NUM_OUTPUTS-1 downto 0) := (others => '1')

  );
end StreamSync;

architecture Behavioral of StreamSync is

  -- Synchronized input stream control signals.
  signal valid                  : std_logic;
  signal ready                  : std_logic;

  -- This flag register is set when an output stream has acknowledged the
  -- current data word, but other streams are still blocked. It is needed to
  -- invalidate the output stream so the data does not get duplicated.
  signal out_accepted           : std_logic_vector(NUM_OUTPUTS-1 downto 0);

  -- Done flag for each output stream. An output stream is done when it is
  -- ready, when it has already accepted the current data, or when it is
  -- disabled.
  signal out_done               : std_logic_vector(NUM_OUTPUTS-1 downto 0);

begin

  -- Synchronize the input streams by asserting the internal valid signal only
  -- if all input streams are valid simultaneously.
  valid <= and_reduce(in_valid or not in_use);

  -- Broadcast the internal ready signal to all input streams.
  in_ready <= in_advance and in_use and (NUM_INPUTS-1 downto 0 => ready);

  out_gen: for os in 0 to NUM_OUTPUTS-1 generate
  begin

    reg_proc: process (clk) is
    begin
      if rising_edge(clk) then

        if valid = '1' then
          if ready = '1' then

            -- New data is available from the next cycle onward, so we need to
            -- clear our "data has already been accepted" flag.
            out_accepted(os) <= '0';

          elsif out_ready(os) = '1' then

            -- Set our "data has already been accepted" flag when the output
            -- stream is ready.
            out_accepted(os) <= '1';

          end if;
        end if;

        -- Reset overrides everything.
        if reset = '1' then
          out_accepted(os) <= '0';
        end if;

      end if;
    end process;

    -- An output stream is valid when all the input streams are valid, the
    -- output stream has not accepted the data yet, and the output stream is
    -- enabled.
    out_valid(os) <= valid and not out_accepted(os) and out_enable(os);

    -- An output stream is done when it is ready, when it has already accepted
    -- the current data, or when it is disabled.
    out_done(os) <= out_ready(os) or out_accepted(os) or not out_enable(os);

  end generate;

  -- We are ready for new input when all output streams are ready for new data
  -- and all input streams are valid.
  ready <= and_reduce(out_done) and valid;

end Behavioral;

