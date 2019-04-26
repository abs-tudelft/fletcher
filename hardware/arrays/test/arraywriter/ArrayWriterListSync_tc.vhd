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
use work.Arrays.all;
use work.SimUtils.all;

--pragma simulation timeout 10 us

-- Simulates the ArrayWriterListSync. Basically checks that whatever we throw
-- into it at the input, it stays the same at the output, independent of the
-- configuration you want to use.

entity ArrayWriterListSync_tc is
end ArrayWriterListSync_tc;

architecture Behavioral of ArrayWriterListSync_tc is

  constant LEN_SEED             : positive := 16#0EA7#;
  constant LEN_COUNT_SEED       : positive := 16#BEEF#;
  constant ELEM_SEED            : positive := 16#F00D#;
  constant MAX_LEN              : real     := 128.0;

  constant ELEMENT_WIDTH        : positive := 8;
  constant COUNT_MAX            : positive := 4;
  constant COUNT_WIDTH          : positive := 3;
  
  constant LENGTH_WIDTH         : positive := 8;
  constant LCOUNT_MAX           : positive := 4;
  constant LCOUNT_WIDTH         : positive := 3;

  constant GENERATE_LENGTH      : boolean  := false;
  constant NORMALIZE            : boolean  := false;
  constant ELEM_LAST_FROM_LENGTH: boolean  := true;

  constant NUM_LISTS            : natural  := 100;

  signal clk                    : std_logic;
  signal reset                  : std_logic;

  signal inl_valid              : std_logic;
  signal inl_ready              : std_logic;
  signal inl_length             : std_logic_vector(LCOUNT_MAX*LENGTH_WIDTH-1 downto 0);
  signal inl_count              : std_logic_vector(LCOUNT_WIDTH-1 downto 0);
  signal inl_last               : std_logic;

  signal ine_valid              : std_logic;
  signal ine_ready              : std_logic;
  signal ine_dvalid             : std_logic := '1';
  signal ine_data               : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal ine_count              : std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
  signal ine_last               : std_logic;

  signal outl_valid             : std_logic;
  signal outl_ready             : std_logic := '1';
  signal outl_length            : std_logic_vector(LCOUNT_MAX*LENGTH_WIDTH-1 downto 0);
  signal outl_count             : std_logic_vector(LCOUNT_WIDTH-1 downto 0);
  signal outl_last              : std_logic;

  signal oute_valid             : std_logic;
  signal oute_ready             : std_logic := '1';
  signal oute_last              : std_logic;
  signal oute_dvalid            : std_logic;
  signal oute_data              : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal oute_count             : std_logic_vector(COUNT_WIDTH-1 downto 0);

  signal clock_stop             : boolean := false;
  signal len_done               : boolean := false;
