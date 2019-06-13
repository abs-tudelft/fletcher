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
    rreq_valid                  : out std_logic;
    rreq_ready                  : in  std_logic;
    rreq_addr                   : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    rreq_len                    : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    rdat_valid                  : in  std_logic;
    rdat_ready                  : out std_logic;
    rdat_data                   : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    rdat_last                   : in  std_logic

  );
end BusReadMasterMock;

architecture Behavioral of BusReadMasterMock is
begin

  -- Request generator.
  req_proc: process is
    variable len    : natural;
    variable addr   : unsigned(BUS_ADDR_WIDTH-1 downto 0);
    variable seed1  : positive := SEED + 27183;
    variable seed2  : positive := 1;
    variable rand   : real;
  begin
    state: loop

      -- Reset state.
      addr := (others => '0');
      rreq_valid <= '0';
      rreq_addr <= (others => '0');
      rreq_len <= (others => '0');

      -- Wait for a clock cycle where we are not under reset.
      wait until rising_edge(clk);
      exit state when reset = '1';

      loop

        -- Delay randomly before generating the next request.
        loop
          uniform(seed1, seed2, rand);
          exit when rand < 0.3;
          wait until rising_edge(clk);
          exit state when reset = '1';
        end loop;

        -- Randomly generate burst length.
        uniform(seed1, seed2, rand);
        len := integer(rand * 10.0) + 1;

        -- Output request.
        rreq_valid <= '1';
        rreq_addr <= std_logic_vector(addr);
        rreq_len <= std_logic_vector(to_unsigned(len, BUS_LEN_WIDTH));

        -- Wait for ready.
        loop
          wait until rising_edge(clk);
          exit state when reset = '1';
          exit when rreq_ready = '1';
        end loop;
        rreq_valid <= '0';

        -- Increment address.
        addr := addr + len * (BUS_DATA_WIDTH/8);

      end loop;
    end loop;
  end process;

  -- Response consumer and checker.
  resp_proc: process is
    variable data   : unsigned(BUS_DATA_WIDTH-1 downto 0);
    variable seed1  : positive := SEED + 27183;
    variable seed2  : positive := 1;
    variable rand   : real;
  begin
    data := (others => '0');
    rdat_ready <= '0';
    state: loop

      -- Consumers are allowed to wait for valid before asserting ready, but
      -- they can also assert ready earlier. In the latter case, ready can
      -- toggle whenever the consumer wants. Model both kinds of interface
      -- styles with a 50/50 chance to test both,
      uniform(seed1, seed2, rand);
      if rand < 0.5 then
        while rdat_valid /= '1' loop
          wait until rising_edge(clk);
          exit state when reset = '1';
        end loop;
      end if;

      -- Delay randomly before accepting the transfer.
      loop
        uniform(seed1, seed2, rand);
        if rand < 0.3 then
          rdat_ready <= '1';
          wait until rising_edge(clk);
          exit state when reset = '1';
          exit when rdat_valid = '1';
        else
          rdat_ready <= '0';
          wait until rising_edge(clk);
          exit state when reset = '1';
        end if;
      end loop;

      -- Accept and check the transfer.
      assert rdat_data = std_logic_vector(data) report "Stream data integrity check failed" severity failure;
      data := data + (BUS_DATA_WIDTH / 8);
      rdat_ready <= '0';

    end loop;
  end process;

end Behavioral;

