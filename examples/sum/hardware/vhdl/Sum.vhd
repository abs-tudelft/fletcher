-- Copyright 2019 Delft University of Technology
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

-- This components implements the sum example kernel.
entity Sum is
  generic (
    BUS_ADDR_WIDTH : integer := 64
  );
  port (
    kcd_clk                          : in  std_logic;
    kcd_reset                        : in  std_logic;
    mmio_awvalid                     : in  std_logic;
    mmio_awready                     : out std_logic;
    mmio_awaddr                      : in  std_logic_vector(31 downto 0);
    mmio_wvalid                      : in  std_logic;
    mmio_wready                      : out std_logic;
    mmio_wdata                       : in  std_logic_vector(31 downto 0);
    mmio_wstrb                       : in  std_logic_vector(3 downto 0);
    mmio_bvalid                      : out std_logic;
    mmio_bready                      : in  std_logic;
    mmio_bresp                       : out std_logic_vector(1 downto 0);
    mmio_arvalid                     : in  std_logic;
    mmio_arready                     : out std_logic;
    mmio_araddr                      : in  std_logic_vector(31 downto 0);
    mmio_rvalid                      : out std_logic;
    mmio_rready                      : in  std_logic;
    mmio_rdata                       : out std_logic_vector(31 downto 0);
    mmio_rresp                       : out std_logic_vector(1 downto 0);
    ExampleBatch_number_valid        : in  std_logic;
    ExampleBatch_number_ready        : out std_logic;
    ExampleBatch_number_dvalid       : in  std_logic;
    ExampleBatch_number_last         : in  std_logic;
    ExampleBatch_number              : in  std_logic_vector(63 downto 0);
    ExampleBatch_number_cmd_valid    : out std_logic;
    ExampleBatch_number_cmd_ready    : in  std_logic;
    ExampleBatch_number_cmd_firstIdx : out std_logic_vector(31 downto 0);
    ExampleBatch_number_cmd_lastidx  : out std_logic_vector(31 downto 0);
    ExampleBatch_number_cmd_ctrl     : out std_logic_vector(1*bus_addr_width-1 downto 0);
    ExampleBatch_number_cmd_tag      : out std_logic_vector(0 downto 0);
    ExampleBatch_number_unl_valid    : in  std_logic;
    ExampleBatch_number_unl_ready    : out std_logic;
    ExampleBatch_number_unl_tag      : in  std_logic_vector(0 downto 0)
  );
end entity;
architecture Implementation of Sum is
  -- Registers used:
  constant REG_CONTROL          : natural :=  0;
  constant REG_STATUS           : natural :=  1;
  constant REG_RETURN0          : natural :=  2;
  constant REG_RETURN1          : natural :=  3;
  constant REG_NUMBER_FIRSTIDX  : natural :=  4;
  constant REG_NUMBER_LASTIDX   : natural :=  5;
  constant REG_NUMBER_VALUES_LO : natural :=  6;
  constant REG_NUMBER_VALUES_HI : natural :=  7;

  constant REG_WIDTH            : natural :=  32;
  constant NUM_REGS             : natural :=   8;

  type reg_array_t is array(natural range <>) of std_logic_vector(31 downto 0);
  
  -- Register signals, where rreg is read reg and wreg write reg as seen from 
  -- host side.
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
  
  type haf_state_t IS (RESET, WAITING, SETUP, RUNNING, DONE);
	signal state, state_next : haf_state_t;

  -- Accumulate the total sum here
  signal accumulator, accumulator_next : signed(2*REG_WIDTH-1 downto 0);
  
  signal kcd_reset_n            : std_logic;
  
