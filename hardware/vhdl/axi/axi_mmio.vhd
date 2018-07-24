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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.axi.all;

-- Provides an AXI4-lite slave MMIO to a serialized std_logic_vector compatible
-- for use as Fletcher MMIO.
entity axi_mmio is
  generic (
    ---------------------------------------------------------------------------
    -- Bus metrics and configuration
    ---------------------------------------------------------------------------
    BUS_ADDR_WIDTH              : natural := 32;
    BUS_DATA_WIDTH              : natural := 32;
    
    NUM_REGS                    : natural := 8;
    
    ENABLE_READ                 : bit_vector(NUM_REGS-1 downto 0) := (others => '1');
    ENABLE_WRITE                : bit_vector(NUM_REGS-1 downto 0) := (others => '1')
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic;
    
    -- Write adress channel
    s_axi_awvalid               : in  std_logic;
    s_axi_awready               : out std_logic;
    s_axi_awaddr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);

    -- Write data channel
    s_axi_wvalid                : in  std_logic;
    s_axi_wready                : out std_logic;
    s_axi_wdata                 : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    s_axi_wstrb                 : in  std_logic_vector((BUS_DATA_WIDTH/8)-1 downto 0);

    -- Write response channel
    s_axi_bvalid                : out std_logic;
    s_axi_bready                : in  std_logic;
    s_axi_bresp                 : out std_logic_vector(1 downto 0);

    -- Read address channel
    s_axi_arvalid               : in  std_logic;
    s_axi_arready               : out std_logic;
    s_axi_araddr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);

    -- Read data channel
    s_axi_rvalid                : out std_logic;
    s_axi_rready                : in  std_logic;
    s_axi_rdata                 : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    s_axi_rresp                 : out std_logic_vector(1 downto 0);
    
    -- Register access
    regs_data                   : out std_logic_vector(BUS_DATA_WIDTH*NUM_REGS-1 downto 0);
    write_data                  : in  std_logic_vector(BUS_DATA_WIDTH*NUM_REGS-1 downto 0);
    write_enable                : in  std_logic_vector(NUM_REGS-1 downto 0)
  );
end axi_mmio;

architecture Behavioral of axi_mmio is
  
  constant RESP_OK : std_logic_vector(1 downto 0) := "00";
  
  type state_type is (IDLE, WR, BR, RD);
  
  type regs_array_type is array (0 to NUM_REGS-1) of std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  
  type reg_type is record
    state : state_type;
    waddr : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    raddr : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    regs  : regs_array_type;
  end record;
  
  type comb_type is record
    awready : std_logic;
    wready  : std_logic;
    bvalid  : std_logic;
    bresp   : std_logic_vector(1 downto 0);
    arready : std_logic;
    rvalid  : std_logic;
    rdata   : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    rresp   : std_logic_vector(1 downto 0);    
  end record;
  
  constant comb_default : comb_type := (
    awready => '0',
    wready  => '0',
    bvalid  => '0',
    bresp   => (others => 'U'),
    arready => '0',
    rvalid  => '0',
    rdata   => (others => 'U'),
    rresp   => (others => 'U')
  );
  
  signal r : reg_type;
  signal d : reg_type;
    
begin

  -- Sequential part of state machine
  seq: process(clk) is
  begin
    if rising_edge(clk) then
      r <= d;
            
      -- Reset:
      if reset = '1' then
      
      end if;
    end if;
  end process;
  
  -- Combinatorial part of state machine
  comb: process(r,
    s_axi_awvalid, s_axi_awaddr,              -- Write Address Channel
    s_axi_wvalid, s_axi_wdata, s_axi_wstrb,   -- Write Data Channel
    s_axi_bready,                             -- Write Response Channel
    s_axi_arvalid, s_axi_araddr,              -- Read Address Channel
    s_axi_rready,                             -- Read Data Channel
    write_data, write_enable
  ) is
    variable widx : natural := 0;
    variable ridx : natural := 0;
  
    variable v : reg_type;
    variable o : comb_type;
  begin
    v := r;
    
    o := comb_default;
        
    -- Writes from peripheral
    for I in 0 to NUM_REGS-1 loop
      if write_enable(I) = '1' then
        v.regs(I) := write_data((I+1)*BUS_DATA_WIDTH-1 downto I*BUS_DATA_WIDTH);
      end if;
    end loop;

    case (r.state) is
      when IDLE =>
        if s_axi_awvalid = '1' then
          -- Write request
          v.state := WR;
          v.waddr := s_axi_awaddr;
          o.awready := '1';
        elsif s_axi_arvalid = '1' then
          -- Read request
          v.state := RD;
          v.raddr := s_axi_araddr;
          o.arready := '1';
        end if;

      -- Write data
      when WR =>
        widx := to_integer(unsigned(r.waddr));
        
        if s_axi_wvalid = '1' then
          if (ENABLE_WRITE(widx) = '1') then
            v.regs(widx) := s_axi_wdata;
            o.wready := '1';
            v.state := BR;
            
            -- Fast write response
            o.bvalid := '1'; 
            o.bresp := RESP_OK;
            if s_axi_bready = '1' then 
              v.state := IDLE;
            end if;
          end if;
        end if;
        
      -- Waiting for write response handshake
      when BR =>        
        o.bvalid := '1'; 
        o.bresp := RESP_OK;
        if s_axi_bready = '1' then
          v.state := IDLE;
        end if;

      -- Read response
      when RD => 
        ridx := to_integer(unsigned(r.raddr));
        
        if (ENABLE_READ(ridx) = '1') then
          o.rdata := r.regs(ridx);
          o.rvalid := '1';
          o.rresp := RESP_OK;
          if s_axi_rready = '1' then
            v.state := IDLE;
          end if;
        end if;

    end case;
    
    -- Registered outputs
    d <= v;
    
    -- Combinatorial outputs
    s_axi_awready <= o.awready;
    s_axi_wready  <= o.wready;
    s_axi_bvalid  <= o.bvalid;
    s_axi_bresp   <= o.bresp;
    s_axi_arready <= o.arready;
    s_axi_rvalid  <= o.rvalid;
    s_axi_rdata   <= o.rdata;
    s_axi_rresp   <= o.rresp;
    
  end process;
  
  -- Serialize the registers onto a single bus
  ser_regs: for I in 0 to NUM_REGS-1 generate
  begin
    regs_data((I+1) * BUS_DATA_WIDTH-1 downto I*BUS_DATA_WIDTH) <= r.regs(I);
  end generate;
  
end Behavioral;
