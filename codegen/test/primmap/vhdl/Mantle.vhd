library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.Interconnect.all;
use work.Interconnect.all;
entity Mantle is
  generic (
    BUS_ADDR_WIDTH : integer := 64
  );
  port (
    bcd_clk         : in  std_logic;
    bcd_reset       : in  std_logic;
    kcd_clk         : in  std_logic;
    kcd_reset       : in  std_logic;
    mmio_awvalid    : in  std_logic;
    mmio_awready    : out std_logic;
    mmio_awaddr     : in  std_logic_vector(31 downto 0);
    mmio_wvalid     : in  std_logic;
    mmio_wready     : out std_logic;
    mmio_wdata      : in  std_logic_vector(31 downto 0);
    mmio_wstrb      : in  std_logic_vector(3 downto 0);
    mmio_bvalid     : out std_logic;
    mmio_bready     : in  std_logic;
    mmio_bresp      : out std_logic_vector(1 downto 0);
    mmio_arvalid    : in  std_logic;
    mmio_arready    : out std_logic;
    mmio_araddr     : in  std_logic_vector(31 downto 0);
    mmio_rvalid     : out std_logic;
    mmio_rready     : in  std_logic;
    mmio_rdata      : out std_logic_vector(31 downto 0);
    mmio_rresp      : out std_logic_vector(1 downto 0);
    mst_rreq_valid  : out std_logic;
    mst_rreq_ready  : in  std_logic;
    mst_rreq_addr   : out std_logic_vector(63 downto 0);
    mst_rreq_len    : out std_logic_vector(7 downto 0);
    mst_rdat_valid  : in  std_logic;
    mst_rdat_ready  : out std_logic;
    mst_rdat_data   : in  std_logic_vector(511 downto 0);
    mst_rdat_last   : in  std_logic;
    mst_wreq_valid  : out std_logic;
    mst_wreq_ready  : in  std_logic;
    mst_wreq_addr   : out std_logic_vector(63 downto 0);
    mst_wreq_len    : out std_logic_vector(7 downto 0);
    mst_wdat_valid  : out std_logic;
    mst_wdat_ready  : in  std_logic;
    mst_wdat_data   : out std_logic_vector(511 downto 0);
    mst_wdat_strobe : out std_logic_vector(63 downto 0);
    mst_wdat_last   : out std_logic
  );
