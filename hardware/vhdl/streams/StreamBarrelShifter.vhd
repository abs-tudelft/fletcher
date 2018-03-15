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
use work.Streams.all;

-- This unit barrel shifts elements in a stream of N elements
entity StreamBarrelShifter is
  generic (
    CTRL_WIDTH                  : natural := 0;
    ELEMENT_WIDTH               : natural := 8;
    ELEMENT_COUNT               : natural := 4;
    SHAMT_WIDTH                 : natural := 2;
    STAGES                      : natural := 4;
    SHIFT_DIRECTION             : string  := "left"
  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(ELEMENT_WIDTH * ELEMENT_COUNT-1 downto 0);
    in_shamt                    : in  std_logic_vector(SHAMT_WIDTH-1 downto 0);

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(ELEMENT_WIDTH * ELEMENT_COUNT-1 downto 0)

  );
end StreamBarrelShifter;

architecture Behavioral of StreamBarrelShifter is

  -- Currently each stage can just shift by one
  constant STAGES               : natural := ELEMENT_COUNT;
  constant MAX_STAGE_SHIFT      : natural := ELEMENT_COUNT/STAGES;

  type buf_t is array (0 to STAGES-1) of std_logic_vector(ELEMENT_COUNT * ELEMENT_WIDTH-1 downto 0);
  signal buf                    : buf_t;

  type stage_shift_t is array (0 to STAGES-1) of unsigned(SHAMT_WIDTH-1 downto 0);
  signal stage_shift            : stage_shift_t;

  signal valid                  : std_logic_vector(0 to STAGES-1);
  signal ready                  : std_logic;

begin

  assert STAGES <= ELEMENT_COUNT
    report "Cannot have more barrel shift stages than elements in vector."
    severity failure;

  -- In ready only when out is ready
  ready                         <= out_ready and not(reset);
  in_ready                      <= ready;

  seq: process(clk)
  begin
    if rising_edge(clk) then
      -- Only advance the pipeline if output is ready and no reset
      if out_ready = '1' and reset /= '1' then
        -- Valid
        valid(0)                <= in_valid and ready;
        for S in 1 to STAGES-1 loop
          valid(S)              <= valid(S-1);
        end loop;

        -- Inputs
        stage_shift(0)          <= unsigned(in_shamt);
        buf(0)                  <= in_data;

        -- Advance pipeline
        for S in 1 to STAGES-1 loop
          -- Shift if not done
          if stage_shift(S-1) /= 0 then

            -- Maximum shift by default
            stage_shift(S)      <= stage_shift(S-1) - MAX_STAGE_SHIFT;
            if SHIFT_DIRECTION = "left" then
              buf(S)              <= std_logic_vector(rotate_left(unsigned(buf(S-1)), MAX_STAGE_SHIFT * ELEMENT_WIDTH));
            else
              buf(S)              <= std_logic_vector(rotate_right(unsigned(buf(S-1)), MAX_STAGE_SHIFT * ELEMENT_WIDTH));
            end if;

            -- Other shift amounts (if they exist)
            if MAX_STAGE_SHIFT /= 1 then
              for I in 1 to MAX_STAGE_SHIFT-1 loop
                if to_unsigned(I, SHAMT_WIDTH) = stage_shift(S-1) then
                  stage_shift(S) <= stage_shift(S-1) - MAX_STAGE_SHIFT;
                  if SHIFT_DIRECTION = "left" then
                    buf(S)      <= std_logic_vector(rotate_left(unsigned(buf(S-1)), I * ELEMENT_WIDTH));
                  else
                    buf(S)      <= std_logic_vector(rotate_right(unsigned(buf(S-1)), I * ELEMENT_WIDTH));
                  end if;
                end if;
              end loop;
            end if;
          else
            stage_shift(S)      <= stage_shift(S-1);
            buf(S)              <= buf(S-1);
          end if;
        end loop;
      end if;

      -- Reset
      if reset = '1' then
        valid                   <= (others => '0');
      end if;
    end if;
  end process;

  out_data                      <= buf(STAGES-1);
  out_valid                     <= valid(STAGES-1);

end Behavioral;
