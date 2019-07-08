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
use work.UtilInt_pkg.all;
use work.UTF8StringGen_pkg.all;

entity Kernel is
  generic (
    BUS_ADDR_WIDTH                  : integer := 64
  );
  port (
    kcd_clk                         : in  std_logic;
    kcd_reset                       : in  std_logic;
    mmio_awvalid                    : in  std_logic;
    mmio_awready                    : out std_logic;
    mmio_awaddr                     : in  std_logic_vector(31 downto 0);
    mmio_wvalid                     : in  std_logic;
    mmio_wready                     : out std_logic;
    mmio_wdata                      : in  std_logic_vector(31 downto 0);
    mmio_wstrb                      : in  std_logic_vector(3 downto 0);
    mmio_bvalid                     : out std_logic;
    mmio_bready                     : in  std_logic;
    mmio_bresp                      : out std_logic_vector(1 downto 0);
    mmio_arvalid                    : in  std_logic;
    mmio_arready                    : out std_logic;
    mmio_araddr                     : in  std_logic_vector(31 downto 0);
    mmio_rvalid                     : out std_logic;
    mmio_rready                     : in  std_logic;
    mmio_rdata                      : out std_logic_vector(31 downto 0);
    mmio_rresp                      : out std_logic_vector(1 downto 0);
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
    StringWrite_String_chars_data   : out std_logic_vector(511 downto 0);
    StringWrite_String_chars_count  : out std_logic_vector(6 downto 0);
    StringWrite_String_cmd_valid    : out std_logic;
    StringWrite_String_cmd_ready    : in  std_logic;
    StringWrite_String_cmd_firstIdx : out std_logic_vector(31 downto 0);
    StringWrite_String_cmd_lastidx  : out std_logic_vector(31 downto 0);
    StringWrite_String_cmd_ctrl     : out std_logic_vector(2*bus_addr_width-1 downto 0);
    StringWrite_String_cmd_tag      : out std_logic_vector(0 downto 0);
    StringWrite_String_unl_valid    : in  std_logic;
    StringWrite_String_unl_ready    : out std_logic;
    StringWrite_String_unl_tag      : in  std_logic_vector(0 downto 0)
  );
end entity;

