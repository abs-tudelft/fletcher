-- Copyright 2018-2019 Delft University of Technology
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
use ieee.std_logic_misc.all;

library work;
use work.Interconnect_pkg.all;
use work.UtilStr_pkg.all;
use work.UtilConv_pkg.all;

entity SimTop_tc is
  generic (
    -- Accelerator properties
    INDEX_WIDTH                 : natural := 32;
    TAG_WIDTH                   : natural := 1;

    -- Host bus properties
    BUS_ADDR_WIDTH              : natural := 64;
    BUS_DATA_WIDTH              : natural := 512;
    BUS_LEN_WIDTH               : natural := 8;
    BUS_BURST_MAX_LEN           : natural := 64;
    BUS_BURST_STEP_LEN          : natural := 1
  );
end SimTop_tc;

architecture Behavorial of SimTop_tc is

  -----------------------------------------------------------------------------
  -- Default wrapper component.
  -----------------------------------------------------------------------------
    component PrimMap_Mantle is
    generic (
      INDEX_WIDTH        : integer := 32;
      TAG_WIDTH          : integer := 1;
      BUS_ADDR_WIDTH     : integer := 64;
      BUS_DATA_WIDTH     : integer := 512;
      BUS_LEN_WIDTH      : integer := 8;
      BUS_BURST_STEP_LEN : integer := 1;
      BUS_BURST_MAX_LEN  : integer := 16
    );
    port (
      bcd_clk                   : in  std_logic;
      bcd_reset                 : in  std_logic;
      kcd_clk                   : in  std_logic;
      kcd_reset                 : in  std_logic;
      mmio_awvalid              : in  std_logic;
      mmio_awready              : out std_logic;
      mmio_awaddr               : in  std_logic_vector(31 downto 0);
      mmio_wvalid               : in  std_logic;
      mmio_wready               : out std_logic;
      mmio_wdata                : in  std_logic_vector(31 downto 0);
      mmio_wstrb                : in  std_logic_vector(3 downto 0);
      mmio_bvalid               : out std_logic;
      mmio_bready               : in  std_logic;
      mmio_bresp                : out std_logic_vector(1 downto 0);
      mmio_arvalid              : in  std_logic;
      mmio_arready              : out std_logic;
      mmio_araddr               : in  std_logic_vector(31 downto 0);
      mmio_rvalid               : out std_logic;
      mmio_rready               : in  std_logic;
      mmio_rdata                : out std_logic_vector(31 downto 0);
      mmio_rresp                : out std_logic_vector(1 downto 0);
      rd_mst_rreq_valid         : out std_logic;
      rd_mst_rreq_ready         : in  std_logic;
      rd_mst_rreq_addr          : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      rd_mst_rreq_len           : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      rd_mst_rdat_valid         : in  std_logic;
      rd_mst_rdat_ready         : out std_logic;
      rd_mst_rdat_data          : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      rd_mst_rdat_last          : in  std_logic;
      wr_mst_wreq_valid         : out std_logic;
      wr_mst_wreq_ready         : in  std_logic;
      wr_mst_wreq_addr          : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      wr_mst_wreq_len           : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      wr_mst_wdat_valid         : out std_logic;
      wr_mst_wdat_ready         : in  std_logic;
      wr_mst_wdat_data          : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      wr_mst_wdat_strobe        : out std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
      wr_mst_wdat_last          : out std_logic;
      ext_platform_complete_req : out std_logic;
      ext_platform_complete_ack : in  std_logic
    );
  end component;
  -----------------------------------------------------------------------------

  -- Fletcher defaults
  constant REG_CONTROL          : natural := 0;
  constant REG_STATUS           : natural := 1;
  constant REG_RETURN0          : natural := 2;
  constant REG_RETURN1          : natural := 3;

  constant CONTROL_CLEAR        : std_logic_vector(31 downto 0) := X"00000000";
  constant CONTROL_START        : std_logic_vector(31 downto 0) := X"00000001";
  constant CONTROL_STOP         : std_logic_vector(31 downto 0) := X"00000002";
  constant CONTROL_RESET        : std_logic_vector(31 downto 0) := X"00000004";

  constant STATUS_IDLE          : std_logic_vector(31 downto 0) := X"00000001";
  constant STATUS_BUSY          : std_logic_vector(31 downto 0) := X"00000002";
  constant STATUS_DONE          : std_logic_vector(31 downto 0) := X"00000004";

  -- Sim signals
  signal clock_stop             : boolean := false;

  -- Accelerator signals
  signal kcd_clk                : std_logic;
  signal kcd_reset              : std_logic;

  -- Fletcher bus signals
  signal bcd_clk                : std_logic;
  signal bcd_reset              : std_logic;

  -- External signals
  signal ext_platform_complete_req : std_logic;
  signal ext_platform_complete_ack : std_logic;

  -- MMIO signals
  signal mmio_awvalid           : std_logic := '0';
  signal mmio_awready           : std_logic := '0';
  signal mmio_awaddr            : std_logic_vector(32-1 downto 0);
  signal mmio_wvalid            : std_logic := '0';
  signal mmio_wready            : std_logic := '0';
  signal mmio_wdata             : std_logic_vector(32-1 downto 0);
  signal mmio_wstrb             : std_logic_vector(32/8-1 downto 0);
  signal mmio_bvalid            : std_logic := '0';
  signal mmio_bready            : std_logic := '0';
  signal mmio_bresp             : std_logic_vector(1 downto 0);
  signal mmio_arvalid           : std_logic := '0';
  signal mmio_arready           : std_logic := '0';
  signal mmio_araddr            : std_logic_vector(32-1 downto 0);
  signal mmio_rvalid            : std_logic := '0';
  signal mmio_rready            : std_logic := '0';
  signal mmio_rdata             : std_logic_vector(32-1 downto 0);
  signal mmio_rresp             : std_logic_vector(1 downto 0);

  -- Mmio signals to source in mmio procedures.
  type mmio_source_t is record
    awvalid           : std_logic;
    awaddr            : std_logic_vector(32-1 downto 0);
    wvalid            : std_logic;
    wdata             : std_logic_vector(32-1 downto 0);
    wstrb             : std_logic_vector(32/8-1 downto 0);
    bready            : std_logic;

    arvalid           : std_logic;
    araddr            : std_logic_vector(32-1 downto 0);
    rready            : std_logic;
  end record;

  -- Mmio signals to sink in mmio procedures
  type mmio_sink_t is record
    wready            : std_logic;

    awready           : std_logic;

    bvalid            : std_logic;
    bresp             : std_logic_vector(1 downto 0);

    arready           : std_logic;

    rvalid            : std_logic;
    rdata             : std_logic_vector(32-1 downto 0);
    rresp             : std_logic_vector(1 downto 0);
  end record;

  signal mmio_source : mmio_source_t;
  signal mmio_sink : mmio_sink_t;

  -- Memory interface signals
  signal bus_rreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_rreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_rreq_valid         : std_logic;
  signal bus_rreq_ready         : std_logic;
  signal bus_rdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_rdat_last          : std_logic;
  signal bus_rdat_valid         : std_logic;
  signal bus_rdat_ready         : std_logic;
  signal bus_wreq_addr          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal bus_wreq_len           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
  signal bus_wreq_valid         : std_logic;
  signal bus_wreq_ready         : std_logic;
  signal bus_wdat_data          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal bus_wdat_strobe        : std_logic_vector(BUS_DATA_WIDTH/8-1 downto 0);
  signal bus_wdat_last          : std_logic;
  signal bus_wdat_valid         : std_logic;
  signal bus_wdat_ready         : std_logic;

  procedure mmio_write32 (constant idx    : in  natural;
                          constant data   : in  std_logic_vector(31 downto 0);
                          signal   source : out mmio_source_t;
                          signal   sink   : in  mmio_sink_t;
                          signal   clk    : in  std_logic;
                          signal   reset  : in  std_logic)
  is
  begin
    -- Wait for reset
    loop
      exit when reset = '0';
      wait until rising_edge(clk);
    end loop;
    -- Address write channel
    source.awaddr <= slv(0 + (32/8)*idx, 32);
    source.awvalid <= '1';
    loop
      wait until rising_edge(clk);
      exit when sink.awready = '1';
    end loop;
    source.awvalid <= '0';
    source.awaddr <= (others => 'U');
    -- Write channel
    source.wdata <= data;
    source.wstrb <= X"F";
    source.wvalid <= '1';
    loop
      wait until rising_edge(clk);
      exit when sink.wready = '1';
    end loop;
    source.wvalid <= '0';
    source.wdata <= (others => 'U');
    source.wstrb <= (others => 'U');
    -- Write response channel.
    source.bready <= '1';
    loop
      wait until rising_edge(clk);
      exit when sink.bvalid = '1';
    end loop;
    source.bready <= '0';
  end procedure;

  procedure mmio_read32(constant idx    : in  natural;
                        variable data   : out std_logic_vector(31 downto 0);
                        signal   source : out mmio_source_t;
                        signal   sink   : in  mmio_sink_t;
                        signal   clk    : in  std_logic;
                        signal   reset  : in  std_logic)
  is
  begin
    -- Wait for reset
    loop
      exit when reset = '0';
      wait until rising_edge(clk);
    end loop;
    -- Address read channel
    source.araddr <= slv(0 + (32/8)*idx, 32);
    source.arvalid <= '1';
    loop
      wait until rising_edge(clk);
      exit when sink.arready = '1';
    end loop;
    source.arvalid <= '0';
    source.araddr <= (others => 'U');
    -- Read channel
    loop
      source.rready <= '1';
      wait until rising_edge(clk);
      if sink.rvalid = '1' then
        data := sink.rdata;
        exit;
      end if;
    end loop;
    source.rready <= '0';
  end procedure;


