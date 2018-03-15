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

-- This unit prevents blocking the bus while waiting for input on the write
-- data stream. It buffers until whatever burst length has been requested
-- in a FIFO and only requests the write burst once the FIFO holds enough
-- words, such that the whole burst may be unloaded onto the bus at once.
entity BusWriteBuffer is
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
    RAM_CONFIG                  : string  := ""
  );
  port (

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    -- Master port.
    mst_req_valid               : out std_logic;
    mst_req_ready               : in  std_logic;
    mst_req_addr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    mst_req_len                 : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    mst_wrd_valid               : out std_logic;
    mst_wrd_ready               : in  std_logic;
    mst_wrd_data                : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    mst_wrd_strobe              : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);

    -- Slave port.
    slv_req_valid               : in  std_logic;
    slv_req_ready               : out std_logic;
    slv_req_addr                : in  std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    slv_req_len                 : in  std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    slv_wrd_valid               : in  std_logic;
    slv_wrd_ready               : out std_logic;
    slv_wrd_data                : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    slv_wrd_strobe              : in  std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0)
    
  );
end BusWriteBuffer;

architecture Behavioral of BusWriteBuffer is

  -- Log2 of the FIFO depth.
  constant DEPTH_LOG2           : natural := log2ceil(FIFO_DEPTH);

  signal fifo_in_valid          : std_logic;
  signal fifo_in_ready          : std_logic;
  signal fifo_in_data           : std_logic_vector(BUS_DATA_WIDTH + BUS_DATA_WIDTH/8-1 downto 0);
  
  signal fifo_out_valid         : std_logic;
  signal fifo_out_ready         : std_logic;
  signal fifo_out_data          : std_logic_vector(BUS_DATA_WIDTH + BUS_DATA_WIDTH/8-1 downto 0);

  type fifo_record is record
    count                       : unsigned(DEPTH_LOG2 downto 0);
    full                        : std_logic;
    empty                       : std_logic;
  end record;

  signal fifo : fifo_record;
  signal fifo_d : fifo_record;
    
  type output_record is record
    slv_req_ready               : std_logic;
    mst_req_valid               : std_logic;
  end record;

begin

  -- Connect FIFO inputs
  fifo_in_valid                 <= slv_wrd_valid;
  slv_wrd_ready                 <= fifo_in_ready;
  fifo_in_data                  <= slv_wrd_data & slv_wrd_strobe;
  
  reg_proc: process(clk)
  begin
    if rising_edge(clk) then
      -- Register
      fifo <= fifo_d;
      
      -- Reset
      if reset = '1' then
        fifo.count <= (others => '0');
      end if;
    end if;
  end process;
  
  comb_proc: process(
    fifo,
    slv_req_len, slv_req_addr, slv_req_valid,
    mst_req_ready
  )
    variable vr : fifo_record;
    variable vo : output_record;
  begin
    if fifo_in_valid = '1' and fifo_in_ready = '1' then
      vr.count := vr.count + 1;
    end if;
    
    if fifo_out_valid = '1' and fifo_out_ready = '1' then
      vr.count := vr.count - 1;
    end if;
    
    -- Ready whenever the master port is ready
    vo.slv_req_ready            := mst_req_ready;
    
    -- Valid whenever the slave port is valid
    vo.mst_req_valid            := slv_req_valid;
    
    -- Back-pressure the bus write request when the FIFO doesn't hold enough
    -- words
    
    if vr.count < u(slv_req_len) then
      vo.slv_req_ready          := '0';
      vo.mst_req_valid          := '0';
    end if;
    
    -- TODO: is all of this actually necessary? Bus requests won't be 
    --       generated until enough data was passed into the FIFO...
    
    mst_req_valid               <= vo.mst_req_valid;
    slv_req_ready               <= vo.slv_req_ready;
  end process;
  
  mst_req_addr <= slv_req_addr;
  mst_req_len <= slv_req_len;
  
  slv_write_buffer: StreamBuffer
    generic map (
      MIN_DEPTH                         => 2**DEPTH_LOG2,
      DATA_WIDTH                        => BUS_DATA_WIDTH + BUS_DATA_WIDTH/8
    )
    port map (
      clk                               => clk,
      reset                             => reset,

      in_valid                          => fifo_in_valid,
      in_ready                          => fifo_in_ready,
      in_data                           => fifo_in_data,

      out_valid                         => fifo_out_valid,
      out_ready                         => fifo_out_ready,
      out_data                          => fifo_out_data
    );

  mst_wrd_data                  <= fifo_out_data(BUS_DATA_WIDTH + BUS_DATA_WIDTH/8 -1 downto BUS_DATA_WIDTH/8);
  mst_wrd_strobe                <= fifo_out_data(BUS_DATA_WIDTH/8 -1 downto 0);
  mst_wrd_valid                 <= fifo_out_valid;
  fifo_out_ready                <= mst_wrd_ready;

end Behavioral;