end entity;
architecture Implementation of Mantle is
  component PrimRead is
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
  end component;
  component PrimWrite is
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
      PrimRead_number_valid         : in  std_logic;
      PrimRead_number_ready         : out std_logic;
      PrimRead_number_dvalid        : in  std_logic;
      PrimRead_number_last          : in  std_logic;
      PrimRead_number               : in  std_logic_vector(7 downto 0);
      PrimRead_number_cmd_valid     : out std_logic;
      PrimRead_number_cmd_ready     : in  std_logic;
      PrimRead_number_cmd_firstIdx  : out std_logic_vector(31 downto 0);
      PrimRead_number_cmd_lastidx   : out std_logic_vector(31 downto 0);
      PrimRead_number_cmd_ctrl      : out std_logic_vector(1*bus_addr_width-1 downto 0);
      PrimRead_number_cmd_tag       : out std_logic_vector(0 downto 0);
      PrimRead_number_unl_valid     : in  std_logic;
      PrimRead_number_unl_ready     : out std_logic;
      PrimRead_number_unl_tag       : in  std_logic_vector(0 downto 0);
      PrimWrite_number_valid        : out std_logic;
      PrimWrite_number_ready        : in  std_logic;
      PrimWrite_number_dvalid       : out std_logic;
      PrimWrite_number_last         : out std_logic;
      PrimWrite_number              : out std_logic_vector(7 downto 0);
      PrimWrite_number_cmd_valid    : out std_logic;
      PrimWrite_number_cmd_ready    : in  std_logic;
      PrimWrite_number_cmd_firstIdx : out std_logic_vector(31 downto 0);
      PrimWrite_number_cmd_lastidx  : out std_logic_vector(31 downto 0);
      PrimWrite_number_cmd_ctrl     : out std_logic_vector(1*bus_addr_width-1 downto 0);
      PrimWrite_number_cmd_tag      : out std_logic_vector(0 downto 0);
      PrimWrite_number_unl_valid    : in  std_logic;
      PrimWrite_number_unl_ready    : out std_logic;
      PrimWrite_number_unl_tag      : in  std_logic_vector(0 downto 0)
    );
  end component;
  signal Kernel_inst_PrimRead_number_valid  : std_logic;
  signal Kernel_inst_PrimRead_number_ready  : std_logic;
  signal Kernel_inst_PrimRead_number_dvalid : std_logic;
  signal Kernel_inst_PrimRead_number_last   : std_logic;
  signal Kernel_inst_PrimRead_number        : std_logic_vector(7 downto 0);
  signal Kernel_inst_PrimRead_number_unl_valid : std_logic;
  signal Kernel_inst_PrimRead_number_unl_ready : std_logic;
  signal Kernel_inst_PrimRead_number_unl_tag   : std_logic_vector(0 downto 0);
  signal BusReadArbiterVec_inst_bsv_rreq_valid : std_logic;
  signal BusReadArbiterVec_inst_bsv_rreq_ready : std_logic;
  signal BusReadArbiterVec_inst_bsv_rreq_addr  : std_logic_vector(63 downto 0);
  signal BusReadArbiterVec_inst_bsv_rreq_len   : std_logic_vector(7 downto 0);
  signal BusReadArbiterVec_inst_bsv_rdat_valid : std_logic;
  signal BusReadArbiterVec_inst_bsv_rdat_ready : std_logic;
  signal BusReadArbiterVec_inst_bsv_rdat_data  : std_logic_vector(511 downto 0);
  signal BusReadArbiterVec_inst_bsv_rdat_last  : std_logic;
  signal Kernel_inst_PrimWrite_number_unl_valid : std_logic;
  signal Kernel_inst_PrimWrite_number_unl_ready : std_logic;
  signal Kernel_inst_PrimWrite_number_unl_tag   : std_logic_vector(0 downto 0);
  signal BusWriteArbiterVec_inst_bsv_wreq_valid  : std_logic;
  signal BusWriteArbiterVec_inst_bsv_wreq_ready  : std_logic;
  signal BusWriteArbiterVec_inst_bsv_wreq_addr   : std_logic_vector(63 downto 0);
  signal BusWriteArbiterVec_inst_bsv_wreq_len    : std_logic_vector(7 downto 0);
  signal BusWriteArbiterVec_inst_bsv_wdat_valid  : std_logic;
  signal BusWriteArbiterVec_inst_bsv_wdat_ready  : std_logic;
  signal BusWriteArbiterVec_inst_bsv_wdat_data   : std_logic_vector(511 downto 0);
  signal BusWriteArbiterVec_inst_bsv_wdat_strobe : std_logic_vector(63 downto 0);
  signal BusWriteArbiterVec_inst_bsv_wdat_last   : std_logic;
  signal PrimRead_inst_PrimRead_number_cmd_valid    : std_logic;
  signal PrimRead_inst_PrimRead_number_cmd_ready    : std_logic;
  signal PrimRead_inst_PrimRead_number_cmd_firstIdx : std_logic_vector(31 downto 0);
  signal PrimRead_inst_PrimRead_number_cmd_lastidx  : std_logic_vector(31 downto 0);
  signal PrimRead_inst_PrimRead_number_cmd_ctrl     : std_logic_vector(1*bus_addr_width-1 downto 0);
  signal PrimRead_inst_PrimRead_number_cmd_tag      : std_logic_vector(0 downto 0);
  signal PrimWrite_inst_PrimWrite_number_valid  : std_logic;
  signal PrimWrite_inst_PrimWrite_number_ready  : std_logic;
  signal PrimWrite_inst_PrimWrite_number_dvalid : std_logic;
  signal PrimWrite_inst_PrimWrite_number_last   : std_logic;
  signal PrimWrite_inst_PrimWrite_number        : std_logic_vector(7 downto 0);
  signal PrimWrite_inst_PrimWrite_number_cmd_valid    : std_logic;
  signal PrimWrite_inst_PrimWrite_number_cmd_ready    : std_logic;
  signal PrimWrite_inst_PrimWrite_number_cmd_firstIdx : std_logic_vector(31 downto 0);
  signal PrimWrite_inst_PrimWrite_number_cmd_lastidx  : std_logic_vector(31 downto 0);
  signal PrimWrite_inst_PrimWrite_number_cmd_ctrl     : std_logic_vector(1*bus_addr_width-1 downto 0);
  signal PrimWrite_inst_PrimWrite_number_cmd_tag      : std_logic_vector(0 downto 0);
