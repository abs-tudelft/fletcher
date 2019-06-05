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
use work.Stream_pkg.all;
use work.Buffer_pkg.all;
use work.Interconnect_pkg.all;
use work.Wrapper_pkg.all;
use work.UtilInt_pkg.all;
use work.UtilConv_pkg.all;

--pragma simulation timeout 1 ms

-- This testbench is used to check the functionality of the BufferReader.
-- TODO: it does not always return TEST_SUCCESSFUL even though it may be 
-- successful. But currently, it's used to generally mess around with
-- internal command stream and the bus request generator
-- So normally if it ends, it should be somewhat okay in terms of how many
-- elements it returns. Whether they are the right elements can be tested using
-- the ArrayReader test bench, or by setting the element size equal to the 
-- word size, but that is not a guarantee of proper functioning.
entity BufferReader_tc is
  generic (
    ---------------------------------------------------------------------------
    -- TEST BENCH
    ---------------------------------------------------------------------------
    TbPeriod                    : time    := 4 ns;

    ---------------------------------------------------------------------------
    -- USER CORE
    ---------------------------------------------------------------------------
    NUM_REQUESTS                : natural := 128;
    NUM_ELEMENTS                : natural := 256;

    RANDOMIZE_OFFSET            : boolean := false;
    RANDOMIZE_NUM_ELEMENTS	    : boolean := false;
    RANDOMIZE_RESP_LATENCY      : boolean := true;
    MAX_LATENCY                 : natural := 8;
    DEFAULT_LATENCY             : natural := 4;
    RESP_TIMEOUT                : natural := 1024;
    WAIT_FOR_PREV_LAST          : boolean := true;

    ---------------------------------------------------------------------------
    -- BUS SLAVE MOCK
    ---------------------------------------------------------------------------
    BUS_ADDR_WIDTH              : natural := 32;
    BUS_DATA_WIDTH              : natural := 32;
    BUS_LEN_WIDTH               : natural := 9;
    BUS_BURST_STEP_LEN          : natural := 16;
    BUS_BURST_MAX_LEN           : natural := 128;

    -- Random timing for bus slave mock
    BUS_SLAVE_RND_REQ           : boolean := true;
    BUS_SLAVE_RND_RESP          : boolean := true;
    ---------------------------------------------------------------------------
    -- ARROW
    ---------------------------------------------------------------------------
    INDEX_WIDTH                 : natural := 32;

    ROWS                        : natural := 1024;
    ELEMENT_WIDTH               : natural := 32;

    ELEMENT_COUNT_MAX           : natural := 1; --BUS_DATA_WIDTH / ELEMENT_WIDTH;
    ELEMENT_COUNT_WIDTH         : natural := imax(1,log2ceil(ELEMENT_COUNT_MAX+1));

    ---------------------------------------------------------------------------
    -- MISC
    ---------------------------------------------------------------------------
    IS_OFFSETS_BUFFER           : boolean := false;

    CMD_IN_SLICE                : boolean := false;
    BUS_REQ_SLICE               : boolean := false;
    BUS_FIFO_DEPTH              : natural := 2*BUS_BURST_MAX_LEN;
    BUS_FIFO_RAM_CONFIG         : string  := "";
    CMD_OUT_SLICE               : boolean := false;
    SHR2GB_SLICE                : boolean := true;
    GB2FIFO_SLICE               : boolean := true;
    ELEMENT_FIFO_SIZE           : natural := 2*BUS_BURST_MAX_LEN*ELEMENT_COUNT_MAX;
    ELEMENT_FIFO_RAM_CONFIG     : string  := "";
    ELEMENT_FIFO_XCLK_STAGES    : natural := 0;
    FIFO2POST_SLICE             : boolean := false;
    OUT_SLICE                   : boolean := false
  );
end BufferReader_tc;

