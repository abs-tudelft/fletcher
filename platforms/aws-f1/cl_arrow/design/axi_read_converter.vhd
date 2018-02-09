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
use work.Utils.all;
use work.Arrow.all;
use work.Streams.all;

-- This entity converts read requests of a specific arlen and size
-- To another arlen and size
-- It assumed the addresses are already aligned and all data is used

entity axi_read_converter is
  generic (
    ADDR_WIDTH                  : natural;
    ID_WIDTH                    : natural;

    MASTER_DATA_WIDTH           : natural;
    SLAVE_DATA_WIDTH            : natural
  );
  
  port (
    clk                         :  in std_logic;
    reset_n                     :  in std_logic;
    
    -- Read address channel
    s_axi_araddr                :  in std_logic_vector(ADDR_WIDTH-1 downto 0);
    s_axi_arid                  :  in std_logic_vector(ID_WIDTH-1 downto 0);
    s_axi_arlen                 :  in std_logic_vector(7 downto 0);
    s_axi_arvalid               :  in std_logic;
    s_axi_arready               : out std_logic;
    s_axi_arsize                :  in std_logic_vector(2 downto 0);

    -- Read data channel
    s_axi_rid                   : out std_logic_vector(ID_WIDTH-1 downto 0);
    s_axi_rdata                 : out std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
    s_axi_rresp                 : out std_logic_vector(1 downto 0);
    s_axi_rlast                 : out std_logic;
    s_axi_rvalid                : out std_logic;
    s_axi_rready                :  in std_logic;

    -- Read address channel
    m_axi_araddr                : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    m_axi_arid                  : out std_logic_vector(ID_WIDTH-1 downto 0);
    m_axi_arlen                 : out std_logic_vector(7 downto 0);
    m_axi_arvalid               : out std_logic;
    m_axi_arready               : in  std_logic;
    m_axi_arsize                : out std_logic_vector(2 downto 0);

    -- Read data channel
    m_axi_rid                   : in  std_logic_vector(ID_WIDTH-1 downto 0);
    m_axi_rdata                 : in  std_logic_vector(MASTER_DATA_WIDTH-1 downto 0);
    m_axi_rresp                 : in  std_logic_vector(1 downto 0);
    m_axi_rlast                 : in  std_logic;
    m_axi_rvalid                : in  std_logic;
    m_axi_rready                : out std_logic
  );
end entity axi_read_converter;

architecture rtl of axi_read_converter is
  constant RATIO                : natural := MASTER_DATA_WIDTH / SLAVE_DATA_WIDTH;
  constant LEN_SHIFT            : natural := log2ceil(RATIO);

  constant MASTER_SIZE          : std_logic_vector(2 downto 0) := slv(u(log2ceil(MASTER_DATA_WIDTH/8),3));

  signal out_data               : std_logic_vector(s_axi_rid'length + s_axi_rresp'length + s_axi_rdata'length - 1 downto 0);

begin

  -- Assuming addresses are already aligned, we can simply
  -- connect the address channel and recalculate the length
  m_axi_araddr                  <= s_axi_araddr;
  m_axi_arid                    <= s_axi_arid;
  m_axi_arvalid                 <= s_axi_arvalid;
  
  m_axi_arsize                  <= MASTER_SIZE;
  m_axi_arlen                   <= slv(shift_right(u("0" & s_axi_arlen) + 1, LEN_SHIFT) - 1)(m_axi_arlen'range);
  
  s_axi_arready                 <= m_axi_arready;
  
  -- Serializer
  serializer: StreamSerializer
   generic map (
     DATA_WIDTH                 => SLAVE_DATA_WIDTH,
     CTRL_WIDTH                 => ID_WIDTH + 2, -- ID + Resp width
     IN_COUNT_MAX               => MASTER_DATA_WIDTH / SLAVE_DATA_WIDTH,
     IN_COUNT_WIDTH             => log2ceil(MASTER_DATA_WIDTH / SLAVE_DATA_WIDTH),
     OUT_COUNT_MAX              => 1,
     OUT_COUNT_WIDTH            => 1
   )
   port map (
     clk                        => clk,
     reset                      => not(reset_n),

     in_valid                   => m_axi_rvalid,
     in_ready                   => m_axi_rready,
     in_data                    => m_axi_rid & m_axi_rresp & m_axi_rdata,
     in_last                    => m_axi_rlast,

     out_valid                  => s_axi_rvalid,
     out_ready                  => s_axi_rready,
     out_data                   => out_data,
     out_last                   => s_axi_rlast
   );
   
   s_axi_rid    <= out_data(s_axi_rid'length + s_axi_rresp'length + s_axi_rdata'length - 1 downto s_axi_rresp'length + s_axi_rdata'length);
   s_axi_rresp  <= out_data(s_axi_rresp'length + s_axi_rdata'length - 1 downto s_axi_rdata'length);
   s_axi_rdata  <= out_data(s_axi_rdata'length - 1 downto 0);

end architecture rtl;

