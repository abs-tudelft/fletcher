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
use ieee.std_logic_misc.all;

library work;
use work.Streams.all;
use work.Utils.all;
use work.Arrow.all;

use work.SimUtils.all;

use work.arrow_regexp_pkg.all;

-- This UserCore matches regular expressions stored in a string column
-- in the Apache Arrow format.
--
-- In our programming model it is required to have an interface to a 
-- memory (host memory, wether or not copied, as long as it retains the
-- Arrow format) and a slave interface for the memory mapped registers.
--
-- This unit uses AXI interconnect to do both, where the slave interface
-- is AXI4-lite and the master interface an AXI4 full interface. For high
-- throughput, the master interface should support bursts.

entity arrow_regexp is
  generic (    
    -- Number of Regexp units. Must be a natural multiple of 2
    CORES                       : natural :=  16;
    
    -- Host bus properties
    BUS_ADDR_WIDTH              : natural :=  64;
    BUS_DATA_WIDTH              : natural := 512;

    -- MMIO bus properties
    SLV_BUS_ADDR_WIDTH          : natural :=  32;
    SLV_BUS_DATA_WIDTH          : natural :=  32
    
    -- (Generic defaults are set for SystemVerilog compatibility)
  );

  port (
    clk                         : in  std_logic;
    reset_n                     : in  std_logic;

    ---------------------------------------------------------------------------
    -- AXI4 master
    --
    -- To be connected to the DDR controllers (through CL_DMA_PCIS_SLV)
    ---------------------------------------------------------------------------
    -- Read address channel
    m_axi_araddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    m_axi_arlen                 : out std_logic_vector(7 downto 0);
    m_axi_arvalid               : out std_logic;
    m_axi_arready               : in  std_logic;
    m_axi_arsize                : out std_logic_vector(2 downto 0);

    -- Read data channel
    m_axi_rdata                 : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    m_axi_rresp                 : in  std_logic_vector(1 downto 0);
    m_axi_rlast                 : in  std_logic;
    m_axi_rvalid                : in  std_logic;
    m_axi_rready                : out std_logic;

    ---------------------------------------------------------------------------
    -- AXI4-lite slave
    --
    -- To be connected to "sh_cl_sda" a.k.a. "AppPF Bar 1"
    ---------------------------------------------------------------------------
    -- Write adress
    s_axi_awvalid               : in std_logic;
    s_axi_awready               : out std_logic;
    s_axi_awaddr                : in std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);

    -- Write data
    s_axi_wvalid                : in std_logic;
    s_axi_wready                : out std_logic;
    s_axi_wdata                 : in std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
    s_axi_wstrb                 : in std_logic_vector((SLV_BUS_DATA_WIDTH/8)-1 downto 0);

    -- Write response
    s_axi_bvalid                : out std_logic;
    s_axi_bready                : in std_logic;
    s_axi_bresp                 : out std_logic_vector(1 downto 0);

    -- Read address
    s_axi_arvalid               : in std_logic;
    s_axi_arready               : out std_logic;
    s_axi_araddr                : in std_logic_vector(SLV_BUS_ADDR_WIDTH-1 downto 0);

    -- Read data
    s_axi_rvalid                : out std_logic;
    s_axi_rready                : in std_logic;
    s_axi_rdata                 : out std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
    s_axi_rresp                 : out std_logic_vector(1 downto 0)
  );
end entity arrow_regexp;

