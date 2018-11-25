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
use work.streams.StreamSlice;
use work.Utils.all;

entity filter is
  generic(
    DATA_WIDTH         : natural;
    OPERANTS           : natural;
    TUSER_WIDTH        : positive := 1;
    SLICES             : natural  := 1
  );
  port(
    clk                : in  std_logic;
    reset              : in  std_logic;
    s_axis_tvalid      : in  std_logic;
    s_axis_tready      : out std_logic;
    s_axis_tdata       : in  std_logic_vector(DATA_WIDTH * OPERANTS - 1 downto 0);
    s_axis_tlast       : in  std_logic := '0';
    s_axis_tuser       : in  std_logic_vector(TUSER_WIDTH-1 downto 0) := (others => '0');
    s_axis_count       : in  std_logic_vector(log2ceil(OPERANTS + 1) - 1 downto 0);
    m_axis_tvalid      : out std_logic;
    m_axis_tready      : in  std_logic;
    m_axis_tdata       : out std_logic_vector(DATA_WIDTH * OPERANTS - 1 downto 0);
    m_axis_tlast       : out std_logic;
    m_axis_tuser       : out std_logic_vector(TUSER_WIDTH-1 downto 0)
  );
end filter;

architecture behavior of filter is
  constant DEFAULT_VALUE    : std_logic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
  
  signal intermediate_valid : std_logic;
  signal intermediate_ready : std_logic;
  signal intermediate_data  : std_logic_vector(DATA_WIDTH * OPERANTS - 1 downto 0);
  signal intermediate_user  : std_logic_vector(TUSER_WIDTH-1 downto 0);
  signal intermediate_last  : std_logic;
begin

  process (s_axis_tdata, s_axis_count)
  begin
    for idx in 0 to OPERANTS - 1 loop
      if unsigned(s_axis_count) > idx then
        intermediate_data((idx + 1) * DATA_WIDTH - 1 downto idx * DATA_WIDTH)
            <= s_axis_tdata((idx + 1) * DATA_WIDTH - 1 downto idx * DATA_WIDTH);
      else
        intermediate_data((idx + 1) * DATA_WIDTH - 1 downto idx * DATA_WIDTH) <= DEFAULT_VALUE;
      end if;
    end loop;
  end process;

  intermediate_valid <= s_axis_tvalid;
  intermediate_last  <= s_axis_tlast;
  intermediate_user  <= s_axis_tuser;
  s_axis_tready <= intermediate_ready;

  no_output_slice_gen: if SLICES = 0 generate
    m_axis_tvalid <= intermediate_valid;
    m_axis_tdata <= intermediate_data;
    m_axis_tuser <= intermediate_user;
    m_axis_tlast <= intermediate_last;
    intermediate_ready <= m_axis_tready;
  end generate;

  output_slice_gen: if SLICES = 1 generate
    signal result_data_last : std_logic_vector(DATA_WIDTH * OPERANTS + TUSER_WIDTH downto 0);
  begin
    slice: StreamSlice generic map (
      DATA_WIDTH                  => DATA_WIDTH * OPERANTS + TUSER_WIDTH + 1
    )
    port map (
      clk                         => clk,
      reset                       => reset,
      in_valid                    => intermediate_valid,
      in_ready                    => intermediate_ready,
      in_data                     => intermediate_data & intermediate_user & intermediate_last,
      out_valid                   => m_axis_tvalid,
      out_ready                   => m_axis_tready,
      out_data                    => result_data_last
    );
    m_axis_tdata <= result_data_last(result_data_last'length-1 downto TUSER_WIDTH + 1);
    m_axis_tuser <= result_data_last(TUSER_WIDTH downto 1);
    m_axis_tlast <= result_data_last(0);
  end generate;  
end architecture;

