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

library work;
use work.Streams.all;
use work.Utils.all;

-- This unit is a barrel shifter, to be used within a pipeline controlled by
-- StreamPipelineControl.

entity StreamPipelineBarrel is
  generic (

    -- Width of a data element.
    ELEMENT_WIDTH               : natural := 1;

    -- Number of data elements.
    ELEMENT_COUNT               : natural;

    -- Width of the amount input.
    AMOUNT_WIDTH                : natural;

    -- Direction of the rotation; left or right..
    DIRECTION                   : string := "left";

    -- Operation; rotate, arithmetic, logical, or shift (=logical). For
    -- arithmetic shift-rights with ELEMENT_WIDTH > 1, the entire data field is
    -- still interpreted as a signed number, so the MSB of the entire data
    -- field is copied.
    OPERATION                   : string := "rotate";

    -- Number of pipeline stages. The delay from input to output is exactly
    -- this number.
    NUM_STAGES                  : positive;

    -- Width of control data. Must be 1 to avoid null ranges. Travels with the
    -- pipeline.
    CTRL_WIDTH                  : natural := 1

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    in_data                     : in  std_logic_vector(ELEMENT_COUNT*ELEMENT_WIDTH-1 downto 0);
    in_ctrl                     : in  std_logic_vector(CTRL_WIDTH-1 downto 0) := (others => '0');
    in_amount                   : in  std_logic_vector(AMOUNT_WIDTH-1 downto 0);

    -- Output stream.
    out_data                    : out std_logic_vector(ELEMENT_COUNT*ELEMENT_WIDTH-1 downto 0);
    out_ctrl                    : out std_logic_vector(CTRL_WIDTH-1 downto 0)

  );
end StreamPipelineBarrel;

architecture Behavioral of StreamPipelineBarrel is

  -- Figure out the number of 2:1 muxes needed to perform the shift. This is
  -- the logarithm of the total number of shift positions. Note that a regular
  -- shift has one more position than a rotation, because a shift can result
  -- in all zero or sign bits while that state would just be the original state
  -- for a rotation.
  constant SHIFT_DEPTH          : natural := work.utils.min(AMOUNT_WIDTH, log2ceil(sel(OPERATION /= "rotate", 1, 0) + ELEMENT_COUNT));

  -- Stage register data type.
  type stage_type is record
    data                        : std_logic_vector(ELEMENT_COUNT*ELEMENT_WIDTH-1 downto 0);
    ctrl                        : std_logic_vector(CTRL_WIDTH-1 downto 0);
    amount                      : unsigned(SHIFT_DEPTH-1 downto 0);
  end record;
  type stage_array is array (natural range <>) of stage_type;

  signal stage_r                : stage_array(1 to NUM_STAGES);

begin

  reg_proc: process (clk) is
    variable stage_v            : stage_array(1 to NUM_STAGES);
    variable s                  : natural;
    variable a                  : natural;
  begin
    if rising_edge(clk) then

      -- Load the state from the previous stage registers.
      stage_v(2 to NUM_STAGES) := stage_r(1 to NUM_STAGES-1);

      -- Load the incoming data into the pipeline.
      stage_v(1).data := in_data;
      stage_v(1).ctrl := in_ctrl;

      -- Preprocess the shift amount. For shifts we clamp it to the maximum
      -- value, for rotations we perform a modulo operation.
      if OPERATION /= "rotate" then

        -- Clamp to ELEMENT_COUNT.
        if unsigned(in_amount) > ELEMENT_COUNT then
          stage_v(1).amount := to_unsigned(ELEMENT_COUNT, SHIFT_DEPTH);
        else
          stage_v(1).amount := resize(unsigned(in_amount), SHIFT_DEPTH);
        end if;

      elsif log2ceil(ELEMENT_COUNT+1) > log2ceil(ELEMENT_COUNT) then

        -- Rotation with power-of-two element count, so we can throw away the
        -- upper bits, i.e. just need a resize.
        stage_v(1).amount := resize(unsigned(in_amount), SHIFT_DEPTH);

      elsif 2**AMOUNT_WIDTH-1 < ELEMENT_COUNT then

        -- Maximum representable amount is less than the element count, so we
        -- always do less than a full rotation and just need a resize.
        stage_v(1).amount := resize(unsigned(in_amount), SHIFT_DEPTH);

      else

        if 2**AMOUNT_WIDTH-1 >= 2*ELEMENT_COUNT then
          -- You shouldn't want to do this, because it requires a significant
          -- divider.
          report "ELEMENT_COUNT is not a power of two and AMOUNT_WIDTH is wider " &
                "than you need to perform a full rotation. Please lower " &
                "AMOUNT_WIDTH to a reasonable value, otherwise a division/modulo " &
                "operation would be required!" severity failure;
        end if;

        -- Maximum representable amount is less than twice the element count
        -- or the user neglected to simulate their design. Either way, assume
        -- that the shift amount is always less than two full rotations.
        if unsigned(in_amount) > ELEMENT_COUNT then
          stage_v(1).amount := resize(unsigned(in_amount) - ELEMENT_COUNT, SHIFT_DEPTH);
        else
          stage_v(1).amount := resize(unsigned(in_amount), SHIFT_DEPTH);
        end if;

      end if;

      -- Perform the shift operations.
      for i in 0 to SHIFT_DEPTH - 1 loop

        -- Determine the pipeline stage for this shift, such that the earlier
        -- stages shift the lower bits of the shift amount, and such that if
        -- the number of shifts is not dividible over the number of stages, the
        -- first stage will have less shifts. It doesn't matter for the shift
        -- algorithm which stage a particular shift step occurs in, as long as
        -- this value is always between 1 and NUM_STAGES, and it is constant
        -- after unrolling the loop.
        s := NUM_STAGES - ((SHIFT_DEPTH - 1 - i) * NUM_STAGES / SHIFT_DEPTH);

        -- Determine the shift amount for this step. This must be constant
        -- after unrolling the loop.
        a := 2**i * ELEMENT_WIDTH;

        if stage_v(s).amount(i) = '1' then
          if DIRECTION = "left" then
            if OPERATION = "rotate" then
              -- Rotate left.
              stage_v(s).data := std_logic_vector(rotate_left(unsigned(stage_v(s).data), a));
            else
              -- Arithmetic and logical left-shifts are identical operations.
              stage_v(s).data := std_logic_vector(shift_left(unsigned(stage_v(s).data), a));
            end if;
          else
            if OPERATION = "rotate" then
              -- Rotate right.
              stage_v(s).data := std_logic_vector(rotate_right(unsigned(stage_v(s).data), a));
            elsif OPERATION = "arithmetic" then
              -- Arithmetic right-shift.
              stage_v(s).data := std_logic_vector(shift_right(signed(stage_v(s).data), a));
            else
              -- Logical right-shift.
              stage_v(s).data := std_logic_vector(shift_right(unsigned(stage_v(s).data), a));
            end if;
          end if;
        end if;

      end loop;

      -- Save the state to the stage registers. Note that we don't need to do
      -- a reset; the pipeline control logic will never consume data that has
      -- not passed through the entire pipeline.
      stage_r <= stage_v;

    end if;
  end process;

  out_data <= stage_r(stage_r'HIGH).data;
  out_ctrl <= stage_r(stage_r'HIGH).ctrl;

end Behavioral;
