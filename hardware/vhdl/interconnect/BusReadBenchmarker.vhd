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
-- by reporting the sum of the latencies between requests/responses and the
-- total number of cycles of requesting a workload.

entity BusReadBenchmarker is
  generic (
    BUS_ADDR_WIDTH              : natural := 64;
    BUS_DATA_WIDTH              : natural := 512;
    BUS_LEN_WIDTH               : natural := 9;
    BUS_MAX_BURST_LENGTH        : natural := 64;
    BUS_BURST_BOUNDARY          : natural := 4096
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
    reg_burst_length            : in  std_logic_vector(31 downto 0);
    reg_max_bursts              : in  std_logic_vector(31 downto 0);
    reg_base_addr_lo            : in  std_logic_vector(31 downto 0);
    reg_base_addr_hi            : in  std_logic_vector(31 downto 0);
    reg_addr_mask_lo            : in  std_logic_vector(31 downto 0);
    reg_addr_mask_hi            : in  std_logic_vector(31 downto 0);

    -- Result registers
    reg_cycles                  : out std_logic_vector(31 downto 0)
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

  type req_state_type is (IDLE, REQUEST, DONE, ERROR);

  type req_regs_type is record
    -- State machine state
    state                       : req_state_type;
    -- Settings for workload
    base_addr                   : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    addr_mask                   : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    max_bursts                  : unsigned(31 downto 0);
    burst_length                : unsigned(31 downto 0);
    -- Measurements for workload
    cycles                      : unsigned(31 downto 0);
    num_bursts                  : unsigned(31 downto 0);
  end record;

  signal r_req                  : req_regs_type;
  signal d_req                  : req_regs_type;

  signal prng_valid             : std_logic;
  signal prng_ready             : std_logic;
  signal prng_data              : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);

begin

  -- Pseudo random number generator instance
  prng_inst : StreamPseudoRandomGenerator
    generic map (
      DATA_WIDTH  => BUS_ADDR_WIDTH
    )
    port map (
      clk         => bus_clk,
      reset       => bus_reset,
      seed        => slv(resize(u(X"FEEDBEEF00000042"), BUS_ADDR_WIDTH)),
      out_valid   => prng_valid,
      out_ready   => prng_ready,
      out_data    => prng_data
    );

  -- Request state machine sequential part
  req_seq: process(bus_clk) is begin
    if rising_edge(bus_clk) then
      r_req <= d_req;
      if bus_reset = '1' then
        r_req.state <= IDLE;
      end if;
    end if;
  end process;

  -- Request state machine combinatorial part
  req_comb: process(
    r_req,
    bus_rreq_ready,
    reg_control,
    reg_max_bursts,
    reg_burst_length,
    reg_base_addr_lo,
    reg_base_addr_hi
  ) is
    variable v_req : req_regs_type;
  begin
    v_req := r_req;

    bus_rreq_valid <= '0';
    bus_rdat_ready <= '1';
    bus_rreq_len   <= slv(r_req.burst_length(BUS_LEN_WIDTH-1 downto 0));

    prng_ready <= '0';
    
    -- default status
    reg_status <= (others => '0');

    case r_req.state is
    
      when IDLE =>
        reg_status(STATUS_IDLE) <= '1';
      
        -- At the start, clock in all settings
        if reg_control(CONTROL_START) = '1' then
          v_req.state        := REQUEST;
          v_req.cycles       := (others => '0');
          v_req.max_bursts   := unsigned(reg_max_bursts);
          v_req.num_bursts   := unsigned(reg_max_bursts);
          v_req.burst_length := unsigned(reg_burst_length);
          v_req.base_addr    := reg_base_addr_hi & reg_base_addr_lo;
          v_req.addr_mask    := reg_addr_mask_hi & reg_addr_mask_lo;
        end if;
        
      when REQUEST =>
        reg_status(STATUS_BUSY) <= '1';
      
        -- Count all cycles spent on all requests
        v_req.cycles := r_req.cycles + 1;

        -- Generate a valid read request
        bus_rreq_valid <= '1';
        bus_rreq_addr <= slv(u(r_req.base_addr) + u(prng_data and r_req.addr_mask));

        if bus_rreq_ready = '1' then
          prng_ready <= '1';
          v_req.num_bursts := r_req.num_bursts - 1;
          if v_req.num_bursts = 0 then
            v_req.state := DONE;
          end if;
        end if;
        
      when DONE =>
        reg_status(STATUS_DONE) <= '1';
        reg_cycles <= slv(r_req.cycles);

      when ERROR =>
        reg_status(STATUS_ERROR) <= '1';

    end case;
    d_req <= v_req;
  end process;
  
end Behavioral;