architecture Behavioral of Kernel is
  -----------------------------------------------------------------------------
  -- MMIO
  -----------------------------------------------------------------------------
  -- Default Fletcher registers:
  constant REG_CONTROL                            : natural :=  0;
  constant REG_STATUS                             : natural :=  1;
  constant REG_RETURN0                            : natural :=  2;
  constant REG_RETURN1                            : natural :=  3;

  -- RecordBatch ranges:
  constant REG_STRINGWRITE_FIRSTIDX               : natural :=  4;
  constant REG_STRINGWRITE_LASTIDX                : natural :=  5;

  -- Buffer addresses:
  constant REG_STRINGWRITE_STRING_OFFSETS_BUF_LO  : natural :=  6;
  constant REG_STRINGWRITE_STRING_OFFSETS_BUF_HI  : natural :=  7;
  constant REG_STRINGWRITE_STRING_VALUES_BUF_LO   : natural :=  8;
  constant REG_STRINGWRITE_STRING_VALUES_BUF_HI   : natural :=  9;

  -- Custom application registers
  constant REG_CUSTOM_STRLEN_MIN                  : natural := 10;
  constant REG_CUSTOM_STRLEN_MASK                 : natural := 11;

  -- Array of MMIO registers:
  constant NUM_REGS                               : natural := 12;
  constant REG_WIDTH                              : natural := 32;

  type reg_array_t is array(natural range <>) of std_logic_vector(31 downto 0);

  signal rreg_concat            : std_logic_vector(NUM_REGS*32-1 downto 0);
  signal rreg_array             : reg_array_t(0 to NUM_REGS-1);
  signal rreg_en                : std_logic_vector(NUM_REGS-1 downto 0);

  signal wreg_array             : reg_array_t(0 to NUM_REGS-1);
  signal wreg_concat            : std_logic_vector(NUM_REGS*32-1 downto 0);

  -----------------------------------------------------------------------------
  -- Control signals
  -----------------------------------------------------------------------------
  signal stat_done              : std_logic;
  signal stat_busy              : std_logic;
  signal stat_idle              : std_logic;
  signal ctrl_reset             : std_logic;
  signal ctrl_stop              : std_logic;
  signal ctrl_start             : std_logic;
  signal kcd_reset_n            : std_logic;

 ------------------------------------------------------------------------------
  -- Application constants
  -----------------------------------------------------------------------------
  constant INDEX_WIDTH          : natural := 32;
  constant TAG_WIDTH            : natural := 1;

  constant ELEMENT_WIDTH        : natural := 8;
  constant ELEMENT_COUNT_MAX    : natural := 64;
  constant ELEMENT_COUNT_WIDTH  : natural := log2ceil(ELEMENT_COUNT_MAX+1);

  -- String length width
  constant LEN_WIDTH : natural  := 8;

  -- Global control state machine
  type state_type is (IDLE, STRINGGEN, INTERFACE, UNLOCK);

  type reg_record is record
    idle                        : std_logic;
    busy                        : std_logic;
    done                        : std_logic;
    reset_start                 : std_logic;
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

  -----------------------------------------------------------------------------
  -- MMIO
  -----------------------------------------------------------------------------
  kcd_reset_n <= not(kcd_reset);

  -- Instantiate the AXI mmio component to communicate with host more easily
  -- through registers.
  axi_mmio_inst : AxiMmio
    generic map (
      BUS_ADDR_WIDTH     => 32,
      BUS_DATA_WIDTH     => 32,
      NUM_REGS           => NUM_REGS,
      REG_CONFIG         => "WRRRWWWWWWWW",
      SLV_R_SLICE_DEPTH  => 0,
      SLV_W_SLICE_DEPTH  => 0
    )
    port map (
      clk                => kcd_clk,
      reset_n            => kcd_reset_n,
      s_axi_awvalid      => mmio_awvalid,
      s_axi_awready      => mmio_awready,
      s_axi_awaddr       => mmio_awaddr,
      s_axi_wvalid       => mmio_wvalid,
      s_axi_wready       => mmio_wready,
      s_axi_wdata        => mmio_wdata,
      s_axi_wstrb        => mmio_wstrb,
      s_axi_bvalid       => mmio_bvalid,
      s_axi_bready       => mmio_bready,
      s_axi_bresp        => mmio_bresp,
      s_axi_arvalid      => mmio_arvalid,
      s_axi_arready      => mmio_arready,
      s_axi_araddr       => mmio_araddr,
      s_axi_rvalid       => mmio_rvalid,
      s_axi_rready       => mmio_rready,
      s_axi_rdata        => mmio_rdata,
      s_axi_rresp        => mmio_rresp,
      regs_out           => wreg_concat,
      regs_in            => rreg_concat,
      regs_in_en         => rreg_en
    );

  -- Turn signals into something more readable
  write_regs_unconcat: for I in 0 to NUM_REGS-1 generate
    wreg_array(I) <= wreg_concat((I+1)*32-1 downto I*32);
  end generate;
  read_regs_concat: for I in 0 to NUM_REGS-1 generate
    rreg_concat((I+1)*32-1 downto I*32) <= rreg_array(I);
  end generate;

  -- Always enable read registers
  rreg_array(REG_STATUS) <= (0 => stat_idle, 1 => stat_busy, 2 => stat_done, others => '0');
  rreg_en <= (REG_STATUS => '1', REG_RETURN0 => '1', REG_RETURN1 => '1', others => '0');

  -- We don't use the return registers for this kernel. Put some random data.
  rreg_array(REG_RETURN0) <= X"42001337";
  rreg_array(REG_RETURN1) <= X"0DDF00D5";

  -- Connect the control bits
  ctrl_start <= wreg_array(REG_CONTROL)(0);
  ctrl_stop  <= wreg_array(REG_CONTROL)(1);
  ctrl_reset <= wreg_array(REG_CONTROL)(2);

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
        r.state         <= IDLE;
        r.reset_start   <= '0';
        r.busy          <= '0';
        r.done          <= '0';
      end if;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Combinatorial process

  comb_proc: process(r,
    wreg_array,
    ctrl_start, ctrl_stop, ctrl_reset,
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
    o.cmd.firstIdx            := wreg_array(REG_STRINGWRITE_FIRSTIDX);
    o.cmd.lastIdx             := wreg_array(REG_STRINGWRITE_LASTIDX);
    o.cmd.tag                 := (others => '0');

    -- We use the last index to determine how many strings have to be
    -- generated. This assumes firstIdx is 0.
    o.str.len  := wreg_array(REG_STRINGWRITE_LASTIDX);
    o.str.min  := wreg_array(REG_CUSTOM_STRLEN_MIN)(7 downto 0);
    o.str.mask := wreg_array(REG_CUSTOM_STRLEN_MASK)(7 downto 0);

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

        if StringWrite_String_cmd_ready = '1' then
          -- Interface command is accepted, wait for unlock.
          v.state := UNLOCK;
        end if;

      when UNLOCK =>
        o.unl.ready := '1';

        if StringWrite_String_unl_valid = '1' then
          v.state := IDLE;
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

    -- Interface
    StringWrite_String_cmd_ctrl <= wreg_array(REG_STRINGWRITE_STRING_VALUES_BUF_HI)   -- Values buffer
                                 & wreg_array(REG_STRINGWRITE_STRING_VALUES_BUF_LO)
                                 & wreg_array(REG_STRINGWRITE_STRING_OFFSETS_BUF_HI)  -- Offsets buffer
                                 & wreg_array(REG_STRINGWRITE_STRING_OFFSETS_BUF_LO);
    StringWrite_String_cmd_valid    <= o.cmd.valid;
    StringWrite_String_cmd_firstIdx <= o.cmd.firstIdx;
    StringWrite_String_cmd_lastIdx  <= o.cmd.lastIdx;
    StringWrite_String_cmd_tag      <= o.cmd.tag;

    StringWrite_String_unl_ready    <= o.unl.ready;

    -- Registered outputs:
    stat_idle                   <= r.idle;
    stat_busy                   <= r.busy;
    stat_done                   <= r.done;
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
  StringWrite_String_chars_data   <= ssg_utf8_data;
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
