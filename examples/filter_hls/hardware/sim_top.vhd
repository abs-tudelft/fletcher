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
use work.Interconnect.all;

entity sim_top is
  generic (
    -- Accelerator properties
    INDEX_WIDTH                 : natural := 32;
    NUM_ARROW_BUFFERS           : natural := 7;
    NUM_USER_REGS               : natural := 0;
    NUM_REGS                    : natural := 20;
    REG_WIDTH                   : natural := 32;
    TAG_WIDTH                   : natural := 1;

    -- Host bus properties
    BUS_ADDR_WIDTH              : natural := 64;
    BUS_DATA_WIDTH              : natural := 512;
    BUS_STROBE_WIDTH            : natural := 64;
    BUS_LEN_WIDTH               : natural := 8;
    BUS_BURST_MAX_LEN           : natural := 64;
    BUS_BURST_STEP_LEN          : natural := 1;

    -- MMIO bus properties
    SLV_BUS_ADDR_WIDTH          : natural := 32;
    SLV_BUS_DATA_WIDTH          : natural := 32
  );
end sim_top;

architecture Behavorial of sim_top is

  -----------------------------------------------------------------------------
  -- Default wrapper component.
  -----------------------------------------------------------------------------
  component filter_wrapper is
    generic(
      BUS_ADDR_WIDTH            : natural;
      BUS_DATA_WIDTH            : natural;
      BUS_STROBE_WIDTH          : natural;
      BUS_LEN_WIDTH             : natural;
      BUS_BURST_STEP_LEN        : natural;
      BUS_BURST_MAX_LEN         : natural;
      INDEX_WIDTH               : natural;
      NUM_ARROW_BUFFERS         : natural;
      NUM_REGS                  : natural;
      NUM_USER_REGS             : natural;
      REG_WIDTH                 : natural;
      TAG_WIDTH                 : natural
    );
    port(
      acc_clk                   : in std_logic;
      acc_reset                 : in std_logic;
      bus_clk                   : in std_logic;
      bus_reset                 : in std_logic;
      mst_rreq_valid            : out std_logic;
      mst_rreq_ready            : in std_logic;
      mst_rreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      mst_rreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      mst_rdat_valid            : in std_logic;
      mst_rdat_ready            : out std_logic;
      mst_rdat_data             : in std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      mst_rdat_last             : in std_logic;
      mst_wreq_valid            : out std_logic;
      mst_wreq_ready            : in std_logic;
      mst_wreq_addr             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      mst_wreq_len              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      mst_wdat_valid            : out std_logic;
      mst_wdat_ready            : in std_logic;
      mst_wdat_data             : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      mst_wdat_strobe           : out std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
      mst_wdat_last             : out std_logic;
      regs_in                   : in std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
      regs_out                  : out std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
      regs_out_en               : out std_logic_vector(NUM_REGS-1 downto 0)
    );
  end component;
  -----------------------------------------------------------------------------

  -- Sim constants
  constant REG_CONTROL          : natural := 0;
  constant REG_STATUS           : natural := 1;
  constant REG_RETURN0          : natural := 2;
  constant REG_RETURN1          : natural := 3;

  -- Sim signals
  signal clock_stop             : boolean := false;

  -- Accelerator signals
  signal acc_clk                : std_logic;
  signal acc_reset              : std_logic;

  -- Fletcher bus signals
  signal bus_clk                : std_logic;
  signal bus_reset              : std_logic;
  
  signal bus_rreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_rreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_rreq_valid         : std_logic;
  signal bus_rreq_ready         : std_logic;
  signal bus_rdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_rdat_last          : std_logic;
  signal bus_rdat_valid         : std_logic;
  signal bus_rdat_ready         : std_logic;
  signal bus_wreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_wreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_wreq_valid         : std_logic;
  signal bus_wreq_ready         : std_logic;
  signal bus_wdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_wdat_strobe        : std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
  signal bus_wdat_last          : std_logic;
  signal bus_wdat_valid         : std_logic;
  signal bus_wdat_ready         : std_logic;

  -- MMIO registers
  signal regs_in                : std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
  signal regs                   : std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
  signal regs_out               : std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
  signal regs_out_en            : std_logic_vector(NUM_REGS-1 downto 0);
  
  -- Write to MMIO register by index
  procedure mmio_write(idx  : in  natural;
                       data : in  std_logic_vector(REG_WIDTH-1 downto 0);
                       signal regs : out std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0))
  is begin
    regs((idx+1)*REG_WIDTH-1 downto idx*REG_WIDTH) <= data;
  end mmio_write;
  
  -- Procedure to easily write to a user register
  procedure uc_reg_write(idx  : in  natural;
                         data : in  std_logic_vector(REG_WIDTH-1 downto 0);
                         signal regs : out std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0))
  is begin
    mmio_write(4+idx, data, regs);
  end uc_reg_write;
  
  -- Read from MMIO register by index
  procedure mmio_read(idx  : in  natural;
                      data : out std_logic_vector(REG_WIDTH-1 downto 0);
                      signal regs : in  std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0))
  is begin
    data := regs((idx+1)*REG_WIDTH-1 downto idx*REG_WIDTH);
  end mmio_read;  
  
  -- Procedure to easily read from a user register
  procedure uc_reg_read(idx  : in  natural;
                        data : out std_logic_vector(REG_WIDTH-1 downto 0);
                        signal regs : in  std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0))
  is begin
    mmio_read(4+idx, data, regs);
  end uc_reg_read;
  
  procedure uc_start(signal regs: out std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0)) is 
  begin 
    mmio_write(REG_CONTROL, X"00000001", regs); 
  end uc_start;
  
  procedure uc_stop (signal regs: out std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0)) is
  begin 
    mmio_write(REG_CONTROL, X"00000002", regs); 
  end uc_stop;
  
  procedure uc_reset(signal regs: out std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0)) is 
  begin 
    mmio_write(REG_CONTROL, X"00000004", regs); 
  end uc_reset;
  
