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

package stringwrite_pkg is
  component UTF8StringGen is
    generic (
      INDEX_WIDTH               : natural :=   32;
      ELEMENT_WIDTH             : natural :=    8;
      ELEMENT_COUNT_MAX         : natural :=    8;
      ELEMENT_COUNT_WIDTH       : natural :=    4;

      LEN_WIDTH                 : natural :=    8;

      LENGTH_BUFFER_DEPTH       : natural :=    8;

      LEN_SLICE                 : boolean := true;
      UTF8_SLICE                : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_len                   : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_strlen_min            : in  std_logic_vector(LEN_WIDTH-1 downto 0);
      cmd_prng_mask             : in  std_logic_vector(LEN_WIDTH-1 downto 0);

      len_valid                 : out std_logic;
      len_ready                 : in  std_logic;
      len_data                  : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      len_last                  : out std_logic;
      len_dvalid                : out std_logic;

      utf8_valid                : out std_logic;
      utf8_ready                : in  std_logic;
      utf8_data                 : out std_logic_vector(ELEMENT_COUNT_MAX * ELEMENT_WIDTH-1 downto 0);
      utf8_count                : out std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      utf8_last                 : out std_logic;
      utf8_dvalid               : out std_logic
    );
  end component;

  component stringwrite is
    generic (
      BUS_ADDR_WIDTH            : natural :=  64;
      BUS_DATA_WIDTH            : natural := 512;
      SLV_BUS_ADDR_WIDTH        : natural :=  32;
      SLV_BUS_DATA_WIDTH        : natural :=  32
    );
    port (
      clk                       : in  std_logic;
      reset_n                   : in  std_logic;
      m_axi_awvalid             : out std_logic;
      m_axi_awready             : in  std_logic;
      m_axi_awaddr              : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      m_axi_awlen               : out std_logic_vector(7 downto 0);
      m_axi_awsize              : out std_logic_vector(2 downto 0);
      m_axi_wvalid              : out std_logic;
      m_axi_wready              : in  std_logic;
      m_axi_wdata               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      m_axi_wlast               : out std_logic;
      m_axi_wstrb               : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
      s_axi_awvalid             : in std_logic;
      s_axi_awready             : out std_logic;
      s_axi_awaddr              : in std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);
      s_axi_wvalid              : in std_logic;
      s_axi_wready              : out std_logic;
      s_axi_wdata               : in std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
      s_axi_wstrb               : in std_logic_vector((SLV_BUS_DATA_WIDTH/8)-1 downto 0);
      s_axi_bvalid              : out std_logic;
      s_axi_bready              : in std_logic;
      s_axi_bresp               : out std_logic_vector(1 downto 0);
      s_axi_arvalid             : in std_logic;
      s_axi_arready             : out std_logic;
      s_axi_araddr              : in std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);
      s_axi_rvalid              : out std_logic;
      s_axi_rready              : in std_logic;
      s_axi_rdata               : out std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
      s_axi_rresp               : out std_logic_vector(1 downto 0)
    );
  end component;

  component axi_write_converter is
    generic (
      ADDR_WIDTH                : natural;
      MASTER_DATA_WIDTH         : natural;
      MASTER_LEN_WIDTH          : natural;
      SLAVE_DATA_WIDTH          : natural;
      SLAVE_LEN_WIDTH           : natural;
      SLAVE_MAX_BURST           : natural;
      ENABLE_FIFO               : boolean
    );
    port (
      clk                       : in  std_logic;
      reset_n                   : in  std_logic;
      s_bus_wreq_valid          : in  std_logic;
      s_bus_wreq_ready          : out std_logic;
      s_bus_wreq_addr           : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      s_bus_wreq_len            : in  std_logic_vector(SLAVE_LEN_WIDTH-1 downto 0);
      s_bus_wdat_valid          : in  std_logic;
      s_bus_wdat_ready          : out std_logic;
      s_bus_wdat_data           : in  std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
      s_bus_wdat_strobe         : in  std_logic_vector(SLAVE_DATA_WIDTH/8-1 downto 0);
      s_bus_wdat_last           : in  std_logic;
      m_axi_awaddr              : out std_logic_vector(ADDR_WIDTH-1 downto 0);
      m_axi_awlen               : out std_logic_vector(MASTER_LEN_WIDTH-1 downto 0);
      m_axi_awvalid             : out std_logic;
      m_axi_awready             : in  std_logic;
      m_axi_awsize              : out std_logic_vector(2 downto 0);
      m_axi_wvalid              : out std_logic;
      m_axi_wready              : in  std_logic;
      m_axi_wdata               : out std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
      m_axi_wstrb               : out std_logic_vector(MASTER_DATA_WIDTH/8-1 downto 0);
      m_axi_wlast               : out std_logic
    );
  end component;
  
  function readable_utf8 (prng_data: std_logic_vector) return unsigned;
    
end stringwrite_pkg;
package body stringwrite_pkg is

  -- Make "readable" UTF8 Final range will be between space and ~
  function readable_utf8 (prng_data: std_logic_vector) 
    return unsigned 
  is
    constant startc  : natural := 32;
    variable char : unsigned(7 downto 0);
  begin
    char := (others => '0');
    
    -- We can only get 0..127
    char(6 downto 0) := unsigned(prng_data(6 downto 0));
    
    -- Make a space out of the character if it's any control character
    if char < startc then
      char := to_unsigned(32, 8);
    end if;
    if char = 127 then
      char := to_unsigned(32, 8);
    end if;
    
    return char;
  end function;
  
end stringwrite_pkg;
