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
    RANDOM_REQUEST_TIMING       : boolean := true;

    -- Whether to randomize the request stream handshake timing.
    RANDOM_RESPONSE_TIMING      : boolean := true;

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
begin

  -- Request handler. First accepts and ready's a command, then outputs the a
  -- response burst as fast as possible.
  process is
    variable len    : natural;
    variable addr   : unsigned(63 downto 0);
    variable data   : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    variable mem    : mem_state_type;
    variable seed1  : positive := SEED;
    variable seed2  : positive := 1;
    variable rand   : real;
  begin
    if SREC_FILE /= "" then
      mem_clear(mem);
      mem_loadSRec(mem, SREC_FILE);
    end if;

    state: loop

      -- Reset state.
      rreq_ready <= '0';
      rdat_valid <= '0';
      rdat_data <= (others => '0');
      rdat_last <= '0';

      -- Delay randomly before accepting the next request, if enabled.
      if RANDOM_REQUEST_TIMING then

        -- Consumers are allowed to wait for valid before asserting ready, but
        -- they can also assert ready earlier. In the latter case, ready can
        -- toggle whenever the consumer wants. Model both kinds of interface
        -- styles with a 50/50 chance to test both,
        uniform(seed1, seed2, rand);
        if rand < 0.5 then
          while rreq_valid /= '1' loop
            wait until rising_edge(clk);
            exit state when reset = '1';
          end loop;
        end if;

        -- Delay randomly before accepting the transfer.
        loop
          uniform(seed1, seed2, rand);
          if rand < 0.3 then
            rreq_ready <= '1';
            wait until rising_edge(clk);
            exit state when reset = '1';
            exit when rreq_valid = '1';
          else
            rreq_ready <= '0';
            wait until rising_edge(clk);
            exit state when reset = '1';
          end if;
        end loop;
        rreq_ready <= '0';

      else

        -- Wait for request valid.
        loop
          wait until rising_edge(clk);
          exit state when reset = '1';
          exit when rreq_valid = '1';
        end loop;

        -- Accept the request.
        rreq_ready <= '1';
        wait until rising_edge(clk);
        exit state when reset = '1';
        rreq_ready <= '0';

      end if;

      addr := resize(unsigned(rreq_addr), 64);
      len := to_integer(unsigned(rreq_len));

      for i in 0 to len-1 loop

        -- Figure out what data to respond with.
        if SREC_FILE /= "" then
          mem_read(mem, std_logic_vector(addr), data);
        else
          data := std_logic_vector(resize(addr, BUS_DATA_WIDTH));
        end if;

        -- Delay randomly before generating the next response, if enabled.
        if RANDOM_RESPONSE_TIMING then
          loop
            uniform(seed1, seed2, rand);
            exit when rand < 0.3;
            wait until rising_edge(clk);
            exit state when reset = '1';
          end loop;
        end if;

        -- Assert response.
        rdat_valid <= '1';
        rdat_data <= data;
        if i = len-1 then
          rdat_last <= '1';
        else
          rdat_last <= '0';
        end if;

        -- Wait for response ready.
        loop
          wait until rising_edge(clk);
          exit state when reset = '1';
          exit when rdat_ready = '1';
        end loop;
        rdat_valid <= '0';

        addr := addr + (BUS_DATA_WIDTH / 8);

      end loop;

    end loop;
  end process;

end Behavioral;
