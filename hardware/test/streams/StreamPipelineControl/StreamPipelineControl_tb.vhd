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
use work.StreamSim.all;

entity StreamPipelineControl_tb is
  generic (
    NUM_PIPE_REGS               : natural;
    MIN_CYCLES_PER_TRANSFER     : positive := 1;
    INPUT_SLICE                 : boolean := false
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic
  );
end StreamPipelineControl_tb;

architecture TestBench of StreamPipelineControl_tb is

  constant DATA_WIDTH           : natural := 8;

  signal valid_a                : std_logic;
  signal ready_a                : std_logic;
  signal data_a                 : std_logic_vector(DATA_WIDTH-1 downto 0);

  signal valid_b                : std_logic;
  signal ready_b                : std_logic;
  signal data_b                 : std_logic_vector(DATA_WIDTH-1 downto 0);

  signal pipe_stall             : std_logic;
  signal pipe_insert            : std_logic;
  signal pipe_delete            : std_logic;
  signal pipe_valid             : std_logic_vector(0 to NUM_PIPE_REGS);
  signal pipe_input             : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal pipe_output            : std_logic_vector(DATA_WIDTH-1 downto 0);

  type stage_reg_array is array (natural range <>) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal stage_regs             : stage_reg_array(1 to NUM_PIPE_REGS);

begin

  prod_a: StreamTbProd
    generic map (
      DATA_WIDTH                => DATA_WIDTH,
      SEED                      => 1,
      NAME                      => "a"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => valid_a,
      out_ready                 => ready_a,
      out_data                  => data_a
    );

  uut: StreamPipelineControl
    generic map (
      IN_DATA_WIDTH             => DATA_WIDTH,
      OUT_DATA_WIDTH            => DATA_WIDTH,
      NUM_PIPE_REGS             => NUM_PIPE_REGS,
      MIN_CYCLES_PER_TRANSFER   => MIN_CYCLES_PER_TRANSFER,
      INPUT_SLICE               => INPUT_SLICE
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_a,
      in_ready                  => ready_a,
      in_data                   => data_a,
      out_valid                 => valid_b,
      out_ready                 => ready_b,
      out_data                  => data_b,
      pipe_stall                => pipe_stall,
      pipe_insert               => pipe_insert,
      pipe_delete               => pipe_delete,
      pipe_valid                => pipe_valid,
      pipe_input                => pipe_input,
      pipe_output               => pipe_output
    );

  stage_reg_proc: process (clk) is
  begin
    if rising_edge(clk) then
      stage_regs(1) <= pipe_input;
      stage_regs(2 to NUM_PIPE_REGS) <= stage_regs(1 to NUM_PIPE_REGS - 1);
      if reset = '1' then
        stage_regs <= (others => (others => 'U'));
      else
        for i in 1 to NUM_PIPE_REGS loop
          if pipe_valid(i) = '1' then
            assert not is_X(stage_regs(i))
              report "Stage data is X while valid is high"
              severity failure;
          end if;
        end loop;
      end if;
    end if;
  end process;

  pipe_output <= stage_regs(stage_regs'HIGH);

  -- TODO: these signals should probably be tested somewhere.
  pipe_stall  <= '0';
  pipe_insert <= '0';
  pipe_delete <= '0';

  cons_b: StreamTbCons
    generic map (
      DATA_WIDTH                => DATA_WIDTH,
      SEED                      => 2,
      NAME                      => "b"
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => valid_b,
      in_ready                  => ready_b,
      in_data                   => data_b
    );

end TestBench;

