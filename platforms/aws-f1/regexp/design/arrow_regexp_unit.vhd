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

library work;
use work.Utils.all;
use work.Arrow.all;
use work.arrow_regexp_pkg.all;

-- A component performing RegExp matching on an Apache Arrow Column
--
-- This is a single unit doing the regular expression matching.
-- Here you can find the instantiation of the ColumnReader, which generates
-- its internal structure according to a configuration string which can
-- be derived from an Arrow Schema.
entity arrow_regexp_unit is
  generic (
    NUM_REGEX                   : natural := 16;
    BUS_ADDR_WIDTH              : natural;
    BUS_DATA_WIDTH              : natural;
    BUS_LEN_WIDTH               : natural;
    BUS_ID_WIDTH                : natural;
    BUS_BURST_LENGTH            : natural;
    BUS_RESP_WIDTH              : natural;
    BUS_WSTRB_WIDTH             : natural;
    REG_WIDTH                   : natural
  );

  port (
    clk                         : in  std_logic;
    reset_n                     : in  std_logic;

    control_reset               : in  std_logic;
    control_start               : in  std_logic;
    reset_start                 : out std_logic;
    
    busy                        : out std_logic;
    done                        : out std_logic;
    
    firstidx                    : in  std_logic_vector(REG_WIDTH-1 downto 0);
    lastidx                     : in  std_logic_vector(REG_WIDTH-1 downto 0);
    
    off_hi                      : in  std_logic_vector(REG_WIDTH-1 downto 0);
    off_lo                      : in  std_logic_vector(REG_WIDTH-1 downto 0);

    utf8_hi                     : in  std_logic_vector(REG_WIDTH-1 downto 0);
    utf8_lo                     : in  std_logic_vector(REG_WIDTH-1 downto 0);
    
    matches                     : out std_logic_vector(NUM_REGEX*REG_WIDTH-1 downto 0);
    
    ---------------------------------------------------------------------------
    -- AXI4 master
    --
    -- To be connected to the DDR controllers (through CL_DMA_PCIS_SLV)
    ---------------------------------------------------------------------------
    -- Write ports
    m_axi_awid                  : out std_logic_vector(BUS_ID_WIDTH-1 downto 0);
    m_axi_awaddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    m_axi_awlen                 : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    m_axi_awsize                : out std_logic_vector(2 downto 0);
    m_axi_awvalid               : out std_logic;

    m_axi_wdata                 : out std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    m_axi_wstrb                 : out std_logic_vector(BUS_WSTRB_WIDTH-1 downto 0);
    m_axi_wlast                 : out std_logic;
    m_axi_wvalid                : out std_logic;

    m_axi_bready                : out std_logic;

    -- Read address channel
    m_axi_araddr                : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    m_axi_arid                  : out std_logic_vector(BUS_ID_WIDTH-1 downto 0);
    m_axi_arlen                 : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    m_axi_arvalid               : out std_logic;
    m_axi_arready               : in  std_logic;
    m_axi_arsize                : out std_logic_vector(2 downto 0);

    -- Read data channel
    m_axi_rdata                 : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    m_axi_rresp                 : in  std_logic_vector(BUS_RESP_WIDTH-1 downto 0);
    m_axi_rlast                 : in  std_logic;
    m_axi_rvalid                : in  std_logic;
    m_axi_rready                : out std_logic
  );
end entity arrow_regexp_unit;

