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
use work.UTF8StringGen_pkg.all;
use work.Stream_pkg.all;

entity UTF8StringGen is
  generic (
    -- Arrow related parameters
    INDEX_WIDTH                 : natural :=   32;
    ELEMENT_WIDTH               : natural :=    8;
    ELEMENT_COUNT_MAX           : natural :=    8;
    ELEMENT_COUNT_WIDTH         : natural :=    4;
    
    -- Internal length width. Is the log2 of the maximum length + 1
    LEN_WIDTH                   : natural :=    8;

    -- Depth of the internal length buffer
    LENGTH_BUFFER_DEPTH         : natural :=    8;
    
    -- Whether to put slices on the output streams
    LEN_SLICE                   : boolean := true;
    UTF8_SLICE                  : boolean := true
  );
  port (
    clk                         : in  std_logic;
    reset                       : in  std_logic;

    cmd_valid                   : in  std_logic;
    cmd_ready                   : out std_logic;
    cmd_len                     : in  std_logic_vector(INDEX_WIDTH-1 downto 0);
    cmd_strlen_min              : in  std_logic_vector(LEN_WIDTH-1 downto 0);
    cmd_strlen_mask             : in  std_logic_vector(LEN_WIDTH-1 downto 0);

    len_valid                   : out std_logic;
    len_ready                   : in  std_logic;
    len_data                    : out std_logic_vector(INDEX_WIDTH-1 downto 0);
    len_last                    : out std_logic;
    len_dvalid                  : out std_logic;

    utf8_valid                  : out std_logic;
    utf8_ready                  : in  std_logic;
    utf8_data                   : out std_logic_vector(ELEMENT_COUNT_MAX * ELEMENT_WIDTH-1 downto 0);
    utf8_count                  : out std_logic_vector(ELEMENT_COUNT_WIDTH-1 downto 0);
    utf8_last                   : out std_logic;
    utf8_dvalid                 : out std_logic
  );
end entity;

architecture Behavorial of UTF8StringGen is

  -- Length state machine
  type state_type is (IDLE, PASS);

  type len_record is record
    ready                       : std_logic;
    valid                       : std_logic;
    data                        : std_logic_vector(LEN_WIDTH-1 downto 0);
    last                        : std_logic;
    dvalid                      : std_logic;
  end record;

  type cmd_in_record is record
    len                         : unsigned(INDEX_WIDTH-1 downto 0);
    min                         : unsigned(LEN_WIDTH-1 downto 0);
    mask                        : unsigned(LEN_WIDTH-1 downto 0);
  end record;

  type regs_record is record
    state                       : state_type;
    cmd                         : cmd_in_record;
  end record;

  type cmd_out_record is record
    ready                       : std_logic;
  end record;

  type out_record is record
    cmd                         : cmd_out_record;
    len                         : len_record;
  end record;

  signal r                      : regs_record;
  signal d                      : regs_record;

  -- Internal length output stream
  signal int_len_valid          : std_logic;
  signal int_len_ready          : std_logic;
  signal int_len_data           : std_logic_vector(LEN_WIDTH-1 downto 0);
  signal int_len_last           : std_logic;
  signal int_len_dvalid         : std_logic;

  -- Signals to length buffer
  signal len_buf_valid          : std_logic;
  signal len_buf_ready          : std_logic;
  signal len_buf_all            : std_logic_vector(1+1+LEN_WIDTH-1 downto 0);

  -- Buffered length stream
  signal buf_all                : std_logic_vector(1+1+LEN_WIDTH-1 downto 0);
  signal buf_valid              : std_logic;
  signal buf_ready              : std_logic;
  signal buf_data               : std_logic_vector(LEN_WIDTH-1 downto 0);
  signal buf_last               : std_logic;
  signal buf_dvalid             : std_logic;

  -- UTF8 (string) state machine

  -- Maximum count
  constant COUNT_MAX_VAL        : unsigned(ELEMENT_COUNT_WIDTH-1 downto 0) := to_unsigned(ELEMENT_COUNT_MAX, ELEMENT_COUNT_WIDTH);

  type utf_record is record
    ready                       : std_logic;
    valid                       : std_logic;
    data                        : std_logic_vector(ELEMENT_COUNT_MAX * ELEMENT_WIDTH-1 downto 0);
    count                       : unsigned(ELEMENT_COUNT_WIDTH-1 downto 0);
    last                        : std_logic;
    dvalid                      : std_logic;
  end record;

  type sregs_record is record
    state                       : state_type;
    len                         : unsigned(LEN_WIDTH-1 downto 0);
  end record;

  type buf_out_record is record
    ready                       : std_logic;
  end record;

  type sout_record is record
    buf                         : buf_out_record;
    utf                         : utf_record;
  end record;

  signal rs                     : sregs_record;
  signal ds                     : sregs_record;

  -- Signals to/from the length generator
  signal len_gen_valid          : std_logic;
  signal len_gen_ready          : std_logic;
  signal len_gen_data           : std_logic_vector(LEN_WIDTH-1 downto 0);

  -- Signals to/from the utf generator
  signal utf_gen_valid          : std_logic;
  signal utf_gen_ready          : std_logic;
  signal utf_gen_data           : std_logic_vector(ELEMENT_COUNT_MAX * ELEMENT_WIDTH-1 downto 0);

  -- Helper signals for utf generation:
  signal duplicate_valid        : std_logic_vector(ELEMENT_COUNT_MAX-1 downto 0);

