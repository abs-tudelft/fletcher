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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.Utils.all;
use work.Streams.all;

-- This unit calculates the prefix sum of an input stream of multiple elements
-- that are considered to be unsigned integers.
--
-- Symbol:   --->(Pr+)--->
--
-- Future work might consider explicitly implementing Brent-Kung, Kogge-Stone 
-- or hybrid approach in case synthesis tools don't do this already.
-- 
entity StreamPrefixSum is
  generic (
  
    ---------------------------------------------------------------------------
    -- Input configuration
    ---------------------------------------------------------------------------
    -- Width of a data element, assumed to be an unsigned integer.
    DATA_WIDTH                  : natural;
        
    -- Maximum number of elements per clock in the data input stream.
    COUNT_MAX                   : natural;
    
    -- The number of bits in the count vectors. This must be at least
    -- ceil(log2(COUNT_MAX)) and must be at least 1. If COUNT_MAX is a power of
    -- two and this value equals log2(COUNT_MAX), a zero count implies that all
    -- entries are valid (i.e., there is an implicit '1' bit in front).
    COUNT_WIDTH                 : natural;
    
    -- Width of control information. This information travels with the data
    -- stream but is left untouched. Must be at least 1 to prevent null vectors.
    CTRL_WIDTH                  : natural  := 1;
        
    -- Whether to loop back the last sum value to the input unless last was
    -- asserted in the previous handshake, or in_clear is asserted in the 
    -- current.
    LOOPBACK                    : boolean := false
  );
  port (
  
    ---------------------------------------------------------------------------
    -- Clock domains
    ---------------------------------------------------------------------------
    -- Rising-edge sensitive clock and active-high synchronous reset.
    clk                         : in  std_logic;
    reset                       : in  std_logic;
    
    ---------------------------------------------------------------------------
    -- Element input stream
    ---------------------------------------------------------------------------
    -- in_clear is used to reset the prefix sum array to in_initial value 
    -- starting from the associated handshake.
    -- in_skip is used to skip summing specific positions.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_clear                    : in  std_logic                                           := '0';
    in_initial                  : in  std_logic_vector(DATA_WIDTH-1 downto 0)             := (others => '0');
    in_data                     : in  std_logic_vector(COUNT_MAX*DATA_WIDTH-1 downto 0);
    in_ctrl                     : in  std_logic_vector(CTRL_WIDTH-1 downto 0)             := (others => '0');
    in_count                    : in  std_logic_vector(COUNT_WIDTH-1 downto 0);
    in_last                     : in  std_logic;

    ---------------------------------------------------------------------------
    -- Prefix sums output stream
    ---------------------------------------------------------------------------
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(COUNT_MAX*DATA_WIDTH-1 downto 0);
    out_ctrl                    : out std_logic_vector(CTRL_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(COUNT_WIDTH-1 downto 0);
    out_last                    : out std_logic
    
  );
end StreamPrefixSum;

architecture Behavioral of StreamPrefixSum is
  -- Array representation of input values
  type arr_t is array(natural range <>) of unsigned(DATA_WIDTH-1 downto 0);  
  
  -- Input array
  signal in_array               : arr_t(COUNT_MAX-1 downto 0);
    
  -- One hot encoded in_count
  signal in_skip                : std_logic_vector(COUNT_MAX-1 downto 0);
  
  -- State machine types and signals
  type state_type is record
    first : std_logic;
    sum   : arr_t(COUNT_MAX-1 downto 0);
    count : std_logic_vector(COUNT_WIDTH-1 downto 0);
    last  : std_logic;
    valid : std_logic;
    ctrl  : std_logic_vector(CTRL_WIDTH-1 downto 0);
  end record;
  
  type input_type is record
    ready : std_logic;
  end record;
  
  signal r : state_type;
  signal d : state_type;
  signal i : input_type;
    
begin

  in_skip <= not(work.Utils.cnt2th(unsigned(in_count), COUNT_MAX));

  -- Represent input data as array
  input_deserialize: for I in 0 to COUNT_MAX-1 generate
    in_array(I) <= unsigned(in_data((I+1)*DATA_WIDTH-1 downto I*DATA_WIDTH));
  end generate;
  
  -- Sequential
  seq: process(clk) is
  begin
    if rising_edge(clk) then
      r <= d;
      -- Reset
      if reset = '1' then
        r.valid <= '0';
        r.first <= '1';
        for I in 0 to COUNT_MAX-1 loop
          r.sum(COUNT_MAX-1) <= (others => '0');
        end loop;
      end if;
    end if;
  end process;
  
  -- Combinatorial
  comb: process(
    r,
    reset,
    in_valid, in_array, in_last, in_initial, in_clear, in_skip,
    out_ready
  ) is 
    variable v : state_type;
  begin
    v := r;
    
    -- Input side is ready by default, unless its being reset.
    if reset /= '1' then    
      i.ready <= '1';
    else
      i.ready <= '0';
    end if;
    
    -- Stall input if output is valid but not handshaked.
    if r.valid = '1' and out_ready = '0' then
      i.ready <= '0';
    end if;
    
    -- If the output is handshaked, but there is no new data
    if r.valid = '1' and out_ready = '1' and in_valid = '0' then
      -- Invalidate the output.
      v.valid                   := '0';
    end if;
    
    -- If the input is valid, and the output has no data or is handshaked
    -- we may advance the stream.
    if in_valid = '1' and
       (r.valid = '0' or (r.valid = '1' and out_ready = '1'))
    then
      v.valid := '1';
      v.ctrl  := in_ctrl;
      v.last  := in_last;
      v.count := in_count;
      
      -- For loopback mode
      if LOOPBACK then
        -- If this is the first handshake after reset or last, or when clear is,
        -- asserted, use the initial value for the first sum.
        if r.first = '1' or in_clear = '1' then
          v.sum(0) := unsigned(in_initial) + in_array(0);
          v.first := '0';
        else
          -- Otherwise get the last sum from the previous prefix sum for the 
          -- first sum
          v.sum(0) := r.sum(COUNT_MAX-1) + in_array(0);
        end if;
        
        -- When this is the last handshake, the next handshake will be a first
        -- handshake again.
        if (in_last = '1') then
          v.first := '1';
        end if;
      else
        -- If no loopback mode, just calculate the prefix sum of this MEPC
        -- handshake.
        v.sum(0) := unsigned(in_initial);
      end if;
      
      -- Calculate prefix sums.
      prefix_sum: for I in 1 to COUNT_MAX-1 loop
        -- Only add when we shouldn't skip at some position.
        if in_skip(I) = '0' then
          v.sum(I) := in_array(I) + v.sum(I-1);
        else 
          v.sum(I) := v.sum(I-1);
        end if;
      end loop;
    end if;
    
    -- Outputs to be registered.
    d <= v;
    
    -- Outputs not to be registered.
    in_ready <= i.ready;
  end process;
  
  
  -- Connect registered outputs:
  
  -- Represent output array as single vector
  output_serialize: for I in 0 to COUNT_MAX-1 generate
    out_data((I+1)*DATA_WIDTH-1 downto I*DATA_WIDTH) <= std_logic_vector(r.sum(I));
  end generate;
  
  out_valid <= r.valid;
  out_count <= r.count;
  out_last  <= r.last;
  out_ctrl  <= r.ctrl;
    
end Behavioral;
