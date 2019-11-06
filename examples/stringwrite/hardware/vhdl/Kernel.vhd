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
use work.UtilStr_pkg.all;
use work.UtilInt_pkg.all;
use work.UTF8StringGen_pkg.all;

entity Kernel is
  generic (
    INDEX_WIDTH : integer := 32;
    TAG_WIDTH   : integer := 1
  );
  port (
    kcd_clk                         : in  std_logic;
    kcd_reset                       : in  std_logic;
    StringWrite_String_valid        : out std_logic;
    StringWrite_String_ready        : in  std_logic;
    StringWrite_String_dvalid       : out std_logic;
    StringWrite_String_last         : out std_logic;
    StringWrite_String_length       : out std_logic_vector(31 downto 0);
    StringWrite_String_count        : out std_logic_vector(0 downto 0);
    StringWrite_String_chars_valid  : out std_logic;
    StringWrite_String_chars_ready  : in  std_logic;
    StringWrite_String_chars_dvalid : out std_logic;
    StringWrite_String_chars_last   : out std_logic;
    StringWrite_String_chars        : out std_logic_vector(511 downto 0);
    StringWrite_String_chars_count  : out std_logic_vector(6 downto 0);
    StringWrite_String_unl_valid    : in  std_logic;
    StringWrite_String_unl_ready    : out std_logic;
    StringWrite_String_unl_tag      : in  std_logic_vector(TAG_WIDTH-1 downto 0);
    StringWrite_String_cmd_valid    : out std_logic;
    StringWrite_String_cmd_ready    : in  std_logic;
    StringWrite_String_cmd_firstIdx : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    StringWrite_String_cmd_lastIdx  : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    StringWrite_String_cmd_tag      : out std_logic_vector(TAG_WIDTH-1 downto 0);
    start                           : in  std_logic;
    stop                            : in  std_logic;
    reset                           : in  std_logic;
    idle                            : out std_logic;
    busy                            : out std_logic;
    done                            : out std_logic;
    result                          : out std_logic_vector(63 downto 0);
    StringWrite_firstidx            : in  std_logic_vector(31 downto 0);
    StringWrite_lastidx             : in  std_logic_vector(31 downto 0);
    strlen_min                      : in  std_logic_vector(31 downto 0);
    strlen_mask                     : in  std_logic_vector(31 downto 0)
  );
end entity;

architecture Behavioral of Kernel is
 ------------------------------------------------------------------------------
  -- Application constants
  -----------------------------------------------------------------------------
  constant ELEMENT_WIDTH        : natural := 8;
  constant ELEMENT_COUNT_MAX    : natural := 64;
  constant ELEMENT_COUNT_WIDTH  : natural := log2ceil(ELEMENT_COUNT_MAX+1);

  -- String length width
  constant LEN_WIDTH : natural  := 8;

  -- Global control state machine
  type state_type is (SIDLE, SSTART, STRINGGEN, INTERFACE, UNLOCK);

  type reg_record is record
    idle                        : std_logic;
    busy                        : std_logic;
    done                        : std_logic;
    state                       : state_type;
  end record;

   -- Fletcher command stream
  type cmd_record is record
    valid                       : std_logic;
    firstIdx                    : std_logic_vector(INDEX_WIDTH-1 downto 0);
    lastIdx                     : std_logic_vector(INDEX_WIDTH-1 downto 0);
    tag                         : std_logic_vector(TAG_WIDTH-1 downto 0);
  end record;

  -- UTF8 string gen command stream
  type str_record is record
    valid                       : std_logic;
    len                         : std_logic_vector(INDEX_WIDTH-1 downto 0);
    min                         : std_logic_vector(LEN_WIDTH-1 downto 0);
    mask                        : std_logic_vector(LEN_WIDTH-1 downto 0);
  end record;

  -- Unlock ready signal
  type unl_record is record
    ready                       : std_logic;
  end record;

  -- Outputs
  type out_record is record
    cmd                         : cmd_record;
    str                         : str_record;
    unl                         : unl_record;
  end record;

  -- State machine signals
  signal r : reg_record;
  signal d : reg_record;

  -- String stream generator signals
  signal ssg_cmd_valid          : std_logic;
  signal ssg_cmd_ready          : std_logic;
  signal ssg_cmd_len            : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal ssg_cmd_strlen_min     : std_logic_vector(LEN_WIDTH-1 downto 0);
  signal ssg_cmd_strlen_mask    : std_logic_vector(LEN_WIDTH-1 downto 0);
  signal ssg_len_valid          : std_logic;
  signal ssg_len_ready          : std_logic;
  signal ssg_len_data           : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal ssg_len_last           : std_logic;
  signal ssg_len_dvalid         : std_logic;
  signal ssg_utf8_valid         : std_logic;
  signal ssg_utf8_ready         : std_logic;
  signal ssg_utf8_data          : std_logic_vector(ELEMENT_COUNT_MAX * ELEMENT_WIDTH-1 downto 0);
  signal ssg_utf8_count         : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
  signal ssg_utf8_last          : std_logic;
  signal ssg_utf8_dvalid        : std_logic;

