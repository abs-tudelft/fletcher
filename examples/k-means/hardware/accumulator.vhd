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

entity accumulator is
    generic(
      DATA_WIDTH        : natural;
      ACCUMULATOR_WIDTH : natural
    );
    port(
      reset             : in  std_logic;
      clk               : in  std_logic;
      point_data        : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      point_valid       : in  std_logic;
      point_ready       : out std_logic;
      point_last        : in  std_logic;
      sum_data          : out std_logic_vector(ACCUMULATOR_WIDTH-1 downto 0);
      sum_last          : out std_logic
    );
end entity accumulator;


architecture behavior of accumulator is
  component adder is
    generic(
      DATA_WIDTH           : natural;
      TUSER_WIDTH          : positive := 1;
      OPERATION            : string   := "add";
      SLICES               : natural  := 1
    );
    port(
      clk                  : in  std_logic;
      reset                : in  std_logic;
      s_axis_a_tvalid      : in  std_logic;
      s_axis_a_tready      : out std_logic;
      s_axis_a_tdata       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      s_axis_a_tlast       : in  std_logic := '0';
      s_axis_a_tuser       : in  std_logic_vector(TUSER_WIDTH-1 downto 0) := (others => '0');
      s_axis_b_tvalid      : in  std_logic;
      s_axis_b_tready      : out std_logic;
      s_axis_b_tdata       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      s_axis_b_tlast       : in  std_logic := '0';
      m_axis_result_tvalid : out std_logic;
      m_axis_result_tready : in  std_logic;
      m_axis_result_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      m_axis_result_tlast  : out std_logic;
      m_axis_result_tuser  : out std_logic_vector(TUSER_WIDTH-1 downto 0)
    );
  end component;

  type haf_state_t is (ACCUMULATE, WAIT_AB, WAIT_A, WAIT_B);
	signal state, state_next : haf_state_t;

  type axi_t is record
    valid : std_logic;
    ready : std_logic;
    last  : std_logic;
    data  : std_logic_vector(ACCUMULATOR_WIDTH-1 downto 0);
  end record axi_t;

  signal arg_a,
         arg_b,
         result : axi_t;

begiN

  process (clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        state <= WAIT_AB;
      else
        case state is
          when WAIT_AB =>
            if arg_a.ready = '1' and arg_b.ready = '1' then
              state <= ACCUMULATE;
            elsif arg_a.ready = '1' then
              state <= WAIT_B;
            elsif arg_b.ready = '1' then
              state <= WAIT_A;
            end if;
          when WAIT_A =>
            if arg_a.ready = '1' then
              state <= ACCUMULATE;
            end if;
          when WAIT_B =>
            if arg_b.ready = '1' then
              state <= ACCUMULATE;
            end if;
          when others =>
            state <= ACCUMULATE;
        end case;
      end if;
    end if;
  end process;


  process (state, point_valid, point_data, point_last,
           result.valid, result.data, result.last,
           arg_a.ready, arg_b.ready)
  begin
    if state = ACCUMULATE then
      arg_a.valid <= point_valid;
      point_ready <= arg_a.ready;
      arg_a.data  <= std_logic_vector(resize(signed(point_data), ACCUMULATOR_WIDTH));
      arg_a.last  <= point_last;

      arg_b.valid  <= result.valid;
      result.ready <= arg_b.ready;
      arg_b.data   <= result.data;
      arg_b.last   <= result.last;

    else
      -- Push exactly one zero into each of the arguments
      if state = WAIT_AB or state = WAIT_A then
        arg_a.valid <= '1';
      else
        arg_a.valid <= '0';
      end if;
      -- Cannot accept a point until initialized
      point_ready <= '0';
      arg_a.data  <= (others => '0');
      arg_a.last  <= '0';

      if state = WAIT_AB or state = WAIT_B then
        arg_b.valid <= '1';
      else
        arg_b.valid <= '0';
      end if;
      arg_b.data  <= (others => '0');
      arg_b.last  <= '0';

      -- Don't consume any result
      result.ready <= '0';
    end if;
  end process;

  -- Output
  sum_data <= result.data;
  sum_last <= result.last and result.valid;

  add_l: adder generic map (
    DATA_WIDTH             => ACCUMULATOR_WIDTH,
    SLICES                 => 1
  )
  port map (
    clk                    => clk,
    reset                  => reset,
    s_axis_a_tvalid        => arg_a.valid,
    s_axis_a_tready        => arg_a.ready,
    s_axis_a_tdata         => arg_a.data,
    s_axis_a_tlast         => arg_a.last,
    s_axis_b_tvalid        => arg_b.valid,
    s_axis_b_tready        => arg_b.ready,
    s_axis_b_tdata         => arg_b.data,
    m_axis_result_tvalid   => result.valid,
    m_axis_result_tready   => result.ready,
    m_axis_result_tdata    => result.data,
    m_axis_result_tlast    => result.last
  );

end architecture;

