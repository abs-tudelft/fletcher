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
use work.SimUtils.all;

-- Example simulation-only User Core for the string read example.
-- This user core is not synthesizable.
entity test is
  generic(
    TAG_WIDTH                                  : natural;
    BUS_ADDR_WIDTH                             : natural;
    INDEX_WIDTH                                : natural;
    REG_WIDTH                                  : natural
  );
  port(
    Name_out_values_out_data                   : in std_logic_vector(31 downto 0);
    Name_out_values_out_count                  : in std_logic_vector(2 downto 0);
    Name_out_values_out_dvalid                 : in std_logic;
    Name_out_values_out_last                   : in std_logic;
    Name_out_values_out_ready                  : out std_logic;
    Name_out_values_out_valid                  : in std_logic;
    Name_out_valid                             : in std_logic;
    Name_out_ready                             : out std_logic;
    Name_out_length                            : in std_logic_vector(INDEX_WIDTH-1 downto 0);
    Name_out_last                              : in std_logic;
    Name_cmd_valid                             : out std_logic;
    Name_cmd_ready                             : in std_logic;
    Name_cmd_firstIdx                          : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    Name_cmd_lastIdx                           : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    Name_cmd_tag                               : out std_logic_vector(TAG_WIDTH-1 downto 0);
    Name_cmd_Name_values_addr                  : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    Name_cmd_Name_offsets_addr                 : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    -------------------------------------------------------------------------
    acc_reset                                  : in std_logic;
    acc_clk                                    : in std_logic;
    -------------------------------------------------------------------------
    ctrl_done                                  : out std_logic;
    ctrl_busy                                  : out std_logic;
    ctrl_idle                                  : out std_logic;
    ctrl_reset                                 : in std_logic;
    ctrl_stop                                  : in std_logic;
    ctrl_start                                 : in std_logic;
    -------------------------------------------------------------------------
    idx_first                                  : in std_logic_vector(REG_WIDTH-1 downto 0);
    idx_last                                   : in std_logic_vector(REG_WIDTH-1 downto 0);
    reg_return0                                : out std_logic_vector(REG_WIDTH-1 downto 0);
    reg_return1                                : out std_logic_vector(REG_WIDTH-1 downto 0);
    reg_Name_values_addr                       : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    reg_Name_offsets_addr                      : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)
  );
end test;

architecture Behavioral of test is
  constant MAX_STR_LEN : natural := 32;
begin
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
    -- Initial outputs
    ctrl_busy <= '0';
    ctrl_done <= '0';
    ctrl_idle <= '0';
    Name_cmd_valid <= '0';
    Name_out_ready <= '0';
    Name_out_values_out_ready <= '0';

    -- Wait for reset to go low and start to go high.
    loop
      wait until rising_edge(acc_clk);
      exit when ctrl_reset = '0' and ctrl_start = '1';
    end loop;

    ctrl_busy <= '1';

    -- Issue the command:
    -- Typically, the parameters for first index, last index should be passed
    -- through by user registers.
    Name_cmd_firstIdx <= (others => '0');
    Name_cmd_lastIdx <= std_logic_vector(to_unsigned(26, INDEX_WIDTH));
    -- The addresses can be taken from the registers, but they are passed
    -- through the user core. In this way, the user can create new buffers
    -- without communicating with host software.
    Name_cmd_Name_offsets_addr <= reg_Name_offsets_addr;
    Name_cmd_Name_values_addr <= reg_Name_values_addr;
    -- Validate the command.
    Name_cmd_valid <= '1';

    -- Wait for command to be accepted.
    loop
      wait until rising_edge(acc_clk);
      exit when Name_cmd_ready = '1';
    end loop;
    Name_cmd_valid <= '0';

    loop
      -- Receive a string length

      -- Wait for valid length
      Name_out_ready <= '1';
      loop
        wait until rising_edge(acc_clk);
        exit when Name_out_valid = '1';
      end loop;

      -- Save the string length, reset the current character and the string
      current_char := 0;
      string_length := to_integer(unsigned(Name_out_length));
      for I in 1 to MAX_STR_LEN loop
        str(I) := nul;
      end loop;

      -- Check if this is the last string
      is_last := Name_out_last = '1';

      -- Not ready to receive a new length at the moment.
      Name_out_ready <= '0';

      -- dumpStdOut("Received a string length of " & integer'image(string_length));

      -- Obtain all string characters
      loop

        Name_out_values_out_ready <= '1';

        -- Wait for handshake
        loop
          wait until rising_edge(acc_clk);
          exit when Name_out_values_out_valid = '1';
        end loop;

        -- Check the number of characters delivered
        num_chars := to_integer(unsigned(Name_out_values_out_count));
        --dumpStdOut("Received " & integer'image(num_chars) & " character(s).");

        -- For each character in the output
        for I in 0 to num_chars-1 loop
          -- Convert the std_logic_vector part to a character
          int_char := to_integer(unsigned(Name_out_values_out_data(8*(i+1)-1 downto 8*i)));
          char := character'val(int_char);

          -- Set the character in the string
          str(1+current_char) := char;

          current_char := current_char + 1;
        end loop;

        -- check if this is the last (bunch of) characters
        is_last_char := Name_out_values_out_last = '1';

        exit when is_last_char;
      end loop;

      Name_out_values_out_ready <= '0';

      -- Check if the string length and the number of characters received is
      -- correct
      assert(current_char = string_length)
        report "String length expected to be zero on last signal, " &
                integer'image(string_length) & " instead."
        severity failure;

      -- Dump the string to the output
      dumpStdOut("String " & integer'image(string_idx) & " : " & str);

      string_idx := string_idx + 1;

      -- If this was the last string, exit the loop
      exit when is_last;
    end loop;

    -- Wait a few extra cycles ...
    -- (normally you should use unlock stream for this)
    for I in 0 to 3 loop
        wait until rising_edge(acc_clk);
    end loop;

    -- Signal done to the usercore controller
    ctrl_busy <= '0';
    ctrl_done <= '1';
    wait;
  end process;

end architecture;
