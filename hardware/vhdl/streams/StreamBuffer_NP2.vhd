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

library work;
use work.Streams.all;
use work.Utils.all;

-- This unit optionally breaks all combinatorial paths from the input stream to
-- the output stream using slices and FIFOs. Its depth can be non-power-of-two
-- by combining multiple buffers. This has increased latency but reduced area.
--             .----.
-- Symbol: --->|buf+|--->
--             '----'

entity StreamBuffer_NP2 is
  generic (
    DEPTH                       : natural;

    -- Width of the stream data vector.
    DATA_WIDTH                  : natural;

    -- RAM configuration. This is passed directly to the Ram1R1W instance used
    -- for the FIFO, if a FIFO is inserted.
    RAM_CONFIG                  : string := ""

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DATA_WIDTH-1 downto 0);

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(DATA_WIDTH-1 downto 0)

  );
end StreamBuffer_NP2;

architecture Behavioral of StreamBuffer_NP2 is
  constant STAGES : natural := log2ceil(DEPTH);
  
  type stage_data_array is array (STAGES+1 downto 0) of std_logic_vector(DATA_WIDTH-1 downto 0);
  
  signal stage_valid : std_logic_vector(STAGES+1 downto 0);
  signal stage_ready : std_logic_vector(STAGES+1 downto 0);
  signal stage_data  : stage_data_array;
  
  function enable_stage(TOTAL_DEPTH : natural;
                        STAGE       : natural) 
  return boolean is
    variable result : natural := 0;
    variable d      : natural := TOTAL_DEPTH;
  begin
    for I in log2ceil(TOTAL_DEPTH) downto 0 loop
      if d - 2**I >= 0 then
        d := d - 2**I;
        if I = STAGE then        
          return true;
        end if;
      end if;
    end loop;
    return false;
  end enable_stage;
  
  
begin
  stage_valid(0) <= in_valid;
  in_ready <= stage_ready(0);
  stage_data(0) <= in_data;
  
  buffer_gen : for I in 0 to STAGES generate
    stage_enabled: if enable_stage(DEPTH, I) generate
      stage_buffer : StreamBuffer
        generic map (
          MIN_DEPTH   => 2**I,
          DATA_WIDTH  => DATA_WIDTH,
          RAM_CONFIG  => RAM_CONFIG
        )
        port map (
          clk         => clk,
          reset       => reset,
          in_valid    => stage_valid(I),
          in_ready    => stage_ready(I),
          in_data     => stage_data(I),
          out_valid    => stage_valid(I+1),
          out_ready    => stage_ready(I+1),
          out_data     => stage_data(I+1)
        );
    end generate;
    stage_disabled: if not(enable_stage(DEPTH, I)) generate
      stage_valid(I+1) <= stage_valid(I);
      stage_ready(I)   <= stage_ready(I+1);
      stage_data(I+1)  <= stage_data(I);
    end generate;
  end generate;
  
  out_valid <= stage_valid(STAGES+1);
  stage_ready(STAGES+1) <= out_ready;
  out_data <= stage_data(STAGES+1);
  
end Behavioral;

