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

library work;
use work.Streams.all;
use work.Utils.all;
use work.Arrow.all;
use work.Arrays.all;

use work.SimUtils.all;

use work.stringwrite_pkg.all;

entity stringwrite_usercore is
  generic(
    NUM_USER_REGS                              : natural;
    TAG_WIDTH                                  : natural;
    BUS_ADDR_WIDTH                             : natural;
    INDEX_WIDTH                                : natural;
    REG_WIDTH                                  : natural
  );
  port(
    -------------------------------------------------------------------------
    acc_reset                                  : in std_logic;
    acc_clk                                    : in std_logic;
    -------------------------------------------------------------------------
    Str_in_values_in_count                     : out std_logic_vector(6 downto 0);
    Str_in_values_in_data                      : out std_logic_vector(511 downto 0);
    Str_in_values_in_dvalid                    : out std_logic;
    Str_in_values_in_last                      : out std_logic;
    Str_in_values_in_valid                     : out std_logic;
    Str_in_values_in_ready                     : in std_logic;
    -------------------------------------------------------------------------
    Str_in_length                              : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    Str_in_last                                : out std_logic;
    Str_in_valid                               : out std_logic;
    Str_in_dvalid                              : out std_logic;
    Str_in_ready                               : in std_logic;
    -------------------------------------------------------------------------
    Str_cmd_firstIdx                           : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    Str_cmd_lastIdx                            : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    Str_cmd_tag                                : out std_logic_vector(TAG_WIDTH-1 downto 0);
    Str_cmd_Str_offsets_addr                   : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    Str_cmd_Str_values_addr                    : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    Str_cmd_valid                              : out std_logic;
    Str_cmd_ready                              : in std_logic;
    -------------------------------------------------------------------------
    Str_unl_valid                              : in std_logic;
    Str_unl_ready                              : out std_logic;
    Str_unl_tag                                : in std_logic_vector(TAG_WIDTH-1 downto 0);
    -------------------------------------------------------------------------
    ctrl_done                                  : out std_logic;
    ctrl_busy                                  : out std_logic;
    ctrl_idle                                  : out std_logic;
    ctrl_reset                                 : in std_logic;
    ctrl_stop                                  : in std_logic;
    ctrl_start                                 : in std_logic;
    -------------------------------------------------------------------------
    reg_Str_offsets_addr                       : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    reg_Str_values_addr                        : in std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    -------------------------------------------------------------------------
    idx_first                                  : in std_logic_vector(REG_WIDTH-1 downto 0);
    idx_last                                   : in std_logic_vector(REG_WIDTH-1 downto 0);
    reg_return0                                : out std_logic_vector(REG_WIDTH-1 downto 0);
    reg_return1                                : out std_logic_vector(REG_WIDTH-1 downto 0);
    -------------------------------------------------------------------------
    regs_in                                    : in std_logic_vector(NUM_USER_REGS*REG_WIDTH-1 downto 0);
    regs_out                                   : out std_logic_vector(NUM_USER_REGS*REG_WIDTH-1 downto 0);
    regs_out_en                                : out std_logic_vector(NUM_USER_REGS-1 downto 0)
  );
end entity;

