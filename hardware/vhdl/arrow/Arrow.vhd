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
use work.ColumnReaderConfig.all;
use work.ColumnReaderConfigParse.all;

package Arrow is
  -----------------------------------------------------------------------------
  -- General address alignment requirements
  -----------------------------------------------------------------------------
  -- The burst boundary in bytes. Bursts will not cross this boundary unless
  -- burst lengths are set to something higher than this.
  -- This is currently set to the AXI4 specification of 4096 byte boundaries:
  constant BUS_BURST_BOUNDARY     : natural := 4096;

  -- Bus write data bits covered by single write strobe bit.
  -- This is currently set to the AXI4 specification of 1 byte / strobe bit.
  constant BUS_WSB                : natural := 8;

  -- The Arrow format specification on buffer address alignment in bytes:
  constant REQ_ARROW_BUFFER_ALIGN : natural := 8;

  -- The Arrow format recommendation on buffer address alignment in bytes:
  constant REC_ARROW_BUFFER_ALIGN : natural := 64;

  -----------------------------------------------------------------------------
  -- ColumnWriter
  -----------------------------------------------------------------------------
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
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      BUS_BURST_STEP_LEN        : natural := 4;
      BUS_BURST_MAX_LEN         : natural := 16;
      INDEX_WIDTH               : natural := 32;
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
      cmd_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_ctrl                  : in  std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      busReq_valid              : out std_logic;
      busReq_ready              : in  std_logic;
      busReq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      busReq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      busResp_valid             : in  std_logic;
      busResp_ready             : out std_logic;
      busResp_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      busResp_last              : in  std_logic;

      out_valid                 : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_ready                 : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_last                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_dvalid                : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_data                  : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
    );
  end component;

  component ColumnReaderLevel is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      BUS_BURST_STEP_LEN        : natural := 4;
      BUS_BURST_MAX_LEN         : natural := 16;
      INDEX_WIDTH               : natural := 32;
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
      cmd_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_ctrl                  : in  std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      busReq_valid              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_ready              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_addr               : out std_logic_vector(arcfg_busCount(CFG)*BUS_ADDR_WIDTH-1 downto 0);
      busReq_len                : out std_logic_vector(arcfg_busCount(CFG)*BUS_LEN_WIDTH-1 downto 0);
      busResp_valid             : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_ready             : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_data              : in  std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH-1 downto 0);
      busResp_last              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);

      out_valid                 : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_ready                 : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_last                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_dvalid                : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_data                  : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
    );
  end component;

  component ColumnReaderArb is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      BUS_BURST_STEP_LEN        : natural := 4;
      BUS_BURST_MAX_LEN         : natural := 16;
      INDEX_WIDTH               : natural := 32;
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
      cmd_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_ctrl                  : in  std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      busReq_valid              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_ready              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_addr               : out std_logic_vector(arcfg_busCount(CFG)*BUS_ADDR_WIDTH-1 downto 0);
      busReq_len                : out std_logic_vector(arcfg_busCount(CFG)*BUS_LEN_WIDTH-1 downto 0);
      busResp_valid             : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_ready             : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_data              : in  std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH-1 downto 0);
      busResp_last              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);

      out_valid                 : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_ready                 : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_last                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_dvalid                : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_data                  : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
    );
  end component;

  component ColumnReaderNull is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      BUS_BURST_STEP_LEN        : natural := 4;
      BUS_BURST_MAX_LEN         : natural := 16;
      INDEX_WIDTH               : natural := 32;
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
      cmd_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_ctrl                  : in  std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      busReq_valid              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_ready              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_addr               : out std_logic_vector(arcfg_busCount(CFG)*BUS_ADDR_WIDTH-1 downto 0);
      busReq_len                : out std_logic_vector(arcfg_busCount(CFG)*BUS_LEN_WIDTH-1 downto 0);
      busResp_valid             : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_ready             : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_data              : in  std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH-1 downto 0);
      busResp_last              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);

      out_valid                 : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_ready                 : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_last                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_dvalid                : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_data                  : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
    );
  end component;

  component ColumnReaderList is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      BUS_BURST_STEP_LEN        : natural := 4;
      BUS_BURST_MAX_LEN         : natural := 16;
      INDEX_WIDTH               : natural := 32;
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
      cmd_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_ctrl                  : in  std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      busReq_valid              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_ready              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_addr               : out std_logic_vector(arcfg_busCount(CFG)*BUS_ADDR_WIDTH-1 downto 0);
      busReq_len                : out std_logic_vector(arcfg_busCount(CFG)*BUS_LEN_WIDTH-1 downto 0);
      busResp_valid             : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_ready             : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_data              : in  std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH-1 downto 0);
      busResp_last              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);

      out_valid                 : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_ready                 : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_last                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_dvalid                : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_data                  : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
    );
  end component;

  component ColumnReaderListPrim is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      BUS_BURST_STEP_LEN        : natural := 4;
      BUS_BURST_MAX_LEN         : natural := 16;
      INDEX_WIDTH               : natural := 32;
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
      cmd_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_ctrl                  : in  std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      busReq_valid              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_ready              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_addr               : out std_logic_vector(arcfg_busCount(CFG)*BUS_ADDR_WIDTH-1 downto 0);
      busReq_len                : out std_logic_vector(arcfg_busCount(CFG)*BUS_LEN_WIDTH-1 downto 0);
      busResp_valid             : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_ready             : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_data              : in  std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH-1 downto 0);
      busResp_last              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);

      out_valid                 : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_ready                 : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_last                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_dvalid                : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_data                  : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
    );
  end component;

  component ColumnReaderStruct is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      BUS_BURST_STEP_LEN        : natural := 4;
      BUS_BURST_MAX_LEN         : natural := 16;
      INDEX_WIDTH               : natural := 32;
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
      cmd_firstIdx              : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_lastIdx               : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_ctrl                  : in  std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
      cmd_tag                   : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      busReq_valid              : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_ready              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busReq_addr               : out std_logic_vector(arcfg_busCount(CFG)*BUS_ADDR_WIDTH-1 downto 0);
      busReq_len                : out std_logic_vector(arcfg_busCount(CFG)*BUS_LEN_WIDTH-1 downto 0);
      busResp_valid             : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_ready             : out std_logic_vector(arcfg_busCount(CFG)-1 downto 0);
      busResp_data              : in  std_logic_vector(arcfg_busCount(CFG)*BUS_DATA_WIDTH-1 downto 0);
      busResp_last              : in  std_logic_vector(arcfg_busCount(CFG)-1 downto 0);

      out_valid                 : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_ready                 : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_last                  : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_dvalid                : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
      out_data                  : out std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)
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

  -----------------------------------------------------------------------------
  -- Buffer reader
  -----------------------------------------------------------------------------
  component BufferReader is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      BUS_BURST_STEP_LEN        : natural := 4;
      BUS_BURST_MAX_LEN         : natural := 16;
      INDEX_WIDTH               : natural := 32;
      ELEMENT_WIDTH             : natural := 8;
      IS_INDEX_BUFFER           : boolean := false;
      ELEMENT_COUNT_MAX         : natural := 1;
      ELEMENT_COUNT_WIDTH       : natural := 1;
      CMD_CTRL_WIDTH            : natural := 1;
      CMD_TAG_WIDTH             : natural := 1;
      CMD_IN_SLICE              : boolean := false;
      BUS_REQ_SLICE             : boolean := false;
      BUS_FIFO_DEPTH            : natural := 16;
      BUS_FIFO_RAM_CONFIG       : string  := "";
      CMD_OUT_SLICE             : boolean := true;
      UNLOCK_SLICE              : boolean := true;
      SHR2GB_SLICE              : boolean := false;
      GB2FIFO_SLICE             : boolean := false;
      ELEMENT_FIFO_SIZE         : natural := 64;
      ELEMENT_FIFO_RAM_CONFIG   : string  := "";
      ELEMENT_FIFO_XCLK_STAGES  : natural := 0;
      FIFO2POST_SLICE           : boolean := false;
      OUT_SLICE                 : boolean := true
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;

      cmdIn_valid               : in  std_logic;
      cmdIn_ready               : out std_logic;
      cmdIn_firstIdx            : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_lastIdx             : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_baseAddr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      cmdIn_implicit            : in  std_logic := '0';
      cmdIn_ctrl                : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0) := (others => '0');
      cmdIn_tag                 : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

      cmdOut_valid              : out std_logic;
      cmdOut_ready              : in  std_logic := '1';
      cmdOut_firstIdx           : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdOut_lastIdx            : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdOut_ctrl               : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0) := (others => '0');
      cmdOut_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
      unlock_ignoreChild        : out std_logic;

      busReq_valid              : out std_logic;
      busReq_ready              : in  std_logic;
      busReq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      busReq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

      busResp_valid             : in  std_logic;
      busResp_ready             : out std_logic;
      busResp_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      busResp_last              : in  std_logic;

      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      out_count                 : out std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      out_last                  : out std_logic
    );
  end component;

  component BufferReaderCmd is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      ELEMENT_WIDTH             : natural;
      IS_INDEX_BUFFER           : boolean;
      CMD_CTRL_WIDTH            : natural;
      CMD_TAG_WIDTH             : natural;
      CMD_IN_SLICE              : boolean;
      BUS_REQ_SLICE             : boolean
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      cmdIn_valid               : in  std_logic;
      cmdIn_ready               : out std_logic;
      cmdIn_firstIdx            : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_lastIdx             : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_baseAddr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      cmdIn_implicit            : in  std_logic;
      cmdIn_ctrl                : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
      cmdIn_tag                 : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      busReq_valid              : out std_logic;
      busReq_ready              : in  std_logic;
      busReq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      busReq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

      intCmd_valid              : out std_logic;
      intCmd_ready              : in  std_logic;
      intCmd_firstIdx           : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      intCmd_lastIdx            : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      intCmd_implicit           : out std_logic;
      intCmd_ctrl               : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
      intCmd_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0)
    );
  end component;

  component BufferReaderCmdGenBusReq is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      ELEMENT_WIDTH             : natural;
      IS_INDEX_BUFFER           : boolean;
      CHECK_INDEX               : boolean
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      cmdIn_valid               : in  std_logic;
      cmdIn_ready               : out std_logic;
      cmdIn_firstIdx            : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_lastIdx             : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_baseAddr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      cmdIn_implicit            : in  std_logic;

      busReq_valid              : out std_logic;
      busReq_ready              : in  std_logic;
      busReq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      busReq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0)
    );
  end component;

  component BufferReaderResp is
    generic (
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      INDEX_WIDTH               : natural;
      ELEMENT_WIDTH             : natural;
      IS_INDEX_BUFFER           : boolean;
      ICS_SHIFT_WIDTH           : natural;
      ICS_COUNT_WIDTH           : natural;
      ELEMENT_FIFO_COUNT_MAX    : natural;
      ELEMENT_FIFO_COUNT_WIDTH  : natural;
      CMD_CTRL_WIDTH            : natural;
      CMD_TAG_WIDTH             : natural;
      CMD_OUT_SLICE             : boolean;
      SHR2GB_SLICE              : boolean;
      GB2FIFO_SLICE             : boolean;
      UNLOCK_SLICE              : boolean
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      busResp_valid             : in  std_logic;
      busResp_ready             : out std_logic;
      busResp_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

      intCmd_valid              : in  std_logic;
      intCmd_ready              : out std_logic;
      intCmd_firstIdx           : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      intCmd_lastIdx            : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      intCmd_implicit           : in  std_logic;
      intCmd_ctrl               : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
      intCmd_tag                : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      cmdOut_valid              : out std_logic;
      cmdOut_ready              : in  std_logic := '1';
      cmdOut_firstIdx           : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdOut_lastIdx            : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdOut_ctrl               : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
      cmdOut_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
      unlock_ignoreChild        : out std_logic;

      fifoIn_valid              : out std_logic;
      fifoIn_ready              : in  std_logic;
      fifoIn_data               : out std_logic_vector(ELEMENT_FIFO_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      fifoIn_count              : out std_logic_vector(ELEMENT_FIFO_COUNT_WIDTH-1 downto 0);
      fifoIn_last               : out std_logic
    );
  end component;

  component BufferReaderRespCtrl is
    generic (
      INDEX_WIDTH               : natural;
      IS_INDEX_BUFFER           : boolean;
      ICS_SHIFT_WIDTH           : natural;
      ICS_COUNT_WIDTH           : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      ELEMENT_WIDTH             : natural;
      CMD_CTRL_WIDTH            : natural;
      CMD_TAG_WIDTH             : natural;
      CHECK_INDEX               : boolean
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      cmdIn_valid               : in  std_logic;
      cmdIn_ready               : out std_logic;
      cmdIn_firstIdx            : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_lastIdx             : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_implicit            : in  std_logic;
      cmdIn_ctrl                : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
      cmdIn_tag                 : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

      intCmd_valid              : out std_logic;
      intCmd_ready              : in  std_logic;
      intCmd_implicit           : out std_logic;
      intCmd_shift              : out std_logic_vector(ICS_SHIFT_WIDTH-1 downto 0);
      intCmd_count              : out std_logic_vector(ICS_COUNT_WIDTH-1 downto 0);
      intCmd_init               : out std_logic;
      intCmd_last               : out std_logic;
      intCmd_ctrl               : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
      intCmd_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0)
    );
  end component;

  component BufferReaderPost is
    generic (
      ELEMENT_WIDTH             : natural;
      IS_INDEX_BUFFER           : boolean;
      ELEMENT_FIFO_COUNT_MAX    : natural;
      ELEMENT_FIFO_COUNT_WIDTH  : natural;
      ELEMENT_COUNT_MAX         : natural;
      ELEMENT_COUNT_WIDTH       : natural;
      FIFO2POST_SLICE           : boolean;
      OUT_SLICE                 : boolean
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      fifoOut_valid             : in  std_logic;
      fifoOut_ready             : out std_logic;
      fifoOut_data              : in  std_logic_vector(ELEMENT_FIFO_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      fifoOut_count             : in  std_logic_vector(ELEMENT_FIFO_COUNT_WIDTH-1 downto 0);
      fifoOut_last              : in  std_logic;

      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      out_count                 : out std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      out_last                  : out std_logic
    );
  end component;

  -----------------------------------------------------------------------------
  -- Bus devices
  -----------------------------------------------------------------------------
  component BusArbiter is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      NUM_MASTERS               : natural := 2;
      ARB_METHOD                : string  := "ROUND-ROBIN";
      MAX_OUTSTANDING           : natural := 2;
      RAM_CONFIG                : string  := "";
      REQ_IN_SLICES             : boolean := false;
      REQ_OUT_SLICE             : boolean := true;
      RESP_IN_SLICE             : boolean := false;
      RESP_OUT_SLICES           : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      slv_req_valid             : out std_logic;
      slv_req_ready             : in  std_logic;
      slv_req_addr              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      slv_req_len               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      slv_resp_valid            : in  std_logic;
      slv_resp_ready            : out std_logic;
      slv_resp_data             : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      slv_resp_last             : in  std_logic;

      -- Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn

      bm0_req_valid             : in  std_logic := '0';
      bm0_req_ready             : out std_logic;
      bm0_req_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm0_req_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm0_resp_valid            : out std_logic;
      bm0_resp_ready            : in  std_logic := '1';
      bm0_resp_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm0_resp_last             : out std_logic;

      bm1_req_valid             : in  std_logic := '0';
      bm1_req_ready             : out std_logic;
      bm1_req_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm1_req_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm1_resp_valid            : out std_logic;
      bm1_resp_ready            : in  std_logic := '1';
      bm1_resp_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm1_resp_last             : out std_logic;

      bm2_req_valid             : in  std_logic := '0';
      bm2_req_ready             : out std_logic;
      bm2_req_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm2_req_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm2_resp_valid            : out std_logic;
      bm2_resp_ready            : in  std_logic := '1';
      bm2_resp_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm2_resp_last             : out std_logic;

      bm3_req_valid             : in  std_logic := '0';
      bm3_req_ready             : out std_logic;
      bm3_req_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm3_req_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm3_resp_valid            : out std_logic;
      bm3_resp_ready            : in  std_logic := '1';
      bm3_resp_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm3_resp_last             : out std_logic;

      bm4_req_valid             : in  std_logic := '0';
      bm4_req_ready             : out std_logic;
      bm4_req_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm4_req_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm4_resp_valid            : out std_logic;
      bm4_resp_ready            : in  std_logic := '1';
      bm4_resp_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm4_resp_last             : out std_logic;

      bm5_req_valid             : in  std_logic := '0';
      bm5_req_ready             : out std_logic;
      bm5_req_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm5_req_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm5_resp_valid            : out std_logic;
      bm5_resp_ready            : in  std_logic := '1';
      bm5_resp_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm5_resp_last             : out std_logic;

      bm6_req_valid             : in  std_logic := '0';
      bm6_req_ready             : out std_logic;
      bm6_req_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm6_req_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm6_resp_valid            : out std_logic;
      bm6_resp_ready            : in  std_logic := '1';
      bm6_resp_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm6_resp_last             : out std_logic;

      bm7_req_valid             : in  std_logic := '0';
      bm7_req_ready             : out std_logic;
      bm7_req_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm7_req_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm7_resp_valid            : out std_logic;
      bm7_resp_ready            : in  std_logic := '1';
      bm7_resp_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm7_resp_last             : out std_logic;

      bm8_req_valid             : in  std_logic := '0';
      bm8_req_ready             : out std_logic;
      bm8_req_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm8_req_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm8_resp_valid            : out std_logic;
      bm8_resp_ready            : in  std_logic := '1';
      bm8_resp_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm8_resp_last             : out std_logic;

      bm9_req_valid             : in  std_logic := '0';
      bm9_req_ready             : out std_logic;
      bm9_req_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm9_req_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm9_resp_valid            : out std_logic;
      bm9_resp_ready            : in  std_logic := '1';
      bm9_resp_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm9_resp_last             : out std_logic;

      bm10_req_valid            : in  std_logic := '0';
      bm10_req_ready            : out std_logic;
      bm10_req_addr             : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm10_req_len              : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm10_resp_valid           : out std_logic;
      bm10_resp_ready           : in  std_logic := '1';
      bm10_resp_data            : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm10_resp_last            : out std_logic;

      bm11_req_valid            : in  std_logic := '0';
      bm11_req_ready            : out std_logic;
      bm11_req_addr             : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm11_req_len              : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm11_resp_valid           : out std_logic;
      bm11_resp_ready           : in  std_logic := '1';
      bm11_resp_data            : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm11_resp_last            : out std_logic;

      bm12_req_valid            : in  std_logic := '0';
      bm12_req_ready            : out std_logic;
      bm12_req_addr             : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm12_req_len              : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm12_resp_valid           : out std_logic;
      bm12_resp_ready           : in  std_logic := '1';
      bm12_resp_data            : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm12_resp_last            : out std_logic;

      bm13_req_valid            : in  std_logic := '0';
      bm13_req_ready            : out std_logic;
      bm13_req_addr             : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm13_req_len              : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm13_resp_valid           : out std_logic;
      bm13_resp_ready           : in  std_logic := '1';
      bm13_resp_data            : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm13_resp_last            : out std_logic;

      bm14_req_valid            : in  std_logic := '0';
      bm14_req_ready            : out std_logic;
      bm14_req_addr             : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm14_req_len              : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm14_resp_valid           : out std_logic;
      bm14_resp_ready           : in  std_logic := '1';
      bm14_resp_data            : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm14_resp_last            : out std_logic;

      bm15_req_valid            : in  std_logic := '0';
      bm15_req_ready            : out std_logic;
      bm15_req_addr             : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bm15_req_len              : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bm15_resp_valid           : out std_logic;
      bm15_resp_ready           : in  std_logic := '1';
      bm15_resp_data            : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bm15_resp_last            : out std_logic
    );
  end component;

  component BusArbiterVec is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      NUM_MASTERS               : natural := 2;
      ARB_METHOD                : string := "ROUND-ROBIN";
      MAX_OUTSTANDING           : natural := 2;
      RAM_CONFIG                : string := "";
      REQ_IN_SLICES             : boolean := false;
      REQ_OUT_SLICE             : boolean := true;
      RESP_IN_SLICE             : boolean := false;
      RESP_OUT_SLICES           : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      slv_req_valid             : out std_logic;
      slv_req_ready             : in  std_logic;
      slv_req_addr              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      slv_req_len               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      slv_resp_valid            : in  std_logic;
      slv_resp_ready            : out std_logic;
      slv_resp_data             : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      slv_resp_last             : in  std_logic;

      bmv_req_valid             : in  std_logic_vector(NUM_MASTERS-1 downto 0);
      bmv_req_ready             : out std_logic_vector(NUM_MASTERS-1 downto 0);
      bmv_req_addr              : in  std_logic_vector(NUM_MASTERS*BUS_ADDR_WIDTH-1 downto 0);
      bmv_req_len               : in  std_logic_vector(NUM_MASTERS*BUS_LEN_WIDTH-1 downto 0);
      bmv_resp_valid            : out std_logic_vector(NUM_MASTERS-1 downto 0);
      bmv_resp_ready            : in  std_logic_vector(NUM_MASTERS-1 downto 0);
      bmv_resp_data             : out std_logic_vector(NUM_MASTERS*BUS_DATA_WIDTH-1 downto 0);
      bmv_resp_last             : out std_logic_vector(NUM_MASTERS-1 downto 0)
    );
  end component;

  component BusBuffer is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      FIFO_DEPTH                : natural;
      RAM_CONFIG                : string;
      REQ_IN_SLICE              : boolean;
      REQ_OUT_SLICE             : boolean;
      RESP_IN_SLICE             : boolean;
      RESP_OUT_SLICE            : boolean
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      mst_req_valid             : in  std_logic;
      mst_req_ready             : out std_logic;
      mst_req_addr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      mst_req_len               : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      mst_resp_valid            : out std_logic;
      mst_resp_ready            : in  std_logic;
      mst_resp_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      mst_resp_last             : out std_logic;

      slv_req_valid             : out std_logic;
      slv_req_ready             : in  std_logic;
      slv_req_addr              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      slv_req_len               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      slv_resp_valid            : in  std_logic;
      slv_resp_ready            : out std_logic;
      slv_resp_data             : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      slv_resp_last             : in  std_logic
    );
  end component;

  component BusWriteArbiter is
    generic (
      BUS_ADDR_WIDTH              : natural;
      BUS_LEN_WIDTH               : natural;
      BUS_DATA_WIDTH              : natural;
      BUS_STROBE_WIDTH            : natural;
      NUM_SLAVES                  : natural;
      ARB_METHOD                  : string;
      MAX_OUTSTANDING             : natural;
      RAM_CONFIG                  : string;
      REQ_IN_SLICES               : boolean;
      REQ_OUT_SLICE               : boolean;
      DAT_IN_SLICE                : boolean;
      DAT_OUT_SLICE               : boolean
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      mst_wreq_valid            : out std_logic;
      mst_wreq_ready            : in  std_logic;
      mst_wreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      mst_wreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      mst_wdat_valid            : out std_logic;
      mst_wdat_ready            : in  std_logic;
      mst_wdat_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      mst_wdat_strobe           : out std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0);
      mst_wdat_last             : out std_logic;

      -- Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn

      -- Slave port 0.
      bs00_wreq_valid           : in  std_logic := '0';
      bs00_wreq_ready           : out std_logic;
      bs00_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs00_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs00_wdat_valid           : in  std_logic := '0';
      bs00_wdat_ready           : out std_logic := '1';
      bs00_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs00_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs00_wdat_last            : in  std_logic := 'U';

      -- Slave port 1.
      bs01_wreq_valid           : in  std_logic := '0';
      bs01_wreq_ready           : out std_logic;
      bs01_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs01_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs01_wdat_valid           : in  std_logic := '0';
      bs01_wdat_ready           : out std_logic := '1';
      bs01_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs01_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs01_wdat_last            : in  std_logic := 'U';

      -- Slave port 2.
      bs02_wreq_valid           : in  std_logic := '0';
      bs02_wreq_ready           : out std_logic;
      bs02_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs02_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs02_wdat_valid           : in  std_logic := '0';
      bs02_wdat_ready           : out std_logic := '1';
      bs02_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs02_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs02_wdat_last            : in  std_logic := 'U';

      -- Slave port 3.
      bs03_wreq_valid           : in  std_logic := '0';
      bs03_wreq_ready           : out std_logic;
      bs03_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs03_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs03_wdat_valid           : in  std_logic := '0';
      bs03_wdat_ready           : out std_logic := '1';
      bs03_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs03_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs03_wdat_last            : in  std_logic := 'U';

      -- Slave port 4.
      bs04_wreq_valid           : in  std_logic := '0';
      bs04_wreq_ready           : out std_logic;
      bs04_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs04_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs04_wdat_valid           : in  std_logic := '0';
      bs04_wdat_ready           : out std_logic := '1';
      bs04_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs04_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs04_wdat_last            : in  std_logic := 'U';

      -- Slave port 5.
      bs05_wreq_valid           : in  std_logic := '0';
      bs05_wreq_ready           : out std_logic;
      bs05_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs05_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs05_wdat_valid           : in  std_logic := '0';
      bs05_wdat_ready           : out std_logic := '1';
      bs05_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs05_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs05_wdat_last            : in  std_logic := 'U';

      -- Slave port 6.
      bs06_wreq_valid           : in  std_logic := '0';
      bs06_wreq_ready           : out std_logic;
      bs06_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs06_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs06_wdat_valid           : in  std_logic := '0';
      bs06_wdat_ready           : out std_logic := '1';
      bs06_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs06_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs06_wdat_last            : in  std_logic := 'U';

      -- Slave port 7.
      bs07_wreq_valid           : in  std_logic := '0';
      bs07_wreq_ready           : out std_logic;
      bs07_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs07_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs07_wdat_valid           : in  std_logic := '0';
      bs07_wdat_ready           : out std_logic := '1';
      bs07_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs07_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs07_wdat_last            : in  std_logic := 'U';

      -- Slave port 8.
      bs08_wreq_valid           : in  std_logic := '0';
      bs08_wreq_ready           : out std_logic;
      bs08_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs08_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs08_wdat_valid           : in  std_logic := '0';
      bs08_wdat_ready           : out std_logic := '1';
      bs08_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs08_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs08_wdat_last            : in  std_logic := 'U';

      -- Slave port 9.
      bs09_wreq_valid           : in  std_logic := '0';
      bs09_wreq_ready           : out std_logic;
      bs09_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs09_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs09_wdat_valid           : in  std_logic := '0';
      bs09_wdat_ready           : out std_logic := '1';
      bs09_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs09_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs09_wdat_last            : in  std_logic := 'U';

      -- Slave port 10.
      bs10_wreq_valid           : in  std_logic := '0';
      bs10_wreq_ready           : out std_logic;
      bs10_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs10_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs10_wdat_valid           : in  std_logic := '0';
      bs10_wdat_ready           : out std_logic := '1';
      bs10_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs10_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs10_wdat_last            : in  std_logic := 'U';

      -- Slave port 11.
      bs11_wreq_valid           : in  std_logic := '0';
      bs11_wreq_ready           : out std_logic;
      bs11_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs11_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs11_wdat_valid           : in  std_logic := '0';
      bs11_wdat_ready           : out std_logic := '1';
      bs11_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs11_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs11_wdat_last            : in  std_logic := 'U';

      -- Slave port 12.
      bs12_wreq_valid           : in  std_logic := '0';
      bs12_wreq_ready           : out std_logic;
      bs12_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs12_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs12_wdat_valid           : in  std_logic := '0';
      bs12_wdat_ready           : out std_logic := '1';
      bs12_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs12_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs12_wdat_last            : in  std_logic := 'U';

      -- Slave port 13.
      bs13_wreq_valid           : in  std_logic := '0';
      bs13_wreq_ready           : out std_logic;
      bs13_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs13_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs13_wdat_valid           : in  std_logic := '0';
      bs13_wdat_ready           : out std_logic := '1';
      bs13_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs13_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs13_wdat_last            : in  std_logic := 'U';

      -- Slave port 14.
      bs14_wreq_valid           : in  std_logic := '0';
      bs14_wreq_ready           : out std_logic;
      bs14_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs14_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs14_wdat_valid           : in  std_logic := '0';
      bs14_wdat_ready           : out std_logic := '1';
      bs14_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs14_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs14_wdat_last            : in  std_logic := 'U';

      -- Slave port 15.
      bs15_wreq_valid           : in  std_logic := '0';
      bs15_wreq_ready           : out std_logic;
      bs15_wreq_addr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0) := (others => '0');
      bs15_wreq_len             : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0) := (others => '0');
      bs15_wdat_valid           : in  std_logic := '0';
      bs15_wdat_ready           : out std_logic := '1';
      bs15_wdat_data            : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0) := (others => 'U');
      bs15_wdat_strobe          : in  std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0) := (others => 'U');
      bs15_wdat_last            : in  std_logic := 'U'
    );
  end component;

  component BusWriteArbiterVec is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      BUS_STROBE_WIDTH          : natural := 32/8;
      NUM_SLAVES                : natural := 2;
      ARB_METHOD                : string  := "ROUND-ROBIN";
      MAX_OUTSTANDING           : natural := 2;
      RAM_CONFIG                : string  := "";
      REQ_IN_SLICES             : boolean := false;
      REQ_OUT_SLICE             : boolean := true;
      DAT_IN_SLICE              : boolean := false;
      DAT_OUT_SLICE             : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      mst_wreq_valid            : out std_logic;
      mst_wreq_ready            : in  std_logic;
      mst_wreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      mst_wreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      mst_wdat_valid            : out std_logic;
      mst_wdat_ready            : in  std_logic;
      mst_wdat_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      mst_wdat_strobe           : out std_logic_vector(BUS_DATA_WIDTH/BUS_WSB-1 downto 0);
      mst_wdat_last             : out  std_logic;
      bsv_wreq_valid            : in  std_logic_vector(NUM_SLAVES-1 downto 0);
      bsv_wreq_ready            : out std_logic_vector(NUM_SLAVES-1 downto 0);
      bsv_wreq_addr             : in  std_logic_vector(NUM_SLAVES*BUS_ADDR_WIDTH-1 downto 0);
      bsv_wreq_len              : in  std_logic_vector(NUM_SLAVES*BUS_LEN_WIDTH-1 downto 0);
      bsv_wdat_valid            : in  std_logic_vector(NUM_SLAVES-1 downto 0);
      bsv_wdat_ready            : out std_logic_vector(NUM_SLAVES-1 downto 0);
      bsv_wdat_data             : in  std_logic_vector(NUM_SLAVES*BUS_DATA_WIDTH-1 downto 0);
      bsv_wdat_strobe           : in  std_logic_vector(NUM_SLAVES*BUS_DATA_WIDTH/BUS_WSB-1 downto 0);
      bsv_wdat_last             : in  std_logic_vector(NUM_SLAVES-1 downto 0)
    );
  end component;

  component BufferWriter is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_STROBE_WIDTH          : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      BUS_FIFO_DEPTH            : natural;
      BUS_FIFO_THRESHOLD_SHIFT  : natural;
      INDEX_WIDTH               : natural;
      ELEMENT_WIDTH             : natural;
      IS_INDEX_BUFFER           : boolean;
      ELEMENT_COUNT_MAX         : natural;
      ELEMENT_COUNT_WIDTH       : natural;
      CMD_CTRL_WIDTH            : natural;
      CMD_TAG_WIDTH             : natural
    );
    port (
      bus_clk                   : in  std_logic;
      bus_reset                 : in  std_logic;
      acc_clk                   : in  std_logic;
      acc_reset                 : in  std_logic;
      cmdIn_valid               : in  std_logic;
      cmdIn_ready               : out std_logic;
      cmdIn_firstIdx            : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_lastIdx             : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_baseAddr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      cmdIn_implicit            : in  std_logic := '0';
      cmdIn_tag                 : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      in_last                   : in  std_logic;
      offset_valid              : out std_logic;
      offset_ready              : in  std_logic := '1';
      offset_data               : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      bus_wreq_valid            : out std_logic;
      bus_wreq_ready            : in  std_logic;
      bus_wreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      bus_wreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      bus_wdat_valid            : out std_logic;
      bus_wdat_ready            : in  std_logic;
      bus_wdat_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bus_wdat_strobe           : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
      bus_wdat_last             : out std_logic
    );
  end component;

  component BufferWriterPre is
    generic (
      INDEX_WIDTH               : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_STROBE_WIDTH          : natural;
      IS_INDEX_BUFFER           : boolean;
      ELEMENT_WIDTH             : natural;
      ELEMENT_COUNT_MAX         : natural := 1;
      ELEMENT_COUNT_WIDTH       : natural := 1;
      CMD_CTRL_WIDTH            : natural;
      CMD_TAG_WIDTH             : natural
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      cmdIn_valid               : in  std_logic;
      cmdIn_ready               : out std_logic;
      cmdIn_firstIdx            : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_lastIdx             : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_implicit            : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_dvalid                 : in  std_logic;
      in_data                   : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      in_last                   : in  std_logic;
      offset_valid              : out std_logic;
      offset_ready              : in  std_logic;
      offset_data               : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      out_strobe                : out std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
      out_last                  : out std_logic
    );
  end component;

  component BufferWriterPrePadder is
    generic (
      INDEX_WIDTH               : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      IS_INDEX_BUFFER           : boolean;
      ELEMENT_WIDTH             : natural;
      ELEMENT_COUNT_MAX         : natural := 1;
      ELEMENT_COUNT_WIDTH       : natural := 1;
      CMD_CTRL_WIDTH            : natural;
      CMD_TAG_WIDTH             : natural
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      cmdIn_valid               : in  std_logic;
      cmdIn_ready               : out std_logic;
      cmdIn_firstIdx            : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_lastIdx             : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_implicit            : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      in_last                   : in  std_logic;
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      out_count                 : out std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      out_strobe                : out std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
      out_last                  : out std_logic;
      out_clear                 : out std_logic
    );
  end component;

  component BufferWriterCmdGenBusReq is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      STEPS_COUNT_WIDTH         : natural;
      STEPS_COUNT_MAX           : natural;
      INDEX_WIDTH               : natural;
      ELEMENT_WIDTH             : natural;
      IS_INDEX_BUFFER           : boolean;
      CHECK_INDEX               : boolean := false
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      cmdIn_valid               : in  std_logic;
      cmdIn_ready               : out std_logic;
      cmdIn_firstIdx            : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_lastIdx             : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_baseAddr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      cmdIn_implicit            : in  std_logic;
      steps_ready               : out std_logic;
      steps_valid               : in  std_logic;
      steps_last                : in  std_logic;
      steps_count               : in  std_logic_vector(STEPS_COUNT_WIDTH-1 downto 0);
      busReq_valid              : out std_logic;
      busReq_ready              : in  std_logic;
      busReq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      busReq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0)
    );
  end component;

  component BusWriteBuffer is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_STROBE_WIDTH          : natural;
      FIFO_DEPTH                : natural;
      LEN_SHIFT                 : natural;
      RAM_CONFIG                : string;
      SLV_LAST_MODE             : string := "burst"
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      full                      : out std_logic;
      empty                     : out std_logic;
      mst_wreq_valid            : out std_logic;
      mst_wreq_ready            : in  std_logic;
      mst_wreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      mst_wreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      mst_wdat_valid            : out std_logic;
      mst_wdat_ready            : in  std_logic;
      mst_wdat_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      mst_wdat_strobe           : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
      mst_wdat_last             : out std_logic;
      mst_wdat_last_in_cmd      : out std_logic;
      slv_wreq_valid            : in  std_logic;
      slv_wreq_ready            : out std_logic;
      slv_wreq_addr             : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      slv_wreq_len              : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      slv_wdat_valid            : in  std_logic;
      slv_wdat_ready            : out std_logic;
      slv_wdat_data             : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      slv_wdat_strobe           : in  std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
      slv_wdat_last             : in  std_logic
    );
  end component;

  -----------------------------------------------------------------------------
  -- Component declarations for simulation-only helper units
  -----------------------------------------------------------------------------
  -- pragma translate_off

  component BusMasterMock is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      SEED                      : positive
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      req_valid                 : out std_logic;
      req_ready                 : in  std_logic;
      req_addr                  : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      req_len                   : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      resp_valid                : in  std_logic;
      resp_ready                : out std_logic;
      resp_data                 : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      resp_last                 : in  std_logic
    );
  end component;

  component BusSlaveMock is
    generic (
      BUS_ADDR_WIDTH            : natural := 32;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_DATA_WIDTH            : natural := 32;
      SEED                      : positive := 1;
      RANDOM_REQUEST_TIMING     : boolean := true;
      RANDOM_RESPONSE_TIMING    : boolean := true;
      SREC_FILE                 : string := ""
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      req_valid                 : in  std_logic;
      req_ready                 : out std_logic;
      req_addr                  : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      req_len                   : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      resp_valid                : out std_logic;
      resp_ready                : in  std_logic;
      resp_data                 : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      resp_last                 : out std_logic
    );
  end component;

  component BusWriteMasterMock is
    generic (
      BUS_ADDR_WIDTH              : natural;
      BUS_LEN_WIDTH               : natural;
      BUS_DATA_WIDTH              : natural;
      BUS_STROBE_WIDTH            : natural;
      SEED                        : positive

    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      wreq_valid                  : out std_logic;
      wreq_ready                  : in  std_logic;
      wreq_addr                   : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      wreq_len                    : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      wdat_valid                  : out std_logic;
      wdat_ready                  : in  std_logic;
      wdat_data                   : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      wdat_strobe                 : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
      wdat_last                   : out std_logic
    );
  end component;

  component BusWriteSlaveMock is
    generic (
      BUS_ADDR_WIDTH              : natural;
      BUS_LEN_WIDTH               : natural;
      BUS_DATA_WIDTH              : natural;
      BUS_STROBE_WIDTH            : natural;
      SEED                        : positive;
      RANDOM_REQUEST_TIMING       : boolean := false;
      RANDOM_RESPONSE_TIMING      : boolean := false;
      SREC_FILE                   : string  := ""
    );
    port (
      clk                         : in  std_logic;
      reset                       : in  std_logic;
      wreq_valid                  : in  std_logic;
      wreq_ready                  : out std_logic;
      wreq_addr                   : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      wreq_len                    : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      wdat_valid                  : in  std_logic;
      wdat_ready                  : out std_logic;
      wdat_data                   : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      wdat_strobe                 : in  std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
      wdat_last                   : in  std_logic
    );
  end component;

  component UserCoreMock is
    generic (
      NUM_REQUESTS              : natural;
      NUM_ELEMENTS              : natural;
      RANDOMIZE_OFFSET          : boolean;
      RANDOMIZE_NUM_ELEMENTS	  : boolean;
      RANDOMIZE_RESP_LATENCY    : boolean;
      MAX_LATENCY               : natural;
      DEFAULT_LATENCY           : natural;
      RESP_TIMEOUT              : natural;
      SEED                      : positive;
      IS_INDEX_BUFFER           : boolean;
      WAIT_FOR_PREV_LAST        : boolean;
      RESULT_LSHIFT             : natural;
      DATA_WIDTH                : natural;
      INDEX_WIDTH               : natural;
      ELEMENT_WIDTH             : natural;
      ELEMENT_COUNT_MAX         : natural;
      ELEMENT_COUNT_WIDTH       : natural
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      start                     : in  std_logic;
      done                      : out std_logic;

      req_resp_error            : out std_logic;
      incorrect                 : out std_logic;
      timeout                   : out std_logic;

      rows                      : in  std_logic_vector(INDEX_WIDTH-1 downto 0);

      cmd_valid                 : out std_logic;
      cmd_ready                 : in  std_logic;
      cmd_firstIdx              : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_lastIdx               : out std_logic_vector(INDEX_WIDTH-1 downto 0);

      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      in_last                   : in  std_logic
    );
  end component;

  -- pragma translate_on

end Arrow;

package body Arrow is
end Arrow;
