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

package UTF8StringGen_pkg is
  component UTF8StringGen is
    generic (
      INDEX_WIDTH               : natural :=   32;
      ELEMENT_WIDTH             : natural :=    8;
      ELEMENT_COUNT_MAX         : natural :=    8;
      ELEMENT_COUNT_WIDTH       : natural :=    4;

      LEN_WIDTH                 : natural :=    8;

      LENGTH_BUFFER_DEPTH       : natural :=    8;

      LEN_SLICE                 : boolean := true;
      UTF8_SLICE                : boolean := true
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;

      cmd_valid                 : in  std_logic;
      cmd_ready                 : out std_logic;
      cmd_len                   : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
      cmd_strlen_min            : in  std_logic_vector(LEN_WIDTH-1 downto 0);
      cmd_strlen_mask           : in  std_logic_vector(LEN_WIDTH-1 downto 0);

      len_valid                 : out std_logic;
      len_ready                 : in  std_logic;
      len_data                  : out std_logic_vector(INDEX_WIDTH-1 downto 0);
      len_last                  : out std_logic;
      len_dvalid                : out std_logic;

      utf8_valid                : out std_logic;
      utf8_ready                : in  std_logic;
      utf8_data                 : out std_logic_vector(ELEMENT_COUNT_MAX * ELEMENT_WIDTH-1 downto 0);
      utf8_count                : out std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
      utf8_last                 : out std_logic;
      utf8_dvalid               : out std_logic
    );
  end component;
  
  function readable_utf8 (prng_data: std_logic_vector) return unsigned;
    
end UTF8StringGen_pkg;

package body UTF8StringGen_pkg is

  -- Make "readable" UTF8 Final range will be between space and ~
  function readable_utf8 (prng_data: std_logic_vector) 
    return unsigned 
  is
    constant startc  : natural := 32;
    variable char : unsigned(7 downto 0);
  begin
    char := (others => '0');
    
    -- We can only get 0..127
    char(6 downto 0) := unsigned(prng_data(6 downto 0));
    
    -- Make a '.' out of the character if it's any control character
    if char < startc then
      char := to_unsigned(46, 8);
    end if;
    if char = 127 then
      char := to_unsigned(46, 8);
    end if;
    
    return char;
  end function;
  
end UTF8StringGen_pkg;
