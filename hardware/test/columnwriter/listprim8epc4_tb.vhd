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
use work.Arrow.all;
use work.ColumnReaderConfig.all;
use work.ColumnReaderConfigParse.all;

entity listprim8epc4_tb is
end listprim8epc4_tb;

architecture tb of listprim8epc4_tb is

  constant BUS_ADDR_WIDTH     : natural := 32;
  constant BUS_LEN_WIDTH      : natural := 8;
  constant BUS_DATA_WIDTH     : natural := 32;
  constant BUS_STROBE_WIDTH   : natural := 32/8;
  constant BUS_BURST_STEP_LEN : natural := 1;
  constant BUS_BURST_MAX_LEN  : natural := 16;
  constant INDEX_WIDTH        : natural := 32;
  constant CFG                : string  := "listprim(8;epc=4)";
  constant CMD_TAG_ENABLE     : boolean := false;
  constant CMD_TAG_WIDTH      : natural := 1;
  
  constant LEN_SEED           : natural := 16#1337#;
  constant ELEM_SEED          : natural := 16#BEE5#;
  
  constant ELEMENT_WIDTH      : natural := 8;
  constant COUNT_MAX          : natural := 4;
  constant COUNT_WIDTH        : natural := 3;
  constant MAX_LEN            : real    := 16.0;
  constant NUM_LISTS          : natural := 1024;
  constant LENGTH_WIDTH       : natural := INDEX_WIDTH;

  signal bus_clk              : std_logic;
  signal bus_reset            : std_logic;
  signal acc_clk              : std_logic;
  signal acc_reset            : std_logic;
  signal cmd_valid            : std_logic;
  signal cmd_ready            : std_logic;
  signal cmd_firstIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_lastIdx          : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmd_ctrl             : std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
  signal cmd_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');
  signal unlock_valid         : std_logic;
  signal unlock_ready         : std_logic := '1';
  signal unlock_tag           : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  signal bus_wreq_valid       : std_logic;
  signal bus_wreq_ready       : std_logic;
  signal bus_wreq_addr        : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_wreq_len         : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_wdat_valid       : std_logic;
  signal bus_wdat_ready       : std_logic;
  signal bus_wdat_data        : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_wdat_strobe      : std_logic_vector(BUS_STROBE_WIDTH-1 downto 0);
  signal bus_wdat_last        : std_logic;
  
  signal in_valid             : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_ready             : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_last              : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_dvalid            : std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
  signal in_data              : std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0);
  
  signal len_valid            : std_logic;
  signal len_ready            : std_logic;
  signal len_data             : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal len_last             : std_logic;
  
  signal prim_valid           : std_logic;
  signal prim_ready           : std_logic;
  signal prim_count           : std_logic_vector(2 downto 0);
  signal prim_data            : std_logic_vector(31 downto 0);
  signal prim_last            : std_logic;
  signal prim_dvalid          : std_logic;
  
  signal clock_stop           : boolean := false;
  signal len_done             : boolean := false;

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
  
  in_valid(0)                     <= len_valid;
  len_ready                       <= in_ready(0);
  in_data(INDEX_WIDTH-1 downto 0) <= len_data;
  in_last(0)                      <= len_last;
  in_dvalid(0)                    <= '1';
  
  in_valid(1)                                       <= prim_valid;
  prim_ready                                        <= in_ready(1);
  in_data(INDEX_WIDTH+32-1 downto INDEX_WIDTH)      <= prim_data;
  in_data(INDEX_WIDTH+32+3-1 downto INDEX_WIDTH+32) <= prim_count;
  in_last(1)                                        <= prim_last;
  in_dvalid(1)                                      <= prim_dvalid;
  
  cmd_proc: process is
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
    
    cmd_valid <= '0';
    
    wait;
    
  end process;
  
    len_stream_proc: process is
    variable seed1             : positive := LEN_SEED;
    variable seed2             : positive := 1;
    variable rand              : real;

    variable list               : integer;

    variable len                : integer;
  begin

    len_valid   <= '0';
    len_data  <= (others => 'U');
    len_last    <= '0';

    loop
      wait until rising_edge(acc_clk);
      exit when acc_reset = '0';
    end loop;

    list := 0;

    loop
      -- Randomize list length
      uniform(seed1, seed2, rand);
      len := natural(rand * MAX_LEN);

      dumpStdOut("length stream: list " & integer'image(list) & " length is " & integer'image(len));

      -- Set the length vector
      len_data <= std_logic_vector(to_unsigned(len, LENGTH_WIDTH));

      -- Set last
      if list = NUM_LISTS-1 then
        len_last <= '1';
      else
        len_last <= '0';
      end if;

      -- Validate length
      len_valid <= '1';

      -- Wait for handshake
      loop
        wait until rising_edge(acc_clk);
        exit when len_ready = '1';
      end loop;

      -- A list item is completed.
      list := list + 1;

      exit when list = NUM_LISTS;
    end loop;

    len_valid   <= '0';
    len_data  <= (others => 'U');
    len_last    <= '0';

    len_done <= true;

    wait;
  end process;


  elem_stream_proc: process is
    variable lseed1             : positive := LEN_SEED;
    variable lseed2             : positive := 1;
    variable lrand              : real;

    variable seed1              : positive := ELEM_SEED;
    variable seed2              : positive := 1;
    variable rand               : real;

    variable data               : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable count              : natural;

    variable len                : integer;
    variable orig_len           : integer;
    variable empty              : boolean;

    variable list               : integer;

    variable element            : natural := 0;
  begin

    prim_valid <= '0';

    -- Wait until no reset
    loop
      wait until rising_edge(acc_clk);
      exit when acc_reset = '0';
    end loop;

    list := 0;

    -- Loop over different list
    loop
      prim_valid   <= '0';
      prim_last    <= '0';
      prim_count   <= (others => 'U');
      prim_dvalid  <= '0';
      prim_data    <= (others => 'U');

      exit when list = NUM_LISTS;

      -- Randomize list length, using the same seed as the len stream process
      uniform(lseed1, lseed2, lrand);
      len := natural(lrand * MAX_LEN);
      orig_len := len;

      dumpStdOut("element stream: list " & integer'image(list) & " length is " & integer'image(len));

      if len = 0 then
        empty := true;
      else
        empty := false;
      end if;

      -- Generate some data
      loop
        -- Randomize count
        uniform(seed1, seed2, rand);
        count := 1 + work.Utils.min(3, natural(100.0*rand * real(COUNT_MAX)));

        dumpStdOut("element stream: count is " & integer'image(count));

        -- Resize count if necessary
        if len - count < 0 then
          count := len;
        end if;

        prim_count <= std_logic_vector(to_unsigned(count, COUNT_WIDTH));

        -- Determine elements
        for e in 0 to count-1 loop
          element := element + 1;
          prim_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) <= std_logic_vector(to_unsigned(element, ELEMENT_WIDTH));
        end loop;
        for e in count to COUNT_MAX-1 loop
          prim_data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH) <= (others => 'U');
        end loop;

        -- Subtract count
        len := len - count;

        -- Determine last
        if len = 0 then
          prim_last <= '1';
        end if;

        -- Determine dvalid
        if empty then
          prim_dvalid <= '0';
        else
          prim_dvalid <= '1';
        end if;

        prim_valid <= '1';

        -- Wait for acceptance
        loop
          wait until rising_edge(acc_clk);
          exit when prim_ready = '1';
        end loop;

        if prim_last = '1' then
          list := list + 1;
        end if;

        exit when len = 0;

      end loop;

    end loop;

    -- Wait a bit for all the outputs in a nasty way
    wait for 1000 ns;

    clock_stop <= true;
    wait;

  end process;
  
  bus_wreq_ready <= '1';
  bus_wdat_ready <= '1';
  
  uut : ColumnWriter
    generic map (
      BUS_ADDR_WIDTH      => BUS_ADDR_WIDTH,    
      BUS_LEN_WIDTH       => BUS_LEN_WIDTH,     
      BUS_DATA_WIDTH      => BUS_DATA_WIDTH,    
      BUS_STROBE_WIDTH    => BUS_STROBE_WIDTH,  
      BUS_BURST_STEP_LEN  => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN   => BUS_BURST_MAX_LEN, 
      INDEX_WIDTH         => INDEX_WIDTH,      
      CFG                 => CFG,               
      CMD_TAG_ENABLE      => CMD_TAG_ENABLE,    
      CMD_TAG_WIDTH       => CMD_TAG_WIDTH     
    )
    port map (
      bus_clk             => bus_clk,
      bus_reset           => bus_reset,
      acc_clk             => acc_clk,
      acc_reset           => acc_reset,
      cmd_valid           => cmd_valid,
      cmd_ready           => cmd_ready,
      cmd_firstIdx        => cmd_firstIdx,
      cmd_lastIdx         => cmd_lastIdx,
      cmd_ctrl            => cmd_ctrl,
      cmd_tag             => cmd_tag,
      unlock_valid        => unlock_valid,
      unlock_ready        => unlock_ready,
      unlock_tag          => unlock_tag,
      bus_wreq_valid      => bus_wreq_valid,
      bus_wreq_ready      => bus_wreq_ready,
      bus_wreq_addr       => bus_wreq_addr,
      bus_wreq_len        => bus_wreq_len,
      bus_wdat_valid      => bus_wdat_valid,
      bus_wdat_ready      => bus_wdat_ready,
      bus_wdat_data       => bus_wdat_data,
      bus_wdat_strobe     => bus_wdat_strobe,
      bus_wdat_last       => bus_wdat_last,
      in_valid            => in_valid,
      in_ready            => in_ready,
      in_last             => in_last,
      in_dvalid           => in_dvalid,
      in_data             => in_data
    );
  
end architecture;
