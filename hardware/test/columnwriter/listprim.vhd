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
use work.Utils.all;
use work.Arrow.all;
use work.ColumnReaderConfig.all;
use work.ColumnReaderConfigParse.all;

entity listprim is
end listprim;

architecture tb of listprim is

  constant BUS_ADDR_WIDTH     : natural := 32;
  constant BUS_LEN_WIDTH      : natural := 8;
  constant BUS_DATA_WIDTH     : natural := 32;
  constant BUS_STROBE_WIDTH   : natural := 32/8;
  constant BUS_BURST_STEP_LEN : natural := 4;
  constant BUS_BURST_MAX_LEN  : natural := 16;
  constant INDEX_WIDTH        : natural := 32;
  constant CFG                : string  := "listprim(8,epc=4)";
  constant CMD_TAG_ENABLE     : boolean := false;
  constant CMD_TAG_WIDTH      : natural := 1;

  signal bus_clk              : std_logic;
  signal bus_reset            : std_logic;
  signal acc_clk              : std_logic;
  signal acc_reset            : std_logic;
  signal cmd_valid            : std_logic;
  signal cmd_ready            : std_logic;
  signal cmd_firstIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_lastIdx          : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_ctrl             : std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
  signal cmd_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
  signal unlock_valid         : std_logic;
  signal unlock_ready         : std_logic := '1';
  signal unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal bus_wreq_valid       : std_logic;
  signal bus_wreq_ready       : std_logic;
  signal bus_wreq_addr        : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_wreq_len         : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_wdat_valid       : std_logic;
  signal bus_wdat_ready       : std_logic;
  signal bus_wdat_data        : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_wdat_last        : std_logic;
  signal in_valid             : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_ready             : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_last              : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_dvalid            : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_data              : std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0);

begin
  
  cr_inst : ColumnReader
    generic map (
      BUS_ADDR_WIDTH      => BUS_ADDR_WIDTH,    
      BUS_LEN_WIDTH       => BUS_LEN_WIDTH,     
      BUS_DATA_WIDTH      => BUS_DATA_WIDTH,    
      BUS_STROBE_WIDTH    => BUS_STROBE_WIDTH,  
      BUS_BURST_STEP_LEN  => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN   => BUS_BURST_MAX_LEN, 
      INDEX_WIDTH         => INDEX_WIDTH,      
      CFG                 => CFG,               
      CMD_TAG_ENABLE      => CMD_TAG_ENABLE,    
      CMD_TAG_WIDTH       => CMD_TAG_WIDTH     
    )
    port map (
      bus_clk             => bus_clk,
      bus_reset           => bus_reset,
      acc_clk             => acc_clk,
      acc_reset           => acc_reset,
      cmd_valid           => cmd_valid,
      cmd_ready           => cmd_ready,
      cmd_firstIdx        => cmd_firstIdx,
      cmd_lastIdx         => cmd_lastIdx,
      cmd_ctrl            => cmd_ctrl,
      cmd_tag             => cmd_tag,
      unlock_valid        => unlock_valid,
      unlock_ready        => unlock_ready,
      unlock_tag          => unlock_tag,
      bus_wreq_valid      => bus_wreq_valid,
      bus_wreq_ready      => bus_wreq_ready,
      bus_wreq_addr       => bus_wreq_addr,
      bus_wreq_len        => bus_wreq_len,
      bus_wdat_valid      => bus_wdat_valid,
      bus_wdat_ready      => bus_wdat_ready,
      bus_wdat_data       => bus_wdat_data,
      bus_wdat_last       => bus_wdat_last,
      in_valid            => in_valid,
      in_ready            => in_ready,
      in_last             => in_last,
      in_dvalid           => in_dvalid,
      in_data             => in_data
    )
  
end architecture;
