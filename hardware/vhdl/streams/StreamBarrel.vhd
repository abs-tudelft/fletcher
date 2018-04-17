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
    ELEMENT_WIDTH               : natural := 1;

    -- Maximum number of elements per clock.
    COUNT_MAX                   : natural := 4;

    -- Width of the amount input
    AMOUNT_WIDTH                : natural := 3;
    
    -- Maximum shift/rotate
    AMOUNT_MAX                  : natural := 3;

    -- Direction of the rotation
    DIRECTION                   : string := "left";
    
    -- Operation; shift or rotate
    OPERATION                   : string := "rotate";

    -- The number of pipelined stages to use to make the rotation
    STAGES                      : natural := 4;
    
    -- Whether or not this unit uses the "out_ready" signal. Make false to
    -- disable backpressure but to remove high fan-out on the out_ready signal.
    BACKPRESSURE                : boolean := false;

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

  constant STAGE_EXT            : natural := STAGES + 1;
  constant STAGE_MAX            : natural := AMOUNT_MAX / STAGES;
  constant STAGE_ROT_BITS       : natural := log2ceil(STAGE_MAX+1);
  
  -- Prevent simulator spam
  type u_array is array(natural range <>) of unsigned(STAGE_ROT_BITS-1 downto 0);
  
  function fill_stage_rot_array(bits : natural) return u_array is
    variable ret : u_array(1 to 2**bits-1);
  begin
    for i in 1 to 2**bits-1 loop
      ret(i) := to_unsigned(i, bits);
    end loop;
    return ret;
  end function;
  
  constant STAGE_ROT : u_array(1 to 2**STAGE_ROT_BITS-1) := fill_stage_rot_array(STAGE_ROT_BITS);
  
  -- Internal rotate signal width
  constant ROT_WIDTH : natural := work.Utils.max(STAGE_ROT_BITS, AMOUNT_WIDTH);
  constant ROT_MAX   : unsigned(ROT_WIDTH-1 downto 0) := to_unsigned(STAGE_MAX, ROT_WIDTH);

  type in_type is record
    ready                       : std_logic;
  end record;
  
  type element_array_type is array(COUNT_MAX-1 downto 0) of std_logic_vector(ELEMENT_WIDTH-1 downto 0);

  type pipeline_reg_type is record
    elements : element_array_type;
    rotate   : unsigned(ROT_WIDTH-1 downto 0);

    valid    : std_logic;
    ctrl     : std_logic_vector(CTRL_WIDTH-1 downto 0);
  end record;
  
  -- Prevent simulator spam
  constant ROTATE_ZERO : unsigned(AMOUNT_WIDTH-1 downto 0) := (others => '0');

  type pipeline_type is array(0 to STAGE_EXT-1) of pipeline_reg_type;

  signal r : pipeline_type;
  signal d : pipeline_type;

