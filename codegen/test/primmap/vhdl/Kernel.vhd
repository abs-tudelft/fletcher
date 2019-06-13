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
use work.Axi_pkg.all;
use work.UtilStr_pkg.all;

entity Kernel is
  generic (
    BUS_ADDR_WIDTH : integer := 64
  );
  port (
    kcd_clk                       : in  std_logic;
    kcd_reset                     : in  std_logic;
    mmio_awvalid                  : in  std_logic;
    mmio_awready                  : out std_logic;
    mmio_awaddr                   : in  std_logic_vector(31 downto 0);
    mmio_wvalid                   : in  std_logic;
    mmio_wready                   : out std_logic;
    mmio_wdata                    : in  std_logic_vector(31 downto 0);
    mmio_wstrb                    : in  std_logic_vector(3 downto 0);
    mmio_bvalid                   : out std_logic;
    mmio_bready                   : in  std_logic;
    mmio_bresp                    : out std_logic_vector(1 downto 0);
    mmio_arvalid                  : in  std_logic;
    mmio_arready                  : out std_logic;
    mmio_araddr                   : in  std_logic_vector(31 downto 0);
    mmio_rvalid                   : out std_logic;
    mmio_rready                   : in  std_logic;
    mmio_rdata                    : out std_logic_vector(31 downto 0);
    mmio_rresp                    : out std_logic_vector(1 downto 0);
    PrimRead_number_valid         : in  std_logic;
    PrimRead_number_ready         : out std_logic;
    PrimRead_number_dvalid        : in  std_logic;
    PrimRead_number_last          : in  std_logic;
    PrimRead_number               : in  std_logic_vector(7 downto 0);
    PrimRead_number_cmd_valid     : out std_logic;
    PrimRead_number_cmd_ready     : in  std_logic;
    PrimRead_number_cmd_firstIdx  : out std_logic_vector(31 downto 0);
    PrimRead_number_cmd_lastidx   : out std_logic_vector(31 downto 0);
    PrimRead_number_cmd_ctrl      : out std_logic_vector(1*bus_addr_width-1 downto 0);
    PrimRead_number_cmd_tag       : out std_logic_vector(0 downto 0);
    PrimRead_number_unl_valid     : in  std_logic;
    PrimRead_number_unl_ready     : out std_logic;
    PrimRead_number_unl_tag       : in  std_logic_vector(0 downto 0);
    PrimWrite_number_valid        : out std_logic;
    PrimWrite_number_ready        : in  std_logic;
    PrimWrite_number_dvalid       : out std_logic;
    PrimWrite_number_last         : out std_logic;
    PrimWrite_number              : out std_logic_vector(7 downto 0);
    PrimWrite_number_cmd_valid    : out std_logic;
    PrimWrite_number_cmd_ready    : in  std_logic;
    PrimWrite_number_cmd_firstIdx : out std_logic_vector(31 downto 0);
    PrimWrite_number_cmd_lastidx  : out std_logic_vector(31 downto 0);
    PrimWrite_number_cmd_ctrl     : out std_logic_vector(1*bus_addr_width-1 downto 0);
    PrimWrite_number_cmd_tag      : out std_logic_vector(0 downto 0);
    PrimWrite_number_unl_valid    : in  std_logic;
    PrimWrite_number_unl_ready    : out std_logic;
    PrimWrite_number_unl_tag      : in  std_logic_vector(0 downto 0)
  );
end entity;