begin
  PrimRead_inst : PrimRead
    generic map (
      BUS_ADDR_WIDTH => 64
    )
    port map (
      bcd_clk                      => bcd_clk,
      bcd_reset                    => bcd_reset,
      kcd_clk                      => kcd_clk,
      kcd_reset                    => kcd_reset,
      PrimRead_number_valid        => Kernel_inst_PrimRead_number_valid,
      PrimRead_number_ready        => Kernel_inst_PrimRead_number_ready,
      PrimRead_number_dvalid       => Kernel_inst_PrimRead_number_dvalid,
      PrimRead_number_last         => Kernel_inst_PrimRead_number_last,
      PrimRead_number              => Kernel_inst_PrimRead_number,
      PrimRead_number_cmd_valid    => PrimRead_inst_PrimRead_number_cmd_valid,
      PrimRead_number_cmd_ready    => PrimRead_inst_PrimRead_number_cmd_ready,
      PrimRead_number_cmd_firstIdx => PrimRead_inst_PrimRead_number_cmd_firstIdx,
      PrimRead_number_cmd_lastidx  => PrimRead_inst_PrimRead_number_cmd_lastidx,
      PrimRead_number_cmd_ctrl     => PrimRead_inst_PrimRead_number_cmd_ctrl,
      PrimRead_number_cmd_tag      => PrimRead_inst_PrimRead_number_cmd_tag,
      PrimRead_number_unl_valid    => Kernel_inst_PrimRead_number_unl_valid,
      PrimRead_number_unl_ready    => Kernel_inst_PrimRead_number_unl_ready,
      PrimRead_number_unl_tag      => Kernel_inst_PrimRead_number_unl_tag,
      PrimRead_bus_rreq_valid      => BusReadArbiterVec_inst_bsv_rreq_valid,
      PrimRead_bus_rreq_ready      => BusReadArbiterVec_inst_bsv_rreq_ready,
      PrimRead_bus_rreq_addr       => BusReadArbiterVec_inst_bsv_rreq_addr,
      PrimRead_bus_rreq_len        => BusReadArbiterVec_inst_bsv_rreq_len,
      PrimRead_bus_rdat_valid      => BusReadArbiterVec_inst_bsv_rdat_valid,
      PrimRead_bus_rdat_ready      => BusReadArbiterVec_inst_bsv_rdat_ready,
      PrimRead_bus_rdat_data       => BusReadArbiterVec_inst_bsv_rdat_data,
      PrimRead_bus_rdat_last       => BusReadArbiterVec_inst_bsv_rdat_last
    );
  PrimWrite_inst : PrimWrite
    generic map (
      BUS_ADDR_WIDTH => 64
    )
    port map (
      bcd_clk                       => bcd_clk,
      bcd_reset                     => bcd_reset,
      kcd_clk                       => kcd_clk,
      kcd_reset                     => kcd_reset,
      PrimWrite_number_valid        => PrimWrite_inst_PrimWrite_number_valid,
      PrimWrite_number_ready        => PrimWrite_inst_PrimWrite_number_ready,
      PrimWrite_number_dvalid       => PrimWrite_inst_PrimWrite_number_dvalid,
      PrimWrite_number_last         => PrimWrite_inst_PrimWrite_number_last,
      PrimWrite_number              => PrimWrite_inst_PrimWrite_number,
      PrimWrite_number_cmd_valid    => PrimWrite_inst_PrimWrite_number_cmd_valid,
      PrimWrite_number_cmd_ready    => PrimWrite_inst_PrimWrite_number_cmd_ready,
      PrimWrite_number_cmd_firstIdx => PrimWrite_inst_PrimWrite_number_cmd_firstIdx,
      PrimWrite_number_cmd_lastidx  => PrimWrite_inst_PrimWrite_number_cmd_lastidx,
      PrimWrite_number_cmd_ctrl     => PrimWrite_inst_PrimWrite_number_cmd_ctrl,
      PrimWrite_number_cmd_tag      => PrimWrite_inst_PrimWrite_number_cmd_tag,
      PrimWrite_number_unl_valid    => Kernel_inst_PrimWrite_number_unl_valid,
      PrimWrite_number_unl_ready    => Kernel_inst_PrimWrite_number_unl_ready,
      PrimWrite_number_unl_tag      => Kernel_inst_PrimWrite_number_unl_tag,
      PrimWrite_bus_wreq_valid      => BusWriteArbiterVec_inst_bsv_wreq_valid,
      PrimWrite_bus_wreq_ready      => BusWriteArbiterVec_inst_bsv_wreq_ready,
      PrimWrite_bus_wreq_addr       => BusWriteArbiterVec_inst_bsv_wreq_addr,
      PrimWrite_bus_wreq_len        => BusWriteArbiterVec_inst_bsv_wreq_len,
      PrimWrite_bus_wdat_valid      => BusWriteArbiterVec_inst_bsv_wdat_valid,
      PrimWrite_bus_wdat_ready      => BusWriteArbiterVec_inst_bsv_wdat_ready,
      PrimWrite_bus_wdat_data       => BusWriteArbiterVec_inst_bsv_wdat_data,
      PrimWrite_bus_wdat_strobe     => BusWriteArbiterVec_inst_bsv_wdat_strobe,
      PrimWrite_bus_wdat_last       => BusWriteArbiterVec_inst_bsv_wdat_last
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
      PrimRead_number_valid         => Kernel_inst_PrimRead_number_valid,
      PrimRead_number_ready         => Kernel_inst_PrimRead_number_ready,
      PrimRead_number_dvalid        => Kernel_inst_PrimRead_number_dvalid,
      PrimRead_number_last          => Kernel_inst_PrimRead_number_last,
      PrimRead_number               => Kernel_inst_PrimRead_number,
      PrimRead_number_cmd_valid     => PrimRead_inst_PrimRead_number_cmd_valid,
      PrimRead_number_cmd_ready     => PrimRead_inst_PrimRead_number_cmd_ready,
      PrimRead_number_cmd_firstIdx  => PrimRead_inst_PrimRead_number_cmd_firstIdx,
      PrimRead_number_cmd_lastidx   => PrimRead_inst_PrimRead_number_cmd_lastidx,
      PrimRead_number_cmd_ctrl      => PrimRead_inst_PrimRead_number_cmd_ctrl,
      PrimRead_number_cmd_tag       => PrimRead_inst_PrimRead_number_cmd_tag,
      PrimRead_number_unl_valid     => Kernel_inst_PrimRead_number_unl_valid,
      PrimRead_number_unl_ready     => Kernel_inst_PrimRead_number_unl_ready,
      PrimRead_number_unl_tag       => Kernel_inst_PrimRead_number_unl_tag,
      PrimWrite_number_valid        => PrimWrite_inst_PrimWrite_number_valid,
      PrimWrite_number_ready        => PrimWrite_inst_PrimWrite_number_ready,
      PrimWrite_number_dvalid       => PrimWrite_inst_PrimWrite_number_dvalid,
      PrimWrite_number_last         => PrimWrite_inst_PrimWrite_number_last,
      PrimWrite_number              => PrimWrite_inst_PrimWrite_number,
      PrimWrite_number_cmd_valid    => PrimWrite_inst_PrimWrite_number_cmd_valid,
      PrimWrite_number_cmd_ready    => PrimWrite_inst_PrimWrite_number_cmd_ready,
      PrimWrite_number_cmd_firstIdx => PrimWrite_inst_PrimWrite_number_cmd_firstIdx,
      PrimWrite_number_cmd_lastidx  => PrimWrite_inst_PrimWrite_number_cmd_lastidx,
      PrimWrite_number_cmd_ctrl     => PrimWrite_inst_PrimWrite_number_cmd_ctrl,
      PrimWrite_number_cmd_tag      => PrimWrite_inst_PrimWrite_number_cmd_tag,
      PrimWrite_number_unl_valid    => Kernel_inst_PrimWrite_number_unl_valid,
      PrimWrite_number_unl_ready    => Kernel_inst_PrimWrite_number_unl_ready,
      PrimWrite_number_unl_tag      => Kernel_inst_PrimWrite_number_unl_tag
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
      bsv_rreq_valid(0)           => BusReadArbiterVec_inst_bsv_rreq_valid,
      bsv_rreq_ready(0)           => BusReadArbiterVec_inst_bsv_rreq_ready,
      bsv_rreq_addr(63 downto 0)  => BusReadArbiterVec_inst_bsv_rreq_addr,
      bsv_rreq_len(7 downto 0)    => BusReadArbiterVec_inst_bsv_rreq_len,
      bsv_rdat_valid(0)           => BusReadArbiterVec_inst_bsv_rdat_valid,
      bsv_rdat_ready(0)           => BusReadArbiterVec_inst_bsv_rdat_ready,
      bsv_rdat_data(511 downto 0) => BusReadArbiterVec_inst_bsv_rdat_data,
      bsv_rdat_last(0)            => BusReadArbiterVec_inst_bsv_rdat_last
    );
  BusWriteArbiterVec_inst : BusWriteArbiterVec
    generic map (
      NUM_SLAVE_PORTS  => 1,
      BUS_ADDR_WIDTH   => 64,
      BUS_LEN_WIDTH    => 8,
      BUS_DATA_WIDTH   => 512,
      BUS_STROBE_WIDTH => 64,
      ARB_METHOD       => "ROUND-ROBIN",
      MAX_OUTSTANDING  => 4,
      RAM_CONFIG       => "",
      SLV_REQ_SLICES   => true,
      MST_REQ_SLICE    => true,
      MST_DAT_SLICE    => true,
      SLV_DAT_SLICES   => true
    )
    port map (
      bcd_clk                      => bcd_clk,
      bcd_reset                    => bcd_reset,
      mst_wreq_valid               => mst_wreq_valid,
      mst_wreq_ready               => mst_wreq_ready,
      mst_wreq_addr                => mst_wreq_addr,
      mst_wreq_len                 => mst_wreq_len,
      mst_wdat_valid               => mst_wdat_valid,
      mst_wdat_ready               => mst_wdat_ready,
      mst_wdat_data                => mst_wdat_data,
      mst_wdat_strobe              => mst_wdat_strobe,
      mst_wdat_last                => mst_wdat_last,
      bsv_wreq_valid(0)            => BusWriteArbiterVec_inst_bsv_wreq_valid,
      bsv_wreq_ready(0)            => BusWriteArbiterVec_inst_bsv_wreq_ready,
      bsv_wreq_addr(63 downto 0)   => BusWriteArbiterVec_inst_bsv_wreq_addr,
      bsv_wreq_len(7 downto 0)     => BusWriteArbiterVec_inst_bsv_wreq_len,
      bsv_wdat_valid(0)            => BusWriteArbiterVec_inst_bsv_wdat_valid,
      bsv_wdat_ready(0)            => BusWriteArbiterVec_inst_bsv_wdat_ready,
      bsv_wdat_data(511 downto 0)  => BusWriteArbiterVec_inst_bsv_wdat_data,
      bsv_wdat_strobe(63 downto 0) => BusWriteArbiterVec_inst_bsv_wdat_strobe,
      bsv_wdat_last(0)             => BusWriteArbiterVec_inst_bsv_wdat_last
    );
end architecture;
