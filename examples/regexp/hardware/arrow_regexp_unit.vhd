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
use work.Streams.all;
use work.Utils.all;
use work.Arrow.all;
use work.Columns.all;
use work.SimUtils.all;

use work.arrow_regexp_pkg.all;

-- A component performing RegExp matching on an Apache Arrow Column
--
-- This is a single unit doing the regular expression matching.
-- Here you can find the instantiation of the ColumnReader, which generates
-- its internal structure according to a configuration string which can
-- be derived from an Arrow Schema.
entity arrow_regexp_unit is
  generic (
    NUM_REGEX                   : natural := 16;
    BUS_ADDR_WIDTH              : natural;
    BUS_DATA_WIDTH              : natural;
    BUS_LEN_WIDTH               : natural;
    BUS_BURST_STEP_LEN          : natural;
    BUS_BURST_MAX_LEN           : natural;
    REG_WIDTH                   : natural;
    ID                          : natural
  );

  port (
    clk                         : in  std_logic;
    reset_n                     : in  std_logic;

    control_reset               : in  std_logic;
    control_start               : in  std_logic;
    reset_start                 : out std_logic;

    busy                        : out std_logic;
    done                        : out std_logic;

    firstidx                    : in  std_logic_vector(REG_WIDTH-1 downto 0);
    lastidx                     : in  std_logic_vector(REG_WIDTH-1 downto 0);

	off_lo                      : in  std_logic_vector(REG_WIDTH-1 downto 0);
    off_hi                      : in  std_logic_vector(REG_WIDTH-1 downto 0);
    
    utf8_lo                     : in  std_logic_vector(REG_WIDTH-1 downto 0);
    utf8_hi                     : in  std_logic_vector(REG_WIDTH-1 downto 0);

    matches                     : out std_logic_vector(NUM_REGEX*REG_WIDTH-1 downto 0);

    ---------------------------------------------------------------------------
    -- Master bus
    ---------------------------------------------------------------------------
    -- Read request channel
    mst_bus_rreq_addr           : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_bus_rreq_len            : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_bus_rreq_valid          : out std_logic;
    mst_bus_rreq_ready          : in  std_logic;

    -- Read response channel
    mst_bus_rdat_data           : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_bus_rdat_last           : in  std_logic;
    mst_bus_rdat_valid          : in  std_logic;
    mst_bus_rdat_ready          : out std_logic
  );
end entity arrow_regexp_unit;

