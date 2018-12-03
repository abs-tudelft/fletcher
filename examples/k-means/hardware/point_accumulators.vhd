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

entity point_accumulators is
  generic(
    DIMENSION         : natural;
    CENTROIDS         : natural;
    DATA_WIDTH        : natural;
    ACCUMULATOR_WIDTH : natural
  );
  port(
    reset             : in  std_logic;
    clk               : in  std_logic;
    -------------------------------------------------------------------------
    point_data        : in  std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);
    point_centroid    : in  std_logic_vector(log2ceil(CENTROIDS)-1 downto 0);
    point_valid       : in  std_logic;
    point_ready       : out std_logic;
    point_last        : in  std_logic;
    accum_data        : out std_logic_vector(ACCUMULATOR_WIDTH * DIMENSION * CENTROIDS - 1 downto 0);
    accum_counters    : out std_logic_vector(ACCUMULATOR_WIDTH * CENTROIDS - 1 downto 0);
    accum_valid       : out std_logic
  );
end entity point_accumulators;


architecture behavior of point_accumulators is

  component accumulator is
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
  end component;

  component axi_funnel is
    generic(
      SLAVES          : natural;
      DATA_WIDTH      : natural
    );
    port(
      reset           : in  std_logic;
      clk             : in  std_logic;
      -------------------------------------------------------------------------
      in_data         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      in_valid        : in  std_logic;
      in_ready        : out std_logic;
      in_last         : in  std_logic;
      out_data        : out std_logic_vector(DATA_WIDTH-1 downto 0);
      out_valid       : out std_logic_vector(SLAVES-1 downto 0);
      out_ready       : in  std_logic_vector(SLAVES-1 downto 0);
      out_last        : out std_logic_vector(SLAVES-1 downto 0)
    );
  end component;

  signal centr_valid,
         centr_ready,
         centr_last : std_logic_vector(DIMENSION downto 0);
  signal centr_data : std_logic_vector(DIMENSION * DATA_WIDTH - 1 downto 0);

  type cdim_t is array (0 to CENTROIDS-1) of std_logic_vector(DIMENSION downto 0);
  signal cdim_ready,
         cdim_valid,
         cdim_last,
         accum_last : cdim_t;

begin

  select_centroid: process (point_centroid, centr_valid, cdim_ready, centr_last, accum_last)
  begin
    accum_valid <= '0';
    for C in 0 to CENTROIDS-1 loop
      -- Connect bus to the right centroid
      cdim_last(C) <= centr_last;
      if unsigned(point_centroid) = C then
        cdim_valid(C) <= centr_valid;
        centr_ready   <= cdim_ready(C);
      else
        cdim_valid(C) <= (others => '0');
      end if;

      -- Detection of last point
      if (unsigned(not accum_last(C)) = 0) then
        accum_valid <= '1';
      end if;
    end loop;
  end process;

  accum_funnel_l: axi_funnel generic map (
    SLAVES          => DIMENSION + 1,
    DATA_WIDTH      => DATA_WIDTH * DIMENSION
  )
  port map (
    reset           => reset,
    clk             => clk,
    in_data         => point_data,
    in_valid        => point_valid,
    in_ready        => point_ready,
    in_last         => point_last,
    out_data        => centr_data,
    out_valid       => centr_valid,
    out_ready       => centr_ready,
    out_last        => centr_last
  );

  centroids_g: for C in 0 to CENTROIDS-1 generate

    accumulator_inst_count: accumulator generic map(
      DATA_WIDTH        => 2,
      ACCUMULATOR_WIDTH => ACCUMULATOR_WIDTH
    )
    port map (
      reset             => reset,
      clk               => clk,
      point_data        => "01",
      point_valid       => cdim_valid(C)(DIMENSION),
      point_ready       => cdim_ready(C)(DIMENSION),
      point_last        => cdim_last(C)(DIMENSION),
      sum_data          => accum_counters((C + 1) * ACCUMULATOR_WIDTH - 1 downto C * ACCUMULATOR_WIDTH),
      sum_last          => accum_last(C)(DIMENSION)
    );

    dimension_g: for D in 0 to DIMENSION-1 generate

      accumulator_inst_point: accumulator generic map (
        DATA_WIDTH        => DATA_WIDTH,
        ACCUMULATOR_WIDTH => ACCUMULATOR_WIDTH
      )
      port map (
        reset             => reset,
        clk               => clk,
        point_data        => centr_data((D + 1) * DATA_WIDTH - 1 downto D * DATA_WIDTH),
        point_valid       => cdim_valid(C)(D),
        point_ready       => cdim_ready(C)(D),
        point_last        => cdim_last(C)(D),
        sum_data          => accum_data((C * DIMENSION + D + 1) * ACCUMULATOR_WIDTH - 1 downto (C * DIMENSION + D) * ACCUMULATOR_WIDTH),
        sum_last          => accum_last(C)(D)
      );

    end generate;

  end generate;

end architecture;

