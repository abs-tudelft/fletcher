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

-- Simulation-only kernel for testing purposes.
--
-- This kernel performs the following map transformation between two array pairs.
--   number --> abs(number) + add
--
-- It also calculates the sum of the input and outputs that on the sum register.
entity Kernel is
  generic (
    INDEX_WIDTH : integer := 32;
    TAG_WIDTH   : integer := 1
  );
  port (
    kcd_clk          : in  std_logic;
    kcd_reset        : in  std_logic;
    R_A_valid        : in  std_logic;
    R_A_ready        : out std_logic;
    R_A_dvalid       : in  std_logic;
    R_A_last         : in  std_logic;
    R_A              : in  std_logic_vector(7 downto 0);
    R_B_valid        : in  std_logic;
    R_B_ready        : out std_logic;
    R_B_dvalid       : in  std_logic;
    R_B_last         : in  std_logic;
    R_B              : in  std_logic_vector(7 downto 0);
    R_A_unl_valid    : in  std_logic;
    R_A_unl_ready    : out std_logic;
    R_A_unl_tag      : in  std_logic_vector(TAG_WIDTH-1 downto 0);
    R_B_unl_valid    : in  std_logic;
    R_B_unl_ready    : out std_logic;
    R_B_unl_tag      : in  std_logic_vector(TAG_WIDTH-1 downto 0);
    R_A_cmd_valid    : out std_logic;
    R_A_cmd_ready    : in  std_logic;
    R_A_cmd_firstIdx : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    R_A_cmd_lastIdx  : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    R_A_cmd_tag      : out std_logic_vector(TAG_WIDTH-1 downto 0);
    R_B_cmd_valid    : out std_logic;
    R_B_cmd_ready    : in  std_logic;
    R_B_cmd_firstIdx : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    R_B_cmd_lastIdx  : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    R_B_cmd_tag      : out std_logic_vector(TAG_WIDTH-1 downto 0);
    W_C_valid        : out std_logic;
    W_C_ready        : in  std_logic;
    W_C_dvalid       : out std_logic;
    W_C_last         : out std_logic;
    W_C              : out std_logic_vector(7 downto 0);
    W_D_valid        : out std_logic;
    W_D_ready        : in  std_logic;
    W_D_dvalid       : out std_logic;
    W_D_last         : out std_logic;
    W_D              : out std_logic_vector(7 downto 0);
    W_C_unl_valid    : in  std_logic;
    W_C_unl_ready    : out std_logic;
    W_C_unl_tag      : in  std_logic_vector(TAG_WIDTH-1 downto 0);
    W_D_unl_valid    : in  std_logic;
    W_D_unl_ready    : out std_logic;
    W_D_unl_tag      : in  std_logic_vector(TAG_WIDTH-1 downto 0);
    W_C_cmd_valid    : out std_logic;
    W_C_cmd_ready    : in  std_logic;
    W_C_cmd_firstIdx : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    W_C_cmd_lastIdx  : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    W_C_cmd_tag      : out std_logic_vector(TAG_WIDTH-1 downto 0);
    W_D_cmd_valid    : out std_logic;
    W_D_cmd_ready    : in  std_logic;
    W_D_cmd_firstIdx : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    W_D_cmd_lastIdx  : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    W_D_cmd_tag      : out std_logic_vector(TAG_WIDTH-1 downto 0);
    start            : in  std_logic;
    stop             : in  std_logic;
    reset            : in  std_logic;
    idle             : out std_logic;
    busy             : out std_logic;
    done             : out std_logic;
    result           : out std_logic_vector(63 downto 0);
    R_firstidx       : in  std_logic_vector(31 downto 0);
    R_lastidx        : in  std_logic_vector(31 downto 0);
    W_firstidx       : in  std_logic_vector(31 downto 0);
    W_lastidx        : in  std_logic_vector(31 downto 0);
    add              : in  std_logic_vector(7 downto 0);
    sum              : out std_logic_vector(31 downto 0)
  );
end entity;

