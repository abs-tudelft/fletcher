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
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.Streams.all;
use work.Utils.all;
use work.SimUtils.all;

-- This unit "maximizes" a stream that carries multiple elements per transfer.
-- By "maximization", we mean that the output stream always carries the
-- maximum number of elements per cycle, unless:
--  - the input "last" flag is set
-- This unit forwards backpressure from the output directly to the input and 
-- inserts an optional FIFO 

entity StreamMaximizer is
  generic (

    -- Width of a data element.
    ELEMENT_WIDTH               : natural := 8;

    -- Maximum number of elements per clock.
    COUNT_MAX                   : natural := 4;
    
    -- The number of bits in the count vectors. This must be at least
    -- ceil(log2(COUNT_MAX)) and must be at least 1. If COUNT_MAX is a power of
    -- two and this value equals log2(COUNT_MAX), a zero count implies that all
    -- entries are valid (i.e., there is an implicit '1' bit in front).
    COUNT_WIDTH                 : natural := 2;
    
    -- Whether this unit places the required FIFO itself at the output. If this
    -- set to false, it is required to generate the "almost_not_ready" signal
    -- when the downstream consumer will generate the ready signal in LATENCY
    -- cycles.
    USE_FIFO                    : boolean := true;
    
    -- Whether the barrel shifters and rotators should be backpressured
    BARREL_BACKPRESSURE         : boolean := false
    
  );
  port (

    -- Rising-edge sensitive clock.
    clk                         : in  std_logic;

    -- Active-high synchronous reset.
    reset                       : in  std_logic;

    -- Input stream. dvalid specifies whether the data vector and count are
    -- valid; when low, the whole transfer is ignored by this unit. THAT MEANS
    -- THAT THE LAST FLAG OF A DVALID LOW TRANSFER IS DROPPED. count specifies
    -- the number of valid elements in data (which must be LSB-aligned, LSB
    -- first), with 0 signaling COUNT_MAX instead of 0. The last flag can be
    -- used to break up the output stream.
    in_valid                    : in  std_logic;
    in_ready                    : out std_logic;
    in_dvalid                   : in  std_logic := '1';
    in_data                     : in  std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    in_count                    : in  std_logic_vector(COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, COUNT_WIDTH));
    in_last                     : in  std_logic := '0';

    -- Output stream. last is high when the last element returned was received
    -- with the last flag set.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_has_space               : in  std_logic := '0';
    out_data                    : out std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(COUNT_WIDTH-1 downto 0);
    out_last                    : out std_logic
  );
end StreamMaximizer;