architecture rtl of arrow_regexp is

  signal reset                  : std_logic;

  -- Bottom buses
  constant BB                   : natural := 16;
   
  -- Number of regexes
  constant NUM_REGEX            : natural := 16;
  
  -----------------------------------------------------------------------------
  -- Memory Mapped Input/Output
  -----------------------------------------------------------------------------
 
  -----------------------------------
  -- Fletcher registers
  ----------------------------------- Default registers
  --   1 status (uint64)        =  2
  --   1 control (uint64)       =  2
  --   1 return (uint64)        =  2
  ----------------------------------- Buffer addresses
  --   1 index buf address      =  2
  --   1 data  buf address      =  2
  ----------------------------------- Custom registers
  --  16 first & last idx       = 32
  --  16 regex results          = 16
  -----------------------------------
  -- Total:                       58 regs  
  constant NUM_FLETCHER_REGS    : natural := 58;
       
  -- The LSB index in the slave address
  constant SLV_ADDR_LSB        : natural := log2floor(SLV_BUS_DATA_WIDTH/4) - 1;
  
  -- The MSB index in the slave address
  constant SLV_ADDR_MSB         : natural := SLV_ADDR_LSB + log2floor(NUM_FLETCHER_REGS);
    
  -- Fletcher register offsets
  constant REG_STATUS_HI        : natural := 0;
  constant REG_STATUS_LO        : natural := 1;
  
    -- The offsets of the bits to signal busy and done for each of the units
    constant STATUS_BUSY_OFFSET   : natural := 0;
    constant STATUS_DONE_OFFSET   : natural := CORES;
                                
  constant REG_CONTROL_HI       : natural := 2;
  constant REG_CONTROL_LO       : natural := 3;
  
    -- The offsets of the bits to signal start and reset to each of the units
    constant CONTROL_START_OFFSET : natural := 0;
    constant CONTROL_RESET_OFFSET : natural := CORES;
  
  -- Return register
  constant REG_RETURN_HI        : natural := 4;
  constant REG_RETURN_LO        : natural := 5;
  
  -- Offset buffer address
  constant REG_OFF_ADDR_HI      : natural := 6;
  constant REG_OFF_ADDR_LO      : natural := 7;
  
  -- Data buffer address
  constant REG_UTF8_ADDR_HI     : natural := 8;
  constant REG_UTF8_ADDR_LO     : natural := 9;

  -- Register offsets to indices for each RegExp unit to work on
  constant REG_FIRST_IDX  		  : natural := 10;
  constant REG_LAST_IDX   		  : natural := 26;
  
  -- Register offset for each RegExp unit to put its result
  constant REG_RESULT       	  : natural := 42;

  -- Memory mapped register file
  type mm_regs_t is array (0 to NUM_FLETCHER_REGS-1) of std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
  signal mm_regs                : mm_regs_t;

  -- Helper signals to do handshaking on the slave port
  signal read_address           : natural range 0 to NUM_FLETCHER_REGS-1;
  signal write_valid            : std_logic;
  signal read_valid             : std_logic := '0';
  signal write_processed        : std_logic;

  -----------------------------------------------------------------------------
  -- AXI Interconnect Master Ports
  -----------------------------------------------------------------------------
  type bus_bottom_array_t       is array (0 to BB-1) of bus_bottom_t;
  type axi_mid_array_t          is array (0 to BB-1) of axi_mid_t;
  
  signal bus_bottom_array       : bus_bottom_array_t;
  signal axi_mid_array          : axi_mid_array_t;
  signal axi_top                : axi_top_t;

  -----------------------------------------------------------------------------
  -- Registers
  -----------------------------------------------------------------------------
  type reg_array_t is array (0 to CORES-1) of std_logic_vector(31 downto 0);

  signal reg_array_firstidx     : reg_array_t;
  signal reg_array_lastidx      : reg_array_t;
  signal reg_array_off_hi       : reg_array_t;
  signal reg_array_off_lo       : reg_array_t;
  signal reg_array_utf8_hi      : reg_array_t;
  signal reg_array_utf8_lo      : reg_array_t;

  signal bit_array_control_reset: std_logic_vector(CORES-1 downto 0);
  signal bit_array_control_start: std_logic_vector(CORES-1 downto 0);
  signal bit_array_reset_start  : std_logic_vector(CORES-1 downto 0);
  signal bit_array_busy         : std_logic_vector(CORES-1 downto 0);
  signal bit_array_done         : std_logic_vector(CORES-1 downto 0);
  
  -----------------------------------------------------------------------------
  -- Result adder tree
  -----------------------------------------------------------------------------
  
  type result_conv_t is array(0 to CORES-1) of std_logic_vector(NUM_REGEX*32-1 downto 0);
  signal result_conv            : result_conv_t;
  
  type result_array_t is array (0 to CORES-1) of std_logic_vector(31 downto 0);
  type regex_result_array_t is array (0 to NUM_REGEX-1) of result_array_t;
  signal result_array           : regex_result_array_t;
  
  -- The width of the innermost array is 2^log2ceil(cores) instead of cores-1
  -- such that even no. cores is possible vs. only powers of 2 no. cores.
  type result_add_t is array (0 to 2**log2ceil(CORES)) of unsigned(31 downto 0);
  
  type result_add_tree_t is array (0 to log2ceil(CORES)) of result_add_t;
  type regex_result_add_tree_t is array(0 to NUM_REGEX-1) of result_add_tree_t;
  
  signal result_add             : regex_result_add_tree_t;
  
