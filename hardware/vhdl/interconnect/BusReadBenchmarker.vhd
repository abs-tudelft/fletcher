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
use work.Utils.all;
use work.SimUtils.all;
use work.Interconnect.all;
use work.Streams.all;

-- This unit benchmarks a memory interface in terms of latency and throughput
-- by reporting the total number of cycles of requesting a workload.

entity BusReadBenchmarker is
  generic (
    BUS_ADDR_WIDTH              : natural := 64;
    BUS_DATA_WIDTH              : natural := 512;
    BUS_LEN_WIDTH               : natural := 9;
    BUS_MAX_BURST_LENGTH        : natural := 64;
    BUS_BURST_BOUNDARY          : natural := 4096;
    PATTERN                     : string := "RANDOM"
  );
  port (
    bus_clk                     : in  std_logic;
    bus_reset                   : in  std_logic;

    bus_rreq_valid              : out std_logic;
    bus_rreq_ready              : in  std_logic;
    bus_rreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_rreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    bus_rdat_valid              : in  std_logic;
    bus_rdat_ready              : out std_logic;
    bus_rdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_rdat_last               : in  std_logic;
    
    -- Control / status registers
    reg_control                 : in  std_logic_vector(31 downto 0);
    reg_status                  : out std_logic_vector(31 downto 0);

    -- Configuration registers
    
    -- Burst length
    reg_burst_length            : in  std_logic_vector(31 downto 0);
    
    -- Maximum number of bursts
    reg_max_bursts              : in  std_logic_vector(31 downto 0);
    
    -- Base addresse
    reg_base_addr_lo            : in  std_logic_vector(31 downto 0);
    reg_base_addr_hi            : in  std_logic_vector(31 downto 0);
    
    -- Address mask
    reg_addr_mask_lo            : in  std_logic_vector(31 downto 0);
    reg_addr_mask_hi            : in  std_logic_vector(31 downto 0);
    
    -- Number of cycles to absorb a word, set 0 to always accept immediately
    reg_cycles_per_word         : in  std_logic_vector(31 downto 0);

    -- Result registers
    reg_cycles                  : out std_logic_vector(31 downto 0);
    reg_checksum                : out std_logic_vector(31 downto 0)
  );
end BusReadBenchmarker;

architecture Behavioral of BusReadBenchmarker is

  constant CONTROL_START        : natural := 0;
  constant CONTROL_STOP         : natural := 1;
  constant CONTROL_RESET        : natural := 2;

  constant STATUS_IDLE          : natural := 0;
  constant STATUS_BUSY          : natural := 1;
  constant STATUS_DONE          : natural := 2;
  constant STATUS_ERROR         : natural := 3;
  
  constant ADDR_SHIFT           : natural := log2ceil(BUS_MAX_BURST_LENGTH * BUS_DATA_WIDTH / 8);

  type state_type is (IDLE, BUSY, DONE, ERROR);

  type regs_type is record
    -- State machine state
    state                       : state_type;
    -- Memory for start bit high
    start                       : std_logic;
    -- Settings for workload
    base_addr                   : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    addr_mask                   : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    max_bursts                  : unsigned(31 downto 0);
    burst_length                : unsigned(31 downto 0);
    -- Current request address
    addr                        : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    -- Accept rate modifier
    accept_cycles               : unsigned(31 downto 0);
    -- Measurements for workload
    cycles                      : unsigned(31 downto 0);
    num_requests                : unsigned(31 downto 0);
    num_responses               : unsigned(31 downto 0);
  end record;

  signal r                      : regs_type;
  signal d                      : regs_type;

  signal prng_valid             : std_logic;
  signal prng_ready             : std_logic;
  signal prng_data              : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);

