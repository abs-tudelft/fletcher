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
use work.Utils.all;

entity sum is
  generic(
    PRIM_WIDTH                                 : natural;
    PRIM_EPC                                   : natural;
    TAG_WIDTH                                  : natural;
    BUS_ADDR_WIDTH                             : natural;
    INDEX_WIDTH                                : natural;
    REG_WIDTH                                  : natural
  );
  port(
    weight_cmd_weight_values_addr              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    weight_cmd_tag                             : out std_logic_vector(TAG_WIDTH-1 downto 0);
    weight_cmd_lastIdx                         : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    weight_cmd_firstIdx                        : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    weight_cmd_ready                           : in std_logic;
    weight_cmd_valid                           : out std_logic;
    weight_out_data                            : in std_logic_vector(PRIM_WIDTH*PRIM_EPC-1 downto 0);
    weight_out_valid                           : in std_logic;
    weight_out_ready                           : out std_logic;
    weight_out_last                            : in std_logic;
    -------------------------------------------------------------------------
    acc_reset                                  : in std_logic;
    acc_clk                                    : in std_logic;
    -------------------------------------------------------------------------
    ctrl_done                                  : out std_logic;
    ctrl_busy                                  : out std_logic;
    ctrl_idle                                  : out std_logic;
    ctrl_reset                                 : in std_logic;
    ctrl_stop                                  : in std_logic;
    ctrl_start                                 : in std_logic;
    -------------------------------------------------------------------------
    idx_first                                  : in std_logic_vector(REG_WIDTH-1 downto 0);
    idx_last                                   : in std_logic_vector(REG_WIDTH-1 downto 0);
    reg_return0                                : out std_logic_vector(REG_WIDTH-1 downto 0);
    reg_return1                                : out std_logic_vector(REG_WIDTH-1 downto 0);
    -------------------------------------------------------------------------
    reg_weight_values_addr                     : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)
  );
end entity sum;


architecture rtl of sum is

  component tree_adder is
    generic(
      PRIM_WIDTH : natural;
      PRIM_EPC   : natural
    );
    port(
      reset   : in  std_logic;
      clk     : in  std_logic;
      firstidx: in  std_logic_vector(log2ceil(PRIM_EPC)-1 downto 0);
      lastidx : in  std_logic_vector(log2ceil(PRIM_EPC)-1 downto 0);
      i_valid : in  std_logic;
      i_ready : out std_logic;
      i_data  : in  std_logic_vector(PRIM_WIDTH * PRIM_EPC - 1 downto 0);
      i_last  : in  std_logic;
      o_data  : out std_logic_vector(PRIM_WIDTH - 1 downto 0);
      o_valid : out std_logic;
      o_last  : out std_logic
    );
  end component;

  constant ZERO : std_logic_vector(31 downto 0) := x"00000000";

  type haf_state_t IS (RESET, WAITING, SETUP, RUNNING, DONE);
	signal state, state_next : haf_state_t;

  -- Accumulate the total sum here
  signal accumulator, accumulator_next : signed(2*REG_WIDTH-1 downto 0);
  signal sum_elements : std_logic_vector(2*REG_WIDTH-1 downto 0);
  signal accum_done  : std_logic;
  signal sum_valid   : std_logic;

