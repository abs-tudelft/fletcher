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
use work.Axi.all;

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
    PrimRead_number_data_dvalid   : in  std_logic;
    PrimRead_number_data_last     : in  std_logic;
    PrimRead_number_data_data     : in  std_logic_vector(7 downto 0);
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
    PrimWrite_number_data_dvalid  : out std_logic;
    PrimWrite_number_data_last    : out std_logic;
    PrimWrite_number_data_data    : out std_logic_vector(7 downto 0);
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
  -- Instantiate the AXI mmio component to communicate with host more easily 
  -- through registers.
  axi_mmio_inst : axi_mmio
    generic map (
      BUS_ADDR_WIDTH     => 32,
      BUS_DATA_WIDTH     => 32,
      NUM_REGS           => NUM_REGS,
      REG_CONFIG         => "WRRRWWWWWW",
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
  rreg_array(REG_RETURN1) <= X"FEEDC4F3";
  
  -- Connect the control bits  
  ctrl_start <= wreg_array(REG_CONTROL)(0);
  ctrl_stop  <= wreg_array(REG_CONTROL)(1);
  ctrl_reset <= wreg_array(REG_CONTROL)(2);
  
  process is
    variable idx : natural := 0;
  begin
    -- Initial outputs
    ctrl_busy <= '0';
    ctrl_done <= '0';
    ctrl_idle <= '0';
    
    primread_cmd_valid <= '0';
    primwrite_cmd_valid <= '0';
    
    primread_out_ready <= '0';
    primwrite_in_valid <= '0';
    primwrite_in_last  <= '0';
    
    -- Wait for reset to go low and start to go high.
    loop
      wait until rising_edge(acc_clk);
      exit when ctrl_reset = '0' and ctrl_start = '1';
    end loop;
    
    ctrl_busy <= '1';
        
    -- Issue the commands
    primread_cmd_firstIdx <= (others => '0');
    primread_cmd_lastIdx <= std_logic_vector(to_unsigned(4, INDEX_WIDTH));
    primread_cmd_primread_values_addr <= reg_primread_values_addr;
    primread_cmd_valid <= '1';

    -- Wait for read command to be accepted.
    loop
      wait until rising_edge(acc_clk);
      exit when primread_cmd_ready = '1';
    end loop;
    primread_cmd_valid <= '0';    

    primwrite_cmd_firstIdx <= (others => '0');
    primwrite_cmd_lastIdx <= std_logic_vector(to_unsigned(4, INDEX_WIDTH));
    -- Write to some buffer that should normally be preallocated and passed
    -- through registers
    primwrite_cmd_primwrite_values_addr <= X"0000000000000000";
    primwrite_cmd_valid <= '1';
    
    -- Wait for write command to be accepted.
    loop
      wait until rising_edge(acc_clk);
      exit when primwrite_cmd_ready = '1';
    end loop;
    primwrite_cmd_valid <= '0';
    
    -- Receive the primitives
    loop 
      primread_out_ready <= '1';
      loop
        wait until rising_edge(acc_clk);
        exit when primread_out_valid = '1';
      end loop;
      primread_out_ready <= '0';
      
      -- Add one to the input and put it on the output.
      primwrite_in_data <= std_logic_vector(unsigned(primread_out_data)+1);
      
      -- Check if this is the last primitive
      if (idx = 3) then
        primwrite_in_last <= '1';
      end if;
      
      -- Wait for handshake
      primwrite_in_valid <= '1';
      loop
        wait until rising_edge(acc_clk);
        exit when primwrite_in_ready = '1';
      end loop;
      primwrite_in_valid <= '0';
      
      idx := idx + 1;
      exit when idx = 4;
    end loop;
        
    -- Wait a few extra cycles ... 
    -- (normally you should use unlock stream for this)
    for I in 0 to 128 loop
        wait until rising_edge(acc_clk);
    end loop;
    
    -- Signal done to the usercore controller
    ctrl_busy <= '0';
    ctrl_done <= '1';
    wait;
  end process;
end Behavioral;
