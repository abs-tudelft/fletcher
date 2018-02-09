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

package arrow_regexp_pkg is
  -----------------------------------------------------------------------------
  -- AXI Interfaces
  -----------------------------------------------------------------------------
  constant BOTTOM_ADDR_WIDTH    : natural :=  64;
  constant BOTTOM_DATA_WIDTH    : natural :=  32;
  constant BOTTOM_WSTRB_WIDTH   : natural :=   4;
  constant BOTTOM_ID_WIDTH      : natural :=   1;

  constant MID_ADDR_WIDTH       : natural :=  64;
  constant MID_DATA_WIDTH       : natural := 512;
  constant MID_WSTRB_WIDTH      : natural :=  64;
  constant MID_ID_WIDTH         : natural :=   1;
  
  constant TOP_ADDR_WIDTH       : natural :=  64;
  constant TOP_DATA_WIDTH       : natural := 512;
  constant TOP_WSTRB_WIDTH      : natural :=  64;
  constant TOP_ID_WIDTH         : natural :=   8;
  
  -- Bottom (regex matchers to read converters)
  type axi_bottom_t is record
    areset_out_n                : std_logic;
    aclk                        : std_logic;
    awid                        : std_logic_vector(BOTTOM_ID_WIDTH-1 downto 0);
    awaddr                      : std_logic_vector(BOTTOM_ADDR_WIDTH-1 downto 0);
    awlen                       : std_logic_vector( 7 downto 0);
    awsize                      : std_logic_vector( 2 downto 0);
    awburst                     : std_logic_vector( 1 downto 0);
    awlock                      : std_logic;
    awcache                     : std_logic_vector( 3 downto 0);
    awprot                      : std_logic_vector( 2 downto 0);
    awqos                       : std_logic_vector( 3 downto 0);
    awvalid                     : std_logic;
    awready                     : std_logic;
    wdata                       : std_logic_vector(BOTTOM_DATA_WIDTH-1 downto 0);
    wstrb                       : std_logic_vector(BOTTOM_WSTRB_WIDTH-1 downto 0);
    wlast                       : std_logic;
    wvalid                      : std_logic;
    wready                      : std_logic;
    bid                         : std_logic_vector(BOTTOM_ID_WIDTH-1 downto 0);
    bresp                       : std_logic_vector( 1 downto 0);
    bvalid                      : std_logic;
    bready                      : std_logic;
    arid                        : std_logic_vector(BOTTOM_ID_WIDTH-1 downto 0);
    araddr                      : std_logic_vector(BOTTOM_ADDR_WIDTH-1 downto 0);
    arlen                       : std_logic_vector( 7 downto 0);
    arsize                      : std_logic_vector( 2 downto 0);
    arburst                     : std_logic_vector( 1 downto 0);
    arlock                      : std_logic;
    arcache                     : std_logic_vector( 3 downto 0);
    arprot                      : std_logic_vector( 2 downto 0);
    arqos                       : std_logic_vector( 3 downto 0);
    arvalid                     : std_logic;
    arready                     : std_logic;
    rid                         : std_logic_vector(BOTTOM_ID_WIDTH-1 downto 0);
    rdata                       : std_logic_vector(BOTTOM_DATA_WIDTH-1 downto 0);
    rresp                       : std_logic_vector( 1 downto 0);
    rlast                       : std_logic;
    rvalid                      : std_logic;
    rready                      : std_logic;
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
  
  -- Top (to AWS shell)
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
      NUM_REGEX                 : natural := 4;
      BUS_ADDR_WIDTH            : natural := 64;
      BUS_DATA_WIDTH            : natural := 32;
      BUS_ID_WIDTH              : natural := 1;
      BUS_LEN_WIDTH             : natural := 8;
      BUS_BURST_LENGTH          : natural := 4;
      BUS_WSTRB_WIDTH           : natural := 4;
      BUS_RESP_WIDTH            : natural := 2;
      REG_WIDTH                 : natural := 32
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

      m_axi_awid                : out std_logic_vector(0 downto 0);
      m_axi_awaddr              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      m_axi_awlen               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      m_axi_awsize              : out std_logic_vector(2 downto 0);
      m_axi_awvalid             : out std_logic;
      m_axi_wdata               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      m_axi_wstrb               : out std_logic_vector(BUS_WSTRB_WIDTH-1 downto 0);
      m_axi_wlast               : out std_logic;
      m_axi_wvalid              : out std_logic;
      m_axi_bready              : out std_logic;

      m_axi_araddr              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      m_axi_arid                : out std_logic_vector(0 downto 0);
      m_axi_arlen               : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      m_axi_arvalid             : out std_logic;
      m_axi_arready             : in  std_logic;
      m_axi_arsize              : out std_logic_vector(2 downto 0);
      m_axi_rdata               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      m_axi_rresp               : in  std_logic_vector(BUS_RESP_WIDTH-1 downto 0);
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
      INPUT_REG_ENABLE          : boolean := false;
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
  
  
  -----------------------------------------------------------------------------
  -- AXI read address & data channel conversion
  -----------------------------------------------------------------------------
  component axi_read_converter is
    generic (
      ADDR_WIDTH                  : natural;
      ID_WIDTH                    : natural;
      MASTER_DATA_WIDTH           : natural;
      SLAVE_DATA_WIDTH            : natural
    );
    port (
      clk                         :  in std_logic;
      reset_n                     :  in std_logic;
      s_axi_araddr                :  in std_logic_vector(ADDR_WIDTH-1 downto 0);
      s_axi_arid                  :  in std_logic_vector(ID_WIDTH-1 downto 0);
      s_axi_arlen                 :  in std_logic_vector(7 downto 0);
      s_axi_arvalid               :  in std_logic;
      s_axi_arready               : out std_logic;
      s_axi_arsize                :  in std_logic_vector(2 downto 0);
      s_axi_rid                   : out std_logic_vector(ID_WIDTH-1 downto 0);
      s_axi_rdata                 : out std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
      s_axi_rresp                 : out std_logic_vector(1 downto 0);
      s_axi_rlast                 : out std_logic;
      s_axi_rvalid                : out std_logic;
      s_axi_rready                :  in std_logic;
      m_axi_araddr                : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      m_axi_arid                  : out std_logic_vector(ID_WIDTH-1 downto 0);
      m_axi_arlen                 : out std_logic_vector(7 downto 0);
      m_axi_arvalid               : out std_logic;
      m_axi_arready               : in  std_logic;
      m_axi_arsize                : out std_logic_vector(2 downto 0);
      m_axi_rid                   : in  std_logic_vector(ID_WIDTH-1 downto 0);
      m_axi_rdata                 : in  std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
      m_axi_rresp                 : in  std_logic_vector(1 downto 0);
      m_axi_rlast                 : in  std_logic;
      m_axi_rvalid                : in  std_logic;
      m_axi_rready                : out std_logic
    );
  end component;
  
  -----------------------------------------------------------------------------
  -- AXI interconnect
  -----------------------------------------------------------------------------
  component axi_interconnect_utf8
    port (
      interconnect_aclk : in std_logic;
      interconnect_aresetn : in std_logic;
      s00_axi_areset_out_n : out std_logic;
      s00_axi_aclk : in std_logic;
      s00_axi_awid : in std_logic_vector(0 downto 0);
      s00_axi_awaddr : in std_logic_vector(63 downto 0);
      s00_axi_awlen : in std_logic_vector(7 downto 0);
      s00_axi_awsize : in std_logic_vector(2 downto 0);
      s00_axi_awburst : in std_logic_vector(1 downto 0);
      s00_axi_awlock : in std_logic;
      s00_axi_awcache : in std_logic_vector(3 downto 0);
      s00_axi_awprot : in std_logic_vector(2 downto 0);
      s00_axi_awqos : in std_logic_vector(3 downto 0);
      s00_axi_awvalid : in std_logic;
      s00_axi_awready : out std_logic;
      s00_axi_wdata : in std_logic_vector(511 downto 0);
      s00_axi_wstrb : in std_logic_vector(63 downto 0);
      s00_axi_wlast : in std_logic;
      s00_axi_wvalid : in std_logic;
      s00_axi_wready : out std_logic;
      s00_axi_bid : out std_logic_vector(0 downto 0);
      s00_axi_bresp : out std_logic_vector(1 downto 0);
      s00_axi_bvalid : out std_logic;
      s00_axi_bready : in std_logic;
      s00_axi_arid : in std_logic_vector(0 downto 0);
      s00_axi_araddr : in std_logic_vector(63 downto 0);
      s00_axi_arlen : in std_logic_vector(7 downto 0);
      s00_axi_arsize : in std_logic_vector(2 downto 0);
      s00_axi_arburst : in std_logic_vector(1 downto 0);
      s00_axi_arlock : in std_logic;
      s00_axi_arcache : in std_logic_vector(3 downto 0);
      s00_axi_arprot : in std_logic_vector(2 downto 0);
      s00_axi_arqos : in std_logic_vector(3 downto 0);
      s00_axi_arvalid : in std_logic;
      s00_axi_arready : out std_logic;
      s00_axi_rid : out std_logic_vector(0 downto 0);
      s00_axi_rdata : out std_logic_vector(511 downto 0);
      s00_axi_rresp : out std_logic_vector(1 downto 0);
      s00_axi_rlast : out std_logic;
      s00_axi_rvalid : out std_logic;
      s00_axi_rready : in std_logic;
      s01_axi_areset_out_n : out std_logic;
      s01_axi_aclk : in std_logic;
      s01_axi_awid : in std_logic_vector(0 downto 0);
      s01_axi_awaddr : in std_logic_vector(63 downto 0);
      s01_axi_awlen : in std_logic_vector(7 downto 0);
      s01_axi_awsize : in std_logic_vector(2 downto 0);
      s01_axi_awburst : in std_logic_vector(1 downto 0);
      s01_axi_awlock : in std_logic;
      s01_axi_awcache : in std_logic_vector(3 downto 0);
      s01_axi_awprot : in std_logic_vector(2 downto 0);
      s01_axi_awqos : in std_logic_vector(3 downto 0);
      s01_axi_awvalid : in std_logic;
      s01_axi_awready : out std_logic;
      s01_axi_wdata : in std_logic_vector(511 downto 0);
      s01_axi_wstrb : in std_logic_vector(63 downto 0);
      s01_axi_wlast : in std_logic;
      s01_axi_wvalid : in std_logic;
      s01_axi_wready : out std_logic;
      s01_axi_bid : out std_logic_vector(0 downto 0);
      s01_axi_bresp : out std_logic_vector(1 downto 0);
      s01_axi_bvalid : out std_logic;
      s01_axi_bready : in std_logic;
      s01_axi_arid : in std_logic_vector(0 downto 0);
      s01_axi_araddr : in std_logic_vector(63 downto 0);
      s01_axi_arlen : in std_logic_vector(7 downto 0);
      s01_axi_arsize : in std_logic_vector(2 downto 0);
      s01_axi_arburst : in std_logic_vector(1 downto 0);
      s01_axi_arlock : in std_logic;
      s01_axi_arcache : in std_logic_vector(3 downto 0);
      s01_axi_arprot : in std_logic_vector(2 downto 0);
      s01_axi_arqos : in std_logic_vector(3 downto 0);
      s01_axi_arvalid : in std_logic;
      s01_axi_arready : out std_logic;
      s01_axi_rid : out std_logic_vector(0 downto 0);
      s01_axi_rdata : out std_logic_vector(511 downto 0);
      s01_axi_rresp : out std_logic_vector(1 downto 0);
      s01_axi_rlast : out std_logic;
      s01_axi_rvalid : out std_logic;
      s01_axi_rready : in std_logic;
      s02_axi_areset_out_n : out std_logic;
      s02_axi_aclk : in std_logic;
      s02_axi_awid : in std_logic_vector(0 downto 0);
      s02_axi_awaddr : in std_logic_vector(63 downto 0);
      s02_axi_awlen : in std_logic_vector(7 downto 0);
      s02_axi_awsize : in std_logic_vector(2 downto 0);
      s02_axi_awburst : in std_logic_vector(1 downto 0);
      s02_axi_awlock : in std_logic;
      s02_axi_awcache : in std_logic_vector(3 downto 0);
      s02_axi_awprot : in std_logic_vector(2 downto 0);
      s02_axi_awqos : in std_logic_vector(3 downto 0);
      s02_axi_awvalid : in std_logic;
      s02_axi_awready : out std_logic;
      s02_axi_wdata : in std_logic_vector(511 downto 0);
      s02_axi_wstrb : in std_logic_vector(63 downto 0);
      s02_axi_wlast : in std_logic;
      s02_axi_wvalid : in std_logic;
      s02_axi_wready : out std_logic;
      s02_axi_bid : out std_logic_vector(0 downto 0);
      s02_axi_bresp : out std_logic_vector(1 downto 0);
      s02_axi_bvalid : out std_logic;
      s02_axi_bready : in std_logic;
      s02_axi_arid : in std_logic_vector(0 downto 0);
      s02_axi_araddr : in std_logic_vector(63 downto 0);
      s02_axi_arlen : in std_logic_vector(7 downto 0);
      s02_axi_arsize : in std_logic_vector(2 downto 0);
      s02_axi_arburst : in std_logic_vector(1 downto 0);
      s02_axi_arlock : in std_logic;
      s02_axi_arcache : in std_logic_vector(3 downto 0);
      s02_axi_arprot : in std_logic_vector(2 downto 0);
      s02_axi_arqos : in std_logic_vector(3 downto 0);
      s02_axi_arvalid : in std_logic;
      s02_axi_arready : out std_logic;
      s02_axi_rid : out std_logic_vector(0 downto 0);
      s02_axi_rdata : out std_logic_vector(511 downto 0);
      s02_axi_rresp : out std_logic_vector(1 downto 0);
      s02_axi_rlast : out std_logic;
      s02_axi_rvalid : out std_logic;
      s02_axi_rready : in std_logic;
      s03_axi_areset_out_n : out std_logic;
      s03_axi_aclk : in std_logic;
      s03_axi_awid : in std_logic_vector(0 downto 0);
      s03_axi_awaddr : in std_logic_vector(63 downto 0);
      s03_axi_awlen : in std_logic_vector(7 downto 0);
      s03_axi_awsize : in std_logic_vector(2 downto 0);
      s03_axi_awburst : in std_logic_vector(1 downto 0);
      s03_axi_awlock : in std_logic;
      s03_axi_awcache : in std_logic_vector(3 downto 0);
      s03_axi_awprot : in std_logic_vector(2 downto 0);
      s03_axi_awqos : in std_logic_vector(3 downto 0);
      s03_axi_awvalid : in std_logic;
      s03_axi_awready : out std_logic;
      s03_axi_wdata : in std_logic_vector(511 downto 0);
      s03_axi_wstrb : in std_logic_vector(63 downto 0);
      s03_axi_wlast : in std_logic;
      s03_axi_wvalid : in std_logic;
      s03_axi_wready : out std_logic;
      s03_axi_bid : out std_logic_vector(0 downto 0);
      s03_axi_bresp : out std_logic_vector(1 downto 0);
      s03_axi_bvalid : out std_logic;
      s03_axi_bready : in std_logic;
      s03_axi_arid : in std_logic_vector(0 downto 0);
      s03_axi_araddr : in std_logic_vector(63 downto 0);
      s03_axi_arlen : in std_logic_vector(7 downto 0);
      s03_axi_arsize : in std_logic_vector(2 downto 0);
      s03_axi_arburst : in std_logic_vector(1 downto 0);
      s03_axi_arlock : in std_logic;
      s03_axi_arcache : in std_logic_vector(3 downto 0);
      s03_axi_arprot : in std_logic_vector(2 downto 0);
      s03_axi_arqos : in std_logic_vector(3 downto 0);
      s03_axi_arvalid : in std_logic;
      s03_axi_arready : out std_logic;
      s03_axi_rid : out std_logic_vector(0 downto 0);
      s03_axi_rdata : out std_logic_vector(511 downto 0);
      s03_axi_rresp : out std_logic_vector(1 downto 0);
      s03_axi_rlast : out std_logic;
      s03_axi_rvalid : out std_logic;
      s03_axi_rready : in std_logic;
      s04_axi_areset_out_n : out std_logic;
      s04_axi_aclk : in std_logic;
      s04_axi_awid : in std_logic_vector(0 downto 0);
      s04_axi_awaddr : in std_logic_vector(63 downto 0);
      s04_axi_awlen : in std_logic_vector(7 downto 0);
      s04_axi_awsize : in std_logic_vector(2 downto 0);
      s04_axi_awburst : in std_logic_vector(1 downto 0);
      s04_axi_awlock : in std_logic;
      s04_axi_awcache : in std_logic_vector(3 downto 0);
      s04_axi_awprot : in std_logic_vector(2 downto 0);
      s04_axi_awqos : in std_logic_vector(3 downto 0);
      s04_axi_awvalid : in std_logic;
      s04_axi_awready : out std_logic;
      s04_axi_wdata : in std_logic_vector(511 downto 0);
      s04_axi_wstrb : in std_logic_vector(63 downto 0);
      s04_axi_wlast : in std_logic;
      s04_axi_wvalid : in std_logic;
      s04_axi_wready : out std_logic;
      s04_axi_bid : out std_logic_vector(0 downto 0);
      s04_axi_bresp : out std_logic_vector(1 downto 0);
      s04_axi_bvalid : out std_logic;
      s04_axi_bready : in std_logic;
      s04_axi_arid : in std_logic_vector(0 downto 0);
      s04_axi_araddr : in std_logic_vector(63 downto 0);
      s04_axi_arlen : in std_logic_vector(7 downto 0);
      s04_axi_arsize : in std_logic_vector(2 downto 0);
      s04_axi_arburst : in std_logic_vector(1 downto 0);
      s04_axi_arlock : in std_logic;
      s04_axi_arcache : in std_logic_vector(3 downto 0);
      s04_axi_arprot : in std_logic_vector(2 downto 0);
      s04_axi_arqos : in std_logic_vector(3 downto 0);
      s04_axi_arvalid : in std_logic;
      s04_axi_arready : out std_logic;
      s04_axi_rid : out std_logic_vector(0 downto 0);
      s04_axi_rdata : out std_logic_vector(511 downto 0);
      s04_axi_rresp : out std_logic_vector(1 downto 0);
      s04_axi_rlast : out std_logic;
      s04_axi_rvalid : out std_logic;
      s04_axi_rready : in std_logic;
      s05_axi_areset_out_n : out std_logic;
      s05_axi_aclk : in std_logic;
      s05_axi_awid : in std_logic_vector(0 downto 0);
      s05_axi_awaddr : in std_logic_vector(63 downto 0);
      s05_axi_awlen : in std_logic_vector(7 downto 0);
      s05_axi_awsize : in std_logic_vector(2 downto 0);
      s05_axi_awburst : in std_logic_vector(1 downto 0);
      s05_axi_awlock : in std_logic;
      s05_axi_awcache : in std_logic_vector(3 downto 0);
      s05_axi_awprot : in std_logic_vector(2 downto 0);
      s05_axi_awqos : in std_logic_vector(3 downto 0);
      s05_axi_awvalid : in std_logic;
      s05_axi_awready : out std_logic;
      s05_axi_wdata : in std_logic_vector(511 downto 0);
      s05_axi_wstrb : in std_logic_vector(63 downto 0);
      s05_axi_wlast : in std_logic;
      s05_axi_wvalid : in std_logic;
      s05_axi_wready : out std_logic;
      s05_axi_bid : out std_logic_vector(0 downto 0);
      s05_axi_bresp : out std_logic_vector(1 downto 0);
      s05_axi_bvalid : out std_logic;
      s05_axi_bready : in std_logic;
      s05_axi_arid : in std_logic_vector(0 downto 0);
      s05_axi_araddr : in std_logic_vector(63 downto 0);
      s05_axi_arlen : in std_logic_vector(7 downto 0);
      s05_axi_arsize : in std_logic_vector(2 downto 0);
      s05_axi_arburst : in std_logic_vector(1 downto 0);
      s05_axi_arlock : in std_logic;
      s05_axi_arcache : in std_logic_vector(3 downto 0);
      s05_axi_arprot : in std_logic_vector(2 downto 0);
      s05_axi_arqos : in std_logic_vector(3 downto 0);
      s05_axi_arvalid : in std_logic;
      s05_axi_arready : out std_logic;
      s05_axi_rid : out std_logic_vector(0 downto 0);
      s05_axi_rdata : out std_logic_vector(511 downto 0);
      s05_axi_rresp : out std_logic_vector(1 downto 0);
      s05_axi_rlast : out std_logic;
      s05_axi_rvalid : out std_logic;
      s05_axi_rready : in std_logic;
      s06_axi_areset_out_n : out std_logic;
      s06_axi_aclk : in std_logic;
      s06_axi_awid : in std_logic_vector(0 downto 0);
      s06_axi_awaddr : in std_logic_vector(63 downto 0);
      s06_axi_awlen : in std_logic_vector(7 downto 0);
      s06_axi_awsize : in std_logic_vector(2 downto 0);
      s06_axi_awburst : in std_logic_vector(1 downto 0);
      s06_axi_awlock : in std_logic;
      s06_axi_awcache : in std_logic_vector(3 downto 0);
      s06_axi_awprot : in std_logic_vector(2 downto 0);
      s06_axi_awqos : in std_logic_vector(3 downto 0);
      s06_axi_awvalid : in std_logic;
      s06_axi_awready : out std_logic;
      s06_axi_wdata : in std_logic_vector(511 downto 0);
      s06_axi_wstrb : in std_logic_vector(63 downto 0);
      s06_axi_wlast : in std_logic;
      s06_axi_wvalid : in std_logic;
      s06_axi_wready : out std_logic;
      s06_axi_bid : out std_logic_vector(0 downto 0);
      s06_axi_bresp : out std_logic_vector(1 downto 0);
      s06_axi_bvalid : out std_logic;
      s06_axi_bready : in std_logic;
      s06_axi_arid : in std_logic_vector(0 downto 0);
      s06_axi_araddr : in std_logic_vector(63 downto 0);
      s06_axi_arlen : in std_logic_vector(7 downto 0);
      s06_axi_arsize : in std_logic_vector(2 downto 0);
      s06_axi_arburst : in std_logic_vector(1 downto 0);
      s06_axi_arlock : in std_logic;
      s06_axi_arcache : in std_logic_vector(3 downto 0);
      s06_axi_arprot : in std_logic_vector(2 downto 0);
      s06_axi_arqos : in std_logic_vector(3 downto 0);
      s06_axi_arvalid : in std_logic;
      s06_axi_arready : out std_logic;
      s06_axi_rid : out std_logic_vector(0 downto 0);
      s06_axi_rdata : out std_logic_vector(511 downto 0);
      s06_axi_rresp : out std_logic_vector(1 downto 0);
      s06_axi_rlast : out std_logic;
      s06_axi_rvalid : out std_logic;
      s06_axi_rready : in std_logic;
      s07_axi_areset_out_n : out std_logic;
      s07_axi_aclk : in std_logic;
      s07_axi_awid : in std_logic_vector(0 downto 0);
      s07_axi_awaddr : in std_logic_vector(63 downto 0);
      s07_axi_awlen : in std_logic_vector(7 downto 0);
      s07_axi_awsize : in std_logic_vector(2 downto 0);
      s07_axi_awburst : in std_logic_vector(1 downto 0);
      s07_axi_awlock : in std_logic;
      s07_axi_awcache : in std_logic_vector(3 downto 0);
      s07_axi_awprot : in std_logic_vector(2 downto 0);
      s07_axi_awqos : in std_logic_vector(3 downto 0);
      s07_axi_awvalid : in std_logic;
      s07_axi_awready : out std_logic;
      s07_axi_wdata : in std_logic_vector(511 downto 0);
      s07_axi_wstrb : in std_logic_vector(63 downto 0);
      s07_axi_wlast : in std_logic;
      s07_axi_wvalid : in std_logic;
      s07_axi_wready : out std_logic;
      s07_axi_bid : out std_logic_vector(0 downto 0);
      s07_axi_bresp : out std_logic_vector(1 downto 0);
      s07_axi_bvalid : out std_logic;
      s07_axi_bready : in std_logic;
      s07_axi_arid : in std_logic_vector(0 downto 0);
      s07_axi_araddr : in std_logic_vector(63 downto 0);
      s07_axi_arlen : in std_logic_vector(7 downto 0);
      s07_axi_arsize : in std_logic_vector(2 downto 0);
      s07_axi_arburst : in std_logic_vector(1 downto 0);
      s07_axi_arlock : in std_logic;
      s07_axi_arcache : in std_logic_vector(3 downto 0);
      s07_axi_arprot : in std_logic_vector(2 downto 0);
      s07_axi_arqos : in std_logic_vector(3 downto 0);
      s07_axi_arvalid : in std_logic;
      s07_axi_arready : out std_logic;
      s07_axi_rid : out std_logic_vector(0 downto 0);
      s07_axi_rdata : out std_logic_vector(511 downto 0);
      s07_axi_rresp : out std_logic_vector(1 downto 0);
      s07_axi_rlast : out std_logic;
      s07_axi_rvalid : out std_logic;
      s07_axi_rready : in std_logic;
      s08_axi_areset_out_n : out std_logic;
      s08_axi_aclk : in std_logic;
      s08_axi_awid : in std_logic_vector(0 downto 0);
      s08_axi_awaddr : in std_logic_vector(63 downto 0);
      s08_axi_awlen : in std_logic_vector(7 downto 0);
      s08_axi_awsize : in std_logic_vector(2 downto 0);
      s08_axi_awburst : in std_logic_vector(1 downto 0);
      s08_axi_awlock : in std_logic;
      s08_axi_awcache : in std_logic_vector(3 downto 0);
      s08_axi_awprot : in std_logic_vector(2 downto 0);
      s08_axi_awqos : in std_logic_vector(3 downto 0);
      s08_axi_awvalid : in std_logic;
      s08_axi_awready : out std_logic;
      s08_axi_wdata : in std_logic_vector(511 downto 0);
      s08_axi_wstrb : in std_logic_vector(63 downto 0);
      s08_axi_wlast : in std_logic;
      s08_axi_wvalid : in std_logic;
      s08_axi_wready : out std_logic;
      s08_axi_bid : out std_logic_vector(0 downto 0);
      s08_axi_bresp : out std_logic_vector(1 downto 0);
      s08_axi_bvalid : out std_logic;
      s08_axi_bready : in std_logic;
      s08_axi_arid : in std_logic_vector(0 downto 0);
      s08_axi_araddr : in std_logic_vector(63 downto 0);
      s08_axi_arlen : in std_logic_vector(7 downto 0);
      s08_axi_arsize : in std_logic_vector(2 downto 0);
      s08_axi_arburst : in std_logic_vector(1 downto 0);
      s08_axi_arlock : in std_logic;
      s08_axi_arcache : in std_logic_vector(3 downto 0);
      s08_axi_arprot : in std_logic_vector(2 downto 0);
      s08_axi_arqos : in std_logic_vector(3 downto 0);
      s08_axi_arvalid : in std_logic;
      s08_axi_arready : out std_logic;
      s08_axi_rid : out std_logic_vector(0 downto 0);
      s08_axi_rdata : out std_logic_vector(511 downto 0);
      s08_axi_rresp : out std_logic_vector(1 downto 0);
      s08_axi_rlast : out std_logic;
      s08_axi_rvalid : out std_logic;
      s08_axi_rready : in std_logic;
      s09_axi_areset_out_n : out std_logic;
      s09_axi_aclk : in std_logic;
      s09_axi_awid : in std_logic_vector(0 downto 0);
      s09_axi_awaddr : in std_logic_vector(63 downto 0);
      s09_axi_awlen : in std_logic_vector(7 downto 0);
      s09_axi_awsize : in std_logic_vector(2 downto 0);
      s09_axi_awburst : in std_logic_vector(1 downto 0);
      s09_axi_awlock : in std_logic;
      s09_axi_awcache : in std_logic_vector(3 downto 0);
      s09_axi_awprot : in std_logic_vector(2 downto 0);
      s09_axi_awqos : in std_logic_vector(3 downto 0);
      s09_axi_awvalid : in std_logic;
      s09_axi_awready : out std_logic;
      s09_axi_wdata : in std_logic_vector(511 downto 0);
      s09_axi_wstrb : in std_logic_vector(63 downto 0);
      s09_axi_wlast : in std_logic;
      s09_axi_wvalid : in std_logic;
      s09_axi_wready : out std_logic;
      s09_axi_bid : out std_logic_vector(0 downto 0);
      s09_axi_bresp : out std_logic_vector(1 downto 0);
      s09_axi_bvalid : out std_logic;
      s09_axi_bready : in std_logic;
      s09_axi_arid : in std_logic_vector(0 downto 0);
      s09_axi_araddr : in std_logic_vector(63 downto 0);
      s09_axi_arlen : in std_logic_vector(7 downto 0);
      s09_axi_arsize : in std_logic_vector(2 downto 0);
      s09_axi_arburst : in std_logic_vector(1 downto 0);
      s09_axi_arlock : in std_logic;
      s09_axi_arcache : in std_logic_vector(3 downto 0);
      s09_axi_arprot : in std_logic_vector(2 downto 0);
      s09_axi_arqos : in std_logic_vector(3 downto 0);
      s09_axi_arvalid : in std_logic;
      s09_axi_arready : out std_logic;
      s09_axi_rid : out std_logic_vector(0 downto 0);
      s09_axi_rdata : out std_logic_vector(511 downto 0);
      s09_axi_rresp : out std_logic_vector(1 downto 0);
      s09_axi_rlast : out std_logic;
      s09_axi_rvalid : out std_logic;
      s09_axi_rready : in std_logic;
      s10_axi_areset_out_n : out std_logic;
      s10_axi_aclk : in std_logic;
      s10_axi_awid : in std_logic_vector(0 downto 0);
      s10_axi_awaddr : in std_logic_vector(63 downto 0);
      s10_axi_awlen : in std_logic_vector(7 downto 0);
      s10_axi_awsize : in std_logic_vector(2 downto 0);
      s10_axi_awburst : in std_logic_vector(1 downto 0);
      s10_axi_awlock : in std_logic;
      s10_axi_awcache : in std_logic_vector(3 downto 0);
      s10_axi_awprot : in std_logic_vector(2 downto 0);
      s10_axi_awqos : in std_logic_vector(3 downto 0);
      s10_axi_awvalid : in std_logic;
      s10_axi_awready : out std_logic;
      s10_axi_wdata : in std_logic_vector(511 downto 0);
      s10_axi_wstrb : in std_logic_vector(63 downto 0);
      s10_axi_wlast : in std_logic;
      s10_axi_wvalid : in std_logic;
      s10_axi_wready : out std_logic;
      s10_axi_bid : out std_logic_vector(0 downto 0);
      s10_axi_bresp : out std_logic_vector(1 downto 0);
      s10_axi_bvalid : out std_logic;
      s10_axi_bready : in std_logic;
      s10_axi_arid : in std_logic_vector(0 downto 0);
      s10_axi_araddr : in std_logic_vector(63 downto 0);
      s10_axi_arlen : in std_logic_vector(7 downto 0);
      s10_axi_arsize : in std_logic_vector(2 downto 0);
      s10_axi_arburst : in std_logic_vector(1 downto 0);
      s10_axi_arlock : in std_logic;
      s10_axi_arcache : in std_logic_vector(3 downto 0);
      s10_axi_arprot : in std_logic_vector(2 downto 0);
      s10_axi_arqos : in std_logic_vector(3 downto 0);
      s10_axi_arvalid : in std_logic;
      s10_axi_arready : out std_logic;
      s10_axi_rid : out std_logic_vector(0 downto 0);
      s10_axi_rdata : out std_logic_vector(511 downto 0);
      s10_axi_rresp : out std_logic_vector(1 downto 0);
      s10_axi_rlast : out std_logic;
      s10_axi_rvalid : out std_logic;
      s10_axi_rready : in std_logic;
      s11_axi_areset_out_n : out std_logic;
      s11_axi_aclk : in std_logic;
      s11_axi_awid : in std_logic_vector(0 downto 0);
      s11_axi_awaddr : in std_logic_vector(63 downto 0);
      s11_axi_awlen : in std_logic_vector(7 downto 0);
      s11_axi_awsize : in std_logic_vector(2 downto 0);
      s11_axi_awburst : in std_logic_vector(1 downto 0);
      s11_axi_awlock : in std_logic;
      s11_axi_awcache : in std_logic_vector(3 downto 0);
      s11_axi_awprot : in std_logic_vector(2 downto 0);
      s11_axi_awqos : in std_logic_vector(3 downto 0);
      s11_axi_awvalid : in std_logic;
      s11_axi_awready : out std_logic;
      s11_axi_wdata : in std_logic_vector(511 downto 0);
      s11_axi_wstrb : in std_logic_vector(63 downto 0);
      s11_axi_wlast : in std_logic;
      s11_axi_wvalid : in std_logic;
      s11_axi_wready : out std_logic;
      s11_axi_bid : out std_logic_vector(0 downto 0);
      s11_axi_bresp : out std_logic_vector(1 downto 0);
      s11_axi_bvalid : out std_logic;
      s11_axi_bready : in std_logic;
      s11_axi_arid : in std_logic_vector(0 downto 0);
      s11_axi_araddr : in std_logic_vector(63 downto 0);
      s11_axi_arlen : in std_logic_vector(7 downto 0);
      s11_axi_arsize : in std_logic_vector(2 downto 0);
      s11_axi_arburst : in std_logic_vector(1 downto 0);
      s11_axi_arlock : in std_logic;
      s11_axi_arcache : in std_logic_vector(3 downto 0);
      s11_axi_arprot : in std_logic_vector(2 downto 0);
      s11_axi_arqos : in std_logic_vector(3 downto 0);
      s11_axi_arvalid : in std_logic;
      s11_axi_arready : out std_logic;
      s11_axi_rid : out std_logic_vector(0 downto 0);
      s11_axi_rdata : out std_logic_vector(511 downto 0);
      s11_axi_rresp : out std_logic_vector(1 downto 0);
      s11_axi_rlast : out std_logic;
      s11_axi_rvalid : out std_logic;
      s11_axi_rready : in std_logic;
      s12_axi_areset_out_n : out std_logic;
      s12_axi_aclk : in std_logic;
      s12_axi_awid : in std_logic_vector(0 downto 0);
      s12_axi_awaddr : in std_logic_vector(63 downto 0);
      s12_axi_awlen : in std_logic_vector(7 downto 0);
      s12_axi_awsize : in std_logic_vector(2 downto 0);
      s12_axi_awburst : in std_logic_vector(1 downto 0);
      s12_axi_awlock : in std_logic;
      s12_axi_awcache : in std_logic_vector(3 downto 0);
      s12_axi_awprot : in std_logic_vector(2 downto 0);
      s12_axi_awqos : in std_logic_vector(3 downto 0);
      s12_axi_awvalid : in std_logic;
      s12_axi_awready : out std_logic;
      s12_axi_wdata : in std_logic_vector(511 downto 0);
      s12_axi_wstrb : in std_logic_vector(63 downto 0);
      s12_axi_wlast : in std_logic;
      s12_axi_wvalid : in std_logic;
      s12_axi_wready : out std_logic;
      s12_axi_bid : out std_logic_vector(0 downto 0);
      s12_axi_bresp : out std_logic_vector(1 downto 0);
      s12_axi_bvalid : out std_logic;
      s12_axi_bready : in std_logic;
      s12_axi_arid : in std_logic_vector(0 downto 0);
      s12_axi_araddr : in std_logic_vector(63 downto 0);
      s12_axi_arlen : in std_logic_vector(7 downto 0);
      s12_axi_arsize : in std_logic_vector(2 downto 0);
      s12_axi_arburst : in std_logic_vector(1 downto 0);
      s12_axi_arlock : in std_logic;
      s12_axi_arcache : in std_logic_vector(3 downto 0);
      s12_axi_arprot : in std_logic_vector(2 downto 0);
      s12_axi_arqos : in std_logic_vector(3 downto 0);
      s12_axi_arvalid : in std_logic;
      s12_axi_arready : out std_logic;
      s12_axi_rid : out std_logic_vector(0 downto 0);
      s12_axi_rdata : out std_logic_vector(511 downto 0);
      s12_axi_rresp : out std_logic_vector(1 downto 0);
      s12_axi_rlast : out std_logic;
      s12_axi_rvalid : out std_logic;
      s12_axi_rready : in std_logic;
      s13_axi_areset_out_n : out std_logic;
      s13_axi_aclk : in std_logic;
      s13_axi_awid : in std_logic_vector(0 downto 0);
      s13_axi_awaddr : in std_logic_vector(63 downto 0);
      s13_axi_awlen : in std_logic_vector(7 downto 0);
      s13_axi_awsize : in std_logic_vector(2 downto 0);
      s13_axi_awburst : in std_logic_vector(1 downto 0);
      s13_axi_awlock : in std_logic;
      s13_axi_awcache : in std_logic_vector(3 downto 0);
      s13_axi_awprot : in std_logic_vector(2 downto 0);
      s13_axi_awqos : in std_logic_vector(3 downto 0);
      s13_axi_awvalid : in std_logic;
      s13_axi_awready : out std_logic;
      s13_axi_wdata : in std_logic_vector(511 downto 0);
      s13_axi_wstrb : in std_logic_vector(63 downto 0);
      s13_axi_wlast : in std_logic;
      s13_axi_wvalid : in std_logic;
      s13_axi_wready : out std_logic;
      s13_axi_bid : out std_logic_vector(0 downto 0);
      s13_axi_bresp : out std_logic_vector(1 downto 0);
      s13_axi_bvalid : out std_logic;
      s13_axi_bready : in std_logic;
      s13_axi_arid : in std_logic_vector(0 downto 0);
      s13_axi_araddr : in std_logic_vector(63 downto 0);
      s13_axi_arlen : in std_logic_vector(7 downto 0);
      s13_axi_arsize : in std_logic_vector(2 downto 0);
      s13_axi_arburst : in std_logic_vector(1 downto 0);
      s13_axi_arlock : in std_logic;
      s13_axi_arcache : in std_logic_vector(3 downto 0);
      s13_axi_arprot : in std_logic_vector(2 downto 0);
      s13_axi_arqos : in std_logic_vector(3 downto 0);
      s13_axi_arvalid : in std_logic;
      s13_axi_arready : out std_logic;
      s13_axi_rid : out std_logic_vector(0 downto 0);
      s13_axi_rdata : out std_logic_vector(511 downto 0);
      s13_axi_rresp : out std_logic_vector(1 downto 0);
      s13_axi_rlast : out std_logic;
      s13_axi_rvalid : out std_logic;
      s13_axi_rready : in std_logic;
      s14_axi_areset_out_n : out std_logic;
      s14_axi_aclk : in std_logic;
      s14_axi_awid : in std_logic_vector(0 downto 0);
      s14_axi_awaddr : in std_logic_vector(63 downto 0);
      s14_axi_awlen : in std_logic_vector(7 downto 0);
      s14_axi_awsize : in std_logic_vector(2 downto 0);
      s14_axi_awburst : in std_logic_vector(1 downto 0);
      s14_axi_awlock : in std_logic;
      s14_axi_awcache : in std_logic_vector(3 downto 0);
      s14_axi_awprot : in std_logic_vector(2 downto 0);
      s14_axi_awqos : in std_logic_vector(3 downto 0);
      s14_axi_awvalid : in std_logic;
      s14_axi_awready : out std_logic;
      s14_axi_wdata : in std_logic_vector(511 downto 0);
      s14_axi_wstrb : in std_logic_vector(63 downto 0);
      s14_axi_wlast : in std_logic;
      s14_axi_wvalid : in std_logic;
      s14_axi_wready : out std_logic;
      s14_axi_bid : out std_logic_vector(0 downto 0);
      s14_axi_bresp : out std_logic_vector(1 downto 0);
      s14_axi_bvalid : out std_logic;
      s14_axi_bready : in std_logic;
      s14_axi_arid : in std_logic_vector(0 downto 0);
      s14_axi_araddr : in std_logic_vector(63 downto 0);
      s14_axi_arlen : in std_logic_vector(7 downto 0);
      s14_axi_arsize : in std_logic_vector(2 downto 0);
      s14_axi_arburst : in std_logic_vector(1 downto 0);
      s14_axi_arlock : in std_logic;
      s14_axi_arcache : in std_logic_vector(3 downto 0);
      s14_axi_arprot : in std_logic_vector(2 downto 0);
      s14_axi_arqos : in std_logic_vector(3 downto 0);
      s14_axi_arvalid : in std_logic;
      s14_axi_arready : out std_logic;
      s14_axi_rid : out std_logic_vector(0 downto 0);
      s14_axi_rdata : out std_logic_vector(511 downto 0);
      s14_axi_rresp : out std_logic_vector(1 downto 0);
      s14_axi_rlast : out std_logic;
      s14_axi_rvalid : out std_logic;
      s14_axi_rready : in std_logic;
      s15_axi_areset_out_n : out std_logic;
      s15_axi_aclk : in std_logic;
      s15_axi_awid : in std_logic_vector(0 downto 0);
      s15_axi_awaddr : in std_logic_vector(63 downto 0);
      s15_axi_awlen : in std_logic_vector(7 downto 0);
      s15_axi_awsize : in std_logic_vector(2 downto 0);
      s15_axi_awburst : in std_logic_vector(1 downto 0);
      s15_axi_awlock : in std_logic;
      s15_axi_awcache : in std_logic_vector(3 downto 0);
      s15_axi_awprot : in std_logic_vector(2 downto 0);
      s15_axi_awqos : in std_logic_vector(3 downto 0);
      s15_axi_awvalid : in std_logic;
      s15_axi_awready : out std_logic;
      s15_axi_wdata : in std_logic_vector(511 downto 0);
      s15_axi_wstrb : in std_logic_vector(63 downto 0);
      s15_axi_wlast : in std_logic;
      s15_axi_wvalid : in std_logic;
      s15_axi_wready : out std_logic;
      s15_axi_bid : out std_logic_vector(0 downto 0);
      s15_axi_bresp : out std_logic_vector(1 downto 0);
      s15_axi_bvalid : out std_logic;
      s15_axi_bready : in std_logic;
      s15_axi_arid : in std_logic_vector(0 downto 0);
      s15_axi_araddr : in std_logic_vector(63 downto 0);
      s15_axi_arlen : in std_logic_vector(7 downto 0);
      s15_axi_arsize : in std_logic_vector(2 downto 0);
      s15_axi_arburst : in std_logic_vector(1 downto 0);
      s15_axi_arlock : in std_logic;
      s15_axi_arcache : in std_logic_vector(3 downto 0);
      s15_axi_arprot : in std_logic_vector(2 downto 0);
      s15_axi_arqos : in std_logic_vector(3 downto 0);
      s15_axi_arvalid : in std_logic;
      s15_axi_arready : out std_logic;
      s15_axi_rid : out std_logic_vector(0 downto 0);
      s15_axi_rdata : out std_logic_vector(511 downto 0);
      s15_axi_rresp : out std_logic_vector(1 downto 0);
      s15_axi_rlast : out std_logic;
      s15_axi_rvalid : out std_logic;
      s15_axi_rready : in std_logic;
      m00_axi_areset_out_n : out std_logic;
      m00_axi_aclk : in std_logic;
      m00_axi_awid : out std_logic_vector(3 downto 0);
      m00_axi_awaddr : out std_logic_vector(63 downto 0);
      m00_axi_awlen : out std_logic_vector(7 downto 0);
      m00_axi_awsize : out std_logic_vector(2 downto 0);
      m00_axi_awburst : out std_logic_vector(1 downto 0);
      m00_axi_awlock : out std_logic;
      m00_axi_awcache : out std_logic_vector(3 downto 0);
      m00_axi_awprot : out std_logic_vector(2 downto 0);
      m00_axi_awqos : out std_logic_vector(3 downto 0);
      m00_axi_awvalid : out std_logic;
      m00_axi_awready : in std_logic;
      m00_axi_wdata : out std_logic_vector(511 downto 0);
      m00_axi_wstrb : out std_logic_vector(63 downto 0);
      m00_axi_wlast : out std_logic;
      m00_axi_wvalid : out std_logic;
      m00_axi_wready : in std_logic;
      m00_axi_bid : in std_logic_vector(3 downto 0);
      m00_axi_bresp : in std_logic_vector(1 downto 0);
      m00_axi_bvalid : in std_logic;
      m00_axi_bready : out std_logic;
      m00_axi_arid : out std_logic_vector(3 downto 0);
      m00_axi_araddr : out std_logic_vector(63 downto 0);
      m00_axi_arlen : out std_logic_vector(7 downto 0);
      m00_axi_arsize : out std_logic_vector(2 downto 0);
      m00_axi_arburst : out std_logic_vector(1 downto 0);
      m00_axi_arlock : out std_logic;
      m00_axi_arcache : out std_logic_vector(3 downto 0);
      m00_axi_arprot : out std_logic_vector(2 downto 0);
      m00_axi_arqos : out std_logic_vector(3 downto 0);
      m00_axi_arvalid : out std_logic;
      m00_axi_arready : in std_logic;
      m00_axi_rid : in std_logic_vector(3 downto 0);
      m00_axi_rdata : in std_logic_vector(511 downto 0);
      m00_axi_rresp : in std_logic_vector(1 downto 0);
      m00_axi_rlast : in std_logic;
      m00_axi_rvalid : in std_logic;
      m00_axi_rready : out std_logic
    );
  end component;

end package;