architecture rtl of arrow_regexp_unit is
  -----------------------------------------------------------------------------
  -- ColumnReader Interface
  -----------------------------------------------------------------------------
  signal out_valid              : std_logic_vector(  1 downto 0);
  signal out_ready              : std_logic_vector(  1 downto 0);
  signal out_last               : std_logic_vector(  1 downto 0);
  signal out_dvalid             : std_logic_vector(  1 downto 0);
  signal out_data               : std_logic_vector( 66 downto 0);

  signal busreq_len             : std_logic_vector(log2ceil(BUS_BURST_LENGTH)+1 downto 0);
  
  -- Command Stream
  type command_t is record
    valid                       : std_logic;
    ready                       : std_logic;
    firstIdx                    : std_logic_vector( 31 downto 0);
    lastIdx                     : std_logic_vector( 31 downto 0);
    ctrl                        : std_logic_vector(127 downto 0);
  end record;
  
  signal cmd_ready              : std_logic;
  
  -- Output Streams
  type len_stream_in_t is record
    valid                       : std_logic;
    dvalid                      : std_logic;
    last                        : std_logic;
    data                        : std_logic_vector( 31 downto 0);
  end record;

  type utf8_stream_in_t is record
    valid                       : std_logic;
    dvalid                      : std_logic;
    last                        : std_logic;
    count                       : std_logic_vector(  2 downto 0);
    data                        : std_logic_vector( 31 downto 0);
  end record;

  type str_elem_in_t is record
    len                         : len_stream_in_t;
    utf8                        : utf8_stream_in_t;
  end record;
  
  procedure conv_streams_in (
    signal valid                : in  std_logic_vector( 1 downto 0);
    signal dvalid               : in  std_logic_vector( 1 downto 0);
    signal last                 : in  std_logic_vector( 1 downto 0);
    signal data                 : in  std_logic_vector(66 downto 0);
    signal str_elem_in          : out str_elem_in_t
  ) is
  begin
    str_elem_in.len.data        <= data  (31 downto  0);
    str_elem_in.len.valid       <= valid (0);
    str_elem_in.len.dvalid      <= dvalid(0);
    str_elem_in.len.last        <= last  (0);

    str_elem_in.utf8.count      <= data  (66 downto 64);
    str_elem_in.utf8.data       <= data  (63 downto 32);
    str_elem_in.utf8.valid      <= valid (1);
    str_elem_in.utf8.dvalid     <= dvalid(1);
    str_elem_in.utf8.last       <= last  (1);
  end procedure;
  
  type len_stream_out_t is record
    ready                       : std_logic;
  end record;
  
  type utf8_stream_out_t is record
    ready                       : std_logic;
  end record;
  
  type str_elem_out_t is record
    len                         : len_stream_out_t;
    utf8                        : utf8_stream_out_t;
  end record;
  
  procedure conv_streams_out (
    signal str_elem_out         : in  str_elem_out_t;
    signal out_ready            : out std_logic_vector(1 downto 0)
  ) is
  begin
    out_ready(0)                <= str_elem_out.len.ready;
    out_ready(1)                <= str_elem_out.utf8.ready;
  end procedure;
  
  signal str_elem_in            : str_elem_in_t;
  signal str_elem_out           : str_elem_out_t;
  
  type regex_in_t is record
    valid                       : std_logic;
    data                        : std_logic_vector(31 downto 0);
    mask                        : std_logic_vector(3 downto 0);
    last                        : std_logic;
  end record;
  
  type regex_out_t is record
    valid                       : std_logic_vector(NUM_REGEX-1 downto 0);
    match                       : std_logic_vector(NUM_REGEX-1 downto 0);
    error                       : std_logic_vector(NUM_REGEX-1 downto 0);
  end record;
  
  type regex_t is record
    input                       : regex_in_t;
    output                      : regex_out_t;
  end record;
  
  signal regex_input            : regex_in_t;
  signal regex_output           : regex_out_t;
  
  -----------------------------------------------------------------------------
  -- UserCore
  -----------------------------------------------------------------------------
  type state_t is (STATE_IDLE, STATE_RESET_START, STATE_REQUEST, STATE_BUSY, STATE_DONE);

  -- Control and status bits
  type cs_t is record
    reset_start                 : std_logic;
    done                        : std_logic;
    busy                        : std_logic;
  end record;

  type reg_array is array (0 to NUM_REGEX-1) of unsigned(REG_WIDTH-1 downto 0);

  type reg is record
    state                       : state_t;
    cs                          : cs_t;
    
    command                     : command_t;
    
    regex                       : regex_t;
    
    str_elem_out                : str_elem_out_t;
    str_elem_in                 : str_elem_in_t;
    
    processed                   : reg_array;
    matches                     : reg_array;
  end record;

  signal r                      : reg;
  signal d                      : reg;
  