begin

  -- Typical stimuli process:
  stimuli_proc : process is
    variable read_data : std_logic_vector(REG_WIDTH-1 downto 0);
  begin
    wait until acc_reset = '1' and bus_reset = '1';
    
    -- 1. Reset the user core
    uc_reset(regs_in);
    wait until rising_edge(acc_clk);
    
    
    -- 2. Write addresses of the arrow buffers in the SREC file.
    mmio_write(6, X"00000000", regs_in);
    wait until rising_edge(acc_clk);
    mmio_write(7, X"00000000", regs_in);
    wait until rising_edge(acc_clk);
    mmio_write(8, X"00000040", regs_in);
    wait until rising_edge(acc_clk);
    mmio_write(9, X"00000000", regs_in);
    wait until rising_edge(acc_clk);
    mmio_write(10, X"00000080", regs_in);
    wait until rising_edge(acc_clk);
    mmio_write(11, X"00000000", regs_in);
    wait until rising_edge(acc_clk);
    mmio_write(12, X"000000c0", regs_in);
    wait until rising_edge(acc_clk);
    mmio_write(13, X"00000000", regs_in);
    wait until rising_edge(acc_clk);
    mmio_write(14, X"00000100", regs_in);
    wait until rising_edge(acc_clk);
    mmio_write(15, X"00000000", regs_in);
    wait until rising_edge(acc_clk);
    
    mmio_write(16, X"00000000", regs_in);
    wait until rising_edge(acc_clk);
    mmio_write(17, X"00000000", regs_in);
    wait until rising_edge(acc_clk);
    
    mmio_write(18, X"00000100", regs_in);
    wait until rising_edge(acc_clk);
    mmio_write(19, X"00000000", regs_in);
    wait until rising_edge(acc_clk);

    -- 3. Writes any user core registers.
    --
    -- Here you can write, for example, the first and last index
    -- 
    -- Example:
    -- First index in user reg 0
    uc_reg_write(0, X"00000000", regs_in); wait until rising_edge(acc_clk);
    -- Last index in user reg 1
    uc_reg_write(1, X"00000004", regs_in); wait until rising_edge(acc_clk);
    
    -- 4. Start the user core.    
    uc_start(regs_in);
    wait until rising_edge(acc_clk);
    
    -- 5. Poll for completion
    loop
      wait until rising_edge(acc_clk);
      
      -- Read from the status register.
      mmio_read(REG_STATUS, read_data, regs);
      
      -- Stop polling when done bit is asserted.
      exit when read_data(2) = '1';
    end loop;
    
    -- 6. Read return register
    mmio_read(REG_RETURN0, read_data, regs);
    report "Return register 0: " & integer'image(to_integer(unsigned(read_data)));
    
    mmio_read(REG_RETURN0, read_data, regs);
    report "Return register 1: " & integer'image(to_integer(unsigned(read_data)));
    
    -- 7. Finish and stop simulation
    report "Stimuli done.";
    clock_stop <= true;
    
    wait;
  end process;

  clk_proc: process is
  begin
    if not clock_stop then
      acc_clk <= '1';
      bus_clk <= '1';
      wait for 5 ns;
      acc_clk <= '0';
      bus_clk <= '0';
      wait for 5 ns;
    else
      wait;
    end if;
  end process;

  reset_proc: process is
  begin
    acc_reset <= '1';
    bus_reset <= '1';
    wait for 50 ns;
    wait until rising_edge(acc_clk);
    acc_reset <= '0';
    bus_reset <= '0';
    wait;
  end process;
  
  regs_out_proc: process(acc_clk) is
  begin
    if rising_edge(acc_clk) then
      for I in 0 to NUM_REGS-1 loop
        if regs_out_en(I) = '1' then
          regs((I+1)*REG_WIDTH-1 downto I * REG_WIDTH) <= regs_out((I+1)*REG_WIDTH-1 downto I * REG_WIDTH);
        end if;
      end loop;
    end if;
  end process;
  
  rmem_inst: BusReadSlaveMock
  generic map (
    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,
    BUS_LEN_WIDTH               => BUS_LEN_WIDTH,
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
    SEED                        => 1337,
    RANDOM_REQUEST_TIMING       => false,
    RANDOM_RESPONSE_TIMING      => false,
    SREC_FILE                   => "filter.srec"
  )
  port map (
    clk                         => bus_clk,
    reset                       => bus_reset,
    rreq_valid                  => bus_rreq_valid,
    rreq_ready                  => bus_rreq_ready,
    rreq_addr                   => bus_rreq_addr,
    rreq_len                    => bus_rreq_len,
    rdat_valid                  => bus_rdat_valid,
    rdat_ready                  => bus_rdat_ready,
    rdat_data                   => bus_rdat_data,
    rdat_last                   => bus_rdat_last
  );
  
  wmem_inst: BusWriteSlaveMock
  generic map (
    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,
    BUS_LEN_WIDTH               => BUS_LEN_WIDTH,
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
    BUS_STROBE_WIDTH            => BUS_STROBE_WIDTH,
    SEED                        => 1337,
    RANDOM_REQUEST_TIMING       => false,
    RANDOM_RESPONSE_TIMING      => false,
    SREC_FILE                   => "filter_out.srec"
  )
  port map (
    clk                         => bus_clk,
    reset                       => bus_reset,
    wreq_valid                  => bus_wreq_valid,
    wreq_ready                  => bus_wreq_ready,
    wreq_addr                   => bus_wreq_addr,
    wreq_len                    => bus_wreq_len,
    wdat_valid                  => bus_wdat_valid,
    wdat_ready                  => bus_wdat_ready,
    wdat_data                   => bus_wdat_data,
    wdat_strobe                 => bus_wdat_strobe,
    wdat_last                   => bus_wdat_last
  );


  -----------------------------------------------------------------------------
  -- Fletcher generated wrapper
  -----------------------------------------------------------------------------
  filter_wrapper_inst : filter_wrapper
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_STROBE_WIDTH          => BUS_STROBE_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      NUM_ARROW_BUFFERS         => NUM_ARROW_BUFFERS,
      NUM_REGS                  => NUM_REGS,
      NUM_USER_REGS             => NUM_USER_REGS,
      REG_WIDTH                 => REG_WIDTH,
      TAG_WIDTH                 => TAG_WIDTH
    )
    port map (
      acc_clk                   => acc_clk,
      acc_reset                 => acc_reset,
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      mst_rreq_valid            => bus_rreq_valid,
      mst_rreq_ready            => bus_rreq_ready,
      mst_rreq_addr             => bus_rreq_addr,
      mst_rreq_len              => bus_rreq_len,
      mst_rdat_valid            => bus_rdat_valid,
      mst_rdat_ready            => bus_rdat_ready,
      mst_rdat_data             => bus_rdat_data,
      mst_rdat_last             => bus_rdat_last,
      mst_wreq_valid            => bus_wreq_valid,
      mst_wreq_ready            => bus_wreq_ready,
      mst_wreq_addr             => bus_wreq_addr,
      mst_wreq_len              => bus_wreq_len,
      mst_wdat_valid            => bus_wdat_valid,
      mst_wdat_ready            => bus_wdat_ready,
      mst_wdat_data             => bus_wdat_data,
      mst_wdat_strobe           => bus_wdat_strobe,
      mst_wdat_last             => bus_wdat_last,
      regs_in                   => regs_in,
      regs_out                  => regs_out,
      regs_out_en               => regs_out_en
    );

end architecture;

