library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Arrays.all;
entity PrimRead is
  generic (
    BUS_ADDR_WIDTH : integer := 64
  );
  port (
    bcd_clk                      : in  std_logic;
    bcd_reset                    : in  std_logic;
    kcd_clk                      : in  std_logic;
    kcd_reset                    : in  std_logic;
    PrimRead_number_valid        : out std_logic;
    PrimRead_number_ready        : in  std_logic;
    PrimRead_number_dvalid       : out std_logic;
    PrimRead_number_last         : out std_logic;
    PrimRead_number              : out std_logic_vector(7 downto 0);
    PrimRead_number_cmd_valid    : in  std_logic;
    PrimRead_number_cmd_ready    : out std_logic;
    PrimRead_number_cmd_firstIdx : in  std_logic_vector(31 downto 0);
    PrimRead_number_cmd_lastidx  : in  std_logic_vector(31 downto 0);
    PrimRead_number_cmd_ctrl     : in  std_logic_vector(1*bus_addr_width-1 downto 0);
    PrimRead_number_cmd_tag      : in  std_logic_vector(0 downto 0);
    PrimRead_number_unl_valid    : out std_logic;
    PrimRead_number_unl_ready    : in  std_logic;
    PrimRead_number_unl_tag      : out std_logic_vector(0 downto 0);
    PrimRead_bus_rreq_valid      : out std_logic;
    PrimRead_bus_rreq_ready      : in  std_logic;
    PrimRead_bus_rreq_addr       : out std_logic_vector(63 downto 0);
    PrimRead_bus_rreq_len        : out std_logic_vector(7 downto 0);
    PrimRead_bus_rdat_valid      : in  std_logic;
    PrimRead_bus_rdat_ready      : out std_logic;
    PrimRead_bus_rdat_data       : in  std_logic_vector(511 downto 0);
    PrimRead_bus_rdat_last       : in  std_logic
  );
end entity;
architecture Implementation of PrimRead is
begin
  number_inst : ArrayReader
    generic map (
      BUS_ADDR_WIDTH     => 64,
      BUS_LEN_WIDTH      => 8,
      BUS_DATA_WIDTH     => 512,
      BUS_BURST_STEP_LEN => 4,
      BUS_BURST_MAX_LEN  => 16,
      INDEX_WIDTH        => 32,
      CFG                => "prim(8)",
      CMD_TAG_ENABLE     => false,
      CMD_TAG_WIDTH      => 1
    )
    port map (
      bcd_clk              => bcd_clk,
      bcd_reset            => bcd_reset,
      kcd_clk              => kcd_clk,
      kcd_reset            => kcd_reset,
      bus_rreq_valid       => PrimRead_bus_rreq_valid,
      bus_rreq_ready       => PrimRead_bus_rreq_ready,
      bus_rreq_addr        => PrimRead_bus_rreq_addr,
      bus_rreq_len         => PrimRead_bus_rreq_len,
      bus_rdat_valid       => PrimRead_bus_rdat_valid,
      bus_rdat_ready       => PrimRead_bus_rdat_ready,
      bus_rdat_data        => PrimRead_bus_rdat_data,
      bus_rdat_last        => PrimRead_bus_rdat_last,
      cmd_valid            => PrimRead_number_cmd_valid,
      cmd_ready            => PrimRead_number_cmd_ready,
      cmd_firstIdx         => PrimRead_number_cmd_firstIdx,
      cmd_lastidx          => PrimRead_number_cmd_lastidx,
      cmd_ctrl             => PrimRead_number_cmd_ctrl,
      cmd_tag              => PrimRead_number_cmd_tag,
      unl_valid            => PrimRead_number_unl_valid,
      unl_ready            => PrimRead_number_unl_ready,
      unl_tag              => PrimRead_number_unl_tag,
      out_valid(0)         => PrimRead_number_valid,
      out_ready(0)         => PrimRead_number_ready,
      out_data(7 downto 0) => PrimRead_number,
      out_dvalid(0)        => PrimRead_number_dvalid,
      out_last(0)          => PrimRead_number_last
    );
end architecture;