architecture Implementation of Kernel is
  procedure command(signal c            : in  std_logic;
                    signal r    		    : in  std_logic;
                    signal firstidx     : in  std_logic_vector(31 downto 0);
                    signal lastidx      : in  std_logic_vector(31 downto 0);
                    signal firstidx_out : out std_logic_vector(31 downto 0);
                    signal lastidx_out  : out std_logic_vector(31 downto 0);
                    signal valid		    : out std_logic;
                    signal ready        : in  std_logic)
  is begin
    firstidx_out <= firstidx;
    lastidx_out  <= lastidx;
    valid        <= '1';
    -- wait for acceptance
    loop
      wait until rising_edge(c);
      exit when ready = '1';
      exit when reset = '1';
    end loop;
    valid <= '0';
  end procedure;
  
  procedure transform(signal c        : in  std_logic;
                      signal r        : in  std_logic;
                      
                      signal si_add   : in  std_logic_vector(7 downto 0);
                      
                      signal i_ready  : out std_logic;
                      signal i_valid  : in  std_logic;
                      signal i_dvalid : in  std_logic;
                      signal i_last   : in  std_logic;
                      signal i_elem   : in  std_logic_vector(7 downto 0);
                      
                      signal o_ready  : in  std_logic;
                      signal o_valid  : out std_logic;
                      signal o_dvalid : out std_logic;
                      signal o_last   : out std_logic;
                      signal o_elem   : out std_logic_vector(7 downto 0);
                      
                      variable so_sum : out std_logic_vector(31 downto 0))
  is 
    variable idx        : natural             := 0;
    variable number_in  : signed(7 downto 0)  := (others => '0');
    variable number_out : signed(7 downto 0)  := (others => '0');
    variable number_sum : signed(31 downto 0) := (others => '0');
    variable last       : std_logic := '0';
  begin
    loop
      -- Wait for intput.
      i_ready <= '1';
      loop
        last := i_last;
        wait until rising_edge(kcd_clk);
        exit when i_valid = '1';
      end loop;
      
      -- dvalid should always be 1 for these schemas, since this is only used
      -- to signal empty lists on a list child stream.
      assert(i_dvalid = '1')
        report("dvalid expected to be '1', but was '0'")
        severity failure;
      
      i_ready <= '0';

      -- Convert to signed integer
      number_in := signed(i_elem);
      -- Calculate the sum of the input.
      number_sum := number_sum + number_in;
      -- Take the absolute value because ABS awesome. Then, add the "add" mmio input.
      number_out := abs(number_in) + signed(si_add);

      -- Put the sum onto the output.
      so_sum := std_logic_vector(number_sum);

      -- Put the transformed value to the output.
      o_dvalid <= '1';
      o_last   <= last;
      o_elem   <= std_logic_vector(number_out);
      -- Validate the output and wait for handshake
      o_valid <= '1';
      loop
        wait until rising_edge(kcd_clk);
        exit when o_ready = '1';
      end loop;

      println("Number (in) " & sgnToDec(number_in) & " --> " & sgnToDec(number_out) & " (out)");
      
      o_valid <= '0';

      idx := idx + 1;
      exit when idx = 4;
    end loop;
  end procedure;

begin
  process is
    variable sum_A : std_logic_vector(31 downto 0);
    variable sum_B : std_logic_vector(31 downto 0);
  begin
    -- Initial outputs
    busy <= '0';
    done <= '0';
    idle <= '0';

    R_A_cmd_valid <= '0';
    R_B_cmd_valid <= '0';
    W_C_cmd_valid <= '0';
    W_D_cmd_valid <= '0';
    R_A_ready <= '0';
    R_B_ready <= '0';
    W_C_valid <= '0';
    W_C_last <= '0';
    W_D_valid <= '0';
    R_A_unl_ready <= '1';
    R_B_unl_ready <= '1';
    W_C_unl_ready <= '1';
    W_D_unl_ready <= '1';
 
    -- Wait for reset to go low and start to go high.
    loop
      wait until rising_edge(kcd_clk);
      exit when reset = '0' and start = '1';
    end loop;

    busy <= '1';

    -- Issue the commands to all ArrayReaders/Writers
    command(kcd_clk, kcd_reset, R_firstidx, R_lastidx, R_A_cmd_firstidx, R_A_cmd_lastidx, R_A_cmd_valid, R_A_cmd_ready);
    command(kcd_clk, kcd_reset, R_firstidx, R_lastidx, R_B_cmd_firstidx, R_B_cmd_lastidx, R_B_cmd_valid, R_B_cmd_ready);
    command(kcd_clk, kcd_reset, W_firstidx, W_lastidx, W_C_cmd_firstidx, W_C_cmd_lastidx, W_C_cmd_valid, W_C_cmd_ready);
    command(kcd_clk, kcd_reset, W_firstidx, W_lastidx, W_D_cmd_firstidx, W_D_cmd_lastidx, W_D_cmd_valid, W_D_cmd_ready);

    -- Apply the transformation on both arrays.
    transform(kcd_clk, kcd_reset, add, R_A_ready, R_A_valid, R_A_dvalid, R_A_last, R_A, W_C_ready, W_C_valid, W_C_dvalid, W_C_last, W_C, sum_A);
    transform(kcd_clk, kcd_reset, add, R_B_ready, R_B_valid, R_B_dvalid, R_B_last, R_B, W_D_ready, W_D_valid, W_D_dvalid, W_D_last, W_D, sum_B);

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
