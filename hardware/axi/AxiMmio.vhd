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
use work.Axi_pkg.all;
use work.Stream_pkg.all;
use work.UtilInt_pkg.all;

-- Provides an AXI4-lite slave to write to / read from a set of registers.
entity AxiMmio is
  generic (
    ---------------------------------------------------------------------------
    -- Bus metrics and configuration
    ---------------------------------------------------------------------------
    BUS_ADDR_WIDTH              : natural := 32;
    BUS_DATA_WIDTH              : natural := 32;
    
    ---------------------------------------------------------------------------
    -- Register configuration
    ---------------------------------------------------------------------------
    
    -- Number of 32-bit registers.    
    NUM_REGS                    : natural;
    
    -- Register read/write configuration:
    -- Each character in this string will determine whether its corresponding
    -- register is Write-Only (W), Read-Only (R) or Bidirectional (B) as seen
    -- from the master of the AXI4-lite bus.
    --
    -- Example : 0..3 write only, 4..5 read only 6..7 bidi
    -- Register: 0 1 2 3 4 5 6 7
    -- String  : W W W W R R B B -> "WWWWRRBB"
    --
    -- Leaving this string empty ("") will cause all registers to be 
    -- bidirectional.
    REG_CONFIG                  : string := "";
    
    -- Register reset configuration:
    -- Each character in this string will determine whether its corresponding
    -- register is reset when reset is asserted. 'Y' is used to reset, 'N' is
    -- used to not reset.
    --
    -- Example : 0..3 should be reset, 4..7 should not be reset
    -- Register: 0 1 2 3 4 5 6 7
    -- String  : Y Y Y Y N N N N -> "YYYYNNNN"
    --
    -- Leave blank to reset all registers.    
    REG_RESET                   : string := "";
    
    -- Read channels slice depth
    SLV_R_SLICE_DEPTH           : natural := 2;
    
    -- Write channels slice depths
    SLV_W_SLICE_DEPTH           : natural := 2
    
  );
  port (
    clk                         : in  std_logic;
    reset_n                     : in  std_logic;
    
    -- Write address channel
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
    regs_out                    : out std_logic_vector(BUS_DATA_WIDTH*NUM_REGS-1 downto 0);
    regs_in                     : in  std_logic_vector(BUS_DATA_WIDTH*NUM_REGS-1 downto 0);
    regs_in_en                  : in  std_logic_vector(NUM_REGS-1 downto 0)
  );
end AxiMmio;

architecture Behavioral of AxiMmio is

  constant ARDCI : nat_array := cumulative((
    1 => s_axi_rdata'length,
    0 => s_axi_rresp'length
  ));  

  constant AWDCI : nat_array := cumulative((
    1 => s_axi_wdata'length,
    0 => s_axi_wstrb'length
  ));
  
  signal int_s_axi_wall         : std_logic_vector(AWDCI(2)-1 downto 0);
  signal int_s_axi_rall         : std_logic_vector(ARDCI(2)-1 downto 0);
  signal s_axi_wall             : std_logic_vector(AWDCI(2)-1 downto 0);
  signal s_axi_rall             : std_logic_vector(ARDCI(2)-1 downto 0);
  
  signal int_s_axi_awvalid      : std_logic;
  signal int_s_axi_awready      : std_logic;
  signal int_s_axi_awaddr       : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal int_s_axi_wvalid       : std_logic;
  signal int_s_axi_wready       : std_logic;
  signal int_s_axi_wdata        : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal int_s_axi_wstrb        : std_logic_vector((BUS_DATA_WIDTH/8)-1 downto 0);
  signal int_s_axi_bvalid       : std_logic;
  signal int_s_axi_bready       : std_logic;
  signal int_s_axi_bresp        : std_logic_vector(1 downto 0);
  signal int_s_axi_arvalid      : std_logic;
  signal int_s_axi_arready      : std_logic;
  signal int_s_axi_araddr       : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal int_s_axi_rvalid       : std_logic;
  signal int_s_axi_rready       : std_logic;
  signal int_s_axi_rdata        : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal int_s_axi_rresp        : std_logic_vector(1 downto 0);

  
  constant RESP_OK : std_logic_vector(1 downto 0) := "00";
  
  -- The LSB index in the slave address
  constant SLV_ADDR_LSB : natural := log2ceil(BUS_DATA_WIDTH/4) - 1;
  
  -- The MSB index in the slave address
  constant SLV_ADDR_MSB : natural := SLV_ADDR_LSB + log2ceil(NUM_REGS) - 1;
  
  type state_type is (IDLE, WR, BR, RD);
  
  type regs_array_type is array (0 to NUM_REGS-1) of std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  
  type reg_type is record
    state : state_type;
    addr  : std_logic_vector(SLV_ADDR_MSB - SLV_ADDR_LSB downto 0);
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
  
  signal reset : std_logic;
    
