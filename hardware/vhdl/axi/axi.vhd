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

package AXI is

  component axi_mmio is
    generic (
      BUS_ADDR_WIDTH            : natural;
      BUS_DATA_WIDTH            : natural;   
      NUM_REGS                  : natural;
      ENABLE_READ               : bit_vector(NUM_REGS-1 downto 0);
      ENABLE_WRITE              : bit_vector(NUM_REGS-1 downto 0)
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      s_axi_awvalid             : in  std_logic;
      s_axi_awready             : out std_logic;
      s_axi_awaddr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      s_axi_wvalid              : in  std_logic;
      s_axi_wready              : out std_logic;
      s_axi_wdata               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      s_axi_wstrb               : in  std_logic_vector((BUS_DATA_WIDTH/8)-1 downto 0);
      s_axi_bvalid              : out std_logic;
      s_axi_bready              : in  std_logic;
      s_axi_bresp               : out std_logic_vector(1 downto 0);
      s_axi_arvalid             : in  std_logic;
      s_axi_arready             : out std_logic;
      s_axi_araddr              : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      s_axi_rvalid              : out std_logic;
      s_axi_rready              : in  std_logic;
      s_axi_rdata               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      s_axi_rresp               : out std_logic_vector(1 downto 0);
      regs_data                 : out std_logic_vector(BUS_DATA_WIDTH*NUM_REGS-1 downto 0);
      write_data                : in  std_logic_vector(BUS_DATA_WIDTH*NUM_REGS-1 downto 0);
      write_enable              : in  std_logic_vector(NUM_REGS-1 downto 0)
    );
  end component;


end AXI;
