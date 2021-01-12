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
use work.ArrayConfig_pkg.all;
use work.ArrayConfigParse_pkg.all;

package Array_pkg is
  -----------------------------------------------------------------------------
  -- ArrayWriter
  -----------------------------------------------------------------------------
  component ArrayWriter is
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
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_ctrl                  : in  std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unl_valid                 : out std_logic;
      unl_ready                 : in  std_logic := '1';
      unl_tag                   : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_wreq_valid            : out std_logic;
      bus_wreq_ready            : in  std_logic;
      bus_wreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      bus_wreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      bus_wreq_last             : out std_logic;
      bus_wdat_valid            : out std_logic;
      bus_wdat_ready            : in  std_logic;
      bus_wdat_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bus_wdat_strobe           : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
      bus_wdat_last             : out std_logic;
      bus_wrep_valid            : in  std_logic;
      bus_wrep_ready            : out std_logic;
      bus_wrep_ok               : in  std_logic;
      in_valid                  : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      in_ready                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      in_last                   : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      in_dvalid                 : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      in_data                   : in  std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
    );
  end component;

  component ArrayWriterLevel is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean;
      CMD_TAG_WIDTH             : natural
    );
    port (
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
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
      bus_wreq_last             : out std_logic_vector;
      bus_wdat_valid            : out std_logic_vector;
      bus_wdat_ready            : in  std_logic_vector;
      bus_wdat_data             : out std_logic_vector;
      bus_wdat_strobe           : out std_logic_vector;
      bus_wdat_last             : out std_logic_vector;
      bus_wrep_valid            : in  std_logic_vector;
      bus_wrep_ready            : out std_logic_vector;
      bus_wrep_ok               : in  std_logic_vector;
      in_valid                  : in  std_logic_vector;
      in_ready                  : out std_logic_vector;
      in_last                   : in  std_logic_vector;
      in_dvalid                 : in  std_logic_vector;
      in_data                   : in  std_logic_vector
    );
  end component;

  component ArrayWriterArb is
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
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
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
      bus_wreq_last             : out std_logic_vector;
      bus_wdat_valid            : out std_logic_vector;
      bus_wdat_ready            : in  std_logic_vector;
      bus_wdat_data             : out std_logic_vector;
      bus_wdat_strobe           : out std_logic_vector;
      bus_wdat_last             : out std_logic_vector;
      bus_wrep_valid            : in  std_logic_vector;
      bus_wrep_ready            : out std_logic_vector;
      bus_wrep_ok               : in  std_logic_vector;
      in_valid                  : in  std_logic_vector;
      in_ready                  : out std_logic_vector;
      in_last                   : in  std_logic_vector;
      in_dvalid                 : in  std_logic_vector;
      in_data                   : in  std_logic_vector
    );
  end component;

  component ArrayWriterListPrim is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      CFG                       : string;
      CMD_TAG_ENABLE            : boolean;
      CMD_TAG_WIDTH             : natural
    );
    port (
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
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
      bus_wreq_last             : out std_logic_vector;
      bus_wdat_valid            : out std_logic_vector;
      bus_wdat_ready            : in  std_logic_vector;
      bus_wdat_data             : out std_logic_vector;
      bus_wdat_strobe           : out std_logic_vector;
      bus_wdat_last             : out std_logic_vector;
      bus_wrep_valid            : in  std_logic_vector;
      bus_wrep_ready            : out std_logic_vector;
      bus_wrep_ok               : in  std_logic_vector;
      in_valid                  : in  std_logic_vector;
      in_ready                  : out std_logic_vector;
      in_last                   : in  std_logic_vector;
      in_dvalid                 : in  std_logic_vector;
      in_data                   : in  std_logic_vector
    );
  end component;

  component ArrayWriterListSync is
    generic (
      LENGTH_WIDTH              : positive;
      LCOUNT_MAX                : positive := 1;
      LCOUNT_WIDTH              : positive := 1
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_len_valid              : in  std_logic;
      in_len_ready              : out std_logic;
      in_len_count              : in  std_logic_vector(LCOUNT_WIDTH-1 downto 0);
      in_len_last               : in  std_logic;
      out_len_valid             : out std_logic;
      out_len_ready             : in  std_logic;
      in_val_valid              : in  std_logic;
      in_val_ready              : out std_logic;
      in_val_last               : in  std_logic;
      out_val_valid             : out std_logic;
      out_val_ready             : in  std_logic;
      out_val_last              : out std_logic
    );
  end component;

  -----------------------------------------------------------------------------
  -- ArrayReader
  -----------------------------------------------------------------------------
  component ArrayReader is
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
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_firstIdx              : in  std_logic_vector;
      cmd_lastIdx               : in  std_logic_vector;
      cmd_ctrl                  : in  std_logic_vector;
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      unl_valid                 : out std_logic;
      unl_ready                 : in  std_logic := '1';
      unl_tag                   : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_rreq_valid            : out std_logic;
      bus_rreq_ready            : in  std_logic;
      bus_rreq_addr             : out std_logic_vector;
      bus_rreq_len              : out std_logic_vector;
      bus_rdat_valid            : in  std_logic;
      bus_rdat_ready            : out std_logic;
      bus_rdat_data             : in  std_logic_vector;
      bus_rdat_last             : in  std_logic;
      out_valid                 : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_ready                 : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_last                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_dvalid                : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_data                  : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
    );
  end component;

  component ArrayReaderLevel is
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
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
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

  component ArrayReaderArb is
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
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
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

  component ArrayReaderNull is
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
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
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

  component ArrayReaderList is
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
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
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

  component ArrayReaderListPrim is
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
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
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

  component ArrayReaderStruct is
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
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
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

  component ArrayReaderUnlockCombine is
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

  component ArrayReaderListSync is
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

  component ArrayReaderListSyncDecoder is
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
  
  component ArrayCmdCtrlMerger is
    generic (
      BUS_ADDR_WIDTH            : positive := 64;
      NUM_ADDR                  : positive := 1;
      TAG_WIDTH                 : positive := 1;
      INDEX_WIDTH               : positive := 32
    );
    port (
      nucleus_cmd_valid         : out std_logic;
      nucleus_cmd_ready         : in  std_logic;
      nucleus_cmd_firstIdx      : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      nucleus_cmd_lastidx       : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      nucleus_cmd_ctrl          : out std_logic_vector(NUM_ADDR * BUS_ADDR_WIDTH-1 downto 0);
      nucleus_cmd_tag           : out std_logic_vector(TAG_WIDTH-1 downto 0);
      kernel_cmd_valid          : in  std_logic;
      kernel_cmd_ready          : out std_logic;
      kernel_cmd_firstIdx       : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      kernel_cmd_lastidx        : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      kernel_cmd_tag            : in  std_logic_vector(TAG_WIDTH-1 downto 0);
      ctrl                      : in  std_logic_vector(NUM_ADDR * BUS_ADDR_WIDTH-1 downto 0)
    );
  end component;

end Array_pkg;
