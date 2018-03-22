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
use ieee.std_logic_misc.all;
use ieee.math_real.all;

library work;
use work.Streams.all;
use work.Utils.all;
use work.Arrow.all;
use work.SimUtils.all;

-------------------------------------------------------------------------------
-- This testbench is used to partially check the functionality of the 
-- BufferWriter.
entity BufferWriter_tb is
  generic (   
    BUS_ADDR_WIDTH              : natural  := 32;
    BUS_DATA_WIDTH              : natural  := 32;
    BUS_LEN_WIDTH               : natural  := 9;
    BUS_BURST_STEP_LEN          : natural  := 8;
    BUS_BURST_MAX_LEN           : natural  := 64;
                                           
    BUS_FIFO_DEPTH              : natural  := 1;
                                           
    ELEMENT_WIDTH               : natural  := 16;
    ELEMENT_COUNT_MAX           : natural  := 16;
    ELEMENT_COUNT_WIDTH         : natural  := max(1,log2ceil(ELEMENT_COUNT_MAX));
                                           
    INDEX_WIDTH                 : natural  := 32;
    IS_INDEX_BUFFER             : boolean  := false;
                                           
    NUM_COMMANDS                : natural  := 64;
                                           
    CMD_CTRL_WIDTH              : natural  := 1;
                                           
    CMD_TAG_WIDTH               : natural  := log2ceil(NUM_COMMANDS);
    
    VERBOSE                     : boolean  := false;
    SEED                        : positive := 16#BEE5#
  );
end BufferWriter_tb;

architecture tb of BufferWriter_tb is
  constant ELEMS_PER_WORD       : natural := BUS_DATA_WIDTH / ELEMENT_WIDTH;
  constant BYTES_PER_ELEM       : natural := work.Utils.max(1, ELEMENT_WIDTH/8);
  constant ELEMS_PER_BYTE       : natural := 8 / ELEMENT_WIDTH;
  constant MAX_ELEM_VAL         : real    := 2.0 ** (ELEMENT_WIDTH - 1);
  
  signal command_done           : std_logic := '0';
  signal input_done             : std_logic := '0';
  signal write_done             : std_logic := '0';

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
  signal cmdIn_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  
  signal unlock_valid           : std_logic;
  signal unlock_ready           : std_logic := '1';
  signal unlock_tag             : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal in_valid               : std_logic := '0';
  signal in_ready               : std_logic;
  signal in_data                : std_logic_vector(ELEMENT_COUNT_MAX * ELEMENT_WIDTH -1 downto 0);
  signal in_count               : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal in_last                : std_logic := '0';
  
  signal bus_req_valid          : std_logic;
  signal bus_req_ready          : std_logic;
  signal bus_req_addr           : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_req_len            : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_wrd_valid          : std_logic;
  signal bus_wrd_ready          : std_logic;
  signal bus_wrd_data           : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_wrd_strobe         : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal bus_wrd_last           : std_logic;
  
  function gen_elem_val(rand: real) return unsigned is
  begin
    return to_unsigned(natural(rand * MAX_ELEM_VAL), ELEMENT_WIDTH);
  end function;
  
  procedure print_elem(name: in string; index: in integer; a: in unsigned) is 
  begin
    dumpStdOut(name & "[" & ii(index) & "]: " & ii(int(a)));
  end print_elem;
  
  procedure print_elem_check(name: in string; index: in integer; a: in unsigned; b: in unsigned) is 
  begin
    dumpStdOut(name & "[" & ii(index) & "]: " & ii(int(a)) & " =?= " & ii(int(b)));
  end print_elem_check;
  
