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

-- This unit "normalizes" a stream that carries multiple elements per transfer.
-- By "normalization", we mean that the output stream always carries the
-- maximum number of elements per cycle, unless:
--  - the input "last" flag is set
--  - an explicit amount of elements is requested (synchronized to the output
--    stream).
-- If both mechanisms are used, the minimum amount of items of the two is
-- returned.

entity StreamNormalizer is
  generic (

    -- Width of a data element.
    ELEMENT_WIDTH               : natural;

    -- Maximum number of elements per clock.
    COUNT_MAX                   : natural;

    -- The number of bits in the count vectors. This must be at least
    -- ceil(log2(COUNT_MAX)) and must be at least 1. If COUNT_MAX is a power of
    -- two and this value equals log2(COUNT_MAX), a zero count implies that all
    -- entries are valid (i.e., there is an implicit '1' bit in front).
    COUNT_WIDTH                 : natural;

    -- The number of bits in the requested count vector. This must be at least
    -- ceil(log2(COUNT_MAX+1)) and must be at least 1.
    REQ_COUNT_WIDTH             : natural

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

    -- Requested number of items. This signal does NOT use an implicitly high
    -- MSB, so zero items can be requested if necessary, which results in an
    -- output transfer with dvalid low.
    req_count                   : in  std_logic_vector(REQ_COUNT_WIDTH-1 downto 0) := std_logic_vector(to_unsigned(COUNT_MAX, REQ_COUNT_WIDTH));

    -- Output stream. dvalid is low only when zero elements are requested by
    -- req_count. last is high when the last element returned was received with
    -- the last flag set.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic;
    out_dvalid                  : out std_logic;
    out_data                    : out std_logic_vector(COUNT_MAX*ELEMENT_WIDTH-1 downto 0);
    out_count                   : out std_logic_vector(COUNT_WIDTH-1 downto 0);
    out_last                    : out std_logic

  );
end StreamNormalizer;

architecture Behavioral of StreamNormalizer is

  -- Determine the size of the FIFO.
  constant FIFO_DEPTH_LOG2      : natural := log2ceil(COUNT_MAX * 2 + 1);
  constant FIFO_DEPTH           : natural := 2**FIFO_DEPTH_LOG2;

  -- Construct the FIFO contents. Note that this will almost certainly not be
  -- implementable as a hard memory, because there are multiple read and
  -- multiple write ports.
  type fifo_element is record
    data                        : std_logic_vector(ELEMENT_WIDTH-1 downto 0);
    last                        : std_logic;
  end record;
  type fifo_array is array (natural range <>) of fifo_element;
  signal fifo                   : fifo_array(0 to FIFO_DEPTH-1);

  -- Read and write pointers for the FIFO.
  signal read_ptr               : std_logic_vector(FIFO_DEPTH_LOG2 downto 0);
  signal write_ptr              : std_logic_vector(FIFO_DEPTH_LOG2 downto 0);

  -- Number of entries in the FIFO (decoded from read_ptr and write_ptr).
  signal fifo_count             : std_logic_vector(FIFO_DEPTH_LOG2 downto 0);

  -- Amount of room available in the FIFO (decoded from read_ptr and
  -- write_ptr).
  signal fifo_avail             : std_logic_vector(FIFO_DEPTH_LOG2 downto 0);

  -- Write-side FIFO state update signals.
  signal write_ptr_add          : std_logic_vector(FIFO_DEPTH_LOG2 downto 0);
  signal fifo_we                : std_logic_vector(FIFO_DEPTH-1 downto 0);
  signal fifo_wdata             : fifo_array(0 to FIFO_DEPTH-1);

  -- Read-side FIFO state update signals.
  signal read_ptr_add           : std_logic_vector(FIFO_DEPTH_LOG2 downto 0);

