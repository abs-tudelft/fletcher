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

entity AxiMmio_tc is
  generic (
    ---------------------------------------------------------------------------
    -- Bus metrics and configuration
    ---------------------------------------------------------------------------
    BUS_ADDR_WIDTH              : natural := 32;
    BUS_DATA_WIDTH              : natural := 32;

    NUM_REGS                    : natural := 8;

    REG_CONFIG                  : string := "";
    REG_RESET                   : string := ""
  );
end AxiMmio_tc;

architecture Behavioral of AxiMmio_tc is
  signal clk                    : std_logic;
  signal reset_n                : std_logic := '0';
  signal s_axi_awvalid          : std_logic;
  signal s_axi_awready          : std_logic;
  signal s_axi_awaddr           : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal s_axi_wvalid           : std_logic;
  signal s_axi_wready           : std_logic;
  signal s_axi_wdata            : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal s_axi_wstrb            : std_logic_vector((BUS_DATA_WIDTH/8)-1 downto 0);
  signal s_axi_bvalid           : std_logic;
  signal s_axi_bready           : std_logic;
  signal s_axi_bresp            : std_logic_vector(1 downto 0);
  signal s_axi_arvalid          : std_logic;
  signal s_axi_arready          : std_logic;
  signal s_axi_araddr           : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal s_axi_rvalid           : std_logic;
  signal s_axi_rready           : std_logic;
  signal s_axi_rdata            : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal s_axi_rresp            : std_logic_vector(1 downto 0);
  signal regs_data              : std_logic_vector(BUS_DATA_WIDTH*NUM_REGS-1 downto 0);
  signal write_data             : std_logic_vector(BUS_DATA_WIDTH*NUM_REGS-1 downto 0);
  signal write_enable           : std_logic_vector(NUM_REGS-1 downto 0);

  signal sim_done               : boolean := false;
  signal per_write_done         : boolean := false;
  signal bus_write_done         : boolean := false;
  signal bus_write_start        : boolean := false;  
begin

  -- Clock
  clk_proc: process is
  begin
    if not sim_done then
      clk <= '1';
      wait for 2 ns;
      clk <= '0';
      wait for 2 ns;
    else
      report "TEST PASSED";
      wait;
    end if;
  end process;

  -- Reset
  reset_proc: process is
  begin
    reset_n <= '0';
    wait for 8 ns;
    wait until rising_edge(clk);
    reset_n <= '1';
    wait;
  end process;
  
  -- Writes from peripheral
  per_write_proc: process is
  begin
    wait until reset_n <= '1';
    
    for I in 0 to NUM_REGS-1 loop
      write_data((I+1)*BUS_DATA_WIDTH-1 downto I*BUS_DATA_WIDTH) <= std_logic_vector(to_unsigned(I,BUS_DATA_WIDTH));
      write_enable(I) <= '1';
    end loop;
    
    wait until rising_edge(clk);
    
    per_write_done <= true;
    write_enable <= (others => '0');
    
    wait;
  end process;

  -- Read
  read_proc: process is
    variable raddr : natural := 0;
    variable rdat  : natural := 0;
  begin
    wait until reset_n = '1';

    loop
      s_axi_arvalid <= '0';
      s_axi_rready <= '0';
      
      -- We read twice, once after peripheral write, once after bus write
      wait until (per_write_done and not bus_write_start) or bus_write_done;

      loop
        -- Set address and validate
        s_axi_araddr <= std_logic_vector(to_unsigned(raddr * 4, BUS_ADDR_WIDTH));
        s_axi_arvalid <= '1';
        
        -- Wait for handshake
        wait until rising_edge(clk) and to_X01(s_axi_arready) = '1';
        
        s_axi_arvalid <= '0';
        s_axi_rready  <= '0';

        raddr := raddr + 1;

        -- Handshake read data
        if s_axi_rvalid /= '1' then
          wait until to_X01(s_axi_rvalid) = '1';
        end if;
        s_axi_rready <= '1';
        
        assert std_logic_vector(to_unsigned(rdat, BUS_ADDR_WIDTH)) = s_axi_rdata
          report "Unexpected s_axi_rdata."
          severity failure;
        
        wait until rising_edge(clk);
        s_axi_rready <= '0';
        
        
        rdat := rdat + 1;

        exit when raddr = NUM_REGS;
      end loop;
      
      bus_write_start <= true;
      
      -- Reset address for second round
      raddr := 0;
      
      if bus_write_done then
        exit;
      end if;
      
    end loop;
    
    sim_done <= true;
    wait;    
    
  end process;
  
    -- Writes from bus
  bus_write_proc: process is
    variable waddr : natural := 0;
    variable wdat  : natural := NUM_REGS;
  begin
    wait until reset_n <= '1';
    
    s_axi_awvalid <= '0';
    s_axi_bready <= '0';
    
    wait until bus_write_start;

    loop
      s_axi_awaddr <= std_logic_vector(to_unsigned(waddr * 4, BUS_ADDR_WIDTH));
      s_axi_awvalid <= '1';
      s_axi_bready <= '0';

      -- Wait for handshake
      wait until rising_edge(clk) and s_axi_awready = '1';
      
      s_axi_awvalid <= '0';

      waddr := waddr + 1;

      s_axi_wdata <= std_logic_vector(to_unsigned(wdat, BUS_ADDR_WIDTH));
      s_axi_wvalid <= '1';
      s_axi_bready <= '1'; -- forward bready in case the slave is fast
      wdat := wdat + 1;
            
      -- Wait for write acceptance
      if s_axi_wready /= '1' then
        wait until rising_edge(clk) and s_axi_wready = '1';
      end if;

      s_axi_wvalid <= '0';

      -- Wait for write response
      if s_axi_bvalid /= '1' then
        wait until rising_edge(clk) and s_axi_bvalid = '1';
      end if;
      
      s_axi_bready <= '1';
      
      exit when waddr = NUM_REGS;
    end loop;

    bus_write_done <= true;

    wait;
  end process;

  -- AXI mmio unit
  uut : AxiMmio
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      NUM_REGS                  => NUM_REGS
    )
    port map (
      clk => clk,
      reset_n => reset_n,
      s_axi_awvalid             => s_axi_awvalid,
      s_axi_awready             => s_axi_awready,
      s_axi_awaddr              => s_axi_awaddr,
      s_axi_wvalid              => s_axi_wvalid,
      s_axi_wready              => s_axi_wready,
      s_axi_wdata               => s_axi_wdata,
      s_axi_wstrb               => s_axi_wstrb,
      s_axi_bvalid              => s_axi_bvalid,
      s_axi_bready              => s_axi_bready,
      s_axi_bresp               => s_axi_bresp,
      s_axi_arvalid             => s_axi_arvalid,
      s_axi_arready             => s_axi_arready,
      s_axi_araddr              => s_axi_araddr,
      s_axi_rvalid              => s_axi_rvalid,
      s_axi_rready              => s_axi_rready,
      s_axi_rdata               => s_axi_rdata,
      s_axi_rresp               => s_axi_rresp,
      regs_out                  => regs_data,
      regs_in                   => write_data,
      regs_in_en                => write_enable
    );

end Behavioral;