begin

  -- Pseudo random number generator instance, if pattern is set to random
  random_prng : if PATTERN = "RANDOM" generate
    prng_inst : StreamPseudoRandomGenerator
      generic map (
        DATA_WIDTH  => BUS_ADDR_WIDTH
      )
      port map (
        clk         => bus_clk,
        reset       => bus_reset,
        seed        => slv(resize(u(X"FEEDBEEF13374242"), BUS_ADDR_WIDTH)),
        out_valid   => prng_valid,
        out_ready   => prng_ready,
        out_data    => prng_data
      );
  end generate;

  -- State machine sequential part
  req_seq: process(bus_clk) is begin
    if rising_edge(bus_clk) then
      r <= d;
      if bus_reset = '1' or reg_control(CONTROL_RESET) = '1' then
        r.state <= IDLE;
      end if;
    end if;
  end process;

  -- State machine combinatorial part
  req_comb: process(
    r,
    bus_rreq_ready,
    bus_rdat_valid,
    bus_rdat_last,
    reg_control,
    reg_max_bursts,
    reg_burst_length,
    reg_base_addr_lo,
    reg_base_addr_hi,
    reg_cycles_per_word,
    prng_valid,
    prng_data
  ) is
    variable v : regs_type;
    
    variable rdat_ready_v : std_logic;
  begin
    v := r;
    
    -- Defaults
    bus_rreq_valid <= '0';
    bus_rreq_len   <= slv(r.burst_length(BUS_LEN_WIDTH-1 downto 0));
    prng_ready     <= '0';
    reg_status     <= (others => '0');
    
    rdat_ready_v := '0';
    
    -- States
    case r.state is
    
      when IDLE =>
        reg_status(STATUS_IDLE) <= '1';
      
        -- When start is high, clock in all settings
        if reg_control(CONTROL_START) = '1' then
          v.start         := '1';
          v.cycles        := (others => '0');
          v.max_bursts    := unsigned(reg_max_bursts);
          v.num_requests  := unsigned(reg_max_bursts);
          v.num_responses := unsigned(reg_max_bursts);
          v.burst_length  := unsigned(reg_burst_length);
          v.base_addr     := reg_base_addr_hi & reg_base_addr_lo;
          v.addr_mask     := reg_addr_mask_hi & reg_addr_mask_lo;
          v.addr          := reg_base_addr_hi & reg_base_addr_lo;
          v.accept_cycles := u(reg_cycles_per_word);
        end if;
        
        -- When start goes low after it was high, start the actual benchmark
        if reg_control(CONTROL_START) = '0' and r.start = '1' then
          v.state := BUSY;
          -- Reset the start bit for next time.
          v.start := '1';
        end if;
        
      when BUSY =>
        reg_status(STATUS_BUSY) <= '1';
      
        -- Count all cycles spent on all requests
        v.cycles := r.cycles + 1;

        if r.num_requests /= 0 then
          -- Generate a valid read request
          bus_rreq_valid <= '1';
          
          -- Determine the next address
          if PATTERN = "RANDOM" then
            -- Use PRNG burst address
            bus_rreq_addr <= slv(u(r.base_addr) + u(prng_data and r.addr_mask));
          else
            -- Use sequential burst address
            bus_rreq_addr <= r.addr;
          end if;

          -- If request was handshaked
          if bus_rreq_ready = '1' then
            -- Decrease number of requests left to make
            v.num_requests := r.num_requests - 1;
            
            -- Either grab next PRN or increment the address to the next burst
            if PATTERN = "RANDOM" then
              prng_ready <= '1';            
            else
              v.addr := slv(u(r.addr) + shift_left(r.burst_length, log2ceil(BUS_DATA_WIDTH/8)));
            end if;
          end if;
        end if;
        
        -- If there is valid data on the bus...
        if bus_rdat_valid = '1' then
          if v.accept_cycles - 1 /= 0 then
            v.accept_cycles := v.accept_cycles - 1;
            rdat_ready_v := '0';
          else
            v.accept_cycles := u(reg_cycles_per_word);
            rdat_ready_v := '1';
          end if;
        end if;
                
        -- Keep track of how many responses have been delivered.
        if bus_rdat_valid = '1' and rdat_ready_v = '1' and bus_rdat_last = '1' then
          v.num_responses := r.num_responses - 1;
        end if;
        
        if v.num_responses = 0 then
          v.state := DONE;
        end if;
               
      when DONE =>
        reg_status(STATUS_DONE) <= '1';
        reg_cycles <= slv(r.cycles);
        -- Go to idle on reset.
        if (reg_control(CONTROL_RESET) = '1') then
          v.state := IDLE;
        end if;

      when ERROR =>
        reg_status(STATUS_ERROR) <= '1';

    end case;
    
    bus_rdat_ready <= rdat_ready_v;
    
    d <= v;
  end process;
  
end Behavioral;
