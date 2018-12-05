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

-- This unit breaks all combinatorial paths from the input stream to the output
-- stream. All outputs are registers.
--
-- Symbol: --->|--->

entity StreamSlice is
  generic (

    -- Width of the stream data vector.
    DATA_WIDTH                  : natural

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(DATA_WIDTH-1 downto 0)

  );
end StreamSlice;

architecture Behavioral of StreamSlice is

  -- Internal "copies" of the in_ready and out_valid control output signals.
  signal in_ready_s             : std_logic;
  signal out_valid_s            : std_logic;

  -- Holding register for data, used when the output stream is blocked and the
  -- input stream is valid. This is needed to break the "ready" signal
  -- combinatorial path.
  signal saved_data             : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal saved_valid            : std_logic;

begin

  reg_proc: process (clk) is
  begin
    if rising_edge(clk) then
      -- We're ready for new data on the input unless otherwise specified.
      in_ready_s <= '1';

      if saved_valid = '0' then

        -- Output faster than input or normal operation.
        if in_valid = '0' or in_ready_s = '0' then

          -- Input stalled, so if the output needs new data, we cannot provide
          -- any.
          if out_ready = '1' then
            out_valid_s <= '0';
          end if;

        else -- in_valid = '1' and in_ready_s = '1'

          -- We need to take in a new data item from our input.
          if out_ready = '1' or out_valid_s = '0' then

            -- The output (register) is ready too, so we can push the new
            -- data item directly into the output.
            out_data <= in_data;
            out_valid_s <= '1';

          else -- out_ready = '0' and out_valid_s = '1'

            -- The output is stalled, so we can't save the new data item in the
            -- output register. We put it in saved_data instead.
            saved_data <= in_data;
            saved_valid <= '1';

            -- We need to stall the input from the next cycle onwards, because
            -- we have no place to store new items until the output unblocks.
            in_ready_s <= '0';

          end if;

        end if;

      else -- saved_valid = '1'

        -- Handle and recover from input-faster-than-output condition.
        if out_ready = '0' then

          -- While the output is not ready yet, we need to keep blocking the
          -- input.
          in_ready_s <= '0';

        else -- out_ready = '1'

          -- The contents of the saved_data register are valid; we had to save
          -- an item there because the output stream stalled. So we need to
          -- output that item next, instead of the input data.
          out_data <= saved_data;
          out_valid_s <= '1';

          -- Now that saved_data has moved to the output, it is no longer
          -- valid there.
          saved_valid <= '0';

        end if;

      end if;
      -- Reset overrides everything.
      if reset = '1' then
        in_ready_s  <= '0';
        --saved_data  <= (others => '0');
        saved_valid <= '0';
        --out_data    <= (others => '0');
        out_valid_s <= '0';
      end if;
    end if;
  end process;

  -- Forward the internal "copies" of the control output signals.
  in_ready <= in_ready_s;
  out_valid <= out_valid_s;

end Behavioral;

