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

-- This simulation-only unit is a mockup of a bus master. It requests
-- consecutive addresses with varying burst lengths, and verifies that it
-- receives the requested addresses cast to data words (as BusSlaveMock returns
-- them).

entity BusReadMasterMock is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Random seed. This should be different for every instantiation.
    SEED                        : positive

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Bus interface.
    req_valid                   : out std_logic;
    req_ready                   : in  std_logic;
    req_addr                    : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    req_len                     : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    resp_valid                  : in  std_logic;
    resp_ready                  : out std_logic;
    resp_data                   : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    resp_last                   : in  std_logic

  );
end BusReadMasterMock;

architecture Behavioral of BusReadMasterMock is

  signal req_prod_valid         : std_logic;
  signal req_prod_ready         : std_logic;

  signal req_int_valid          : std_logic;
  signal req_int_ready          : std_logic;

  signal resp_monitor           : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

begin

  -- Request generator.
  process is
    variable len    : natural;
    variable addr   : unsigned(BUS_ADDR_WIDTH-1 downto 0);
    variable seed1  : positive := SEED + 27183;
    variable seed2  : positive := 1;
    variable rand   : real;
  begin
    state: loop

      -- Reset state.
      addr := (others => '0');
      req_int_valid <= '0';
      req_addr <= (others => '0');
      req_len <= (others => '0');

      -- Wait for a clock cycle where we are not under reset.
      wait until rising_edge(clk);
      exit state when reset = '1';

      loop

        -- Randomly generate burst length.
        uniform(seed1, seed2, rand);
        len := integer(rand * 10.0) + 1;

        -- Output request.
        req_int_valid <= '1';
        req_addr <= std_logic_vector(addr);
        req_len <= std_logic_vector(to_unsigned(len, BUS_LEN_WIDTH));

        -- Wait for ready.
        loop
          wait until rising_edge(clk);
          exit state when reset = '1';
          exit when req_int_ready = '1';
        end loop;

        -- Increment address.
        addr := addr + len * (BUS_DATA_WIDTH/8);

      end loop;
    end loop;
  end process;

  -- Request producer and synchronizer. These two units randomize the rate at
  -- which requests are generated.
  producer_inst: StreamTbProd
    generic map (
      SEED                      => SEED
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      out_valid                 => req_prod_valid,
      out_ready                 => req_prod_ready
    );

  producer_sync: StreamSync
    generic map (
      NUM_INPUTS                => 2,
      NUM_OUTPUTS               => 1
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid(1)               => req_prod_valid,
      in_valid(0)               => req_int_valid,
      in_ready(1)               => req_prod_ready,
      in_ready(0)               => req_int_ready,
      out_valid(0)              => req_valid,
      out_ready(0)              => req_ready
    );

  -- Response consumer. Randomizes the rate at which responses are consumed.
  consumer_inst: StreamTbCons
    generic map (
      SEED                      => SEED + 31415,
      DATA_WIDTH                => BUS_DATA_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => resp_valid,
      in_ready                  => resp_ready,
      in_data                   => resp_data,
      monitor                   => resp_monitor
    );

  process is
    variable data               : unsigned(BUS_DATA_WIDTH-1 downto 0);
  begin
    data := (others => '0');
    loop
      wait until rising_edge(clk);
      exit when reset = '1';
      next when resp_monitor(0) = 'Z';

      assert resp_monitor = std_logic_vector(data) report "Stream data integrity check failed" severity failure;
      data := data + (BUS_DATA_WIDTH / 8);

    end loop;
  end process;

end Behavioral;

