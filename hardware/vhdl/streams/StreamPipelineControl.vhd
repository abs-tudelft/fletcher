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

-- This unit provides the control logic for a custom pipeline performing
-- operations on a datastream, abstracting handshaking and buffering away from
-- the functional behavior of the pipeline. For a simple stateless pipeline,
-- the user only needs to insert the pipeline stage registers and the requisite
-- combinatorial logic between them. The following more advanced features are
-- optional:
--
--  - If inter-transfer state storage is necessary, the pipe_valid signal must
--    be used as a write-enable signal to prevent bubbles in the pipeline from
--    corrupting data.
--  - Resource sharing between pipeline stages is possible by setting the
--    MIN_CYCLES_PER_TRANSFER generic to more than one, which guarantees that
--    MIN_CYCLES_PER_TRANSFER-1 bubbles are inserted between valid data
--    transfers. That means that combinatorial logic can be shared between
--    MIN_CYCLES_PER_TRANSFER consecutive stages.
--  - Multi-cycle logic required between data transfers can be implemented
--    using the pipe_stall input.
--  - The first pipeline stage can request insertion of data into the stream
--    through the pipe_insert signal. When this signal is asserted, no data
--    is popped from the incoming stream.
--  - The last pipeline stage can request deletion of data (either from the
--    input stream or inserted using pipe_insert) using pipe_delete. When this
--    signal is asserted, the data is discarded before entering the FIFO.

entity StreamPipelineControl is
  generic (

    -- Width of the input stream data vector.
    IN_DATA_WIDTH               : natural;

    -- Width of the output stream data vector.
    OUT_DATA_WIDTH              : natural;

    -- Number of pipeline stage registers.
    NUM_PIPE_REGS               : natural;

    -- Minimum number of cycles per transfer. When set to more than one,
    -- pipe_valid(1) is set at most once every MIN_CYCLES_PER_TRANSFER cycles.
    -- This can be used for implementing resource sharing. pipe_stall can also
    -- be used instead of this to limit the rate, but specifying it here allows
    -- this unit to reduce the FIFO size.
    MIN_CYCLES_PER_TRANSFER     : positive := 1;

    -- Whether to insert a slice between the input stream and the first
    -- pipeline stage.
    INPUT_SLICE                 : boolean := false;

    -- RAM configuration. This is passed directly to the Ram1R1W instance used
    -- for the FIFO.
    RAM_CONFIG                  : string := ""

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(IN_DATA_WIDTH-1 downto 0);

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(OUT_DATA_WIDTH-1 downto 0);

    -- When set, pipe_valid(0) is guaranteed to be low in the next cycle.
    pipe_stall                  : in  std_logic := '0';

    -- When set by the pipeline, pipe_valid(0) will be asserted without taking
    -- a transfer from the input stream when all conditions except input stream
    -- validity are met.
    pipe_insert                 : in  std_logic := '0';

    -- When set by the pipeline, the accompanying pipe_output data will not be
    -- sent to the output stream.
    pipe_delete                 : in  std_logic := '0';

    -- Pipeline stage data valid output. pipe_valid(0) corresponds with the
    -- validity of pipe_input, while pipe_valid(NUM_PIPE_REGS) corresponds with
    -- pipe_output. This value shifts right (increasing indices) each cycle.
    pipe_valid                  : out std_logic_vector(0 to NUM_PIPE_REGS);

    -- Input to the pipeline, valid when pipe_valid(0) is set and pipe_insert
    -- is not set.
    pipe_input                  : out std_logic_vector(IN_DATA_WIDTH-1 downto 0);

    -- Pipeline output, sampled when pipe_valid(NUM_PIPE_REGS) is set and
    -- pipe_delete is not set. When delete is asserted, the transfer is not
    -- propagated.
    pipe_output                 : in  std_logic_vector(OUT_DATA_WIDTH-1 downto 0)

  );
end StreamPipelineControl;

architecture Behavioral of StreamPipelineControl is

  -- Optionally reg-sliced input stream.
  signal inS_valid              : std_logic;
  signal inS_ready              : std_logic;
  signal inS_data               : std_logic_vector(IN_DATA_WIDTH-1 downto 0);

  -- Pipeline write enable shift register.
  constant PIPE_VALID_SR_HIGH   : natural := work.utils.max(work.utils.max(NUM_PIPE_REGS, MIN_CYCLES_PER_TRANSFER), 1);
  signal pipe_valid_s           : std_logic_vector(0 to PIPE_VALID_SR_HIGH);

  -- Rate limiter.
  signal rate_limiter           : std_logic;

  -- Buffer sizing logic. The buffer must be at least large enough to absorb
  -- the contents of the pipeline registers in the worst case, should the
  -- output stream suddenly block for a long time. In practice it'll be larger
  -- because this value is rounded upward a few times.
  constant MIN_FIFO_DEPTH       : natural := (NUM_PIPE_REGS + MIN_CYCLES_PER_TRANSFER) / MIN_CYCLES_PER_TRANSFER;
  constant FIFO_DEPTH_LOG2      : natural := log2ceil(MIN_FIFO_DEPTH)+1;
  constant REQ_FIFO_DEPTH       : natural := 2**FIFO_DEPTH_LOG2;
  signal fifo_reserved          : unsigned(FIFO_DEPTH_LOG2 downto 0);

  -- FIFO push signal.
  signal fifo_push              : std_logic;

  -- Local copy of the valid output.
  signal out_valid_s            : std_logic;