begin

  reset <= not(reset_n);

  -- Sequential part of state machine
  seq: process(clk) is
  begin
    if rising_edge(clk) then
      r <= d;
      
      -- Reset:
      if reset_n = '0' then
        r.state <= IDLE;
        
        -- Check for each register if it needs to be reset
        if (REG_RESET /= "") then
          for I in REG_RESET'range loop
              if (REG_RESET(I) /= 'Y') then
                r.regs(I-REG_RESET'low) <= (others => '0');
              end if;
          end loop;
        else
          for I in r.regs'range loop
            r.regs(I) <= (others => '0');
          end loop;
        end if;
      end if;
    end if;
  end process;
  
  -- Combinatorial part of state machine
  comb: process(r,
    int_s_axi_awvalid, int_s_axi_awaddr,                  -- Write Address Channel
    int_s_axi_wvalid, int_s_axi_wdata, int_s_axi_wstrb,   -- Write Data Channel
    int_s_axi_bready,                                     -- Write Response Channel
    int_s_axi_arvalid, int_s_axi_araddr,                  -- Read Address Channel
    int_s_axi_rready,                                     -- Read Data Channel
    regs_in, regs_in_en
  ) is
    variable idx : natural := 0;
  
    variable v : reg_type;
    variable o : comb_type;
  begin
    v := r;
    
    o := comb_default;
    
    -- Writes from peripheral
    for I in 0 to NUM_REGS-1 loop
      if regs_in_en(I) = '1' then
        v.regs(I) := regs_in((I+1)*BUS_DATA_WIDTH-1 downto I*BUS_DATA_WIDTH);
      end if;
    end loop;

    case (r.state) is
      when IDLE =>
        if int_s_axi_awvalid = '1' then
          -- Write request
          v.state := WR;
          v.addr := int_s_axi_awaddr(SLV_ADDR_MSB downto SLV_ADDR_LSB);
          o.awready := '1';
        elsif int_s_axi_arvalid = '1' then
          -- Read request
          v.state := RD;
          v.addr := int_s_axi_araddr(SLV_ADDR_MSB downto SLV_ADDR_LSB);
          o.arready := '1';
        end if;

      -- Write data
      when WR =>
        idx := to_integer(unsigned(r.addr));
        
        if int_s_axi_wvalid = '1' then
          -- Acknowledge write
          o.wready := '1';
          v.state := BR;
            
          -- Fast write response
          o.bvalid := '1'; 
          o.bresp := RESP_OK;
          
          -- Write only if register is writeable
          if (REG_CONFIG = "") or (REG_CONFIG(idx+REG_CONFIG'low) = 'W') or (REG_CONFIG(idx+REG_CONFIG'low) = 'B') then
            v.regs(idx) := int_s_axi_wdata;
          else
            -- If not writable, generate a warning in simulation            
            report "[AXI MMIO] Attempted to write to read-only register " & 
              integer'image(idx) & "."
              severity warning;
          end if;
          
          -- Go to idle if write response was already ready.
          if int_s_axi_bready = '1' then 
              v.state := IDLE;
            end if;
                    
        end if;
        
      -- Waiting for write response handshake
      when BR =>        
        o.bvalid := '1'; 
        o.bresp := RESP_OK;
        if int_s_axi_bready = '1' then
          v.state := IDLE;
        end if;

      -- Read response
      when RD => 
        idx := to_integer(unsigned(r.addr));

        -- Accept the read
        o.rvalid := '1';
        o.rresp := RESP_OK;
                
        -- Check if register is readable
        if (REG_CONFIG = "") or (REG_CONFIG(idx+REG_CONFIG'low) = 'R') or (REG_CONFIG(idx+REG_CONFIG'low) = 'B') then
          o.rdata := r.regs(idx);
        else
          -- Respond with DEADBEEF if not readable
          o.rdata := X"DEADBEEF";
          
          -- Generate a warning in simulation.
          report "[AXI MMIO] Attempted to read from write-only register " & 
            integer'image(idx) & "."
            severity warning;
        end if;
        
        -- Go back to idle if the read data was accepted.
        if int_s_axi_rready = '1' then
          v.state := IDLE;
        end if;

    end case;
    
    -- Registered outputs
    d <= v;
    
    -- Combinatorial outputs
    int_s_axi_awready <= o.awready;
    int_s_axi_wready  <= o.wready;
    int_s_axi_bvalid  <= o.bvalid;
    int_s_axi_bresp   <= o.bresp;
    int_s_axi_arready <= o.arready;
    int_s_axi_rvalid  <= o.rvalid;
    int_s_axi_rdata   <= o.rdata;
    int_s_axi_rresp   <= o.rresp;
    
  end process;
  
  -- Serialize the registers onto a single bus
  ser_regs: for I in 0 to NUM_REGS-1 generate
  begin
    regs_out((I+1) * BUS_DATA_WIDTH-1 downto I*BUS_DATA_WIDTH) <= r.regs(I);
  end generate;
  
  
  -----------------------------------------------------------------------------
  -- Slices
  
  -- AXI read address channel slice -------------------------------------------
  arac_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => SLV_R_SLICE_DEPTH,
      DATA_WIDTH                => s_axi_araddr'length
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_ready                  => s_axi_arready,
      in_valid                  => s_axi_arvalid,
      in_data                   => s_axi_araddr,
      out_ready                 => int_s_axi_arready,
      out_valid                 => int_s_axi_arvalid,
      out_data                  => int_s_axi_araddr
    );
    
  -- AXI read data channel slice ----------------------------------------------
  int_s_axi_rall                <= int_s_axi_rdata & int_s_axi_rresp;
  ardc_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => SLV_R_SLICE_DEPTH,
      DATA_WIDTH                => ARDCI(2)
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_ready                  => int_s_axi_rready,
      in_valid                  => int_s_axi_rvalid,
      in_data                   => int_s_axi_rall,
      out_ready                 => s_axi_rready,
      out_valid                 => s_axi_rvalid,
      out_data                  => s_axi_rall
    );
    
  s_axi_rdata                   <= s_axi_rall(ARDCI(2)-1 downto ARDCI(1));
  s_axi_rresp                   <= s_axi_rall(ARDCI(1)-1 downto ARDCI(0));
    
  -- AXI write address channel slice ------------------------------------------
  awac_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => SLV_R_SLICE_DEPTH,
      DATA_WIDTH                => s_axi_awaddr'length
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_ready                  => s_axi_awready,
      in_valid                  => s_axi_awvalid,
      in_data                   => s_axi_awaddr,
      out_ready                 => int_s_axi_awready,
      out_valid                 => int_s_axi_awvalid,
      out_data                  => int_s_axi_awaddr
    );
  
  -- AXI write data channel slice ---------------------------------------------
  s_axi_wall                    <= s_axi_wdata & s_axi_wstrb;
  
  awdc_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => SLV_R_SLICE_DEPTH,
      DATA_WIDTH                => AWDCI(2)
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_ready                  => s_axi_wready,
      in_valid                  => s_axi_wvalid,
      in_data                   => s_axi_wall,
      out_ready                 => int_s_axi_wready,
      out_valid                 => int_s_axi_wvalid,
      out_data                  => int_s_axi_wall
    );
    
  int_s_axi_wdata               <= s_axi_wall(AWDCI(2)-1 downto AWDCI(1));
  int_s_axi_wstrb               <= s_axi_wall(AWDCI(1)-1 downto AWDCI(0));
  
  -- AXI write response channel slice -----------------------------------------
  awbc_slice : StreamBuffer
    generic map (
      MIN_DEPTH                 => SLV_R_SLICE_DEPTH,
      DATA_WIDTH                => s_axi_bresp'length
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_ready                  => int_s_axi_bready,
      in_valid                  => int_s_axi_bvalid,
      in_data                   => int_s_axi_bresp,
      out_ready                 => s_axi_bready,
      out_valid                 => s_axi_bvalid,
      out_data                  => s_axi_bresp
    ); 
  
end Behavioral;
