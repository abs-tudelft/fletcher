library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Interconnect_pkg.all;
entity Mantle is
  generic (
    BUS_ADDR_WIDTH : integer := 64
  );
  port (
    bcd_clk        : in  std_logic;
    bcd_reset      : in  std_logic;
    kcd_clk        : in  std_logic;
    kcd_reset      : in  std_logic;
    mmio_awvalid   : in  std_logic;
    mmio_awready   : out std_logic;
    mmio_awaddr    : in  std_logic_vector(31 downto 0);
    mmio_wvalid    : in  std_logic;
    mmio_wready    : out std_logic;
    mmio_wdata     : in  std_logic_vector(31 downto 0);
    mmio_wstrb     : in  std_logic_vector(3 downto 0);
    mmio_bvalid    : out std_logic;
    mmio_bready    : in  std_logic;
    mmio_bresp     : out std_logic_vector(1 downto 0);
    mmio_arvalid   : in  std_logic;
    mmio_arready   : out std_logic;
    mmio_araddr    : in  std_logic_vector(31 downto 0);
    mmio_rvalid    : out std_logic;
    mmio_rready    : in  std_logic;
    mmio_rdata     : out std_logic_vector(31 downto 0);
    mmio_rresp     : out std_logic_vector(1 downto 0);
    mst_rreq_valid : out std_logic;
    mst_rreq_ready : in  std_logic;
    mst_rreq_addr  : out std_logic_vector(63 downto 0);
    mst_rreq_len   : out std_logic_vector(7 downto 0);
    mst_rdat_valid : in  std_logic;
    mst_rdat_ready : out std_logic;
    mst_rdat_data  : in  std_logic_vector(511 downto 0);
    mst_rdat_last  : in  std_logic
  );