begin

  -- Work out what to write to the FIFO and by what to increment the write_ptr.
  write_comb_proc: process (
    in_valid, in_dvalid, in_data, in_count, in_last,
    write_ptr, fifo_avail
  ) is
    variable fifo_ready         : std_logic;
    variable incoming           : fifo_array(0 to COUNT_MAX-1);
    variable index              : natural range 0 to FIFO_DEPTH-1;
    variable fifo_we_v          : unsigned(FIFO_DEPTH-1 downto 0);
  begin

    -- Determine whether there is not enough room in the FIFO to receive a
    -- max-count transfer.
    if unsigned(fifo_avail) >= COUNT_MAX then
      fifo_ready := '1';
    else
      fifo_ready := '0';
    end if;

    -- Figure out the data that we will write to the FIFO. Everything beyond
    -- in_count is don't care.
    for i in 0 to COUNT_MAX-1 loop

      -- Data is trivial; just unpack the input vector.
      incoming(i).data := in_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH);

      -- The last flag should be set only for the last valid element. Note,
      -- again, that we don't care about the value for anything beyond
      -- in_count.
      if i + 1 < to_01(unsigned(resize_count(in_count, FIFO_DEPTH_LOG2+1))) then
        incoming(i).last := '0';
      else
        incoming(i).last := in_last;
      end if;

    end loop;

    -- Rotate incoming by the write pointer to get the FIFO write data.
    for i in 0 to FIFO_DEPTH-1 loop
      index := (i - to_integer(to_01(unsigned(write_ptr(FIFO_DEPTH_LOG2-1 downto 0))))) mod FIFO_DEPTH;
      if index < COUNT_MAX then
        fifo_wdata(i) <= incoming(index);
      else
        fifo_wdata(i) <= incoming(0);
      end if;
    end loop;

    -- We always write all the elements we receive into the FIFO, including the
    -- invalid ones which are masked by count/dvalid. This is allowed because
    -- we wait for this amount of space in the FIFO anyway, and the invalid
    -- data written to the FIFO is also already considered invalid due to the
    -- write_ptr and read_ptr relation after pushing. This simplifies the logic
    -- somewhat, removing the dependence on in_count and in_dvalid.
    fifo_we_v := (others => '0');
    for i in 0 to COUNT_MAX-1 loop
      fifo_we_v(i) := '1';
    end loop;
    fifo_we <= std_logic_vector(rotate_left(
      fifo_we_v, to_integer(to_01(unsigned(write_ptr)))));

    -- Figure out by how much we should advance the write pointer. This is the
    -- incoming count value (properly resized to include the implicit '1' MSB)
    -- if dvalid is high, or zero if dvalid is low.
    if in_dvalid = '1' then
      write_ptr_add <= resize_count(in_count, FIFO_DEPTH_LOG2+1);
    else
      write_ptr_add <= (others => '0');
    end if;

    -- Don't do anything if the input is almost full (that is, there is not
    -- enough room in the FIFO to write a COUNT_MAX transfer into it).
    if in_valid = '0' or fifo_ready = '0' then
      write_ptr_add <= (others => '0');
      fifo_we <= (others => '0');
      -- pragma translate_off
      fifo_wdata <= (
        others => (
          data => (others => 'U'),
          last => 'U'
        )
      );
      -- pragma translate_on
    end if;

    -- Signal ready when our FIFO is empty enough.
    in_ready <= fifo_ready;

  end process;

  -- The FIFO memory is simply implemented as a number of fabric registers with
  -- write enables.
  fifo_mem_proc: process (clk) is
  begin
    if rising_edge(clk) then

      -- Instantiate registers with write enable.
      for i in 0 to FIFO_DEPTH-1 loop
        if fifo_we(i) = '1' then
          fifo(i) <= fifo_wdata(i);
        end if;
      end loop;

      -- pragma translate_off
      if reset = '1' then
        fifo <= (
          others => (
            data => (others => 'U'),
            last => 'U'
          )
        );
      end if;
      -- pragma translate_on

    end if;
  end process;

  -- Create the pointer registers.
  fifo_ptr_proc: process (clk) is
  begin
    if rising_edge(clk) then

      -- Create the read and write pointer counters.
      write_ptr <= std_logic_vector(
          unsigned(write_ptr)
        + unsigned(write_ptr_add));
      read_ptr <= std_logic_vector(
          unsigned(read_ptr)
        + unsigned(read_ptr_add));

      -- Reset both pointers to zero.
      if reset = '1' then
        write_ptr <= (others => '0');
        read_ptr <= (others => '0');
      end if;

    end if;
  end process;

  -- Work out the fullness of the FIFO.
  fifo_count <= std_logic_vector(
      unsigned(write_ptr)
    - unsigned(read_ptr));
  fifo_avail <= std_logic_vector(
      to_unsigned(FIFO_DEPTH, FIFO_DEPTH_LOG2+1)
    + unsigned(read_ptr)
    - unsigned(write_ptr));

  -- Handle the read side of the FIFO.
  read_comb_proc: process (fifo, read_ptr, req_count, fifo_count, out_ready) is
    variable fifo_ready         : std_logic;
    variable rdata              : fifo_array(0 to COUNT_MAX-1);
    variable count              : std_logic_vector(REQ_COUNT_WIDTH-1 downto 0);
    variable last               : std_logic;
  begin

    -- Instantiate the multiplexers that form the read ports of the FIFO.
    for i in 0 to COUNT_MAX-1 loop
      rdata(i) := fifo((i + to_integer(to_01(unsigned(read_ptr(FIFO_DEPTH_LOG2-1 downto 0))))) mod FIFO_DEPTH);
    end loop;

    -- Determine the maximum amount of items that we can respond with this
    -- cycle based on the last flags. Also determine whether this is the
    -- last transfer.
    count := std_logic_vector(to_unsigned(COUNT_MAX, REQ_COUNT_WIDTH));
    last := '0';
    for i in COUNT_MAX-1 downto 0 loop
      if i < to_01(unsigned(fifo_count)) then
        if rdata(i).last = '1' then
          count := std_logic_vector(to_unsigned(i+1, REQ_COUNT_WIDTH));
          last := '1';
        end if;
      end if;
    end loop;

    -- Clamp the count by the requested amount of items.
    if to_01(unsigned(count)) > to_01(unsigned(req_count)) then
      count := req_count;
      last := '0';
    end if;

    -- Determine whether the FIFO is full enough to support this amount of
    -- items.
    if to_01(unsigned(fifo_count)) >= to_01(unsigned(count)) then
      fifo_ready := '1';
    else
      fifo_ready := '0';
    end if;

    -- Assign the output stream signals.
    for i in 0 to COUNT_MAX-1 loop
      out_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) <= rdata(i).data;
      -- pragma translate_off
      if i >= to_01(unsigned(count)) then
        out_data((i+1)*ELEMENT_WIDTH-1 downto i*ELEMENT_WIDTH) <= (others => 'U');
      end if;
      -- pragma translate_on
    end loop;
    out_valid  <= fifo_ready;
    out_dvalid <= or_reduce(count);
    out_count  <= std_logic_vector(resize(unsigned(count), COUNT_WIDTH));
    out_last   <= last;

    -- Update the read pointer if the output stream and FIFO are ready.
    if out_ready = '1' and fifo_ready = '1' then
      read_ptr_add <= std_logic_vector(resize(unsigned(count), FIFO_DEPTH_LOG2+1));
    else
      read_ptr_add <= (others => '0');
    end if;

  end process;

end Behavioral;