architecture Behavioral of StreamMaximizer is

  constant AMOUNT_WIDTH         : natural := log2ceil(COUNT_MAX);
  constant ROTATE_WIDTH         : natural := AMOUNT_WIDTH+1;

  -- Control will contain the last bit
  constant CTRL_WIDTH           : natural := COUNT_WIDTH + 1;

  type barrel_type is record
    valid                       : std_logic;
    data                        : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    evalid                      : std_logic_vector(COUNT_MAX-1 downto 0);
    ctrl                        : std_logic_vector(CTRL_WIDTH-1 downto 0);
  end record;

  -- Rotate is 1 bit longer than required for the barrel shifter of the 
  -- fall-through registers enable bits
  type reg_type is record
    position                    : unsigned(AMOUNT_WIDTH-1 downto 0);
    barrel                      : barrel_type;
    rotate                      : unsigned(AMOUNT_WIDTH+1-1 downto 0);
    newstream                   : std_logic;
  end record;

  type in_type is record
    ready                       : std_logic;
  end record;

  signal r : reg_type;
  signal d : reg_type;

  signal barrel_ready           : std_logic;
  signal rotated : barrel_type;
  signal rotated_ready          : std_logic;
  
  signal shifter_in_data        : std_logic_vector(2*COUNT_MAX-1 downto 0);
  signal shifter_out_data       : std_logic_vector(2*COUNT_MAX-1 downto 0);
  
  signal enable_buffer          : std_logic_vector(COUNT_MAX-1 downto 0);
  signal enable_output          : std_logic_vector(COUNT_MAX-1 downto 0);

  type line_type is record
    data  : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    valid : std_logic_vector(COUNT_MAX-1 downto 0);
    ctrl  : std_logic_vector(CTRL_WIDTH-1 downto 0);
  end record;

  type freg_type is record
    bufl    : line_type;
    outl    : line_type;
    count   : std_logic_vector(AMOUNT_WIDTH-1 downto 0);
    valid   : std_logic;
    last    : std_logic;
  end record;

  signal fr : freg_type;
  signal fd : freg_type;
  
  signal buf_valid              : std_logic;
  signal buf_ready              : std_logic;
  signal buf_data               : std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
  signal buf_count              : std_logic_vector(AMOUNT_WIDTH-1 downto 0);
  signal buf_last               : std_logic;
  
  constant SDIV                 : natural := 4;
  constant SADD                 : natural := 4;
  constant FIFO_DEPTH_LOG2      : natural := log2ceil(COUNT_MAX/SDIV+SADD);
  
  signal buf_wptr               : std_logic_vector(FIFO_DEPTH_LOG2 downto 0);
  signal buf_rptr               : std_logic_vector(FIFO_DEPTH_LOG2 downto 0);
  signal buf_has_space          : std_logic;  
  
  constant BSI : nat_array := cumulative((
    2 => 1, --last 
    1 => AMOUNT_WIDTH,
    0 => COUNT_MAX*ELEMENT_WIDTH
  ));
  
  signal buf_all                : std_logic_vector(BSI(3)-1 downto 0);
  signal out_all                : std_logic_vector(BSI(3)-1 downto 0);
  
  signal rotators_ready         : std_logic;
  signal downstream_space       : std_logic;