begin

  reset                         <= '1' when reset_n = '0' else '0';

  -----------------------------------------------------------------------------
  -- Memory Mapped Slave Registers
  -----------------------------------------------------------------------------
  write_valid                   <= s_axi_awvalid and s_axi_wvalid and not write_processed;

  s_axi_awready                 <= write_valid;
  s_axi_wready                  <= write_valid;
  s_axi_bresp                   <= "00"; -- Always OK
  s_axi_bvalid                  <= write_processed;

  s_axi_arready                 <= not read_valid;

  -- Mux for reading
  -- Might want to insert a reg slice before getting it to the ColumnReaders
  -- and UserCore
  s_axi_rdata                   <= mm_regs(read_address);
  s_axi_rvalid                  <= read_valid;
  s_axi_rresp                   <= "00"; -- Always OK

  -- Reads
  read_from_regs: process(clk) is
    variable address : natural range 0 to NUM_FLETCHER_REGS-1;
  begin
    address                     := int(s_axi_araddr(SLV_ADDR_MSB downto SLV_ADDR_LSB));

    if rising_edge(clk) then
      if reset_n = '0' then
        read_valid              <= '0';
      else
        if s_axi_arvalid = '1' and read_valid = '0' then
          dumpStdOut("Read request from MMIO: " & integer'image(address) & " value " & integer'image(int(mm_regs(address))));
          read_address          <= address;
          read_valid            <= '1';
        elsif s_axi_rready = '1' then
          read_valid            <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Writes
  
  -- TODO: For registers that are split up over two addresses, this is not
  -- very pretty. There should probably be some synchronization mechanism
  -- to only apply the write after both HI and LO addresses have been
  -- written.
  -- Also we don't care about byte enables at the moment.
  write_to_regs: process(clk) is
    variable address            : natural range 0 to NUM_FLETCHER_REGS;
  begin
   
    address                     := int(s_axi_awaddr(SLV_ADDR_MSB downto SLV_ADDR_LSB));

    if rising_edge(clk) then
      if write_valid = '1' then
        dumpStdOut("Write to MMIO: " & integer'image(address));
     
        case address is
          -- Read only addresses do nothing
          when REG_STATUS_HI  =>
          when REG_STATUS_LO  =>
          when REG_RETURN_HI  =>
          when REG_RETURN_LO  =>
          when REG_RESULT to REG_RESULT + NUM_REGEX - 1 =>
          -- All others are writeable:
          when others         =>
            mm_regs(address)  <= s_axi_wdata;
        end case;
      else
        -- Control register is also resettable by individual units
        for I in 0 to CORES-1 loop
          if bit_array_reset_start(I) = '1' then
            mm_regs(REG_CONTROL_LO)(CONTROL_START_OFFSET + I) <= '0';
          end if;
        end loop;
      end if;
     
      -- Read only register values:
      
      -- Status registers
      mm_regs(REG_STATUS_HI) <= (others => '0');
      
      if CORES /= 16 then
        mm_regs(REG_STATUS_LO)(SLV_BUS_DATA_WIDTH-1 downto STATUS_DONE_OFFSET + CORES) <= (others => '0');
      end if;
      
      mm_regs(REG_STATUS_LO)(STATUS_BUSY_OFFSET + CORES - 1 downto STATUS_BUSY_OFFSET) <= bit_array_busy;
      mm_regs(REG_STATUS_LO)(STATUS_DONE_OFFSET + CORES - 1 downto STATUS_DONE_OFFSET) <= bit_array_done;
      
      -- Return registers
      mm_regs(REG_RETURN_HI) <= (others => '0');
      mm_regs(REG_RETURN_LO) <= slv(result_add(0)(0)(0));
      
      -- Result registers
      for R in 0 to NUM_REGEX-1 loop
        mm_regs(REG_RESULT + R) <= slv(result_add(R)(0)(0));
      end loop;
      
      if reset_n = '0' then
        mm_regs(REG_CONTROL_LO)    <= (others => '0');
        mm_regs(REG_CONTROL_HI)    <= (others => '0');
      end if;
    end if;
  end process;

  -- Write response
  write_resp_proc: process(clk) is
  begin
    if rising_edge(clk) then
      if reset_n = '0' then
        write_processed <= '0';
      else
        if write_valid = '1' then
          write_processed <= '1';
        elsif s_axi_bready = '1' then
          write_processed <= '0';
        end if;
      end if;
    end if;
  end process;

  -- Some registers between paths to units
  reg_settings: process(clk)
  begin
    if rising_edge(clk) then
      -- Control bits
      bit_array_control_start <= mm_regs(REG_CONTROL_LO)(CONTROL_START_OFFSET + CORES -1 downto CONTROL_START_OFFSET);
      bit_array_control_reset <= mm_regs(REG_CONTROL_LO)(CONTROL_RESET_OFFSET + CORES -1 downto CONTROL_RESET_OFFSET);

      -- Registers
      reg_gen: for I in 0 to CORES-1 loop
        -- Local
        reg_array_firstidx(I)       <= mm_regs(REG_FIRST_IDX + I);
        reg_array_lastidx(I)        <= mm_regs(REG_LAST_IDX + I);
        -- Global
        reg_array_off_hi (I)        <= mm_regs(REG_OFF_ADDR_HI);
        reg_array_off_lo (I)        <= mm_regs(REG_OFF_ADDR_LO);
        reg_array_utf8_hi(I)        <= mm_regs(REG_UTF8_ADDR_HI);
        reg_array_utf8_lo(I)        <= mm_regs(REG_UTF8_ADDR_LO);
      end loop;
    end if;
  end process;

  -----------------------------------------------------------------------------
  -- Master
  -----------------------------------------------------------------------------
  -- Read address channel
  axi_top.arready               <= m_axi_arready;
    
  m_axi_arvalid                 <= axi_top.arvalid;
  m_axi_araddr                  <= axi_top.araddr;
    
  m_axi_arlen                   <= axi_top.arlen;
    
  m_axi_arsize                  <= "110"; --6 for 2^6*8 bits = 512 bits
    
  -- Read data channel  
  m_axi_rready                  <= axi_top.rready ;
    
  axi_top.rvalid                <= m_axi_rvalid;    
  axi_top.rdata                 <= m_axi_rdata;
  axi_top.rresp                 <= m_axi_rresp;
  axi_top.rlast                 <= m_axi_rlast;
  
  regex_add_tree: for R in 0 to NUM_REGEX-1 generate
    -----------------------------------------------------------------------------
    -- Adder tree assuming CORES is even
    -----------------------------------------------------------------------------
    -- TODO: somehow make sure that when the result regs are read that there is 
    -- nothing left in the adder tree pipeline.
    process(clk) is
    begin
      if rising_edge(clk) then
        -- Top level
        for I in 0 to CORES-1 loop
          result_add(R)(log2ceil(CORES))(I) <= u(result_array(R)(I));
        end loop;
        
        -- Other levels
        for L in log2ceil(CORES)-1 downto 0 loop -- 3,2,1,0
          for I in 0 to (2**L)-1 loop -- 8,4,2,1
            result_add(R)(L)(I) <= result_add(R)(L+1)(2*I) + result_add(R)(L+1)(2*I+1);
          end loop;
        end loop;
      end if;
    end process;
  end generate;
   
  -----------------------------------------------------------------------------
  -- Bottom layer
  -----------------------------------------------------------------------------
  bottom_regexp_gen: for I in 0 to CORES-1 generate
  
    -- Convert axi read address channel and read response channel
    -- Scales "len" and "size" according to the master data width
    -- and converts the Fletcher bus "len" to AXI bus "len"
    read_converter_inst: axi_read_converter generic map (
      ADDR_WIDTH                => BUS_ADDR_WIDTH,
      ID_WIDTH                  => 1,
      MASTER_DATA_WIDTH         => BUS_DATA_WIDTH,
      MASTER_LEN_WIDTH          => 8,
      SLAVE_DATA_WIDTH          => BOTTOM_DATA_WIDTH,
      SLAVE_LEN_WIDTH           => BOTTOM_LEN_WIDTH,
      SLAVE_MAX_BURST           => BOTTOM_BURST_MAX_LEN,
      ENABLE_FIFO               => BOTTOM_ENABLE_FIFO
    )
    port map (                  
      clk                       => clk,
      reset_n                   => reset_n,
      s_bus_req_addr            => bus_bottom_array(I).req_addr,
      s_bus_req_len             => bus_bottom_array(I).req_len,
      s_bus_req_valid           => bus_bottom_array(I).req_valid,
      s_bus_req_ready           => bus_bottom_array(I).req_ready,
      s_bus_rsp_data            => bus_bottom_array(I).rsp_data,
      s_bus_rsp_last            => bus_bottom_array(I).rsp_last,
      s_bus_rsp_valid           => bus_bottom_array(I).rsp_valid,
      s_bus_rsp_ready           => bus_bottom_array(I).rsp_ready,
      m_axi_araddr              => axi_mid_array(I).araddr,
      m_axi_arlen               => axi_mid_array(I).arlen,
      m_axi_arvalid             => axi_mid_array(I).arvalid,
      m_axi_arready             => axi_mid_array(I).arready,
      m_axi_arsize              => axi_mid_array(I).arsize,
      m_axi_rdata               => axi_mid_array(I).rdata,
      m_axi_rlast               => axi_mid_array(I).rlast,
      m_axi_rvalid              => axi_mid_array(I).rvalid,
      m_axi_rready              => axi_mid_array(I).rready
    );

    -- utf8 regular expression matcher generation
    regexp_inst: arrow_regexp_unit generic map (
      NUM_REGEX                 => NUM_REGEX,
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_DATA_WIDTH            => BOTTOM_DATA_WIDTH,
      BUS_LEN_WIDTH             => BOTTOM_LEN_WIDTH,
      BUS_BURST_STEP_LEN        => BOTTOM_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BOTTOM_BURST_MAX_LEN,
      REG_WIDTH                 => 32
    ) port map (
      clk                       => clk,
      reset_n                   => reset_n,
      
      control_reset             => bit_array_control_reset(I),
      control_start             => bit_array_control_start(I),
      reset_start               => bit_array_reset_start  (I),
      busy                      => bit_array_busy         (I),
      done                      => bit_array_done         (I),
      
      firstidx                  => reg_array_firstidx     (I),
      lastidx                   => reg_array_lastidx      (I),
      off_hi                    => reg_array_off_hi       (I),
      off_lo                    => reg_array_off_lo       (I),
      utf8_hi                   => reg_array_utf8_hi      (I),
      utf8_lo                   => reg_array_utf8_lo      (I),
      
      matches                   => result_conv            (I),
      
      bus_req_addr              => bus_bottom_array(I).req_addr ,
      bus_req_len               => bus_bottom_array(I).req_len  ,
      bus_req_valid             => bus_bottom_array(I).req_valid,
      bus_req_ready             => bus_bottom_array(I).req_ready,
      bus_rsp_data              => bus_bottom_array(I).rsp_data  ,
      bus_rsp_resp              => bus_bottom_array(I).rsp_resp  ,
      bus_rsp_last              => bus_bottom_array(I).rsp_last  ,
      bus_rsp_valid             => bus_bottom_array(I).rsp_valid ,
      bus_rsp_ready             => bus_bottom_array(I).rsp_ready
    );   
    
    -- Pass through result to right result_array:
    result_conv_gen: for R in 0 to NUM_REGEX-1 generate
      result_array(R)(I) <= result_conv(I)(32*(R+1)-1 downto (32*R));
    end generate;
  end generate;
  
  -- Tie off unused ports, if any
  unused_gen: for I in CORES to BB-1 generate 
    axi_mid_array(I).araddr     <= (others => '0');
    axi_mid_array(I).arlen      <= (others => '0');
    axi_mid_array(I).arvalid    <= '0';
    axi_mid_array(I).arsize     <= (others => '0');
    axi_mid_array(I).rready     <= '0';
    axi_mid_array(I).aclk       <= clk;
  end generate;

  -----------------------------------------------------------------------------
  -- Mid layer interconnect generation
  -----------------------------------------------------------------------------
  -- Interconnect
  
  mid_interconnect: BusArbiter generic map (
    BUS_ADDR_WIDTH              => BUS_ADDR_WIDTH,
    BUS_LEN_WIDTH               => 8,
    BUS_DATA_WIDTH              => BUS_DATA_WIDTH,
    NUM_MASTERS                 => CORES,
    ARB_METHOD                  => "ROUND-ROBIN",
    MAX_OUTSTANDING             => 32,
    RAM_CONFIG                  => "",
    REQ_IN_SLICES               => false,
    REQ_OUT_SLICE               => false,
    RESP_IN_SLICE               => false,    
    RESP_OUT_SLICES             => false
  )
  port map (
    clk                         => clk,
    reset                       => reset,
    slv_req_valid               => axi_top.arvalid,
    slv_req_ready               => axi_top.arready,
    slv_req_addr                => axi_top.araddr,
    slv_req_len                 => axi_top.arlen,
    slv_resp_valid              => axi_top.rvalid,
    slv_resp_ready              => axi_top.rready,
    slv_resp_data               => axi_top.rdata,
    slv_resp_last               => axi_top.rlast,
    bm0_req_valid               => axi_mid_array(0 ).arvalid,
    bm0_req_ready               => axi_mid_array(0 ).arready,
    bm0_req_addr                => axi_mid_array(0 ).araddr,
    bm0_req_len                 => axi_mid_array(0 ).arlen,
    bm0_resp_valid              => axi_mid_array(0 ).rvalid,
    bm0_resp_ready              => axi_mid_array(0 ).rready,
    bm0_resp_data               => axi_mid_array(0 ).rdata,
    bm0_resp_last               => axi_mid_array(0 ).rlast,
    bm1_req_valid               => axi_mid_array(1 ).arvalid,
    bm1_req_ready               => axi_mid_array(1 ).arready,
    bm1_req_addr                => axi_mid_array(1 ).araddr,
    bm1_req_len                 => axi_mid_array(1 ).arlen,
    bm1_resp_valid              => axi_mid_array(1 ).rvalid,
    bm1_resp_ready              => axi_mid_array(1 ).rready,
    bm1_resp_data               => axi_mid_array(1 ).rdata,
    bm1_resp_last               => axi_mid_array(1 ).rlast,
    bm2_req_valid               => axi_mid_array(2 ).arvalid,
    bm2_req_ready               => axi_mid_array(2 ).arready,
    bm2_req_addr                => axi_mid_array(2 ).araddr,
    bm2_req_len                 => axi_mid_array(2 ).arlen,
    bm2_resp_valid              => axi_mid_array(2 ).rvalid,
    bm2_resp_ready              => axi_mid_array(2 ).rready,
    bm2_resp_data               => axi_mid_array(2 ).rdata,
    bm2_resp_last               => axi_mid_array(2 ).rlast,
    bm3_req_valid               => axi_mid_array(3 ).arvalid,
    bm3_req_ready               => axi_mid_array(3 ).arready,
    bm3_req_addr                => axi_mid_array(3 ).araddr,
    bm3_req_len                 => axi_mid_array(3 ).arlen,
    bm3_resp_valid              => axi_mid_array(3 ).rvalid,
    bm3_resp_ready              => axi_mid_array(3 ).rready,
    bm3_resp_data               => axi_mid_array(3 ).rdata,
    bm3_resp_last               => axi_mid_array(3 ).rlast,
    bm4_req_valid               => axi_mid_array(4 ).arvalid,
    bm4_req_ready               => axi_mid_array(4 ).arready,
    bm4_req_addr                => axi_mid_array(4 ).araddr,
    bm4_req_len                 => axi_mid_array(4 ).arlen,
    bm4_resp_valid              => axi_mid_array(4 ).rvalid,
    bm4_resp_ready              => axi_mid_array(4 ).rready,
    bm4_resp_data               => axi_mid_array(4 ).rdata,
    bm4_resp_last               => axi_mid_array(4 ).rlast,
    bm5_req_valid               => axi_mid_array(5 ).arvalid,
    bm5_req_ready               => axi_mid_array(5 ).arready,
    bm5_req_addr                => axi_mid_array(5 ).araddr,
    bm5_req_len                 => axi_mid_array(5 ).arlen,
    bm5_resp_valid              => axi_mid_array(5 ).rvalid,
    bm5_resp_ready              => axi_mid_array(5 ).rready,
    bm5_resp_data               => axi_mid_array(5 ).rdata,
    bm5_resp_last               => axi_mid_array(5 ).rlast,
    bm6_req_valid               => axi_mid_array(6 ).arvalid,
    bm6_req_ready               => axi_mid_array(6 ).arready,
    bm6_req_addr                => axi_mid_array(6 ).araddr,
    bm6_req_len                 => axi_mid_array(6 ).arlen,
    bm6_resp_valid              => axi_mid_array(6 ).rvalid,
    bm6_resp_ready              => axi_mid_array(6 ).rready,
    bm6_resp_data               => axi_mid_array(6 ).rdata,
    bm6_resp_last               => axi_mid_array(6 ).rlast,
    bm7_req_valid               => axi_mid_array(7 ).arvalid,
    bm7_req_ready               => axi_mid_array(7 ).arready,
    bm7_req_addr                => axi_mid_array(7 ).araddr,
    bm7_req_len                 => axi_mid_array(7 ).arlen,
    bm7_resp_valid              => axi_mid_array(7 ).rvalid,
    bm7_resp_ready              => axi_mid_array(7 ).rready,
    bm7_resp_data               => axi_mid_array(7 ).rdata,
    bm7_resp_last               => axi_mid_array(7 ).rlast,
    bm8_req_valid               => axi_mid_array(8 ).arvalid,
    bm8_req_ready               => axi_mid_array(8 ).arready,
    bm8_req_addr                => axi_mid_array(8 ).araddr,
    bm8_req_len                 => axi_mid_array(8 ).arlen,
    bm8_resp_valid              => axi_mid_array(8 ).rvalid,
    bm8_resp_ready              => axi_mid_array(8 ).rready,
    bm8_resp_data               => axi_mid_array(8 ).rdata,
    bm8_resp_last               => axi_mid_array(8 ).rlast,
    bm9_req_valid               => axi_mid_array(9 ).arvalid,
    bm9_req_ready               => axi_mid_array(9 ).arready,
    bm9_req_addr                => axi_mid_array(9 ).araddr,
    bm9_req_len                 => axi_mid_array(9 ).arlen,
    bm9_resp_valid              => axi_mid_array(9 ).rvalid,
    bm9_resp_ready              => axi_mid_array(9 ).rready,
    bm9_resp_data               => axi_mid_array(9 ).rdata,
    bm9_resp_last               => axi_mid_array(9 ).rlast,
    bm10_req_valid              => axi_mid_array(10).arvalid,
    bm10_req_ready              => axi_mid_array(10).arready,
    bm10_req_addr               => axi_mid_array(10).araddr,
    bm10_req_len                => axi_mid_array(10).arlen,
    bm10_resp_valid             => axi_mid_array(10).rvalid,
    bm10_resp_ready             => axi_mid_array(10).rready,
    bm10_resp_data              => axi_mid_array(10).rdata,
    bm10_resp_last              => axi_mid_array(10).rlast,
    bm11_req_valid              => axi_mid_array(11).arvalid,
    bm11_req_ready              => axi_mid_array(11).arready,
    bm11_req_addr               => axi_mid_array(11).araddr,
    bm11_req_len                => axi_mid_array(11).arlen,
    bm11_resp_valid             => axi_mid_array(11).rvalid,
    bm11_resp_ready             => axi_mid_array(11).rready,
    bm11_resp_data              => axi_mid_array(11).rdata,
    bm11_resp_last              => axi_mid_array(11).rlast,
    bm12_req_valid              => axi_mid_array(12).arvalid,
    bm12_req_ready              => axi_mid_array(12).arready,
    bm12_req_addr               => axi_mid_array(12).araddr,
    bm12_req_len                => axi_mid_array(12).arlen,
    bm12_resp_valid             => axi_mid_array(12).rvalid,
    bm12_resp_ready             => axi_mid_array(12).rready,
    bm12_resp_data              => axi_mid_array(12).rdata,
    bm12_resp_last              => axi_mid_array(12).rlast,
    bm13_req_valid              => axi_mid_array(13).arvalid,
    bm13_req_ready              => axi_mid_array(13).arready,
    bm13_req_addr               => axi_mid_array(13).araddr,
    bm13_req_len                => axi_mid_array(13).arlen,
    bm13_resp_valid             => axi_mid_array(13).rvalid,
    bm13_resp_ready             => axi_mid_array(13).rready,
    bm13_resp_data              => axi_mid_array(13).rdata,
    bm13_resp_last              => axi_mid_array(13).rlast,
    bm14_req_valid              => axi_mid_array(14).arvalid,
    bm14_req_ready              => axi_mid_array(14).arready,
    bm14_req_addr               => axi_mid_array(14).araddr,
    bm14_req_len                => axi_mid_array(14).arlen,
    bm14_resp_valid             => axi_mid_array(14).rvalid,
    bm14_resp_ready             => axi_mid_array(14).rready,
    bm14_resp_data              => axi_mid_array(14).rdata,
    bm14_resp_last              => axi_mid_array(14).rlast,
    bm15_req_valid              => axi_mid_array(15).arvalid,
    bm15_req_ready              => axi_mid_array(15).arready,
    bm15_req_addr               => axi_mid_array(15).araddr,
    bm15_req_len                => axi_mid_array(15).arlen,
    bm15_resp_valid             => axi_mid_array(15).rvalid,
    bm15_resp_ready             => axi_mid_array(15).rready,
    bm15_resp_data              => axi_mid_array(15).rdata,
    bm15_resp_last              => axi_mid_array(15).rlast
  );                            

end architecture;
