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
use ieee.std_logic_misc.all;

library work;
use work.Streams.all;
use work.Utils.all;
use work.Arrow.all;

-- AXI4 compatible top level for Fletcher generated accelerators.
entity fletcher_axi_top is
  generic (    
    -- Host bus properties
    BUS_ADDR_WIDTH              : natural :=  64;
    BUS_DATA_WIDTH              : natural := 512;

    -- MMIO bus properties
    SLV_BUS_ADDR_WIDTH          : natural :=  32;
    SLV_BUS_DATA_WIDTH          : natural :=  32
  );

  port (
    clk                         : in  std_logic;
    reset_n                     : in  std_logic;

    ---------------------------------------------------------------------------
    -- AXI4 master as Host Memory Interface
    ---------------------------------------------------------------------------    
    -- Read address channel
    m_axi_araddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    m_axi_arlen                 : out std_logic_vector(7 downto 0);
    m_axi_arvalid               : out std_logic;
    m_axi_arready               : in  std_logic;
    m_axi_arsize                : out std_logic_vector(2 downto 0);

    -- Read data channel
    m_axi_rdata                 : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    m_axi_rresp                 : in  std_logic_vector(1 downto 0);
    m_axi_rlast                 : in  std_logic;
    m_axi_rvalid                : in  std_logic;
    m_axi_rready                : out std_logic;
    
    -- Write address channel
    m_axi_awvalid               : out std_logic;
    m_axi_awready               : in  std_logic;
    m_axi_awaddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    m_axi_awlen                 : out std_logic_vector(7 downto 0);
    m_axi_awsize                : out std_logic_vector(2 downto 0);

    -- Write data channel
    m_axi_wvalid                : out std_logic;
    m_axi_wready                : in  std_logic;
    m_axi_wdata                 : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    m_axi_wlast                 : out std_logic;
    m_axi_wstrb                 : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
    
    ---------------------------------------------------------------------------
    -- AXI4-lite Slave as MMIO interface
    ---------------------------------------------------------------------------
    -- Write adress channel
    s_axi_awvalid               : in std_logic;
    s_axi_awready               : out std_logic;
    s_axi_awaddr                : in std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);

    -- Write data channel
    s_axi_wvalid                : in std_logic;
    s_axi_wready                : out std_logic;
    s_axi_wdata                 : in std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
    s_axi_wstrb                 : in std_logic_vector((SLV_BUS_DATA_WIDTH/8)-1 downto 0);

    -- Write response channel
    s_axi_bvalid                : out std_logic;
    s_axi_bready                : in std_logic;
    s_axi_bresp                 : out std_logic_vector(1 downto 0);

    -- Read address channel
    s_axi_arvalid               : in std_logic;
    s_axi_arready               : out std_logic;
    s_axi_araddr                : in std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);

    -- Read data channel
    s_axi_rvalid                : out std_logic;
    s_axi_rready                : in std_logic;
    s_axi_rdata                 : out std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
    s_axi_rresp                 : out std_logic_vector(1 downto 0)
  );
end fletcher_axi_top;

architecture Behavorial of fletcher_axi_top is
begin

end architecture;
