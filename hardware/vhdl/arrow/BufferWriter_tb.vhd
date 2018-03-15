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
use work.Arrow.all;

-- This testbench is used to check the functionality of the BufferReader.
-- TODO: it does not always return TEST_SUCCESSFUL even though it may be 
-- successful. But currently, it's used to generally mess around with
-- internal command stream and the bus request generator
-- So normally if it ends, it should be somewhat okay in terms of how many
-- elements it returns. Wether they are the right elements can be tested using
-- the columnreader test bench, or by setting the element size equal to the 
-- word size, but that is not a guarantee of proper functioning.
entity BufferWriter_tb is
  generic (   
    BUS_ADDR_WIDTH              : natural := 64;
    BUS_DATA_WIDTH              : natural := 512;
    BUS_LEN_WIDTH               : natural := 9;
    BUS_BURST_STEP_LEN          : natural := 1;
    BUS_BURST_MAX_LEN           : natural := 8;
    
    BUS_FIFO_DEPTH              : natural := 16;
    
    ELEMENT_WIDTH               : natural := 8;
    ELEMENT_COUNT_MAX           : natural := 64;
    ELEMENT_COUNT_WIDTH         : natural := max(1,log2ceil(ELEMENT_COUNT_MAX));

    INDEX_WIDTH                 : natural := 32;
    IS_INDEX_BUFFER             : boolean := false;
    
    SEED                        : positive := 1337
  );
end BufferWriter_tb;

architecture tb of BufferWriter_tb is
  signal test_done              : std_logic := '0';

  signal bus_clk                : std_logic := '1';
  signal bus_reset              : std_logic := '1';
  signal acc_clk                : std_logic := '1';
  signal acc_reset              : std_logic := '1';
  
  signal cmdIn_valid            : std_logic;
  signal cmdIn_ready            : std_logic;
  signal cmdIn_firstIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmdIn_lastIdx          : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmdIn_baseAddr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal cmdIn_implicit         : std_logic;

  signal in_valid               : std_logic := '0';
  signal in_ready               : std_logic;
  signal in_data                : std_logic_vector(ELEMENT_COUNT_MAX * ELEMENT_WIDTH -1 downto 0);
  signal in_count               : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal in_last                : std_logic := '0';

begin

  clk_proc: process is
  begin
    if test_done /= '1' then
      bus_clk <= '1';
      acc_clk <= '1';
      wait for 5 ns;
      bus_clk <= '0';
      acc_clk <= '0';
      wait for 5 ns;
    else
      wait;
    end if;
  end process;

  reset_proc: process is
  begin
    bus_reset <= '1';
    acc_reset <= '1';
    wait for 50 ns;
    wait until rising_edge(acc_clk);
    bus_reset <= '0';
    acc_reset <= '0';
    wait;
  end process;
  
  command_proc: process is 
    variable seed1              : positive := SEED;
    variable seed2              : positive := 1;
    variable rand               : real;
  begin
    cmdIn_implicit              <= '0';
    cmdIn_baseAddr              <= (others => '0');
    cmdIn_lastIdx               <= (others => '0');
    
    for I in 0 to 8 loop
      cmdIn_valid               <= '0';
      wait until rising_edge(acc_clk) and (acc_reset /= '1');
      
      cmdIn_firstIdx            <= X"00000007";
      cmdIn_valid               <= '1';
      wait until rising_edge(acc_clk) and (cmdIn_ready = '1');
    end loop;
    test_done                   <= '1';
    wait;
  end process;
  
  input_stream_proc: process is
    variable seed1              : positive := SEED;
    variable seed2              : positive := 1;
    variable rand               : real;
  begin
    in_valid                    <= '0';
    loop
      uniform(seed1, seed2, rand);
      if rand > 0.8 then
        in_count                  <= slv(to_unsigned(natural(rand * real(ELEMENT_COUNT_MAX-1)),ELEMENT_COUNT_WIDTH));
      else
        in_count                  <= (others => '0');
      end if;
      
      for I in 0 to ELEMENT_COUNT_MAX-1  loop
        uniform(seed1, seed2, rand);
        in_data((I+1)*ELEMENT_WIDTH-1 downto I*ELEMENT_WIDTH) <= slv(to_unsigned(natural(rand * real(2.0 ** ELEMENT_WIDTH)), ELEMENT_WIDTH));
      end loop;
      
      if rand > 0.98 then
        in_last                 <= '1';
        if test_done = '1' then
          exit;
        end if;
      else
        in_last                 <= '0';
      end if;
      
      in_valid                  <= '1';
      wait until rising_edge(acc_clk) and (in_ready = '1');
    end loop;
    wait;
  end process;
  

  uut : BufferWriter
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_FIFO_DEPTH            => BUS_FIFO_DEPTH,
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      IS_INDEX_BUFFER           => IS_INDEX_BUFFER,
      ELEMENT_COUNT_MAX         => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => ELEMENT_COUNT_WIDTH,
      CMD_CTRL_WIDTH            => 1,
      CMD_TAG_WIDTH             => 1
    )
    port map (
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      acc_clk                   => acc_clk,
      acc_reset                 => acc_reset,
      
      cmdIn_valid               => cmdIn_valid, 
      cmdIn_ready               => cmdIn_ready,   
      cmdIn_firstIdx            => cmdIn_firstIdx,
      cmdIn_lastIdx             => cmdIn_lastIdx, 
      cmdIn_baseAddr            => cmdIn_baseAddr,
      cmdIn_implicit            => cmdIn_implicit,
      
      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_data                   => in_data,
      in_count                  => in_count,
      in_last                   => in_last
    );



end architecture;