begin
  -- We don't use the result register for this kernel. Put some random data.
  result <= X"420013370DDF00D5";

  -----------------------------------------------------------------------------
  -- Kernel state machine
  -----------------------------------------------------------------------------

  -----------------------------------------------------------------------------
  -- Register process
  seq_proc: process(kcd_clk) is
  begin
    if rising_edge(kcd_clk) then
      r <= d;

      -- Reset
      if kcd_reset = '1' then
        r.state         <= SIDLE;
        r.busy          <= '0';
        r.done          <= '0';
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Combinatorial process

  comb_proc: process(r,
    start, stop, reset,
    StringWrite_String_cmd_ready,
    StringWrite_String_unl_valid,
    ssg_cmd_ready)
  is
    variable v : reg_record;
    variable o : out_record;
  begin
    v := r;

    -- Disable command streams by default
    o.cmd.valid               := '0';
    o.str.valid               := '0';
    o.unl.ready               := '0';

    -- Default outputs
    o.cmd.firstIdx            := StringWrite_firstIdx;
    o.cmd.lastIdx             := StringWrite_lastIdx;
    o.cmd.tag                 := (others => '0');

    -- We use the last index to determine how many strings have to be
    -- generated. This assumes firstIdx is 0.
    o.str.len  := StringWrite_lastIdx;
    o.str.min  := strlen_min(7 downto 0);
    o.str.mask := strlen_mask(7 downto 0);

    -- Note: string lengths that are generated will be:
    -- (minimum string length) + ((PRNG output) bitwise and (PRNG mask))
    -- Set STRLEN_MIN to 0 and PRNG_MASK to all 1's (strongly not
    -- recommended) to generate all possible string lengths.

    case r.state is
      when SIDLE =>
        v.idle := '1';

        if start = '1' then
          v.state := SSTART;
          v.busy := '1';
          v.done := '0';
          v.idle := '0';
        end if;
        
      when SSTART =>
        -- Wait for start bit to go low, before actually starting, to prevent
        -- too early restarts.
        v.idle := '0';
        if start = '0' then
          v.state := STRINGGEN;
        end if;

      when STRINGGEN =>
        -- Validate command:
        o.str.valid := '1';

        if ssg_cmd_ready = '1' then
          -- String gen command is accepted, start interface
          v.state := INTERFACE;
        end if;

      when INTERFACE =>
        -- Validate command:
        o.cmd.valid    := '1';

        if StringWrite_String_cmd_ready = '1' then
          -- Interface command is accepted, wait for unlock.
          v.state := UNLOCK;
        end if;

      when UNLOCK =>
        o.unl.ready := '1';

        if StringWrite_String_unl_valid = '1' then
          v.state := SIDLE;
          -- Make done and reset busy
          v.done := '1';
          v.busy := '0';
        end if;

    end case;

    ---------------------------------------------------------------------------
    -- Combinatorial outputs:

    -- Next state
    d                           <= v;

    -- String stream generator
    ssg_cmd_valid               <= o.str.valid;
    ssg_cmd_len                 <= o.str.len;
    ssg_cmd_strlen_mask           <= o.str.mask;
    ssg_cmd_strlen_min          <= o.str.min;

    -- Command stream to generated interface
    StringWrite_String_cmd_valid    <= o.cmd.valid;
    StringWrite_String_cmd_firstIdx <= o.cmd.firstIdx;
    StringWrite_String_cmd_lastIdx  <= o.cmd.lastIdx;
    StringWrite_String_cmd_tag      <= o.cmd.tag;

    StringWrite_String_unl_ready    <= o.unl.ready;

    -- Registered outputs:
    idle                   <= r.idle;
    busy                   <= r.busy;
    done                   <= r.done;
  end process;

  -----------------------------------------------------------------------------
  -- String generator unit
  -----------------------------------------------------------------------------
  -- Generates a pseudorandom stream of lengths and characters with appropriate
  -- last signals and counts

  stream_gen_inst: UTF8StringGen
    generic map (
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      ELEMENT_COUNT_MAX         => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => ELEMENT_COUNT_WIDTH,
      LEN_WIDTH                 => LEN_WIDTH,
      LENGTH_BUFFER_DEPTH       => 32,
      LEN_SLICE                 => true,
      UTF8_SLICE                => true
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,
      cmd_valid                 => ssg_cmd_valid,
      cmd_ready                 => ssg_cmd_ready,
      cmd_len                   => ssg_cmd_len,
      cmd_strlen_min            => ssg_cmd_strlen_min,
      cmd_strlen_mask           => ssg_cmd_strlen_mask,
      len_valid                 => ssg_len_valid,
      len_ready                 => ssg_len_ready,
      len_data                  => ssg_len_data,
      len_last                  => ssg_len_last,
      len_dvalid                => ssg_len_dvalid,
      utf8_valid                => ssg_utf8_valid,
      utf8_ready                => ssg_utf8_ready,
      utf8_data                 => ssg_utf8_data,
      utf8_count                => ssg_utf8_count,
      utf8_last                 => ssg_utf8_last,
      utf8_dvalid               => ssg_utf8_dvalid
    );

  -----------------------------------------------------------------------------
  -- Connection to generated interface
  -----------------------------------------------------------------------------
  StringWrite_String_chars_valid  <= ssg_utf8_valid;
  ssg_utf8_ready                  <= StringWrite_String_chars_ready;
  StringWrite_String_chars        <= ssg_utf8_data;
  StringWrite_String_chars_count  <= ssg_utf8_count;
  StringWrite_String_chars_dvalid <= ssg_utf8_dvalid;
  StringWrite_String_chars_last   <= ssg_utf8_last;

  StringWrite_String_valid        <= ssg_len_valid;
  ssg_len_ready                   <= StringWrite_String_ready;
  StringWrite_String_length       <= ssg_len_data;
  StringWrite_String_count        <= (0 => '1', others => '0');
  StringWrite_String_last         <= ssg_len_last;
  StringWrite_String_dvalid       <= ssg_len_dvalid;

end architecture;
