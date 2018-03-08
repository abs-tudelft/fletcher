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

package arrow_regexp_pkg is
  -----------------------------------------------------------------------------
  -- Bus interfaces
  -----------------------------------------------------------------------------
  constant BOTTOM_ADDR_WIDTH    : natural :=   64;
  constant BOTTOM_DATA_WIDTH    : natural :=   32;
  constant BOTTOM_ID_WIDTH      : natural :=    1;
  constant BOTTOM_BURST_STEP_LEN: natural :=   16;
  constant BOTTOM_BURST_MAX_LEN : natural :=  256;
  constant BOTTOM_LEN_WIDTH     : natural := log2ceil(BOTTOM_BURST_MAX_LEN) + 1;
  constant BOTTOM_ENABLE_FIFO   : boolean := true;

  constant MID_ADDR_WIDTH       : natural :=   64;
  constant MID_DATA_WIDTH       : natural :=  512;
  constant MID_WSTRB_WIDTH      : natural :=   64;
  constant MID_ID_WIDTH         : natural :=    1;

  constant TOP_ADDR_WIDTH       : natural :=   64;
  constant TOP_DATA_WIDTH       : natural :=  512;
  constant TOP_WSTRB_WIDTH      : natural :=   64;
  constant TOP_ID_WIDTH         : natural :=    8;

  -----------------------------------------------------------------------------
  -- Regular Expression Matching example top-level
  -----------------------------------------------------------------------------
  component arrow_regexp is
    generic (
      CORES                     : natural :=  16;
      BUS_ADDR_WIDTH            : natural :=  64;
      BUS_DATA_WIDTH            : natural := 512;
      SLV_BUS_ADDR_WIDTH        : natural :=  32;
      SLV_BUS_DATA_WIDTH        : natural :=  32
    );
    port (
      clk                       : in  std_logic;
      reset_n                   : in  std_logic;
      m_axi_araddr              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      m_axi_arlen               : out std_logic_vector(7 downto 0);
      m_axi_arvalid             : out std_logic;
      m_axi_arready             : in  std_logic;
      m_axi_arsize              : out std_logic_vector(2 downto 0);
      m_axi_rdata               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      m_axi_rresp               : in  std_logic_vector(1 downto 0);
      m_axi_rlast               : in  std_logic;
      m_axi_rvalid              : in  std_logic;
      m_axi_rready              : out std_logic;
      s_axi_awvalid             : in  std_logic;
      s_axi_awready             : out std_logic;
      s_axi_awaddr              : in  std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);
      s_axi_wvalid              : in  std_logic;
      s_axi_wready              : out std_logic;
      s_axi_wdata               : in  std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
      s_axi_wstrb               : in  std_logic_vector((SLV_BUS_DATA_WIDTH/8)-1 downto 0);
      s_axi_bvalid              : out std_logic;
      s_axi_bready              : in  std_logic;
      s_axi_bresp               : out std_logic_vector(1 downto 0);
      s_axi_arvalid             : in  std_logic;
      s_axi_arready             : out std_logic;
      s_axi_araddr              : in  std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);
      s_axi_rvalid              : out std_logic;
      s_axi_rready              : in  std_logic;
      s_axi_rdata               : out std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
      s_axi_rresp               : out std_logic_vector(1 downto 0)
    );
  end component;

  -----------------------------------------------------------------------------
  -- Internal buses
  -----------------------------------------------------------------------------

  -- Bottom (regex matchers to read converters)
  -- All signals have the same definition as in AXI4, except len which is axi_len + 1
  type bus_bottom_t is record
    req_id                      : std_logic_vector(BOTTOM_ID_WIDTH-1 downto 0);
    req_addr                    : std_logic_vector(BOTTOM_ADDR_WIDTH-1 downto 0);
    req_len                     : std_logic_vector(BOTTOM_LEN_WIDTH-1 downto 0);
    req_valid                   : std_logic;
    req_ready                   : std_logic;
    rsp_id                      : std_logic_vector(BOTTOM_ID_WIDTH-1 downto 0);
    rsp_data                    : std_logic_vector(BOTTOM_DATA_WIDTH-1 downto 0);
    rsp_resp                    : std_logic_vector( 1 downto 0);
    rsp_last                    : std_logic;
    rsp_valid                   : std_logic;
    rsp_ready                   : std_logic;
  end record;

  -- Mid (read converters to interconnect)
  type axi_mid_t is record
    areset_out_n                : std_logic;
    aclk                        : std_logic;
    awid                        : std_logic_vector(MID_ID_WIDTH-1 downto 0);
    awaddr                      : std_logic_vector(MID_ADDR_WIDTH-1 downto 0);
    awlen                       : std_logic_vector( 7 downto 0);
    awsize                      : std_logic_vector( 2 downto 0);
    awburst                     : std_logic_vector( 1 downto 0);
    awlock                      : std_logic;
    awcache                     : std_logic_vector( 3 downto 0);
    awprot                      : std_logic_vector( 2 downto 0);
    awqos                       : std_logic_vector( 3 downto 0);
    awvalid                     : std_logic;
    awready                     : std_logic;
    wdata                       : std_logic_vector(MID_DATA_WIDTH-1 downto 0);
    wstrb                       : std_logic_vector(MID_WSTRB_WIDTH-1 downto 0);
    wlast                       : std_logic;
    wvalid                      : std_logic;
    wready                      : std_logic;
    bid                         : std_logic_vector(MID_ID_WIDTH-1 downto 0);
    bresp                       : std_logic_vector( 1 downto 0);
    bvalid                      : std_logic;
    bready                      : std_logic;
    arid                        : std_logic_vector(MID_ID_WIDTH-1 downto 0);
    araddr                      : std_logic_vector(MID_ADDR_WIDTH-1 downto 0);
    arlen                       : std_logic_vector( 7 downto 0);
    arsize                      : std_logic_vector( 2 downto 0);
    arburst                     : std_logic_vector( 1 downto 0);
    arlock                      : std_logic;
    arcache                     : std_logic_vector( 3 downto 0);
    arprot                      : std_logic_vector( 2 downto 0);
    arqos                       : std_logic_vector( 3 downto 0);
    arvalid                     : std_logic;
    arready                     : std_logic;
    rid                         : std_logic_vector(MID_ID_WIDTH-1 downto 0);
    rdata                       : std_logic_vector(MID_DATA_WIDTH-1 downto 0);
    rresp                       : std_logic_vector( 1 downto 0);
    rlast                       : std_logic;
    rvalid                      : std_logic;
    rready                      : std_logic;
  end record;

  -- Top (to host interface)
  type axi_top_t is record
    areset_out_n                : std_logic;
    aclk                        : std_logic;
    awid                        : std_logic_vector(TOP_ID_WIDTH-1 downto 0);
    awaddr                      : std_logic_vector(TOP_ADDR_WIDTH-1 downto 0);
    awlen                       : std_logic_vector( 7 downto 0);
    awsize                      : std_logic_vector( 2 downto 0);
    awburst                     : std_logic_vector( 1 downto 0);
    awlock                      : std_logic;
    awcache                     : std_logic_vector( 3 downto 0);
    awprot                      : std_logic_vector( 2 downto 0);
    awqos                       : std_logic_vector( 3 downto 0);
    awvalid                     : std_logic;
    awready                     : std_logic;
    wdata                       : std_logic_vector(TOP_DATA_WIDTH-1 downto 0);
    wstrb                       : std_logic_vector(TOP_WSTRB_WIDTH-1 downto 0);
    wlast                       : std_logic;
    wvalid                      : std_logic;
    wready                      : std_logic;
    bid                         : std_logic_vector(TOP_ID_WIDTH-1 downto 0);
    bresp                       : std_logic_vector( 1 downto 0);
    bvalid                      : std_logic;
    bready                      : std_logic;
    arid                        : std_logic_vector(TOP_ID_WIDTH-1 downto 0);
    araddr                      : std_logic_vector(TOP_ADDR_WIDTH-1 downto 0);
    arlen                       : std_logic_vector( 7 downto 0);
    arsize                      : std_logic_vector( 2 downto 0);
    arburst                     : std_logic_vector( 1 downto 0);
    arlock                      : std_logic;
    arcache                     : std_logic_vector( 3 downto 0);
    arprot                      : std_logic_vector( 2 downto 0);
    arqos                       : std_logic_vector( 3 downto 0);
    arvalid                     : std_logic;
    arready                     : std_logic;
    rid                         : std_logic_vector(TOP_ID_WIDTH-1 downto 0);
    rdata                       : std_logic_vector(TOP_DATA_WIDTH-1 downto 0);
    rresp                       : std_logic_vector( 1 downto 0);
    rlast                       : std_logic;
    rvalid                      : std_logic;
    rready                      : std_logic;
  end record;

  -----------------------------------------------------------------------------
  -- Arrow regular expression matching unit
  -----------------------------------------------------------------------------
  component arrow_regexp_unit is
    generic (
      NUM_REGEX                 : natural := 16;
      BUS_ADDR_WIDTH            : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      REG_WIDTH                 : natural
    );
    port (
      clk                       : in  std_logic;
      reset_n                   : in  std_logic;
      control_reset             : in  std_logic;
      control_start             : in  std_logic;
      reset_start               : out std_logic;
      busy                      : out std_logic;
      done                      : out std_logic;
      firstidx                  : in  std_logic_vector(REG_WIDTH-1 downto 0);
      lastidx                   : in  std_logic_vector(REG_WIDTH-1 downto 0);
      off_hi                    : in  std_logic_vector(REG_WIDTH-1 downto 0);
      off_lo                    : in  std_logic_vector(REG_WIDTH-1 downto 0);
      utf8_hi                   : in  std_logic_vector(REG_WIDTH-1 downto 0);
      utf8_lo                   : in  std_logic_vector(REG_WIDTH-1 downto 0);
      matches                   : out std_logic_vector(NUM_REGEX*REG_WIDTH-1 downto 0);
      bus_req_addr              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      bus_req_len               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      bus_req_valid             : out std_logic;
      bus_req_ready             : in  std_logic;
      bus_rsp_data              : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      bus_rsp_resp              : in  std_logic_vector(1 downto 0);
      bus_rsp_last              : in  std_logic;
      bus_rsp_valid             : in  std_logic;
      bus_rsp_ready             : out std_logic
    );
  end component;

  -----------------------------------------------------------------------------
  -- AXI read address & data channel conversion
  -----------------------------------------------------------------------------
  component axi_read_converter is
    generic (
      ADDR_WIDTH                : natural;
      ID_WIDTH                  : natural;

      MASTER_DATA_WIDTH         : natural;
      MASTER_LEN_WIDTH          : natural := 8;

      SLAVE_DATA_WIDTH          : natural;
      SLAVE_LEN_WIDTH           : natural;
      SLAVE_MAX_BURST           : natural;

      ENABLE_FIFO               : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset_n                   : in  std_logic;
      s_bus_req_addr            : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      s_bus_req_len             : in  std_logic_vector(SLAVE_LEN_WIDTH-1 downto 0);
      s_bus_req_valid           : in  std_logic;
      s_bus_req_ready           : out std_logic;
      s_bus_rsp_data            : out std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
      s_bus_rsp_last            : out std_logic;
      s_bus_rsp_valid           : out std_logic;
      s_bus_rsp_ready           : in  std_logic;
      m_axi_araddr              : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      m_axi_arlen               : out std_logic_vector(7 downto 0);
      m_axi_arvalid             : out std_logic;
      m_axi_arready             : in  std_logic;
      m_axi_arsize              : out std_logic_vector(2 downto 0);
      m_axi_rdata               : in  std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
      m_axi_rlast               : in  std_logic;
      m_axi_rvalid              : in  std_logic;
      m_axi_rready              : out std_logic
    );
  end component;

  -----------------------------------------------------------------------------
  -- RegEx matchers
  -----------------------------------------------------------------------------
    component bird is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component bunny is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component cat is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component dog is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component ferret is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component fish is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component gerbil is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component hamster is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component horse is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component kitten is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component lizard is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component mouse is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component puppy is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component rabbit is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component rat is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

  component turtle is
    generic (
      BPC                       : positive := 4;
      BIG_ENDIAN                : boolean := false;
      INPUT_REG_ENABLE          : boolean := true;
      S12_REG_ENABLE            : boolean := true;
      S23_REG_ENABLE            : boolean := true;
      S34_REG_ENABLE            : boolean := true;
      S45_REG_ENABLE            : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic := '0';
      aresetn                   : in  std_logic := '1';
      clken                     : in  std_logic := '1';
      in_valid                  : in  std_logic := '1';
      in_ready                  : out std_logic;
      in_mask                   : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
      in_data                   : in  std_logic_vector(BPC*8-1 downto 0);
      in_last                   : in  std_logic := '0';
      in_xlast                  : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic := '1';
      out_match                 : out std_logic_vector(0 downto 0);
      out_error                 : out std_logic;
      out_xmask                 : out std_logic_vector(BPC-1 downto 0);
      out_xmatch                : out std_logic_vector(BPC*1-1 downto 0);
      out_xerror                : out std_logic_vector(BPC-1 downto 0)
    );
  end component;

end package;
