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

entity selector is
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
end selector;

architecture behavior of selector is
  signal intermediate_valid : std_logic;
  signal intermediate_ready : std_logic;
  signal intermediate_data  : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal intermediate_path  : std_logic_vector(PATH_WIDTH-1 downto 0);
  signal intermediate_last  : std_logic;
begin

  op_p: process (s_axis_a_tdata, s_axis_b_tdata, s_axis_a_tpath, s_axis_b_tpath)
  begin
    if OPERATION = "min" then
      if unsigned(s_axis_a_tdata) < unsigned(s_axis_b_tdata) then
        intermediate_data <= s_axis_a_tdata;
        intermediate_path <= s_axis_a_tpath;
      else
        intermediate_data <= s_axis_b_tdata;
        intermediate_path <= s_axis_b_tpath;
      end if;
    end if;
  end process;

  intermediate_valid <= s_axis_a_tvalid and s_axis_b_tvalid;
  intermediate_last  <= s_axis_a_tlast or s_axis_b_tlast;
  s_axis_a_tready    <= intermediate_ready;
  s_axis_b_tready    <= intermediate_ready;

  no_output_slice_gen: if SLICES = 0 generate
    m_axis_result_tvalid <= intermediate_valid;
    m_axis_result_tdata  <= intermediate_data;
    m_axis_result_tpath  <= intermediate_path;
    m_axis_result_tlast  <= intermediate_last;
    intermediate_ready   <= m_axis_result_tready;
  end generate;

  output_slice_gen: if SLICES = 1 generate
    signal result_data_last : std_logic_vector(DATA_WIDTH + PATH_WIDTH downto 0);
  begin
    slice: StreamSlice generic map (
      DATA_WIDTH                  => DATA_WIDTH + PATH_WIDTH + 1
    )
    port map (
      clk                         => clk,
      reset                       => reset,
      in_valid                    => intermediate_valid,
      in_ready                    => intermediate_ready,
      in_data                     => intermediate_data & intermediate_path & intermediate_last,
      out_valid                   => m_axis_result_tvalid,
      out_ready                   => m_axis_result_tready,
      out_data                    => result_data_last
    );
    m_axis_result_tdata <= result_data_last(result_data_last'length-1 downto PATH_WIDTH + 1);
    m_axis_result_tpath <= result_data_last(PATH_WIDTH downto 1);
    m_axis_result_tlast <= result_data_last(0);
  end generate;  
end architecture;

