library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.Arrow.all;
use work.Utils.all;

entity wrapper_tb is
  generic(
    BUS_DATA_WIDTH                             : natural := 32;
    BUS_ADDR_WIDTH                             : natural := 32;
    BUS_LEN_WIDTH                              : natural := 8;
    BUS_BURST_STEP_LEN                         : natural := 1;
    BUS_BURST_MAX_LEN                          : natural := 8;
    ---------------------------------------------------------------------------
    INDEX_WIDTH                                : natural := 32;
    ---------------------------------------------------------------------------
    NUM_ARROW_BUFFERS                          : natural := 0;
    NUM_REGS                                   : natural := 8;
    NUM_USER_REGS                              : natural := 2;
    REG_WIDTH                                  : natural := 32;
    ---------------------------------------------------------------------------
    TAG_WIDTH                                  : natural := 1
  );
end wrapper_tb;

architecture Behavioral of wrapper_tb is

  component test_wrapper is
    generic(
      BUS_DATA_WIDTH                            : natural;
      BUS_ADDR_WIDTH                            : natural;
      BUS_LEN_WIDTH                             : natural;
      BUS_BURST_STEP_LEN                        : natural;
      BUS_BURST_MAX_LEN                         : natural;
      -------------------------------------------------------------------------
      INDEX_WIDTH                               : natural;
      -------------------------------------------------------------------------
      NUM_ARROW_BUFFERS                         : natural;
      NUM_REGS                                  : natural;
      NUM_USER_REGS                             : natural;
      REG_WIDTH                                 : natural;
      -------------------------------------------------------------------------
      TAG_WIDTH                                 : natural
    );
    port(
      acc_clk                                   : in  std_logic;
      acc_reset                                 : in  std_logic;
      bus_clk                                   : in  std_logic;
      bus_reset                                 : in  std_logic;
      -------------------------------------------------------------------------
      mst_rreq_valid                            : out std_logic;
      mst_rreq_ready                            : in  std_logic;
      mst_rreq_addr                             : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
      mst_rreq_len                              : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
      ---------------------------------------------------------------------------
      mst_rdat_valid                            : in  std_logic;
      mst_rdat_ready                            : out std_logic;
      mst_rdat_data                             : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
      mst_rdat_last                             : in  std_logic;
      ---------------------------------------------------------------------------
      regs_in                                   : in  std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
      regs_out                                  : out std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
      regs_out_en                               : out std_logic_vector(NUM_REGS-1 downto 0)
    );
  end component;

  signal acc_clk                                : std_logic;
  signal acc_reset                              : std_logic;
  signal bus_clk                                : std_logic;
  signal bus_reset                              : std_logic;
                                                 
  signal mst_rreq_valid                         : std_logic;
  signal mst_rreq_ready                         : std_logic;
  signal mst_rreq_addr                          : std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
  signal mst_rreq_len                           : std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
                                                 
  signal mst_rdat_valid                         : std_logic;
  signal mst_rdat_ready                         : std_logic;
  signal mst_rdat_data                          : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
  signal mst_rdat_last                          : std_logic;
                                                 
  signal regs_in                                : std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
  signal regs_out                               : std_logic_vector(NUM_REGS*REG_WIDTH-1 downto 0);
  signal regs_out_en                            : std_logic_vector(NUM_REGS-1 downto 0);
  
  signal clock_stop : boolean := false;
begin
  
  clk_proc: process is
  begin
    if not clock_stop then
      acc_clk <= '1';
      bus_clk <= '1';
      wait for 5 ns;
      acc_clk <= '0';
      bus_clk <= '0';
      wait for 5 ns;
    else
      wait;
    end if;
  end process;

  reset_proc: process is
  begin
    acc_reset <= '1';
    bus_reset <= '1';
    wait for 50 ns;
    wait until rising_edge(acc_clk);
    acc_reset <= '0';
    bus_reset <= '0';
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
    SREC_FILE                   => "test.srec"
  )
  port map (
    clk                         => bus_clk,
    reset                       => bus_reset,
    rreq_valid                  => mst_rreq_valid,
    rreq_ready                  => mst_rreq_ready,
    rreq_addr                   => mst_rreq_addr,
    rreq_len                    => mst_rreq_len,
    rdat_valid                  => mst_rdat_valid,
    rdat_ready                  => mst_rdat_ready,
    rdat_data                   => mst_rdat_data,
    rdat_last                   => mst_rdat_last
  );
  
  test_wrapper_inst : test_wrapper
  generic map (
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH    ,
    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH    ,
    BUS_LEN_WIDTH               => BUS_LEN_WIDTH     ,
    BUS_BURST_STEP_LEN          => BUS_BURST_STEP_LEN,
    BUS_BURST_MAX_LEN           => BUS_BURST_MAX_LEN ,
    INDEX_WIDTH                 => INDEX_WIDTH       ,
    NUM_ARROW_BUFFERS           => NUM_ARROW_BUFFERS ,
    NUM_REGS                    => NUM_REGS          ,
    NUM_USER_REGS               => NUM_USER_REGS     ,
    REG_WIDTH                   => REG_WIDTH         ,
    TAG_WIDTH                   => TAG_WIDTH         
  )                             
  port map (                    
    acc_clk                     => acc_clk           ,
    acc_reset                   => acc_reset         ,
    bus_clk                     => bus_clk           ,
    bus_reset                   => bus_reset         ,
    mst_rreq_valid              => mst_rreq_valid    ,
    mst_rreq_ready              => mst_rreq_ready    ,
    mst_rreq_addr               => mst_rreq_addr     ,
    mst_rreq_len                => mst_rreq_len      ,
    mst_rdat_valid              => mst_rdat_valid    ,
    mst_rdat_ready              => mst_rdat_ready    ,
    mst_rdat_data               => mst_rdat_data     ,
    mst_rdat_last               => mst_rdat_last     ,
    regs_in                     => regs_in           ,
    regs_out                    => regs_out          ,
    regs_out_en                 => regs_out_en       
  );
  
end architecture;