begin
  -----------------------------------------------------------------------------
  -- ColumnReader
  -----------------------------------------------------------------------------
  cr: ColumnReader
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => log2ceil(BUS_BURST_LENGTH) + 2,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_LENGTH          => BUS_BURST_LENGTH,
      INDEX_WIDTH               => 32,
      CFG                       => "listprim(8;epc=4,bus_fifo_depth=128,idx_bus_fifo_depth=128)",
      CMD_TAG_ENABLE            => false,
      CMD_TAG_WIDTH             => 1
    )
    port map (
      bus_clk                   => clk,
      bus_reset                 => not(reset_n),
      acc_clk                   => clk,
      acc_reset                 => not(reset_n),
      cmd_valid                 => d.command.valid,
      cmd_ready                 => cmd_ready,
      cmd_firstIdx              => d.command.firstIdx,
      cmd_lastIdx               => d.command.lastIdx,
      cmd_ctrl                  => d.command.ctrl,
      cmd_tag                   => (others => '0'), -- CMD_TAG_ENABLE is false
      unlock_valid              => open,
      unlock_ready              => '1',
      unlock_tag                => open,
      busReq_valid              => m_axi_arvalid,
      busReq_ready              => m_axi_arready,
      busReq_addr               => m_axi_araddr,
      busReq_len                => busreq_len,
      busResp_valid             => m_axi_rvalid,
      busResp_ready             => m_axi_rready,
      busResp_data              => m_axi_rdata,
      busResp_last              => m_axi_rlast,
      out_valid                 => out_valid,
      out_ready                 => out_ready,
      out_last                  => out_last,
      out_dvalid                => out_dvalid,
      out_data                  => out_data
    );

  -----------------------------------------------------------------------------
  -- AXI Master
  -----------------------------------------------------------------------------

  -- Tie off read channel ID
  m_axi_arid    <= (others => '0');

  -- Tie off write channels:
  m_axi_awid    <= (others => '0');
  m_axi_awaddr  <= (others => '0');
  m_axi_awlen   <= (others => '0');
  m_axi_awsize  <= (others => '0');
  m_axi_awvalid <= '0';

  m_axi_wdata   <= (others => '0');
  m_axi_wstrb   <= (others => '0');
  m_axi_wlast   <= '0';
  m_axi_wvalid  <= '0';

  m_axi_bready  <= '0';

  -- Convert to AXI Bus request burst length
  
  -- Normal operation:
  m_axi_arlen                   <= slv(u(busreq_len) - 1)(m_axi_arlen'range);        -- Convert to AXI bus sizes
  m_axi_arsize                  <= slv(u(log2ceil(BUS_DATA_WIDTH / 8),3));  -- Corresponding to ColumnReader data width.
  
  -- Output
  str_elem_out <= d.str_elem_out;

  -- Convert the stream inputs and outputs to something readable
  conv_streams_in(out_valid, out_dvalid, out_last, out_data, str_elem_in);
  conv_streams_out(str_elem_out, out_ready);
  
  -- Control & Status
  reset_start                   <= r.cs.reset_start;
  done                          <= r.cs.done;
  busy                          <= r.cs.busy;

  -----------------------------------------------------------------------------
  -- A UserCore that counts matches to the RegEx: .*[Kk][Ii][Tt][Tt][Ee][Nn].*
  -----------------------------------------------------------------------------
  sm_seq: process(clk) is
  begin
    if rising_edge(clk) then
      if reset_n = '0' or control_reset = '1' then
        r.state                 <= STATE_IDLE;
      else
        r                       <= d;
      end if;
    end if;
  end process;

  sm_comb: process( r, 
                    cmd_ready, 
                    str_elem_in, 
                    regex_output, 
                    firstidx, 
                    lastidx, 
                    off_hi, 
                    off_lo, 
                    utf8_hi, 
                    utf8_lo, 
                    control_start, 
                    control_reset) 
  is
    variable v                  : reg;
  begin
    v                           := r;
    -- Inputs:
    v.command.ready             := cmd_ready;
    v.str_elem_in               := str_elem_in;
    v.regex.output              := regex_output;
    
    -- Default outputs:
    v.command.valid             := '0';
    
    v.str_elem_out.len.ready    := '0';
    v.str_elem_out.utf8.ready   := '0';
    
    v.regex.input.valid         := '0';
    v.regex.input.last          := '0';

    case v.state is
      when STATE_IDLE =>
        v.cs.busy               := '0';
        v.cs.done               := '0';
        v.cs.reset_start        := '0';

        v.processed             := (others => (others => '0'));
        v.matches               := (others => (others => '0'));

        if control_start = '1' then
          v.state               := STATE_RESET_START;
          v.cs.reset_start      := '1';
        end if;
      
      when STATE_RESET_START =>
        v.cs.busy               := '1';
        v.cs.done               := '0';
        
        if control_start = '0' then
          v.state               := STATE_REQUEST;
        end if;
        
      when STATE_REQUEST =>
        v.cs.done               := '0';
        v.cs.busy               := '1';
        v.cs.reset_start        := '0';

        -- First four argument registers are buffer addresses
        -- MSBs are index buffer address
        v.command.ctrl(127 downto 96) := off_hi;
        v.command.ctrl( 95 downto 64) := off_lo;
        -- LSBs are data buffer address
        v.command.ctrl( 63 downto 32) := utf8_hi;
        v.command.ctrl( 31 downto  0) := utf8_lo;

        -- Next two argument registers are first and last index
        v.command.firstIdx      := firstIdx;
        v.command.lastIdx       := lastIdx;

        -- Make command valid
        v.command.valid         := '1';

        -- Wait for command accepted
        if v.command.ready = '1' then
          report "RegExp unit requested strings";
          v.state               := STATE_BUSY;
        end if;

      when STATE_BUSY =>
        v.cs.done               := '0';
        v.cs.busy               := '1';
        v.cs.reset_start        := '0';

        -- Always ready to receive length
        v.str_elem_out.len.ready := '1';
        
        if v.str_elem_in.len.valid = '1' then
          -- Do something when this is the last string
        end if;
        if (v.str_elem_in.len.last = '1') and
           (v.processed(0) = u(v.command.lastIdx) - u(v.command.firstIdx))
        then
          report "RegEx unit is done";
          for P in 0 to NUM_REGEX-1 loop
            report "PROCESSED: " & integer'image(P) & " " & integer'image(int(v.processed(P)));
            report "MATCHED: " & integer'image(P) & " " & integer'image(int(v.matches(P)));
          end loop;
          
          v.state               := STATE_DONE;
        end if;
        
        -- Always ready to receive utf8 char
        v.str_elem_out.utf8.ready := '1';
        
        if v.str_elem_in.utf8.valid = '1' then
          -- Do something for every utf8 char
          v.regex.input.valid   := '1';
          v.regex.input.data    := v.str_elem_in.utf8.data;
          
          -- One hot encode mask          
          case v.str_elem_in.utf8.count is
            when "001"          => v.regex.input.mask := "0001";
            when "010"          => v.regex.input.mask := "0011";
            when "011"          => v.regex.input.mask := "0111";
            when "100"          => v.regex.input.mask := "1111";
            when others         => v.regex.input.mask := "0000";
          end case;
          
        end if;
        if v.str_elem_in.utf8.last = '1' then
          -- Do something when this is the last utf8 char
          v.regex.input.last    := '1';
        end if;

        for P in 0 to NUM_REGEX-1 loop
          if v.regex.output.valid(P) = '1' then
            v.processed(P)      := v.processed(P) + 1;
            if v.regex.output.match(P) = '1' then
              v.matches(P)      := v.matches(P) + 1;
            end if;
          end if;
        end loop;

      when STATE_DONE =>
        v.cs.done               := '1';
        v.cs.busy               := '0';
        v.cs.reset_start        := '0';

        if control_reset = '1' or control_start = '1' then
          v.state               := STATE_IDLE;
        end if;
    end case;

    d                           <= v;
  end process;
  
  -- Connect matches reg to output
  match_connect: for P in 0 to NUM_REGEX-1 generate
    matches((P+1)*REG_WIDTH-1 downto P*REG_WIDTH) <= slv(r.matches(P));
  end generate;
  
  -------------------------------------------------------------------------------
  -- RegEx components generated by vhdre generator
  -------------------------------------------------------------------------------
  regex_input                   <= d.regex.input;
  
  -- May we be forgiven for our sins:
  r00 : bird    generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid( 0),out_match=>regex_output.match( 0 downto  0),out_error=>regex_output.error( 0));
  r01 : bunny   generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid( 1),out_match=>regex_output.match( 1 downto  1),out_error=>regex_output.error( 1));  
  r02 : cat     generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid( 2),out_match=>regex_output.match( 2 downto  2),out_error=>regex_output.error( 2));  
  r03 : dog     generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid( 3),out_match=>regex_output.match( 3 downto  3),out_error=>regex_output.error( 3));  
  r04 : ferret  generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid( 4),out_match=>regex_output.match( 4 downto  4),out_error=>regex_output.error( 4));  
  r05 : fish    generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid( 5),out_match=>regex_output.match( 5 downto  5),out_error=>regex_output.error( 5));  
  r06 : gerbil  generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid( 6),out_match=>regex_output.match( 6 downto  6),out_error=>regex_output.error( 6));  
  r07 : hamster generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid( 7),out_match=>regex_output.match( 7 downto  7),out_error=>regex_output.error( 7));  
  r08 : horse   generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid( 8),out_match=>regex_output.match( 8 downto  8),out_error=>regex_output.error( 8));  
  r09 : kitten  generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid( 9),out_match=>regex_output.match( 9 downto  9),out_error=>regex_output.error( 9));  
  r10 : lizard  generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid(10),out_match=>regex_output.match(10 downto 10),out_error=>regex_output.error(10));  
  r11 : mouse   generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid(11),out_match=>regex_output.match(11 downto 11),out_error=>regex_output.error(11));  
  r12 : puppy   generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid(12),out_match=>regex_output.match(12 downto 12),out_error=>regex_output.error(12));  
  r13 : rabbit  generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid(13),out_match=>regex_output.match(13 downto 13),out_error=>regex_output.error(13));  
  r14 : rat     generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid(14),out_match=>regex_output.match(14 downto 14),out_error=>regex_output.error(14));  
  r15 : turtle  generic map (BPC=> 4) port map (clk=>clk,reset=>not(reset_n),in_valid=>regex_input.valid,in_mask=>regex_input.mask,in_data=>regex_input.data,in_last=>regex_input.last,out_valid=>regex_output.valid(15),out_match=>regex_output.match(15 downto 15),out_error=>regex_output.error(15));  

end architecture;