begin

  seq_proc: process(clk) is
  begin
    if rising_edge(clk) then
      r <= d;
      if reset = '1' then
        r.position <= (others => '0');
        r.barrel.valid <= '0';
        r.newstream <= '1';
      end if;
    end if;
  end process;

  comb_proc: process(r,
    in_valid, in_dvalid, in_data, in_count, in_last,
    rotators_ready, downstream_space
  ) is
    variable v: reg_type;
    variable i: in_type;
    
    variable extsum : unsigned(AMOUNT_WIDTH downto 0);
  begin
    v := r;

    -- Input is ready when valid is asserted by default
    if in_valid = '1' and downstream_space = '1' then
      i.ready := '1';
    else
      i.ready := '0';
    end if;

    -- If the barrel output is valid, but not handshaked, the input must be
    -- stalled immediately
    if r.barrel.valid = '1' and rotators_ready = '0' then
      i.ready := '0';
    end if;

    -- If the barrel output is handshaked, but there is no new valid data
    -- or if we do not use backpressure, the output is always accepted by the barrels
    if (BARREL_BACKPRESSURE and r.barrel.valid = '1' and rotators_ready = '1' and (in_valid = '0' or in_dvalid = '0'))
       or (not BARREL_BACKPRESSURE and r.barrel.valid = '1')
    then
      -- Invalidate the output
      v.barrel.valid := '0';
    end if;

    -- If the input is valid, and the barrel output has no data or is
    -- handshaked we may advance the stream
    if downstream_space = '1' and in_valid = '1' and in_dvalid = '1' and
       (r.barrel.valid = '0' or (r.barrel.valid = '1' and rotators_ready = '1'))
    then
      extsum := unsigned("0" & std_logic_vector(r.position)) + unsigned(in_count);
      
      -- The rotation for this input is the current position.
      v.rotate(AMOUNT_WIDTH)              := '0';
      v.rotate(AMOUNT_WIDTH-1 downto 0)   := r.position;
      
      -- Data for barrel shifter
      v.barrel.data                       := in_data;
      
      -- Control contains new position and last signal
      v.barrel.ctrl(AMOUNT_WIDTH downto 1) := std_logic_vector(extsum(AMOUNT_WIDTH-1 downto 0));
      v.barrel.ctrl(0)                    := in_last;
      
      -- Generate element valids by one-hot encoding the input count when the input is ready
      v.barrel.evalid                     := work.Utils.cnt2oh(unsigned(in_count), COUNT_MAX);
      
      -- We add COUNT_MAX to the rotation to make sure after we start a new
      -- stream or we returned to starting position the elements get buffered
      -- and not direclty sent to the output line. There might still be 
      -- something on the output line from the previous stream.
      if v.newstream = '1' or r.position = 0 then
        v.rotate := v.rotate + COUNT_MAX;
        v.newstream := '0';
      end if;
    
      -- If this is the last handshake in the stream
      if in_last = '1' then
        -- The position for the next handshake is zero
        v.position := (others => '0');
        v.newstream := '1';
      else
        -- Calculate the position for the potentially next handshake
        v.position := extsum(AMOUNT_WIDTH-1 downto 0);
      end if;
      
      -- Validate the data for the barrel rotator and shifter
      v.barrel.valid := '1';

    end if;

    in_ready <= i.ready;

    d <= v;
  end process;

  rotators_ready <= barrel_ready when BARREL_BACKPRESSURE else '1';
  
  downstream_space <= '1'           when BARREL_BACKPRESSURE else
                      buf_has_space when USE_FIFO else
                      out_has_space;

  -- Barrel shift the elements according to the position the first element
  -- should be in for the fall-through registers. The position is sent along
  -- the control stream so it can be decoded to determine if the buffered line
  -- or the output line should be enabled.
  element_rotator_inst: StreamBarrel
    generic map (
      ELEMENT_WIDTH             => ELEMENT_WIDTH,
      COUNT_MAX                 => COUNT_MAX,
      AMOUNT_WIDTH              => AMOUNT_WIDTH,
      AMOUNT_MAX                => COUNT_MAX,
      DIRECTION                 => "left",
      OPERATION                 => "rotate",
      STAGES                    => COUNT_MAX/SDIV,
      BACKPRESSURE              => false,
      CTRL_WIDTH                => CTRL_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => r.barrel.valid,
      in_ready                  => barrel_ready,
      in_rotate                 => std_logic_vector(r.rotate(AMOUNT_WIDTH-1 downto 0)),
      in_data                   => r.barrel.data,
      in_ctrl                   => r.barrel.ctrl,
      out_valid                 => rotated.valid,
      out_ready                 => rotated_ready,
      out_data                  => rotated.data,
      out_ctrl                  => rotated.ctrl
    );

  -- Padd the element valids with zeros in front before shifting
  shifter_in_data(2*COUNT_MAX-1 downto COUNT_MAX) <= (others => '0');
  shifter_in_data(  COUNT_MAX-1 downto 0)         <= r.barrel.evalid;  

  one_hot_shifter_inst: StreamBarrel
    generic map (
      ELEMENT_WIDTH             => 1,
      COUNT_MAX                 => 2*COUNT_MAX,
      AMOUNT_WIDTH              => AMOUNT_WIDTH+1,
      AMOUNT_MAX                => COUNT_MAX,
      DIRECTION                 => "left",
      OPERATION                 => "shift",
      BACKPRESSURE              => false,
      STAGES                    => COUNT_MAX/SDIV
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => r.barrel.valid,
      in_rotate                 => std_logic_vector(r.rotate),
      in_data                   => shifter_in_data,
      in_ctrl                   => "0",
      out_ready                 => rotated_ready,
      out_data                  => shifter_out_data
    );
  
  enable_buffer <= shifter_out_data(2*COUNT_MAX-1 downto COUNT_MAX);
  enable_output <= shifter_out_data(  COUNT_MAX-1 downto 0);

  fseq_proc: process(clk) is
  begin
    if rising_edge(clk) then

      fr <= fd;

      if reset = '1' then
        -- Reset output valid
        fr.valid <= '0';
        
        -- Reset last
        fr.last <= '0';
        
        -- Reset output count
        fr.count <= (others => '0');
        
        -- Reset fall-through register valids
        fr.outl.valid <= (others => '0');
        fr.bufl.valid <= (others => '0');
        
        -- Reset the last signals or output might be validated.
        fr.outl.ctrl(0) <= '0';
        fr.bufl.ctrl(0) <= '0';
      end if;
    end if;
  end process;

  fcomb_proc: process(fr,
    rotated,
    enable_buffer, enable_output,
    buf_ready
  ) is
    variable fv: freg_type;
    variable i: in_type;

    variable eb : std_logic_vector(COUNT_MAX-1 downto 0);
    variable eo : std_logic_vector(COUNT_MAX-1 downto 0);
  begin
    fv := fr;

    i.ready := '1';
    if fr.valid = '1' and buf_ready = '0' then
      i.ready := '0';
    end if;
    
    -- If output is handshaked
    if fr.valid = '1' and buf_ready = '1' then      
      -- Reset outputs
      fv.valid := '0';
      fv.last := '0';
      fv.outl.ctrl(0) := '0';
      fv.outl.valid := (others => '0');
      --fv.bufl.ctrl(0) := '0';
      --fv.bufl.valid := (others => '0');
      --pragma translate off
      fv.count := (others => 'U');
      fv.outl.data := (others => 'U');
      fv.bufl.data := (others => 'U');
      --pragma translate on
    end if;

    -- Advance if there is some valid input or there is still
    -- data in the buffer.
    if (rotated.valid = '1' or or_reduce(fr.bufl.valid) = '1') and
       (fr.valid = '0' or (fr.valid = '1' and buf_ready = '1'))
    then

      -- Clear any valid bits from the lines by default if the current output 
      -- is valid (and handshaked by the outer if statement)
      if fr.valid = '1' and buf_ready = '1' then
        fv.valid := '0';
        fv.last := '0';
        fv.outl.ctrl(0) := '0';
        fv.outl.valid := (others => '0');
        fv.bufl.ctrl(0) := '0';
        fv.bufl.valid := (others => '0');
        --pragma translate off
        fv.count := (others => 'U');
        fv.outl.data := (others => 'U');
        fv.bufl.data := (others => 'U');
        --pragma translate on
      end if;
      
      -- Get the enables
      eb := enable_buffer;
      eo := enable_output;
                        
      -- Move the control data from the buffer to the output when it is last
      if fr.bufl.ctrl(0) = '1' then
        fv.outl.ctrl := fr.bufl.ctrl;
        -- Clear the last bit from the buffer line
        fv.bufl.ctrl(0) := '0';
      end if;
      
      -- If there is something to buffer, buffer the control data too
      if or_reduce(eb) = '1' and rotated.valid = '1' then
        fv.bufl.ctrl := rotated.ctrl;
      end if;
      
      -- If there is nothing to buffer but there is something going to the output,
      -- forward the control.
      if or_reduce(eb) = '0' and rotated.valid = '1' then
        fv.outl.ctrl := rotated.ctrl;
      end if;

      for e in 0 to COUNT_MAX-1 loop
        -- If this element is valid on the buffer line 
        if fr.bufl.valid(e) = '1' then
          -- Pass it to the output line.
          fv.outl.data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH)
            := fr.bufl.data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH);
          -- Copy the valid from the buffer line
          fv.outl.valid(e) := fr.bufl.valid(e);
          -- Make the data invalid on the buffer line
          fv.bufl.valid(e) := '0';
          --pragma translate off
          fv.bufl.data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH)
            := (others => 'U');
          --pragma translate on
        end if;

        -- If this element should be passed through to the output if the data
        -- is valid
        if eo(e) = '1' and rotated.valid = '1' then
          -- Pass it to the output line
          fv.outl.data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH)
            := rotated.data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH);
          -- Make the data valid on the output line
          fv.outl.valid(e) := '1';
        end if;
        
        if eb(e) = '1' and rotated.valid = '1' then
          -- Any data that is not passed through should be buffered
          fv.bufl.data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH)
            := rotated.data((e+1)*ELEMENT_WIDTH-1 downto e*ELEMENT_WIDTH);
          -- Make the data valid on the buffer line.
          fv.bufl.valid(e) := '1';
        end if;
      end loop;
      
      -- Set the last signal
      fv.last   := fv.outl.ctrl(0);
      
      -- Count is the position
      if fv.last = '1' then
        fv.count := fv.outl.ctrl(AMOUNT_WIDTH downto 1);
      else
        fv.count := (others => '0');
      end if;
      
      -- If all data in output line are valid or if the last signal is high,
      -- validate the output
      fv.valid := and_reduce(fv.outl.valid) or fv.last;
      
    end if;

    -- Combinatorial outputs
    fd <= fv;

    rotated_ready <= i.ready;

    -- Registered outputs

    buf_valid <= fr.valid;
    
    buf_data  <= fr.outl.data;
    buf_count <= fr.count;
    buf_last  <= fr.last;
  end process;
    
  use_fifo_gen: if USE_FIFO generate
  
    buf_all(                BSI(2)) <= buf_last;
    buf_all(BSI(2)-1 downto BSI(1)) <= buf_count;
    buf_all(BSI(1)-1 downto BSI(0)) <= buf_data;
  
    fifo_inst: StreamFIFO
    generic map (
      DEPTH_LOG2  => FIFO_DEPTH_LOG2,
      DATA_WIDTH  => BSI(3)
    )
    port map (
      in_clk      => clk,
      in_reset    => reset,
      in_valid    => buf_valid,
      in_ready    => buf_ready,
      in_data     => buf_all,
      in_rptr     => buf_rptr,
      in_wptr     => buf_wptr,
      out_clk     => clk,
      out_reset   => reset,
      out_valid   => out_valid,
      out_ready   => out_ready,
      out_data    => out_all
    );
    
    fifo_has_space_proc: process(buf_rptr, buf_wptr) is
      variable space : unsigned(FIFO_DEPTH_LOG2 downto 0);
    begin
      space := to_unsigned(2**FIFO_DEPTH_LOG2,FIFO_DEPTH_LOG2+1) - unsigned(abs(signed(unsigned(buf_wptr) - unsigned(buf_rptr))));
      
      if space < COUNT_MAX/SDIV+SADD then
        buf_has_space <= '0';
      else
        buf_has_space <= '1';
      end if;      
    end process;
    
    out_last                    <= out_all(                BSI(2));
    out_count                   <= resize_count(out_all(BSI(2)-1 downto BSI(1)), COUNT_WIDTH);
    out_data                    <= out_all(BSI(1)-1 downto BSI(0));
    
  end generate;
  no_fifo_gen: if not USE_FIFO generate
    out_valid <= buf_valid;
    buf_ready <= out_ready;
    out_data  <= buf_data;
    out_count <= buf_count;
    out_last  <= buf_last;    
  end generate;
  
  -- In simulation, check if no data is lost because of too little backpressure.
  --pragma translate off
  check_bp: process(clk) is
  begin
    if rising_edge(clk) then
      if rotated.valid = '1' and rotated_ready = '0' and not BARREL_BACKPRESSURE then
        report "Fall-through registers didn't catch non-backpressured barrel output."
        severity failure;
      end if;
    end if;
  end process;
  --pragma translate on

end Behavioral;

