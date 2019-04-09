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
use ieee.math_real.all;

library work;
use work.Memory.all;
use work.Utils.all;
use work.Streams.all;
use work.StreamSim.all;
use work.Interconnect.all;
use work.SimUtils.all;

-- This simulation-only unit is a mockup of a bus slave that can either
-- respond based on an S-record file of the memory contents, or simply returns
-- the requested address as data. The handshake signals can be randomized.

entity BusReadSlaveMock is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Random seed. This should be different for every instantiation if
    -- randomized handshake signals are used.
    SEED                        : positive := 1;

    -- Whether to randomize the request stream handshake timing.
    RANDOM_REQUEST_TIMING       : boolean := false;

    -- Whether to randomize the request stream handshake timing.
    RANDOM_RESPONSE_TIMING      : boolean := false;
    
    -- Latency on request channel handshakes, when random response is false.
    REQUEST_LATENCY             : positive := 1;
    
    -- Pipeline depth of the interface
    PIPELINE_DEPTH              : positive := 1;

    -- S-record file to load into memory. If not specified, the unit reponds
    -- with the requested address for each word.
    SREC_FILE                   : string := ""

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Bus interface.
    rreq_valid                  : in  std_logic;
    rreq_ready                  : out std_logic := '0';
    rreq_addr                   : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    rreq_len                    : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    rdat_valid                  : out std_logic := '0';
    rdat_ready                  : in  std_logic;
    rdat_data                   : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    rdat_last                   : out std_logic

  );
end BusReadSlaveMock;

architecture Behavioral of BusReadSlaveMock is
  
  type request_type is record
    addr    : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    len     : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    latency : natural;
  end record;
  
  type req_queue_type is array (0 to PIPELINE_DEPTH-1) of request_type;
  signal reqs         : req_queue_type;
  signal req_idx_out  : natural := 0;
  signal req_idx_in   : natural := 0;
  signal req_flip_in  : boolean := false;
  signal req_flip_out : boolean := false;
  signal req_full     : boolean := false;
  signal req_empty    : boolean := true;

  procedure subtract_latency_cycles(signal reqs : inout req_queue_type) is
  begin
    for I in 0 to PIPELINE_DEPTH-1 loop
      if reqs(I).latency - 1 >= 0 then
        reqs(I).latency <= reqs(I).latency - 1;
      end if;
    end loop;
  end procedure;
  
begin

  req_full <= true when (req_flip_in /= req_flip_out) and (req_idx_in = req_idx_out)
              else false;
              
  req_empty <= true when req_flip_in = req_flip_out  and (req_idx_in = req_idx_out)
              else false;
  
  -- Always accept requests when FIFO is not full
  rreq_ready <= '0' when req_full else '1';
  
  -- Request process
  req_proc : process is
  begin
    state: loop
      -- Wait for request valid and fifo not full
      loop
        exit when rreq_valid = '1' and req_full = false;
        wait until rising_edge(clk);
        subtract_latency_cycles(reqs);
        exit state when reset = '1';
      end loop;
      
      reqs(req_idx_in).addr    <= rreq_addr;
      reqs(req_idx_in).len     <= rreq_len;
      reqs(req_idx_in).latency <= REQUEST_LATENCY-1;
        
      -- Wrap or increment input index
      if req_idx_in + 1 >= PIPELINE_DEPTH then
        req_idx_in <= 0;
        req_flip_in <= not req_flip_in;
      else
        req_idx_in <= req_idx_in + 1;
      end if;
      
      -- Wait one clock cycle
      wait until rising_edge(clk);
      subtract_latency_cycles(reqs);
      exit state when reset = '1';
      
    end loop;
  end process;
  
  -- Response process
  resp_proc : process is
    variable len    : natural;
    variable addr   : unsigned(63 downto 0);
    variable data   : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    variable mem    : mem_state_type;
  begin
    if SREC_FILE /= "" then
      mem_clear(mem);
      mem_loadSRec(mem, SREC_FILE);
    end if;
  
    state: loop
      -- Wait for fifo not empty and latency.
      loop
        exit when req_empty = false and reqs(req_idx_out).latency = 0;
        wait until rising_edge(clk);
        exit state when reset = '1';
      end loop;
      
      len  := to_integer(unsigned(reqs(req_idx_out).len));
      addr := unsigned(reqs(req_idx_out).addr);
      
      -- dumpStdOut("Generating Response. Addr: " & ii(addr) & " length: " & ii(len));
      
      for i in 0 to len-1 loop
        -- Figure out what data to respond with.
        if SREC_FILE /= "" then
          mem_read(mem, std_logic_vector(addr), data);
        else
          data := std_logic_vector(resize(addr, BUS_DATA_WIDTH));
        end if;

        -- Assert response.
        rdat_valid <= '1';
        rdat_data <= data;
        
        if i = len-1 then
          rdat_last <= '1';
          -- Wrap or increment output index
          if req_idx_out + 1 >= PIPELINE_DEPTH then
            req_idx_out <= 0;
            req_flip_out <= not req_flip_out;
          else
            req_idx_out <= req_idx_out + 1;
          end if;
        else
          rdat_last <= '0';
        end if;

        -- Wait for response ready.
        loop
          wait until rising_edge(clk);
          exit state when reset = '1';
          exit when rdat_ready = '1';
        end loop;

        addr := addr + (BUS_DATA_WIDTH / 8);
        
      end loop;
            
      rdat_valid <= '0';
      rdat_last <= '0';

    end loop;
  end process;

end Behavioral;
