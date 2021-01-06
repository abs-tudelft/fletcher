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

package Buffer_pkg is
  -----------------------------------------------------------------------------
  -- BufferReader components
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
      IS_OFFSETS_BUFFER         : boolean := false;
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
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;

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

      bus_rreq_valid            : out std_logic;
      bus_rreq_ready            : in  std_logic;
      bus_rreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      bus_rreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

      bus_rdat_valid            : in  std_logic;
      bus_rdat_ready            : out std_logic;
      bus_rdat_data             : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bus_rdat_last             : in  std_logic;

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
      IS_OFFSETS_BUFFER         : boolean;
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
      IS_OFFSETS_BUFFER         : boolean;
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
      IS_OFFSETS_BUFFER         : boolean;
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
      IS_OFFSETS_BUFFER         : boolean;
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
      IS_OFFSETS_BUFFER         : boolean;
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
  -- BufferWriter components
  -----------------------------------------------------------------------------
  component BufferWriter is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_STROBE_WIDTH          : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      BUS_FIFO_DEPTH            : natural;
      BUS_FIFO_THRES_SHIFT      : natural := 0;
      INDEX_WIDTH               : natural;
      ELEMENT_WIDTH             : natural;
      IS_OFFSETS_BUFFER         : boolean;
      ELEMENT_COUNT_MAX         : natural;
      ELEMENT_COUNT_WIDTH       : natural;
      CMD_CTRL_WIDTH            : natural;
      CMD_TAG_WIDTH             : natural
    );
    port (
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
      cmdIn_valid               : in  std_logic;
      cmdIn_ready               : out std_logic;
      cmdIn_firstIdx            : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_lastIdx             : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdIn_baseAddr            : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      cmdIn_implicit            : in  std_logic := '0';
      cmdIn_tag                 : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      cmdIn_ctrl                : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0) := (others => '0');
      unlock_valid              : out std_logic;
      unlock_ready              : in  std_logic := '1';
      unlock_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      in_last                   : in  std_logic;
      cmdOut_valid              : out std_logic;
      cmdOut_ready              : in  std_logic := '1';
      cmdOut_firstIdx           : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdOut_lastIdx            : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdOut_ctrl               : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0) := (others => '0');
      cmdOut_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      bus_wreq_valid            : out std_logic;
      bus_wreq_ready            : in  std_logic;
      bus_wreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      bus_wreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      bus_wreq_last             : out std_logic;
      bus_wdat_valid            : out std_logic;
      bus_wdat_ready            : in  std_logic;
      bus_wdat_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bus_wdat_strobe           : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
      bus_wdat_last             : out std_logic;
      bus_wrep_valid            : in  std_logic;
      bus_wrep_ready            : out std_logic;
      bus_wrep_ok               : in  std_logic
    );
  end component;

  component BufferWriterPre is
    generic (
      INDEX_WIDTH               : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_STROBE_WIDTH          : natural;
      IS_OFFSETS_BUFFER         : boolean;
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
      cmdIn_ctrl                : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
      cmdIn_tag                 : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_dvalid                 : in  std_logic;
      in_data                   : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      in_last                   : in  std_logic;
      cmdOut_valid              : out std_logic;
      cmdOut_ready              : in  std_logic := '1';
      cmdOut_firstIdx           : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdOut_lastIdx            : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmdOut_ctrl               : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0) := (others => '0');
      cmdOut_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      out_strobe                : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
      out_last                  : out std_logic
    );
  end component;

  component BufferWriterPrePadder is
    generic (
      INDEX_WIDTH               : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_BURST_STEP_LEN        : natural;
      IS_OFFSETS_BUFFER         : boolean;
      ELEMENT_WIDTH             : natural;
      ELEMENT_COUNT_MAX         : natural := 1;
      ELEMENT_COUNT_WIDTH       : natural := 1;
      CMD_CTRL_WIDTH            : natural;
      CMD_TAG_WIDTH             : natural;
      OUT_SLICE                 : boolean := true
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
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      in_dvalid                 : in  std_logic;
      in_count                  : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      in_last                   : in  std_logic;
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
      out_count                 : out std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      out_strobe                : out std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);
      out_last                  : out std_logic;
      out_clear                 : out std_logic;
      out_implicit              : out std_logic;
      out_ctrl                  : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
      out_tag                   : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
      out_last_npad             : out std_logic
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
      IS_OFFSETS_BUFFER         : boolean;
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
      busReq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      busReq_last               : out std_logic
    );
  end component;

  component BufferWriterPreCmdGen is
    generic (
      OFFSET_WIDTH              : natural := 32;
      COUNT_MAX                 : natural := 1;
      COUNT_WIDTH               : natural := 1;
      CMD_CTRL_WIDTH            : natural := 1;
      CMD_TAG_WIDTH             : natural := 1;
      MODE                      : string := ""
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_offsets                : in  std_logic_vector(COUNT_MAX*OFFSET_WIDTH-1 downto 0);
      in_count                  : in  std_logic_vector(COUNT_WIDTH-1 downto 0);
      in_dvalid                 : in  std_logic;
      in_last                   : in  std_logic;
      in_ctrl                   : in  std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
      in_tag                    : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
      cmdOut_valid              : out std_logic;
      cmdOut_ready              : in  std_logic;
      cmdOut_firstIdx           : out std_logic_vector(OFFSET_WIDTH-1 downto 0);
      cmdOut_lastIdx            : out std_logic_vector(OFFSET_WIDTH-1 downto 0);
      cmdOut_implicit           : out std_logic;
      cmdOut_ctrl               : out std_logic_vector(CMD_CTRL_WIDTH-1 downto 0);
      cmdOut_tag                : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0)
    );
  end component;

end Buffer_pkg;
