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
use ieee.math_real.all;

library work;
use work.Streams.all;
use work.Utils.all;
use work.SimUtils.all;
use work.Columns.all;
use work.ColumnConfig.all;
use work.ColumnConfigParse.all;
use work.Interconnect.all;
use work.BusChecking.all;

--pragma simulation timeout 1 ms

entity prim32_tc is
end prim32_tc;

architecture tb of prim32_tc is

  constant BUS_ADDR_WIDTH       : natural := 64;
  constant BUS_DATA_WIDTH       : natural := 512;
  constant BUS_STROBE_WIDTH     : natural := 512/8;
  constant BUS_BURST_STEP_LEN   : natural := 1;
  constant BUS_BURST_MAX_LEN    : natural := 32;
  constant BUS_LEN_WIDTH        : natural := log2ceil(BUS_BURST_MAX_LEN) + 1;
  constant INDEX_WIDTH          : natural := 32;
  constant CFG                  : string  := "prim(32)";
  constant CMD_TAG_ENABLE       : boolean := true;
  constant CMD_TAG_WIDTH        : natural := 1;

  constant CMD_SEED             : natural := 16#1010#;
  constant NUM_SEED             : natural := 16#1337#;
  constant ELEM_SEED            : natural := 16#BEE5#;

  constant ELEMENT_WIDTH        : natural := 32;
  constant MAX_NUM              : real    := 16.0;
  constant MAX_FIRSTIDX         : real    := 1024.0*1024.0;
  constant MAX_NUMS             : natural := 1337;

  signal bus_clk                : std_logic;
  signal bus_reset              : std_logic;
  signal acc_clk                : std_logic;
  signal acc_reset              : std_logic;
  signal cmd_valid              : std_logic;
  signal cmd_ready              : std_logic;
  signal cmd_firstIdx           : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_lastIdx            : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_ctrl               : std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
  signal cmd_tag                : std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
  signal unlock_valid           : std_logic;
  signal unlock_ready           : std_logic := '1';
  signal unlock_tag             : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal bus_wreq_valid         : std_logic;
  signal bus_wreq_ready         : std_logic;
  signal bus_wreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_wreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_wdat_valid         : std_logic;
  signal bus_wdat_ready         : std_logic;
  signal bus_wdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_wdat_strobe        : std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
  signal bus_wdat_last          : std_logic;

  signal in_valid               : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_ready               : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_last                : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_dvalid              : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_data                : std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0);

  signal num_valid              : std_logic;
  signal num_ready              : std_logic;
  signal num_data               : std_logic_vector(ELEMENT_WIDTH-1 downto 0);
  signal num_last               : std_logic;
  signal num_dvalid             : std_logic;

  ---------------------------------------------------------------------------
  -- Master bus Result
  ---------------------------------------------------------------------------
  -- Write request channel
  signal bus_result_wreq_addr   : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_result_wreq_len    : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_result_wreq_valid  : std_logic;
  signal bus_result_wreq_ready  : std_logic;

  -- Write response channel
  signal bus_result_wdat_data   : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_result_wdat_strobe : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);  -- TODO Laurens: "/8"?
  signal bus_result_wdat_last   : std_logic;
  signal bus_result_wdat_valid  : std_logic;
  signal bus_result_wdat_ready  : std_logic;

  -- Other stuff
  signal clock_stop             : boolean := false;
  signal num_done               : boolean := false;