begin

  -----------------------------------------------------------------------------
  -- Length stream PRNG
  -----------------------------------------------------------------------------
  -- Instantiate the pseudo random number generator for the length stream
  len_prng_inst: StreamPRNG
    generic map (
      DATA_WIDTH => LEN_WIDTH
    )
    port map (
      clk                       => clk,
      reset                     => reset,
      seed                      => (others => '0'),
      out_valid                 => len_gen_valid,
      out_ready                 => len_gen_ready,
      out_data                  => len_gen_data
    );

  -----------------------------------------------------------------------------
  -- Length stream state machine
  -----------------------------------------------------------------------------
  len_seq_proc: process(clk)
  begin
    if rising_edge(clk) then
      -- Register new state
      r <= d;

      -- Reset
      if reset = '1' then
        r.state <= IDLE;
      end if;
    end if;
  end process;

  len_comb_proc: process(r,
    cmd_valid, cmd_len, cmd_strlen_min, cmd_strlen_mask,
    int_len_ready,
    len_gen_valid, len_gen_data
  ) is
    variable v : regs_record;
    variable o : out_record;
  begin
    v := r;
  
    -- Default outputs
    o.len.data   := std_logic_vector(
          r.cmd.min + 
          unsigned(len_gen_data and std_logic_vector(r.cmd.mask))
        );
    o.len.last   := '0';
    o.len.dvalid := '1';


    case v.state is
      -------------------------------------------------------------------------
      when IDLE =>
      -------------------------------------------------------------------------
        -- Length output stream is invalid
        o.cmd.ready := '0';
        o.len.valid := '0';
        o.len.ready := '0';

        -- If the command is valid
        if cmd_valid = '1' then
          -- Accept the command
          o.cmd.ready := '1';

          -- Register the stream length and string min and max lengths
          v.cmd.len := unsigned(cmd_len);
          v.cmd.min := unsigned(cmd_strlen_min);
          v.cmd.mask := unsigned(cmd_strlen_mask);
          
          -- Go to PASS
          v.state := PASS;
        end if;

      -------------------------------------------------------------------------
      when PASS =>
      -------------------------------------------------------------------------
        -- Don't accept new commands
        o.cmd.ready := '0';

        -- Let the length stream pass through if we still need to generate
        -- more strings.
        o.len.valid  := len_gen_valid;
        o.len.ready  := int_len_ready; -- to len generator
        o.len.dvalid := '1';
        o.len.last   := '0';
        
        -- Add the minimum length to the generated length masked
        o.len.data   := std_logic_vector(
          r.cmd.min + 
          unsigned(len_gen_data and std_logic_vector(r.cmd.mask))
        );
                        
        if r.cmd.len-1 = 0 then
          o.len.last := '1';
        end if;
        
        -- TODO: somehow make the len data "uniformly" random between min and 
        --       max

        -- Count the number of lengths handshaked
        if int_len_ready = '1' and o.len.valid = '1' then        
          -- Calculate the new length for when this transfer is handshaked.
          v.cmd.len := r.cmd.len - 1;
        
          -- Assert last and go back to idle when all lengths have been
          -- streamed out.
          if v.cmd.len = 0 then
            v.state := IDLE;
          end if;
        end if;

    end case;

    -- Connect registered outputs
    d               <= v;

    -- Connect combinatorial outputs
    cmd_ready       <= o.cmd.ready;

    len_gen_ready   <= o.len.ready;
    int_len_valid   <= o.len.valid;
    int_len_data    <= o.len.data;
    int_len_dvalid  <= o.len.dvalid;
    int_len_last    <= o.len.last;

  end process;

  -----------------------------------------------------------------------------
  -- UTF8 PNRG's
  -----------------------------------------------------------------------------
  -- Instantiate the pseudo random number generator for the utf8 stream for
  -- each element. Each PRNG gets its own seed so not all elements will be the
  -- same every cycle.
  utf_prng_inst_gen: for i in 0 to ELEMENT_COUNT_MAX-1 generate
  begin
    utf8_conv: block
      signal prng_data : std_logic_vector(ELEMENT_WIDTH-1 downto 0);
    begin
      utf_prng_inst: StreamPRNG
        generic map (
          DATA_WIDTH              => ELEMENT_WIDTH
        )
        port map (
          clk                     => clk,
          reset                   => reset,
          seed                    => std_logic_vector(to_unsigned(i, ELEMENT_WIDTH)),
          out_valid               => duplicate_valid(i),
          out_ready               => utf_gen_ready,
          out_data                => prng_data
        );
      
      utf_gen_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) 
        <= std_logic_vector(readable_utf8(prng_data));
    
    end block;
  end generate;

  -- The valid is the and reduce of the valids. Yes, it's ugly, but there 
  -- should be no reason the streams can desynchronize.
  utf_gen_valid <= and_reduce(duplicate_valid);

  -----------------------------------------------------------------------------
  -- UTF8 stream state machine
  -----------------------------------------------------------------------------
  utf_seq_proc: process(clk)
  begin
    if rising_edge(clk) then
      -- Register new state
      rs <= ds;

      -- Reset
      if reset = '1' then
        rs.state <= IDLE;
      end if;
    end if;
  end process;

  utf_comb_proc: process(rs,
    buf_valid, buf_data,
    utf8_ready,
    utf_gen_valid, utf_gen_data
  ) is
    variable vs : sregs_record;
    variable os : sout_record;
  begin
    vs := rs;
    
    -- Default outputs
    os.utf.ready  := utf8_ready;
    os.utf.data   := utf_gen_data;
    os.utf.count  := COUNT_MAX_VAL;
    os.utf.last   := '0';
    os.utf.dvalid := '1';
    os.utf.valid  := '0';


    case vs.state is
      -------------------------------------------------------------------------
      when IDLE =>
      -------------------------------------------------------------------------
        os.utf.valid := '0';
        os.utf.ready := '0';
        os.buf.ready := '0';

        if buf_valid = '1' then
          -- Accept length from buffer
          os.buf.ready := '1';

          -- Register length
          vs.len := unsigned(buf_data);

          -- Go to PASS
          vs.state := PASS;
        end if;

      -------------------------------------------------------------------------
      when PASS =>
      -------------------------------------------------------------------------
        -- Not ready for a new length
        os.buf.ready := '0';
        os.utf.ready  := utf8_ready; -- to output
        os.utf.valid  := utf_gen_valid;
        os.utf.data   := utf_gen_data;
        os.utf.last   := '0';
        os.utf.dvalid := '1';

        -- Determine the count. It's maximum as long as we haven't reached the
        -- end yet.
        if rs.len > ELEMENT_COUNT_MAX then
          os.utf.count := COUNT_MAX_VAL;
        else
          os.utf.count := rs.len(ELEMENT_COUNT_WIDTH-1 downto 0);
        end if;

        -- If the output is handshaked
        if os.utf.valid = '1' and utf8_ready = '1' then
          -- Decrease the number of elements we still need to stream out
          vs.len := rs.len - os.utf.count;

          -- If it's zero element left
          if vs.len = 0 then
            -- Assert the last signal
            os.utf.last := '1';
                        
            -- Check if more lengths are ready to be processed
            if buf_valid = '1' then
              -- Accept length from buffer
              os.buf.ready := '1';

              -- Register length
              vs.len := unsigned(buf_data);

              -- Go to PASS
              vs.state := PASS;
            else
              -- No lengths to be processed. Go to idle.
              vs.state := IDLE;
            end if;
          end if;
        end if;

    end case;

    -- Connect registered outputs
    ds <= vs;

    -- Connect combinatorial outputs
    buf_ready     <= os.buf.ready;

    utf_gen_ready <= os.utf.ready;
    utf8_valid    <= os.utf.valid;
    utf8_data     <= os.utf.data;
    utf8_count    <= std_logic_vector(os.utf.count);
    utf8_last     <= os.utf.last;
    utf8_dvalid   <= os.utf.dvalid;
  end process;

  -- Split the length stream to the output and the buffer
  len_split: StreamSync
    generic map (
      NUM_INPUTS => 1,
      NUM_OUTPUTS => 2
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid(0)               => int_len_valid,
      in_ready(0)               => int_len_ready,

      out_valid(0)              => len_valid,
      out_valid(1)              => len_buf_valid,

      out_ready(0)              => len_ready,
      out_ready(1)              => len_buf_ready
    );

  -- Connect the output length stream
  len_data                      <= std_logic_vector(resize(unsigned(int_len_data),INDEX_WIDTH));
  len_dvalid                    <= int_len_dvalid;
  len_last                      <= int_len_last;

  -- Buffer the length stream internally so the length stream can progress on
  -- the external length output
  len_buf_all <= int_len_dvalid & int_len_last & int_len_data;

  len_buf: StreamBuffer
    generic map (
      MIN_DEPTH                 => LENGTH_BUFFER_DEPTH,
      DATA_WIDTH                => LEN_WIDTH+2
    )
    port map (
      clk                       => clk,
      reset                     => reset,

      in_valid                  => len_buf_valid,
      in_ready                  => len_buf_ready,
      in_data                   => len_buf_all,

      out_valid                 => buf_valid,
      out_ready                 => buf_ready,
      out_data                  => buf_all
    );

  buf_dvalid                    <= buf_all(1+1+LEN_WIDTH-1);
  buf_last                      <= buf_all(1+LEN_WIDTH-1);
  buf_data                      <= buf_all(LEN_WIDTH-1 downto 0);

end architecture;
