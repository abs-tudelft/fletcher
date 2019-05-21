library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Arrays.all;
entity PrimWrite is
  generic (
    BUS_ADDR_WIDTH : integer := 64
  );
  port (
    bcd_clk                       : in  std_logic;
    bcd_reset                     : in  std_logic;
    kcd_clk                       : in  std_logic;
    kcd_reset                     : in  std_logic;
    PrimWrite_number_valid        : in  std_logic;
    PrimWrite_number_ready        : out std_logic;
    PrimWrite_number_dvalid       : in  std_logic;
    PrimWrite_number_last         : in  std_logic;
    PrimWrite_number              : in  std_logic_vector(7 downto 0);
    PrimWrite_number_cmd_valid    : in  std_logic;
    PrimWrite_number_cmd_ready    : out std_logic;
    PrimWrite_number_cmd_firstIdx : in  std_logic_vector(31 downto 0);
    PrimWrite_number_cmd_lastidx  : in  std_logic_vector(31 downto 0);
    PrimWrite_number_cmd_ctrl     : in  std_logic_vector(1*bus_addr_width-1 downto 0);
    PrimWrite_number_cmd_tag      : in  std_logic_vector(0 downto 0);
    PrimWrite_number_unl_valid    : out std_logic;
    PrimWrite_number_unl_ready    : in  std_logic;
    PrimWrite_number_unl_tag      : out std_logic_vector(0 downto 0);
    PrimWrite_bus_wreq_valid      : out std_logic;
    PrimWrite_bus_wreq_ready      : in  std_logic;
    PrimWrite_bus_wreq_addr       : out std_logic_vector(63 downto 0);
    PrimWrite_bus_wreq_len        : out std_logic_vector(7 downto 0);
    PrimWrite_bus_wdat_valid      : out std_logic;
    PrimWrite_bus_wdat_ready      : in  std_logic;
    PrimWrite_bus_wdat_data       : out std_logic_vector(511 downto 0);
    PrimWrite_bus_wdat_strobe     : out std_logic_vector(63 downto 0);
    PrimWrite_bus_wdat_last       : out std_logic
  );
end entity;
architecture Implementation of PrimWrite is
begin
  number_inst : ArrayWriter
    generic map (
      BUS_ADDR_WIDTH     => 64,
      BUS_LEN_WIDTH      => 8,
      BUS_DATA_WIDTH     => 512,
      BUS_STROBE_WIDTH   => 64,
      BUS_BURST_STEP_LEN => 4,
      BUS_BURST_MAX_LEN  => 16,
      INDEX_WIDTH        => 32,
      CFG                => "prim(8)",
      CMD_TAG_ENABLE     => false,
      CMD_TAG_WIDTH      => 1
    )
    port map (
      bcd_clk             => bcd_clk,
      bcd_reset           => bcd_reset,
      kcd_clk             => kcd_clk,
      kcd_reset           => kcd_reset,
      bus_wreq_valid      => PrimWrite_bus_wreq_valid,
      bus_wreq_ready      => PrimWrite_bus_wreq_ready,
      bus_wreq_addr       => PrimWrite_bus_wreq_addr,
      bus_wreq_len        => PrimWrite_bus_wreq_len,
      bus_wdat_valid      => PrimWrite_bus_wdat_valid,
      bus_wdat_ready      => PrimWrite_bus_wdat_ready,
      bus_wdat_data       => PrimWrite_bus_wdat_data,
      bus_wdat_strobe     => PrimWrite_bus_wdat_strobe,
      bus_wdat_last       => PrimWrite_bus_wdat_last,
      cmd_valid           => PrimWrite_number_cmd_valid,
      cmd_ready           => PrimWrite_number_cmd_ready,
      cmd_firstIdx        => PrimWrite_number_cmd_firstIdx,
      cmd_lastidx         => PrimWrite_number_cmd_lastidx,
      cmd_ctrl            => PrimWrite_number_cmd_ctrl,
      cmd_tag             => PrimWrite_number_cmd_tag,
      unl_valid           => PrimWrite_number_unl_valid,
      unl_ready           => PrimWrite_number_unl_ready,
      unl_tag             => PrimWrite_number_unl_tag,
      in_valid(0)         => PrimWrite_number_valid,
      in_ready(0)         => PrimWrite_number_ready,
      in_data(7 downto 0) => PrimWrite_number,
      in_dvalid(0)        => PrimWrite_number_dvalid,
      in_last(0)          => PrimWrite_number_last
    );
end architecture;
