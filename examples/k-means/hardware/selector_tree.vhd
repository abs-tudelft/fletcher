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

entity selector_tree is
  generic(
    DATA_WIDTH              : natural;
    TUSER_WIDTH             : natural := 1;
    OPERATION               : string := "min";
    OPERANTS                : natural
  );
  port(
    clk                     : in  std_logic;
    reset                   : in  std_logic;
    s_axis_tvalid           : in  std_logic_vector(OPERANTS-1 downto 0);
    s_axis_tready           : out std_logic_vector(OPERANTS-1 downto 0);
    s_axis_tdata            : in  std_logic_vector(DATA_WIDTH * OPERANTS - 1 downto 0);
    s_axis_tuser            : in  std_logic_vector(TUSER_WIDTH - 1 downto 0) := (others => '0');
    s_axis_tlast            : in  std_logic_vector(OPERANTS-1 downto 0)      := (others => '0');
    m_axis_result_tvalid    : out std_logic;
    m_axis_result_tready    : in  std_logic;
    m_axis_result_tdata     : out std_logic_vector(DATA_WIDTH-1 downto 0);
    m_axis_result_tuser     : out std_logic_vector(TUSER_WIDTH - 1 downto 0);
    m_axis_result_tlast     : out std_logic;
    m_axis_result_tselected : out std_logic_vector(log2ceil(OPERANTS)-1 downto 0)
  );
end selector_tree;

architecture behavior of selector_tree is
  component selector is
    generic(
      DATA_WIDTH           : natural;
      PATH_WIDTH           : positive := 1;
      OPERATION            : string   := "min";
      SLICES               : natural  := 1
    );
    port(
      clk                  : in  std_logic;
      reset                : in  std_logic;
      s_axis_a_tvalid      : in  std_logic;
      s_axis_a_tready      : out std_logic;
      s_axis_a_tdata       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      s_axis_a_tpath       : in  std_logic_vector(PATH_WIDTH-1 downto 0)  := (others => '0');
      s_axis_a_tlast       : in  std_logic := '0';
      s_axis_b_tvalid      : in  std_logic;
      s_axis_b_tready      : out std_logic;
      s_axis_b_tdata       : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      s_axis_b_tpath       : in  std_logic_vector(PATH_WIDTH-1 downto 0)  := (others => '0');
      s_axis_b_tlast       : in  std_logic := '0';
      m_axis_result_tvalid : out std_logic;
      m_axis_result_tready : in  std_logic;
      m_axis_result_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
      m_axis_result_tpath  : out std_logic_vector(PATH_WIDTH-1 downto 0);
      m_axis_result_tlast  : out std_logic
    );
  end component;

  type axi_t is record
    valid : std_logic;
    ready : std_logic;
    last  : std_logic;
    data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  end record axi_t;

  type data_lvl_t is array (0 to 2**log2ceil(OPERANTS)-1) of axi_t;
  type data_tree_t is array (0 to log2ceil(OPERANTS)) of data_lvl_t;
  signal data_tree : data_tree_t;

  type path_t is array (0 to log2ceil(OPERANTS)) of std_logic_vector(2 ** log2ceil(OPERANTS) - 1 downto 0);
  signal intermediate_path : path_t;

  type user_t is array (0 to log2ceil(OPERANTS)) of std_logic_vector(TUSER_WIDTH - 1 downto 0);
  signal intermediate_tuser : user_t;

