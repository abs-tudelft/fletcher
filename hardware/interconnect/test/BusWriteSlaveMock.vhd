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
use work.Stream_pkg.all;
use work.Interconnect_pkg.all;
use work.UtilMem64_pkg.all;
use work.UtilStr_pkg.all;

-- This simulation-only unit is a mockup of a bus slave that can either write 
-- to an S-record file, or simply accept and print the written data on stdout.
-- The handshake signals can be randomized.

entity BusWriteSlaveMock is
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
    RANDOM_REQUEST_TIMING       : boolean := true;

    -- Whether to randomize the request stream handshake timing.
    RANDOM_RESPONSE_TIMING      : boolean := true;

    -- S-record file to dump writes. If not specified, the unit dumps the 
    -- writes on stdout
    SREC_FILE                   : string := ""

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Bus interface.
    wreq_valid                  : in  std_logic;
    wreq_ready                  : out std_logic;
    wreq_addr                   : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    wreq_len                    : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    wreq_last                   : in  std_logic;
    wdat_valid                  : in  std_logic;
    wdat_ready                  : out std_logic;
    wdat_data                   : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    wdat_strobe                 : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
    wdat_last                   : in  std_logic;
    wrep_valid                  : out std_logic;
    wrep_ready                  : in  std_logic;
    wrep_ok                     : out std_logic

  );
end BusWriteSlaveMock;

architecture Behavioral of BusWriteSlaveMock is

  signal wreq_cons_valid        : std_logic;
  signal wreq_cons_ready        : std_logic;

  signal wreq_int_valid         : std_logic;
  signal wreq_int_ready         : std_logic;

  signal wdat_prod_valid        : std_logic;
  signal wdat_prod_ready        : std_logic;

  signal wdat_int_valid         : std_logic;
  signal wdat_int_ready         : std_logic;

begin

  -- Request handler. First accepts and ready's a command, then outputs the a
  -- response burst as fast as possible.
  process is
    variable len    : natural;
    variable addr   : unsigned(63 downto 0);
    variable data   : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    variable mem    : mem_state_type;
  begin
    if SREC_FILE /= "" then
      mem_clear(mem);
    end if;

    state: loop

      -- Reset state.
      wreq_ready <= '0';

      -- Wait for request valid.
      loop
        wait until rising_edge(clk);
        exit state when reset = '1';
        exit when wreq_valid = '1';
      end loop;

      addr := resize(unsigned(wreq_addr), 64);
      len := to_integer(unsigned(wreq_len));

      -- Accept the request.
      wreq_ready <= '1';
      wait until rising_edge(clk);
      exit state when reset = '1';
      wreq_ready <= '0';

      for i in 0 to len-1 loop

        -- Accept the incoming data
        wdat_ready <= '1';
        
        -- Wait for response ready.
        loop
          wait until rising_edge(clk);
          exit state when reset = '1';
          exit when wdat_valid = '1';
        end loop;
        
        -- Print or dump the data to an SREC file
        if (SREC_FILE = "") then
          println("Write > " & unsToHexNo0x(addr) & " > " & slvToHexNo0x(wdat_data));
        else
          mem_write(mem, std_logic_vector(addr), wdat_data);
          mem_dumpSRec(mem, SREC_FILE);
        end if;
        
        -- Check the last signal
        if i = len-1 then
          assert wdat_last = '1'
            report "Last was not asserted."
            severity failure;
        end if;

        addr := addr + (BUS_DATA_WIDTH / 8);

      end loop;
      
      -- Stop accepting data
      wdat_ready <= '0';
      
      -- Send response
      wrep_valid <= '1';
      wrep_ok <= '1';
      
      -- Wait for response acknowledgement
      loop
        wait until rising_edge(clk);
        exit state when reset = '1';
        exit when wrep_ready = '1';
      end loop;
      
      -- Stop sending response
      wrep_valid <= '0';
      
    end loop;
  end process;

end Behavioral;