architecture tb of BufferReader_tc is
  signal bcd_clk                : std_logic                                               := '0';
  signal bcd_reset              : std_logic                                               := '0';
  signal kcd_clk                : std_logic                                               := '0';
  signal kcd_reset              : std_logic                                               := '0';
  signal cmdIn_valid            : std_logic                                               := '0';
  signal cmdIn_ready            : std_logic                                               := '0';
  signal cmdIn_firstIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0)                := (others => '0');
  signal cmdIn_lastIdx          : std_logic_vector(INDEX_WIDTH-1 downto 0)                := (others => '0');
  signal cmdIn_baseAddr         : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)             := (others => '0');
  signal cmdOut_valid           : std_logic                                               := '0';
  signal cmdOut_ready           : std_logic                                               := '1';
  signal cmdOut_firstIdx        : std_logic_vector(INDEX_WIDTH-1 downto 0)                := (others => '0');
  signal cmdOut_lastIdx         : std_logic_vector(INDEX_WIDTH-1 downto 0)                := (others => '0');
  signal bus_rreq_valid         : std_logic                                               := '0';
  signal bus_rreq_ready         : std_logic                                               := '0';
  signal bus_rreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0)             := (others => '0');
  signal bus_rreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0)              := (others => '0');
  signal bus_rdat_valid         : std_logic                                               := '0';
  signal bus_rdat_ready         : std_logic                                               := '0';
  signal bus_rdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0)             := (others => '0');
  signal bus_rdat_last          : std_logic                                               := '0';
  signal out_valid              : std_logic                                               := '0';
  signal out_ready              : std_logic                                               := '0';
  signal out_data               : std_logic_vector(ELEMENT_COUNT_MAX*ELEMENT_WIDTH-1 downto 0)  := (others => '0');
  signal out_count              : std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0)           := (others => '0');
  signal out_last               : std_logic                                               := '0';

  signal user_start             : std_logic                                               := '0';
  signal user_done              : std_logic                                               := '0';
  signal user_req_resp_error    : std_logic                                               := '0';
  signal user_incorrect         : std_logic                                               := '0';
  signal user_timeout           : std_logic                                               := '0';
  signal user_rows              : std_logic_vector(INDEX_WIDTH-1 downto 0)                := (others => '0');

  signal TbClock                : std_logic                                               := '0';
  signal TbReset                : std_logic                                               := '0';
  signal TbSimEnded             : std_logic                                               := '0';

  signal end_condition          : std_logic;

  procedure handshake (signal clk : in std_logic; signal rdy : in std_logic) is
  begin
    if rdy /= '1' then
      wait until rdy = '1';
    end if;
    wait until rising_edge(clk);
  end handshake;

  function idx(a : in natural) return std_logic_vector is
  begin
    return slv(u(a,INDEX_WIDTH));
  end function;