end entity;
architecture Implementation of Mantle is
  component MyNumbers is
    generic (
      BUS_ADDR_WIDTH : integer := 64
    );
    port (
      bcd_clk                         : in  std_logic;
      bcd_reset                       : in  std_logic;
      kcd_clk                         : in  std_logic;
      kcd_reset                       : in  std_logic;
      MyNumbers_number_valid          : out std_logic;
      MyNumbers_number_ready          : in  std_logic;
      MyNumbers_number_dvalid         : out std_logic;
      MyNumbers_number_last           : out std_logic;
      MyNumbers_number                : out std_logic_vector(63 downto 0);
      MyNumbers_number_cmd_valid      : in  std_logic;
      MyNumbers_number_cmd_ready      : out std_logic;
      MyNumbers_number_cmd_firstIdx   : in  std_logic_vector(31 downto 0);
      MyNumbers_number_cmd_lastidx    : in  std_logic_vector(31 downto 0);
      MyNumbers_number_cmd_ctrl       : in  std_logic_vector(1*bus_addr_width-1 downto 0);
      MyNumbers_number_cmd_tag        : in  std_logic_vector(0 downto 0);
      MyNumbers_number_unl_valid      : out std_logic;
      MyNumbers_number_unl_ready      : in  std_logic;
      MyNumbers_number_unl_tag        : out std_logic_vector(0 downto 0);
      MyNumbers_number_bus_rreq_valid : out std_logic;
      MyNumbers_number_bus_rreq_ready : in  std_logic;
      MyNumbers_number_bus_rreq_addr  : out std_logic_vector(63 downto 0);
      MyNumbers_number_bus_rreq_len   : out std_logic_vector(7 downto 0);
      MyNumbers_number_bus_rdat_valid : in  std_logic;
      MyNumbers_number_bus_rdat_ready : out std_logic;
      MyNumbers_number_bus_rdat_data  : in  std_logic_vector(511 downto 0);
      MyNumbers_number_bus_rdat_last  : in  std_logic
    );
  end component;
  component Kernel is
    generic (
      BUS_ADDR_WIDTH : integer := 64
    );
    port (
      kcd_clk                       : in  std_logic;
      kcd_reset                     : in  std_logic;
      mmio_awvalid                  : in  std_logic;
      mmio_awready                  : out std_logic;
      mmio_awaddr                   : in  std_logic_vector(31 downto 0);
      mmio_wvalid                   : in  std_logic;
      mmio_wready                   : out std_logic;
      mmio_wdata                    : in  std_logic_vector(31 downto 0);
      mmio_wstrb                    : in  std_logic_vector(3 downto 0);
      mmio_bvalid                   : out std_logic;
      mmio_bready                   : in  std_logic;
      mmio_bresp                    : out std_logic_vector(1 downto 0);
      mmio_arvalid                  : in  std_logic;
      mmio_arready                  : out std_logic;
      mmio_araddr                   : in  std_logic_vector(31 downto 0);
      mmio_rvalid                   : out std_logic;
      mmio_rready                   : in  std_logic;
      mmio_rdata                    : out std_logic_vector(31 downto 0);
      mmio_rresp                    : out std_logic_vector(1 downto 0);
      MyNumbers_number_valid        : in  std_logic;
      MyNumbers_number_ready        : out std_logic;
      MyNumbers_number_dvalid       : in  std_logic;
      MyNumbers_number_last         : in  std_logic;
      MyNumbers_number              : in  std_logic_vector(63 downto 0);
      MyNumbers_number_cmd_valid    : out std_logic;
      MyNumbers_number_cmd_ready    : in  std_logic;
      MyNumbers_number_cmd_firstIdx : out std_logic_vector(31 downto 0);
      MyNumbers_number_cmd_lastidx  : out std_logic_vector(31 downto 0);
      MyNumbers_number_cmd_ctrl     : out std_logic_vector(1*bus_addr_width-1 downto 0);
      MyNumbers_number_cmd_tag      : out std_logic_vector(0 downto 0);
      MyNumbers_number_unl_valid    : in  std_logic;
      MyNumbers_number_unl_ready    : out std_logic;
      MyNumbers_number_unl_tag      : in  std_logic_vector(0 downto 0)
    );
  end component;
  signal MyNumbers_inst_MyNumbers_number_valid  : std_logic;
  signal MyNumbers_inst_MyNumbers_number_ready  : std_logic;
  signal MyNumbers_inst_MyNumbers_number_dvalid : std_logic;
  signal MyNumbers_inst_MyNumbers_number_last   : std_logic;
  signal MyNumbers_inst_MyNumbers_number        : std_logic_vector(63 downto 0);
  signal MyNumbers_inst_MyNumbers_number_unl_valid : std_logic;
  signal MyNumbers_inst_MyNumbers_number_unl_ready : std_logic;
  signal MyNumbers_inst_MyNumbers_number_unl_tag   : std_logic_vector(0 downto 0);
  signal MyNumbers_inst_MyNumbers_number_bus_rreq_valid : std_logic;
  signal MyNumbers_inst_MyNumbers_number_bus_rreq_ready : std_logic;
  signal MyNumbers_inst_MyNumbers_number_bus_rreq_addr  : std_logic_vector(63 downto 0);
  signal MyNumbers_inst_MyNumbers_number_bus_rreq_len   : std_logic_vector(7 downto 0);
  signal MyNumbers_inst_MyNumbers_number_bus_rdat_valid : std_logic;
  signal MyNumbers_inst_MyNumbers_number_bus_rdat_ready : std_logic;
  signal MyNumbers_inst_MyNumbers_number_bus_rdat_data  : std_logic_vector(511 downto 0);
  signal MyNumbers_inst_MyNumbers_number_bus_rdat_last  : std_logic;
  signal Kernel_inst_MyNumbers_number_cmd_valid    : std_logic;
  signal Kernel_inst_MyNumbers_number_cmd_ready    : std_logic;
  signal Kernel_inst_MyNumbers_number_cmd_firstIdx : std_logic_vector(31 downto 0);
  signal Kernel_inst_MyNumbers_number_cmd_lastidx  : std_logic_vector(31 downto 0);
  signal Kernel_inst_MyNumbers_number_cmd_ctrl     : std_logic_vector(1*bus_addr_width-1 downto 0);
  signal Kernel_inst_MyNumbers_number_cmd_tag      : std_logic_vector(0 downto 0);
