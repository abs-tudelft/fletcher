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
use work.UtilInt_pkg.all;
use work.UtilConv_pkg.all;
use work.UtilMisc_pkg.all;

-- This entity simulates a user core. It should be synthesizable when
-- randomization generics are set to false.
-- It assumes that the data of an element at a specific index is equal to its
-- index (or the LSBs of that index if the data type is smaller than the index
-- type).

entity UserCoreMock is
  generic (
    -- Number of requests to make
    NUM_REQUESTS                : natural;

    -- Number of elements to request
    NUM_ELEMENTS                : natural;

    -- Randomize the start index (simulation only)
    RANDOMIZE_OFFSET            : boolean;

    -- Randomize the number of elements to request (simulation only)
    RANDOMIZE_NUM_ELEMENTS      : boolean;

    -- Randomize the latency of the in_valid signal
    RANDOMIZE_RESP_LATENCY      : boolean;

    -- Max latency
    MAX_LATENCY                 : natural;

    -- Default latency for non-randomized
    DEFAULT_LATENCY             : natural;

    -- Shift of expected result after adding the sum of a single request
    RESULT_LSHIFT               : natural;

    RESP_TIMEOUT                : natural;

    WAIT_FOR_PREV_LAST          : boolean;

    SEED                        : positive;

    IS_OFFSETS_BUFFER           : boolean;

    DATA_WIDTH                  : natural;
    INDEX_WIDTH                 : natural;
    ELEMENT_WIDTH               : natural;
    ELEMENT_COUNT_MAX           : natural;
    ELEMENT_COUNT_WIDTH         : natural
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    start                       : in  std_logic;
    done                        : out std_logic;

    -- Error signals
    req_resp_error              : out std_logic; -- Done but not equal number of reqs/resps
    incorrect                   : out std_logic; -- Incorrect result of the checksum
    timeout                     : out std_logic; -- A timeout has occured

    rows                        : in  std_logic_vector(INDEX_WIDTH-1 downto 0);

    cmd_valid                   : out std_logic;
    cmd_ready                   : in  std_logic;
    cmd_firstIdx                : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmd_lastIdx                 : out std_logic_vector(INDEX_WIDTH-1 downto 0);

    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_data                     : in  std_logic_vector(DATA_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    in_last                     : in  std_logic
  );
end entity UserCoreMock;

architecture tb of UserCoreMock is

  constant REQ_SHIFT            : natural := log2ceil(NUM_ELEMENTS);
  constant ELEMENTS_PER_WORD    : natural := DATA_WIDTH / ELEMENT_WIDTH;

  procedure generate_command (
    variable offset             : inout unsigned(INDEX_WIDTH-1 downto 0);
    variable elements           : inout unsigned(INDEX_WIDTH-1 downto 0);
    signal   num_rows           : in    std_logic_vector(INDEX_WIDTH-1 downto 0);
    variable seed2              : inout positive
  ) is
    variable seed1              : positive := SEED;
    variable rand               : real;
  begin

    if RANDOMIZE_OFFSET then
      uniform(seed1, seed2, rand);
      offset                    := u(natural(rand * real(int(num_rows) - int(elements))), INDEX_WIDTH);
    else
      offset                    := offset + elements;
    end if;

    if RANDOMIZE_NUM_ELEMENTS then
      uniform(seed1, seed2, rand);
      elements                  := u(1 + natural(rand * real(NUM_ELEMENTS-1)), INDEX_WIDTH);
    else
      elements                  := u(NUM_ELEMENTS, INDEX_WIDTH);
    end if;

    -- Wrap offset
    if (offset + elements) > u(rows) then
      offset                    := u(0, INDEX_WIDTH);
    end if;
  end procedure;

  procedure randomize_latency (
    variable latency            : inout integer range 0 to MAX_LATENCY;
    variable seed2              : inout positive
  ) is
    variable seed1              : positive := SEED;
    variable rand               : real;
  begin
    if RANDOMIZE_RESP_LATENCY then
      uniform(seed1, seed2, rand);
      latency                   := integer(rand * real(MAX_LATENCY));
    else
      latency                   := DEFAULT_LATENCY;
    end if;
  end procedure;
  
  type req_state_type is (IDLE, REQUEST, ACCEPT, HOLD, FINISHED);

  type req is record
    state                       : req_state_type;
    requests                    : integer range 0 to NUM_REQUESTS;
    total_elements              : unsigned(INDEX_WIDTH-1 downto 0);
    elements                    : unsigned(INDEX_WIDTH-1 downto 0);
    offset                      : unsigned(INDEX_WIDTH-1 downto 0);
    valid                       : std_logic;
    firstIdx                    : unsigned(INDEX_WIDTH-1 downto 0);
    lastIdx                     : unsigned(INDEX_WIDTH-1 downto 0);
  end record;

  constant req_empty            : req := (
    state                       => IDLE,
    requests                    => 0,
    total_elements              => u(0, INDEX_WIDTH),
    elements                    => u(0, INDEX_WIDTH),
    offset                      => u(0, INDEX_WIDTH),
    valid                       => '0',
    firstIdx                    => u(0, INDEX_WIDTH),
    lastIdx                     => u(0, INDEX_WIDTH)
  );

  type resp_state_type is (IDLE, GO, FINISHED);

  type resp is record
    state                       : resp_state_type;
    elements                    : unsigned(INDEX_WIDTH-1 downto 0);
    result                      : unsigned(ELEMENT_WIDTH-1 downto 0);
    responses                   : integer range 0 to NUM_REQUESTS;
    latency                     : integer range 0 to MAX_LATENCY;
    timeout_cnt                 : integer range 0 to RESP_TIMEOUT;
    ready                       : std_logic;
    done                        : std_logic;
    req_resp_error              : std_logic;
    incorrect                   : std_logic;
    timeout                     : std_logic;
  end record;

  constant resp_empty           : resp := (
    state                       => IDLE,
    elements                    => u(0, INDEX_WIDTH),
    result                      => u(0, ELEMENT_WIDTH),
    responses                   => 0,
    latency                     => 0,
    timeout_cnt                 => RESP_TIMEOUT,
    ready                       => '0',
    done                        => '0',
    req_resp_error              => '0',
    incorrect                   => '0',
    timeout                     => '0'
  );

  signal rq                     : req;
  signal dq                     : req;

  signal rs                     : resp;
  signal ds                     : resp;

  signal timeout_rst            : std_logic;

  signal expected_result        : unsigned(ELEMENT_WIDTH-1 downto 0);


begin
  sequential : process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        rq                      <= req_empty;
        rs                      <= resp_empty;
      else
        rq                      <= dq;
        rs                      <= ds;
      end if;
    end if;
  end process;

  requests : process(rq, cmd_ready, rows, rs)
    variable v                  : req;
    variable seed               : positive := 1;
  begin

    v                           := rq;
    timeout_rst                 <= '0';

    case v.state is

      when IDLE =>
        if start = '1' then
          v.requests            := 0;
          v.offset              := (others => '0');
          v.elements            := (others => '0');
          timeout_rst           <= '1';
          v.state               := REQUEST;
        end if;

      when REQUEST => 
        generate_command(v.offset, v.elements, rows, seed);
        v.requests              := v.requests + 1;
        v.total_elements        := v.total_elements + v.elements;
        v.firstIdx              := v.offset;
        v.lastIdx               := v.offset + v.elements;
        v.valid                 := '1';
        v.state                 := ACCEPT;
        
      when ACCEPT =>
        if cmd_ready = '1' then
          timeout_rst           <= '1';
          v.valid               := '0';
          if WAIT_FOR_PREV_LAST then
            v.state             := HOLD;
          else
            if v.requests < NUM_REQUESTS then
              v.state           := REQUEST;
            else
              v.state           := FINISHED;
            end if;
          end if;
        end if;
      
      when HOLD =>
        if v.total_elements = rs.elements then
          if v.requests < NUM_REQUESTS then
            v.state           := REQUEST;
          else
            v.state           := FINISHED;
          end if;
        end if;

      when FINISHED =>
        if start = '1' and rs.done = '1' then
          v.state               := REQUEST;
        end if;

    end case;

    dq                          <= v;

  end process;

  cmd_valid                     <= rq.valid;
  cmd_firstIdx                  <= slv(rq.firstIdx);
  cmd_lastIdx                   <= slv(rq.lastIdx);

  -- cmd_valid, cmd_ready, cmd_firstIdx, cmd_lastIdx
  update_expected_result : process(clk)
    variable a                  : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable b                  : unsigned(ELEMENT_WIDTH-1 downto 0);
    variable a2                 : unsigned(2*ELEMENT_WIDTH-1 downto 0);
    variable b2                 : unsigned(2*ELEMENT_WIDTH-1 downto 0);
    variable sum                : unsigned(2*ELEMENT_WIDTH-1 downto 0);
  begin
    if rising_edge(clk) then
      if reset = '1' then
        expected_result         <= u(0, ELEMENT_WIDTH);
      else
        if rq.valid = '1' and cmd_ready = '1' then
          -- The expected result is the sum of indices of the requested indexes
          -- If first idx = a and last idx = b then
          -- s is the sum from n=a to n=b-1 of n, which is
          -- s = -1/2(a-b)(a+b-1) = 1/2 (-a^2+a+b^2-b)
          a                     := resize(dq.firstIdx, ELEMENT_WIDTH);
          b                     := resize(dq.lastIdx, ELEMENT_WIDTH);
          a2                    := a*a;
          b2                    := b*b;
          sum                   := shift(a+b2-a2-b,RESULT_LSHIFT-1);

          expected_result       <= expected_result + sum(ELEMENT_WIDTH-1 downto 0);
        end if;
      end if;
    end if;
  end process;


  responses : process(rs, in_valid, in_data, in_count, timeout_rst, in_last)
    variable v                  : resp;
    variable seed               : positive := 1;
  begin

    v                           := rs;

    case v.state is

      when IDLE =>

        if start = '1' then
          randomize_latency(v.latency, seed);
          v.state               := GO;
        end if;

      when GO =>
        if in_valid = '1' then
          v.timeout_cnt         := RESP_TIMEOUT;
          if v.latency = 0 then
            v.ready             := '1';

            -- Bwaaaarghhhh
            if in_last = '1' and v.responses /= rq.requests then
              v.responses       := v.responses + 1;
            end if;

            for I in 0 to ELEMENTS_PER_WORD-1 loop
              v.result          := v.result + u(in_data((I+1) * ELEMENT_WIDTH - 1 downto I * ELEMENT_WIDTH));
            end loop;

            if IS_OFFSETS_BUFFER then
              v.elements        := v.elements + 1;
            else
              v.elements        := v.elements + u(in_count);
            end if;

            randomize_latency(v.latency, seed);

          else
            v.ready             := '0';
            v.latency           := v.latency - 1;
          end if;
        end if;
        
        if      v.responses = rq.requests
            and v.elements  = rq.total_elements
            and rq.state    = FINISHED
        then
          v.state           := FINISHED;
        end if;

        -- Timeout counter
        if v.timeout_cnt = 0 then
          v.state               := FINISHED;
        else
          if timeout_rst = '1' then
            v.timeout_cnt       := RESP_TIMEOUT;
          else
            v.timeout_cnt       := v.timeout_cnt - 1;
          end if;
        end if;

      when FINISHED =>
        v.done                  := '1';

        if v.elements /= rq.total_elements then
          v.req_resp_error      := '1';
        end if;

        if expected_result /= v.result then
          v.incorrect           := '1';
        end if;

        if v.timeout_cnt = 0 then
          v.incorrect           := '1';
          v.timeout             := '1';
        end if;

        if start = '1' then
          v.state               := GO;
        end if;

    end case;
    ds                          <= v;

  end process;

  in_ready                      <= ds.ready;
  done                          <= ds.done;
  incorrect                     <= ds.incorrect;
  timeout                       <= ds.timeout;
  req_resp_error                <= ds.req_resp_error;

end architecture;
