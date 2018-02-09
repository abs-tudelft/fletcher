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

-- This unit prevents backpressure on the response stream from propagating to
-- the slave, by blocking requests until there is enough room in a response
-- FIFO. This should be placed between a master device and an arbiter to
-- prevent backpressure from blocking the entire bus. Note that this means that
-- the FIFO must be at least large enough to contain the maximum burst size of
-- the master, or all requests will be blocked.

entity BusBuffer is
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
    RAM_CONFIG                  : string := "";

    -- Whether a register slice should be inserted into the bus request input
    -- stream.
    REQ_IN_SLICE                : boolean := false;

    -- Whether a register slice should be inserted into the bus request output
    -- stream.
    REQ_OUT_SLICE               : boolean := true;

    -- Whether a register slice should be inserted into the bus response input
    -- stream.
    RESP_IN_SLICE               : boolean := false;

    -- Whether a register slice should be inserted into the bus response output
    -- stream.
    RESP_OUT_SLICE              : boolean := true

  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Master port.
    mst_req_valid               : in  std_logic;
    mst_req_ready               : out std_logic;
    mst_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_resp_valid              : out std_logic;
    mst_resp_ready              : in  std_logic;
    mst_resp_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_resp_last               : out std_logic;

    -- Slave port.
    slv_req_valid               : out std_logic;
    slv_req_ready               : in  std_logic;
    slv_req_addr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    slv_req_len                 : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    slv_resp_valid              : in  std_logic;
    slv_resp_ready              : out std_logic;
    slv_resp_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    slv_resp_last               : in  std_logic

  );
end BusBuffer;