begin

  -- Connect to records for easier readibility downstream.
  mmio_awvalid <= mmio_source.awvalid;
  mmio_awaddr  <= mmio_source.awaddr;
  mmio_wvalid  <= mmio_source.wvalid;
  mmio_wdata   <= mmio_source.wdata;
  mmio_wstrb   <= mmio_source.wstrb;
  mmio_bready  <= mmio_source.bready;
  mmio_arvalid <= mmio_source.arvalid;
  mmio_araddr  <= mmio_source.araddr;
  mmio_rready  <= mmio_source.rready;

  mmio_sink.wready  <= mmio_wready;
  mmio_sink.awready <= mmio_awready;
  mmio_sink.bvalid  <= mmio_bvalid;
  mmio_sink.bresp   <= mmio_bresp;
  mmio_sink.arready <= mmio_arready;
  mmio_sink.rvalid  <= mmio_rvalid;
  mmio_sink.rdata   <= mmio_rdata;
  mmio_sink.rresp   <= mmio_rresp;


  -- Typical stimuli process:
  stimuli_proc : process is
    variable read_data        : std_logic_vector(31 downto 0) := X"DEADBEEF";
    variable read_data_masked : std_logic_vector(31 downto 0);
  begin
	-- Example of some communication with the platform. In this case,
	-- the platform is this testbench.
	ext_platform_complete_ack <= '0';

    mmio_source.awvalid <= '0';
    mmio_source.wvalid  <= '0';
    mmio_source.bready  <= '0';

    mmio_source.arvalid <= '0';
    mmio_source.rready  <= '0';

    wait until kcd_reset = '1' and bcd_reset = '1';

    -- 1. Reset the user core
    mmio_write32(REG_CONTROL, CONTROL_RESET, mmio_source, mmio_sink, bcd_clk, bcd_reset);

    -- 2. Write addresses of the arrow buffers in the SREC file.
    mmio_write32(8, X"00000000", mmio_source, mmio_sink, bcd_clk, bcd_reset); -- in number_values buffer address.
    mmio_write32(9, X"00000000", mmio_source, mmio_sink, bcd_clk, bcd_reset);
    mmio_write32(10, X"00000000", mmio_source, mmio_sink, bcd_clk, bcd_reset); -- out number_values buffer address.
    mmio_write32(11, X"00000000", mmio_source, mmio_sink, bcd_clk, bcd_reset);

    -- 3. Write recordbatch bounds.
    mmio_write32(4, X"00000000", mmio_source, mmio_sink, bcd_clk, bcd_reset); -- in first index.
    mmio_write32(5, X"00000004", mmio_source, mmio_sink, bcd_clk, bcd_reset); -- in last index.
    mmio_write32(6, X"00000000", mmio_source, mmio_sink, bcd_clk, bcd_reset); -- out first index.
    mmio_write32(7, X"00000000", mmio_source, mmio_sink, bcd_clk, bcd_reset); -- out last index.

    -- 4. Write any kernel-specific registers.

    -- 5. Start the kernel.
    mmio_write32(12, X"00000001", mmio_source, mmio_sink, bcd_clk, bcd_reset); -- Start profiling.
    mmio_write32(REG_CONTROL, CONTROL_START, mmio_source, mmio_sink, bcd_clk, bcd_reset);

    -- 6. Poll for completion
    loop
      -- Wait a bunch of cycles.
      for I in 0 to 8 loop
        wait until rising_edge(bcd_clk);
      end loop;

      -- Read the status register.
      mmio_read32(REG_STATUS, read_data, mmio_source, mmio_sink, bcd_clk, bcd_reset);

      -- Check if we're done.
      read_data_masked := read_data and STATUS_DONE;
      exit when read_data_masked = STATUS_DONE;
    end loop;

    mmio_write32(12, X"00000000", mmio_source, mmio_sink, bcd_clk, bcd_reset); -- Stop profiling.

    -- 7. Read return register.
    mmio_read32(REG_RETURN0, read_data, mmio_source, mmio_sink, bcd_clk, bcd_reset);
    println("Return register 0: " & slvToHex(read_data));
    mmio_read32(REG_RETURN1, read_data, mmio_source, mmio_sink, bcd_clk, bcd_reset);
    println("Return register 1: " & slvToHex(read_data));

	-- Example of some communication with the platform. In this case,
	-- the platform is this testbench.
    wait until ext_platform_complete_req = '1';
    for I in 0 to 32 loop
        wait until rising_edge(bcd_clk);
	end loop;
    ext_platform_complete_ack <= '1';

    -- 9. Finish and stop simulation.
    report "Stimuli done.";
    clock_stop <= true;

    wait;
  end process;

  clk_proc: process is
  begin
    if not clock_stop then
      kcd_clk <= '1';
      bcd_clk <= '1';
      wait for 5 ns;
      kcd_clk <= '0';
      bcd_clk <= '0';
      wait for 5 ns;
    else
      wait;
    end if;
  end process;

  reset_proc: process is
  begin
    kcd_reset <= '1';
    bcd_reset <= '1';
    wait for 50 ns;
    wait until rising_edge(kcd_clk);
    kcd_reset <= '0';
    bcd_reset <= '0';
    wait;
  end process;

  rmem_inst: BusReadSlaveMock
  generic map (
    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,
    BUS_LEN_WIDTH               => BUS_LEN_WIDTH,
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
    SEED                        => 1337,
    RANDOM_REQUEST_TIMING       => false,
    RANDOM_RESPONSE_TIMING      => false,
    SREC_FILE                   => "/home/johan/workspace/tud/fletcher/examples/map/hardware/batch.srec"
  )
  port map (
    clk                         => bcd_clk,
    reset                       => bcd_reset,
    rreq_valid                  => bus_rreq_valid,
    rreq_ready                  => bus_rreq_ready,
    rreq_addr                   => bus_rreq_addr,
    rreq_len                    => bus_rreq_len,
    rdat_valid                  => bus_rdat_valid,
    rdat_ready                  => bus_rdat_ready,
    rdat_data                   => bus_rdat_data,
    rdat_last                   => bus_rdat_last
  );


  wmem_inst: BusWriteSlaveMock
  generic map (
    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,
    BUS_LEN_WIDTH               => BUS_LEN_WIDTH,
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
    SEED                        => 1337,
    RANDOM_REQUEST_TIMING       => false,
    RANDOM_RESPONSE_TIMING      => false,
    SREC_FILE                   => ""
  )
  port map (
    clk                         => bcd_clk,
    reset                       => bcd_reset,
    wreq_valid                  => bus_wreq_valid,
    wreq_ready                  => bus_wreq_ready,
    wreq_addr                   => bus_wreq_addr,
    wreq_len                    => bus_wreq_len,
    wdat_valid                  => bus_wdat_valid,
    wdat_ready                  => bus_wdat_ready,
    wdat_data                   => bus_wdat_data,
    wdat_strobe                 => bus_wdat_strobe,
    wdat_last                   => bus_wdat_last
  );


  -----------------------------------------------------------------------------
  -- Fletcher generated wrapper
  -----------------------------------------------------------------------------
  PrimMap_Mantle_inst : PrimMap_Mantle
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      INDEX_WIDTH               => INDEX_WIDTH,
      TAG_WIDTH                 => TAG_WIDTH
    )
    port map (
      kcd_clk                   => kcd_clk,
      kcd_reset                 => kcd_reset,
      bcd_clk                   => bcd_clk,
      bcd_reset                 => bcd_reset,
      ext_platform_complete_req => ext_platform_complete_req,
      ext_platform_complete_ack => ext_platform_complete_ack,

      rd_mst_rreq_valid         => bus_rreq_valid,
      rd_mst_rreq_ready         => bus_rreq_ready,
      rd_mst_rreq_addr          => bus_rreq_addr,
      rd_mst_rreq_len           => bus_rreq_len,
      rd_mst_rdat_valid         => bus_rdat_valid,
      rd_mst_rdat_ready         => bus_rdat_ready,
      rd_mst_rdat_data          => bus_rdat_data,
      rd_mst_rdat_last          => bus_rdat_last,

      wr_mst_wreq_valid         => bus_wreq_valid,
      wr_mst_wreq_ready         => bus_wreq_ready,
      wr_mst_wreq_addr          => bus_wreq_addr,
      wr_mst_wreq_len           => bus_wreq_len,
      wr_mst_wdat_valid         => bus_wdat_valid,
      wr_mst_wdat_ready         => bus_wdat_ready,
      wr_mst_wdat_data          => bus_wdat_data,
      wr_mst_wdat_strobe        => bus_wdat_strobe,
      wr_mst_wdat_last          => bus_wdat_last,
      mmio_awvalid              => mmio_awvalid,
      mmio_awready              => mmio_awready,
      mmio_awaddr               => mmio_awaddr,
      mmio_wvalid               => mmio_wvalid,
      mmio_wready               => mmio_wready,
      mmio_wdata                => mmio_wdata,
      mmio_wstrb                => mmio_wstrb,
      mmio_bvalid               => mmio_bvalid,
      mmio_bready               => mmio_bready,
      mmio_bresp                => mmio_bresp,
      mmio_arvalid              => mmio_arvalid,
      mmio_arready              => mmio_arready,
      mmio_araddr               => mmio_araddr,
      mmio_rvalid               => mmio_rvalid,
      mmio_rready               => mmio_rready,
      mmio_rdata                => mmio_rdata,
      mmio_rresp                => mmio_rresp
    );

end architecture;
