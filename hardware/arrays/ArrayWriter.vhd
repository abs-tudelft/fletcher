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
use work.ArrayConfig_pkg.all;
use work.ArrayConfigParse_pkg.all;
use work.Array_pkg.all;
use work.UtilStr_pkg.all;

entity ArrayWriter is
  generic (

    ---------------------------------------------------------------------------
    -- Bus metrics and configuration
    ---------------------------------------------------------------------------
    -- Configures interface for host memory bus.
    -- This implementation requires BUS_DATA_WIDTH * BUS_BURST_STEP_LEN to be
    -- equal to or smaller than the alignment of the buffers in memory. For
    -- example, if all buffers are aligned to 64 byte boundaries, and 
    -- BUS_DATA_WIDTH is 32 bits (4 bytes), then BUS_BURST_STEP_LEN cannot
    -- exceed 16. This also means that Arrow buffers should at least be aligned
    -- to the BUS_DATA_WIDTH in bytes, because BUS_BURST_STEP_LEN must be at 
    -- least 1.
    
    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 64;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 512;

    -- Number of beats in a burst step.
    BUS_BURST_STEP_LEN          : natural := 4;
    
    -- Maximum number of beats in a burst.
    BUS_BURST_MAX_LEN           : natural := 16;

    ---------------------------------------------------------------------------
    -- Arrow metrics and configuration
    ---------------------------------------------------------------------------
    -- Index field width.
    INDEX_WIDTH                 : natural := 32;

    ---------------------------------------------------------------------------
    -- Array metrics and configuration
    ---------------------------------------------------------------------------
    -- Configures this ArrayReaderLevel. Due to its complexity, the syntax of
    -- this string is documented centrally in ArrayReaderConfig.vhd.
    CFG                         : string := "listprim(8;epc=64)";

    -- Enables or disables command stream tag system. When enabled, an
    -- additional output stream is created that returns tags supplied along
    -- with the command stream when all BufferWriters finish making bus
    -- requests for the command. This can be used to support chunking later.
    CMD_TAG_ENABLE              : boolean := false;

    -- Command stream tag width. Must be at least 1 to avoid null vectors.
    CMD_TAG_WIDTH               : natural := 1

  );
  port (

    ---------------------------------------------------------------------------
    -- Clock domains
    ---------------------------------------------------------------------------
    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    bcd_clk                     : in  std_logic;
    bcd_reset                   : in  std_logic;

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- accelerator side.
    kcd_clk                     : in  std_logic;
    kcd_reset                   : in  std_logic;

    ---------------------------------------------------------------------------
    -- Command streams
    ---------------------------------------------------------------------------
    -- Command stream input (bus clock domain). firstIdx and lastIdx represent
    -- a range of elements to be fetched from memory. firstIdx is inclusive,
    -- lastIdx is exclusive for normal buffers and inclusive for offsets buffers,
    -- in all cases resulting in lastIdx - firstIdx elements. The ctrl vector
    -- is a concatenation of the base address for each buffer and the null
    -- bitmap present flags, dependent on CFG.
    cmd_valid                   : in  std_logic;
    cmd_ready                   : out std_logic;
    cmd_firstIdx                : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmd_lastIdx                 : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmd_ctrl                    : in  std_logic_vector(arcfg_ctrlWidth(CFG, BUS_ADDR_WIDTH)-1 downto 0);
    cmd_tag                     : in  std_logic_vector(CMD_TAG_WIDTH-1 downto 0) := (others => '0');

    -- Unlock stream (bus clock domain). Produces the chunk tags supplied by
    -- the command stream when all BufferWriters finish processing the command.
    unl_valid                   : out std_logic;
    unl_ready                   : in  std_logic := '1';
    unl_tag                     : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    ---------------------------------------------------------------------------
    -- Bus access ports
    ---------------------------------------------------------------------------
    -- Bus access port (bus clock domain).
    bus_wreq_valid              : out std_logic;
    bus_wreq_ready              : in  std_logic;
    bus_wreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_wreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    bus_wreq_last               : out std_logic;
    bus_wdat_valid              : out std_logic;
    bus_wdat_ready              : in  std_logic;
    bus_wdat_data               : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_wdat_strobe             : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
    bus_wdat_last               : out std_logic;
    bus_wrep_valid              : in  std_logic;
    bus_wrep_ready              : out std_logic;
    bus_wrep_ok                 : in  std_logic;

    ---------------------------------------------------------------------------
    -- User streams
    ---------------------------------------------------------------------------
    -- Concatenation of all user input streams at this level of hierarchy
    -- (accelerator clock domain). The master stream starts at the side of the
    -- least significant bit.
    in_valid                    : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    in_ready                    : out std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    in_last                     : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    in_dvalid                   : in  std_logic_vector(arcfg_userCount(CFG)-1 downto 0);
    in_data                     : in  std_logic_vector(arcfg_userWidth(CFG, INDEX_WIDTH)-1 downto 0)

  );
end ArrayWriter;

architecture Behavioral of ArrayWriter is
begin

  -- pragma translate off
  process is begin
    println("WARNING: ArrayWriter support is in early, experimental stage.");
    println("ArrayWriter");
    println("--------------------------------------------------------------");
    println("Config            : " & CFG);
    println("User streams      : " & integer'image(arcfg_userCount(CFG)));
    println("User total width  : " & integer'image(arcfg_userWidth(CFG, INDEX_WIDTH)));
    wait;
  end process;
  -- pragma translate on

  -- Wrap an arbiter and register slices around the requested array writer.
  arb_inst: ArrayWriterArb
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      CFG                       => "arb(" & CFG & ")",
      CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      bcd_clk                   => bcd_clk,
      bcd_reset                 => bcd_reset,
      kcd_clk                   => kcd_clk,
      kcd_reset                 => kcd_reset,
  
      cmd_valid                 => cmd_valid,
      cmd_ready                 => cmd_ready,
      cmd_firstIdx              => cmd_firstIdx,
      cmd_lastIdx               => cmd_lastIdx,
      cmd_ctrl                  => cmd_ctrl,
      cmd_tag                   => cmd_tag,
      
      unlock_valid              => unl_valid,
      unlock_ready              => unl_ready,
      unlock_tag                => unl_tag,
      
      bus_wreq_valid(0)         => bus_wreq_valid,
      bus_wreq_ready(0)         => bus_wreq_ready,
      bus_wreq_addr             => bus_wreq_addr,
      bus_wreq_len              => bus_wreq_len,
      bus_wreq_last(0)          => bus_wreq_last,
      bus_wdat_valid(0)         => bus_wdat_valid,
      bus_wdat_ready(0)         => bus_wdat_ready,
      bus_wdat_strobe           => bus_wdat_strobe,
      bus_wdat_data             => bus_wdat_data,
      bus_wdat_last(0)          => bus_wdat_last,
      bus_wrep_valid(0)         => bus_wrep_valid,
      bus_wrep_ready(0)         => bus_wrep_ready,
      bus_wrep_ok(0)            => bus_wrep_ok,
      
      in_valid                  => in_valid,
      in_ready                  => in_ready,
      in_last                   => in_last,
      in_dvalid                 => in_dvalid,
      in_data                   => in_data
    );

end Behavioral;