architecture Implementation of Kernel is
  -- Registers used:
  constant REG_CONTROL                 : natural :=  0;
  constant REG_STATUS                  : natural :=  1;
  constant REG_RETURN0                 : natural :=  2;
  constant REG_RETURN1                 : natural :=  3;
  constant REG_PRIMREAD_FIRSTIDX       : natural :=  4;
  constant REG_PRIMREAD_LASTIDX        : natural :=  5;
  constant REG_PRIMWRITE_FIRSTIDX      : natural :=  6;
  constant REG_PRIMWRITE_LASTIDX       : natural :=  7;
  constant REG_PRIMREAD_NUMBER_BUF_LO  : natural :=  8;
  constant REG_PRIMREAD_NUMBER_BUF_HI  : natural :=  9;
  constant REG_PRIMWRITE_NUMBER_BUF_LO : natural := 10;
  constant REG_PRIMWRITE_NUMBER_BUF_HI : natural := 11;

  constant REG_WIDTH            : natural := 32;
  constant NUM_REGS             : natural := 12;
  constant MAX_STR_LEN          : natural := 128;

  type reg_array_t is array(natural range <>) of std_logic_vector(31 downto 0);
  signal rreg_concat            : std_logic_vector(NUM_REGS*32-1 downto 0);
  signal rreg_array             : reg_array_t(0 to NUM_REGS-1);
  signal rreg_en                : std_logic_vector(NUM_REGS-1 downto 0);
  
  signal wreg_array             : reg_array_t(0 to NUM_REGS-1);
  signal wreg_concat            : std_logic_vector(NUM_REGS*32-1 downto 0);

  signal stat_done              : std_logic;
  signal stat_busy              : std_logic;
  signal stat_idle              : std_logic;
  signal ctrl_reset             : std_logic;
  signal ctrl_stop              : std_logic;
  signal ctrl_start             : std_logic;
