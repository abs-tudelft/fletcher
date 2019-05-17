library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Arrays.all;
entity Strings_RecordBatchReader is
  generic (
    BUS_ADDR_WIDTH : integer := 64
  );
  port (
    bcd_clk             : in  std_logic;
    bcd_reset           : in  std_logic;
    kcd_clk             : in  std_logic;
    kcd_reset           : in  std_logic;
    Name_valid          : out std_logic;
    Name_ready          : in  std_logic;
    Name_dvalid         : out std_logic;
    Name_last           : out std_logic;
    Name_length         : out std_logic_vector(31 downto 0);
    Name_count          : out std_logic_vector(0 downto 0);
    Name_chars_valid    : out std_logic;
    Name_chars_ready    : in  std_logic;
    Name_chars_dvalid   : out std_logic;
    Name_chars_last     : out std_logic;
    Name_chars_data     : out std_logic_vector(31 downto 0);
    Name_chars_count    : out std_logic_vector(2 downto 0);
    Name_cmd_valid      : in  std_logic;
    Name_cmd_ready      : out std_logic;
    Name_cmd_firstIdx   : in  std_logic_vector(31 downto 0);
    Name_cmd_lastidx    : in  std_logic_vector(31 downto 0);
    Name_cmd_ctrl       : in  std_logic_vector(2*bus_addr_width-1 downto 0);
    Name_cmd_tag        : in  std_logic_vector(0 downto 0);
    Name_unl_valid      : out std_logic;
    Name_unl_ready      : in  std_logic;
    Name_unl_tag        : out std_logic_vector(0 downto 0);
    Name_bus_rreq_valid : out std_logic;
    Name_bus_rreq_ready : in  std_logic;
    Name_bus_rreq_addr  : out std_logic_vector(63 downto 0);
    Name_bus_rreq_len   : out std_logic_vector(7 downto 0);
    Name_bus_rdat_valid : in  std_logic;
    Name_bus_rdat_ready : out std_logic;
    Name_bus_rdat_data  : in  std_logic_vector(511 downto 0);
    Name_bus_rdat_last  : in  std_logic
  );
end entity;
architecture Implementation of Strings_RecordBatchReader is
begin
  Name_ArrayReader_Inst : ArrayReader
    generic map (
      BUS_ADDR_WIDTH     => 64,
      BUS_LEN_WIDTH      => 8,
      BUS_DATA_WIDTH     => 512,
      BUS_BURST_STEP_LEN => 4,
      BUS_BURST_MAX_LEN  => 16,
      INDEX_WIDTH        => 32,
      CFG                => "listprim(8;epc=4)",
      CMD_TAG_ENABLE     => false,
      CMD_TAG_WIDTH      => 1
    )
    port map (
      bcd_clk                => bcd_clk,
      bcd_reset              => bcd_reset,
      kcd_clk                => kcd_clk,
      kcd_reset              => kcd_reset,
      bus_rreq_valid         => Name_bus_rreq_valid,
      bus_rreq_ready         => Name_bus_rreq_ready,
      bus_rreq_addr          => Name_bus_rreq_addr,
      bus_rreq_len           => Name_bus_rreq_len,
      bus_rdat_valid         => Name_bus_rdat_valid,
      bus_rdat_ready         => Name_bus_rdat_ready,
      bus_rdat_data          => Name_bus_rdat_data,
      bus_rdat_last          => Name_bus_rdat_last,
      cmd_valid              => Name_cmd_valid,
      cmd_ready              => Name_cmd_ready,
      cmd_firstIdx           => Name_cmd_firstIdx,
      cmd_lastidx            => Name_cmd_lastidx,
      cmd_ctrl               => Name_cmd_ctrl,
      cmd_tag                => Name_cmd_tag,
      unl_valid              => Name_unl_valid,
      unl_ready              => Name_unl_ready,
      unl_tag                => Name_unl_tag,
      out_valid(0)           => Name_valid,
      out_valid(1)           => Name_chars_valid,
      out_ready(0)           => Name_ready,
      out_ready(1)           => Name_chars_ready,
      out_data(31 downto 0)  => Name_length,
      out_data(32 downto 32) => Name_count,
      out_data(64 downto 33) => Name_chars_data,
      out_data(67 downto 65) => Name_chars_count,
      out_dvalid(0)          => Name_dvalid,
      out_dvalid(1)          => Name_chars_dvalid,
      out_last(0)            => Name_last,
      out_last(1)            => Name_chars_last
    );
end architecture;
