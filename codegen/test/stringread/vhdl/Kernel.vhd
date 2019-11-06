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
use work.Axi_pkg.all;
use work.UtilStr_pkg.all;

entity Kernel is
  generic (
    INDEX_WIDTH : integer := 32;
    TAG_WIDTH   : integer := 1
  );
  port (
    kcd_clk                      : in  std_logic;
    kcd_reset                    : in  std_logic;
    StringRead_Name_valid        : in  std_logic;
    StringRead_Name_ready        : out std_logic;
    StringRead_Name_dvalid       : in  std_logic;
    StringRead_Name_last         : in  std_logic;
    StringRead_Name_count        : in  std_logic_vector(0 downto 0);
    StringRead_Name_length       : in  std_logic_vector(31 downto 0);
    StringRead_Name_chars_valid  : in  std_logic;
    StringRead_Name_chars_ready  : out std_logic;
    StringRead_Name_chars_dvalid : in  std_logic;
    StringRead_Name_chars_count  : in  std_logic_vector(2 downto 0);
    StringRead_Name_chars_last   : in  std_logic;
    StringRead_Name_chars        : in  std_logic_vector(31 downto 0);
    StringRead_Name_unl_valid    : in  std_logic;
    StringRead_Name_unl_ready    : out std_logic;
    StringRead_Name_unl_tag      : in  std_logic_vector(TAG_WIDTH-1 downto 0);
    StringRead_Name_cmd_valid    : out std_logic;
    StringRead_Name_cmd_ready    : in  std_logic;
    StringRead_Name_cmd_firstIdx : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    StringRead_Name_cmd_lastIdx  : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    StringRead_Name_cmd_tag      : out std_logic_vector(TAG_WIDTH-1 downto 0);
    start                        : in  std_logic;
    stop                         : in  std_logic;
    reset                        : in  std_logic;
    idle                         : out std_logic;
    busy                         : out std_logic;
    done                         : out std_logic;
    result                       : out std_logic_vector(63 downto 0);
    StringRead_firstidx          : in  std_logic_vector(31 downto 0);
    StringRead_lastidx           : in  std_logic_vector(31 downto 0)
  );
end entity;

architecture Implementation of Kernel is
  constant MAX_STR_LEN          : natural := 128;
begin
  -- Stringread kernel example (simulation only)
  process is
    variable string_idx    : natural := 0;
    variable string_length : natural := 0;
    variable current_char  : natural := 0;
    variable num_chars     : natural := 0;
    variable is_last       : boolean := false;
    variable is_last_char  : boolean := false;
    variable int_char      : integer := 0;
    variable char          : character := '0';
    variable str           : string(1 to MAX_STR_LEN);
  begin
    -- Initial status outputs
    idle <= '1';
    busy <= '0';
    done <= '0';
    
    -- Initial Fletcher streams handshake signals
    StringRead_Name_cmd_valid <= '0';
    StringRead_Name_ready <= '0';
    StringRead_Name_chars_ready <= '0';

    -- Wait for reset to go low and start to go high.
    loop
      wait until rising_edge(kcd_clk);
      exit when reset = '0' and start = '1';
    end loop;

    busy <= '1';

    -- Issue the command:
    StringRead_Name_cmd_firstIdx <= StringRead_firstidx;
    StringRead_Name_cmd_lastIdx  <= StringRead_lastidx;
                   
    -- Validate the command.
    StringRead_Name_cmd_valid <= '1';

    -- Wait for command to be accepted.
    loop
      wait until rising_edge(kcd_clk);
      exit when StringRead_Name_cmd_ready = '1';
    end loop;
    StringRead_Name_cmd_valid <= '0';

    loop
      -- Receive a string length

      -- Wait for valid length
      StringRead_Name_ready <= '1';
      loop
        wait until rising_edge(kcd_clk);
        exit when StringRead_Name_valid = '1';
      end loop;

      -- Save the string length, reset the current character and the string
      current_char := 0;
      string_length := to_integer(unsigned(StringRead_Name_length));
      for I in 1 to MAX_STR_LEN loop
        str(I) := nul;
      end loop;

      -- Check if this is the last string
      is_last := StringRead_Name_last = '1';

      -- Not ready to receive a new length at the moment.
      StringRead_Name_ready <= '0';

      -- Obtain all string characters
      loop

        StringRead_Name_chars_ready <= '1';

        -- Wait for handshake
        loop
          wait until rising_edge(kcd_clk);
          exit when StringRead_Name_chars_valid = '1';
        end loop;

        -- Check the number of characters delivered
        num_chars := to_integer(unsigned(StringRead_Name_chars_count));

        -- For each character in the output
        for I in 0 to num_chars-1 loop
          -- Convert the std_logic_vector part to a character
          int_char := to_integer(unsigned(StringRead_Name_chars(8*(i+1)-1 downto 8*i)));
          char := character'val(int_char);

          -- Set the character in the string
          str(1+current_char) := char;

          current_char := current_char + 1;
        end loop;

        -- check if this is the last (bunch of) characters
        is_last_char := StringRead_Name_chars_last = '1';

        exit when is_last_char;
      end loop;

      StringRead_Name_chars_ready <= '0';

      -- Check if the string length and the number of characters received is
      -- correct
      assert(current_char = string_length)
        report "String length expected to be zero on last signal, " &
                integer'image(string_length) & " instead."
        severity failure;

      -- Dump the string to the output
      println("String " & integer'image(string_idx) & " : " & str);

      string_idx := string_idx + 1;

      -- If this was the last string, exit the loop
      exit when is_last;
    end loop;

    -- Wait a few extra cycles ...
    -- (normally you should use unlock stream for this)
    for I in 0 to 3 loop
        wait until rising_edge(kcd_clk);
    end loop;

    -- Signal done to the usercore controller
    busy <= '0';
    done <= '1';
    wait;
  end process;


end architecture;