begin

  clk_proc: process is
  begin
    clock_stop := false;
    len_done := false;
    loop
      clk <= '1';
      wait for 5 ns;
      clk <= '0';
      wait for 5 ns;
      exit when clock_stop;
    end if;
    wait;
  end process;

  reset_proc: process is
  begin
    reset <= '1';
    wait for 50 ns;
    wait until rising_edge(clk);
    reset <= '0';
    wait;
  end process;

  -- Generate length stream
  len_stream_proc: process is
    variable seed1              : positive := LEN_SEED;
    variable seed2              : positive := 1;
    variable rand               : real;
    
    variable lseed1             : positive := LEN_COUNT_SEED;
    variable lseed2             : positive := 1;
    variable lrand              : real;

    variable list               : integer;
    variable handshake          : integer;

    variable len                : integer;
    variable random_count       : integer;
    variable count              : integer;
    
    variable expect_elements    : integer := 0;
  begin

    inl_valid   <= '0';
    inl_length  <= (others => 'U');
    inl_last    <= '0';

    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    list := 0;
    handshake := 0;

    loop
    
      -- Randomize count
      uniform(lseed1, lseed2, lrand);
      random_count := 1 + natural(lrand * real(LCOUNT_MAX-1));
      
      dumpStdOut("Length stream item: " &  integer'image(handshake));
      count := 0;
    
      -- Randomize list lengths
      for I in 0 to random_count-1 loop
        uniform(seed1, seed2, rand);
        len := natural(rand * MAX_LEN);
        
        dumpStdOut("  List : " & integer'image(list) & ", length: " & integer'image(I) & ": " & integer'image(len));
        
        -- Set the length vector
        inl_length((I+1)*LENGTH_WIDTH-1 downto I*LENGTH_WIDTH) <= std_logic_vector(to_unsigned(len, LENGTH_WIDTH));
        
        expect_elements := expect_elements + len;
        
        -- Set last
        if list = NUM_LISTS-1 then
          inl_last <= '1';
        else
          inl_last <= '0';
        end if;
        
        exit when inl_last = '1';
        
        -- Increment counters
        list := list + 1;
        count := count + 1;
      end loop;
      -- Invalidate other list lengths that are outside count
      for I in count to LCOUNT_MAX-1 loop
        inl_length((I+1)*LENGTH_WIDTH-1 downto I*LENGTH_WIDTH) <= (others => 'U');
      end loop;

      inl_count <= std_logic_vector(to_unsigned(count, LCOUNT_WIDTH));
      
      dumpStdOut("  Count: " & integer'image(count));
      
      -- Validate length
      inl_valid <= '1';

      -- Wait for handshake
      loop
        wait until rising_edge(clk);
        exit when inl_ready = '1';
      end loop;
      
      handshake := handshake + 1;
      

      exit when list = NUM_LISTS;
    end loop;

    inl_valid   <= '0';
    inl_length  <= (others => 'U');
    inl_last    <= '0';

    len_done <= true;
    
    wait until clock_stop;
    dumpStdOut("Expected Elements specified by Length Stream: " & integer'image(expect_elements));

    wait;
  end process;


  elem_stream_proc: process is
    variable lseed1             : positive := LEN_SEED;
    variable lseed2             : positive := 1;
    variable lrand              : real;

    variable seed1              : positive := ELEM_SEED;
    variable seed2              : positive := 1;
    variable rand               : real;

    variable data               : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable count              : natural;

    variable len                : integer;
    variable orig_len           : integer;
    variable empty              : boolean;

    variable list               : integer;

    variable element            : natural := 0;
  begin

    ine_valid <= '0';

    -- Wait until no reset
    loop
      wait until rising_edge(clk);
      exit when reset = '0';
    end loop;

    list := 0;

    -- Loop over different list
    loop
      ine_valid   <= '0';
      ine_last    <= '0';
      ine_count   <= (others => 'U');
      ine_dvalid  <= '0';
      ine_data    <= (others => 'U');

      exit when list = NUM_LISTS;

      -- Randomize list length, using the same seed as the len stream process
      uniform(lseed1, lseed2, lrand);
      len := natural(lrand * MAX_LEN);
      orig_len := len;

      --dumpStdOut("Element stream: list " & integer'image(list) & " length is " & integer'image(len));

      if len = 0 then
        empty := true;
      else
        empty := false;
      end if;

      -- Generate some data
      loop
        -- Randomize count
        uniform(seed1, seed2, rand);
        count := 1 + work.Utils.min(3, natural(2.0*rand * real(COUNT_MAX)));

        --dumpStdOut("element stream: count is " & integer'image(count));

        -- Resize count if necessary
        if len - count < 0 then
          count := len;
        end if;

        ine_count <= std_logic_vector(to_unsigned(count, COUNT_WIDTH));

        -- Determine elements
        for e in 0 to count-1 loop
          element := element + 1;
          ine_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) <= std_logic_vector(to_unsigned(element, ELEMENT_WIDTH));
        end loop;
        for e in count to COUNT_MAX-1 loop
          ine_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) <= (others => 'U');
        end loop;

        -- Subtract count
        len := len - count;

        -- Determine last
        if len = 0 then
          ine_last <= '1';
        end if;

        -- Determine dvalid
        if empty then
          ine_dvalid <= '0';
        else
          ine_dvalid <= '1';
        end if;

        ine_valid <= '1';

        -- Wait for acceptance
        loop
          wait until rising_edge(clk);
          exit when ine_ready = '1';
        end loop;

        if ine_last = '1' then
          list := list + 1;
        end if;

        exit when len = 0;

      end loop;

    end loop;

    -- Wait a bit for all the outputs in a nasty way
    wait for 100 ns;

    clock_stop <= true;
    wait;

  end process;

  -- Instantiate UUT.
  uut: ArrayWriterListSync
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      COUNT_WIDTH               => COUNT_WIDTH,
      LENGTH_WIDTH              => LENGTH_WIDTH,
      LCOUNT_MAX                => LCOUNT_MAX,
      LCOUNT_WIDTH              => LCOUNT_WIDTH,
      GENERATE_LENGTH           => GENERATE_LENGTH,
      NORMALIZE                 => NORMALIZE,
      ELEM_LAST_FROM_LENGTH     => ELEM_LAST_FROM_LENGTH,
      DATA_IN_SLICE             => false,
      LEN_IN_SLICE              => false,
      OUT_SLICE                 => true
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      inl_valid                 => inl_valid,
      inl_ready                 => inl_ready,
      inl_length                => inl_length,
      inl_count                 => inl_count,
      inl_last                  => inl_last,

      ine_valid                 => ine_valid,
      ine_ready                 => ine_ready,
      ine_dvalid                => ine_dvalid,
      ine_data                  => ine_data,
      ine_count                 => ine_count,
      ine_last                  => ine_last,

      outl_valid                => outl_valid,
      outl_ready                => outl_ready,
      outl_length               => outl_length,
      outl_count                => outl_count,
      outl_last                 => outl_last,

      oute_valid                => oute_valid,
      oute_ready                => oute_ready,
      oute_last                 => oute_last,
      oute_dvalid               => oute_dvalid,
      oute_data                 => oute_data,
      oute_count                => oute_count
    );

  check_len: process is
    variable lseed1             : positive := LEN_SEED;
    variable lseed2             : positive := 1;
    variable lrand              : real;

    variable len                : natural;
    variable list               : natural := 0;
    variable count              : natural;
  begin
    outl_ready <= '1';
    loop
      -- Wait for a valid length output
      loop
        wait until rising_edge(clk);
        exit when outl_valid = '1';
      end loop;
      
      -- Get count
      count := to_integer(unsigned(resize_count(outl_count, COUNT_WIDTH+1)));

      -- Check all lengths
      for I in 0 to count-1 loop
        -- Get the length from randomizer with the same seed
        uniform(lseed1, lseed2, lrand);
        len := natural(lrand * MAX_LEN);
        -- Check length
        assert unsigned(outl_length((I+1)*LENGTH_WIDTH-1 downto I*LENGTH_WIDTH)) = to_unsigned(len, LENGTH_WIDTH)
          report "Length output stream error. "
               & " List "       & integer'image(list)
               & " is "         & integer'image(to_integer(unsigned(outl_length)))
               & ", expected: " & integer'image(len)
          severity failure;

        list := list + 1;
      end loop;

      exit when list = NUM_LISTS;
    end loop;
    wait;
  end process;

  check_data: process is
    variable seed1              : positive := ELEM_SEED;
    variable seed2              : positive := 1;
    variable rand               : real;

    variable handshake          : natural := 0;
    variable last               : natural := 0;
    variable element            : natural := 0;
    variable count              : natural;
  begin
    oute_ready <= '1';
    loop
      -- Wait for a valid element output
      loop
        wait until rising_edge(clk);
        exit when oute_valid = '1';
      end loop;
      
      -- Check if data is valid
      if oute_dvalid = '1' then
        count := to_integer(unsigned(resize_count(oute_count, COUNT_WIDTH+1)));
        --dumpStdOut("Out elem " & integer'image(handshake) & " count: " & integer'image(count));
        
        -- Check data
        for e in 0 to count-1 loop
        
          element := element + 1;
                    
          assert oute_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) = std_logic_vector(to_unsigned(element, ELEMENT_WIDTH))
            report "Invalid data on output element stream."
            severity failure;
            
        end loop;
      else 
        --dumpStdOut("Out elem " & integer'image(handshake) & " dvalid=0");
      end if;
      
      handshake := handshake + 1;
      
      if oute_last = '1' then
        last := last + 1;
      end if; 
      
      exit when ELEM_LAST_FROM_LENGTH and last > 0;
      exit when last = NUM_LISTS;

    end loop;
    wait until clock_stop;
    dumpStdOut("Received total of " & integer'image(element) & " elements.");
    wait;
  end process;


end Behavioral;