begin
  -- Instantiate the AXI mmio component to communicate with host more easily 
  -- through registers.
  axi_mmio_inst : AxiMmio
    generic map (
      BUS_ADDR_WIDTH     => 32,
      BUS_DATA_WIDTH     => 32,
      NUM_REGS           => NUM_REGS,
      REG_CONFIG         => "WRRRWWWWWWWW",
      SLV_R_SLICE_DEPTH  => 0,
      SLV_W_SLICE_DEPTH  => 0
    )
    port map (
      clk                => kcd_clk,
      reset_n            => not(kcd_reset),
      s_axi_awvalid      => mmio_awvalid,
      s_axi_awready      => mmio_awready,
      s_axi_awaddr       => mmio_awaddr,
      s_axi_wvalid       => mmio_wvalid,
      s_axi_wready       => mmio_wready,
      s_axi_wdata        => mmio_wdata,
      s_axi_wstrb        => mmio_wstrb,
      s_axi_bvalid       => mmio_bvalid,
      s_axi_bready       => mmio_bready,
      s_axi_bresp        => mmio_bresp,
      s_axi_arvalid      => mmio_arvalid,
      s_axi_arready      => mmio_arready,
      s_axi_araddr       => mmio_araddr,
      s_axi_rvalid       => mmio_rvalid,
      s_axi_rready       => mmio_rready,
      s_axi_rdata        => mmio_rdata,
      s_axi_rresp        => mmio_rresp,
      regs_out           => wreg_concat,
      regs_in            => rreg_concat,
      regs_in_en         => rreg_en
    );

  -- Turn signals into something more readable
  write_regs_unconcat: for I in 0 to NUM_REGS-1 generate
    wreg_array(I) <= wreg_concat((I+1)*32-1 downto I*32);
  end generate;
  read_regs_concat: for I in 0 to NUM_REGS-1 generate
    rreg_concat((I+1)*32-1 downto I*32) <= rreg_array(I);
  end generate;

  -- Always enable read registers
  rreg_array(REG_STATUS) <= (0 => stat_idle, 1 => stat_busy, 2 => stat_done, others => '0');
  rreg_en <= (REG_STATUS => '1', REG_RETURN0 => '1', REG_RETURN1 => '1', others => '0');
  
  -- We don't use the return registers for this kernel. Put some random data.
  rreg_array(REG_RETURN0) <= X"42001337";
  rreg_array(REG_RETURN1) <= X"FEEDCAFE";
  
  -- Connect the control bits  
  ctrl_start <= wreg_array(REG_CONTROL)(0);
  ctrl_stop  <= wreg_array(REG_CONTROL)(1);
  ctrl_reset <= wreg_array(REG_CONTROL)(2);
  
  process is
    variable idx : natural := 0;
    variable number_read    : signed(7 downto 0);
    variable number_written : signed(7 downto 0);
  begin
    -- Initial outputs
    stat_busy <= '0';
    stat_done <= '0';
    stat_idle <= '0';
    
    PrimRead_number_cmd_valid <= '0';
    PrimWrite_number_cmd_valid <= '0';
    
    PrimRead_number_ready <= '0';
    PrimWrite_number_valid <= '0';
    PrimWrite_number_last  <= '0';
    
    -- Wait for reset to go low and start to go high.
    loop
      wait until rising_edge(kcd_clk);
      exit when ctrl_reset = '0' and ctrl_start = '1';
    end loop;
    
    stat_busy <= '1';
        
    -- Issue the command
    PrimRead_number_cmd_firstIdx  <= wreg_array(REG_PRIMREAD_FIRSTIDX);
    PrimRead_number_cmd_lastIdx   <= wreg_array(REG_PRIMREAD_LASTIDX);
    PrimRead_number_cmd_ctrl      <= wreg_array(REG_PRIMREAD_NUMBER_BUF_HI) & wreg_array(REG_PRIMREAD_NUMBER_BUF_LO);
    PrimRead_number_cmd_valid     <= '1';

    -- Wait for read command to be accepted.
    loop
      wait until rising_edge(kcd_clk);
      exit when PrimRead_number_cmd_ready = '1';
    end loop;
    
    PrimRead_number_cmd_valid <= '0';    

    PrimWrite_number_cmd_firstIdx  <= wreg_array(REG_PRIMREAD_FIRSTIDX);
    PrimWrite_number_cmd_lastIdx   <= wreg_array(REG_PRIMREAD_LASTIDX);
    PrimWrite_number_cmd_ctrl      <= wreg_array(REG_PRIMREAD_NUMBER_BUF_HI) & wreg_array(REG_PRIMREAD_NUMBER_BUF_LO);
    PrimWrite_number_cmd_valid     <= '1';
    
    -- Wait for write command to be accepted.
    loop
      wait until rising_edge(kcd_clk);
      exit when PrimWrite_number_cmd_ready = '1';
    end loop;
    PrimWrite_number_cmd_valid <= '0';
    
    -- Receive the primitives
    loop 
      PrimRead_number_ready <= '1';
      loop
        wait until rising_edge(kcd_clk);
        exit when PrimRead_number_valid = '1';
      end loop;
      PrimRead_number_ready <= '0';
      
      -- Convert to signed integer
      number_read := signed(PrimRead_number);
      
      -- Take the absolute value. ABS is awesome.
      number_written := abs(number_read);
      
      -- Put the absolute value on the output.
      PrimWrite_number <= std_logic_vector(number_written);
      
      -- Check if this is the last primitive
      if (idx = 3) then
        PrimWrite_number_last <= '1';
      end if;
      
      -- Validate the input and wait for handshake
      PrimWrite_number_valid <= '1';
      loop
        wait until rising_edge(kcd_clk);
        exit when PrimWrite_number_ready = '1';
      end loop;
      
      println("Read number: " & sgnToDec(number_read) & ". Wrote number " & sgnToDec(number_written));
      
      PrimWrite_number_valid <= '0';
      
      idx := idx + 1;
      exit when idx = 4;
    end loop;
        
    -- Wait a few extra cycles ... 
    -- (normally you should use unlock stream for this)
    for I in 0 to 128 loop
        wait until rising_edge(kcd_clk);
    end loop;
    
    -- Signal done to the usercore controller
    stat_busy <= '0';
    stat_done <= '1';
    wait;
  end process;
end Implementation;
