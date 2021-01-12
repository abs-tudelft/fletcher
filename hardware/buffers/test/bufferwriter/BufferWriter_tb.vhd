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
use ieee.std_logic_misc.all;
use ieee.math_real.all;

library work;
use work.Stream_pkg.all;
use work.Buffer_pkg.all;
use work.UtilInt_pkg.all;
use work.UtilStr_pkg.all;
use work.UtilConv_pkg.all;
use work.UtilMisc_pkg.all;

-------------------------------------------------------------------------------
-- This testbench is used to verify the functionality of the BufferWriter.
-------------------------------------------------------------------------------
entity BufferWriter_tb is
  generic (
    TEST_NAME                   : string   := "";
    BUS_ADDR_WIDTH              : natural  := 32;
    BUS_DATA_WIDTH              : natural  := 32;
    BUS_STROBE_WIDTH            : natural  := 32/8;
    BUS_LEN_WIDTH               : natural  := 9;
    BUS_BURST_STEP_LEN          : natural  := 1;
    BUS_BURST_MAX_LEN           : natural  := 16;

    BUS_FIFO_DEPTH              : natural  := 1;
    BUS_FIFO_THRES_SHIFT        : natural  := 0;

    INDEX_WIDTH                 : natural  := 32;
    IS_OFFSETS_BUFFER           : boolean  := true;

    ELEMENT_WIDTH               : natural  := sel(IS_OFFSETS_BUFFER, INDEX_WIDTH, 32);
    ELEMENT_COUNT_MAX           : natural  := 1;
    ELEMENT_COUNT_WIDTH         : natural  := imax(1,log2ceil(ELEMENT_COUNT_MAX));

    AVG_RANGE_LEN               : real     := 2.0 ** 10;

    NUM_COMMANDS                : natural  := 16;
    WAIT_FOR_UNLOCK             : boolean  := true;
    KNOWN_LAST_INDEX            : boolean  := sel(IS_OFFSETS_BUFFER, false, true);
    LAST_PROBABILITY            : real     := 1.0/512.0;

    CMD_CTRL_WIDTH              : natural  := 1;

    CMD_TAG_WIDTH               : natural  := log2ceil(NUM_COMMANDS);

    VERBOSE                     : boolean  := false;
    SEED                        : positive := 16#0123#
  );
end BufferWriter_tb;