architecture Behavioral of BusBuffer is

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

  signal slvrespi_sData         : std_logic_vector(BPI(BPI'high)-1 downto 0);
  signal slvrespo_sData         : std_logic_vector(BPI(BPI'high)-1 downto 0);

  signal mrespi_sData           : std_logic_vector(BPI(BPI'high)-1 downto 0);
  signal mrespo_sData           : std_logic_vector(BPI(BPI'high)-1 downto 0);

  -- Internal register-sliced master request.
  signal ms_req_valid           : std_logic;
  signal ms_req_ready           : std_logic;
  signal ms_req_addr            : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal ms_req_len             : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

  -- Internal register-sliced slave request.
  signal ss_req_valid           : std_logic;
  signal ss_req_ready           : std_logic;
  signal ss_req_addr            : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal ss_req_len             : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);

  -- Internal FIFO'd/register-sliced response.
  signal resp_valid             : std_logic;
  signal resp_ready             : std_logic;
  signal resp_data              : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal resp_last              : std_logic;

  -- Counters storing how much space we currently have reserved in the FIFO.
  signal reserved               : std_logic_vector(DEPTH_LOG2 downto 0);
  signal reserved_if_accepted   : std_logic_vector(DEPTH_LOG2+1 downto 0);
  signal fifo_ready             : std_logic;

begin

  -- Instantiate master request register slice.
  mst_req_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(REQ_IN_SLICE, 2, 0),
      DATA_WIDTH                        => BQI(BQI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => mst_req_valid,
      in_ready                          => mst_req_ready,
      in_data                           => mreqi_sData,

      out_valid                         => ms_req_valid,
      out_ready                         => ms_req_ready,
      out_data                          => mreqo_sData
    );

  mreqi_sData(BQI(2)-1 downto BQI(1))   <= mst_req_addr;
  mreqi_sData(BQI(1)-1 downto BQI(0))   <= mst_req_len;

  ms_req_addr                           <= mreqo_sData(BQI(2)-1 downto BQI(1));
  ms_req_len                            <= mreqo_sData(BQI(1)-1 downto BQI(0));

  -- Block the request when FIFO ready is not asserted.
  ss_req_valid <= ms_req_valid and fifo_ready;
  ms_req_ready <= ss_req_ready and fifo_ready;
  ss_req_addr  <= ms_req_addr;
  ss_req_len   <= ms_req_len;

  -- Determine how many words will be reserved in the FIFO if we accept the
  -- currently incoming length.
  reserved_if_accepted <= std_logic_vector(
                            resize(signed(reserved),   DEPTH_LOG2+2)
                          + resize(signed(ss_req_len), DEPTH_LOG2+2)
                          );

  -- If reserved_if_accepted is greater than the FIFO depth (or equal, for
  -- efficiency), do not accept the transfer.
  fifo_ready <= '0' when signed(reserved_if_accepted) >= 2**DEPTH_LOG2 else '1';

  -- Maintain the FIFO reserved counter.
  reserved_ptr_proc: process (clk) is
    variable reserved_v : signed(DEPTH_LOG2 downto 0);
  begin
    if rising_edge(clk) then
      reserved_v := signed(reserved);

      if ss_req_valid = '1' and ss_req_ready = '1' then
        assert unsigned(ss_req_len) < 2**DEPTH_LOG2 report "Request burst length too long, deadlock!" severity FAILURE;
        reserved_v := resize(signed(reserved_if_accepted), DEPTH_LOG2+1);
        assert reserved_v > 0 or fifo_ready = '1' report "Bus buffer deadlock!" severity FAILURE;
        assert reserved_v >= 0 report "This should never happen... Check if BUS_DATA_WIDTH is wide enough to contain log2(mst_req_len)+2 bits." severity FAILURE;
      end if;

      if resp_valid = '1' and resp_ready = '1' then
        reserved_v := reserved_v - 1;
      end if;

      if reset = '1' then
        reserved_v := (others => '0');
      end if;

      reserved <= std_logic_vector(reserved_v);
    end if;
  end process;

  -- Instantiate slave request register slice.
  slv_req_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(REQ_OUT_SLICE, 2, 0),
      DATA_WIDTH                        => BQI(BQI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => ss_req_valid,
      in_ready                          => ss_req_ready,
      in_data                           => slvreqi_sData,

      out_valid                         => slv_req_valid,
      out_ready                         => slv_req_ready,
      out_data                          => slvreqo_sData
    );

  slvreqi_sData(BQI(2)-1 downto BQI(1)) <= ss_req_addr;
  slvreqi_sData(BQI(1)-1 downto BQI(0)) <= ss_req_len;

  slv_req_addr                          <= slvreqo_sData(BQI(2)-1 downto BQI(1));
  slv_req_len                           <= slvreqo_sData(BQI(1)-1 downto BQI(0));

  -- Instantiate slave response register slice and FIFO.
  slv_resp_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(RESP_IN_SLICE, 2, 0) + 2**DEPTH_LOG2,
      DATA_WIDTH                        => BPI(BPI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => slv_resp_valid,
      in_ready                          => slv_resp_ready,
      in_data                           => slvrespi_sData,

      out_valid                         => resp_valid,
      out_ready                         => resp_ready,
      out_data                          => slvrespo_sData
    );

  slvrespi_sData(BPI(2)-1 downto BPI(1))<= slv_resp_data;
  slvrespi_sData(BPI(0))                <= slv_resp_last;

  resp_data                             <= slvrespo_sData(BPI(2)-1 downto BPI(1));
  resp_last                             <= slvrespo_sData(BPI(0));

  -- Instantiate master response register slice.
  mst_resp_buffer_inst: StreamBuffer
    generic map (
      MIN_DEPTH                         => sel(RESP_OUT_SLICE, 2, 0),
      DATA_WIDTH                        => BPI(BPI'high)
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => resp_valid,
      in_ready                          => resp_ready,
      in_data                           => mrespi_sData,

      out_valid                         => mst_resp_valid,
      out_ready                         => mst_resp_ready,
      out_data                          => mrespo_sData
    );

  mrespi_sData(BPI(2)-1 downto BPI(1))  <= resp_data;
  mrespi_sData(BPI(0))                  <= resp_last;

  mst_resp_data                         <= mrespo_sData(BPI(2)-1 downto BPI(1));
  mst_resp_last                         <= mrespo_sData(BPI(0));

end Behavioral;

