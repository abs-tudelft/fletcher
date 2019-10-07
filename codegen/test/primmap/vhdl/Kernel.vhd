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

-- Simulation-only primitive mapping kernel for testing purposes.
--
-- This kernel performs the following map transformation:
--   number --> abs(number) + add
--
-- It also calculates the sum of the input and outputs that on the sum register.
entity Kernel is
  port (
    kcd_clk                       : in  std_logic;
    kcd_reset                     : in  std_logic;
    start                         : in  std_logic;
    stop                          : in  std_logic;
    reset                         : in  std_logic;
    idle                          : out std_logic;
    busy                          : out std_logic;
    done                          : out std_logic;
    result                        : out std_logic_vector(63 downto 0);
    add                           : in  std_logic_vector(7 downto 0);
    sum                           : out std_logic_vector(31 downto 0);
    PrimRead_firstidx             : in  std_logic_vector(31 downto 0);
    PrimRead_lastidx              : in  std_logic_vector(31 downto 0);
    PrimWrite_firstidx            : in  std_logic_vector(31 downto 0);
    PrimWrite_lastidx             : in  std_logic_vector(31 downto 0);
    PrimRead_number_valid         : in  std_logic;
    PrimRead_number_ready         : out std_logic;
    PrimRead_number_dvalid        : in  std_logic;
    PrimRead_number_last          : in  std_logic;
    PrimRead_number               : in  std_logic_vector(7 downto 0);
    PrimRead_number_unl_valid     : in  std_logic;
    PrimRead_number_unl_ready     : out std_logic;
    PrimRead_number_unl_tag       : in  std_logic_vector(0 downto 0);
    PrimRead_number_cmd_valid     : out std_logic;
    PrimRead_number_cmd_ready     : in  std_logic;
    PrimRead_number_cmd_firstIdx  : out std_logic_vector(31 downto 0);
    PrimRead_number_cmd_lastidx   : out std_logic_vector(31 downto 0);
    PrimRead_number_cmd_tag       : out std_logic_vector(0 downto 0);
    PrimWrite_number_valid        : out std_logic;
    PrimWrite_number_ready        : in  std_logic;
    PrimWrite_number_dvalid       : out std_logic;
    PrimWrite_number_last         : out std_logic;
    PrimWrite_number              : out std_logic_vector(7 downto 0);
    PrimWrite_number_unl_valid    : in  std_logic;
    PrimWrite_number_unl_ready    : out std_logic;
    PrimWrite_number_unl_tag      : in  std_logic_vector(0 downto 0);
    PrimWrite_number_cmd_valid    : out std_logic;
    PrimWrite_number_cmd_ready    : in  std_logic;
    PrimWrite_number_cmd_firstIdx : out std_logic_vector(31 downto 0);
    PrimWrite_number_cmd_lastidx  : out std_logic_vector(31 downto 0);
    PrimWrite_number_cmd_tag      : out std_logic_vector(0 downto 0)
  );
end entity;

architecture Implementation of Kernel is
begin
  process is
    variable idx        : natural            := 0;
    variable number_in  : signed(7 downto 0) := (others => '0');
    variable number_out : signed(7 downto 0) := (others => '0');
    variable number_sum : signed(31 downto 0) := (others => '0');
  begin
    -- Initial outputs
    busy <= '0';
    done <= '0';
    idle <= '0';

    PrimRead_number_cmd_valid <= '0';
    PrimWrite_number_cmd_valid <= '0';

    PrimRead_number_ready <= '0';
    PrimWrite_number_valid <= '0';
    PrimWrite_number_last  <= '0';

    -- Wait for reset to go low and start to go high.
    loop
      wait until rising_edge(kcd_clk);
      exit when reset = '0' and start = '1';
    end loop;

    busy <= '1';

    -- Issue the command
    PrimRead_number_cmd_firstIdx  <= PrimRead_firstidx;
    PrimRead_number_cmd_lastIdx   <= PrimRead_lastidx;
    PrimRead_number_cmd_valid     <= '1';

    -- Wait for read command to be accepted.
    loop
      wait until rising_edge(kcd_clk);
      exit when PrimRead_number_cmd_ready = '1';
    end loop;

    PrimRead_number_cmd_valid <= '0';

    PrimWrite_number_cmd_firstIdx  <= PrimWrite_firstidx;
    PrimWrite_number_cmd_lastIdx   <= PrimWrite_lastidx;
    PrimWrite_number_cmd_valid     <= '1';

    -- Wait for write command to be accepted.
    loop
      wait until rising_edge(kcd_clk);
      exit when PrimWrite_number_cmd_ready = '1';
    end loop;
    PrimWrite_number_cmd_valid <= '0';

    -- Receive the primitives
    loop
      PrimRead_number_ready <= '1';
      loop
        wait until rising_edge(kcd_clk);
        exit when PrimRead_number_valid = '1';
      end loop;
      PrimRead_number_ready <= '0';

      -- Convert to signed integer
      number_in := signed(PrimRead_number);

      -- Calculate the sum of the input.
      number_sum := number_sum + number_in;

      -- Take the absolute value because ABS awesome. Then, add the "add" mmio
      -- input.
      number_out := abs(number_in) + signed(add);

      -- Put the transformed value to the output.
      PrimWrite_number <= std_logic_vector(number_out);
      
      -- Put the sum onto the output mmio reg.
      sum <= std_logic_vector(number_sum);

      -- Check if this is the last primitive
      if idx = to_integer(unsigned(PrimRead_lastidx))-1 then
        PrimWrite_number_last <= '1';
      end if;

      -- Validate the input and wait for handshake
      PrimWrite_number_valid <= '1';
      loop
        wait until rising_edge(kcd_clk);
        exit when PrimWrite_number_ready = '1';
      end loop;

      println("Number (in) " & sgnToDec(number_in) & " --> " & sgnToDec(number_out) & " (out)");
      
      PrimWrite_number_valid <= '0';

      idx := idx + 1;
      exit when idx = 4;
    end loop;

    -- Wait a few extra cycles ...
    -- (normally you should use unlock stream for this)
    for I in 0 to 128 loop
        wait until rising_edge(kcd_clk);
    end loop;

    -- Signal done to the usercore controller
    busy <= '0';
    done <= '1';
    wait;
  end process;
end Implementation;