architecture rtl of arrow_regexp_unit is

  -- Register all ports to ease timing
  signal r_control_reset        : std_logic;
  signal r_control_start        : std_logic;
  signal r_reset_start          : std_logic;
  signal r_busy                 : std_logic;
  signal r_done                 : std_logic;
  signal r_firstidx             : std_logic_vector(REG_WIDTH-1 downto 0);
  signal r_lastidx              : std_logic_vector(REG_WIDTH-1 downto 0);
  signal r_off_hi               : std_logic_vector(REG_WIDTH-1 downto 0);
  signal r_off_lo               : std_logic_vector(REG_WIDTH-1 downto 0);
  signal r_utf8_hi              : std_logic_vector(REG_WIDTH-1 downto 0);
  signal r_utf8_lo              : std_logic_vector(REG_WIDTH-1 downto 0);
  signal r_matches              : std_logic_vector(NUM_REGEX*REG_WIDTH-1 downto 0);

  -----------------------------------------------------------------------------
  -- ColumnReader Interface
  -----------------------------------------------------------------------------
  constant OFFSET_WIDTH         : natural := 32;
  constant VALUE_ELEM_WIDTH     : natural :=  8;
  constant VALUES_PER_CYCLE     : natural :=  4;
  constant NUM_STREAMS          : natural :=  2;
  constant VALUES_WIDTH         : natural := VALUE_ELEM_WIDTH * VALUES_PER_CYCLE;
  constant VALUES_COUNT_WIDTH   : natural := log2ceil(VALUES_PER_CYCLE)+1;
  constant OUT_DATA_WIDTH       : natural := OFFSET_WIDTH + VALUES_WIDTH + VALUES_COUNT_WIDTH;

  signal out_valid              : std_logic_vector(NUM_STREAMS-1 downto 0);
  signal out_ready              : std_logic_vector(NUM_STREAMS-1 downto 0);
  signal out_last               : std_logic_vector(NUM_STREAMS-1 downto 0);
  signal out_dvalid             : std_logic_vector(NUM_STREAMS-1 downto 0);
  signal out_data               : std_logic_vector(OUT_DATA_WIDTH-1 downto 0);

  signal busreq_len             : std_logic_vector(log2ceil(BUS_BURST_MAX_LEN)+1 downto 0);

  -- Command Stream
  type command_t is record
    valid                       : std_logic;
    ready                       : std_logic;
    firstIdx                    : std_logic_vector(OFFSET_WIDTH-1 downto 0);
    lastIdx                     : std_logic_vector(OFFSET_WIDTH-1 downto 0);
    ctrl                        : std_logic_vector(2*BUS_ADDR_WIDTH-1 downto 0);
  end record;

  signal cmd_ready              : std_logic;

  -- Output Streams
  type len_stream_in_t is record
    valid                       : std_logic;
    dvalid                      : std_logic;
    last                        : std_logic;
    data                        : std_logic_vector(OFFSET_WIDTH-1 downto 0);
  end record;

  type utf8_stream_in_t is record
    valid                       : std_logic;
    dvalid                      : std_logic;
    last                        : std_logic;
    count                       : std_logic_vector(VALUES_COUNT_WIDTH-1 downto 0);
    data                        : std_logic_vector(VALUES_WIDTH-1 downto 0);
  end record;

  type str_elem_in_t is record
    len                         : len_stream_in_t;
    utf8                        : utf8_stream_in_t;
  end record;

  procedure conv_streams_in (
    signal valid                : in  std_logic_vector(NUM_STREAMS-1 downto 0);
    signal dvalid               : in  std_logic_vector(NUM_STREAMS-1 downto 0);
    signal last                 : in  std_logic_vector(NUM_STREAMS-1 downto 0);
    signal data                 : in  std_logic_vector(OUT_DATA_WIDTH-1 downto 0);
    signal str_elem_in          : out str_elem_in_t
  ) is
  begin
    str_elem_in.len.data        <= data  (OFFSET_WIDTH-1 downto 0);
    str_elem_in.len.valid       <= valid (0);
    str_elem_in.len.dvalid      <= dvalid(0);
    str_elem_in.len.last        <= last  (0);

    str_elem_in.utf8.count      <= data  (VALUES_COUNT_WIDTH + VALUES_WIDTH + OFFSET_WIDTH - 1 downto VALUES_WIDTH + OFFSET_WIDTH);
    str_elem_in.utf8.data       <= data  (VALUES_WIDTH + OFFSET_WIDTH - 1 downto OFFSET_WIDTH);
    str_elem_in.utf8.valid      <= valid (1);
    str_elem_in.utf8.dvalid     <= dvalid(1);
    str_elem_in.utf8.last       <= last  (1);
  end procedure;

  type len_stream_out_t is record
    ready                       : std_logic;
  end record;

  type utf8_stream_out_t is record
    ready                       : std_logic;
  end record;

  type str_elem_out_t is record
    len                         : len_stream_out_t;
    utf8                        : utf8_stream_out_t;
  end record;

  procedure conv_streams_out (
    signal str_elem_out         : in  str_elem_out_t;
    signal out_ready            : out std_logic_vector(NUM_STREAMS-1 downto 0)
  ) is
  begin
    out_ready(0)                <= str_elem_out.len.ready;
    out_ready(1)                <= str_elem_out.utf8.ready;
  end procedure;

  signal str_elem_in            : str_elem_in_t;
  signal str_elem_out           : str_elem_out_t;

  type regex_in_t is record
    valid                       : std_logic;
    data                        : std_logic_vector(VALUES_WIDTH-1 downto 0);
    mask                        : std_logic_vector(VALUES_PER_CYCLE-1 downto 0);
    last                        : std_logic;
  end record;

  type regex_out_t is record
    valid                       : std_logic_vector(NUM_REGEX-1 downto 0);
    match                       : std_logic_vector(NUM_REGEX-1 downto 0);
    error                       : std_logic_vector(NUM_REGEX-1 downto 0);
  end record;

  type regex_t is record
    input                       : regex_in_t;
    output                      : regex_out_t;
  end record;

  type regex_input_array_t is array(0 to NUM_REGEX-1) of regex_in_t;

  signal regex_input_r          : regex_input_array_t;
  signal regex_output_r         : regex_out_t;
  signal regex_input            : regex_input_array_t;
  signal regex_output           : regex_out_t;

  -----------------------------------------------------------------------------
  -- UserCore
  -----------------------------------------------------------------------------
  type state_t is (STATE_IDLE, STATE_RESET_START, STATE_REQUEST, STATE_BUSY, STATE_DONE);

  -- Control and status bits
  type cs_t is record
    reset_start                 : std_logic;
    done                        : std_logic;
    busy                        : std_logic;
  end record;

  type reg_array is array (0 to NUM_REGEX-1) of unsigned(REG_WIDTH-1 downto 0);

  type reg is record
    state                       : state_t;
    cs                          : cs_t;

    command                     : command_t;

    regex                       : regex_t;

    str_elem_out                : str_elem_out_t;
    str_elem_in                 : str_elem_in_t;

    processed                   : reg_array;
    matches                     : reg_array;

    reset_units                 : std_logic;
  end record;

  signal r                      : reg;
  signal d                      : reg;

  signal s_cmd_tmp              : std_logic_vector(2 * BUS_ADDR_WIDTH + 2 * OFFSET_WIDTH - 1 downto 0);
  signal s_cmd                  : command_t;