begin
  MyNumbers_inst : MyNumbers
    generic map (
      BUS_ADDR_WIDTH => 64
    )
    port map (
      bcd_clk                         => bcd_clk,
      bcd_reset                       => bcd_reset,
      kcd_clk                         => kcd_clk,
      kcd_reset                       => kcd_reset,
      MyNumbers_number_valid          => MyNumbers_inst_MyNumbers_number_valid,
      MyNumbers_number_ready          => MyNumbers_inst_MyNumbers_number_ready,
      MyNumbers_number_dvalid         => MyNumbers_inst_MyNumbers_number_dvalid,
      MyNumbers_number_last           => MyNumbers_inst_MyNumbers_number_last,
      MyNumbers_number                => MyNumbers_inst_MyNumbers_number,
      MyNumbers_number_cmd_valid      => Kernel_inst_MyNumbers_number_cmd_valid,
      MyNumbers_number_cmd_ready      => Kernel_inst_MyNumbers_number_cmd_ready,
      MyNumbers_number_cmd_firstIdx   => Kernel_inst_MyNumbers_number_cmd_firstIdx,
      MyNumbers_number_cmd_lastidx    => Kernel_inst_MyNumbers_number_cmd_lastidx,
      MyNumbers_number_cmd_ctrl       => Kernel_inst_MyNumbers_number_cmd_ctrl,
      MyNumbers_number_cmd_tag        => Kernel_inst_MyNumbers_number_cmd_tag,
      MyNumbers_number_unl_valid      => MyNumbers_inst_MyNumbers_number_unl_valid,
      MyNumbers_number_unl_ready      => MyNumbers_inst_MyNumbers_number_unl_ready,
      MyNumbers_number_unl_tag        => MyNumbers_inst_MyNumbers_number_unl_tag,
      MyNumbers_number_bus_rreq_valid => MyNumbers_inst_MyNumbers_number_bus_rreq_valid,
      MyNumbers_number_bus_rreq_ready => MyNumbers_inst_MyNumbers_number_bus_rreq_ready,
      MyNumbers_number_bus_rreq_addr  => MyNumbers_inst_MyNumbers_number_bus_rreq_addr,
      MyNumbers_number_bus_rreq_len   => MyNumbers_inst_MyNumbers_number_bus_rreq_len,
      MyNumbers_number_bus_rdat_valid => MyNumbers_inst_MyNumbers_number_bus_rdat_valid,
      MyNumbers_number_bus_rdat_ready => MyNumbers_inst_MyNumbers_number_bus_rdat_ready,
      MyNumbers_number_bus_rdat_data  => MyNumbers_inst_MyNumbers_number_bus_rdat_data,
      MyNumbers_number_bus_rdat_last  => MyNumbers_inst_MyNumbers_number_bus_rdat_last
    );
  Kernel_inst : Kernel
    generic map (
      BUS_ADDR_WIDTH => 64
    )
    port map (
      kcd_clk                       => kcd_clk,
      kcd_reset                     => kcd_reset,
      mmio_awvalid                  => mmio_awvalid,
      mmio_awready                  => mmio_awready,
      mmio_awaddr                   => mmio_awaddr,
      mmio_wvalid                   => mmio_wvalid,
      mmio_wready                   => mmio_wready,
      mmio_wdata                    => mmio_wdata,
      mmio_wstrb                    => mmio_wstrb,
      mmio_bvalid                   => mmio_bvalid,
      mmio_bready                   => mmio_bready,
      mmio_bresp                    => mmio_bresp,
      mmio_arvalid                  => mmio_arvalid,
      mmio_arready                  => mmio_arready,
      mmio_araddr                   => mmio_araddr,
      mmio_rvalid                   => mmio_rvalid,
      mmio_rready                   => mmio_rready,
      mmio_rdata                    => mmio_rdata,
      mmio_rresp                    => mmio_rresp,
      MyNumbers_number_valid        => MyNumbers_inst_MyNumbers_number_valid,
      MyNumbers_number_ready        => MyNumbers_inst_MyNumbers_number_ready,
      MyNumbers_number_dvalid       => MyNumbers_inst_MyNumbers_number_dvalid,
      MyNumbers_number_last         => MyNumbers_inst_MyNumbers_number_last,
      MyNumbers_number              => MyNumbers_inst_MyNumbers_number,
      MyNumbers_number_cmd_valid    => Kernel_inst_MyNumbers_number_cmd_valid,
      MyNumbers_number_cmd_ready    => Kernel_inst_MyNumbers_number_cmd_ready,
      MyNumbers_number_cmd_firstIdx => Kernel_inst_MyNumbers_number_cmd_firstIdx,
      MyNumbers_number_cmd_lastidx  => Kernel_inst_MyNumbers_number_cmd_lastidx,
      MyNumbers_number_cmd_ctrl     => Kernel_inst_MyNumbers_number_cmd_ctrl,
      MyNumbers_number_cmd_tag      => Kernel_inst_MyNumbers_number_cmd_tag,
      MyNumbers_number_unl_valid    => MyNumbers_inst_MyNumbers_number_unl_valid,
      MyNumbers_number_unl_ready    => MyNumbers_inst_MyNumbers_number_unl_ready,
      MyNumbers_number_unl_tag      => MyNumbers_inst_MyNumbers_number_unl_tag
    );
  BusReadArbiterVec_inst : BusReadArbiterVec
    generic map (
      NUM_SLAVE_PORTS => 1,
      BUS_ADDR_WIDTH  => 64,
      BUS_LEN_WIDTH   => 8,
      BUS_DATA_WIDTH  => 512,
      ARB_METHOD      => "ROUND-ROBIN",
      MAX_OUTSTANDING => 4,
      RAM_CONFIG      => "",
      SLV_REQ_SLICES  => true,
      MST_REQ_SLICE   => true,
      MST_DAT_SLICE   => true,
      SLV_DAT_SLICES  => true
    )
    port map (
      bcd_clk                     => bcd_clk,
      bcd_reset                   => bcd_reset,
      mst_rreq_valid              => mst_rreq_valid,
      mst_rreq_ready              => mst_rreq_ready,
      mst_rreq_addr               => mst_rreq_addr,
      mst_rreq_len                => mst_rreq_len,
      mst_rdat_valid              => mst_rdat_valid,
      mst_rdat_ready              => mst_rdat_ready,
      mst_rdat_data               => mst_rdat_data,
      mst_rdat_last               => mst_rdat_last,
      bsv_rreq_valid(0)           => MyNumbers_inst_MyNumbers_number_bus_rreq_valid,
      bsv_rreq_ready(0)           => MyNumbers_inst_MyNumbers_number_bus_rreq_ready,
      bsv_rreq_len(7 downto 0)    => MyNumbers_inst_MyNumbers_number_bus_rreq_len,
      bsv_rreq_addr(63 downto 0)  => MyNumbers_inst_MyNumbers_number_bus_rreq_addr,
      bsv_rdat_valid(0)           => MyNumbers_inst_MyNumbers_number_bus_rdat_valid,
      bsv_rdat_ready(0)           => MyNumbers_inst_MyNumbers_number_bus_rdat_ready,
      bsv_rdat_last(0)            => MyNumbers_inst_MyNumbers_number_bus_rdat_last,
      bsv_rdat_data(511 downto 0) => MyNumbers_inst_MyNumbers_number_bus_rdat_data
    );
end architecture;
