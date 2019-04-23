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

package StreamSim is

  -----------------------------------------------------------------------------
  -- Component declarations for simulation-only helper units
  -----------------------------------------------------------------------------
  component StreamTbProd is
    generic (
      DATA_WIDTH                : natural := 4;
      SEED                      : positive;
      NAME                      : string := ""
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      out_valid                 : out std_logic;
      out_ready                 : in  std_logic;
      out_data                  : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

  component StreamTbCons is
    generic (
      DATA_WIDTH                : natural := 4;
      SEED                      : positive;
      NAME                      : string := ""
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : out std_logic;
      in_data                   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      monitor                   : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

  component StreamTbMon is
    generic (
      DATA_WIDTH                : natural := 4;
      NAME                      : string
    );
    port (
      clk                       : in  std_logic;
      reset                     : in  std_logic;
      in_valid                  : in  std_logic;
      in_ready                  : in  std_logic;
      in_data                   : in  std_logic_vector(DATA_WIDTH-1 downto 0);
      monitor                   : out std_logic_vector(DATA_WIDTH-1 downto 0)
    );
  end component;

  -----------------------------------------------------------------------------
  -- Simulation-only cross-entity communication interface
  -----------------------------------------------------------------------------
  -- This interface allows the testbench to send data to stream producers and
  -- expect data from stream consumers simply based on their name using access
  -- functions. The simulation will be terminated with an error if a timeout
  -- occurs or unexpected data is received.

  type stream_tb_name_ptr is access string;
  type stream_tb_data_ptr is access std_logic_vector;
  type stream_tb_data_ll_type;
  type stream_tb_data_ll_ptr is access stream_tb_data_ll_type;
  type stream_tb_data_ll_type is record
    next_node                   : stream_tb_data_ll_ptr;
    data                        : stream_tb_data_ptr;
    -- -1 for random, N>=0 to wait N cycles.
    timing                      : integer;
  end record;
  type stream_tb_reg_ll_type;
  type stream_tb_reg_ll_ptr is access stream_tb_reg_ll_type;
  type stream_tb_reg_ll_type is record
    next_node                   : stream_tb_reg_ll_ptr;
    name                        : stream_tb_name_ptr;
    queue                       : stream_tb_data_ll_ptr;
  end record;
  shared variable stream_tb_reg_ll  : stream_tb_reg_ll_ptr := null;
  shared variable stream_tb_done    : boolean := false;

  -- Simulation completion markers.
  procedure stream_tb_succeed(msg: string);
  procedure stream_tb_skip(msg: string);
  procedure stream_tb_fail(msg: string);

  -- Generates a clock signal, shutting down when the test case completes.
  procedure stream_tb_gen_clock(signal clk: out std_logic; period: time);

  -- Push an std_logic_vector into the specified stream. name should correspond
  -- with the name of a StreamTbProd instance.
  procedure stream_tb_push(
    name                        : in  string;
    data                        : in  std_logic_vector;
    timing                      : in  integer
  );
  procedure stream_tb_push(
    name                        : in  string;
    data                        : in  std_logic_vector
  );

  -- Same as above, but push a whole string of 8-bit ASCII characters at once.
  procedure stream_tb_push_ascii(
    name                        : in  string;
    data                        : in  string;
    timing                      : in  integer
  );
  procedure stream_tb_push_ascii(
    name                        : in  string;
    data                        : in  string
  );

  -- Pop an std_logic_vector from the specified stream. name should correspond
  -- with the name of a StreamTbCons instance. If no data was ready, ok is set
  -- to false and data will be undefined. If data was ready but has a different
  -- length, the simulation will be terminated with a failure. Otherwise, ok
  -- is set to true and the last element of the queue is popped into data.
  procedure stream_tb_pop(
    name                        : in  string;
    data                        : out std_logic_vector;
    timing                      : out integer;
    ok                          : out boolean
  );
  procedure stream_tb_pop(
    name                        : in  string;
    data                        : out std_logic_vector;
    ok                          : out boolean
  );

  -- Same as above, but with a timeout. If the timeout expires before data was
  -- found, the simulation will be terminated with a failure.
  procedure stream_tb_pop(
    name                        : in  string;
    data                        : out std_logic_vector;
    timing                      : out integer;
    timeout                     : in  time
  );
  procedure stream_tb_pop(
    name                        : in  string;
    data                        : out std_logic_vector;
    timeout                     : in  time
  );

  -- Same as above, but also matches the data. If the data does not match
  -- what's given, the simulation will be terminated with an error.
  procedure stream_tb_expect(
    name                        : in  string;
    expected                    : in  std_logic_vector;
    timeout                     : in  time
  );

  procedure stream_tb_expect(
    name                        : in  string;
    expected                    : in  std_logic_vector;
    mask                        : in  std_logic_vector;
    timeout                     : in  time
  );

  -- Same as stream_tb_expect, but compares two streams with each other. The
  -- expected bit width of the data in the streams should be specified in the
  -- bits parameter. This is useful when you want to queue up expected output
  -- while generating the input instead of checking immediately (which stalls
  -- the input) or regenerating the expected data later. Simply push the
  -- expected data into a named stream that isn't used elsewhere and then pass
  -- that stream name to the expected parameter.
  procedure stream_tb_expect_stream(
    name                        : in  string;
    expected                    : in  string;
    bits                        : in  natural;
    timeout                     : in  time
  );

  -- Same as stream_tb_expect, but checks a whole string of 8-bit ASCII
  -- characters at once. The timeout is per character.
  procedure stream_tb_expect_ascii(
    name                        : in  string;
    expected                    : in  string;
    char_timeout                : in  time
  );

  -- This should be called some time after the simulation completes. It
  -- verifies that all queues are empty (to check for unexpected data) and
  -- then terminates the simulation with an appropriate message.
  procedure stream_tb_complete;

end StreamSim;

package body StreamSim is

  -- Converts an std_logic_vector to a string for report statements.
  function to_string(
    a                           : std_logic_vector
  ) return string is
    variable b                  : string(1 to a'length) := (others => NUL);
    variable stri               : integer := 1;
  begin
    for i in a'range loop
      b(stri) := std_logic'image(a((i)))(2);
      stri := stri+1;
    end loop;
    return b;
  end function;

  function to_string(
    a                           : std_logic_vector;
    m                           : std_logic_vector
  ) return string is
    variable b                  : string(1 to a'length) := (others => NUL);
    variable stri               : integer := 1;
  begin
    for i in a'range loop
      if m(i) = '1' then
        b(stri) := std_logic'image(a((i)))(2);
      else
        b(stri) := '-';
      end if;
      stri := stri+1;
    end loop;
    return b;
  end function;

  -- Simulation completion markers.
  procedure stream_tb_succeed(msg: string) is
  begin
    report "TEST CASE PASSED: " & msg severity note;
    stream_tb_done := true;
    wait;
  end procedure;

  procedure stream_tb_skip(msg: string) is
  begin
    report "TEST CASE SKIPPED: " & msg severity note;
    stream_tb_done := true;
    wait;
  end procedure;

  procedure stream_tb_fail(msg: string) is
  begin
    report "TEST CASE FAILED: " & msg severity note;
    wait for 10 us;
    report "Shutdown due to the above failure" severity failure;
    wait;
  end procedure;

  -- Generates a clock signal, shutting down when the test case completes.
  procedure stream_tb_gen_clock(signal clk: out std_logic; period: time) is
  begin
    while not stream_tb_done loop
      clk <= '1';
      wait for period / 2;
      clk <= '0';
      wait for (period + 1 ps) / 2;
    end loop;
    wait;
  end procedure;

  -- Returns the global stream queue entry with the given name. If no entry
  -- exists yet, this creates one.
  procedure stream_tb_get(
    name                        : in  string;
    reg                         : out stream_tb_reg_ll_ptr
  ) is
    variable ptr                : stream_tb_reg_ll_ptr;
  begin
    if stream_tb_reg_ll = null then
      report "Registered first stream node " & name severity note;
      stream_tb_reg_ll := new stream_tb_reg_ll_type'(
        next_node => null,
        name => new string'(name),
        queue => null
      );
      reg := stream_tb_reg_ll;
      return;
    end if;
    ptr := stream_tb_reg_ll;
    while ptr.all.name.all /= name loop
      if ptr.all.next_node = null then
        report "Registered stream node " & name severity note;
        ptr.all.next_node := new stream_tb_reg_ll_type'(
          next_node => null,
          name => new string'(name),
          queue => null
        );
        reg := ptr.all.next_node;
        return;
      end if;
      ptr := ptr.all.next_node;
    end loop;
    --report "Found existing stream node " & name severity note;
    reg := ptr;
  end procedure;

  -- Global simulation helper functions.
  procedure stream_tb_push(
    name                        : in  string;
    data                        : in  std_logic_vector;
    timing                      : in  integer
  ) is
    variable reg                : stream_tb_reg_ll_ptr;
  begin
    stream_tb_get(name, reg);

    -- Push into the front of the queue.
    reg.all.queue := new stream_tb_data_ll_type'(
      next_node => reg.all.queue,
      data      => new std_logic_vector'(data),
      timing    => timing
    );
  end procedure;

  procedure stream_tb_push(
    name                        : in  string;
    data                        : in  std_logic_vector
  ) is
  begin
    stream_tb_push(name, data, -1);
  end procedure;

  procedure stream_tb_push_ascii(
    name                        : in  string;
    data                        : in  string;
    timing                      : in  integer
  ) is
  begin
    for i in data'range loop
      stream_tb_push(name, std_logic_vector(to_unsigned(character'pos(data(i)), 8)), timing);
    end loop;
  end procedure;

  procedure stream_tb_push_ascii(
    name                        : in  string;
    data                        : in  string
  ) is
  begin
    stream_tb_push_ascii(name, data, -1);
  end procedure;

  procedure stream_tb_pop(
    name                        : in  string;
    data                        : out std_logic_vector;
    timing                      : out integer;
    ok                          : out boolean
  ) is
    variable reg                : stream_tb_reg_ll_ptr;
    variable src                : stream_tb_data_ptr;
    variable cur_end, new_end   : stream_tb_data_ll_ptr;
  begin
    stream_tb_get(name, reg);

    -- Fail if the queue is empty.
    if reg.all.queue = null then
      timing := -1;
      ok := false;
      return;
    end if;

    -- Pull from the back of the queue.
    if reg.all.queue.all.next_node = null then
      src := reg.all.queue.all.data;
      if src = null then
        stream_tb_fail("got unexpected null data from stream queue " & name);
      end if;
      if src.all'length /= data'length then
        stream_tb_fail("got unexpected data size from stream queue " & name & ": " &
          integer'image(src'length) & " instead of " & integer'image(data'length));
      end if;
      data := src.all;
      timing := reg.all.queue.all.timing;
      ok := true;
      reg.all.queue := null;
      return;
    end if;
    new_end := reg.all.queue;
    cur_end := reg.all.queue.all.next_node;
    while cur_end.all.next_node /= null loop
      new_end := cur_end;
      cur_end := cur_end.all.next_node;
    end loop;
    src := cur_end.all.data;
    if src = null then
      stream_tb_fail("got unexpected null data from stream queue " & name);
    end if;
    if src.all'length /= data'length then
      stream_tb_fail("got unexpected data size from stream queue " & name & ": " &
        integer'image(src'length) & " instead of " & integer'image(data'length));
    end if;
    data := src.all;
    timing := cur_end.all.timing;
    ok := true;
    new_end.next_node := null;
  end procedure;

  procedure stream_tb_pop(
    name                        : in  string;
    data                        : out std_logic_vector;
    ok                          : out boolean
  ) is
    variable timing             : integer;
  begin
    stream_tb_pop(name, data, timing, ok);
  end procedure;

  procedure stream_tb_pop(
    name                        : in  string;
    data                        : out std_logic_vector;
    timing                      : out integer;
    timeout                     : in  time
  ) is
    variable ok                 : boolean;
    variable time_passed        : time := 0 ns;
  begin
    while time_passed < timeout loop
      stream_tb_pop(name, data, timing, ok);
      if ok then
        return;
      end if;
      wait for 2.5 ns;
      time_passed := time_passed + 2.5 ns;
    end loop;
    stream_tb_fail("timeout waiting for data from stream " & name);
  end procedure;

  procedure stream_tb_pop(
    name                        : in  string;
    data                        : out std_logic_vector;
    timeout                     : in  time
  ) is
    variable timing             : integer;
  begin
    stream_tb_pop(name, data, timing, timeout);
  end procedure;

  procedure stream_tb_expect(
    name                        : in  string;
    expected                    : in  std_logic_vector;
    timeout                     : in  time
  ) is
    variable actual             : std_logic_vector(expected'range);
  begin
    stream_tb_pop(name, actual, timeout);
    if not std_match(actual, expected) then
      stream_tb_fail("data mismatch for stream " & name & "; "
        & "expected " & to_string(expected) & " but got " & to_string(actual));
    end if;
  end procedure;

  procedure stream_tb_expect(
    name                        : in  string;
    expected                    : in  std_logic_vector;
    mask                        : in  std_logic_vector;
    timeout                     : in  time
  ) is
    variable actual             : std_logic_vector(expected'range);
  begin
    stream_tb_pop(name, actual, timeout);
    if (actual and mask) /= (expected and mask) then
      stream_tb_fail("data mismatch for stream " & name & "; "
        & "expected " & to_string(expected, mask) & " but got " & to_string(actual));
    end if;
  end procedure;

  procedure stream_tb_expect_ascii(
    name                        : in  string;
    expected                    : in  string;
    char_timeout                : in  time
  ) is
  begin
    for i in expected'range loop
      stream_tb_expect(name, std_logic_vector(to_unsigned(character'pos(expected(i)), 8)), char_timeout);
    end loop;
  end procedure;

  procedure stream_tb_expect_stream(
    name                        : in  string;
    expected                    : in  string;
    bits                        : in  natural;
    timeout                     : in  time
  ) is
    variable expected_slv       : std_logic_vector(bits-1 downto 0);
    variable ok                 : boolean;
  begin
    loop
      stream_tb_pop(expected, expected_slv, ok);
      exit when not ok;
      stream_tb_expect(name, expected_slv, timeout);
    end loop;
  end procedure;

  procedure stream_tb_complete is
    variable ptr                : stream_tb_reg_ll_ptr;
  begin
    ptr := stream_tb_reg_ll;
    while ptr /= null loop
      if ptr.all.queue /= null then
        stream_tb_fail("there is unconsumed data in stream " & ptr.all.name.all);
      end if;
      ptr := ptr.all.next_node;
    end loop;
    stream_tb_succeed("simulation complete");
  end procedure;

end StreamSim;
