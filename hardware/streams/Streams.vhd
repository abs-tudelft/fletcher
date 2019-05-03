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

package Streams is

  -----------------------------------------------------------------------------
  -- Component declarations for buffer-like stream primitives
  -----------------------------------------------------------------------------
  component StreamSlice is
    generic (
      DATA_WIDTH                : natural
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

  component StreamFIFOCounter is
    generic (
      DEPTH_LOG2                : natural;
      XCLK_STAGES               : natural := 0
    );
    port (
      a_clk                     : in  std_logic;
      a_reset                   : in  std_logic;
      a_increment               : in  std_logic;
      a_counter                 : out std_logic_vector(DEPTH_LOG2 downto 0);
      b_clk                     : in  std_logic;
      b_reset                   : in  std_logic;
      b_counter                 : out std_logic_vector(DEPTH_LOG2 downto 0)
    );
  end component;

  component StreamFIFO is
    generic (
      DEPTH_LOG2                : natural;
      DATA_WIDTH                : natural;
      XCLK_STAGES               : natural := 0;
      RAM_CONFIG                : string := ""
    );
    port (
      in_clk                    : in  std_logic;
      in_reset                  : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      in_rptr                   : out std_logic_vector(DEPTH_LOG2 downto 0);
      in_wptr                   : out std_logic_vector(DEPTH_LOG2 downto 0);
      out_clk                   : in  std_logic;
      out_reset                 : in  std_logic;
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      out_rptr                  : out std_logic_vector(DEPTH_LOG2 downto 0);
      out_wptr                  : out std_logic_vector(DEPTH_LOG2 downto 0)
    );
  end component;

  component StreamBuffer is
    generic (
      MIN_DEPTH                 : natural;
      DATA_WIDTH                : natural;
      RAM_CONFIG                : string := ""
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

  -----------------------------------------------------------------------------
  -- Component declarations for split & merge stream primitives
  -----------------------------------------------------------------------------
  component StreamSync is
    generic (
      NUM_INPUTS                : natural := 1;
      NUM_OUTPUTS               : natural := 1
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic_vector(NUM_INPUTS-1 downto 0);
      in_ready                  : out std_logic_vector(NUM_INPUTS-1 downto 0);
      in_advance                : in  std_logic_vector(NUM_INPUTS-1 downto 0) := (others => '1');
      in_use                    : in  std_logic_vector(NUM_INPUTS-1 downto 0) := (others => '1');
      out_valid                 : out std_logic_vector(NUM_OUTPUTS-1 downto 0);
      out_ready                 : in  std_logic_vector(NUM_OUTPUTS-1 downto 0);
      out_enable                : in  std_logic_vector(NUM_OUTPUTS-1 downto 0) := (others => '1')
    );
  end component;

  component StreamArb is
    generic (
      NUM_INPUTS                : natural;
      INDEX_WIDTH               : natural;
      DATA_WIDTH                : natural;
      ARB_METHOD                : string := "ROUND-ROBIN"
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic_vector(NUM_INPUTS-1 downto 0);
      in_ready                  : out std_logic_vector(NUM_INPUTS-1 downto 0);
      in_data                   : in  std_logic_vector(NUM_INPUTS*DATA_WIDTH-1 downto 0);
      in_last                   : in  std_logic_vector(NUM_INPUTS-1 downto 0) := (others => '1');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      out_last                  : out std_logic;
      out_index                 : out std_logic_vector(INDEX_WIDTH-1 downto 0)
    );
  end component;

  -----------------------------------------------------------------------------
  -- Component declarations for pipeline(d) logic
  -----------------------------------------------------------------------------
  component StreamPipelineControl is
    generic (
      IN_DATA_WIDTH               : natural;
      OUT_DATA_WIDTH              : natural;
      NUM_PIPE_REGS               : natural;
      MIN_CYCLES_PER_TRANSFER     : positive := 1;
      INPUT_SLICE                 : boolean := false;
      RAM_CONFIG                  : string := ""
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      in_valid                    : in  std_logic;
      in_ready                    : out std_logic;
      in_data                     : in  std_logic_vector(IN_DATA_WIDTH-1 downto 0);
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_data                    : out std_logic_vector(OUT_DATA_WIDTH-1 downto 0);
      pipe_stall                  : in  std_logic := '0';
      pipe_insert                 : in  std_logic := '0';
      pipe_delete                 : in  std_logic := '0';
      pipe_valid                  : out std_logic_vector(0 to NUM_PIPE_REGS);
      pipe_input                  : out std_logic_vector(IN_DATA_WIDTH-1 downto 0);
      pipe_output                 : in  std_logic_vector(OUT_DATA_WIDTH-1 downto 0)
    );
  end component;

  component StreamPipelineBarrel is
    generic (
      ELEMENT_WIDTH               : natural := 1;
      ELEMENT_COUNT               : natural;
      AMOUNT_WIDTH                : natural;
      DIRECTION                   : string := "left";
      OPERATION                   : string := "rotate";
      NUM_STAGES                  : positive;
      CTRL_WIDTH                  : natural := 1
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      in_data                     : in  std_logic_vector(ELEMENT_COUNT*ELEMENT_WIDTH-1 downto 0);
      in_ctrl                     : in  std_logic_vector(CTRL_WIDTH-1 downto 0) := (others => '0');
      in_amount                   : in  std_logic_vector(AMOUNT_WIDTH-1 downto 0);
      out_data                    : out std_logic_vector(ELEMENT_COUNT*ELEMENT_WIDTH-1 downto 0);
      out_ctrl                    : out std_logic_vector(CTRL_WIDTH-1 downto 0)
    );
  end component;

  -----------------------------------------------------------------------------
  -- Component declarations for stream reshapers
  -----------------------------------------------------------------------------
  component StreamSerializer is
    generic (
      DATA_WIDTH                : natural;
      CTRL_WIDTH                : natural := 0;
      IN_COUNT_MAX              : natural;
      IN_COUNT_WIDTH            : natural;
      OUT_COUNT_MAX             : natural := 1;
      OUT_COUNT_WIDTH           : natural := 1
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(CTRL_WIDTH+IN_COUNT_MAX*DATA_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(IN_COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(IN_COUNT_MAX, IN_COUNT_WIDTH));
      in_last                   : in  std_logic := '1';
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(CTRL_WIDTH+OUT_COUNT_MAX*DATA_WIDTH-1 downto 0);
      out_count                 : out std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
      out_last                  : out std_logic
    );
  end component;

  component StreamParallelizer is
    generic (
      DATA_WIDTH                : natural;
      CTRL_WIDTH                : natural := 0;
      IN_COUNT_MAX              : natural := 1;
      IN_COUNT_WIDTH            : natural := 1;
      OUT_COUNT_MAX             : natural;
      OUT_COUNT_WIDTH           : natural
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(CTRL_WIDTH+IN_COUNT_MAX*DATA_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(IN_COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(IN_COUNT_MAX, IN_COUNT_WIDTH));
      in_last                   : in  std_logic := '0';
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(CTRL_WIDTH+OUT_COUNT_MAX*DATA_WIDTH-1 downto 0);
      out_count                 : out std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
      out_last                  : out std_logic
    );
  end component;

  component StreamGearbox is
    generic (
      DATA_WIDTH                : natural;
      CTRL_WIDTH                : natural := 0;
      IN_COUNT_MAX              : natural := 1;
      IN_COUNT_WIDTH            : natural := 1;
      OUT_COUNT_MAX             : natural := 1;
      OUT_COUNT_WIDTH           : natural := 1
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(CTRL_WIDTH+IN_COUNT_MAX*DATA_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(IN_COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(IN_COUNT_MAX, IN_COUNT_WIDTH));
      in_last                   : in  std_logic := '0';
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(CTRL_WIDTH+OUT_COUNT_MAX*DATA_WIDTH-1 downto 0);
      out_count                 : out std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
      out_last                  : out std_logic
    );
  end component;

  component StreamNormalizer is
    generic (
      ELEMENT_WIDTH             : natural;
      COUNT_MAX                 : natural;
      COUNT_WIDTH               : natural;
      REQ_COUNT_WIDTH           : natural
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_dvalid                 : in  std_logic := '1';
      in_data                   : in  std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
      in_last                   : in  std_logic := '0';
      req_count                 : in  std_logic_vector(REQ_COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, REQ_COUNT_WIDTH));
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_dvalid                : out std_logic;
      out_data                  : out std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      out_count                 : out std_logic_vector(COUNT_WIDTH-1 downto 0);
      out_last                  : out std_logic
    );
  end component;

  component StreamReshaper is
    generic (
      ELEMENT_WIDTH               : natural;
      IN_COUNT_MAX                : natural := 1;
      IN_COUNT_WIDTH              : natural := 1;
      OUT_COUNT_MAX               : natural := 1;
      OUT_COUNT_WIDTH             : natural := 1;
      DIN_BUFFER_DEPTH            : natural := 2;
      CIN_BUFFER_DEPTH            : natural := 2;
      CTRL_WIDTH                  : natural := 1;
      RAM_CONFIG                  : string := "";
      SHIFTS_PER_STAGE            : natural := 3
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      din_valid                   : in  std_logic;
      din_ready                   : out std_logic;
      din_dvalid                  : in  std_logic := '1';
      din_data                    : in  std_logic_vector(IN_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      din_count                   : in  std_logic_vector(IN_COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(IN_COUNT_MAX, IN_COUNT_WIDTH));
      din_last                    : in  std_logic := '0';
      cin_valid                   : in  std_logic := '1';
      cin_ready                   : out std_logic;
      cin_dvalid                  : in  std_logic := '1';
      cin_count                   : in  std_logic_vector(OUT_COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(OUT_COUNT_MAX, OUT_COUNT_WIDTH));
      cin_last                    : in  std_logic := '0';
      cin_ctrl                    : in  std_logic_vector(CTRL_WIDTH-1 downto 0) := (others => '0');
      error_strobe                : out std_logic;
      out_valid                   : out std_logic;
      out_ready                   : in  std_logic;
      out_dvalid                  : out std_logic;
      out_data                    : out std_logic_vector(OUT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      out_count                   : out std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
      out_last                    : out std_logic;
      out_ctrl                    : out std_logic_vector(CTRL_WIDTH-1 downto 0)
    );
  end component;

  -----------------------------------------------------------------------------
  -- Component declarations for stream arithmetic
  -----------------------------------------------------------------------------
  component StreamElementCounter is
    generic (
      IN_COUNT_WIDTH            : positive;
      IN_COUNT_MAX              : positive;
      OUT_COUNT_WIDTH           : positive;
      OUT_COUNT_MAX             : positive
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_last                   : in  std_logic;
      in_count                  : in  std_logic_vector(IN_COUNT_WIDTH-1 downto 0);
      in_dvalid                 : in  std_logic := '1';
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_count                 : out std_logic_vector(OUT_COUNT_WIDTH-1 downto 0);
      out_last                  : out std_logic
    );
  end component;

  component StreamAccumulator is
    generic (
      DATA_WIDTH                : positive;
      CTRL_WIDTH                : natural;
      IS_SIGNED                 : boolean
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(CTRL_WIDTH + DATA_WIDTH-1 downto 0);
      in_skip                   : in  std_logic;
      in_clear                  : in  std_logic;
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(CTRL_WIDTH + DATA_WIDTH-1 downto 0)

    );
  end component;

  component StreamPrefixSum is
    generic (
      DATA_WIDTH                : natural;
      COUNT_MAX                 : natural;
      COUNT_WIDTH               : natural;
      CTRL_WIDTH                : natural  := 1;
      LOOPBACK                  : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_clear                  : in  std_logic := '0';
      in_initial                : in  std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      in_data                   : in  std_logic_vector(COUNT_MAX*DATA_WIDTH-1 downto 0);
      in_ctrl                   : in  std_logic_vector(CTRL_WIDTH-1 downto 0) := (others => '0');
      in_count                  : in  std_logic_vector(COUNT_WIDTH-1 downto 0);
      in_last                   : in  std_logic;
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(COUNT_MAX*DATA_WIDTH-1 downto 0);
      out_ctrl                  : out std_logic_vector(CTRL_WIDTH-1 downto 0);
      out_count                 : out std_logic_vector(COUNT_WIDTH-1 downto 0);
      out_last                  : out std_logic
    );
  end component;

  component StreamPseudoRandomGenerator is
    generic (
      DATA_WIDTH                : positive
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      seed                      : in  std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

  -----------------------------------------------------------------------------
  -- Helper functions
  -----------------------------------------------------------------------------
  -- Resizes a count vector using the semantics of the Serializer,
  -- Parallelizer, and Gearbox components. That is, upsizing a vector that is
  -- zero results in the implicit '1' MSB being made explicit.
  function resize_count(
    cnt   : std_logic_vector;
    size  : natural
  ) return std_logic_vector;

end Streams;

package body Streams is

  function resize_count(
    cnt   : std_logic_vector;
    size  : natural
  ) return std_logic_vector is
    variable norm : std_logic_vector(cnt'length-1 downto 0);
    variable res  : std_logic_vector(size-1 downto 0);
  begin
    norm := cnt;
    if size > cnt'length then
      res := (others => '0');
      res(cnt'length-1 downto 0) := norm;
      res(cnt'length) := not or_reduce(cnt);
    else
      res := norm(size-1 downto 0);
    end if;
    return res;
  end function;

end Streams;
