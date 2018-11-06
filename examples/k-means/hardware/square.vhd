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

entity square is
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
    m_axis_result_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
    m_axis_result_tlast  : out std_logic;
    m_axis_result_tuser  : out std_logic_vector(TUSER_WIDTH-1 downto 0)
  );
end square;

architecture behavior of square is
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
      s_axis_tlast         : in  std_logic_vector(OPERANTS-1 downto 0) := (others => '0');
      s_axis_tuser         : in  std_logic_vector(TUSER_WIDTH-1 downto 0) := (others => '0');
      m_axis_result_tvalid : out std_logic;
      m_axis_result_tready : in  std_logic;
      m_axis_result_tdata  : out std_logic_vector(DATA_WIDTH-1 downto 0);
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

  signal operants_in : std_logic_vector(DATA_WIDTH * DATA_WIDTH - 1 downto 0);
  signal tree_data : std_logic_vector(DATA_WIDTH * DATA_WIDTH + TUSER_WIDTH - 1 downto 0);
  signal tree_valid, tree_ready, tree_last : std_logic_vector(DATA_WIDTH-1 downto 0);
begin

  -- Define operants for addition
  square_operants: process (s_axis_tdata)
  begin
    for idx in 0 to DATA_WIDTH - 1 loop
      if s_axis_tdata(idx) = '1' then
        -- Shift the operant
        operants_in((idx + 1) * DATA_WIDTH - 1 downto idx * DATA_WIDTH) <= std_logic_vector(
          shift_left(
            signed(s_axis_tdata(DATA_WIDTH-1 downto 0)),
            idx)
          );
      else
        -- Do not add, set to 0
        operants_in((idx + 1) * DATA_WIDTH - 1 downto idx * DATA_WIDTH) <= (others => '0');
      end if;
    end loop;
  end process;

  -- Split the AXI stream to the adders
  --TODO: replace with StreamSync
  dim_split: axi_funnel
  generic map (
    SLAVES                 => DATA_WIDTH,
    DATA_WIDTH             => DATA_WIDTH * DATA_WIDTH + TUSER_WIDTH
  )
  port map (
    reset                  => reset,
    clk                    => clk,
    in_data                => operants_in & s_axis_tuser,
    in_valid               => s_axis_tvalid,
    in_ready               => s_axis_tready,
    in_last                => s_axis_tlast,
    out_data               => tree_data,
    out_valid              => tree_valid,
    out_ready              => tree_ready,
    out_last               => tree_last
  );

  square_tree: adder_tree generic map (
    DATA_WIDTH  => DATA_WIDTH,
    TUSER_WIDTH => TUSER_WIDTH,
    OPERANTS    => DATA_WIDTH
  )
  port map (
    clk                    => clk,
    reset                  => reset,
    s_axis_tvalid          => tree_valid,
    s_axis_tready          => tree_ready,
    s_axis_tdata           => tree_data(tree_data'length-1 downto TUSER_WIDTH),
    s_axis_tlast           => tree_last,
    s_axis_tuser           => tree_data(TUSER_WIDTH-1 downto 0),
    m_axis_result_tvalid   => m_axis_result_tvalid,
    m_axis_result_tready   => m_axis_result_tready,
    m_axis_result_tdata    => m_axis_result_tdata,
    m_axis_result_tlast    => m_axis_result_tlast,
    m_axis_result_tuser    => m_axis_result_tuser
  );

end architecture;