architecture Implementation of stringwrite_usercore is

 -----------------------------------------------------------------------------
  -- Application constants
  -----------------------------------------------------------------------------
  constant ELEMENT_WIDTH        : natural := 8;
  constant ELEMENT_COUNT_MAX    : natural := 64;
  constant ELEMENT_COUNT_WIDTH  : natural := log2ceil(ELEMENT_COUNT_MAX+1);

  -- String length width
  constant LEN_WIDTH : natural  := 8;

  -- Convenience signals for custom registers
  signal reg_str_len_min      : std_logic_vector(LEN_WIDTH-1 downto 0);
  signal reg_str_utf8_mask    : std_logic_vector(ELEMENT_WIDTH-1 downto 0);

  -- Global control state machine
  type state_type is (IDLE, STRINGGEN, INTERFACE, UNLOCK);

  type reg_record is record
    idle                      : std_logic;
    busy                      : std_logic;
    done                      : std_logic;
    reset_start               : std_logic;
    state                     : state_type;
  end record;

   -- Fletcher command stream
  type cmd_record is record
    valid                     : std_logic;
    firstIdx                  : std_logic_vector(INDEX_WIDTH-1 downto 0);
    lastIdx                   : std_logic_vector(INDEX_WIDTH-1 downto 0);
    tag                       : std_logic_vector(TAG_WIDTH-1 downto 0);
  end record;

  -- UTF8 string gen command stream
  type str_record is record
    valid                     : std_logic;
    len                       : std_logic_vector(INDEX_WIDTH-1 downto 0);
    min                       : std_logic_vector(LEN_WIDTH-1 downto 0);
    mask                      : std_logic_vector(LEN_WIDTH-1 downto 0);
  end record;

  -- Unlock ready signal
  type unl_record is record
    ready                     : std_logic;
  end record;

  -- Outputs
  type out_record is record
    cmd                       : cmd_record;
    str                       : str_record;
    unl                       : unl_record;
  end record;
  
  -- State machine signals
  signal r : reg_record;
  signal d : reg_record;
  
  -- String stream generator signals
  signal ssg_cmd_valid          : std_logic;
  signal ssg_cmd_ready          : std_logic;
  signal ssg_cmd_len            : std_logic_vector(INDEX_WIDTH-1 downto 0);
  signal ssg_cmd_strlen_min     : std_logic_vector(LEN_WIDTH-1 downto 0);
  signal ssg_cmd_prng_mask      : std_logic_vector(LEN_WIDTH-1 downto 0);
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
  
  reg_str_len_min   <= regs_in(0 * REG_WIDTH + LEN_WIDTH     - 1 downto 0 * REG_WIDTH);
  reg_str_utf8_mask <= regs_in(1 * REG_WIDTH + ELEMENT_WIDTH - 1 downto 1 * REG_WIDTH);  
  
  ctrl_idle <= r.idle;
  ctrl_busy <= r.busy;
  ctrl_done <= r.done;
  
  seq_proc: process(acc_clk) is
  begin
    if rising_edge(acc_clk) then
      r <= d;

      -- Reset
      if acc_reset = '1' then
        r.state         <= IDLE;
        r.reset_start   <= '0';
        r.busy          <= '0';
        r.done          <= '0';
      end if;
    end if;
  end process;

  comb_proc: process(r, 
    idx_first, idx_last, 
    reg_str_len_min, reg_str_utf8_mask, 
    reg_Str_offsets_addr, reg_Str_values_addr,
    ctrl_start,
    Str_unl_valid, Str_cmd_ready, 
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
    o.cmd.firstIdx            := idx_first;
    o.cmd.lastIdx             := idx_last;
    o.cmd.tag                 := (others => '0');

    -- We use the last index to determine how many strings have to be
    -- generated. This assumes firstIdx is 0.
    o.str.len  := idx_last;
    o.str.min  := reg_str_len_min;
    o.str.mask := reg_str_utf8_mask;
  
    -- Note: string lengths that are generated will be:
    -- (minimum string length) + ((PRNG output) bitwise and (PRNG mask))
    -- Set STRLEN_MIN to 0 and PRNG_MASK to all 1's (strongly not
    -- recommended) to generate all possible string lengths.

    case r.state is
      when IDLE =>
        v.idle := '1';
        
        if ctrl_start = '1' then
          v.reset_start := '1';
          v.state := STRINGGEN;
          v.busy := '1';
          v.done := '0';
          v.idle := '0';
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

        if Str_cmd_ready = '1' then
          -- Interface command is accepted, wait for unlock.
          v.state := UNLOCK;
        end if;

      when UNLOCK =>
        o.unl.ready := '1';

        if Str_unl_valid = '1' then
          v.state := IDLE;
          -- Make done and reset busy
          v.done := '1';
          v.busy := '0';
        end if;

    end case;

    -- Registered outputs:
    d                         <= v;
    
    -- Combinatorial outputs:
    
    -- String stream generator
    ssg_cmd_valid             <= o.str.valid;
    ssg_cmd_len               <= o.str.len;
    ssg_cmd_prng_mask         <= o.str.mask;
    ssg_cmd_strlen_min        <= o.str.min;
    
    -- Interface
    Str_cmd_Str_offsets_addr  <= reg_Str_offsets_addr;
    Str_cmd_Str_values_addr   <= reg_Str_values_addr;
    Str_cmd_valid             <= o.cmd.valid;
    Str_cmd_firstIdx          <= o.cmd.firstIdx;
    Str_cmd_lastIdx           <= o.cmd.lastIdx;
    Str_cmd_tag               <= o.cmd.tag;

    Str_unl_ready             <= o.unl.ready;

  end process;

  -----------------------------------------------------------------------------
  -- String generator unit
  -----------------------------------------------------------------------------
  -- Generates a pseudorandom stream of lengths and characters with appropriate
  -- last signals and counts

  stream_gen_inst: UTF8StringGen
    generic map (
      INDEX_WIDTH           => INDEX_WIDTH,
      ELEMENT_WIDTH         => ELEMENT_WIDTH,
      ELEMENT_COUNT_MAX     => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH   => ELEMENT_COUNT_WIDTH,
      LEN_WIDTH             => LEN_WIDTH,
      LENGTH_BUFFER_DEPTH   => 32,
      LEN_SLICE             => true,
      UTF8_SLICE            => true
    )
    port map (
      clk                   => acc_clk,
      reset                 => acc_reset,
      cmd_valid             => ssg_cmd_valid,
      cmd_ready             => ssg_cmd_ready,
      cmd_len               => ssg_cmd_len,
      cmd_strlen_min        => ssg_cmd_strlen_min,
      cmd_prng_mask         => ssg_cmd_prng_mask,
      len_valid             => ssg_len_valid,
      len_ready             => ssg_len_ready,
      len_data              => ssg_len_data,
      len_last              => ssg_len_last,
      len_dvalid            => ssg_len_dvalid,
      utf8_valid            => ssg_utf8_valid,
      utf8_ready            => ssg_utf8_ready,
      utf8_data             => ssg_utf8_data,
      utf8_count            => ssg_utf8_count,
      utf8_last             => ssg_utf8_last,
      utf8_dvalid           => ssg_utf8_dvalid
    );
    
  -----------------------------------------------------------------------------
  -- Connection to interface
  -----------------------------------------------------------------------------
  Str_in_values_in_count    <= ssg_utf8_count;
  Str_in_values_in_data     <= ssg_utf8_data;
  Str_in_values_in_dvalid   <= ssg_utf8_dvalid;
  Str_in_values_in_last     <= ssg_utf8_last;
  Str_in_values_in_valid    <= ssg_utf8_valid;
  ssg_utf8_ready            <= Str_in_values_in_ready;

  Str_in_length             <= ssg_len_data;
  Str_in_last               <= ssg_len_last;
  Str_in_valid              <= ssg_len_valid;
  Str_in_dvalid             <= ssg_len_dvalid;
  ssg_len_ready             <= Str_in_ready;

end architecture;