begin

  -- Optional input slice.
  input_slice_gen: if INPUT_SLICE generate
  begin
    slice_inst: StreamSlice
      generic map (
        DATA_WIDTH              => IN_DATA_WIDTH
      )
      port map (
        clk                     => clk,
        reset                   => reset,
        in_valid                => in_valid,
        in_ready                => in_ready,
        in_data                 => in_data,
        out_valid               => inS_valid,
        out_ready               => inS_ready,
        out_data                => inS_data
      );
  end generate;
  no_input_slice_gen: if not INPUT_SLICE generate
  begin
    inS_valid <= in_valid;
    in_ready  <= inS_ready;
    inS_data  <= in_data;
  end generate;

  pipe_input <= inS_data;
  inS_ready <= pipe_valid_s(0) and not pipe_insert;

  -- Generate pipeline write enable shift register.
  pipe_valid_s(0) <= (inS_valid or pipe_insert)           -- Check input stream validity/requirement.
                and not fifo_reserved(fifo_reserved'HIGH) -- FIFO must have space available.
                and not rate_limiter                      -- Rate limiter must not be active.
                and not pipe_stall;                       -- Pipeline must not be stalled.

  pipe_valid_r_proc: process (clk) is
  begin
    if rising_edge(clk) then
      pipe_valid_s(1 to PIPE_VALID_SR_HIGH) <= pipe_valid_s(0 to PIPE_VALID_SR_HIGH-1);
      if reset = '1' then
        pipe_valid_s(1 to PIPE_VALID_SR_HIGH) <= (others => '0');
      end if;
    end if;
  end process;

  pipe_valid <= pipe_valid_s(0 to NUM_PIPE_REGS);

  -- Generate the rate limiter by blocking when any of the MIN_CYCLES_PER_TRANSFER-1
  -- previous write enables are set.
  rate_limiter_proc: process (pipe_valid_s) is
  begin
    rate_limiter <= '0';
    for i in 1 to MIN_CYCLES_PER_TRANSFER - 1 loop
      if pipe_valid_s(i) = '1' then
        rate_limiter <= '1';
      end if;
    end loop;
  end process;

  -- Generate the FIFO reservation counter. This counts how many items are in
  -- the buffer AND in the pipeline. As long as this value stays less than or
  -- equal to the buffer size, backpressure can never result in data loss.
  fifo_reservation_proc: process (clk) is
    variable fifo_reserved_v    : unsigned(FIFO_DEPTH_LOG2 downto 0);
  begin
    if rising_edge(clk) then
      fifo_reserved_v := fifo_reserved;
      if pipe_valid_s(0) = '1' then
        assert fifo_reserved_v(fifo_reserved_v'HIGH) = '0'
          report "FIFO overflow possible!" severity failure;
        fifo_reserved_v := fifo_reserved_v + 1;
      end if;
      if out_valid_s = '1' and out_ready = '1' then
        assert fifo_reserved_v > 0
          report "FIFO underflow possible!" severity failure;
        fifo_reserved_v := fifo_reserved_v - 1;
      end if;
      if pipe_valid_s(pipe_valid_s'HIGH) = '1' and pipe_delete = '1' then
        assert fifo_reserved_v > 0
          report "FIFO underflow possible!" severity failure;
        fifo_reserved_v := fifo_reserved_v - 1;
      end if;
      if reset = '1' then
        fifo_reserved_v := (others => '0');
      end if;
      fifo_reserved <= fifo_reserved_v;
    end if;
  end process;

  -- Determine when we need to push data into the FIFO.
  fifo_push <= pipe_valid_s(pipe_valid_s'HIGH) and not pipe_delete;

  -- Generate the output buffer.
  output_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                 => REQ_FIFO_DEPTH,
      DATA_WIDTH                => OUT_DATA_WIDTH,
      RAM_CONFIG                => RAM_CONFIG
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => fifo_push,
      in_ready                  => open,
      in_data                   => pipe_output,
      out_valid                 => out_valid_s,
      out_ready                 => out_ready,
      out_data                  => out_data
    );

  out_valid <= out_valid_s;

end Behavioral;

