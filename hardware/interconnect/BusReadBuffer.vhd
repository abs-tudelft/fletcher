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
use work.Interconnect_pkg.all;
use work.UtilInt_pkg.all;
use work.UtilStr_pkg.all;
use work.UtilMisc_pkg.all;

-- This unit prevents backpressure on the response stream from propagating to
-- the slave, by blocking requests until there is enough room in a response
-- FIFO. This should be placed between a master device and an arbiter to
-- prevent backpressure from blocking the entire bus. Note that this means that
-- the FIFO must be at least large enough to contain the maximum burst size of
-- the master, or all requests will be blocked.

entity BusReadBuffer is
  generic (

    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Minimum number of burst beats that can be stored in the FIFO. Rounded up
    -- to a power of two. This is also the maximum burst length supported.
    FIFO_DEPTH                  : natural := 16;

    -- RAM configuration string for the response FIFO.
    RAM_CONFIG                  : string  := "";

    -- Whether a register slice should be inserted into the slave port request
    SLV_REQ_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the master port request
    MST_REQ_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the master port data
    MST_DAT_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the slave port data
    SLV_DAT_SLICE               : boolean := true

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Slave port.
    slv_rreq_valid              : in  std_logic;
    slv_rreq_ready              : out std_logic;
    slv_rreq_addr               : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    slv_rreq_len                : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    slv_rdat_valid              : out std_logic;
    slv_rdat_ready              : in  std_logic;
    slv_rdat_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    slv_rdat_last               : out std_logic;

    -- Master port.
    mst_rreq_valid              : out std_logic;
    mst_rreq_ready              : in  std_logic;
    mst_rreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_rreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_rdat_valid              : in  std_logic;
    mst_rdat_ready              : out std_logic;
    mst_rdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_rdat_last               : in  std_logic

  );
end BusReadBuffer;