begin

  clk_proc: process is
  begin
    if not clock_stop then
      acc_clk <= '1';
      bus_clk <= '1';
      wait for 5 ns;
      acc_clk <= '0';
      bus_clk <= '0';
      wait for 5 ns;
    else
      wait;
    end if;
  end process;

  reset_proc: process is
  begin
    acc_reset <= '1';
    bus_reset <= '1';
    wait for 50 ns;
    wait until rising_edge(acc_clk);
    acc_reset <= '0';
    bus_reset <= '0';
    wait;
  end process;

  in_valid(0)                       <= num_valid;
  num_ready                         <= in_ready(0);
  in_data(ELEMENT_WIDTH-1 downto 0) <= num_data;
  in_last(0)                        <= num_last;
  in_dvalid(0)                      <= num_dvalid;

  cmd_proc: process is
    variable seed1              : positive := CMD_SEED;
    variable seed2              : positive := 1;
    variable rand               : real;
    variable cmd                : integer := 0;
  begin
    cmd_firstIdx <= (others => '0');
    cmd_lastIdx  <= (others => '0');
    cmd_ctrl     <= (others => '0');
    cmd_tag      <= (others => '0');
    cmd_valid    <= '0';

    loop
      wait until rising_edge(acc_clk);
      exit when acc_reset = '0';
    end loop;

    cmd_valid <= '1';

    loop
        wait until rising_edge(acc_clk);
        exit when cmd_ready = '1';
    end loop;

    cmd := cmd + 1;

    wait;

  end process;

  unlock_proc: process is
  begin
    loop
      wait until rising_edge(acc_clk);
      exit when unlock_valid = '1';
    end loop;

    wait until rising_edge(acc_clk);

    clock_stop <= true;

    wait;
  end process;

  num_stream_proc: process is
    variable seed1              : positive := NUM_SEED;
    variable seed2              : positive := 1;
    variable rand               : real;

    variable idx                : integer;

    variable num                : integer;
  begin

    num_valid <= '0';
    num_data  <= (others => 'U');
    num_last  <= '0';

    loop
      wait until rising_edge(acc_clk);
      exit when acc_reset = '0';
    end loop;

    loop
      loop
        wait until rising_edge(acc_clk);
        exit when cmd_valid = '1' and cmd_ready = '1';
      end loop;

      idx := 0;

      loop
        -- Randomize list length
        uniform(seed1, seed2, rand);
        num := natural(rand * MAX_NUM);

        --dumpStdOut("Number: " & integer'image(idx) & " is " & integer'image(num));

        -- Set the length vector
        num_data <= std_logic_vector(to_unsigned(num, ELEMENT_WIDTH));

        -- Set last
        if idx = MAX_NUMS-1 then
          num_last <= '1';
        else
          num_last <= '0';
        end if;

        -- Validate length
        num_valid <= '1';

        -- Wait for handshake
        loop
          wait until rising_edge(acc_clk);
          exit when num_ready = '1';
        end loop;

        -- A list item is completed.
        idx := idx + 1;

        exit when idx = MAX_NUMS;
      end loop;

      num_valid   <= '0';
      num_data  <= (others => 'U');
      num_last    <= '0';

      num_done <= true;

    end loop;

    wait;
  end process;

  bus_wreq_ready <= '1';
  bus_wdat_ready <= '1';

  prot_checker : BusProtocolChecker
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_STROBE_WIDTH          => BUS_STROBE_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_BOUNDARY        => BUS_BURST_BOUNDARY
    )
    port map (
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      bus_rreq_valid            => '0',
      bus_rreq_ready            => '0',
      bus_rreq_addr             => (others => '0'),
      bus_rreq_len              => (others => '0'),
      bus_rdat_valid            => '0',
      bus_rdat_ready            => '0',
      bus_rdat_data             => (others => '0'),
      bus_rdat_last             => '0',
      bus_wreq_valid            => bus_wreq_valid,
      bus_wreq_ready            => bus_wreq_ready,
      bus_wreq_addr             => bus_wreq_addr,
      bus_wreq_len              => bus_wreq_len,
      bus_wdat_valid            => bus_wdat_valid,
      bus_wdat_ready            => bus_wdat_ready,
      bus_wdat_data             => bus_wdat_data,
      bus_wdat_strobe           => bus_wdat_strobe,
      bus_wdat_last             => bus_wdat_last
    );

  uut : ColumnWriter
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_STROBE_WIDTH          => BUS_STROBE_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      CFG                       => CFG,
      CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      acc_clk                   => acc_clk,
      acc_reset                 => acc_reset,
      cmd_valid                 => cmd_valid,
      cmd_ready                 => cmd_ready,
      cmd_firstIdx              => cmd_firstIdx,
      cmd_lastIdx               => cmd_lastIdx,
      cmd_ctrl                  => cmd_ctrl,
      cmd_tag                   => cmd_tag,
      unlock_valid              => unlock_valid,
      unlock_ready              => unlock_ready,
      unlock_tag                => unlock_tag,
      bus_wreq_valid            => bus_wreq_valid,
      bus_wreq_ready            => bus_wreq_ready,
      bus_wreq_addr             => bus_wreq_addr,
      bus_wreq_len              => bus_wreq_len,
      bus_wdat_valid            => bus_wdat_valid,
      bus_wdat_ready            => bus_wdat_ready,
      bus_wdat_data             => bus_wdat_data,
      bus_wdat_strobe           => bus_wdat_strobe,
      bus_wdat_last             => bus_wdat_last,
      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_last                   => in_last,
      in_dvalid                 => in_dvalid,
      in_data                   => in_data
    );

end architecture;
