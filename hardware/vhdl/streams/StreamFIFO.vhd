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
use work.Utils.all;

-- This unit breaks all combinatorial paths from the input stream to the output
-- stream using a FIFO, that can optionally cross clock domains.
--
--             .----.
-- Symbol: --->|::::|--->
--             '----'

entity StreamFIFO is
  generic (

    -- FIFO depth represented as log2(depth).
    DEPTH_LOG2                  : natural;

    -- Width of the stream data vector.
    DATA_WIDTH                  : natural;

    -- The amount of clock domain crossing synchronization registers required.
    -- If this is zero, the input and output clocks are assumed to be
    -- synchronous and the gray-code codecs are omitted.
    XCLK_STAGES                 : natural := 0;

    -- RAM configuration. This is passed directly to the Ram1R1W instance.
    RAM_CONFIG                  : string := ""

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for input
    -- stream.
    in_clk                      : in  std_logic;
    in_reset                    : in  std_logic;

    -- Input stream.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Read and write pointer synchronized to the input stream clock domain.
    in_rptr                     : out std_logic_vector(DEPTH_LOG2 downto 0);
    in_wptr                     : out std_logic_vector(DEPTH_LOG2 downto 0);

    -- Rising-edge sensitive clock and active-high synchronous reset for output
    -- stream. out_clk must be synchronous to in_clk if
    out_clk                     : in  std_logic;
    out_reset                   : in  std_logic;

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Read and write pointer synchronized to the output stream clock domain.
    out_rptr                    : out std_logic_vector(DEPTH_LOG2 downto 0);
    out_wptr                    : out std_logic_vector(DEPTH_LOG2 downto 0)

  );
end StreamFIFO;

architecture Behavioral of StreamFIFO is

  -- Internal "copies" of the read and write pointers in both clock domains.
  signal in_rptr_s              : std_logic_vector(DEPTH_LOG2 downto 0);
  signal in_wptr_s              : std_logic_vector(DEPTH_LOG2 downto 0);
  signal out_rptr_s             : std_logic_vector(DEPTH_LOG2 downto 0);
  signal out_wptr_s             : std_logic_vector(DEPTH_LOG2 downto 0);

  -- FIFO full indicator in the write clock domain.
  signal in_full                : std_logic;

  -- Write pointer increment signal in the write clock domain.
  signal in_next                : std_logic;

  -- FIFO nonempty indicator in the read clock domain.
  signal out_nonEmpty           : std_logic;

  -- Read pointer increment signal in the read clock domain.
  signal out_next               : std_logic;

  -- Memory read data and valid signals.
  signal out_readData           : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal out_readValid          : std_logic;

  -- Data holding register data and valid signals. This register is necessary
  -- to compensate for the RAM read latency. Without it, we'd have to wait for
  -- ready before we can set valid, which violates AXI stream requirements.
  signal out_bufData            : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal out_bufValid           : std_logic;

begin

  -- Generate the FIFO full signal. This is the case when the read and write
  -- pointer are exactly the depth of the FIFO apart.
  in_full <= '1' when
    (in_rptr_s(DEPTH_LOG2-1 downto 0) = in_wptr_s(DEPTH_LOG2-1 downto 0))
    and (in_rptr_s(DEPTH_LOG2) /= in_wptr_s(DEPTH_LOG2))
    else '0';

  -- Generate the FIFO write enable signal. We write when the input data is
  -- valid and the FIFO is not full.
  in_next <= in_valid and not in_full;

  -- Forward the FIFO write enable signal to the input stream.
  in_ready <= in_next;

  -- Forward the internal copies of the read and write pointers.
  in_rptr <= in_rptr_s;
  in_wptr <= in_wptr_s;

  -- Instantiate the write pointer counter.
  wptr_inst: StreamFIFOCounter
    generic map (
      DEPTH_LOG2                => DEPTH_LOG2,
      XCLK_STAGES               => XCLK_STAGES
    )
    port map (
      a_clk                     => in_clk,
      a_reset                   => in_reset,
      a_increment               => in_next,
      a_counter                 => in_wptr_s,
      b_clk                     => out_clk,
      b_reset                   => out_reset,
      b_counter                 => out_wptr_s
    );

  -- Instantiate the dual-port RAM representing the FIFO contents.
  ram_inst: Ram1R1W
    generic map (
      WIDTH                     => DATA_WIDTH,
      DEPTH_LOG2                => DEPTH_LOG2,
      RAM_CONFIG                => RAM_CONFIG
    )
    port map (
      w_clk                     => in_clk,
      w_ena                     => in_next,
      w_addr                    => in_wptr_s(DEPTH_LOG2-1 downto 0),
      w_data                    => in_data,
      r_clk                     => out_clk,
      r_ena                     => out_next,
      r_addr                    => out_rptr_s(DEPTH_LOG2-1 downto 0),
      r_data                    => out_readData
    );

  -- Generate the read data valid flag.
  read_valid_reg_proc: process (out_clk) is
  begin
    if rising_edge(out_clk) then
      if out_reset = '1' then
        out_readValid <= '0';
      else
        out_readValid <= out_next;
      end if;
    end if;
  end process;

  -- Instantiate the read pointer counter.
  rptr_inst: StreamFIFOCounter
    generic map (
      DEPTH_LOG2                => DEPTH_LOG2,
      XCLK_STAGES               => XCLK_STAGES
    )
    port map (
      a_clk                     => out_clk,
      a_reset                   => out_reset,
      a_increment               => out_next,
      a_counter                 => out_rptr_s,
      b_clk                     => in_clk,
      b_reset                   => in_reset,
      b_counter                 => in_rptr_s
    );

  -- Forward the internal copies of the read and write pointers.
  out_rptr <= out_rptr_s;
  out_wptr <= out_wptr_s;

  -- Generate the FIFO nonempty signal. This is the case when the read and
  -- write pointers differ.
  out_nonEmpty <= '1' when out_rptr_s /= out_wptr_s else '0';

  -- We can read the next FIFO entry when the FIFO is not empty and either
  -- we're not fetching or buffering any data word yet or we won't be in the
  -- next cycle because the output stream is ready.
  out_next <= out_nonEmpty and (out_ready or not (out_bufValid or out_readValid));

  -- Instantiate the data buffer.
  data_buf_proc: process (out_clk) is
  begin
    if rising_edge(out_clk) then

      -- When the RAM read data is valid, write it to the buffer...
      if out_readValid = '1' then
        out_bufData <= out_readData;
        out_bufValid <= '1';
      end if;

      -- ... unless it is already being read by the stream right now, or if
      -- we're resetting.
      if out_reset = '1' or out_ready = '1' then
        out_bufValid <= '0';
      end if;

    end if;
  end process;

  -- Assign the outgoing stream data and valid signals.
  out_data <= out_bufData when out_bufValid = '1' else out_readData;
  out_valid <= out_bufValid or out_readValid;

end Behavioral;

