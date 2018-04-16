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
use work.Streams.all;
use work.Utils.all;

-- This unit either barrel shifts or barrel rotates a group of elements 
-- either left or right.
--
-- Symbol: --->(o=o)--->

entity StreamBarrel is
  generic (

    -- Width of a data element.
    ELEMENT_WIDTH               : natural;

    -- Maximum number of elements per clock.
    COUNT_MAX                   : natural;

    -- Width of the amount input
    AMOUNT_WIDTH                : natural;
    
    -- Maximum shift/rotate
    AMOUNT_MAX                  : natural;

    -- Direction of the rotation
    DIRECTION                   : string := "left";
    
    -- Operation; shift or rotate
    OPERATION                   : string := "rotate";

    -- The number of pipelined stages to use to make the rotation
    --STAGES                      : natural;

    -- Width of control data. Must be 1 to avoid null ranges. Travels with the
    -- pipeline
    CTRL_WIDTH                  : natural := 1

  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_rotate                   : in  std_logic_vector(AMOUNT_WIDTH-1 downto 0);
    in_data                     : in  std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    in_ctrl                     : in  std_logic_vector(CTRL_WIDTH-1 downto 0) := (others => '0');

    -- Output stream.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_data                    : out std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    out_ctrl                    : out std_logic_vector(CTRL_WIDTH-1 downto 0)
  );
end StreamBarrel;

architecture Behavioral of StreamBarrel is

  type in_type is record
    ready                       : std_logic;
  end record;

  -- Current implementation only supports shifting one position per stage.
  constant STAGES : natural := AMOUNT_MAX+1;

  type element_array_type is array(COUNT_MAX-1 downto 0) of std_logic_vector(ELEMENT_WIDTH-1 downto 0);

  type pipeline_reg_type is record
    elements : element_array_type;
    rotate   : unsigned(AMOUNT_WIDTH-1 downto 0);

    valid    : std_logic;
    ctrl     : std_logic_vector(CTRL_WIDTH-1 downto 0);
  end record;
  
  -- Prevent simulator spam
  constant ROTATE_ZERO : unsigned(AMOUNT_WIDTH-1 downto 0) := (others => '0');

  type pipeline_type is array(0 to STAGES-1) of pipeline_reg_type;

  signal r : pipeline_type;
  signal d : pipeline_type;

begin

  seq_proc: process(clk) is
  begin
    if rising_edge(clk) then
      r <= d;
      
      if reset = '1' then
        -- Invalidate all data
        for i in 0 to STAGES-1 loop
          r(i).valid <= '0';
        end loop;
      end if;
    end if;
  end process;

  comb_proc: process(r,
    in_valid, in_rotate, in_data, in_ctrl,
    out_ready
  ) is
    variable v : pipeline_type;
    variable i : in_type;
    variable has_data : std_logic;
  begin
    v                           := r;
    
    -- Input is ready when valid by default
    if in_valid = '1' then
      i.ready := '1';
    else
      i.ready := '0';
    end if;
           
    -- If the output stage is valid, but not handshaked, the input must be 
    -- stalled immediately
    if r(STAGES-1).valid = '1' and out_ready = '0' then
      i.ready                   := '0';
    end if;
        
    -- If the output is handshaked, lower the output valid by default.
    if r(STAGES-1).valid = '1' and out_ready = '1' then
      v(STAGES-1).valid := '0';
    end if;
    
    -- Check if the pipeline has data anywhere
    has_data := in_valid;
    
    for s in 0 to STAGES-1 loop
      has_data := has_data or v(s).valid;
    end loop;

    -- If the pipeline still has data, and the output has no data or is 
    -- handshaked, we may advance the stream
    if has_data = '1' and
       (r(STAGES-1).valid = '0' or (r(STAGES-1).valid = '1' and out_ready = '1'))
    then
      -- Grab inputs
      v(0).valid := in_valid and i.ready;
      v(0).rotate := unsigned(in_rotate);
      v(0).ctrl := in_ctrl;
      
      -- Determine inputs
      for e in 0 to COUNT_MAX-1 loop
        v(0).elements(e) := in_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH);
      end loop;
      
      --pragma translate off
      if v(0).valid = '0' then
        v(0).rotate := (others => '0');
        v(0).ctrl := (others => 'U');
        for e in 0 to COUNT_MAX-1 loop
          v(0).elements(e) := (others => 'U');
        end loop;
      end if;
      --pragma translate on
    
      -- Loop over all stages
      for s in 1 to STAGES-1 loop

        -- Only shift if we still have to shift
        if r(s-1).rotate /= ROTATE_ZERO then

          -- The maximum shift amount in a stage is COUNT_MAX / STAGES, assuming
          -- COUNT_MAX is a power of 2 and stages is a multiple of 2.
          -- TODO: support this? do we need this?

          if DIRECTION = "left" then
            -- Shift left
            for e in 0 to COUNT_MAX-1 loop
              if OPERATION = "rotate" then
                -- Rotation
                v(s).elements(e) := r(s-1).elements((e-1) mod COUNT_MAX);
              else
                -- Shifting
                if e = 0 then
                  v(s).elements(e) := (others => '0');
                else
                  v(s).elements(e) := r(s-1).elements((e-1));
                end if;
              end if;
            end loop;
          else
            -- Shift right
            for e in 0 to COUNT_MAX-1 loop
              if OPERATION = "rotate" then
                -- Rotation
                v(s).elements(e) := r(s-1).elements((e+1) mod COUNT_MAX);
              else
                -- Shifting
                if e = COUNT_MAX-1 then
                  v(s).elements(e) := (others => '0');
                else
                  v(s).elements(e) := r(s-1).elements((e+1));
                end if;
              end if;
            end loop;
          end if;

          -- Decrease shift amount
          v(s).rotate := r(s-1).rotate - 1;
        else
          -- We are done shifting, just pass through the elements
          v(s).elements := r(s-1).elements;
          v(s).rotate := r(s-1).rotate;
        end if;

        v(s).valid := r(s-1).valid;
        v(s).ctrl := r(s-1).ctrl;

      end loop;
    end if;
        
    d <= v;
    
    in_ready <= i.ready;
        
  end process;
  
  out_gen: for e in 0 to COUNT_MAX-1 generate
    out_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) <= r(STAGES-1).elements(e);
  end generate;
  
  out_ctrl <= r(STAGES-1).ctrl;
  out_valid <= r(STAGES-1).valid;

end Behavioral;