begin
  kcd_reset_n <= not(kcd_reset);
  -- Instantiate the AXI mmio component to communicate with host more easily 
  -- through registers.
  axi_mmio_inst : AxiMmio
    generic map (
      BUS_ADDR_WIDTH     => 32,
      BUS_DATA_WIDTH     => 32,
      NUM_REGS           => NUM_REGS,
      REG_CONFIG         => "WRRRWWWW",
      SLV_R_SLICE_DEPTH  => 0,
      SLV_W_SLICE_DEPTH  => 0
    )
    port map (
      clk                => kcd_clk,
      reset_n            => kcd_reset_n,
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
    
  -- Connect the control bits  
  ctrl_start <= wreg_array(REG_CONTROL)(0);
  ctrl_stop  <= wreg_array(REG_CONTROL)(1);
  ctrl_reset <= wreg_array(REG_CONTROL)(2);
  
  ------------------------------------------------------------------------------
  -- Sum implementation
  ------------------------------------------------------------------------------
  
  -- Sum output is the accumulator value
  rreg_array(REG_RETURN0) <= std_logic_vector(accumulator(1*REG_WIDTH-1 downto 0*REG_WIDTH));
  rreg_array(REG_RETURN1) <= std_logic_vector(accumulator(2*REG_WIDTH-1 downto 1*REG_WIDTH));

  -- Provide base address to ArrayReader
  ExampleBatch_number_cmd_ctrl <= wreg_array(REG_NUMBER_VALUES_HI) 
                                & wreg_array(REG_NUMBER_VALUES_LO);

  -- Set the first and last index on our array
  ExampleBatch_number_cmd_firstIdx <= wreg_array(REG_NUMBER_FIRSTIDX);
  ExampleBatch_number_cmd_lastIdx  <= wreg_array(REG_NUMBER_LASTIDX);

  logic_p: process (
    -- State
    state, 
    -- Control signals
    ctrl_start, ctrl_stop, ctrl_reset, 
    -- Command stream
    ExampleBatch_number_cmd_ready, 
    -- Data stream
    ExampleBatch_number, ExampleBatch_number_valid, ExampleBatch_number_last, ExampleBatch_number_dvalid,
    -- Unlock stream
    ExampleBatch_number_unl_valid,
    -- Internal
    accumulator
  ) is 
  begin
    
    -- Default values:
    
    -- No command to "number" ArrayReader
    ExampleBatch_number_cmd_valid <= '0';
    -- Do not accept values from the "number" ArrayReader
    ExampleBatch_number_unl_ready <= '0';
    -- Retain accumulator value
    accumulator_next <= accumulator;
    -- Stay in same state
    state_next <= state;

    -- States:
    case state is
      when RESET =>
        stat_done <= '0';
        stat_busy <= '0';
        stat_idle <= '0';
        state_next <= WAITING;
        -- Start sum at 0
        accumulator_next <= (others => '0');

      when WAITING =>
        stat_done <= '0';
        stat_busy <= '0';
        stat_idle <= '1';
        -- Wait for start signal from UserCore (initiated by software)
        if ctrl_start = '1' then
          state_next <= SETUP;
        end if;

      when SETUP =>
        stat_done <= '0';
        stat_busy <= '1';
        stat_idle <= '0';
        -- Send address and row indices to the ArrayReader
        ExampleBatch_number_cmd_valid <= '1';
        if ExampleBatch_number_cmd_ready = '1' then
          -- ArrayReader has received the command
          state_next <= RUNNING;
        end if;

      when RUNNING =>
        stat_done <= '0';
        stat_busy <= '1';
        stat_idle <= '0';
        -- Always ready to accept input
        ExampleBatch_number_ready <= '1';
        if ExampleBatch_number_valid = '1' then
          -- Sum the record to the accumulator
          accumulator_next <= accumulator + signed(ExampleBatch_number);
          -- Wait for last element from ArrayReader
          if ExampleBatch_number_last = '1' then
            state_next <= DONE;
          end if;
        end if;

      when DONE =>
        stat_done <= '1';
        stat_busy <= '0';
        stat_idle <= '1';

      when others =>
        stat_done <= '0';
        stat_busy <= '0';
        stat_idle <= '0';
    end case;
  end process;


  state_p: process (kcd_clk)
  begin
    -- Control state machine
    if rising_edge(kcd_clk) then
      if kcd_reset = '1' or ctrl_reset = '1' then
        state <= RESET;
        accumulator <= (others => '0');
      else
        state <= state_next;
        accumulator <= accumulator_next;
      end if;
    end if;
  end process;
  
end architecture;
