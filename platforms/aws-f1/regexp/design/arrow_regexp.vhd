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
use work.Utils.all;
use work.Arrow.all;
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
    BUS_ADDR_WIDTH              : natural :=  64;
    BUS_DATA_WIDTH              : natural := 512;
    BUS_LEN_WIDTH               : natural :=   8;
    BUS_BURST_WIDTH             : natural :=   2;
    BUS_RESP_WIDTH              : natural :=   2;

    SLV_BUS_ADDR_WIDTH          : natural :=  32;
    SLV_BUS_DATA_WIDTH          : natural :=  32
  );

  port (
    clk                         : in  std_logic;
    reset_n                     : in  std_logic;

    ---------------------------------------------------------------------------
    -- AXI4 master
    --
    -- To be connected to the DDR controllers (through CL_DMA_PCIS_SLV)
    ---------------------------------------------------------------------------
    -- Write ports
    m_axi_awid                  : out std_logic_vector(7 downto 0);
    m_axi_awaddr                : out std_logic_vector(63 downto 0);
    m_axi_awlen                 : out std_logic_vector(7 downto 0);
    m_axi_awsize                : out std_logic_vector(2 downto 0);
    m_axi_awvalid               : out std_logic;

    m_axi_wdata                 : out std_logic_vector(511 downto 0);
    m_axi_wstrb                 : out std_logic_vector(63 downto 0);
    m_axi_wlast                 : out std_logic;
    m_axi_wvalid                : out std_logic;

    m_axi_bready                : out std_logic;

    -- Read address channel
    m_axi_araddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    m_axi_arid                  : out std_logic_vector(7 downto 0);
    m_axi_arlen                 : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    m_axi_arvalid               : out std_logic;
    m_axi_arready               : in  std_logic;
    m_axi_arsize                : out std_logic_vector(2 downto 0);

    -- Read data channel
    m_axi_rid                   : in  std_logic_vector(7 downto 0);
    m_axi_rdata                 : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    m_axi_rresp                 : in  std_logic_vector(BUS_RESP_WIDTH-1 downto 0);
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
  -- Bottom buses
  constant BB                   : natural := 16;
  
  -- Bottom total number of connected units
  constant CORES                : natural := 16; -- Must be even for adder tree to work
  
  -- Number of regexes
  constant NUM_REGEX            : natural := 16;
  
  -----------------------------------------------------------------------------
  -- Memory Mapped Slave Registers
  -----------------------------------------------------------------------------
  --   1 control (uint64)  =   2 
  --   1 status (uint64)   =   2 
  --   1 return (uint64)   =   2 
  --   1 index buf address =   2 
  --   1 data  buf address =   2 
  --  16 first & last idx  =  32 
  --  16 regex results     =  16 
  -----------------------------------
  -- Total:                   58 regs  
  constant NUM_REGS             : natural := 58;
  
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

  -- Slave address width and calculation helper constants
  constant SLV_ADDR_WIDTH       : natural := log2ceil(NUM_REGS);
  constant SLV_ADDR_SHIFT       : natural := log2ceil(SLV_BUS_DATA_WIDTH)-3;

  -- Memory mapped register file
  type mm_regs_t is array (0 to NUM_REGS-1) of std_logic_vector(SLV_BUS_DATA_WIDTH-1 downto 0);
  signal mm_regs                : mm_regs_t;

  -- Helper signals to do handshaking on the slave port
  signal read_address           : natural range 0 to NUM_REGS-1;
  signal write_valid            : std_logic;
  signal read_valid             : std_logic := '0';
  signal write_processed        : std_logic;

  -----------------------------------------------------------------------------
  -- AXI Interconnect Master Ports
  -----------------------------------------------------------------------------
  type axi_bottom_array_t       is array (0 to BB-1) of axi_bottom_t;
  type axi_mid_array_t          is array (0 to BB-1) of axi_mid_t;
  
  signal axi_bottom_array       : axi_bottom_array_t;
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
  
  type result_add_t is array (0 to CORES-1) of unsigned(31 downto 0);
  type result_add_tree_t is array (0 to log2ceil(CORES)) of result_add_t;
  type regex_result_add_tree_t is array(0 to NUM_REGEX-1) of result_add_tree_t;
  
  signal result_add             : regex_result_add_tree_t;
  
begin

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
    variable address : natural range 0 to NUM_REGS-1;
  begin
    address                     := int(s_axi_araddr(SLV_ADDR_WIDTH+SLV_ADDR_SHIFT-1 downto SLV_ADDR_SHIFT));

    if rising_edge(clk) then
      if reset_n = '0' then
        read_valid              <= '0';
      else
        if s_axi_arvalid = '1' and read_valid = '0' then
          report "Read from MMSR: " & integer'image(address);
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
  write_to_regs: process(clk) is
    variable address : natural range 0 to NUM_REGS-1;
  begin
    -- Convert address
    address                     := int(s_axi_awaddr(SLV_ADDR_WIDTH+SLV_ADDR_SHIFT-1 downto SLV_ADDR_SHIFT));

    if rising_edge(clk) then
      if reset_n = '0' then
        for I in 0 to NUM_REGS-1 loop
          mm_regs(I)            <= (others => '0');
        end loop;
      else
        if write_valid = '1' then
          report "Write to MMSR: " & integer'image(address);
          case address is
            -- Read only regs:
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

        -- Status register
        mm_regs(REG_STATUS_HI) <= (others => '0');
        mm_regs(REG_STATUS_LO)(STATUS_BUSY_OFFSET + CORES - 1 downto STATUS_BUSY_OFFSET) <= bit_array_busy;
        mm_regs(REG_STATUS_LO)(STATUS_DONE_OFFSET + CORES - 1 downto STATUS_DONE_OFFSET) <= bit_array_done;
        
        -- Result registers
        for R in 0 to NUM_REGEX-1 loop
          mm_regs(REG_RESULT + R) <= slv(result_add(R)(0)(0));
        end loop;
        
        -- Return registers
        mm_regs(REG_RETURN_HI) <= (others => '0');
        mm_regs(REG_RETURN_LO) <= slv(result_add(0)(0)(0));
        
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

  -- Control bits
  bit_array_control_start <= mm_regs(REG_CONTROL_LO)(CONTROL_START_OFFSET + CORES -1 downto CONTROL_START_OFFSET);
  bit_array_control_reset <= mm_regs(REG_CONTROL_LO)(CONTROL_RESET_OFFSET + CORES -1 downto CONTROL_RESET_OFFSET);

  -- Registers
  reg_gen: for I in 0 to CORES-1 generate
    -- Local
    reg_array_firstidx(I)       <= mm_regs(REG_FIRST_IDX + I);
    reg_array_lastidx(I)        <= mm_regs(REG_LAST_IDX + I);
    -- Global
    reg_array_off_hi (I)        <= mm_regs(REG_OFF_ADDR_HI);
    reg_array_off_lo (I)        <= mm_regs(REG_OFF_ADDR_LO);
    reg_array_utf8_hi(I)        <= mm_regs(REG_UTF8_ADDR_HI);
    reg_array_utf8_lo(I)        <= mm_regs(REG_UTF8_ADDR_LO);
  end generate;

  -----------------------------------------------------------------------------
  -- AXI Master
  -----------------------------------------------------------------------------
  -- Tie off write channels:
  m_axi_awid                  <= axi_top.awid;
  m_axi_awaddr                <= (others => '0');
  m_axi_awlen                 <= (others => '0');
  m_axi_awsize                <= (others => '0');
  m_axi_awvalid               <= '0';

  m_axi_wdata                 <= (others => '0');
  m_axi_wstrb                 <= (others => '0');
  m_axi_wlast                 <= '0';
  m_axi_wvalid                <= '0';

  m_axi_bready                <= '0';

  -- Read address channel
  axi_top.arready             <= m_axi_arready;

  m_axi_arvalid               <= axi_top.arvalid;
  m_axi_araddr                <= axi_top.araddr;
  m_axi_arid                  <= axi_top.arid;
  m_axi_arlen                 <= axi_top.arlen;
  m_axi_arsize                <= axi_top.arsize;

  -- Read data channel
  m_axi_rready                <= axi_top.rready ;

  axi_top.rvalid              <= m_axi_rvalid;    
  axi_top.rid                 <= m_axi_rid;
  axi_top.rdata               <= m_axi_rdata;
  axi_top.rresp               <= m_axi_rresp;
  axi_top.rlast               <= m_axi_rlast;
  
  regex_add_tree: for R in 0 to NUM_REGEX-1 generate
    -----------------------------------------------------------------------------
    -- Adder tree assuming CORES is even
    -----------------------------------------------------------------------------
    -- TODO: somehow make sure when the return reg is read that there is nothing 
    -- left in the adder tree pipeline.
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
    read_converter_inst: axi_read_converter generic map (
      ADDR_WIDTH                => 64,
      ID_WIDTH                  => 1,
      MASTER_DATA_WIDTH         => 512,
      SLAVE_DATA_WIDTH          => 32
    )                           
    port map (                  
      clk                       => clk,
      reset_n                   => reset_n,
      s_axi_araddr              => axi_bottom_array(I).araddr,
      s_axi_arid                => axi_bottom_array(I).arid,
      s_axi_arlen               => axi_bottom_array(I).arlen,
      s_axi_arvalid             => axi_bottom_array(I).arvalid,
      s_axi_arready             => axi_bottom_array(I).arready,
      s_axi_arsize              => axi_bottom_array(I).arsize,
      s_axi_rid                 => axi_bottom_array(I).rid, 
      s_axi_rdata               => axi_bottom_array(I).rdata,
      s_axi_rresp               => axi_bottom_array(I).rresp,
      s_axi_rlast               => axi_bottom_array(I).rlast,
      s_axi_rvalid              => axi_bottom_array(I).rvalid,
      s_axi_rready              => axi_bottom_array(I).rready,
      m_axi_araddr              => axi_mid_array(I).araddr,
      m_axi_arid                => axi_mid_array(I).arid,
      m_axi_arlen               => axi_mid_array(I).arlen,
      m_axi_arvalid             => axi_mid_array(I).arvalid,
      m_axi_arready             => axi_mid_array(I).arready,
      m_axi_arsize              => axi_mid_array(I).arsize,
      m_axi_rid                 => axi_mid_array(I).rid,
      m_axi_rdata               => axi_mid_array(I).rdata,
      m_axi_rresp               => axi_mid_array(I).rresp,
      m_axi_rlast               => axi_mid_array(I).rlast,
      m_axi_rvalid              => axi_mid_array(I).rvalid,
      m_axi_rready              => axi_mid_array(I).rready
    );
      
    -- utf8 regular expression matcher generation
    regexp_inst: arrow_regexp_unit generic map (
      NUM_REGEX                 => NUM_REGEX,
      BUS_ADDR_WIDTH            => 64,
      BUS_DATA_WIDTH            => 32,
      BUS_ID_WIDTH              => 1,
      BUS_LEN_WIDTH             => 8,
      BUS_BURST_LENGTH          => 128,
      BUS_WSTRB_WIDTH           => 32/8,
      BUS_RESP_WIDTH            => 2,
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
      
      m_axi_awaddr              => axi_bottom_array(I).awaddr ,
      m_axi_awlen               => axi_bottom_array(I).awlen  ,
      m_axi_awsize              => axi_bottom_array(I).awsize ,
      m_axi_awvalid             => axi_bottom_array(I).awvalid,
      m_axi_wdata               => axi_bottom_array(I).wdata  ,
      m_axi_wstrb               => axi_bottom_array(I).wstrb  ,
      m_axi_wlast               => axi_bottom_array(I).wlast  ,
      m_axi_wvalid              => axi_bottom_array(I).wvalid ,
      m_axi_bready              => axi_bottom_array(I).bready ,
      m_axi_araddr              => axi_bottom_array(I).araddr ,
      m_axi_arid                => axi_bottom_array(I).arid   ,
      m_axi_arlen               => axi_bottom_array(I).arlen  ,
      m_axi_arvalid             => axi_bottom_array(I).arvalid,
      m_axi_arready             => axi_bottom_array(I).arready,
      m_axi_arsize              => axi_bottom_array(I).arsize ,
      m_axi_rdata               => axi_bottom_array(I).rdata  ,
      m_axi_rresp               => axi_bottom_array(I).rresp  ,
      m_axi_rlast               => axi_bottom_array(I).rlast  ,
      m_axi_rvalid              => axi_bottom_array(I).rvalid ,
      m_axi_rready              => axi_bottom_array(I).rready
    );   
    
    -- Pass through result to right result_array:
    result_conv_gen: for R in 0 to NUM_REGEX-1 generate
      result_array(R)(I) <= result_conv(I)(32*(R+1)-1 downto (32*R));
    end generate;
       
    -- Connect clocks
    axi_mid_array(I).aclk       <= clk;

    axi_mid_array(I).arburst    <= "01";      -- Incremental bursts, required according to Xilinx
    -- Unused and not required
    --axi_mid_array(I).arprot     <= "000";   -- required according to ARM, not required according to Xilinx:
    --axi_mid_array(I).arlock     <= '0';     -- Non exclusive access
    --axi_mid_array(I).arcache    <= "0000";  -- Non-modifiable, Non-bufferable
    --axi_mid_array(I).arqos      <= "0000";  
    
    -- Write channel tie off
    axi_mid_array(I).awaddr     <= (others => '0');
    axi_mid_array(I).awlen      <= (others => '0');
    axi_mid_array(I).awsize     <= (others => '0');
    axi_mid_array(I).awvalid    <= '0';
    axi_mid_array(I).wdata      <= (others => '0');
    axi_mid_array(I).wstrb      <= (others => '0');
    axi_mid_array(I).wlast      <= '0';
    axi_mid_array(I).wvalid     <= '0';
    axi_mid_array(I).bready     <= '1';
    axi_mid_array(I).awid       <= (others => '0');
    axi_mid_array(I).awburst    <= "01";        -- Incremental    
    --axi_bottom_array(I).awprot  <= "010";
    --axi_bottom_array(I).awlock  <= '0';
    --axi_bottom_array(I).awcache <= "0000";
    --axi_bottom_array(I).awqos   <= "0000";
  end generate;
  
  -- Tie off unused ports, if any
  unused_gen: for I in CORES to BB-1 generate 
    axi_mid_array(I).awaddr     <= (others => '0');
    axi_mid_array(I).awlen      <= (others => '0');
    axi_mid_array(I).awsize     <= (others => '0');
    axi_mid_array(I).awvalid    <= '0';
    axi_mid_array(I).wdata      <= (others => '0');
    axi_mid_array(I).wstrb      <= (others => '0');
    axi_mid_array(I).wlast      <= '0';
    axi_mid_array(I).wvalid     <= '0';
    axi_mid_array(I).bready     <= '0';
    axi_mid_array(I).araddr     <= (others => '0');
    axi_mid_array(I).arlen      <= (others => '0');
    axi_mid_array(I).arvalid    <= '0';
    axi_mid_array(I).arsize     <= (others => '0');
    axi_mid_array(I).rready     <= '0';
    axi_mid_array(I).aclk       <= clk;
    axi_mid_array(I).arid       <= (others => '0');
    axi_mid_array(I).arburst    <= "01";
    --axi_mid_array(I).arprot     <= "010";
    --axi_mid_array(I).arlock     <= '0';
    --axi_mid_array(I).arcache    <= "0011";
    --axi_mid_array(I).arqos      <= "0000";
    axi_mid_array(I).awid       <= (others => '0');
    axi_mid_array(I).awburst    <= "01";  
    --axi_mid_array(I).awprot     <= "010";
    --axi_mid_array(I).awlock     <= '0';    
    --axi_mid_array(I).awcache    <= "0000"; 
    --axi_mid_array(I).awqos      <= "0000";
  end generate;

  -----------------------------------------------------------------------------
  -- Mid layer interconnect generation
  -----------------------------------------------------------------------------
  -- Interconnect
  mid_interconnect: axi_interconnect_utf8 port map (
    interconnect_aclk           => clk,
    interconnect_aresetn        => reset_n,
    s00_axi_areset_out_n        => axi_mid_array( 0).areset_out_n,
    s00_axi_aclk                => axi_mid_array( 0).aclk        ,
    s00_axi_awid                => axi_mid_array( 0).awid        ,
    s00_axi_awaddr              => axi_mid_array( 0).awaddr      ,
    s00_axi_awlen               => axi_mid_array( 0).awlen       ,
    s00_axi_awsize              => axi_mid_array( 0).awsize      ,
    s00_axi_awburst             => axi_mid_array( 0).awburst     ,
    s00_axi_awlock              => axi_mid_array( 0).awlock      ,
    s00_axi_awcache             => axi_mid_array( 0).awcache     ,
    s00_axi_awprot              => axi_mid_array( 0).awprot      ,
    s00_axi_awqos               => axi_mid_array( 0).awqos       ,
    s00_axi_awvalid             => axi_mid_array( 0).awvalid     ,
    s00_axi_awready             => axi_mid_array( 0).awready     ,
    s00_axi_wdata               => axi_mid_array( 0).wdata       ,
    s00_axi_wstrb               => axi_mid_array( 0).wstrb       ,
    s00_axi_wlast               => axi_mid_array( 0).wlast       ,
    s00_axi_wvalid              => axi_mid_array( 0).wvalid      ,
    s00_axi_wready              => axi_mid_array( 0).wready      ,
    s00_axi_bid                 => axi_mid_array( 0).bid         ,
    s00_axi_bresp               => axi_mid_array( 0).bresp       ,
    s00_axi_bvalid              => axi_mid_array( 0).bvalid      ,
    s00_axi_bready              => axi_mid_array( 0).bready      ,
    s00_axi_arid                => axi_mid_array( 0).arid        ,
    s00_axi_araddr              => axi_mid_array( 0).araddr      ,
    s00_axi_arlen               => axi_mid_array( 0).arlen       ,
    s00_axi_arsize              => axi_mid_array( 0).arsize      ,
    s00_axi_arburst             => axi_mid_array( 0).arburst     ,
    s00_axi_arlock              => axi_mid_array( 0).arlock      ,
    s00_axi_arcache             => axi_mid_array( 0).arcache     ,
    s00_axi_arprot              => axi_mid_array( 0).arprot      ,
    s00_axi_arqos               => axi_mid_array( 0).arqos       ,
    s00_axi_arvalid             => axi_mid_array( 0).arvalid     ,
    s00_axi_arready             => axi_mid_array( 0).arready     ,
    s00_axi_rid                 => axi_mid_array( 0).rid         ,
    s00_axi_rdata               => axi_mid_array( 0).rdata       ,
    s00_axi_rresp               => axi_mid_array( 0).rresp       ,
    s00_axi_rlast               => axi_mid_array( 0).rlast       ,
    s00_axi_rvalid              => axi_mid_array( 0).rvalid      ,
    s00_axi_rready              => axi_mid_array( 0).rready      ,
    s01_axi_areset_out_n        => axi_mid_array( 1).areset_out_n,
    s01_axi_aclk                => axi_mid_array( 1).aclk        ,
    s01_axi_awid                => axi_mid_array( 1).awid        ,
    s01_axi_awaddr              => axi_mid_array( 1).awaddr      ,
    s01_axi_awlen               => axi_mid_array( 1).awlen       ,
    s01_axi_awsize              => axi_mid_array( 1).awsize      ,
    s01_axi_awburst             => axi_mid_array( 1).awburst     ,
    s01_axi_awlock              => axi_mid_array( 1).awlock      ,
    s01_axi_awcache             => axi_mid_array( 1).awcache     ,
    s01_axi_awprot              => axi_mid_array( 1).awprot      ,
    s01_axi_awqos               => axi_mid_array( 1).awqos       ,
    s01_axi_awvalid             => axi_mid_array( 1).awvalid     ,
    s01_axi_awready             => axi_mid_array( 1).awready     ,
    s01_axi_wdata               => axi_mid_array( 1).wdata       ,
    s01_axi_wstrb               => axi_mid_array( 1).wstrb       ,
    s01_axi_wlast               => axi_mid_array( 1).wlast       ,
    s01_axi_wvalid              => axi_mid_array( 1).wvalid      ,
    s01_axi_wready              => axi_mid_array( 1).wready      ,
    s01_axi_bid                 => axi_mid_array( 1).bid         ,
    s01_axi_bresp               => axi_mid_array( 1).bresp       ,
    s01_axi_bvalid              => axi_mid_array( 1).bvalid      ,
    s01_axi_bready              => axi_mid_array( 1).bready      ,
    s01_axi_arid                => axi_mid_array( 1).arid        ,
    s01_axi_araddr              => axi_mid_array( 1).araddr      ,
    s01_axi_arlen               => axi_mid_array( 1).arlen       ,
    s01_axi_arsize              => axi_mid_array( 1).arsize      ,
    s01_axi_arburst             => axi_mid_array( 1).arburst     ,
    s01_axi_arlock              => axi_mid_array( 1).arlock      ,
    s01_axi_arcache             => axi_mid_array( 1).arcache     ,
    s01_axi_arprot              => axi_mid_array( 1).arprot      ,
    s01_axi_arqos               => axi_mid_array( 1).arqos       ,
    s01_axi_arvalid             => axi_mid_array( 1).arvalid     ,
    s01_axi_arready             => axi_mid_array( 1).arready     ,
    s01_axi_rid                 => axi_mid_array( 1).rid         ,
    s01_axi_rdata               => axi_mid_array( 1).rdata       ,
    s01_axi_rresp               => axi_mid_array( 1).rresp       ,
    s01_axi_rlast               => axi_mid_array( 1).rlast       ,
    s01_axi_rvalid              => axi_mid_array( 1).rvalid      ,
    s01_axi_rready              => axi_mid_array( 1).rready      ,
    s02_axi_areset_out_n        => axi_mid_array( 2).areset_out_n,
    s02_axi_aclk                => axi_mid_array( 2).aclk        ,
    s02_axi_awid                => axi_mid_array( 2).awid        ,
    s02_axi_awaddr              => axi_mid_array( 2).awaddr      ,
    s02_axi_awlen               => axi_mid_array( 2).awlen       ,
    s02_axi_awsize              => axi_mid_array( 2).awsize      ,
    s02_axi_awburst             => axi_mid_array( 2).awburst     ,
    s02_axi_awlock              => axi_mid_array( 2).awlock      ,
    s02_axi_awcache             => axi_mid_array( 2).awcache     ,
    s02_axi_awprot              => axi_mid_array( 2).awprot      ,
    s02_axi_awqos               => axi_mid_array( 2).awqos       ,
    s02_axi_awvalid             => axi_mid_array( 2).awvalid     ,
    s02_axi_awready             => axi_mid_array( 2).awready     ,
    s02_axi_wdata               => axi_mid_array( 2).wdata       ,
    s02_axi_wstrb               => axi_mid_array( 2).wstrb       ,
    s02_axi_wlast               => axi_mid_array( 2).wlast       ,
    s02_axi_wvalid              => axi_mid_array( 2).wvalid      ,
    s02_axi_wready              => axi_mid_array( 2).wready      ,
    s02_axi_bid                 => axi_mid_array( 2).bid         ,
    s02_axi_bresp               => axi_mid_array( 2).bresp       ,
    s02_axi_bvalid              => axi_mid_array( 2).bvalid      ,
    s02_axi_bready              => axi_mid_array( 2).bready      ,
    s02_axi_arid                => axi_mid_array( 2).arid        ,
    s02_axi_araddr              => axi_mid_array( 2).araddr      ,
    s02_axi_arlen               => axi_mid_array( 2).arlen       ,
    s02_axi_arsize              => axi_mid_array( 2).arsize      ,
    s02_axi_arburst             => axi_mid_array( 2).arburst     ,
    s02_axi_arlock              => axi_mid_array( 2).arlock      ,
    s02_axi_arcache             => axi_mid_array( 2).arcache     ,
    s02_axi_arprot              => axi_mid_array( 2).arprot      ,
    s02_axi_arqos               => axi_mid_array( 2).arqos       ,
    s02_axi_arvalid             => axi_mid_array( 2).arvalid     ,
    s02_axi_arready             => axi_mid_array( 2).arready     ,
    s02_axi_rid                 => axi_mid_array( 2).rid         ,
    s02_axi_rdata               => axi_mid_array( 2).rdata       ,
    s02_axi_rresp               => axi_mid_array( 2).rresp       ,
    s02_axi_rlast               => axi_mid_array( 2).rlast       ,
    s02_axi_rvalid              => axi_mid_array( 2).rvalid      ,
    s02_axi_rready              => axi_mid_array( 2).rready      ,
    s03_axi_areset_out_n        => axi_mid_array( 3).areset_out_n,
    s03_axi_aclk                => axi_mid_array( 3).aclk        ,
    s03_axi_awid                => axi_mid_array( 3).awid        ,
    s03_axi_awaddr              => axi_mid_array( 3).awaddr      ,
    s03_axi_awlen               => axi_mid_array( 3).awlen       ,
    s03_axi_awsize              => axi_mid_array( 3).awsize      ,
    s03_axi_awburst             => axi_mid_array( 3).awburst     ,
    s03_axi_awlock              => axi_mid_array( 3).awlock      ,
    s03_axi_awcache             => axi_mid_array( 3).awcache     ,
    s03_axi_awprot              => axi_mid_array( 3).awprot      ,
    s03_axi_awqos               => axi_mid_array( 3).awqos       ,
    s03_axi_awvalid             => axi_mid_array( 3).awvalid     ,
    s03_axi_awready             => axi_mid_array( 3).awready     ,
    s03_axi_wdata               => axi_mid_array( 3).wdata       ,
    s03_axi_wstrb               => axi_mid_array( 3).wstrb       ,
    s03_axi_wlast               => axi_mid_array( 3).wlast       ,
    s03_axi_wvalid              => axi_mid_array( 3).wvalid      ,
    s03_axi_wready              => axi_mid_array( 3).wready      ,
    s03_axi_bid                 => axi_mid_array( 3).bid         ,
    s03_axi_bresp               => axi_mid_array( 3).bresp       ,
    s03_axi_bvalid              => axi_mid_array( 3).bvalid      ,
    s03_axi_bready              => axi_mid_array( 3).bready      ,
    s03_axi_arid                => axi_mid_array( 3).arid        ,
    s03_axi_araddr              => axi_mid_array( 3).araddr      ,
    s03_axi_arlen               => axi_mid_array( 3).arlen       ,
    s03_axi_arsize              => axi_mid_array( 3).arsize      ,
    s03_axi_arburst             => axi_mid_array( 3).arburst     ,
    s03_axi_arlock              => axi_mid_array( 3).arlock      ,
    s03_axi_arcache             => axi_mid_array( 3).arcache     ,
    s03_axi_arprot              => axi_mid_array( 3).arprot      ,
    s03_axi_arqos               => axi_mid_array( 3).arqos       ,
    s03_axi_arvalid             => axi_mid_array( 3).arvalid     ,
    s03_axi_arready             => axi_mid_array( 3).arready     ,
    s03_axi_rid                 => axi_mid_array( 3).rid         ,
    s03_axi_rdata               => axi_mid_array( 3).rdata       ,
    s03_axi_rresp               => axi_mid_array( 3).rresp       ,
    s03_axi_rlast               => axi_mid_array( 3).rlast       ,
    s03_axi_rvalid              => axi_mid_array( 3).rvalid      ,
    s03_axi_rready              => axi_mid_array( 3).rready      ,
    s04_axi_areset_out_n        => axi_mid_array( 4).areset_out_n,
    s04_axi_aclk                => axi_mid_array( 4).aclk        ,
    s04_axi_awid                => axi_mid_array( 4).awid        ,
    s04_axi_awaddr              => axi_mid_array( 4).awaddr      ,
    s04_axi_awlen               => axi_mid_array( 4).awlen       ,
    s04_axi_awsize              => axi_mid_array( 4).awsize      ,
    s04_axi_awburst             => axi_mid_array( 4).awburst     ,
    s04_axi_awlock              => axi_mid_array( 4).awlock      ,
    s04_axi_awcache             => axi_mid_array( 4).awcache     ,
    s04_axi_awprot              => axi_mid_array( 4).awprot      ,
    s04_axi_awqos               => axi_mid_array( 4).awqos       ,
    s04_axi_awvalid             => axi_mid_array( 4).awvalid     ,
    s04_axi_awready             => axi_mid_array( 4).awready     ,
    s04_axi_wdata               => axi_mid_array( 4).wdata       ,
    s04_axi_wstrb               => axi_mid_array( 4).wstrb       ,
    s04_axi_wlast               => axi_mid_array( 4).wlast       ,
    s04_axi_wvalid              => axi_mid_array( 4).wvalid      ,
    s04_axi_wready              => axi_mid_array( 4).wready      ,
    s04_axi_bid                 => axi_mid_array( 4).bid         ,
    s04_axi_bresp               => axi_mid_array( 4).bresp       ,
    s04_axi_bvalid              => axi_mid_array( 4).bvalid      ,
    s04_axi_bready              => axi_mid_array( 4).bready      ,
    s04_axi_arid                => axi_mid_array( 4).arid        ,
    s04_axi_araddr              => axi_mid_array( 4).araddr      ,
    s04_axi_arlen               => axi_mid_array( 4).arlen       ,
    s04_axi_arsize              => axi_mid_array( 4).arsize      ,
    s04_axi_arburst             => axi_mid_array( 4).arburst     ,
    s04_axi_arlock              => axi_mid_array( 4).arlock      ,
    s04_axi_arcache             => axi_mid_array( 4).arcache     ,
    s04_axi_arprot              => axi_mid_array( 4).arprot      ,
    s04_axi_arqos               => axi_mid_array( 4).arqos       ,
    s04_axi_arvalid             => axi_mid_array( 4).arvalid     ,
    s04_axi_arready             => axi_mid_array( 4).arready     ,
    s04_axi_rid                 => axi_mid_array( 4).rid         ,
    s04_axi_rdata               => axi_mid_array( 4).rdata       ,
    s04_axi_rresp               => axi_mid_array( 4).rresp       ,
    s04_axi_rlast               => axi_mid_array( 4).rlast       ,
    s04_axi_rvalid              => axi_mid_array( 4).rvalid      ,
    s04_axi_rready              => axi_mid_array( 4).rready      ,
    s05_axi_areset_out_n        => axi_mid_array( 5).areset_out_n,
    s05_axi_aclk                => axi_mid_array( 5).aclk        ,
    s05_axi_awid                => axi_mid_array( 5).awid        ,
    s05_axi_awaddr              => axi_mid_array( 5).awaddr      ,
    s05_axi_awlen               => axi_mid_array( 5).awlen       ,
    s05_axi_awsize              => axi_mid_array( 5).awsize      ,
    s05_axi_awburst             => axi_mid_array( 5).awburst     ,
    s05_axi_awlock              => axi_mid_array( 5).awlock      ,
    s05_axi_awcache             => axi_mid_array( 5).awcache     ,
    s05_axi_awprot              => axi_mid_array( 5).awprot      ,
    s05_axi_awqos               => axi_mid_array( 5).awqos       ,
    s05_axi_awvalid             => axi_mid_array( 5).awvalid     ,
    s05_axi_awready             => axi_mid_array( 5).awready     ,
    s05_axi_wdata               => axi_mid_array( 5).wdata       ,
    s05_axi_wstrb               => axi_mid_array( 5).wstrb       ,
    s05_axi_wlast               => axi_mid_array( 5).wlast       ,
    s05_axi_wvalid              => axi_mid_array( 5).wvalid      ,
    s05_axi_wready              => axi_mid_array( 5).wready      ,
    s05_axi_bid                 => axi_mid_array( 5).bid         ,
    s05_axi_bresp               => axi_mid_array( 5).bresp       ,
    s05_axi_bvalid              => axi_mid_array( 5).bvalid      ,
    s05_axi_bready              => axi_mid_array( 5).bready      ,
    s05_axi_arid                => axi_mid_array( 5).arid        ,
    s05_axi_araddr              => axi_mid_array( 5).araddr      ,
    s05_axi_arlen               => axi_mid_array( 5).arlen       ,
    s05_axi_arsize              => axi_mid_array( 5).arsize      ,
    s05_axi_arburst             => axi_mid_array( 5).arburst     ,
    s05_axi_arlock              => axi_mid_array( 5).arlock      ,
    s05_axi_arcache             => axi_mid_array( 5).arcache     ,
    s05_axi_arprot              => axi_mid_array( 5).arprot      ,
    s05_axi_arqos               => axi_mid_array( 5).arqos       ,
    s05_axi_arvalid             => axi_mid_array( 5).arvalid     ,
    s05_axi_arready             => axi_mid_array( 5).arready     ,
    s05_axi_rid                 => axi_mid_array( 5).rid         ,
    s05_axi_rdata               => axi_mid_array( 5).rdata       ,
    s05_axi_rresp               => axi_mid_array( 5).rresp       ,
    s05_axi_rlast               => axi_mid_array( 5).rlast       ,
    s05_axi_rvalid              => axi_mid_array( 5).rvalid      ,
    s05_axi_rready              => axi_mid_array( 5).rready      ,
    s06_axi_areset_out_n        => axi_mid_array( 6).areset_out_n,
    s06_axi_aclk                => axi_mid_array( 6).aclk        ,
    s06_axi_awid                => axi_mid_array( 6).awid        ,
    s06_axi_awaddr              => axi_mid_array( 6).awaddr      ,
    s06_axi_awlen               => axi_mid_array( 6).awlen       ,
    s06_axi_awsize              => axi_mid_array( 6).awsize      ,
    s06_axi_awburst             => axi_mid_array( 6).awburst     ,
    s06_axi_awlock              => axi_mid_array( 6).awlock      ,
    s06_axi_awcache             => axi_mid_array( 6).awcache     ,
    s06_axi_awprot              => axi_mid_array( 6).awprot      ,
    s06_axi_awqos               => axi_mid_array( 6).awqos       ,
    s06_axi_awvalid             => axi_mid_array( 6).awvalid     ,
    s06_axi_awready             => axi_mid_array( 6).awready     ,
    s06_axi_wdata               => axi_mid_array( 6).wdata       ,
    s06_axi_wstrb               => axi_mid_array( 6).wstrb       ,
    s06_axi_wlast               => axi_mid_array( 6).wlast       ,
    s06_axi_wvalid              => axi_mid_array( 6).wvalid      ,
    s06_axi_wready              => axi_mid_array( 6).wready      ,
    s06_axi_bid                 => axi_mid_array( 6).bid         ,
    s06_axi_bresp               => axi_mid_array( 6).bresp       ,
    s06_axi_bvalid              => axi_mid_array( 6).bvalid      ,
    s06_axi_bready              => axi_mid_array( 6).bready      ,
    s06_axi_arid                => axi_mid_array( 6).arid        ,
    s06_axi_araddr              => axi_mid_array( 6).araddr      ,
    s06_axi_arlen               => axi_mid_array( 6).arlen       ,
    s06_axi_arsize              => axi_mid_array( 6).arsize      ,
    s06_axi_arburst             => axi_mid_array( 6).arburst     ,
    s06_axi_arlock              => axi_mid_array( 6).arlock      ,
    s06_axi_arcache             => axi_mid_array( 6).arcache     ,
    s06_axi_arprot              => axi_mid_array( 6).arprot      ,
    s06_axi_arqos               => axi_mid_array( 6).arqos       ,
    s06_axi_arvalid             => axi_mid_array( 6).arvalid     ,
    s06_axi_arready             => axi_mid_array( 6).arready     ,
    s06_axi_rid                 => axi_mid_array( 6).rid         ,
    s06_axi_rdata               => axi_mid_array( 6).rdata       ,
    s06_axi_rresp               => axi_mid_array( 6).rresp       ,
    s06_axi_rlast               => axi_mid_array( 6).rlast       ,
    s06_axi_rvalid              => axi_mid_array( 6).rvalid      ,
    s06_axi_rready              => axi_mid_array( 6).rready      ,
    s07_axi_areset_out_n        => axi_mid_array( 7).areset_out_n,
    s07_axi_aclk                => axi_mid_array( 7).aclk        ,
    s07_axi_awid                => axi_mid_array( 7).awid        ,
    s07_axi_awaddr              => axi_mid_array( 7).awaddr      ,
    s07_axi_awlen               => axi_mid_array( 7).awlen       ,
    s07_axi_awsize              => axi_mid_array( 7).awsize      ,
    s07_axi_awburst             => axi_mid_array( 7).awburst     ,
    s07_axi_awlock              => axi_mid_array( 7).awlock      ,
    s07_axi_awcache             => axi_mid_array( 7).awcache     ,
    s07_axi_awprot              => axi_mid_array( 7).awprot      ,
    s07_axi_awqos               => axi_mid_array( 7).awqos       ,
    s07_axi_awvalid             => axi_mid_array( 7).awvalid     ,
    s07_axi_awready             => axi_mid_array( 7).awready     ,
    s07_axi_wdata               => axi_mid_array( 7).wdata       ,
    s07_axi_wstrb               => axi_mid_array( 7).wstrb       ,
    s07_axi_wlast               => axi_mid_array( 7).wlast       ,
    s07_axi_wvalid              => axi_mid_array( 7).wvalid      ,
    s07_axi_wready              => axi_mid_array( 7).wready      ,
    s07_axi_bid                 => axi_mid_array( 7).bid         ,
    s07_axi_bresp               => axi_mid_array( 7).bresp       ,
    s07_axi_bvalid              => axi_mid_array( 7).bvalid      ,
    s07_axi_bready              => axi_mid_array( 7).bready      ,
    s07_axi_arid                => axi_mid_array( 7).arid        ,
    s07_axi_araddr              => axi_mid_array( 7).araddr      ,
    s07_axi_arlen               => axi_mid_array( 7).arlen       ,
    s07_axi_arsize              => axi_mid_array( 7).arsize      ,
    s07_axi_arburst             => axi_mid_array( 7).arburst     ,
    s07_axi_arlock              => axi_mid_array( 7).arlock      ,
    s07_axi_arcache             => axi_mid_array( 7).arcache     ,
    s07_axi_arprot              => axi_mid_array( 7).arprot      ,
    s07_axi_arqos               => axi_mid_array( 7).arqos       ,
    s07_axi_arvalid             => axi_mid_array( 7).arvalid     ,
    s07_axi_arready             => axi_mid_array( 7).arready     ,
    s07_axi_rid                 => axi_mid_array( 7).rid         ,
    s07_axi_rdata               => axi_mid_array( 7).rdata       ,
    s07_axi_rresp               => axi_mid_array( 7).rresp       ,
    s07_axi_rlast               => axi_mid_array( 7).rlast       ,
    s07_axi_rvalid              => axi_mid_array( 7).rvalid      ,
    s07_axi_rready              => axi_mid_array( 7).rready      ,
    s08_axi_areset_out_n        => axi_mid_array( 8).areset_out_n,
    s08_axi_aclk                => axi_mid_array( 8).aclk        ,
    s08_axi_awid                => axi_mid_array( 8).awid        ,
    s08_axi_awaddr              => axi_mid_array( 8).awaddr      ,
    s08_axi_awlen               => axi_mid_array( 8).awlen       ,
    s08_axi_awsize              => axi_mid_array( 8).awsize      ,
    s08_axi_awburst             => axi_mid_array( 8).awburst     ,
    s08_axi_awlock              => axi_mid_array( 8).awlock      ,
    s08_axi_awcache             => axi_mid_array( 8).awcache     ,
    s08_axi_awprot              => axi_mid_array( 8).awprot      ,
    s08_axi_awqos               => axi_mid_array( 8).awqos       ,
    s08_axi_awvalid             => axi_mid_array( 8).awvalid     ,
    s08_axi_awready             => axi_mid_array( 8).awready     ,
    s08_axi_wdata               => axi_mid_array( 8).wdata       ,
    s08_axi_wstrb               => axi_mid_array( 8).wstrb       ,
    s08_axi_wlast               => axi_mid_array( 8).wlast       ,
    s08_axi_wvalid              => axi_mid_array( 8).wvalid      ,
    s08_axi_wready              => axi_mid_array( 8).wready      ,
    s08_axi_bid                 => axi_mid_array( 8).bid         ,
    s08_axi_bresp               => axi_mid_array( 8).bresp       ,
    s08_axi_bvalid              => axi_mid_array( 8).bvalid      ,
    s08_axi_bready              => axi_mid_array( 8).bready      ,
    s08_axi_arid                => axi_mid_array( 8).arid        ,
    s08_axi_araddr              => axi_mid_array( 8).araddr      ,
    s08_axi_arlen               => axi_mid_array( 8).arlen       ,
    s08_axi_arsize              => axi_mid_array( 8).arsize      ,
    s08_axi_arburst             => axi_mid_array( 8).arburst     ,
    s08_axi_arlock              => axi_mid_array( 8).arlock      ,
    s08_axi_arcache             => axi_mid_array( 8).arcache     ,
    s08_axi_arprot              => axi_mid_array( 8).arprot      ,
    s08_axi_arqos               => axi_mid_array( 8).arqos       ,
    s08_axi_arvalid             => axi_mid_array( 8).arvalid     ,
    s08_axi_arready             => axi_mid_array( 8).arready     ,
    s08_axi_rid                 => axi_mid_array( 8).rid         ,
    s08_axi_rdata               => axi_mid_array( 8).rdata       ,
    s08_axi_rresp               => axi_mid_array( 8).rresp       ,
    s08_axi_rlast               => axi_mid_array( 8).rlast       ,
    s08_axi_rvalid              => axi_mid_array( 8).rvalid      ,
    s08_axi_rready              => axi_mid_array( 8).rready      ,
    s09_axi_areset_out_n        => axi_mid_array( 9).areset_out_n,
    s09_axi_aclk                => axi_mid_array( 9).aclk        ,
    s09_axi_awid                => axi_mid_array( 9).awid        ,
    s09_axi_awaddr              => axi_mid_array( 9).awaddr      ,
    s09_axi_awlen               => axi_mid_array( 9).awlen       ,
    s09_axi_awsize              => axi_mid_array( 9).awsize      ,
    s09_axi_awburst             => axi_mid_array( 9).awburst     ,
    s09_axi_awlock              => axi_mid_array( 9).awlock      ,
    s09_axi_awcache             => axi_mid_array( 9).awcache     ,
    s09_axi_awprot              => axi_mid_array( 9).awprot      ,
    s09_axi_awqos               => axi_mid_array( 9).awqos       ,
    s09_axi_awvalid             => axi_mid_array( 9).awvalid     ,
    s09_axi_awready             => axi_mid_array( 9).awready     ,
    s09_axi_wdata               => axi_mid_array( 9).wdata       ,
    s09_axi_wstrb               => axi_mid_array( 9).wstrb       ,
    s09_axi_wlast               => axi_mid_array( 9).wlast       ,
    s09_axi_wvalid              => axi_mid_array( 9).wvalid      ,
    s09_axi_wready              => axi_mid_array( 9).wready      ,
    s09_axi_bid                 => axi_mid_array( 9).bid         ,
    s09_axi_bresp               => axi_mid_array( 9).bresp       ,
    s09_axi_bvalid              => axi_mid_array( 9).bvalid      ,
    s09_axi_bready              => axi_mid_array( 9).bready      ,
    s09_axi_arid                => axi_mid_array( 9).arid        ,
    s09_axi_araddr              => axi_mid_array( 9).araddr      ,
    s09_axi_arlen               => axi_mid_array( 9).arlen       ,
    s09_axi_arsize              => axi_mid_array( 9).arsize      ,
    s09_axi_arburst             => axi_mid_array( 9).arburst     ,
    s09_axi_arlock              => axi_mid_array( 9).arlock      ,
    s09_axi_arcache             => axi_mid_array( 9).arcache     ,
    s09_axi_arprot              => axi_mid_array( 9).arprot      ,
    s09_axi_arqos               => axi_mid_array( 9).arqos       ,
    s09_axi_arvalid             => axi_mid_array( 9).arvalid     ,
    s09_axi_arready             => axi_mid_array( 9).arready     ,
    s09_axi_rid                 => axi_mid_array( 9).rid         ,
    s09_axi_rdata               => axi_mid_array( 9).rdata       ,
    s09_axi_rresp               => axi_mid_array( 9).rresp       ,
    s09_axi_rlast               => axi_mid_array( 9).rlast       ,
    s09_axi_rvalid              => axi_mid_array( 9).rvalid      ,
    s09_axi_rready              => axi_mid_array( 9).rready      ,
    s10_axi_areset_out_n        => axi_mid_array(10).areset_out_n,
    s10_axi_aclk                => axi_mid_array(10).aclk        ,
    s10_axi_awid                => axi_mid_array(10).awid        ,
    s10_axi_awaddr              => axi_mid_array(10).awaddr      ,
    s10_axi_awlen               => axi_mid_array(10).awlen       ,
    s10_axi_awsize              => axi_mid_array(10).awsize      ,
    s10_axi_awburst             => axi_mid_array(10).awburst     ,
    s10_axi_awlock              => axi_mid_array(10).awlock      ,
    s10_axi_awcache             => axi_mid_array(10).awcache     ,
    s10_axi_awprot              => axi_mid_array(10).awprot      ,
    s10_axi_awqos               => axi_mid_array(10).awqos       ,
    s10_axi_awvalid             => axi_mid_array(10).awvalid     ,
    s10_axi_awready             => axi_mid_array(10).awready     ,
    s10_axi_wdata               => axi_mid_array(10).wdata       ,
    s10_axi_wstrb               => axi_mid_array(10).wstrb       ,
    s10_axi_wlast               => axi_mid_array(10).wlast       ,
    s10_axi_wvalid              => axi_mid_array(10).wvalid      ,
    s10_axi_wready              => axi_mid_array(10).wready      ,
    s10_axi_bid                 => axi_mid_array(10).bid         ,
    s10_axi_bresp               => axi_mid_array(10).bresp       ,
    s10_axi_bvalid              => axi_mid_array(10).bvalid      ,
    s10_axi_bready              => axi_mid_array(10).bready      ,
    s10_axi_arid                => axi_mid_array(10).arid        ,
    s10_axi_araddr              => axi_mid_array(10).araddr      ,
    s10_axi_arlen               => axi_mid_array(10).arlen       ,
    s10_axi_arsize              => axi_mid_array(10).arsize      ,
    s10_axi_arburst             => axi_mid_array(10).arburst     ,
    s10_axi_arlock              => axi_mid_array(10).arlock      ,
    s10_axi_arcache             => axi_mid_array(10).arcache     ,
    s10_axi_arprot              => axi_mid_array(10).arprot      ,
    s10_axi_arqos               => axi_mid_array(10).arqos       ,
    s10_axi_arvalid             => axi_mid_array(10).arvalid     ,
    s10_axi_arready             => axi_mid_array(10).arready     ,
    s10_axi_rid                 => axi_mid_array(10).rid         ,
    s10_axi_rdata               => axi_mid_array(10).rdata       ,
    s10_axi_rresp               => axi_mid_array(10).rresp       ,
    s10_axi_rlast               => axi_mid_array(10).rlast       ,
    s10_axi_rvalid              => axi_mid_array(10).rvalid      ,
    s10_axi_rready              => axi_mid_array(10).rready      ,
    s11_axi_areset_out_n        => axi_mid_array(11).areset_out_n,
    s11_axi_aclk                => axi_mid_array(11).aclk        ,
    s11_axi_awid                => axi_mid_array(11).awid        ,
    s11_axi_awaddr              => axi_mid_array(11).awaddr      ,
    s11_axi_awlen               => axi_mid_array(11).awlen       ,
    s11_axi_awsize              => axi_mid_array(11).awsize      ,
    s11_axi_awburst             => axi_mid_array(11).awburst     ,
    s11_axi_awlock              => axi_mid_array(11).awlock      ,
    s11_axi_awcache             => axi_mid_array(11).awcache     ,
    s11_axi_awprot              => axi_mid_array(11).awprot      ,
    s11_axi_awqos               => axi_mid_array(11).awqos       ,
    s11_axi_awvalid             => axi_mid_array(11).awvalid     ,
    s11_axi_awready             => axi_mid_array(11).awready     ,
    s11_axi_wdata               => axi_mid_array(11).wdata       ,
    s11_axi_wstrb               => axi_mid_array(11).wstrb       ,
    s11_axi_wlast               => axi_mid_array(11).wlast       ,
    s11_axi_wvalid              => axi_mid_array(11).wvalid      ,
    s11_axi_wready              => axi_mid_array(11).wready      ,
    s11_axi_bid                 => axi_mid_array(11).bid         ,
    s11_axi_bresp               => axi_mid_array(11).bresp       ,
    s11_axi_bvalid              => axi_mid_array(11).bvalid      ,
    s11_axi_bready              => axi_mid_array(11).bready      ,
    s11_axi_arid                => axi_mid_array(11).arid        ,
    s11_axi_araddr              => axi_mid_array(11).araddr      ,
    s11_axi_arlen               => axi_mid_array(11).arlen       ,
    s11_axi_arsize              => axi_mid_array(11).arsize      ,
    s11_axi_arburst             => axi_mid_array(11).arburst     ,
    s11_axi_arlock              => axi_mid_array(11).arlock      ,
    s11_axi_arcache             => axi_mid_array(11).arcache     ,
    s11_axi_arprot              => axi_mid_array(11).arprot      ,
    s11_axi_arqos               => axi_mid_array(11).arqos       ,
    s11_axi_arvalid             => axi_mid_array(11).arvalid     ,
    s11_axi_arready             => axi_mid_array(11).arready     ,
    s11_axi_rid                 => axi_mid_array(11).rid         ,
    s11_axi_rdata               => axi_mid_array(11).rdata       ,
    s11_axi_rresp               => axi_mid_array(11).rresp       ,
    s11_axi_rlast               => axi_mid_array(11).rlast       ,
    s11_axi_rvalid              => axi_mid_array(11).rvalid      ,
    s11_axi_rready              => axi_mid_array(11).rready      ,
    s12_axi_areset_out_n        => axi_mid_array(12).areset_out_n,
    s12_axi_aclk                => axi_mid_array(12).aclk        ,
    s12_axi_awid                => axi_mid_array(12).awid        ,
    s12_axi_awaddr              => axi_mid_array(12).awaddr      ,
    s12_axi_awlen               => axi_mid_array(12).awlen       ,
    s12_axi_awsize              => axi_mid_array(12).awsize      ,
    s12_axi_awburst             => axi_mid_array(12).awburst     ,
    s12_axi_awlock              => axi_mid_array(12).awlock      ,
    s12_axi_awcache             => axi_mid_array(12).awcache     ,
    s12_axi_awprot              => axi_mid_array(12).awprot      ,
    s12_axi_awqos               => axi_mid_array(12).awqos       ,
    s12_axi_awvalid             => axi_mid_array(12).awvalid     ,
    s12_axi_awready             => axi_mid_array(12).awready     ,
    s12_axi_wdata               => axi_mid_array(12).wdata       ,
    s12_axi_wstrb               => axi_mid_array(12).wstrb       ,
    s12_axi_wlast               => axi_mid_array(12).wlast       ,
    s12_axi_wvalid              => axi_mid_array(12).wvalid      ,
    s12_axi_wready              => axi_mid_array(12).wready      ,
    s12_axi_bid                 => axi_mid_array(12).bid         ,
    s12_axi_bresp               => axi_mid_array(12).bresp       ,
    s12_axi_bvalid              => axi_mid_array(12).bvalid      ,
    s12_axi_bready              => axi_mid_array(12).bready      ,
    s12_axi_arid                => axi_mid_array(12).arid        ,
    s12_axi_araddr              => axi_mid_array(12).araddr      ,
    s12_axi_arlen               => axi_mid_array(12).arlen       ,
    s12_axi_arsize              => axi_mid_array(12).arsize      ,
    s12_axi_arburst             => axi_mid_array(12).arburst     ,
    s12_axi_arlock              => axi_mid_array(12).arlock      ,
    s12_axi_arcache             => axi_mid_array(12).arcache     ,
    s12_axi_arprot              => axi_mid_array(12).arprot      ,
    s12_axi_arqos               => axi_mid_array(12).arqos       ,
    s12_axi_arvalid             => axi_mid_array(12).arvalid     ,
    s12_axi_arready             => axi_mid_array(12).arready     ,
    s12_axi_rid                 => axi_mid_array(12).rid         ,
    s12_axi_rdata               => axi_mid_array(12).rdata       ,
    s12_axi_rresp               => axi_mid_array(12).rresp       ,
    s12_axi_rlast               => axi_mid_array(12).rlast       ,
    s12_axi_rvalid              => axi_mid_array(12).rvalid      ,
    s12_axi_rready              => axi_mid_array(12).rready      ,
    s13_axi_areset_out_n        => axi_mid_array(13).areset_out_n,
    s13_axi_aclk                => axi_mid_array(13).aclk        ,
    s13_axi_awid                => axi_mid_array(13).awid        ,
    s13_axi_awaddr              => axi_mid_array(13).awaddr      ,
    s13_axi_awlen               => axi_mid_array(13).awlen       ,
    s13_axi_awsize              => axi_mid_array(13).awsize      ,
    s13_axi_awburst             => axi_mid_array(13).awburst     ,
    s13_axi_awlock              => axi_mid_array(13).awlock      ,
    s13_axi_awcache             => axi_mid_array(13).awcache     ,
    s13_axi_awprot              => axi_mid_array(13).awprot      ,
    s13_axi_awqos               => axi_mid_array(13).awqos       ,
    s13_axi_awvalid             => axi_mid_array(13).awvalid     ,
    s13_axi_awready             => axi_mid_array(13).awready     ,
    s13_axi_wdata               => axi_mid_array(13).wdata       ,
    s13_axi_wstrb               => axi_mid_array(13).wstrb       ,
    s13_axi_wlast               => axi_mid_array(13).wlast       ,
    s13_axi_wvalid              => axi_mid_array(13).wvalid      ,
    s13_axi_wready              => axi_mid_array(13).wready      ,
    s13_axi_bid                 => axi_mid_array(13).bid         ,
    s13_axi_bresp               => axi_mid_array(13).bresp       ,
    s13_axi_bvalid              => axi_mid_array(13).bvalid      ,
    s13_axi_bready              => axi_mid_array(13).bready      ,
    s13_axi_arid                => axi_mid_array(13).arid        ,
    s13_axi_araddr              => axi_mid_array(13).araddr      ,
    s13_axi_arlen               => axi_mid_array(13).arlen       ,
    s13_axi_arsize              => axi_mid_array(13).arsize      ,
    s13_axi_arburst             => axi_mid_array(13).arburst     ,
    s13_axi_arlock              => axi_mid_array(13).arlock      ,
    s13_axi_arcache             => axi_mid_array(13).arcache     ,
    s13_axi_arprot              => axi_mid_array(13).arprot      ,
    s13_axi_arqos               => axi_mid_array(13).arqos       ,
    s13_axi_arvalid             => axi_mid_array(13).arvalid     ,
    s13_axi_arready             => axi_mid_array(13).arready     ,
    s13_axi_rid                 => axi_mid_array(13).rid         ,
    s13_axi_rdata               => axi_mid_array(13).rdata       ,
    s13_axi_rresp               => axi_mid_array(13).rresp       ,
    s13_axi_rlast               => axi_mid_array(13).rlast       ,
    s13_axi_rvalid              => axi_mid_array(13).rvalid      ,
    s13_axi_rready              => axi_mid_array(13).rready      ,
    s14_axi_areset_out_n        => axi_mid_array(14).areset_out_n,
    s14_axi_aclk                => axi_mid_array(14).aclk        ,
    s14_axi_awid                => axi_mid_array(14).awid        ,
    s14_axi_awaddr              => axi_mid_array(14).awaddr      ,
    s14_axi_awlen               => axi_mid_array(14).awlen       ,
    s14_axi_awsize              => axi_mid_array(14).awsize      ,
    s14_axi_awburst             => axi_mid_array(14).awburst     ,
    s14_axi_awlock              => axi_mid_array(14).awlock      ,
    s14_axi_awcache             => axi_mid_array(14).awcache     ,
    s14_axi_awprot              => axi_mid_array(14).awprot      ,
    s14_axi_awqos               => axi_mid_array(14).awqos       ,
    s14_axi_awvalid             => axi_mid_array(14).awvalid     ,
    s14_axi_awready             => axi_mid_array(14).awready     ,
    s14_axi_wdata               => axi_mid_array(14).wdata       ,
    s14_axi_wstrb               => axi_mid_array(14).wstrb       ,
    s14_axi_wlast               => axi_mid_array(14).wlast       ,
    s14_axi_wvalid              => axi_mid_array(14).wvalid      ,
    s14_axi_wready              => axi_mid_array(14).wready      ,
    s14_axi_bid                 => axi_mid_array(14).bid         ,
    s14_axi_bresp               => axi_mid_array(14).bresp       ,
    s14_axi_bvalid              => axi_mid_array(14).bvalid      ,
    s14_axi_bready              => axi_mid_array(14).bready      ,
    s14_axi_arid                => axi_mid_array(14).arid        ,
    s14_axi_araddr              => axi_mid_array(14).araddr      ,
    s14_axi_arlen               => axi_mid_array(14).arlen       ,
    s14_axi_arsize              => axi_mid_array(14).arsize      ,
    s14_axi_arburst             => axi_mid_array(14).arburst     ,
    s14_axi_arlock              => axi_mid_array(14).arlock      ,
    s14_axi_arcache             => axi_mid_array(14).arcache     ,
    s14_axi_arprot              => axi_mid_array(14).arprot      ,
    s14_axi_arqos               => axi_mid_array(14).arqos       ,
    s14_axi_arvalid             => axi_mid_array(14).arvalid     ,
    s14_axi_arready             => axi_mid_array(14).arready     ,
    s14_axi_rid                 => axi_mid_array(14).rid         ,
    s14_axi_rdata               => axi_mid_array(14).rdata       ,
    s14_axi_rresp               => axi_mid_array(14).rresp       ,
    s14_axi_rlast               => axi_mid_array(14).rlast       ,
    s14_axi_rvalid              => axi_mid_array(14).rvalid      ,
    s14_axi_rready              => axi_mid_array(14).rready      ,
    s15_axi_areset_out_n        => axi_mid_array(15).areset_out_n,
    s15_axi_aclk                => axi_mid_array(15).aclk        ,
    s15_axi_awid                => axi_mid_array(15).awid        ,
    s15_axi_awaddr              => axi_mid_array(15).awaddr      ,
    s15_axi_awlen               => axi_mid_array(15).awlen       ,
    s15_axi_awsize              => axi_mid_array(15).awsize      ,
    s15_axi_awburst             => axi_mid_array(15).awburst     ,
    s15_axi_awlock              => axi_mid_array(15).awlock      ,
    s15_axi_awcache             => axi_mid_array(15).awcache     ,
    s15_axi_awprot              => axi_mid_array(15).awprot      ,
    s15_axi_awqos               => axi_mid_array(15).awqos       ,
    s15_axi_awvalid             => axi_mid_array(15).awvalid     ,
    s15_axi_awready             => axi_mid_array(15).awready     ,
    s15_axi_wdata               => axi_mid_array(15).wdata       ,
    s15_axi_wstrb               => axi_mid_array(15).wstrb       ,
    s15_axi_wlast               => axi_mid_array(15).wlast       ,
    s15_axi_wvalid              => axi_mid_array(15).wvalid      ,
    s15_axi_wready              => axi_mid_array(15).wready      ,
    s15_axi_bid                 => axi_mid_array(15).bid         ,
    s15_axi_bresp               => axi_mid_array(15).bresp       ,
    s15_axi_bvalid              => axi_mid_array(15).bvalid      ,
    s15_axi_bready              => axi_mid_array(15).bready      ,
    s15_axi_arid                => axi_mid_array(15).arid        ,
    s15_axi_araddr              => axi_mid_array(15).araddr      ,
    s15_axi_arlen               => axi_mid_array(15).arlen       ,
    s15_axi_arsize              => axi_mid_array(15).arsize      ,
    s15_axi_arburst             => axi_mid_array(15).arburst     ,
    s15_axi_arlock              => axi_mid_array(15).arlock      ,
    s15_axi_arcache             => axi_mid_array(15).arcache     ,
    s15_axi_arprot              => axi_mid_array(15).arprot      ,
    s15_axi_arqos               => axi_mid_array(15).arqos       ,
    s15_axi_arvalid             => axi_mid_array(15).arvalid     ,
    s15_axi_arready             => axi_mid_array(15).arready     ,
    s15_axi_rid                 => axi_mid_array(15).rid         ,
    s15_axi_rdata               => axi_mid_array(15).rdata       ,
    s15_axi_rresp               => axi_mid_array(15).rresp       ,
    s15_axi_rlast               => axi_mid_array(15).rlast       ,
    s15_axi_rvalid              => axi_mid_array(15).rvalid      ,
    s15_axi_rready              => axi_mid_array(15).rready      ,
    
    m00_axi_areset_out_n        => axi_top.areset_out_n     ,
    m00_axi_aclk                => axi_top.aclk             ,
    m00_axi_awid                => axi_top.awid(3 downto 0) ,
    m00_axi_awaddr              => axi_top.awaddr           ,
    m00_axi_awlen               => axi_top.awlen            ,
    m00_axi_awsize              => axi_top.awsize           ,
    m00_axi_awburst             => axi_top.awburst          ,
    m00_axi_awlock              => axi_top.awlock           ,
    m00_axi_awcache             => axi_top.awcache          ,
    m00_axi_awprot              => axi_top.awprot           ,
    m00_axi_awqos               => axi_top.awqos            ,
    m00_axi_awvalid             => axi_top.awvalid          ,
    m00_axi_awready             => axi_top.awready          ,
    m00_axi_wdata               => axi_top.wdata            ,
    m00_axi_wstrb               => axi_top.wstrb            ,
    m00_axi_wlast               => axi_top.wlast            ,
    m00_axi_wvalid              => axi_top.wvalid           ,
    m00_axi_wready              => axi_top.wready           ,
    m00_axi_bid                 => axi_top.bid(3 downto 0)  ,
    m00_axi_bresp               => axi_top.bresp            ,
    m00_axi_bvalid              => axi_top.bvalid           ,
    m00_axi_bready              => axi_top.bready           ,
    m00_axi_arid                => axi_top.arid(3 downto 0) ,
    m00_axi_araddr              => axi_top.araddr           ,
    m00_axi_arlen               => axi_top.arlen            ,
    m00_axi_arsize              => axi_top.arsize           ,
    m00_axi_arburst             => axi_top.arburst          ,
    m00_axi_arlock              => axi_top.arlock           ,
    m00_axi_arcache             => axi_top.arcache          ,
    m00_axi_arprot              => axi_top.arprot           ,
    m00_axi_arqos               => axi_top.arqos            ,
    m00_axi_arvalid             => axi_top.arvalid          ,
    m00_axi_arready             => axi_top.arready          ,
    m00_axi_rid                 => axi_top.rid(3 downto 0)  ,
    m00_axi_rdata               => axi_top.rdata            ,
    m00_axi_rresp               => axi_top.rresp            ,
    m00_axi_rlast               => axi_top.rlast            ,
    m00_axi_rvalid              => axi_top.rvalid           ,
    m00_axi_rready              => axi_top.rready
  );
  
  -- Connect the top clock
  axi_top.aclk                  <= clk;
  
  -- Set some of the leftover ID bits
  axi_top.awid(7 downto 4)      <= (others => '0');
  axi_top.bid(7 downto 4)       <= (others => '0');  
  axi_top.arid(7 downto 4)      <= (others => '0');
  
end architecture;
