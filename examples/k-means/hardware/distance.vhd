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
      DIMENSION         : natural;
      DATA_WIDTH        : natural;
      TUSER_WIDTH       : natural := 1
    );
    port(
      reset             : in  std_logic;
      clk               : in  std_logic;
      -------------------------------------------------------------------------
      centroid          : in  std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);
      point_data        : in  std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);
      point_valid       : in  std_logic;
      point_ready       : out std_logic;
      point_last        : in  std_logic;
      point_tuser       : in  std_logic_vector(TUSER_WIDTH - 1 downto 0) := (others => '0');
      distance_distance : out std_logic_vector(DATA_WIDTH - 1 downto 0);
      distance_point    : out std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);
      distance_valid    : out std_logic;
      distance_ready    : in  std_logic;
      distance_last     : out std_logic;
      distance_tuser    : out std_logic_vector(TUSER_WIDTH - 1 downto 0)
    );
end entity distance;


architecture behavior of distance is

  component adder is
    generic(
      DATA_WIDTH           : natural;
      TUSER_WIDTH          : natural := 1;
      OPERATION            : string  := "add";
      SLICES               : natural := 1
    );
    port(
      clk : in std_logic;
      reset : in std_logic;
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

  component square is
    generic(
      DATA_WIDTH           : natural;
      TUSER_WIDTH          : positive := 1
    );
    port(
      clk                  : in  std_logic;
      reset                : in  std_logic;
      s_axis_tvalid        : in  std_logic;
      s_axis_tready        : out std_logic;
      s_axis_tdata         : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      s_axis_tlast         : in  std_logic := '0';
      s_axis_tuser         : in  std_logic_vector(TUSER_WIDTH-1 downto 0) := (others => '0');
      m_axis_result_tvalid : out std_logic;
      m_axis_result_tready : in  std_logic;
      m_axis_result_tdata  : out std_logic_vector(DATA_WIDTH*2-1 downto 0);
      m_axis_result_tlast  : out std_logic;
      m_axis_result_tuser  : out std_logic_vector(TUSER_WIDTH-1 downto 0)
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

  component adder_tree is
    generic(
      DATA_WIDTH           : natural;
      TUSER_WIDTH          : positive := 1;
      OPERANTS             : natural
    );
    port(
      clk                  : in  std_logic;
      reset                : in  std_logic;
      s_axis_tvalid        : in  std_logic_vector(OPERANTS-1 downto 0);
      s_axis_tready        : out std_logic_vector(OPERANTS-1 downto 0);
      s_axis_tdata         : in  std_logic_vector(DATA_WIDTH * OPERANTS - 1 downto 0);
      s_axis_tlast         : in  std_logic_vector(OPERANTS-1 downto 0)    := (others => '0');
      s_axis_tuser         : in  std_logic_vector(TUSER_WIDTH-1 downto 0) := (others => '0');
      m_axis_result_tvalid : out std_logic;
      m_axis_result_tready : in  std_logic;
      m_axis_result_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      m_axis_result_tlast  : out std_logic;
      m_axis_result_tuser  : out std_logic_vector(TUSER_WIDTH-1 downto 0)
    );
  end component;


  signal point_valid_split,
         point_ready_split,
         point_last_split : std_logic_vector(DIMENSION - 1 downto 0);
  signal point_data_split : std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);

  type data_array_t is array (0 to DIMENSION-1) of std_logic_vector(DATA_WIDTH - 1 downto 0);
  type user_array_t is array (0 to DIMENSION-1) of std_logic_vector(DATA_WIDTH + TUSER_WIDTH - 1 downto 0);
  signal diff_valid,
         diff_ready,
         diff_last  : std_logic_vector(DIMENSION-1 downto 0);
  signal diff_data  : data_array_t;
  signal diff_user  : user_array_t;

  signal square_valid,
         square_ready,
         square_last   : std_logic_vector(DIMENSION-1 downto 0);
  signal square_data,
         square_point  : std_logic_vector(DATA_WIDTH * DIMENSION - 1 downto 0);
  signal square_user   : std_logic_vector(TUSER_WIDTH - 1 downto 0);
  signal distance_user_tmp : std_logic_vector(TUSER_WIDTH + DATA_WIDTH * DIMENSION - 1 downto 0);

begin

  -- Split the point AXI stream to the dimension subtractors
  --TODO: replace with StreamSync
  dim_split: axi_funnel
  generic map (
    SLAVES                 => DIMENSION,
    DATA_WIDTH             => DATA_WIDTH * DIMENSION
  )
  port map (
    reset                  => reset,
    clk                    => clk,
    in_data                => point_data,
    in_valid               => point_valid,
    in_ready               => point_ready,
    in_last                => point_last,
    out_data               => point_data_split,
    out_valid              => point_valid_split,
    out_ready              => point_ready_split,
    out_last               => point_last_split
  );

  -- For each dimension: take distance between point and centroid, then square
  dim_gen: for D in 0 to DIMENSION-1 generate
    -- Single dimension distance
    adder_inst: adder generic map(
      DATA_WIDTH           => DATA_WIDTH,
      TUSER_WIDTH          => DATA_WIDTH + TUSER_WIDTH,
      OPERATION            => "sub"
    )
    port map (
      clk                  => clk,
      reset                => reset,
      s_axis_a_tvalid      => point_valid_split(D),
      s_axis_a_tready      => point_ready_split(D),
      s_axis_a_tdata       => point_data_split((D+1) * DATA_WIDTH - 1 downto D * DATA_WIDTH),
      s_axis_a_tlast       => point_last_split(D),
      s_axis_a_tuser       => point_tuser & point_data_split((D+1) * DATA_WIDTH - 1 downto D * DATA_WIDTH),

      s_axis_b_tvalid      => point_valid_split(D),
      s_axis_b_tready      => open,
      s_axis_b_tdata       => centroid((D + 1) * DATA_WIDTH - 1 downto D * DATA_WIDTH),

      m_axis_result_tvalid => diff_valid(D),
      m_axis_result_tready => diff_ready(D),
      m_axis_result_tdata  => diff_data(D),
      m_axis_result_tlast  => diff_last(D),
      m_axis_result_tuser  => diff_user(D)
    );

    with_user: if D = 0 generate
      signal tuser_tmp : std_logic_vector(TUSER_WIDTH + DATA_WIDTH - 1 downto 0);
    begin
      -- Square distances
      square_inst: square generic map(
        DATA_WIDTH           => DATA_WIDTH/2,
        TUSER_WIDTH          => DATA_WIDTH + TUSER_WIDTH
      )
      port map (
        clk                  => clk,
        reset                => reset,
        s_axis_tvalid        => diff_valid(D),
        s_axis_tready        => diff_ready(D),
        s_axis_tdata         => diff_data(D)(DATA_WIDTH / 2 - 1 downto 0),
        s_axis_tlast         => diff_last(D),
        s_axis_tuser         => diff_user(D),

        m_axis_result_tvalid => square_valid(D),
        m_axis_result_tready => square_ready(D),
        m_axis_result_tdata  => square_data((D+1)*DATA_WIDTH-1 downto D*DATA_WIDTH),
        m_axis_result_tlast  => square_last(D),
        m_axis_result_tuser  => tuser_tmp
      );

      -- Split up the external user data and internal point location
      square_point((D+1)*DATA_WIDTH-1 downto D*DATA_WIDTH) <= tuser_tmp(DATA_WIDTH - 1 downto 0);
      square_user <= tuser_tmp(DATA_WIDTH + TUSER_WIDTH - 1 downto DATA_WIDTH);
    end generate;

    without_user: if D /= 0 generate
      square_inst: square generic map(
        DATA_WIDTH           => DATA_WIDTH/2,
        TUSER_WIDTH          => DATA_WIDTH
      )
      port map (
        clk                  => clk,
        reset                => reset,
        s_axis_tvalid        => diff_valid(D),
        s_axis_tready        => diff_ready(D),
        s_axis_tdata         => diff_data(D)(DATA_WIDTH / 2 - 1 downto 0),
        s_axis_tlast         => diff_last(D),
        -- Only take single dimension location of the point
        s_axis_tuser         => diff_user(D)(DATA_WIDTH - 1 downto 0),

        m_axis_result_tvalid => square_valid(D),
        m_axis_result_tready => square_ready(D),
        m_axis_result_tdata  => square_data((D+1)*DATA_WIDTH-1 downto D*DATA_WIDTH),
        m_axis_result_tlast  => square_last(D),
        m_axis_result_tuser  => square_point((D+1)*DATA_WIDTH-1 downto D*DATA_WIDTH)
      );
    end generate;
  end generate;

  -- Add single dimension squared distances to get the euclidian distance
  dist_l: adder_tree generic map (
    DATA_WIDTH           => DATA_WIDTH,
    TUSER_WIDTH          => DATA_WIDTH * DIMENSION + TUSER_WIDTH,
    OPERANTS             => DIMENSION
  )
  port map (
    clk                  => clk,
    reset                => reset,
    s_axis_tvalid        => square_valid,
    s_axis_tready        => square_ready,
    s_axis_tdata         => square_data,
    s_axis_tlast         => square_last,
    s_axis_tuser         => square_user & square_point,
    m_axis_result_tvalid => distance_valid,
    m_axis_result_tready => distance_ready,
    m_axis_result_tdata  => distance_distance,
    m_axis_result_tlast  => distance_last,
    m_axis_result_tuser  => distance_user_tmp
  );
  distance_tuser <= distance_user_tmp(DATA_WIDTH * DIMENSION + TUSER_WIDTH - 1 downto DATA_WIDTH * DIMENSION);
  distance_point <= distance_user_tmp(DATA_WIDTH * DIMENSION - 1 downto 0);

end architecture;

