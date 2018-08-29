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
use work.Utils.all;
use work.ColumnConfig.all;
use work.ColumnConfigParse.all;

package Columns is
  -----------------------------------------------------------------------------
  -- ColumnWriter
  -----------------------------------------------------------------------------
  component ColumnWriter is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_STROBE_WIDTH          : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean := false;
      CMD_TAG_WIDTH             : natural := 1
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;
      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_wreq_valid            : out std_logic;
      bus_wreq_ready            : in  std_logic;
      bus_wreq_addr             : out std_logic_vector;
      bus_wreq_len              : out std_logic_vector;
      bus_wdat_valid            : out std_logic;
      bus_wdat_ready            : in  std_logic;
      bus_wdat_data             : out std_logic_vector;
      bus_wdat_strobe           : out std_logic_vector;
      bus_wdat_last             : out std_logic;
      in_valid                  : in  std_logic_vector;
      in_ready                  : out std_logic_vector;
      in_last                   : in  std_logic_vector;
      in_dvalid                 : in  std_logic_vector;
      in_data                   : in  std_logic_vector
    );
  end component;

  component ColumnWriterLevel is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_STROBE_WIDTH          : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean;
      CMD_TAG_WIDTH             : natural
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;
      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_wreq_valid            : out std_logic_vector;
      bus_wreq_ready            : in  std_logic_vector;
      bus_wreq_addr             : out std_logic_vector;
      bus_wreq_len              : out std_logic_vector;
      bus_wdat_valid            : out std_logic_vector;
      bus_wdat_ready            : in  std_logic_vector;
      bus_wdat_data             : out std_logic_vector;
      bus_wdat_strobe           : out std_logic_vector;
      bus_wdat_last             : out std_logic_vector;
      in_valid                  : in  std_logic_vector;
      in_ready                  : out std_logic_vector;
      in_last                   : in  std_logic_vector;
      in_dvalid                 : in  std_logic_vector;
      in_data                   : in  std_logic_vector
    );
  end component;

  component ColumnWriterArb is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_STROBE_WIDTH          : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean := false;
      CMD_TAG_WIDTH             : natural := 1
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;
      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_wreq_valid            : out std_logic_vector;
      bus_wreq_ready            : in  std_logic_vector;
      bus_wreq_addr             : out std_logic_vector;
      bus_wreq_len              : out std_logic_vector;
      bus_wdat_valid            : out std_logic_vector;
      bus_wdat_ready            : in  std_logic_vector;
      bus_wdat_data             : out std_logic_vector;
      bus_wdat_strobe           : out std_logic_vector;
      bus_wdat_last             : out std_logic_vector;
      in_valid                  : in  std_logic_vector;
      in_ready                  : out std_logic_vector;
      in_last                   : in  std_logic_vector;
      in_dvalid                 : in  std_logic_vector;
      in_data                   : in  std_logic_vector
    );
  end component;

  component ColumnWriterListPrim is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_STROBE_WIDTH          : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean;
      CMD_TAG_WIDTH             : natural
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;
      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_wreq_valid            : out std_logic_vector;
      bus_wreq_ready            : in  std_logic_vector;
      bus_wreq_addr             : out std_logic_vector;
      bus_wreq_len              : out std_logic_vector;
      bus_wdat_valid            : out std_logic_vector;
      bus_wdat_ready            : in  std_logic_vector;
      bus_wdat_data             : out std_logic_vector;
      bus_wdat_strobe           : out std_logic_vector;
      bus_wdat_last             : out std_logic_vector;
      in_valid                  : in  std_logic_vector;
      in_ready                  : out std_logic_vector;
      in_last                   : in  std_logic_vector;
      in_dvalid                 : in  std_logic_vector;
      in_data                   : in  std_logic_vector
    );
  end component;

  component ColumnWriterListSync is
    generic (
      ELEMENT_WIDTH             : positive;
      LENGTH_WIDTH              : positive;
      COUNT_MAX                 : positive;
      COUNT_WIDTH               : positive;
      GENERATE_LENGTH           : boolean;
      NORMALIZE                 : boolean;
      ELEM_LAST_FROM_LENGTH     : boolean;
      DATA_IN_SLICE             : boolean;
      LEN_IN_SLICE              : boolean;
      OUT_SLICE                 : boolean
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      inl_valid                 : in  std_logic;
      inl_ready                 : out std_logic;
      inl_length                : in  std_logic_vector(LENGTH_WIDTH-1 downto 0);
      inl_last                  : in  std_logic;
      ine_valid                 : in  std_logic;
      ine_ready                 : out std_logic;
      ine_dvalid                : in  std_logic;
      ine_data                  : in  std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      ine_count                 : in  std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
      ine_last                  : in  std_logic;
      outl_valid                : out std_logic;
      outl_ready                : in  std_logic;
      outl_length               : out std_logic_vector(LENGTH_WIDTH-1 downto 0);
      outl_last                 : out std_logic;
      oute_valid                : out std_logic;
      oute_ready                : in  std_logic;
      oute_last                 : out std_logic;
      oute_dvalid               : out std_logic;
      oute_data                 : out std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      oute_count                : out std_logic_vector(COUNT_WIDTH-1 downto 0)

    );
  end component;

  -----------------------------------------------------------------------------
  -- ColumnReader
  -----------------------------------------------------------------------------
  component ColumnReader is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean := false;
      CMD_TAG_WIDTH             : natural := 1
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;
      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_rreq_valid            : out std_logic;
      bus_rreq_ready            : in  std_logic;
      bus_rreq_addr             : out std_logic_vector;
      bus_rreq_len              : out std_logic_vector;
      bus_rdat_valid            : in  std_logic;
      bus_rdat_ready            : out std_logic;
      bus_rdat_data             : in  std_logic_vector;
      bus_rdat_last             : in  std_logic;
      out_valid                 : out std_logic_vector;
      out_ready                 : in  std_logic_vector;
      out_last                  : out std_logic_vector;
      out_dvalid                : out std_logic_vector;
      out_data                  : out std_logic_vector
    );
  end component;

  component ColumnReaderLevel is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean := false;
      CMD_TAG_WIDTH             : natural := 1
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;
      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_rreq_valid            : out std_logic_vector;
      bus_rreq_ready            : in  std_logic_vector;
      bus_rreq_addr             : out std_logic_vector;
      bus_rreq_len              : out std_logic_vector;
      bus_rdat_valid            : in  std_logic_vector;
      bus_rdat_ready            : out std_logic_vector;
      bus_rdat_data             : in  std_logic_vector;
      bus_rdat_last             : in  std_logic_vector;
      out_valid                 : out std_logic_vector;
      out_ready                 : in  std_logic_vector;
      out_last                  : out std_logic_vector;
      out_dvalid                : out std_logic_vector;
      out_data                  : out std_logic_vector
    );
  end component;

  component ColumnReaderArb is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean := false;
      CMD_TAG_WIDTH             : natural := 1
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;
      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_rreq_valid            : out std_logic_vector;
      bus_rreq_ready            : in  std_logic_vector;
      bus_rreq_addr             : out std_logic_vector;
      bus_rreq_len              : out std_logic_vector;
      bus_rdat_valid            : in  std_logic_vector;
      bus_rdat_ready            : out std_logic_vector;
      bus_rdat_data             : in  std_logic_vector;
      bus_rdat_last             : in  std_logic_vector;
      out_valid                 : out std_logic_vector;
      out_ready                 : in  std_logic_vector;
      out_last                  : out std_logic_vector;
      out_dvalid                : out std_logic_vector;
      out_data                  : out std_logic_vector
    );
  end component;

  component ColumnReaderNull is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean := false;
      CMD_TAG_WIDTH             : natural := 1
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;
      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_rreq_valid            : out std_logic_vector;
      bus_rreq_ready            : in  std_logic_vector;
      bus_rreq_addr             : out std_logic_vector;
      bus_rreq_len              : out std_logic_vector;
      bus_rdat_valid            : in  std_logic_vector;
      bus_rdat_ready            : out std_logic_vector;
      bus_rdat_data             : in  std_logic_vector;
      bus_rdat_last             : in  std_logic_vector;
      out_valid                 : out std_logic_vector;
      out_ready                 : in  std_logic_vector;
      out_last                  : out std_logic_vector;
      out_dvalid                : out std_logic_vector;
      out_data                  : out std_logic_vector
    );
  end component;

  component ColumnReaderList is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean := false;
      CMD_TAG_WIDTH             : natural := 1
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;
      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_rreq_valid            : out std_logic_vector;
      bus_rreq_ready            : in  std_logic_vector;
      bus_rreq_addr             : out std_logic_vector;
      bus_rreq_len              : out std_logic_vector;
      bus_rdat_valid            : in  std_logic_vector;
      bus_rdat_ready            : out std_logic_vector;
      bus_rdat_data             : in  std_logic_vector;
      bus_rdat_last             : in  std_logic_vector;
      out_valid                 : out std_logic_vector;
      out_ready                 : in  std_logic_vector;
      out_last                  : out std_logic_vector;
      out_dvalid                : out std_logic_vector;
      out_data                  : out std_logic_vector
    );
  end component;

  component ColumnReaderListPrim is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean := false;
      CMD_TAG_WIDTH             : natural := 1
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;

      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_rreq_valid            : out std_logic_vector;
      bus_rreq_ready            : in  std_logic_vector;
      bus_rreq_addr             : out std_logic_vector;
      bus_rreq_len              : out std_logic_vector;
      bus_rdat_valid            : in  std_logic_vector;
      bus_rdat_ready            : out std_logic_vector;
      bus_rdat_data             : in  std_logic_vector;
      bus_rdat_last             : in  std_logic_vector;
      out_valid                 : out std_logic_vector;
      out_ready                 : in  std_logic_vector;
      out_last                  : out std_logic_vector;
      out_dvalid                : out std_logic_vector;
      out_data                  : out std_logic_vector
    );
  end component;

  component ColumnReaderStruct is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean := false;
      CMD_TAG_WIDTH             : natural := 1
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;

      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_rreq_valid            : out std_logic_vector;
      bus_rreq_ready            : in  std_logic_vector;
      bus_rreq_addr             : out std_logic_vector;
      bus_rreq_len              : out std_logic_vector;
      bus_rdat_valid            : in  std_logic_vector;
      bus_rdat_ready            : out std_logic_vector;
      bus_rdat_data             : in  std_logic_vector;
      bus_rdat_last             : in  std_logic_vector;
      out_valid                 : out std_logic_vector;
      out_ready                 : in  std_logic_vector;
      out_last                  : out std_logic_vector;
      out_dvalid                : out std_logic_vector;
      out_data                  : out std_logic_vector
    );
  end component;

  component ColumnReaderUnlockCombine is
    generic (
      CMD_TAG_ENABLE            : boolean;
      CMD_TAG_WIDTH             : natural
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      a_unlock_valid            : in  std_logic;
      a_unlock_ready            : out std_logic;
      a_unlock_tag              : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
      a_unlock_ignoreChild      : in  std_logic := '0';

      b_unlock_valid            : in  std_logic;
      b_unlock_ready            : out std_logic;
      b_unlock_tag              : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic;
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0)
    );
  end component;

  component ColumnReaderListSync is
    generic (
      ELEMENT_WIDTH             : natural;
      LENGTH_WIDTH              : natural;
      COUNT_MAX                 : natural := 1;
      COUNT_WIDTH               : natural := 1;
      DATA_IN_SLICE             : boolean := false;
      LEN_IN_SLICE              : boolean := false;
      OUT_SLICE                 : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      inl_valid                 : in  std_logic;
      inl_ready                 : out std_logic;
      inl_length                : in  std_logic_vector(LENGTH_WIDTH-1 downto 0);

      ind_valid                 : in  std_logic;
      ind_ready                 : out std_logic;
      ind_data                  : in  std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      ind_count                 : in  std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));

      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_last                  : out std_logic;
      out_dvalid                : out std_logic;
      out_data                  : out std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      out_count                 : out std_logic_vector(COUNT_WIDTH-1 downto 0)
    );
  end component;

  component ColumnReaderListSyncDecoder is
    generic (
      LENGTH_WIDTH              : natural;
      COUNT_MAX                 : natural;
      COUNT_WIDTH               : natural;
      LEN_IN_SLICE              : boolean
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      inl_valid                 : in  std_logic;
      inl_ready                 : out std_logic;
      inl_length                : in  std_logic_vector(LENGTH_WIDTH-1 downto 0);

      ctrl_valid                : out std_logic;
      ctrl_ready                : in  std_logic;
      ctrl_last                 : out std_logic;
      ctrl_dvalid               : out std_logic;
      ctrl_count                : out std_logic_vector(COUNT_WIDTH-1 downto 0)
    );
  end component;

end Columns;

package body Columns is
end Columns;