begin

  multi_adder : tree_adder
    generic map(
      PRIM_WIDTH => PRIM_WIDTH,
      PRIM_EPC   => PRIM_EPC
    )
    port map(
      reset   => ctrl_reset,
      clk     => acc_clk,
      firstidx=> idx_first( log2ceil(PRIM_EPC)-1 downto 0 ),
      lastidx => idx_last ( log2ceil(PRIM_EPC)-1 downto 0 ),
      i_valid => weight_out_valid,
      i_ready => weight_out_ready,
      i_data  => weight_out_data,
      i_last  => weight_out_last,
      o_data  => sum_elements,
      o_valid => sum_valid,
      o_last  => accum_done
    );

  -- Module output is the accumulator value
  reg_return0 <= std_logic_vector(accumulator(1*REG_WIDTH-1 downto 0*REG_WIDTH));
  reg_return1 <= std_logic_vector(accumulator(2*REG_WIDTH-1 downto 1*REG_WIDTH));

  -- Provide base address to ArrayReader
  weight_cmd_weight_values_addr <= reg_weight_values_addr;
  weight_cmd_tag <= (others => '0');

  row_idx_p: process (idx_first, idx_last)
  begin
    -- Set the first and last index on our array
    weight_cmd_firstIdx <= ZERO( log2ceil(PRIM_EPC)-1 downto 0 )
        & idx_first( idx_first'length-1 downto log2ceil(PRIM_EPC) );
    -- Since the last index is exclusive, add one after truncating if not on boundary
    if unsigned(idx_last ( log2ceil(PRIM_EPC)-1 downto 0 )) /= 0 then
      weight_cmd_lastIdx <= std_logic_vector(unsigned(
            ZERO( log2ceil(PRIM_EPC)-1 downto 0 )
            & idx_last( idx_first'length-1 downto log2ceil(PRIM_EPC) )
          ) + 1);
    else
      weight_cmd_lastIdx <= ZERO( log2ceil(PRIM_EPC)-1 downto 0 )
            & idx_last( idx_first'length-1 downto log2ceil(PRIM_EPC) );
    end if;
  end process;

  logic_p: process (state, ctrl_start,
    weight_cmd_ready, accum_done, sum_valid, accumulator, sum_elements)
  begin
    -- Default values
    -- No command to ArrayReader
    weight_cmd_valid <= '0';
    -- Retain accumulator value
    accumulator_next <= accumulator;
    -- Stay in same state
    state_next <= state;

    case state is
      when RESET =>
        ctrl_done <= '0';
        ctrl_busy <= '0';
        ctrl_idle <= '0';
        state_next <= WAITING;
        -- Start sum at 0
        accumulator_next <= (others => '0');

      when WAITING =>
        ctrl_done <= '0';
        ctrl_busy <= '0';
        ctrl_idle <= '1';
        -- Wait for start signal from UserCore (initiated by software)
        if ctrl_start = '1' then
          state_next <= SETUP;
        end if;

      when SETUP =>
        ctrl_done <= '0';
        ctrl_busy <= '1';
        ctrl_idle <= '0';
        -- Send address and row indices to the ArrayReader
        weight_cmd_valid <= '1';
        if weight_cmd_ready = '1' then
          -- ArrayReader has received the command
          state_next <= RUNNING;
        end if;

      when RUNNING =>
        ctrl_done <= '0';
        ctrl_busy <= '1';
        ctrl_idle <= '0';
        if sum_valid = '1' then
          accumulator_next <= accumulator + signed(sum_elements);
        end if;
        if accum_done = '1' then
          state_next <= DONE;
        end if;

      when DONE =>
        ctrl_done <= '1';
        ctrl_busy <= '0';
        ctrl_idle <= '1';

      when others =>
        ctrl_done <= '0';
        ctrl_busy <= '0';
        ctrl_idle <= '0';
    end case;
  end process;


  state_p: process (acc_clk)
  begin
    -- Control state machine
    if rising_edge(acc_clk) then
      if acc_reset = '1' or ctrl_reset = '1' then
        state <= RESET;
        accumulator <= (others => '0');
      else
        state <= state_next;
        accumulator <= accumulator_next;
      end if;
    end if;
  end process;

end architecture;





library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use IEEE.numeric_std.all;

library work;
use work.Utils.all;

entity tree_adder is
  generic(
    PRIM_WIDTH : natural;
    PRIM_EPC   : natural
  );
  port(
    reset   : in  std_logic;
    clk     : in  std_logic;
    firstidx: in  std_logic_vector(log2ceil(PRIM_EPC)-1 downto 0);
    lastidx : in  std_logic_vector(log2ceil(PRIM_EPC)-1 downto 0);
    i_valid : in  std_logic;
    i_ready : out std_logic;
    i_data  : in  std_logic_vector(PRIM_WIDTH * PRIM_EPC - 1 downto 0);
    i_last  : in  std_logic;
    o_data  : out std_logic_vector(PRIM_WIDTH - 1 downto 0);
    o_valid : out std_logic;
    o_last  : out std_logic
  );
end entity tree_adder;


architecture tree_clocked of tree_adder is
  signal intermediate : signed( (2 ** (log2ceil(PRIM_EPC) + 1) - 1) * PRIM_WIDTH - 1 downto 0);
  signal done_delay : std_logic_vector(log2ceil(PRIM_EPC) downto 0);
  signal first : std_logic;
begin


  o_data  <= std_logic_vector(intermediate(o_data'length - 1 downto 0));
  o_last  <= done_delay(done_delay'length - 1);
  i_ready <= '1';

  process (clk)
    variable reg_src   : natural;
    variable reg_dst   : natural;
    variable srca_base : natural;
    variable srcb_base : natural;
    variable dst_base  : natural;
  begin
    if rising_edge(clk) then
      if reset = '1' then
        intermediate <= (others => '0');
        done_delay   <= (others => '0');
        o_valid <= '0';
        first <= '1';

      -- Only advance when there is valid input, or to empty pipeline
      elsif i_valid = '1' or done_delay(0) = '1' then
        o_valid <= '1';
        first <= '0';

        -- Delay the `done' signal by the pipeline depth
        done_delay(done_delay'length - 1 downto 1)
          <= done_delay(done_delay'length - 2 downto 0);
        if i_last = '1' or done_delay(1) = '1' then
          done_delay(0) <= '1';
        end if;

        -- Zero inputs that are outside given row range
        for regidx in 0 to PRIM_EPC - 1 loop
          if
               (i_last = '1' and regidx >= unsigned(lastidx) and unsigned(lastidx) /= 0)
            or (first  = '1' and regidx < unsigned(firstidx)) then
            intermediate(
              intermediate'length - i_data'length + (regidx + 1) * PRIM_WIDTH - 1
              downto intermediate'length - i_data'length + regidx * PRIM_WIDTH
            ) <= (others => '0');
          else
            intermediate(
              intermediate'length - i_data'length + (regidx + 1) * PRIM_WIDTH - 1
              downto intermediate'length - i_data'length + regidx * PRIM_WIDTH
            ) <= signed(i_data( (regidx + 1) * PRIM_WIDTH - 1 downto regidx * PRIM_WIDTH) );
          end if;
        end loop;

        -- Generate all the pairwise sum units
        for lvl in 0 to log2ceil(PRIM_EPC) - 1 loop
          reg_src := ( 2 ** (lvl + 1) ) - 1;
          reg_dst := ( 2 ** lvl ) - 1;
          for idx in 0 to 2 ** lvl - 1 loop
            dst_base  := PRIM_WIDTH * (reg_dst + idx);
            srca_base := PRIM_WIDTH * (reg_src + idx * 2);
            srcb_base := PRIM_WIDTH * (reg_src + idx * 2 + 1);
            intermediate(dst_base + PRIM_WIDTH - 1 downto dst_base)
              <= intermediate(srca_base + PRIM_WIDTH - 1 downto srca_base) +
                 intermediate(srcb_base + PRIM_WIDTH - 1 downto srcb_base);
          end loop; -- idx
        end loop; -- lvl

      else -- no valid input
        o_valid <= '0';
      end if; -- reset / input
    end if; -- clk
  end process;

end architecture;

