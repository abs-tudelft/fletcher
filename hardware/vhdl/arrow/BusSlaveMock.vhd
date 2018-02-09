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
use work.Streams.all;
use work.Utils.all;
use work.Memory.all;

-- This simulation-only unit is a mockup of a bus slave that can either
-- respond based on an S-record file of the memory contents, or simply returns
-- the requested address as data. The handshake signals can be randomized.

entity BusSlaveMock is
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
    req_valid                   : in  std_logic;
    req_ready                   : out std_logic;
    req_addr                    : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    req_len                     : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    resp_valid                  : out std_logic;
    resp_ready                  : in  std_logic;
    resp_data                   : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    resp_last                   : out std_logic

  );
end BusSlaveMock;

architecture Behavioral of BusSlaveMock is

  signal req_cons_valid         : std_logic;
  signal req_cons_ready         : std_logic;

  signal req_int_valid          : std_logic;
  signal req_int_ready          : std_logic;

  signal resp_prod_valid        : std_logic;
  signal resp_prod_ready        : std_logic;

  signal resp_int_valid         : std_logic;
  signal resp_int_ready         : std_logic;

begin

  random_request_timing_gen: if RANDOM_REQUEST_TIMING generate
  begin

    -- Request consumer and synchronizer. These two units randomize the rate at
    -- which requests are consumed.
    consumer_sync: StreamSync
      generic map (
        NUM_INPUTS                => 1,
        NUM_OUTPUTS               => 2
      )
      port map (
        clk                       => clk,
        reset                     => reset,
        in_valid(0)               => req_valid,
        in_ready(0)               => req_ready,
        out_valid(1)              => req_cons_valid,
        out_valid(0)              => req_int_valid,
        out_ready(1)              => req_cons_ready,
        out_ready(0)              => req_int_ready
      );

    consumer_inst: StreamTbCons
      generic map (
        SEED                      => SEED
      )
      port map (
        clk                       => clk,
        reset                     => reset,
        in_valid                  => req_cons_valid,
        in_ready                  => req_cons_ready,
        in_data                   => (others => '0')
      );

  end generate;

  fast_request_timing_gen: if not RANDOM_REQUEST_TIMING generate
  begin
    req_int_valid <= req_valid;
    req_ready <= req_int_ready;
  end generate;

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
      mem_loadSRec(mem, SREC_FILE);
    end if;

    state: loop

      -- Reset state.
      req_int_ready <= '0';
      resp_int_valid <= '0';
      resp_data <= (others => '0');
      resp_last <= '0';

      -- Wait for request valid.
      loop
        wait until rising_edge(clk);
        exit state when reset = '1';
        exit when req_int_valid = '1';
      end loop;

      addr := resize(unsigned(req_addr), 64);
      len := to_integer(unsigned(req_len));

      -- Accept the request.
      req_int_ready <= '1';
      wait until rising_edge(clk);
      exit state when reset = '1';
      req_int_ready <= '0';

      for i in 0 to len-1 loop

        -- Figure out what data to respond with.
        if SREC_FILE /= "" then
          mem_read(mem, std_logic_vector(addr), data);
        else
          data := std_logic_vector(resize(addr, BUS_DATA_WIDTH));
        end if;

        -- Assert response.
        resp_int_valid <= '1';
        resp_data <= data;
        if i = len-1 then
          resp_last <= '1';
        else
          resp_last <= '0';
        end if;

        -- Wait for response ready.
        loop
          wait until rising_edge(clk);
          exit state when reset = '1';
          exit when resp_int_ready = '1';
        end loop;

        addr := addr + (BUS_DATA_WIDTH / 8);

      end loop;

    end loop;
  end process;

  random_response_timing_gen: if RANDOM_RESPONSE_TIMING generate
  begin

    -- Response producer and synchronizer. These two units randomize the rate at
    -- which burst beats are generated.
    producer_inst: StreamTbProd
      generic map (
        SEED                      => SEED + 31415
      )
      port map (
        clk                       => clk,
        reset                     => reset,
        out_valid                 => resp_prod_valid,
        out_ready                 => resp_prod_ready
      );

    producer_sync: StreamSync
      generic map (
        NUM_INPUTS                => 2,
        NUM_OUTPUTS               => 1
      )
      port map (
        clk                       => clk,
        reset                     => reset,
        in_valid(1)               => resp_prod_valid,
        in_valid(0)               => resp_int_valid,
        in_ready(1)               => resp_prod_ready,
        in_ready(0)               => resp_int_ready,
        out_valid(0)              => resp_valid,
        out_ready(0)              => resp_ready
      );

  end generate;

  fast_response_timing_gen: if not RANDOM_RESPONSE_TIMING generate
  begin
    resp_valid <= resp_int_valid;
    resp_int_ready <= resp_ready;
  end generate;

end Behavioral;

