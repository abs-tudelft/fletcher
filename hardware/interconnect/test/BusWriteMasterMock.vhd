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
-- consecutive addresses with varying burst lengths, and generates a write data
-- stream. BusWriteSlaveMock can verify the write data.

entity BusWriteMasterMock is
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
    wreq_valid                  : out std_logic;
    wreq_ready                  : in  std_logic;
    wreq_addr                   : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    wreq_len                    : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    wreq_last                   : out std_logic;
    wdat_valid                  : out std_logic;
    wdat_ready                  : in  std_logic;
    wdat_data                   : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    wdat_strobe                 : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
    wdat_last                   : out std_logic;
    wrep_valid                  : in  std_logic;
    wrep_ready                  : out std_logic;
    wrep_ok                     : in  std_logic
  );
end BusWriteMasterMock;

architecture Behavioral of BusWriteMasterMock is

  signal wreq_prod_valid         : std_logic;
  signal wreq_prod_ready         : std_logic;

  signal wreq_int_valid          : std_logic;
  signal wreq_int_ready          : std_logic;
  
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
      wreq_int_valid <= '0';
      wreq_addr <= (others => '0');
      wreq_len <= (others => '0');
      wreq_last <= '0';
      wreq_valid <= '0';
      wdat_valid <= '0';

      -- Wait for a clock cycle where we are not under reset.
      wait until rising_edge(clk);
      exit state when reset = '1';

      loop

        -- Generate random burst length.
        uniform(seed1, seed2, rand);
        len := integer(rand * 10.0) + 1;

        -- Output request.
        wreq_addr <= std_logic_vector(addr);
        wreq_len <= std_logic_vector(to_unsigned(len, BUS_LEN_WIDTH));
        wreq_valid <= '1';

        -- Wait for ready.
        loop
          wait until rising_edge(clk);
          exit state when reset = '1';
          exit when wreq_ready = '1';
        end loop;
        
        wreq_valid <= '0';
        
        -- Generate len words
        for i in 0 to len-1 loop
        
          -- Generate data
          wdat_valid <= '1';
          wdat_data  <= std_logic_vector(resize(addr, BUS_DATA_WIDTH));
          
          if i = len-1 then
            wdat_last <= '1';
          else
            wdat_last <= '0';
          end if;    

          -- Wait for response ready.
          loop
            wait until rising_edge(clk);
            exit state when reset = '1';
            exit when wdat_ready = '1';
          end loop;
          
          wdat_valid <= '0';
          
          addr := addr + (BUS_DATA_WIDTH / 8);
        
        end loop;

      end loop;
    end loop;
  end process;

  -- Ignore responses.
  wrep_ready <= '1';

end Behavioral;