begin

  -----------------------------------------------------------------------------
  -- Command Stream Slice
  -----------------------------------------------------------------------------
  slice_inst: StreamSlice
    generic map (
      DATA_WIDTH                => 2 * BUS_ADDR_WIDTH + 2 * OFFSET_WIDTH
    ) port map (
      clk                       => clk,
      reset                     => d.reset_units,
      in_valid                  => d.command.valid,
      in_ready                  => cmd_ready,
      in_data                   => d.command.firstIdx & d.command.lastIdx & d.command.ctrl,
      out_valid                 => s_cmd.valid,
      out_ready                 => s_cmd.ready,
      out_data                  => s_cmd_tmp
    );

  s_cmd.ctrl                    <= s_cmd_tmp(2 * BUS_ADDR_WIDTH-1 downto 0);
  s_cmd.lastIdx                 <= s_cmd_tmp(2 * BUS_ADDR_WIDTH + OFFSET_WIDTH - 1 downto 2 * BUS_ADDR_WIDTH);
  s_cmd.firstIdx                <= s_cmd_tmp(2 * BUS_ADDR_WIDTH + 2 * OFFSET_WIDTH - 1 downto 2 * BUS_ADDR_WIDTH + OFFSET_WIDTH);

  -----------------------------------------------------------------------------
  -- ColumnReader
  -----------------------------------------------------------------------------
  cr: ColumnReader
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      INDEX_WIDTH               => 32,
      CFG                       => "listprim(8;epc=4)",
      CMD_TAG_ENABLE            => false,
      CMD_TAG_WIDTH             => 1
    )
    port map (
      bus_clk                   => clk,
      bus_reset                 => r.reset_units,
      acc_clk                   => clk,
      acc_reset                 => r.reset_units,
      cmd_valid                 => s_cmd.valid,
      cmd_ready                 => s_cmd.ready,
      cmd_firstIdx              => s_cmd.firstIdx,
      cmd_lastIdx               => s_cmd.lastIdx,
      cmd_ctrl                  => s_cmd.ctrl,
      cmd_tag                   => (others => '0'), -- CMD_TAG_ENABLE is false
      unlock_valid              => open,
      unlock_ready              => '1',
      unlock_tag                => open,
      bus_rreq_valid            => mst_bus_rreq_valid,
      bus_rreq_ready            => mst_bus_rreq_ready,
      bus_rreq_addr             => mst_bus_rreq_addr,
      bus_rreq_len              => mst_bus_rreq_len,
      bus_rdat_valid            => mst_bus_rdat_valid,
      bus_rdat_ready            => mst_bus_rdat_ready,
      bus_rdat_data             => mst_bus_rdat_data,
      bus_rdat_last             => mst_bus_rdat_last,
      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_last                  => out_last,
      out_dvalid                => out_dvalid,
      out_data                  => out_data
    );

  -- Output
  str_elem_out <= d.str_elem_out;

  -- Convert the stream inputs and outputs to something readable
  conv_streams_in(out_valid, out_dvalid, out_last, out_data, str_elem_in);
  conv_streams_out(str_elem_out, out_ready);

  -- Control & Status
  r_reset_start                   <= r.cs.reset_start;
  r_done                          <= r.cs.done;
  r_busy                          <= r.cs.busy;

  -----------------------------------------------------------------------------
  -- A UserCore that counts matches to several RegExes
  -----------------------------------------------------------------------------
  sm_seq: process(clk) is
  begin
    if rising_edge(clk) then
      r                         <= d;

      r_control_reset           <= control_reset;
      r_control_start           <= control_start;
      reset_start               <= r_reset_start;

      busy                      <= r_busy;
      done                      <= r_done;

      r_firstidx                <= firstidx;
      r_lastidx                 <= lastidx;

	  r_off_lo                  <= off_lo;
      r_off_hi                  <= off_hi;

      r_utf8_lo                 <= utf8_lo;
      r_utf8_hi                 <= utf8_hi;
      matches                   <= r_matches;

      if control_reset = '1' then
        r.state                 <= STATE_IDLE;
        r.reset_units           <= '1';
      end if;
    end if;
  end process;

  sm_comb: process( r,
                    cmd_ready,
                    str_elem_in,
                    regex_output,
                    r_firstidx,
                    r_lastidx,
                    r_off_hi,
                    r_off_lo,
                    r_utf8_hi,
                    r_utf8_lo,
                    r_control_start,
                    r_control_reset)
  is
    variable v                  : reg;
  begin
    v                           := r;
    -- Inputs:
    v.command.ready             := cmd_ready;
    v.str_elem_in               := str_elem_in;
    v.regex.output              := regex_output;

    -- Default outputs:
    v.command.valid             := '0';

    v.str_elem_out.len.ready    := '0';
    v.str_elem_out.utf8.ready   := '0';

    v.regex.input.valid         := '0';
    v.regex.input.last          := '0';

    case v.state is
      when STATE_IDLE =>
        v.cs.busy               := '0';
        v.cs.done               := '0';
        v.cs.reset_start        := '0';

        v.processed             := (others => (others => '0'));
        v.matches               := (others => (others => '0'));

        v.reset_units           := '1';

        if control_start = '1' then
          v.state               := STATE_RESET_START;
          v.cs.reset_start      := '1';
        end if;

      when STATE_RESET_START =>
        v.cs.busy               := '1';
        v.cs.done               := '0';

        v.reset_units           := '0';

        if control_start = '0' then
          v.state               := STATE_REQUEST;
        end if;

      when STATE_REQUEST =>
        v.cs.done               := '0';
        v.cs.busy               := '1';
        v.cs.reset_start        := '0';
        v.reset_units           := '0';

        -- First four argument registers are buffer addresses
        -- MSBs are index buffer address
        v.command.ctrl(127 downto 96) := r_utf8_hi;
        v.command.ctrl( 95 downto 64) := r_utf8_lo;
        -- LSBs are data buffer address
        v.command.ctrl( 63 downto 32) := r_off_hi;
        v.command.ctrl( 31 downto  0) := r_off_lo;

        -- Next two argument registers are first and last index
        v.command.firstIdx      := r_firstIdx;
        v.command.lastIdx       := r_lastIdx;

        -- Make command valid
        v.command.valid         := '1';

        -- Wait for command accepted
        if v.command.ready = '1' then
          dumpStdOut("RegExp unit " & integer'image(ID) & " requested strings: "
            & integer'image(int(v.command.firstIdx))
            & " ... "
            & integer'image(int(v.command.lastIdx)-1));
          v.state               := STATE_BUSY;
        end if;

      when STATE_BUSY =>
        v.cs.done               := '0';
        v.cs.busy               := '1';
        v.cs.reset_start        := '0';
        v.reset_units           := '0';

        -- Always ready to receive length
        v.str_elem_out.len.ready := '1';

        if v.str_elem_in.len.valid = '1' then
          -- Do something when this is the last string
        end if;
        if (v.str_elem_in.len.last = '1') and
           (v.processed(0) = u(v.command.lastIdx) - u(v.command.firstIdx))
        then
          dumpStdOut("RegEx unit " & integer'image(ID) & " is done.");
          --for P in 0 to NUM_REGEX-1 loop
          --  dumpStdOut("PROCESSED: " & integer'image(P) & " " &
          --    integer'image(int(v.processed(P))));
          --  dumpStdOut("MATCHED: " & integer'image(P) & " " &
          --    integer'image(int(v.matches(P))));
          --end loop;

          v.state               := STATE_DONE;
        end if;

        -- Always ready to receive utf8 char
        v.str_elem_out.utf8.ready := '1';

        if v.str_elem_in.utf8.valid = '1' then
          -- Do something for every utf8 char
          v.regex.input.valid   := '1';
          v.regex.input.data    := v.str_elem_in.utf8.data;

          -- One hot encode mask
          case v.str_elem_in.utf8.count is
            when "001"          => v.regex.input.mask := "0001";
            when "010"          => v.regex.input.mask := "0011";
            when "011"          => v.regex.input.mask := "0111";
            when "100"          => v.regex.input.mask := "1111";
            when others         => v.regex.input.mask := "0000";
            --when "0001"          => v.regex.input.mask := "00000001";
            --when "0010"          => v.regex.input.mask := "00000011";
            --when "0011"          => v.regex.input.mask := "00000111";
            --when "0100"          => v.regex.input.mask := "00001111";
            --when "0101"          => v.regex.input.mask := "00011111";
            --when "0110"          => v.regex.input.mask := "00111111";
            --when "0111"          => v.regex.input.mask := "01111111";
            --when "1000"          => v.regex.input.mask := "11111111";
            --when others          => v.regex.input.mask := "00000000";
          end case;
        end if;

        if v.str_elem_in.utf8.last = '1' then
          -- Do something when this is the last utf8 char
          v.regex.input.last    := '1';
        end if;

        for P in 0 to NUM_REGEX-1 loop
          if v.regex.output.valid(P) = '1' then
            v.processed(P)      := v.processed(P) + 1;
            if v.regex.output.match(P) = '1' then
              v.matches(P)      := v.matches(P) + 1;
            end if;
          end if;
        end loop;

      when STATE_DONE =>
        v.cs.done               := '1';
        v.cs.busy               := '0';
        v.cs.reset_start        := '0';
        v.reset_units           := '0'; -- See issue #4, otherwise this could be '1'

        if r_control_reset = '1' or r_control_start = '1' then
          v.state               := STATE_IDLE;
        end if;
    end case;

    d                           <= v;
  end process;

  -- Connect matches reg to output
  match_connect: for P in 0 to NUM_REGEX-1 generate
    r_matches((P+1)*REG_WIDTH-1 downto P*REG_WIDTH) <= slv(r.matches(P));
  end generate;

  -------------------------------------------------------------------------------
  -- RegEx components generated by vhdre generator
  -------------------------------------------------------------------------------
  regex_inputs_gen : for I in 0 to NUM_REGEX-1 generate
    regex_input_r(I)            <= r.regex.input;
  end generate;

  -- Clock in the regex input and outputs to ease timing. Also see vhdre readme.
  -- Because we don't use any backpressure, we don't need stream slices here
  -- but just normal registers will do
  regex_inputs_reg: process(clk)
  begin
    if rising_edge(clk) then
      regex_input <= regex_input_r;
      regex_output <= regex_output_r;
    end if;
  end process;

  -- May we be forgiven for our sins:
  r00 : bird    generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input( 0).valid,in_mask=>regex_input( 0).mask,in_data=>regex_input( 0).data,in_last=>regex_input( 0).last,out_valid=>regex_output_r.valid( 0),out_match=>regex_output_r.match( 0 downto  0),out_error=>regex_output_r.error( 0));
  r01 : bunny   generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input( 1).valid,in_mask=>regex_input( 1).mask,in_data=>regex_input( 1).data,in_last=>regex_input( 1).last,out_valid=>regex_output_r.valid( 1),out_match=>regex_output_r.match( 1 downto  1),out_error=>regex_output_r.error( 1));
  r02 : cat     generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input( 2).valid,in_mask=>regex_input( 2).mask,in_data=>regex_input( 2).data,in_last=>regex_input( 2).last,out_valid=>regex_output_r.valid( 2),out_match=>regex_output_r.match( 2 downto  2),out_error=>regex_output_r.error( 2));
  r03 : dog     generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input( 3).valid,in_mask=>regex_input( 3).mask,in_data=>regex_input( 3).data,in_last=>regex_input( 3).last,out_valid=>regex_output_r.valid( 3),out_match=>regex_output_r.match( 3 downto  3),out_error=>regex_output_r.error( 3));
  r04 : ferret  generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input( 4).valid,in_mask=>regex_input( 4).mask,in_data=>regex_input( 4).data,in_last=>regex_input( 4).last,out_valid=>regex_output_r.valid( 4),out_match=>regex_output_r.match( 4 downto  4),out_error=>regex_output_r.error( 4));
  r05 : fish    generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input( 5).valid,in_mask=>regex_input( 5).mask,in_data=>regex_input( 5).data,in_last=>regex_input( 5).last,out_valid=>regex_output_r.valid( 5),out_match=>regex_output_r.match( 5 downto  5),out_error=>regex_output_r.error( 5));
  r06 : gerbil  generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input( 6).valid,in_mask=>regex_input( 6).mask,in_data=>regex_input( 6).data,in_last=>regex_input( 6).last,out_valid=>regex_output_r.valid( 6),out_match=>regex_output_r.match( 6 downto  6),out_error=>regex_output_r.error( 6));
  r07 : hamster generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input( 7).valid,in_mask=>regex_input( 7).mask,in_data=>regex_input( 7).data,in_last=>regex_input( 7).last,out_valid=>regex_output_r.valid( 7),out_match=>regex_output_r.match( 7 downto  7),out_error=>regex_output_r.error( 7));
  r08 : horse   generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input( 8).valid,in_mask=>regex_input( 8).mask,in_data=>regex_input( 8).data,in_last=>regex_input( 8).last,out_valid=>regex_output_r.valid( 8),out_match=>regex_output_r.match( 8 downto  8),out_error=>regex_output_r.error( 8));
  r09 : kitten  generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input( 9).valid,in_mask=>regex_input( 9).mask,in_data=>regex_input( 9).data,in_last=>regex_input( 9).last,out_valid=>regex_output_r.valid( 9),out_match=>regex_output_r.match( 9 downto  9),out_error=>regex_output_r.error( 9));
  r10 : lizard  generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input(10).valid,in_mask=>regex_input(10).mask,in_data=>regex_input(10).data,in_last=>regex_input(10).last,out_valid=>regex_output_r.valid(10),out_match=>regex_output_r.match(10 downto 10),out_error=>regex_output_r.error(10));
  r11 : mouse   generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input(11).valid,in_mask=>regex_input(11).mask,in_data=>regex_input(11).data,in_last=>regex_input(11).last,out_valid=>regex_output_r.valid(11),out_match=>regex_output_r.match(11 downto 11),out_error=>regex_output_r.error(11));
  r12 : puppy   generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input(12).valid,in_mask=>regex_input(12).mask,in_data=>regex_input(12).data,in_last=>regex_input(12).last,out_valid=>regex_output_r.valid(12),out_match=>regex_output_r.match(12 downto 12),out_error=>regex_output_r.error(12));
  r13 : rabbit  generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input(13).valid,in_mask=>regex_input(13).mask,in_data=>regex_input(13).data,in_last=>regex_input(13).last,out_valid=>regex_output_r.valid(13),out_match=>regex_output_r.match(13 downto 13),out_error=>regex_output_r.error(13));
  r14 : rat     generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input(14).valid,in_mask=>regex_input(14).mask,in_data=>regex_input(14).data,in_last=>regex_input(14).last,out_valid=>regex_output_r.valid(14),out_match=>regex_output_r.match(14 downto 14),out_error=>regex_output_r.error(14));
  r15 : turtle  generic map (BPC=>VALUES_PER_CYCLE) port map (clk=>clk,reset=>r.reset_units,in_valid=>regex_input(15).valid,in_mask=>regex_input(15).mask,in_data=>regex_input(15).data,in_last=>regex_input(15).last,out_valid=>regex_output_r.valid(15),out_match=>regex_output_r.match(15 downto 15),out_error=>regex_output_r.error(15));

end architecture;