architecture tb of BufferWriter_tb is
  constant ELEMS_PER_WORD       : natural := BUS_DATA_WIDTH / ELEMENT_WIDTH;
  constant BYTES_PER_ELEM       : natural := imax(1, ELEMENT_WIDTH/8);
  constant ELEMS_PER_BYTE       : natural := 8 / ELEMENT_WIDTH;
  constant MAX_ELEM_VAL         : real    := 2.0 ** (ELEMENT_WIDTH - 1);

  signal command_done           : boolean := false;
  signal input_done             : boolean := false;
  signal write_done             : boolean := false;
  signal sim_done               : boolean := false;

  signal bcd_clk                : std_logic := '1';
  signal bcd_reset              : std_logic := '1';
  signal kcd_clk                : std_logic := '1';
  signal kcd_reset              : std_logic := '1';

  signal cmdIn_valid            : std_logic;
  signal cmdIn_ready            : std_logic;
  signal cmdIn_firstIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmdIn_lastIdx          : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmdIn_baseAddr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal cmdIn_implicit         : std_logic;
  signal cmdIn_tag              : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal cmdOut_valid           : std_logic;
  signal cmdOut_ready           : std_logic := '1';
  signal cmdOut_firstIdx        : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmdOut_lastIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal cmdOut_ctrl            : std_logic_vector(CMD_CTRL_WIDTH-1 downto 0) := (others => '0');
  signal cmdOut_tag             : std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

  signal unlock_valid           : std_logic;
  signal unlock_ready           : std_logic := '1';
  signal unlock_tag             : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

  signal in_valid               : std_logic := '0';
  signal in_ready               : std_logic;
  signal in_data                : std_logic_vector(ELEMENT_COUNT_MAX * ELEMENT_WIDTH -1 downto 0);
  signal in_count               : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal in_last                : std_logic := '0';

  signal bus_wreq_valid         : std_logic;
  signal bus_wreq_ready         : std_logic;
  signal bus_wreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_wreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_wreq_last          : std_logic;
  signal bus_wdat_valid         : std_logic;
  signal bus_wdat_ready         : std_logic;
  signal bus_wdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_wdat_strobe        : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal bus_wdat_last          : std_logic;
  signal bus_wrep_valid         : std_logic;
  signal bus_wrep_ready         : std_logic;
  signal bus_wrep_ok            : std_logic;

  signal cycle                  : unsigned(63 downto 0) := (others => '0');

  function gen_elem_val(rand: real) return unsigned is
  begin
    if ELEMENT_WIDTH < 32 then
      return to_unsigned(natural(rand * MAX_ELEM_VAL), ELEMENT_WIDTH);
    else
      return to_unsigned(natural(rand * 2.0**31), ELEMENT_WIDTH);
    end if;
  end function;

  procedure print_elem(name: in string; index: in unsigned; a: in unsigned) is
  begin
    println(TEST_NAME & " :" & name & "[" & unsToUDec(index) & "]: " & intToDec(int(a)));
  end print_elem;

  procedure print_elem_check(name: in string; index: in integer; a: in unsigned; b: in unsigned) is
  begin
    println(TEST_NAME & " :" & name & "[" & intToDec(index) & "]: W[" & intToDec(int(a)) & "] =?= E[" & intToDec(int(b)) & "]");
  end print_elem_check;

  procedure generate_command(
    first_index     : out unsigned(INDEX_WIDTH-1 downto 0);
    last_index      : out unsigned(INDEX_WIDTH-1 downto 0);
    rand            : in real;
    rand_last       : in real
  ) is
  begin
    -- For offsets buffers, first_index should start at zero
    first_index             := (others => '0');
    last_index              := (others => '0');

    -- Otherwise
    if not IS_OFFSETS_BUFFER then
      first_index             := to_unsigned(natural(rand * 256.0), INDEX_WIDTH);
      if KNOWN_LAST_INDEX then
        last_index            := first_index + to_unsigned(imax(1, natural(rand_last * AVG_RANGE_LEN)), INDEX_WIDTH);
      end if;
    end if;

    -- If ELEMS_PER_BYTE = 0 then all elements start on byte boundaries.
    -- Otherwise align:
    if ELEMS_PER_BYTE /= 0 then
      -- Elements don't always start on a byte boundary, align the first index to a byte boundary
      first_index             := alignDown(first_index, log2ceil(ELEMS_PER_BYTE));
      last_index              := alignUp(last_index, log2ceil(ELEMS_PER_BYTE));
    end if;
  end generate_command;

