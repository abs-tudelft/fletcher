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

entity distance is
    generic(
      DIMENSION       : natural;
      DATA_WIDTH      : natural
    );
    port(
      reset           : in std_logic;
      clk             : in std_logic;
      -------------------------------------------------------------------------
      centroid        : in std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);
      point_data      : in std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);
      point_valid     : in std_logic;
      point_ready     : out std_logic;
      point_last      : in std_logic;
      distance_data   : out std_logic_vector(DATA_WIDTH-1 downto 0);
      distance_valid  : out std_logic;
      distance_ready  : in std_logic;
      distance_last   : out std_logic
    );
end entity distance;


architecture behavior of distance is

  COMPONENT floating_point_sub_double
    PORT (
      aclk : IN STD_LOGIC;
      aresetn : IN STD_LOGIC;
      s_axis_a_tvalid : IN STD_LOGIC;
      s_axis_a_tready : OUT STD_LOGIC;
      s_axis_a_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      s_axis_a_tlast : IN STD_LOGIC;
      s_axis_b_tvalid : IN STD_LOGIC;
      s_axis_b_tready : OUT STD_LOGIC;
      s_axis_b_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      m_axis_result_tvalid : OUT STD_LOGIC;
      m_axis_result_tready : IN STD_LOGIC;
      m_axis_result_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      m_axis_result_tlast : OUT STD_LOGIC
    );
  END COMPONENT;

  COMPONENT floating_point_mult_double
    PORT (
      aclk : IN STD_LOGIC;
      aresetn : IN STD_LOGIC;
      s_axis_a_tvalid : IN STD_LOGIC;
      s_axis_a_tready : OUT STD_LOGIC;
      s_axis_a_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      s_axis_a_tlast : IN STD_LOGIC;
      s_axis_b_tvalid : IN STD_LOGIC;
      s_axis_b_tready : OUT STD_LOGIC;
      s_axis_b_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      m_axis_result_tvalid : OUT STD_LOGIC;
      m_axis_result_tready : IN STD_LOGIC;
      m_axis_result_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      m_axis_result_tlast : OUT STD_LOGIC
    );
  END COMPONENT;

  COMPONENT floating_point_add_double
    PORT (
      aclk : IN STD_LOGIC;
      aresetn : IN STD_LOGIC;
      s_axis_a_tvalid : IN STD_LOGIC;
      s_axis_a_tready : OUT STD_LOGIC;
      s_axis_a_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      s_axis_a_tlast : IN STD_LOGIC;
      s_axis_b_tvalid : IN STD_LOGIC;
      s_axis_b_tready : OUT STD_LOGIC;
      s_axis_b_tdata : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
      s_axis_b_tlast : IN STD_LOGIC;
      m_axis_result_tvalid : OUT STD_LOGIC;
      m_axis_result_tready : IN STD_LOGIC;
      m_axis_result_tdata : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
      m_axis_result_tlast : OUT STD_LOGIC
    );
  END COMPONENT;

  component axi_funnel is
    generic(
      SLAVES          : natural;
      DATA_WIDTH      : natural
    );
    port(
      reset           : in std_logic;
      clk             : in std_logic;
      -------------------------------------------------------------------------
      in_data         : in std_logic_vector(DATA_WIDTH-1 downto 0);
      in_valid        : in std_logic;
      in_ready        : out std_logic;
      in_last         : in std_logic;
      out_data        : out std_logic_vector(DATA_WIDTH-1 downto 0);
      out_valid       : out std_logic_vector(SLAVES-1 downto 0);
      out_ready       : in std_logic_vector(SLAVES-1 downto 0);
      out_last        : out std_logic_vector(SLAVES-1 downto 0)
    );
  end component;

  type axi_t is record
    valid : std_logic;
    ready : std_logic;
    last  : std_logic;
    data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  end record axi_t;

  signal point_valid_split,
         point_ready_split,
         point_last_split : std_logic_vector(DIMENSION-1 downto 0);
  signal point_data_split : std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);

  type data_array_t is array (0 to DIMENSION-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal diff_valid : std_logic_vector(DIMENSION-1 downto 0);
  signal diff_ready : std_logic_vector(DIMENSION-1 downto 0);
  signal diff_last  : std_logic_vector(DIMENSION-1 downto 0);
  signal diff_data  : data_array_t;

  type split_array_t is array (0 to DIMENSION-1) of std_logic_vector(1 downto 0);
  signal diff_split_valid : split_array_t;
  signal diff_split_ready : split_array_t;
  signal diff_split_last  : split_array_t;
  signal diff_split_data  : data_array_t;

  type squares_t is array (0 to DIMENSION-1) of axi_t;
  signal squares : squares_t;

  type sum_lvl_t is array (0 to DIMENSION-1) of axi_t;
  type sum_tree_t is array (0 to log2ceil(DIMENSION)) of sum_lvl_t;
  signal sum_tree : sum_tree_t;
begin

  dim_split: axi_funnel
  generic map (
    SLAVES => DIMENSION,
    DATA_WIDTH => DATA_WIDTH * DIMENSION
  )
  port map (
    reset     => reset,
    clk       => clk,
    in_data   => point_data,
    in_valid  => point_valid,
    in_ready  => point_ready,
    in_last   => point_last,
    out_data  => point_data_split,
    out_valid => point_valid_split,
    out_ready => point_ready_split,
    out_last  => point_last_split
  );

  dim_gen: for D in 0 to DIMENSION-1 generate
    -- Single dimension distance
    dsub: floating_point_sub_double port map (
      aclk => clk,
      aresetn => not reset,
      s_axis_a_tvalid => point_valid_split(D),
      s_axis_a_tready => point_ready_split(D),
      s_axis_a_tdata  => point_data_split((D+1) * DATA_WIDTH - 1 downto D * DATA_WIDTH),
      s_axis_a_tlast  => point_last_split(D),

      s_axis_b_tvalid => point_valid_split(D), --TODO: use correct valid
      s_axis_b_tready => open,
      s_axis_b_tdata  => centroid((D+1)*DATA_WIDTH-1 downto D*DATA_WIDTH),

      m_axis_result_tvalid => diff_valid(D),
      m_axis_result_tready => diff_ready(D),
      m_axis_result_tdata => diff_data(D),
      m_axis_result_tlast => diff_last(D)
    );

    -- Clone distance into two streams
    dist_mult_split: axi_funnel
    generic map (
      SLAVES => 2,
      DATA_WIDTH => DATA_WIDTH
    )
    port map (
      reset     => reset,
      clk       => clk,
      in_data   => diff_data(D),
      in_valid  => diff_valid(D),
      in_ready  => diff_ready(D),
      in_last   => diff_last(D),
      out_data  => diff_split_data(D),
      out_valid => diff_split_valid(D),
      out_ready => diff_split_ready(D),
      out_last  => diff_split_last(D)
    );

    -- Square distances
    dmult: floating_point_mult_double port map (
      aclk => clk,
      aresetn => not reset,
      s_axis_a_tvalid => diff_split_valid(D)(0),
      s_axis_a_tready => diff_split_ready(D)(0),
      s_axis_a_tdata  => diff_split_data(D),
      s_axis_a_tlast  => diff_split_last(D)(0),

      s_axis_b_tvalid => diff_split_valid(D)(1),
      s_axis_b_tready => diff_split_ready(D)(1),
      s_axis_b_tdata  => diff_split_data(D),

      m_axis_result_tvalid => sum_tree(log2ceil(DIMENSION))(D).valid,
      m_axis_result_tready => sum_tree(log2ceil(DIMENSION))(D).ready,
      m_axis_result_tdata  => sum_tree(log2ceil(DIMENSION))(D).data,
      m_axis_result_tlast  => sum_tree(log2ceil(DIMENSION))(D).last
    );
  end generate;

  sum_tree_gen: for lvl in 0 to log2ceil(DIMENSION) - 1 generate
    lvl_gen: for idx in 0 to 2 ** lvl - 1 generate
      adder: floating_point_add_double port map (
        aclk => clk,
        aresetn => not reset,
        s_axis_a_tvalid => sum_tree(lvl + 1)(idx * 2).valid,
        s_axis_a_tready => sum_tree(lvl + 1)(idx * 2).ready,
        s_axis_a_tdata  => sum_tree(lvl + 1)(idx * 2).data,
        s_axis_a_tlast  => sum_tree(lvl + 1)(idx * 2).last,

        s_axis_b_tvalid => sum_tree(lvl + 1)(idx * 2 + 1).valid,
        s_axis_b_tready => sum_tree(lvl + 1)(idx * 2 + 1).ready,
        s_axis_b_tdata  => sum_tree(lvl + 1)(idx * 2 + 1).data,
        s_axis_b_tlast  => sum_tree(lvl + 1)(idx * 2 + 1).last,

        m_axis_result_tvalid => sum_tree(lvl)(idx).valid,
        m_axis_result_tready => sum_tree(lvl)(idx).ready,
        m_axis_result_tdata  => sum_tree(lvl)(idx).data,
        m_axis_result_tlast  => sum_tree(lvl)(idx).last
      );
    end generate;
  end generate;

  distance_valid <= sum_tree(0)(0).valid;
  sum_tree(0)(0).ready <= distance_ready;
  distance_last  <= sum_tree(0)(0).last;
  distance_data  <= sum_tree(0)(0).data;

end architecture;