begin

  -- Clock
  clk_proc: process is
  begin
    if command_done = '0' or input_done = '0' or write_done = '0' then
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

  -- Reset
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
  
  -- Command generation
  command_proc: process is 
    variable seed1              : positive := SEED;
    variable seed2              : positive := 1;
    variable rand               : real;
    
    variable first_index        : unsigned(INDEX_WIDTH-1 downto 0) := (others => '0');
  begin
    cmdIn_implicit              <= '0';
    cmdIn_baseAddr              <= (others => '0');
    cmdIn_lastIdx               <= (others => '0');
    cmdIn_valid                 <= '0';
    cmdIn_tag                   <= (others => '0');
    
    -- Wait for reset
    wait until rising_edge(acc_clk) and (acc_reset /= '1');
      
    for I in 0 to NUM_COMMANDS-1 loop      
      -- Determine the first index
      uniform(seed1, seed2, rand);
      
      -- For index buffers, first_index should start at zero
      if IS_INDEX_BUFFER then
        first_index             := (others => '0');
      else
        first_index             := to_unsigned(natural(rand * 4096.0), INDEX_WIDTH);
      end if;
      
      if ELEMS_PER_BYTE = 0 then 
        -- Elements start on byte boundaries
        cmdIn_firstIdx          <= slv(first_index);
      else
        -- Elements don't always start on a byte boundary, align the first index to a byte boundary
        cmdIn_firstIdx          <= slv(align_beq(first_index, log2ceil(ELEMS_PER_BYTE)));
      end if;
      
      -- Set tag:
      cmdIn_tag                 <= slv(to_unsigned(I, CMD_TAG_WIDTH));
      
      -- Validate the command
      cmdIn_valid               <= '1';
      
      -- Wait until it's accepted and invalidate
      wait until rising_edge(acc_clk) and (cmdIn_ready = '1');
      cmdIn_valid               <= '0';
    end loop;
    
    -- All commands have been accepted
    command_done                <= '1';
    
    wait;
  end process;
  
  -- Input stream generation
  input_stream_proc: process is
    variable seed1              : positive := SEED;
    variable seed2              : positive := 1;
    variable rand               : real;
    
    variable count_seed1        : positive := SEED;
    variable count_seed2        : positive := 1;
    variable count_rand         : real;
    
    variable last_seed1         : positive := SEED;
    variable last_seed2         : positive := 1;
    variable last_rand          : real;
    
    variable true_count         : integer  := 0;
    
    variable total_elements     : integer  := 0;
    variable first_index        : integer  := 0;
    
    variable elem_val           : unsigned(ELEMENT_WIDTH-1 downto 0);
  begin
    
    in_valid                    <= '0';
    in_last                     <= '0';
    
    loop     
      -- Wait until a command gets accepted:
      wait until rising_edge(acc_clk) and (cmdIn_ready = '1' and cmdIn_valid = '1');
      first_index               := int(cmdIn_firstIdx);
      total_elements            := 0;
      
      if IS_INDEX_BUFFER then
        total_elements          := total_elements + 1;
      end if;
      
      loop
        in_last                 <= '0';
        -- Randomize count
        if ELEMENT_COUNT_MAX > 1 then
          uniform(count_seed1, count_seed2, count_rand);
          if count_rand > 0.9 then
            true_count          := natural(count_rand * real(ELEMENT_COUNT_MAX-1));
            in_count            <= slv(to_unsigned(true_count, ELEMENT_COUNT_WIDTH));
          else
            true_count          := ELEMENT_COUNT_MAX;
            in_count            <= (others => '0');
          end if;
        else
          true_count            := ELEMENT_COUNT_MAX;
          in_count              <= (others => '1');
        end if;
        
        -- Make data unkown
        in_data                 <= (others => 'X');
        
        -- Randomize data
        for I in 0 to true_count-1  loop
            uniform(seed1, seed2, rand);

            elem_val            := gen_elem_val(rand);
            in_data((I+1)*ELEMENT_WIDTH-1 downto I*ELEMENT_WIDTH) <= slv(elem_val);
            
            if VERBOSE then
              print_elem("Stream", first_index + total_elements, elem_val);
            end if;
            
            total_elements      := total_elements + 1;
        end loop;
        
        -- Randomize last, but only assert it if the "last index" is on a byte boundary
        uniform(last_seed1, last_seed2, last_rand);
        if last_rand < (1.0/256.0) then
          if ELEMS_PER_BYTE /= 0 then -- prevent mod 0 error
            if total_elements mod ELEMS_PER_BYTE = 0 then
              in_last           <= '1';
            end if;
          else
            in_last             <= '1';
          end if;
        end if;
        
        -- Wait until handshake
        in_valid                <= '1';
        wait until rising_edge(acc_clk) and (in_ready = '1');
                
        -- Exit when last
        if in_last = '1' then
          exit;
        end if;
      end loop;
      
      -- Exit when command is done
      if command_done = '1' then
        input_done              <= '1';
        in_valid                <= '0';
        in_last                 <= '0';
        exit;
      end if;
    end loop;
    
    wait;
  end process;
   
  -- Unlock stream check
  unlock_proc: process is
    variable unlocked           : integer := 0;
    
    variable expected_tag       : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  begin
    loop
      -- Wait for unlock handshake
      wait until rising_edge(acc_clk) and (unlock_valid = '1' and unlock_ready = '1');

      expected_tag              := slv(to_unsigned(unlocked,CMD_TAG_WIDTH));
      
      if unlock_tag /= expected_tag then
        report "TEST FAILURE. Unexpected tag on unlock stream." severity failure;
      end if;
      
      -- Increase number of unlocks
      unlocked                  := unlocked + 1;
      
      -- Check if we are done
      if unlocked = NUM_COMMANDS then
        write_done              <= '1';
        exit;
      end if;
    end loop;
    
    -- Dirty trick to allow stdout to empty write buffer since textio doesn't have a flush function
    wait for 100 ns;
    
    -- If the test finishes, it is successful.
    report "TEST SUCCESSFUL.";
    
    wait;
  end process;

  -- Bus write check
  -- This process can only accept a single bus burst request at a time
  bus_write_proc: process is
    variable seed1              : positive := SEED;
    variable seed2              : positive := 1;
    variable rand               : real;
    
    variable address            : unsigned(BUS_ADDR_WIDTH-1 downto 0);
    
    variable len                : unsigned(BUS_LEN_WIDTH-1 downto 0);
    variable transfers          : unsigned(BUS_LEN_WIDTH-1 downto 0);
        
    variable index              : integer := 0;
    variable elem_strobe        : std_logic := '1';    
    variable elem_written       : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable elem_expected      : unsigned(ELEMENT_WIDTH-1 downto 0);
  begin
    bus_req_ready               <= '1';
    bus_wrd_ready               <= '0';
    loop
      -- Exit when all writes are done
      if write_done = '1' then
        exit;
      end if;
      -- Wait for a bus request
      wait until rising_edge(acc_clk) and (bus_req_ready = '1' and bus_req_valid = '1');
      bus_req_ready             <= '0';
      bus_wrd_ready             <= '1';
      
      -- Remember the burst length
      len                       := unsigned(bus_req_len);
      transfers                 := (others => '0');
      
      -- Work back the element index from the address, assuming the base address is zero
      index                     := int(bus_req_addr) / BYTES_PER_ELEM;
      
      -- Accept the number of words requested by the burst length
      for I in 0 to int(len)-1 loop
        -- Wait until master writes a burst beat
        wait until rising_edge(acc_clk) and (bus_wrd_valid = '1');
        
        transfers               := transfers + 1;
        
        -- Check each element value
        for I in 0 to ELEMS_PER_WORD-1 loop
          -- Determine the element strobe. For elements smaller than a byte, duplicate the strobe.
          if ELEMS_PER_BYTE = 0 then
            -- The elements are always byte aligned.
            elem_strobe         := or_reduce(bus_wrd_strobe((I+1)*BYTES_PER_ELEM-1 downto I*BYTES_PER_ELEM));
          else
            -- The elements are not always byte aligned
            elem_strobe         := bus_wrd_strobe(I/ELEMS_PER_BYTE);
          end if;
          
          -- Grab what is written
          elem_written          := u(bus_wrd_data((I+1) * ELEMENT_WIDTH-1 downto I * ELEMENT_WIDTH));
          
          -- Check if the element strobe is asserted
          if elem_strobe = '1' then
          
            -- If this is an index buffer and its the first element, we expect it to be 0
            if IS_INDEX_BUFFER and index+I = 0 then
              elem_expected     := (others => '0');
            else
              uniform(seed1, seed2, rand);
              elem_expected     := gen_elem_val(rand);
            end if;
            
            if VERBOSE then
              print_elem_check("Bus", index+I, elem_written, elem_expected);
            end if;
            
            if elem_written /= elem_expected then
              if not(VERBOSE) then
                print_elem_check("Bus", index+I, elem_written, elem_expected);
              end if;
              report "TEST FAILURE. Unexpected element on bus." severity failure;
            end if;
              
          end if;
          
          -- Make sure last is not too early
          if bus_wrd_last = '1' then
            assert transfers = len
              report "TEST FAILURE. Bus write channel last asserted at transfer " & ii(int(transfers)) & " while requested length was " & ii(int(len)) 
              severity failure;
          end if;
          
          -- Or too late
          if transfers = len and bus_wrd_last = '0' then
            report "TEST FAILURE. Bus write channel last NOT asserted at transfer " & ii(int(transfers)) & " while requested length was " & ii(int(len)) 
              severity failure;
          end if;
          
        end loop;
        
        -- Increase current index
        index                   := index + BUS_DATA_WIDTH / ELEMENT_WIDTH;
      end loop;
      -- Start accepting new requests
      bus_req_ready             <= '1';
      bus_wrd_ready             <= '0';
    end loop;
    wait;
  end process;

  -- BufferWriter instantiation
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
      CMD_CTRL_WIDTH            => CMD_CTRL_WIDTH,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
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
      cmdIn_tag                 => cmdIn_tag,
      
      unlock_valid              => unlock_valid,
      unlock_ready              => unlock_ready,
      unlock_tag                => unlock_tag,
      
      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_data                   => in_data,
      in_count                  => in_count,
      in_last                   => in_last,
      
      bus_req_valid             => bus_req_valid,
      bus_req_ready             => bus_req_ready,
      bus_req_addr              => bus_req_addr,
      bus_req_len               => bus_req_len,
      bus_wrd_valid             => bus_wrd_valid,
      bus_wrd_ready             => bus_wrd_ready,
      bus_wrd_data              => bus_wrd_data,
      bus_wrd_strobe            => bus_wrd_strobe,
      bus_wrd_last              => bus_wrd_last
    );

end architecture;
