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

entity adder_tree is
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
end adder_tree;

architecture behavior of adder_tree is
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

  type axi_t is record
    valid : std_logic;
    ready : std_logic;
    last  : std_logic;
    data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  end record axi_t;

  type sum_lvl_t is array (0 to OPERANTS-1) of axi_t;
  type sum_tree_t is array (0 to log2ceil(OPERANTS)) of sum_lvl_t;
  signal sum_tree : sum_tree_t;

  type user_t is array (0 to log2ceil(OPERANTS)) of std_logic_vector(TUSER_WIDTH-1 downto 0);
  signal intermediate_user : user_t;

begin

  -- Give tree its inputs
  sum_tree_connect: for idx in 0 to 2 ** log2ceil(OPERANTS) - 1 generate
    -- Connect inputs to top of tree
    connect: if idx < OPERANTS generate
      sum_tree(log2ceil(OPERANTS))(idx).valid <= s_axis_tvalid(idx);
      sum_tree(log2ceil(OPERANTS))(idx).last  <= s_axis_tlast(idx);
      sum_tree(log2ceil(OPERANTS))(idx).data  <= s_axis_tdata((idx+1)*DATA_WIDTH-1 downto idx * DATA_WIDTH);
      s_axis_tready(idx) <= sum_tree(log2ceil(OPERANTS))(idx).ready;
    end generate;

    -- Fill up tree to power of 2
    zero_fill: if idx >= OPERANTS generate
      sum_tree(log2ceil(OPERANTS))(idx).valid <= '1';
      sum_tree(log2ceil(OPERANTS))(idx).last  <= '0';
      sum_tree(log2ceil(OPERANTS))(idx).data  <= (others => '0');
    end generate;
  end generate;
  intermediate_user(log2ceil(OPERANTS)) <= s_axis_tuser;

  -- Connect bottom of tree to output
  m_axis_result_tuser  <= intermediate_user(0);
  m_axis_result_tvalid <= sum_tree(0)(0).valid;
  sum_tree(0)(0).ready <= m_axis_result_tready;
  m_axis_result_tlast  <= sum_tree(0)(0).last;
  m_axis_result_tdata  <= sum_tree(0)(0).data;

  sum_tree_gen: for lvl in 0 to log2ceil(OPERANTS) - 1 generate
    lvl_gen: for idx in 0 to 2 ** lvl - 1 generate
      do_user: if idx = 0 generate
        unit: adder generic map(
          DATA_WIDTH           => DATA_WIDTH,
          TUSER_WIDTH          => TUSER_WIDTH
        )
        port map (
          clk => clk,
          reset => reset,
          s_axis_a_tvalid      => sum_tree(lvl + 1)(idx * 2).valid,
          s_axis_a_tready      => sum_tree(lvl + 1)(idx * 2).ready,
          s_axis_a_tdata       => sum_tree(lvl + 1)(idx * 2).data,
          s_axis_a_tlast       => sum_tree(lvl + 1)(idx * 2).last,
          s_axis_a_tuser       => intermediate_user(lvl + 1),

          s_axis_b_tvalid      => sum_tree(lvl + 1)(idx * 2 + 1).valid,
          s_axis_b_tready      => sum_tree(lvl + 1)(idx * 2 + 1).ready,
          s_axis_b_tdata       => sum_tree(lvl + 1)(idx * 2 + 1).data,
          s_axis_b_tlast       => sum_tree(lvl + 1)(idx * 2 + 1).last,

          m_axis_result_tvalid => sum_tree(lvl)(idx).valid,
          m_axis_result_tready => sum_tree(lvl)(idx).ready,
          m_axis_result_tdata  => sum_tree(lvl)(idx).data,
          m_axis_result_tlast  => sum_tree(lvl)(idx).last,
          m_axis_result_tuser  => intermediate_user(lvl)
        );
      end generate;
      no_user: if idx > 0 generate
        unit: adder generic map(
          DATA_WIDTH           => DATA_WIDTH
        )
        port map (
          clk => clk,
          reset => reset,
          s_axis_a_tvalid      => sum_tree(lvl + 1)(idx * 2).valid,
          s_axis_a_tready      => sum_tree(lvl + 1)(idx * 2).ready,
          s_axis_a_tdata       => sum_tree(lvl + 1)(idx * 2).data,
          s_axis_a_tlast       => sum_tree(lvl + 1)(idx * 2).last,

          s_axis_b_tvalid      => sum_tree(lvl + 1)(idx * 2 + 1).valid,
          s_axis_b_tready      => sum_tree(lvl + 1)(idx * 2 + 1).ready,
          s_axis_b_tdata       => sum_tree(lvl + 1)(idx * 2 + 1).data,
          s_axis_b_tlast       => sum_tree(lvl + 1)(idx * 2 + 1).last,

          m_axis_result_tvalid => sum_tree(lvl)(idx).valid,
          m_axis_result_tready => sum_tree(lvl)(idx).ready,
          m_axis_result_tdata  => sum_tree(lvl)(idx).data,
          m_axis_result_tlast  => sum_tree(lvl)(idx).last
        );
      end generate;
    end generate;
  end generate;

end architecture;

