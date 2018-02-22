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

-- This entity converts read requests of a specific len and size on the slave port
-- to proper len and size on the master port. It assumed the addresses and lens are
-- already aligned to the master data width. So for example, if the slave width is 
-- 32 bits and the master width is 512, the slave len should be integer multiples of
-- 16.
-- It also subtracts the Fletcher side len with 1 and decreases the number
-- of bits used to whatever is specified on the slave port.

entity axi_read_converter is
  generic (
    ADDR_WIDTH                  : natural;
    ID_WIDTH                    : natural;

    MASTER_DATA_WIDTH           : natural;
    MASTER_LEN_WIDTH            : natural;
    SLAVE_DATA_WIDTH            : natural;
    SLAVE_LEN_WIDTH             : natural
  );
  
  port (
    clk                         :  in std_logic;
    reset_n                     :  in std_logic;
    
    -- Fletcher bus
    -- Read address channel
    s_bus_req_addr              :  in std_logic_vector(ADDR_WIDTH-1 downto 0);
    s_bus_req_id                :  in std_logic_vector(ID_WIDTH-1 downto 0);
    s_bus_req_len               :  in std_logic_vector(SLAVE_LEN_WIDTH-1 downto 0);
    s_bus_req_valid             :  in std_logic;
    s_bus_req_ready             : out std_logic;

    -- Read data channel
    s_bus_rsp_id                : out std_logic_vector(ID_WIDTH-1 downto 0);
    s_bus_rsp_data              : out std_logic_vector(SLAVE_DATA_WIDTH-1 downto 0);
    s_bus_rsp_resp              : out std_logic_vector(1 downto 0);
    s_bus_rsp_last              : out std_logic;
    s_bus_rsp_valid             : out std_logic;
    s_bus_rsp_ready             :  in std_logic;

    -- AXI BUS
    -- Read address channel
    m_axi_araddr                : out std_logic_vector(ADDR_WIDTH-1 downto 0);
    m_axi_arid                  : out std_logic_vector(ID_WIDTH-1 downto 0);
    m_axi_arlen                 : out std_logic_vector(MASTER_LEN_WIDTH-1 downto 0);
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
  
  signal new_len                : unsigned(SLAVE_LEN_WIDTH-1 downto 0);

  signal out_data               : std_logic_vector(s_bus_rsp_id'length + s_bus_rsp_resp'length + s_bus_rsp_data'length - 1 downto 0);
begin

  -- Assuming addresses are already aligned, we can simply
  -- connect the address channel and recalculate the length
  m_axi_araddr                  <= s_bus_req_addr;
  m_axi_arid                    <= s_bus_req_id;
  m_axi_arvalid                 <= s_bus_req_valid;
  
  m_axi_arsize                  <= MASTER_SIZE;
  
  -- Length conversion; get the number of full words on the master
  -- Thus we have to shift with the log2ceil of the ratio, but round up 
  -- in case its not an integer multiple of the ratio.
  -- Also subtract 1 from the length to go to AXI spec
  new_len                       <= shift_right_round_up(u(s_bus_req_len), LEN_SHIFT) - 1;
  -- Resize the new length to AXI spec
  m_axi_arlen                   <= slv(resize(new_len, MASTER_LEN_WIDTH));
  
  s_bus_req_ready               <= m_axi_arready;
  
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

     out_valid                  => s_bus_rsp_valid,
     out_ready                  => s_bus_rsp_ready,
     out_data                   => out_data,
     out_last                   => s_bus_rsp_last
   );
   
   s_bus_rsp_id    <= out_data(s_bus_rsp_id'length + s_bus_rsp_resp'length + s_bus_rsp_data'length - 1 downto s_bus_rsp_resp'length + s_bus_rsp_data'length);
   s_bus_rsp_resp  <= out_data(s_bus_rsp_resp'length + s_bus_rsp_data'length - 1 downto s_bus_rsp_data'length);
   s_bus_rsp_data  <= out_data(s_bus_rsp_data'length - 1 downto 0);

end architecture rtl;

