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
-- WITHout WARRANTIES OR CONDITIONS OF ANY KinD, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use IEEE.numeric_std.all;

library work;
use work.Utils.all;

entity divider is
  generic(
    IN_WIDTH             : natural;
    OUT_WIDTH            : natural
  );
  port(
    clk                  : in  std_logic;
    reset                : in  std_logic;
    s_in_valid           : in  std_logic;
    s_in_ready           : out std_logic;
    -- Signed
    s_in_numerator       : in  std_logic_vector(IN_WIDTH-1 downto 0);
    -- Unsigned
    s_in_denominator     : in  std_logic_vector(IN_WIDTH-1 downto 0);
    m_result_valid       : out std_logic;
    m_result_ready       : in  std_logic;
    m_result_quotient    : out std_logic_vector(OUT_WIDTH-1 downto 0);
    m_result_remainder   : out std_logic_vector(OUT_WIDTH-1 downto 0)
  );
end divider;

architecture behavior of divider is

  signal shift_reg,
         shift_reg_next         : unsigned(IN_WIDTH + OUT_WIDTH - 1 downto 0);
  signal shift_hold             : std_logic;
  signal negate,
         negate_next            : std_logic;
  signal iteration,
         iteration_next         : unsigned(log2ceil(OUT_WIDTH + 2) - 1 downto 0);

  signal intermediate_valid,
         intermediate_ready     : std_logic;
  signal intermediate_quotient,
         intermediate_remainder : std_logic_vector(OUT_WIDTH-1 downto 0);
  signal full_remainder,
         subtracted_remainder   : unsigned(IN_WIDTH - 1 downto 0);
begin
  -- (R & N,Q) << 1
  -- if R >= D
  --  R -= D
  --  Q(0) = 1

  intermediate_quotient  <= 
      std_logic_vector( - signed(shift_reg(OUT_WIDTH - 1 downto 0))) when negate = '1' else
      std_logic_vector(shift_reg(OUT_WIDTH - 1 downto 0));
  intermediate_remainder <= std_logic_vector(shift_reg(OUT_WIDTH * 2 - 1 downto OUT_WIDTH));
  full_remainder         <= unsigned(shift_reg(shift_reg'length - 1 downto OUT_WIDTH));
  subtracted_remainder   <= full_remainder - unsigned(s_in_denominator);

  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        iteration <= (others => '0');
      else
        iteration <= iteration_next;
        negate    <= negate_next;
        if (shift_hold = '0') then
          shift_reg <= rotate_left(shift_reg_next, 1);
        end if;
      end if;
    end if;
  end process;

  process (iteration, shift_reg, full_remainder, subtracted_remainder, negate,
    s_in_valid, s_in_numerator, intermediate_ready)
  begin
    s_in_ready         <= '0';
    intermediate_valid <= '0';
    iteration_next     <= iteration + 1;
    negate_next        <= negate;
    shift_reg_next     <= shift_reg;
    shift_hold         <= '0';

    -- Normal iteration
    if subtracted_remainder(subtracted_remainder'length-1) = '1' then
      -- R < D
      shift_reg_next(shift_reg'length - 1) <= '0';
    else
      -- R >= D
      shift_reg_next(shift_reg'length - 1 downto OUT_WIDTH) <= subtracted_remainder;
      shift_reg_next(shift_reg'length - 1) <= '1';
    end if;

    if iteration = 0 then
      shift_reg_next <= (others => '0');
      if s_in_valid = '1' then
        -- Start
        shift_reg_next <= (others => '0');
        if s_in_numerator(s_in_numerator'length - 1) = '1' then
          shift_reg_next(IN_WIDTH - 1 downto 0) <= unsigned( - signed(s_in_numerator));
          negate_next <= '1';
        else
          shift_reg_next(IN_WIDTH - 1 downto 0) <= unsigned(s_in_numerator);
          negate_next <= '0';
        end if;
      else
        -- Waiting for input
        iteration_next <= (others => '0');
      end if;

    elsif iteration = OUT_WIDTH + 1 then
      -- Done
      shift_hold            <= '1';
      intermediate_valid    <= '1';
      if intermediate_ready <= '1' then
        s_in_ready <= '1';
        iteration_next <= (others => '0');
      else
        iteration_next <= iteration;
      end if;
    end if;
  end process;

  m_result_valid     <= intermediate_valid;
  m_result_quotient  <= intermediate_quotient;
  m_result_remainder <= intermediate_remainder;
  intermediate_ready <= m_result_ready;

end architecture;

