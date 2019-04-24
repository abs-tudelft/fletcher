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

entity primmap is
  generic(
    TAG_WIDTH                                   : natural;
    BUS_ADDR_WIDTH                              : natural;
    INDEX_WIDTH                                 : natural;
    REG_WIDTH                                   : natural
  );
  port(
    primread_out_last                           : in std_logic;
    primwrite_in_last                           : out std_logic;
    primwrite_in_ready                          : in std_logic;
    primwrite_in_valid                          : out std_logic;
    primread_cmd_primread_values_addr           : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    primread_cmd_tag                            : out std_logic_vector(TAG_WIDTH-1 downto 0);
    primread_cmd_lastIdx                        : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    primread_cmd_firstIdx                       : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    primread_cmd_ready                          : in std_logic;
    primread_cmd_valid                          : out std_logic;
    primread_out_data                           : in std_logic_vector(7 downto 0);
    primread_out_ready                          : out std_logic;
    primread_out_valid                          : in std_logic;
    primwrite_in_data                           : out std_logic_vector(7 downto 0);
    primwrite_cmd_valid                         : out std_logic;
    primwrite_cmd_ready                         : in std_logic;
    primwrite_cmd_firstIdx                      : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    primwrite_cmd_lastIdx                       : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    primwrite_cmd_tag                           : out std_logic_vector(TAG_WIDTH-1 downto 0);
    primwrite_cmd_primwrite_values_addr         : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    -------------------------------------------------------------------------
    acc_reset                                   : in std_logic;
    acc_clk                                     : in std_logic;
    -------------------------------------------------------------------------
    ctrl_done                                   : out std_logic;
    ctrl_busy                                   : out std_logic;
    ctrl_idle                                   : out std_logic;
    ctrl_reset                                  : in std_logic;
    ctrl_stop                                   : in std_logic;
    ctrl_start                                  : in std_logic;
    -------------------------------------------------------------------------
    reg_return0                                 : out std_logic_vector(REG_WIDTH-1 downto 0);
    reg_return1                                 : out std_logic_vector(REG_WIDTH-1 downto 0);
    reg_primread_values_addr                    : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    reg_primwrite_values_addr                   : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)
  );
end entity;

architecture Behavioral of primmap is
  constant MAX_STR_LEN : natural := 32;
begin
  process is
    variable idx : natural := 0;
  begin
    -- Initial outputs
    ctrl_busy <= '0';
    ctrl_done <= '0';
    ctrl_idle <= '0';
    
    primread_cmd_valid <= '0';
    primwrite_cmd_valid <= '0';
    
    primread_out_ready <= '0';
    primwrite_in_valid <= '0';
    primwrite_in_last  <= '0';
    
    -- Wait for reset to go low and start to go high.
    loop
      wait until rising_edge(acc_clk);
      exit when ctrl_reset = '0' and ctrl_start = '1';
    end loop;
    
    ctrl_busy <= '1';
        
    -- Issue the commands
    primread_cmd_firstIdx <= (others => '0');
    primread_cmd_lastIdx <= std_logic_vector(to_unsigned(4, INDEX_WIDTH));
    primread_cmd_primread_values_addr <= reg_primread_values_addr;
    primread_cmd_valid <= '1';

    -- Wait for read command to be accepted.
    loop
      wait until rising_edge(acc_clk);
      exit when primread_cmd_ready = '1';
    end loop;
    primread_cmd_valid <= '0';    

    primwrite_cmd_firstIdx <= (others => '0');
    primwrite_cmd_lastIdx <= std_logic_vector(to_unsigned(4, INDEX_WIDTH));
    -- Write to some buffer that should normally be preallocated and passed
    -- through registers
    primwrite_cmd_primwrite_values_addr <= X"0000000000000000";
    primwrite_cmd_valid <= '1';
    
    -- Wait for write command to be accepted.
    loop
      wait until rising_edge(acc_clk);
      exit when primwrite_cmd_ready = '1';
    end loop;
    primwrite_cmd_valid <= '0';
    
    -- Receive the primitives
    loop 
      primread_out_ready <= '1';
      loop
        wait until rising_edge(acc_clk);
        exit when primread_out_valid = '1';
      end loop;
      primread_out_ready <= '0';
      
      -- Add one to the input and put it on the output.
      primwrite_in_data <= std_logic_vector(unsigned(primread_out_data)+1);
      
      -- Check if this is the last primitive
      if (idx = 3) then
        primwrite_in_last <= '1';
      end if;
      
      -- Wait for handshake
      primwrite_in_valid <= '1';
      loop
        wait until rising_edge(acc_clk);
        exit when primwrite_in_ready = '1';
      end loop;
      primwrite_in_valid <= '0';
      
      idx := idx + 1;
      exit when idx = 4;
    end loop;
        
    -- Wait a few extra cycles ... 
    -- (normally you should use unlock stream for this)
    for I in 0 to 128 loop
        wait until rising_edge(acc_clk);
    end loop;
    
    -- Signal done to the usercore controller
    ctrl_busy <= '0';
    ctrl_done <= '1';
    wait;
  end process;
end Behavioral;