begin

  seq_proc: process(clk) is
  begin
    if rising_edge(clk) then
      r <= d;
      
      if reset = '1' then
        -- Invalidate all data
        for i in 0 to STAGE_EXT-1 loop
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
    
    variable rot_sub : unsigned(ROT_WIDTH-1 downto 0) := (others => '0');
  begin
    v := r;
    
    -- Input is ready when valid by default
    if in_valid = '1' then
      i.ready := '1';
    else
      i.ready := '0';
    end if;

    if BACKPRESSURE then
      -- If the output stage is valid, but not handshaked, the input must be 
      -- stalled immediately
      if r(STAGE_EXT-1).valid = '1' and out_ready = '0' then
        i.ready := '0';
      end if;
              
      -- If the output is handshaked, lower the output valid by default.
      if r(STAGE_EXT-1).valid = '1' and out_ready = '1' then
        v(STAGE_EXT-1).valid := '0';
      end if;
    end if;
    
    if BACKPRESSURE then
      -- Check if the pipeline has data anywhere
      has_data := in_valid;
      
      for s in 0 to STAGE_EXT-1 loop
        has_data := has_data or v(s).valid;
      end loop;
    end if;

    -- We don't use backpressure,
    -- or the pipeline still has data and we do use backpressure and
    -- the output has no data, or is handshaked, we may advance the stream
    if  (not BACKPRESSURE) or 
        (has_data = '1' and 
          (r(STAGE_EXT-1).valid = '0' or 
            (r(STAGE_EXT-1).valid = '1' and out_ready = '1')
          )
        )
    then
      -- Grab inputs
      v(0).valid := in_valid and i.ready;
      v(0).rotate := resize(unsigned(in_rotate), ROT_WIDTH);
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
      for s in 1 to STAGE_EXT-1 loop
        rot_sub := (others => '0');
        -- Only shift if we still have to shift
        if r(s-1).rotate /= ROTATE_ZERO then
          -- Calculate how much we will rotate in this stage
          rot_sub := ROT_MAX;
          for a in 1 to STAGE_MAX-1 loop
            if STAGE_ROT(a) = r(s-1).rotate(STAGE_ROT_BITS-1 downto 0) then
              rot_sub := resize(STAGE_ROT(a),ROT_WIDTH);
            end if;
          end loop;
                    
          if DIRECTION = "left" then
            -- Loop over all elements
            for e in 0 to COUNT_MAX-1 loop
              if OPERATION = "rotate" then                
                -- Rotate maximum by default
                v(s).elements(e) := r(s-1).elements((e-STAGE_MAX) mod COUNT_MAX);
                -- Loop over all other possible rotations
                for a in 1 to STAGE_MAX-1 loop
                  if STAGE_ROT(a) = r(s-1).rotate(STAGE_ROT_BITS-1 downto 0) then
                    v(s).elements(e) := r(s-1).elements((e-a) mod COUNT_MAX);
                  end if;
                end loop;
              else
                -- Shift maximum by default
                if e >= STAGE_MAX then
                  v(s).elements(e) := r(s-1).elements(e-STAGE_MAX);
                else
                  v(s).elements(e) := (others => '0');
                end if;
                -- Loop over all other possible shifts
                for a in 1 to STAGE_MAX-1 loop
                  if STAGE_ROT(a) = r(s-1).rotate(STAGE_ROT_BITS-1 downto 0) then
                    if e-a < 0 then
                      v(s).elements(e) := (others => '0');
                    else
                      v(s).elements(e) := r(s-1).elements(e-a);
                    end if;
                  end if;
                end loop;
              end if;
            end loop;
          else
            -- Loop over all elements
            for e in 0 to COUNT_MAX-1 loop
              if OPERATION = "rotate" then                
                -- Rotate maximum by default
                v(s).elements(e) := r(s-1).elements((e+STAGE_MAX) mod COUNT_MAX);
                -- Loop over all other possible rotations
                for a in 1 to STAGE_MAX-1 loop
                  if STAGE_ROT(a) = r(s-1).rotate(STAGE_ROT_BITS-1 downto 0) then
                    v(s).elements(e) := r(s-1).elements((e+a) mod COUNT_MAX);
                  end if;
                end loop;
              else
                -- Shift maximum by default
                v(s).elements(e) := r(s-1).elements(e+STAGE_MAX);
                if e < COUNT_MAX - STAGE_MAX then
                  v(s).elements(e) := r(s-1).elements(e+STAGE_MAX);
                else
                  v(s).elements(e) := (others => '0');
                end if;
                -- Loop over all other possible shifts
                for a in 1 to STAGE_MAX-1 loop
                  if STAGE_ROT(a) = r(s-1).rotate(STAGE_ROT_BITS-1 downto 0) then
                    if e-a < 0 then
                      v(s).elements(e) := (others => '0');
                    else
                      v(s).elements(e) := r(s-1).elements(e+a);
                    end if;
                  end if;
                end loop;
              end if;
            end loop;
          end if;
        else
          -- We are done shifting, just pass through the elements
          v(s).elements := r(s-1).elements;
          v(s).rotate := r(s-1).rotate;
        end if;
        
        -- Decrease shift amount
        v(s).rotate := r(s-1).rotate - rot_sub;
        
        -- Send out ctrl from last stage
        v(s).ctrl := r(s-1).ctrl;
        
        -- Take valid from last stage
        v(s).valid := r(s-1).valid;

      end loop;
    end if;
        
    d <= v;
    
    in_ready <= i.ready;
        
  end process;
  
  out_gen: for e in 0 to COUNT_MAX-1 generate
    out_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) <= r(STAGE_EXT-1).elements(e);
  end generate;
  
  out_ctrl <= r(STAGE_EXT-1).ctrl;
  out_valid <= r(STAGE_EXT-1).valid;

end Behavioral;