architecture Behavioral of BusReadBuffer is

  -- Log2 of the FIFO depth.
  constant DEPTH_LOG2           : natural := log2ceil(FIFO_DEPTH);

  -- Bus request serialization indices.
  constant BQI : nat_array := cumulative((
    1 => BUS_ADDR_WIDTH,
    0 => BUS_LEN_WIDTH
  ));

  signal slvreqi_sData          : std_logic_vector(BQI(BQI'high)-1 downto 0);
  signal slvreqo_sData          : std_logic_vector(BQI(BQI'high)-1 downto 0);

  signal mreqi_sData            : std_logic_vector(BQI(BQI'high)-1 downto 0);
  signal mreqo_sData            : std_logic_vector(BQI(BQI'high)-1 downto 0);

  -- Bus response serialization indices.
  constant BPI : nat_array := cumulative((
    1 => BUS_DATA_WIDTH,
    0 => 1
  ));

  signal mstrespi_sData         : std_logic_vector(BPI(BPI'high)-1 downto 0);
  signal mstrespo_sData         : std_logic_vector(BPI(BPI'high)-1 downto 0);

  signal slvrespi_sData         : std_logic_vector(BPI(BPI'high)-1 downto 0);
  signal slvrespo_sData         : std_logic_vector(BPI(BPI'high)-1 downto 0);

  -- Internal register-sliced slave port request.
  signal ss_req_valid           : std_logic;
  signal ss_req_ready           : std_logic;
  signal ss_req_addr            : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal ss_req_len             : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

  -- Internal register-sliced master port request.
  signal ms_req_valid           : std_logic;
  signal ms_req_ready           : std_logic;
  signal ms_req_addr            : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal ms_req_len             : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

  -- Internal FIFO'd/register-sliced response.
  signal resp_valid             : std_logic;
  signal resp_ready             : std_logic;
  signal resp_data              : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal resp_last              : std_logic;

  -- Counters storing how much space we currently have reserved in the FIFO.
  signal reserved               : signed(DEPTH_LOG2+1 downto 0);
  signal reserved_if_accepted   : signed(DEPTH_LOG2+1 downto 0);
  signal fifo_ready             : std_logic;

begin

  -- Instantiate slave port request register slice.
  slv_rreq_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(SLV_REQ_SLICE, 2, 0),
      DATA_WIDTH                        => BQI(BQI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => slv_rreq_valid,
      in_ready                          => slv_rreq_ready,
      in_data                           => mreqi_sData,

      out_valid                         => ss_req_valid,
      out_ready                         => ss_req_ready,
      out_data                          => mreqo_sData
    );

  mreqi_sData(BQI(2)-1 downto BQI(1))   <= slv_rreq_addr;
  mreqi_sData(BQI(1)-1 downto BQI(0))   <= slv_rreq_len;

  ss_req_addr                           <= mreqo_sData(BQI(2)-1 downto BQI(1));
  ss_req_len                            <= mreqo_sData(BQI(1)-1 downto BQI(0));

  -- Block the request when FIFO ready is not asserted.
  ms_req_valid <= ss_req_valid and fifo_ready;
  ss_req_ready <= ms_req_ready and fifo_ready;
  ms_req_addr  <= ss_req_addr;
  ms_req_len   <= ss_req_len;

  -- Determine how many words will be reserved in the FIFO if we accept the currently incoming length.
  reserved_if_accepted <= reserved + resize(signed("0" & ms_req_len), DEPTH_LOG2+2);

  -- If reserved_if_accepted is greater than the FIFO depth (or equal, for efficiency), do not accept the transfer.
  fifo_ready <= '0' when reserved_if_accepted >= 2**DEPTH_LOG2 else '1';

  -- Maintain the FIFO reserved counter.
  reserved_ptr_proc: process (clk) is
    variable reserved_v : signed(DEPTH_LOG2+1 downto 0);
  begin
    if rising_edge(clk) then
      -- Reset
      if reset = '1' then
        reserved_v := (others => '0');
      else
        reserved_v := reserved;

        -- A request is made and accepted
        if ms_req_valid = '1' and ms_req_ready = '1' then

          -- Increase amount of space reserved in the FIFO
          reserved_v := reserved_if_accepted;

          -- pragma translate_off

          -- Check if the request burst length is not larger than the FIFO depth
          assert unsigned(ms_req_len) < 2**DEPTH_LOG2
            report "Violated burst length requirement. ms_req_len(=" & slvToUDec(ms_req_len) & ") < 2**DEPTH_LOG2(=" & integer'image(2**DEPTH_LOG2) & ") not met, deadlock!"
            severity FAILURE;

          -- Check if either the amount of space reserved is larger than 0 or the fifo is ready
          assert reserved_v > 0 or fifo_ready = '1'
            report "Bus buffer deadlock!"
            severity FAILURE;

          -- Check if the amount of space reserved is equal or larger than 0 after the reservation
          assert reserved_v >= 0
            report "This should never happen... " &
                   "Check if BUS_LEN_WIDTH is wide enough to contain log2(slv_rreq_len)+2 bits. " &
                   "reserved_v=" & sgnToDec(reserved_v) & ">= 0. " &
                   "Reserved (if accepted):" & sgnToDec(reserved_if_accepted)
            severity FAILURE;

          -- pragma translate_on

        end if;

        -- Decrease counter if response channel transfer takes place
        if resp_valid = '1' and resp_ready = '1' then
          reserved_v := reserved_v - 1;
        end if;
      end if;
      reserved <= reserved_v;
    end if;
  end process;

  -- Instantiate master port request register slice.
  mst_rreq_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(MST_REQ_SLICE, 2, 0),
      DATA_WIDTH                        => BQI(BQI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => ms_req_valid,
      in_ready                          => ms_req_ready,
      in_data                           => slvreqi_sData,

      out_valid                         => mst_rreq_valid,
      out_ready                         => mst_rreq_ready,
      out_data                          => slvreqo_sData
    );

  slvreqi_sData(BQI(2)-1 downto BQI(1)) <= ms_req_addr;
  slvreqi_sData(BQI(1)-1 downto BQI(0)) <= ms_req_len;

  mst_rreq_addr                         <= slvreqo_sData(BQI(2)-1 downto BQI(1));
  mst_rreq_len                          <= slvreqo_sData(BQI(1)-1 downto BQI(0));

  -- Instantiate master port response register slice and FIFO.
  mst_rdat_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(MST_DAT_SLICE, 2, 0) + 2**DEPTH_LOG2,
      DATA_WIDTH                        => BPI(BPI'high),
      RAM_CONFIG                        => RAM_CONFIG
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => mst_rdat_valid,
      in_ready                          => mst_rdat_ready,
      in_data                           => mstrespi_sData,

      out_valid                         => resp_valid,
      out_ready                         => resp_ready,
      out_data                          => mstrespo_sData
    );

  mstrespi_sData(BPI(2)-1 downto BPI(1))<= mst_rdat_data;
  mstrespi_sData(BPI(0))                <= mst_rdat_last;

  resp_data                             <= mstrespo_sData(BPI(2)-1 downto BPI(1));
  resp_last                             <= mstrespo_sData(BPI(0));

  -- Instantiate slave port response register slice.
  slv_rdat_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(SLV_DAT_SLICE, 2, 0),
      DATA_WIDTH                        => BPI(BPI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => resp_valid,
      in_ready                          => resp_ready,
      in_data                           => slvrespi_sData,

      out_valid                         => slv_rdat_valid,
      out_ready                         => slv_rdat_ready,
      out_data                          => slvrespo_sData
    );

  slvrespi_sData(BPI(2)-1 downto BPI(1))<= resp_data;
  slvrespi_sData(BPI(0))                <= resp_last;

  slv_rdat_data                         <= slvrespo_sData(BPI(2)-1 downto BPI(1));
  slv_rdat_last                         <= slvrespo_sData(BPI(0));

end Behavioral;