begin

  sim_done                      <= command_done and input_done and write_done;

  -- Clock
  clk_proc: process is
  begin
    if not sim_done then
      bcd_clk                   <= '1';
      kcd_clk                   <= '1';
      wait for 2 ns;
      bcd_clk                   <= '0';
      kcd_clk                   <= '0';
      wait for 2 ns;
      -- Count number of cycles.
      if kcd_reset = '0' then
        cycle                   <= cycle + 1;
      end if;
    else
      wait;
    end if;
  end process;

  -- Reset
  reset_proc: process is
  begin
    bcd_reset                   <= '1';
    kcd_reset                   <= '1';
    wait for 8 ns;
    wait until rising_edge(kcd_clk);
    bcd_reset                   <= '0';
    kcd_reset                   <= '0';
    wait;
  end process;

  -- Command generation
  command_proc: process is
    variable seed1              : positive := SEED;
    variable seed2              : positive := 1;
    variable rand               : real;

    variable seed1_last         : positive := SEED;
    variable seed2_last         : positive := 1;
    variable rand_last          : real;

    variable first_index        : unsigned(INDEX_WIDTH-1 downto 0) := (others => '0');
    variable last_index         : unsigned(INDEX_WIDTH-1 downto 0) := (others => '0');
    variable commands_accepted  : natural := 0;
  begin
    cmdIn_implicit              <= '0';
    cmdIn_baseAddr              <= (others => '0');
    cmdIn_lastIdx               <= (others => '0');
    cmdIn_valid                 <= '0';
    cmdIn_tag                   <= (others => '0');

    -- Wait for reset
    wait until rising_edge(kcd_clk) and (kcd_reset /= '1');

    for I in 0 to NUM_COMMANDS-1 loop
      -- Determine the first index and last index
      uniform(seed1, seed2, rand);
      uniform(seed1_last, seed2_last, rand_last);
      generate_command(first_index, last_index, rand, rand_last);

      -- Set first and last index
      cmdIn_firstIdx            <= slv(first_index);
      cmdIn_lastIdx             <= slv(last_index);
      -- Set tag
      cmdIn_tag                 <= slv(to_unsigned(I, CMD_TAG_WIDTH));
      -- Validate the command
      cmdIn_valid               <= '1';

      -- Wait until it's accepted and invalidate
      wait until rising_edge(kcd_clk) and (cmdIn_ready = '1');
      cmdIn_valid               <= '0';
      commands_accepted         := commands_accepted + 1;

      -- All commands have been accepted
      if commands_accepted = NUM_COMMANDS then
        command_done                <= true;
      end if;

      if WAIT_FOR_UNLOCK then
        if VERBOSE then
          println(TEST_NAME & " :" & "Waiting for unlock.");
        end if;
        wait until rising_edge(kcd_clk) and (unlock_ready = '1' and unlock_valid = '1');
      end if;

      if command_done then
        exit;
      end if;
    end loop;

    wait;
  end process;

  -- Input stream generation
  input_proc: process is
    variable seed1              : positive := SEED;
    variable seed2              : positive := 1;
    variable rand               : real;

    variable count_seed1        : positive := SEED;
    variable count_seed2        : positive := 1;
    variable count_rand         : real;

    variable last_seed1         : positive := SEED;
    variable last_seed2         : positive := 1;
    variable last_rand          : real;

    variable cmd_seed1          : positive := SEED;
    variable cmd_seed2          : positive := 1;
    variable cmd_rand           : real;

    variable cmd_seed1_last     : positive := SEED;
    variable cmd_seed2_last     : positive := 1;
    variable cmd_rand_last      : real;

    variable command            : integer  := 0;

    variable true_count         : integer  := 0;

    variable current_index      : unsigned(INDEX_WIDTH-1 downto 0) := (others => '0');
    variable first_index        : unsigned(INDEX_WIDTH-1 downto 0) := (others => '0');
    variable last_index         : unsigned(INDEX_WIDTH-1 downto 0) := (others => '0');

    variable elem_val           : unsigned(ELEMENT_WIDTH-1 downto 0);
  begin

    in_valid                    <= '0';
    in_last                     <= '0';
    
    -- Wait for reset
    wait until rising_edge(kcd_clk) and (kcd_reset /= '1');

    loop
      in_valid                  <= '0';
      in_last                   <= '0';

      uniform(cmd_seed1, cmd_seed2, cmd_rand);
      uniform(cmd_seed1_last, cmd_seed2_last, cmd_rand_last);
      generate_command(first_index, last_index, cmd_rand, cmd_rand_last);
      command                   := command + 1;

      current_index             := first_index;

      -- Offsets buffers automatically get a zero padded
      if IS_OFFSETS_BUFFER then
        current_index           := current_index + 1;
      end if;

      loop
        in_last                 <= '0';
        -- Randomize count
        if ELEMENT_COUNT_MAX > 1 then
          uniform(count_seed1, count_seed2, count_rand);
          if count_rand > 0.9 then
            true_count          := natural(count_rand * real(ELEMENT_COUNT_MAX-1));
            in_count            <= slv(to_unsigned(true_count, ELEMENT_COUNT_WIDTH));
          else
            true_count          := ELEMENT_COUNT_MAX;
            in_count            <= (others => '0');
          end if;
        else
          true_count            := ELEMENT_COUNT_MAX;
          in_count              <= (others => '1');
        end if;

        -- Reduce count to not exceed lastidx
        if (last_index /= 0) and (current_index + true_count > last_index) then
          if VERBOSE then
            println(TEST_NAME & " :" & "Count would exceed last index, modifying..." & unsToUDec(current_index) & " + " & intToDec(true_count) & " > " & unsToUDec(last_index));
          end if;

          true_count            := int(last_index - current_index);

          if VERBOSE then
            println(TEST_NAME & " :" & "New count:" & intToDec(true_count));
          end if;

          in_count              <= slv(to_unsigned(true_count, ELEMENT_COUNT_WIDTH));
        end if;

        -- Make data unkown
        in_data                 <= (others => 'X');

        -- Randomize data
        for I in 0 to true_count-1  loop
            if IS_OFFSETS_BUFFER then
              elem_val          := to_unsigned(1, ELEMENT_WIDTH);
            else
              uniform(seed1, seed2, rand);
              elem_val          := gen_elem_val(rand);
            end if;
            in_data((I+1)*ELEMENT_WIDTH-1 downto I*ELEMENT_WIDTH) <= slv(elem_val);

            if VERBOSE then
              print_elem("Stream", current_index, elem_val);
            end if;

            current_index       := current_index + 1;
        end loop;

        -- Randomize last, but only assert it if the "last index" is on a byte boundary
        -- and we didn't give a last index
        if last_index = 0 then
          uniform(last_seed1, last_seed2, last_rand);
          if last_rand < LAST_PROBABILITY then
            if ELEMS_PER_BYTE /= 0 then -- prevent mod 0 error
              if current_index mod ELEMS_PER_BYTE = 0 then
                in_last         <= '1';
              end if;
            else
              in_last           <= '1';
            end if;
          end if;
        else
          -- If we've created enough elements to full the range, last must be '1'
          if current_index = last_index then
            in_last             <= '1';
          end if;
        end if;

        -- Validate input stream
        in_valid                <= '1';

        -- Wait until handshake
        wait until rising_edge(kcd_clk) and (in_ready = '1');

        -- Exit when last element streamed in
        if in_last = '1' then
          if VERBOSE then
            println(TEST_NAME & " : " & "Last element.");
          end if;
          exit;
        end if;
      end loop;

      -- Exit when this was the last command
      if command = NUM_COMMANDS then
        input_done              <= true;
        exit;
      end if;

    end loop;

    wait;
  end process;

  -- Unlock stream check
  unlock_proc: process is
    variable unlocked           : integer := 0;

    variable expected_tag       : std_logic_vector(CMD_TAG_WIDTH-1 downto 0);
  begin
    loop
      -- Wait for unlock handshake
      wait until rising_edge(kcd_clk) and (unlock_valid = '1' and unlock_ready = '1');

      expected_tag              := slv(to_unsigned(unlocked,CMD_TAG_WIDTH));

      if unlock_tag /= expected_tag then
        report "TEST FAILURE. Unexpected tag on unlock stream." severity failure;
      end if;

      -- Increase number of unlocks
      unlocked                  := unlocked + 1;

      -- Check if we are done
      if unlocked = NUM_COMMANDS then
        write_done              <= true;
        exit;
      end if;
    end loop;

    -- Dirty trick to allow stdout to empty write buffer since textio doesn't have a flush function
    wait for 100 ns;

    -- If the test finishes, it is successful.
    report "TEST SUCCESSFUL.";

    wait;
  end process;

  -- Bus write check
  -- This process can only accept a single bus burst request at a time
  bus_proc: process is
    variable seed1              : positive := SEED;
    variable seed2              : positive := 1;
    variable rand               : real;

    variable address            : unsigned(BUS_ADDR_WIDTH-1 downto 0);

    variable len                : unsigned(BUS_LEN_WIDTH-1 downto 0);
    variable transfers          : unsigned(BUS_LEN_WIDTH-1 downto 0);

    variable index              : integer := 0;
    variable elem_strobe        : std_logic := '1';
    variable elem_written       : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable elem_expected      : unsigned(ELEMENT_WIDTH-1 downto 0);
  begin
    bus_wreq_ready              <= '1';
    bus_wdat_ready              <= '0';
    bus_wrep_valid              <= '0';
    loop
      -- Wait for a bus request
      wait until rising_edge(kcd_clk) and (sim_done or (bus_wreq_ready = '1' and bus_wreq_valid = '1'));
      exit when sim_done;
      bus_wreq_ready            <= '0';
      bus_wdat_ready            <= '1';

      -- Remember the burst length
      len                       := unsigned(bus_wreq_len);
      transfers                 := (others => '0');

      -- Work back the element index from the address, assuming the base address is zero
      index                     := int(bus_wreq_addr) / BYTES_PER_ELEM;

      -- Accept the number of words requested by the burst length
      for J in 0 to int(len)-1 loop
        -- Wait until master writes a burst beat
        wait until rising_edge(kcd_clk) and (bus_wdat_valid = '1');

        transfers               := transfers + 1;

        -- Check each element value
        for I in 0 to ELEMS_PER_WORD-1 loop
          -- Determine the element strobe. For elements smaller than a byte, duplicate the strobe.
          if ELEMS_PER_BYTE = 0 then
            -- The elements are always byte aligned.
            elem_strobe         := or_reduce(bus_wdat_strobe((I+1)*BYTES_PER_ELEM-1 downto I*BYTES_PER_ELEM));
          else
            -- The elements are not always byte aligned
            elem_strobe         := bus_wdat_strobe(I/ELEMS_PER_BYTE);
          end if;

          -- Check if the element strobe is asserted
          if elem_strobe = '1' then

            -- Grab what is written
            elem_written          := u(bus_wdat_data((I+1) * ELEMENT_WIDTH-1 downto I * ELEMENT_WIDTH));

            -- If this is an offsets buffer and its the first element, 
            -- we expect it to be 0
            if IS_OFFSETS_BUFFER then
              elem_expected     := to_unsigned(index + I, ELEMENT_WIDTH);
            else
              uniform(seed1, seed2, rand);
              elem_expected     := gen_elem_val(rand);
            end if;

            if VERBOSE then
              print_elem_check("Bus", index+I, elem_written, elem_expected);
            end if;

            -- Check if the correct element was written
            if elem_written /= elem_expected then
              if not(VERBOSE) then
                print_elem_check("Bus", index+I, elem_written, elem_expected);
              end if;
              report "TEST FAILURE. Unexpected element on bus." severity failure;
            end if;
          end if;

          -- Make sure last is not too early
          if bus_wdat_last = '1' then
            assert transfers = len
              report "TEST FAILURE. Bus write channel last asserted at transfer " & intToDec(int(transfers)) & " while requested length was " & intToDec(int(len))
              severity failure;
          end if;

          -- Or too late
          if transfers = len and bus_wdat_last = '0' then
            report "TEST FAILURE. Bus write channel last NOT asserted at transfer " & intToDec(int(transfers)) & " while requested length was " & intToDec(int(len))
              severity failure;
          end if;

        end loop;

        -- Increase current index
        index                   := index + BUS_DATA_WIDTH / ELEMENT_WIDTH;
      end loop;
      bus_wdat_ready            <= '0';

      -- Send response
      bus_wrep_valid            <= '1';
      bus_wrep_ok               <= '1';
      wait until rising_edge(kcd_clk) and (bus_wrep_ready = '1');
      bus_wrep_valid            <= '0';

      -- Start accepting new requests
      bus_wreq_ready            <= '1';
    end loop;
    wait;
  end process;

  avg_bandwidth_proc: process is
    variable transfers : unsigned(63 downto 0) := (others => '0');
  begin
    -- Wait for reset
    wait until rising_edge(kcd_clk) and kcd_reset = '0';

    -- Start counting
    loop
      wait until rising_edge(kcd_clk) or sim_done;

      if bus_wdat_valid = '1' and bus_wdat_ready = '1' then
        transfers               := transfers + 1;
      end if;

      -- Exit when all done
      if sim_done then
        exit;
      end if;

    end loop;

    println(TEST_NAME & " :" & "Transfers: " & unsToUDec(transfers));
    println(TEST_NAME & " :" & "Cycles: " & unsToUDec(cycle));
    println(TEST_NAME & " :" & "Throughput: " & integer'image(integer(100.0 * real(int(transfers))/real(int(cycle)))) & "% of peak.");

    wait;
  end process;

  -- BufferWriter instantiation
  uut : BufferWriter
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_STROBE_WIDTH          => BUS_STROBE_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_FIFO_DEPTH            => BUS_FIFO_DEPTH,
      BUS_FIFO_THRES_SHIFT      => BUS_FIFO_THRES_SHIFT,
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      IS_OFFSETS_BUFFER         => IS_OFFSETS_BUFFER,
      ELEMENT_COUNT_MAX         => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => ELEMENT_COUNT_WIDTH,
      CMD_CTRL_WIDTH            => CMD_CTRL_WIDTH,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      bcd_clk                   => bcd_clk,
      bcd_reset                 => bcd_reset,
      kcd_clk                   => kcd_clk,
      kcd_reset                 => kcd_reset,

      cmdIn_valid               => cmdIn_valid,
      cmdIn_ready               => cmdIn_ready,
      cmdIn_firstIdx            => cmdIn_firstIdx,
      cmdIn_lastIdx             => cmdIn_lastIdx,
      cmdIn_baseAddr            => cmdIn_baseAddr,
      cmdIn_implicit            => cmdIn_implicit,
      cmdIn_tag                 => cmdIn_tag,
      cmdIn_ctrl                => "0",

      unlock_valid              => unlock_valid,
      unlock_ready              => unlock_ready,
      unlock_tag                => unlock_tag,

      cmdOut_valid              => cmdOut_valid,
      cmdOut_ready              => cmdOut_ready,
      cmdOut_firstIdx           => cmdOut_firstIdx,
      cmdOut_lastIdx            => cmdOut_lastIdx,
      cmdOut_ctrl               => cmdOut_ctrl,
      cmdOut_tag                => cmdOut_tag,

      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_data                   => in_data,
      in_count                  => in_count,
      in_last                   => in_last,

      bus_wreq_valid            => bus_wreq_valid,
      bus_wreq_ready            => bus_wreq_ready,
      bus_wreq_addr             => bus_wreq_addr,
      bus_wreq_len              => bus_wreq_len,
      bus_wreq_last             => bus_wreq_last,
      bus_wdat_valid            => bus_wdat_valid,
      bus_wdat_ready            => bus_wdat_ready,
      bus_wdat_data             => bus_wdat_data,
      bus_wdat_strobe           => bus_wdat_strobe,
      bus_wdat_last             => bus_wdat_last,
      bus_wrep_valid            => bus_wrep_valid,
      bus_wrep_ready            => bus_wrep_ready,
      bus_wrep_ok               => bus_wrep_ok
    );

end architecture;
