library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Arrays.all;
entity StringRead is
  generic (
    BUS_ADDR_WIDTH : integer := 64
  );
  port (
    bcd_clk                      : in  std_logic;
    bcd_reset                    : in  std_logic;
    kcd_clk                      : in  std_logic;
    kcd_reset                    : in  std_logic;
    StringRead_Name_valid        : out std_logic;
    StringRead_Name_ready        : in  std_logic;
    StringRead_Name_dvalid       : out std_logic;
    StringRead_Name_last         : out std_logic;
    StringRead_Name_length       : out std_logic_vector(31 downto 0);
    StringRead_Name_count        : out std_logic_vector(0 downto 0);
    StringRead_Name_chars_valid  : out std_logic;
    StringRead_Name_chars_ready  : in  std_logic;
    StringRead_Name_chars_dvalid : out std_logic;
    StringRead_Name_chars_last   : out std_logic;
    StringRead_Name_chars_data   : out std_logic_vector(31 downto 0);
    StringRead_Name_chars_count  : out std_logic_vector(2 downto 0);
    StringRead_Name_cmd_valid    : in  std_logic;
    StringRead_Name_cmd_ready    : out std_logic;
    StringRead_Name_cmd_firstIdx : in  std_logic_vector(31 downto 0);
    StringRead_Name_cmd_lastidx  : in  std_logic_vector(31 downto 0);
    StringRead_Name_cmd_ctrl     : in  std_logic_vector(2*bus_addr_width-1 downto 0);
    StringRead_Name_cmd_tag      : in  std_logic_vector(0 downto 0);
    StringRead_Name_unl_valid    : out std_logic;
    StringRead_Name_unl_ready    : in  std_logic;
    StringRead_Name_unl_tag      : out std_logic_vector(0 downto 0);
    StringRead_bus_rreq_valid    : out std_logic;
    StringRead_bus_rreq_ready    : in  std_logic;
    StringRead_bus_rreq_addr     : out std_logic_vector(63 downto 0);
    StringRead_bus_rreq_len      : out std_logic_vector(7 downto 0);
    StringRead_bus_rdat_valid    : in  std_logic;
    StringRead_bus_rdat_ready    : out std_logic;
    StringRead_bus_rdat_data     : in  std_logic_vector(511 downto 0);
    StringRead_bus_rdat_last     : in  std_logic
  );
end entity;
architecture Implementation of StringRead is
begin
  Name_inst : ArrayReader
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
      bus_rreq_valid         => StringRead_bus_rreq_valid,
      bus_rreq_ready         => StringRead_bus_rreq_ready,
      bus_rreq_addr          => StringRead_bus_rreq_addr,
      bus_rreq_len           => StringRead_bus_rreq_len,
      bus_rdat_valid         => StringRead_bus_rdat_valid,
      bus_rdat_ready         => StringRead_bus_rdat_ready,
      bus_rdat_data          => StringRead_bus_rdat_data,
      bus_rdat_last          => StringRead_bus_rdat_last,
      cmd_valid              => StringRead_Name_cmd_valid,
      cmd_ready              => StringRead_Name_cmd_ready,
      cmd_firstIdx           => StringRead_Name_cmd_firstIdx,
      cmd_lastidx            => StringRead_Name_cmd_lastidx,
      cmd_ctrl               => StringRead_Name_cmd_ctrl,
      cmd_tag                => StringRead_Name_cmd_tag,
      unl_valid              => StringRead_Name_unl_valid,
      unl_ready              => StringRead_Name_unl_ready,
      unl_tag                => StringRead_Name_unl_tag,
      out_valid(0)           => StringRead_Name_valid,
      out_valid(1)           => StringRead_Name_chars_valid,
      out_ready(0)           => StringRead_Name_ready,
      out_ready(1)           => StringRead_Name_chars_ready,
      out_data(31 downto 0)  => StringRead_Name_length,
      out_data(32 downto 32) => StringRead_Name_count,
      out_data(64 downto 33) => StringRead_Name_chars_data,
      out_data(67 downto 65) => StringRead_Name_chars_count,
      out_dvalid(0)          => StringRead_Name_dvalid,
      out_dvalid(1)          => StringRead_Name_chars_dvalid,
      out_last(0)            => StringRead_Name_last,
      out_last(1)            => StringRead_Name_chars_last
    );
end architecture;