begin

  dut : BufferReader
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      IS_OFFSETS_BUFFER         => IS_OFFSETS_BUFFER,
      ELEMENT_COUNT_MAX         => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => ELEMENT_COUNT_WIDTH,
      CMD_IN_SLICE              => CMD_IN_SLICE,
      BUS_REQ_SLICE             => BUS_REQ_SLICE,
      BUS_FIFO_DEPTH            => BUS_FIFO_DEPTH,
      BUS_FIFO_RAM_CONFIG       => BUS_FIFO_RAM_CONFIG,
      CMD_OUT_SLICE             => CMD_OUT_SLICE,
      SHR2GB_SLICE              => SHR2GB_SLICE,
      GB2FIFO_SLICE             => GB2FIFO_SLICE,
      ELEMENT_FIFO_SIZE         => ELEMENT_FIFO_SIZE,
      ELEMENT_FIFO_RAM_CONFIG   => ELEMENT_FIFO_RAM_CONFIG,
      ELEMENT_FIFO_XCLK_STAGES  => ELEMENT_FIFO_XCLK_STAGES,
      FIFO2POST_SLICE           => FIFO2POST_SLICE,
      OUT_SLICE                 => OUT_SLICE
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
      cmdOut_valid              => cmdOut_valid,
      cmdOut_ready              => cmdOut_ready,
      cmdOut_firstIdx           => cmdOut_firstIdx,
      cmdOut_lastIdx            => cmdOut_lastIdx,
      bus_rreq_valid            => bus_rreq_valid,
      bus_rreq_ready            => bus_rreq_ready,
      bus_rreq_addr             => bus_rreq_addr,
      bus_rreq_len              => bus_rreq_len,
      bus_rdat_valid            => bus_rdat_valid,
      bus_rdat_ready            => bus_rdat_ready,
      bus_rdat_data             => bus_rdat_data,
      bus_rdat_last             => bus_rdat_last,
      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_data                  => out_data,
      out_count                 => out_count,
      out_last                  => out_last
    );

  host_mem : BusReadSlaveMock
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      SEED                      => 1337,
      RANDOM_REQUEST_TIMING     => BUS_SLAVE_RND_REQ,
      RANDOM_RESPONSE_TIMING    => BUS_SLAVE_RND_RESP,
      SREC_FILE                 => ""
    )
    port map (
      clk                       => bcd_clk,
      reset                     => bcd_reset,
      rreq_valid                => bus_rreq_valid,
      rreq_ready                => bus_rreq_ready,
      rreq_addr                 => bus_rreq_addr,
      rreq_len                  => bus_rreq_len,
      rdat_valid                => bus_rdat_valid,
      rdat_ready                => bus_rdat_ready,
      rdat_data                 => bus_rdat_data,
      rdat_last                 => bus_rdat_last
    );

  user_core : UserCoreMock
    generic map (
      NUM_REQUESTS              => NUM_REQUESTS,
      NUM_ELEMENTS              => NUM_ELEMENTS,
      RANDOMIZE_OFFSET          => RANDOMIZE_OFFSET,
      RANDOMIZE_NUM_ELEMENTS	  => RANDOMIZE_NUM_ELEMENTS,
      RANDOMIZE_RESP_LATENCY    => RANDOMIZE_RESP_LATENCY,
      MAX_LATENCY               => MAX_LATENCY,
      DEFAULT_LATENCY           => DEFAULT_LATENCY,
      RESP_TIMEOUT              => RESP_TIMEOUT,
      IS_OFFSETS_BUFFER         => IS_OFFSETS_BUFFER,
      SEED                      => 1337,
      RESULT_LSHIFT             => 2,
      WAIT_FOR_PREV_LAST        => WAIT_FOR_PREV_LAST,
      DATA_WIDTH                => ELEMENT_COUNT_MAX * ELEMENT_WIDTH,
      INDEX_WIDTH               => INDEX_WIDTH,
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      ELEMENT_COUNT_MAX         => ELEMENT_COUNT_MAX,
      ELEMENT_COUNT_WIDTH       => ELEMENT_COUNT_WIDTH
    )
    port map (
      clk                       => kcd_clk,
      reset                     => kcd_reset,
      start                     => user_start,
      done                      => user_done,
      incorrect                 => user_incorrect,
      timeout                   => user_timeout,
      rows                      => user_rows,
      cmd_valid                 => cmdIn_valid,
      cmd_ready                 => cmdIn_ready,
      cmd_firstIdx              => cmdIn_firstIdx,
      cmd_lastIdx               => cmdIn_lastIdx,
      in_valid                  => out_valid,
      in_ready                  => out_ready,
      in_data                   => out_data,
      in_count                  => out_count,
      in_last                   => out_last
    );

  -- Clock generation
  TbClock <= not TbClock after TbPeriod/2 when TbSimEnded /= '1' else '0';

  bcd_clk <= TbClock;
  kcd_clk <= TbClock;

  bcd_reset <= TbReset;
  kcd_reset <= TbReset;

  end_condition <= user_done or user_timeout;

  stimuli : process
  begin
    ---------------------------------------------------------------------------
    wait until rising_edge(TbClock);
    TbReset                     <= '1';
    wait until rising_edge(TbClock);
    TbReset                     <= '0';

    cmdIn_baseAddr              <= (others => '0');
    user_rows                   <= idx(ROWS);
    user_start                  <= '1';

    handshake(TbClock, end_condition);

    TbSimEnded                  <= '1';

    if user_timeout = '1' then
      report "USER CORE TIMEOUT" severity failure;
    end if;

    if user_req_resp_error = '1' then
      report "NO. REQUESTS AND RESPONSES NOT EQUAL" severity failure;
    end if;

    if user_incorrect = '1' then
      report "RESULT INCORRECT" severity failure;
    end if;

    report "END OF TEST"  severity note;

    wait;

  end process;

end architecture;