begin

  -- Give tree its inputs
  sum_tree_connect: for idx in 0 to 2 ** log2ceil(OPERANTS) - 1 generate

    -- Connect inputs to top of tree
    connect: if idx < OPERANTS generate
      data_tree(log2ceil(OPERANTS))(idx).valid <= s_axis_tvalid(idx);
      data_tree(log2ceil(OPERANTS))(idx).last  <= s_axis_tlast(idx);
      data_tree(log2ceil(OPERANTS))(idx).data  <= s_axis_tdata((idx + 1) * DATA_WIDTH - 1 downto idx * DATA_WIDTH);
      s_axis_tready(idx) <= data_tree(log2ceil(OPERANTS))(idx).ready;
    end generate;

    -- Fill up tree to power of 2
    zero_fill: if idx >= OPERANTS generate
      data_tree(log2ceil(OPERANTS))(idx).valid <= '1';
      data_tree(log2ceil(OPERANTS))(idx).last  <= '0';
      data_tree(log2ceil(OPERANTS))(idx).data  <= (others => '1');
    end generate;
  end generate;

  intermediate_tuser(log2ceil(OPERANTS)) <= s_axis_tuser;

  -- This is cut off later, but needed as first input
  intermediate_path(log2ceil(OPERANTS)) <= (others => '0');


  -- Connect bottom of tree to output
  -- There is an extra '0' at the end of this vector
  m_axis_result_tselected <= intermediate_path(0)(log2ceil(OPERANTS) downto 1);
  m_axis_result_tvalid    <= data_tree(0)(0).valid;
  data_tree(0)(0).ready   <= m_axis_result_tready;
  m_axis_result_tlast     <= data_tree(0)(0).last;
  m_axis_result_tdata     <= data_tree(0)(0).data;
  m_axis_result_tuser     <= intermediate_tuser(0);

  select_tree_gen: for lvl in 0 to log2ceil(OPERANTS) - 1 generate
    --constant PATH_WIDTH : positive := (log2ceil(OPERANTS) - lvl);
  begin
    lvl_gen: for idx in 0 to 2 ** lvl - 1 generate

      -- First array passes down the user info
      with_point: if idx = 0 generate
        signal upstream_path_a, upstream_path_b : std_logic_vector((log2ceil(OPERANTS) - lvl) - 1 downto 0);
        signal path_a, path_b : std_logic_vector((log2ceil(OPERANTS) - lvl) + TUSER_WIDTH downto 0);
        signal tmp_path_user  : std_logic_vector((log2ceil(OPERANTS) - lvl) + TUSER_WIDTH downto 0);
      begin
        upstream_path_a <= intermediate_path(lvl + 1)((idx*2   + 1) * (log2ceil(OPERANTS) - lvl) - 1 downto (idx*2  ) * (log2ceil(OPERANTS) - lvl));
        upstream_path_b <= intermediate_path(lvl + 1)((idx*2+1 + 1) * (log2ceil(OPERANTS) - lvl) - 1 downto (idx*2+1) * (log2ceil(OPERANTS) - lvl));
        path_a <= "0" & upstream_path_a & intermediate_tuser(lvl + 1);
        path_b <= "1" & upstream_path_b & intermediate_tuser(lvl + 1);

        selector_inst: selector generic map (
          DATA_WIDTH           => DATA_WIDTH,
          PATH_WIDTH           => (log2ceil(OPERANTS) - lvl) + TUSER_WIDTH + 1,
          OPERATION            => OPERATION
        )
        port map (
          clk                  => clk,
          reset                => reset,
          s_axis_a_tvalid      => data_tree(lvl + 1)(idx * 2).valid,
          s_axis_a_tready      => data_tree(lvl + 1)(idx * 2).ready,
          s_axis_a_tlast       => data_tree(lvl + 1)(idx * 2).last,
          s_axis_a_tdata       => data_tree(lvl + 1)(idx * 2).data,
          s_axis_a_tpath       => path_a,
          s_axis_b_tvalid      => data_tree(lvl + 1)(idx * 2 + 1).valid,
          s_axis_b_tready      => data_tree(lvl + 1)(idx * 2 + 1).ready,
          s_axis_b_tlast       => data_tree(lvl + 1)(idx * 2 + 1).last,
          s_axis_b_tdata       => data_tree(lvl + 1)(idx * 2 + 1).data,
          s_axis_b_tpath       => path_b,
          m_axis_result_tvalid => data_tree(lvl)(idx).valid,
          m_axis_result_tready => data_tree(lvl)(idx).ready,
          m_axis_result_tlast  => data_tree(lvl)(idx).last,
          m_axis_result_tdata  => data_tree(lvl)(idx).data,
          m_axis_result_tpath  => tmp_path_user
        );
        intermediate_path(lvl)( (idx + 1) * ((log2ceil(OPERANTS) - lvl) + 1) - 1 downto idx * ((log2ceil(OPERANTS) - lvl) + 1))
           <= tmp_path_user(tmp_path_user'length-1 downto TUSER_WIDTH);
        intermediate_tuser(lvl) <= tmp_path_user(TUSER_WIDTH - 1 downto 0);
      end generate;

      -- Rest of the arrays
      without_point: if idx > 0 generate
        signal upstream_path_a, upstream_path_b : std_logic_vector((log2ceil(OPERANTS) - lvl) - 1 downto 0);
        signal path_a, path_b : std_logic_vector((log2ceil(OPERANTS) - lvl) downto 0);
      begin
        upstream_path_a <= intermediate_path(lvl + 1)((idx*2   + 1) * (log2ceil(OPERANTS) - lvl) - 1 downto (idx*2  ) * (log2ceil(OPERANTS) - lvl));
        upstream_path_b <= intermediate_path(lvl + 1)((idx*2+1 + 1) * (log2ceil(OPERANTS) - lvl) - 1 downto (idx*2+1) * (log2ceil(OPERANTS) - lvl));
        path_a <= "0" & upstream_path_a;
        path_b <= "1" & upstream_path_b;

        selector_inst: selector generic map (
          DATA_WIDTH           => DATA_WIDTH,
          PATH_WIDTH           => (log2ceil(OPERANTS) - lvl) + 1,
          OPERATION            => OPERATION
        )
        port map (
          clk                  => clk,
          reset                => reset,
          s_axis_a_tvalid      => data_tree(lvl + 1)(idx * 2).valid,
          s_axis_a_tready      => data_tree(lvl + 1)(idx * 2).ready,
          s_axis_a_tlast       => data_tree(lvl + 1)(idx * 2).last,
          s_axis_a_tdata       => data_tree(lvl + 1)(idx * 2).data,
          s_axis_a_tpath       => path_a,
          s_axis_b_tvalid      => data_tree(lvl + 1)(idx * 2 + 1).valid,
          s_axis_b_tready      => data_tree(lvl + 1)(idx * 2 + 1).ready,
          s_axis_b_tlast       => data_tree(lvl + 1)(idx * 2 + 1).last,
          s_axis_b_tdata       => data_tree(lvl + 1)(idx * 2 + 1).data,
          s_axis_b_tpath       => path_b,
          m_axis_result_tvalid => data_tree(lvl)(idx).valid,
          m_axis_result_tready => data_tree(lvl)(idx).ready,
          m_axis_result_tlast  => data_tree(lvl)(idx).last,
          m_axis_result_tdata  => data_tree(lvl)(idx).data,
          m_axis_result_tpath  => intermediate_path(lvl)( (idx + 1) * ((log2ceil(OPERANTS) - lvl) + 1) - 1 downto idx * ((log2ceil(OPERANTS) - lvl) + 1))
        );
      end generate;
    end generate;
  end generate;

end architecture;

