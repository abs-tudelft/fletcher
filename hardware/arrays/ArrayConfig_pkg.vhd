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

library work;
use work.ArrayConfigParse_pkg.all;
use work.UtilInt_pkg.all;

package ArrayConfig_pkg is

  -- The supported Array reader configuration commands are listed and
  -- documented below. Vectors are listed MSB first. Streams are listed in
  -- least significant order.
  --
  -----------------------------------------------------------------------------
  -- prim(<width>;epc=1)
  -----------------------------------------------------------------------------
  -- Represents a BufferReader for a primitive data type. width specifies the
  -- bitwidth of the data type.
  --
  -- Control vector:
  --   - baseAddr: BUS_ADDR_WIDTH
  --     Specifies the base address for this buffer, such that
  --     busAddr = baseAddr + index*width/8
  --
  -- Number of masters: 1
  --
  -- User streams:
  --   - Stream 0:
  --       - count: log2ceil(epc+1) when epc > 1, otherwise 0
  --         The number of elements valid in data.
  --       - data: width
  --         The data element.
  --
  -----------------------------------------------------------------------------
  -- arb(<>)
  -----------------------------------------------------------------------------
  -- Constructs an intermediate bus arbiter and registers all streams. This is
  -- automatically instantiated at the top level by ArrayReader.
  --
  -- Control vector:
  --   - <>
  --
  -- Number of masters: 1
  --
  -- User streams:
  --   - <>
  --
  -----------------------------------------------------------------------------
  -- null(<>)
  -----------------------------------------------------------------------------
  -- Makes the data type specified by <> nullable by adding a null bitmap
  -- reader. The elements-per-cycle value for the associated element MUST be 1
  -- for nulls to be supported.
  --
  -- Control vector:
  --   - <>
  --   - present: 1
  --     Specifies whether the null bitmap is present or not. If it is not, the
  --     BufferReader is disabled and always returns non-null.
  --   - baseAddr: BUS_ADDR_WIDTH
  --     Specifies the base address for the null bitmap.
  --
  -- Number of masters: <> + 1
  --
  -- User streams:
  --   - Master stream:
  --       - null: 1
  --         Null flag for this element.
  --       - <>(0)
  --
  --   - Remaining streams: <>(1+)
  --
  -----------------------------------------------------------------------------
  -- list(<>)
  -----------------------------------------------------------------------------
  -- Constructs a list reader for the contained (possibly complex/nullable) data
  -- type.
  --
  -- Control vector:
  --   - <>
  --   - baseAddr: BUS_ADDR_WIDTH
  --     Specifies the base address for the offsets buffer.
  --
  -- Number of masters: <> + 1
  --
  -- User streams:
  --   - Master stream:
  --       - length: INDEX_WIDTH
  --         Length for this list.
  --
  --   - Secondary stream: last/dvalid signaling updated based on length stream
  --   - Remaining streams: <>(1+)
  --
  -----------------------------------------------------------------------------
  -- listprim(<width>;lepc=1,epc=1)
  -----------------------------------------------------------------------------
  -- Constructs a list reader for a primitive, non-nullable data type. width
  -- specifies the bitwidth of the list element data type. The advantage of this
  -- construct over list(prim(width)) is that multiple elements can be returned
  -- per cycle, specified by the epc parameter.
  -- 
  -- For ArrayWriters, multiple list lengths per cycle can also be supplied
  -- using the lepc parameter. 
  -- For ArrayReaders, lepc other than 1 is not supported.
  --
  -- Control vector:
  --   - dataBaseAddr: BUS_ADDR_WIDTH
  --     Specifies the base address for the data buffer.
  --   - indexBaseAddr: BUS_ADDR_WIDTH
  --     Specifies the base address for the index/offsets buffer.
  --
  -- Number of masters: 2
  --
  -- User streams:
  --   - Master stream:
  --       - count: log2ceil(lepc+1)
  --         The number of lengths valid in length.
  --       - length: INDEX_WIDTH*lepc
  --         List lengths.
  --
  --   - Secondary stream:
  --       - count: log2ceil(epc+1)
  --         The number of elements valid in data.
  --       - data: width*epc
  --         The elements returned for this cycle, LSB-aligned.
  --
  -----------------------------------------------------------------------------
  -- struct(<A>,<B>)
  -----------------------------------------------------------------------------
  -- Constructs a struct reader.
  --
  -- Control vector:
  --   - <A>
  --   - <B>
  --
  -- Number of masters: <A> + <B>
  --
  -- User streams:
  --   - Master stream:
  --       - Master stream from <A>
  --       - Master stream from <B>
  --
  --   - Secondary streams from <A>
  --   - Secondary streams from <B>
  --


  -- Returns the control vector width for the given configuration.
  function arcfg_ctrlWidth(cfg: string; BUS_ADDR_WIDTH: natural) return natural;

  -- Returns the number of masters used by the given configuration.
  function arcfg_busCount(cfg: string) return natural;

  -- Returns the number of streams going to the accelerator for the given
  -- configuration.
  function arcfg_userCount(cfg: string) return natural;

  -- Returns a list of user stream widths, such that individual widths can be
  -- indexed, the serialization indices can be computed with cumulative(), and
  -- the total width can be computed with sum().
  function arcfg_userWidths(cfg: string; INDEX_WIDTH: natural) return nat_array;

  -- Returns the width of the main and/or secondary part of the out_data
  -- vector for the given configuration.
  function arcfg_userWidth(cfg: string; INDEX_WIDTH: natural) return natural;
  function arcfg_userWidthMain(cfg: string; INDEX_WIDTH: natural) return natural;
  function arcfg_userWidthSecondary(cfg: string; INDEX_WIDTH: natural) return natural;

end ArrayConfig_pkg;

package body ArrayConfig_pkg is

  -- Returns the control vector width for the given configuration.
  function arcfg_ctrlWidth(cfg: string; BUS_ADDR_WIDTH: natural) return natural is
    constant cmd  : string := parse_command(cfg);
  begin

    if cmd = "prim" then
      return BUS_ADDR_WIDTH; -- Data buffer base address

    elsif cmd = "arb" then
      return arcfg_ctrlWidth(parse_arg(cfg, 0), BUS_ADDR_WIDTH);

    elsif cmd = "null" then
      return 1               -- Null bitmap present flag
           + BUS_ADDR_WIDTH  -- Null bitmap base address
           + arcfg_ctrlWidth(parse_arg(cfg, 0), BUS_ADDR_WIDTH);

    elsif cmd = "list" then
      return BUS_ADDR_WIDTH  -- Index buffer base address
           + arcfg_ctrlWidth(parse_arg(cfg, 0), BUS_ADDR_WIDTH);

    elsif cmd = "listprim" then
      return BUS_ADDR_WIDTH  -- Index buffer base address
           + BUS_ADDR_WIDTH; -- Data buffer base address

    elsif cmd = "struct" then
      return arcfg_ctrlWidth(parse_arg(cfg, 0), BUS_ADDR_WIDTH)  -- Child A
           + arcfg_ctrlWidth(parse_arg(cfg, 1), BUS_ADDR_WIDTH); -- Child B

    end if;

    report "Unknown command '" & cmd & "'."
      severity FAILURE;

    return 1;
  end function;

  -- Returns the number of masters used by the given configuration.
  function arcfg_busCount(cfg: string) return natural is
    constant cmd  : string := parse_command(cfg);
  begin

    if cmd = "prim" then
      return 1; -- Data BufferReader

    elsif cmd = "arb" then
      return 1; -- Arbiter master port

    elsif cmd = "null" then
      return 1 -- Null bitmap BufferReader
           + arcfg_busCount(parse_arg(cfg, 0));

    elsif cmd = "list" then
      return 1 -- Index BufferReader
           + arcfg_busCount(parse_arg(cfg, 0));

    elsif cmd = "listprim" then
      return 1  -- Index BufferReader
           + 1; -- Data BufferReader

    elsif cmd = "struct" then
      return arcfg_busCount(parse_arg(cfg, 0))  -- Child A
           + arcfg_busCount(parse_arg(cfg, 1)); -- Child B

    end if;

    report "Unknown command '" & cmd & "'."
      severity FAILURE;

    return 1;
  end function;

  -- Returns the number of streams going to the accelerator for the given
  -- configuration.
  function arcfg_userCount(cfg: string) return natural is
    constant cmd  : string := parse_command(cfg);
  begin

    if cmd = "prim" then
      return 1; -- Data stream

    elsif cmd = "arb" then
      return arcfg_userCount(parse_arg(cfg, 0));

    elsif cmd = "null" then
      return arcfg_userCount(parse_arg(cfg, 0));

    elsif cmd = "list" then
      return 1 -- Length stream
           + arcfg_userCount(parse_arg(cfg, 0));

    elsif cmd = "listprim" then
      return 1  -- Length stream
           + 1; -- Data stream

    elsif cmd = "struct" then
      return 1 -- Concatenated master stream
           + arcfg_userCount(parse_arg(cfg, 0)) - 1  -- Child A secondary streams
           + arcfg_userCount(parse_arg(cfg, 1)) - 1; -- Child B secondary streams

    end if;

    report "Unknown command '" & cmd & "'."
      severity FAILURE;

    return 1;
  end function;

  function arcfg_userWidthsPrim(cfg: string; INDEX_WIDTH: natural) return nat_array is
    variable res  : nat_array(0 downto 0);
    constant width  : natural := strtoi(parse_arg(cfg, 0));
    constant epc    : natural := parse_param(cfg, "epc", 1);
  begin
    if epc > 1 then
      res(0) := log2ceil(epc + 1) -- Number of elements valid
              + width * epc;      -- data width times epc
    else
      res(0) := width;
    end if;
    return res;
  end function;

  function arcfg_userWidthsNull(child: nat_array; INDEX_WIDTH: natural) return nat_array is
    variable res    : nat_array(child'length-1 downto 0);
  begin
    res(0) := 1         -- Null flag
            + child(0); -- Child master stream data

    -- Append streams of child as secondary streams.
    for i in 1 to child'length-1 loop
      res(i) := child(i);
    end loop;

    return res;
  end function;

  function arcfg_userWidthsList(child: nat_array; INDEX_WIDTH: natural) return nat_array is
    variable res    : nat_array(child'length downto 0);
  begin
    res(0) := INDEX_WIDTH; -- List length

    -- Append streams of child as secondary streams.
    for i in 0 to child'length-1 loop
      res(i+1) := child(i);
    end loop;

    return res;
  end function;

  function arcfg_userWidthsListPrim(cfg: string; INDEX_WIDTH: natural) return nat_array is
    variable res    : nat_array(1 downto 0);
    constant width  : natural := strtoi(parse_arg(cfg, 0));
    constant lepc   : natural := parse_param(cfg, "lepc", 1);
    constant epc    : natural := parse_param(cfg, "epc", 1);
  begin
    res(0) := log2ceil(lepc + 1)  -- Number of lengths valid
            + INDEX_WIDTH * lepc; -- List lengths
    res(1) := log2ceil(epc + 1)   -- Number of elements valid
            + width * epc;        -- epc data lengths
    return res;
  end function;

  function arcfg_userWidthsStruct(a: nat_array; b: nat_array; INDEX_WIDTH: natural) return nat_array is
    variable res    : nat_array(a'length + b'length - 2 downto 0);
  begin
    res(0) := a(0) + b(0); -- Concatenation of child master streams.

    -- Append streams of children as secondary streams.
    for i in 1 to a'length-1 loop
      res(i) := a(i);
    end loop;
    for i in 1 to b'length-1 loop
      res(a'length+i-1) := b(i);
    end loop;

    return res;
  end function;

  -- Returns a list of user stream widths, such that individual widths can be
  -- indexed, the serialization indices can be computed with cumulative(), and
  -- the total width can be computed with sum().
  function arcfg_userWidths(cfg: string; INDEX_WIDTH: natural) return nat_array is
    constant cmd    : string := parse_command(cfg);
  begin
    if cmd = "prim" then
      return arcfg_userWidthsPrim(cfg, INDEX_WIDTH);

    elsif cmd = "arb" then
      return arcfg_userWidths(parse_arg(cfg, 0), INDEX_WIDTH);

    elsif cmd = "null" then
      return arcfg_userWidthsNull(
        arcfg_userWidths(parse_arg(cfg, 0), INDEX_WIDTH),
        INDEX_WIDTH);

    elsif cmd = "list" then
      return arcfg_userWidthsList(
        arcfg_userWidths(parse_arg(cfg, 0), INDEX_WIDTH),
        INDEX_WIDTH);

    elsif cmd = "listprim" then
      return arcfg_userWidthsListPrim(cfg, INDEX_WIDTH);

    elsif cmd = "struct" then
      return arcfg_userWidthsStruct(
        arcfg_userWidths(parse_arg(cfg, 0), INDEX_WIDTH),
        arcfg_userWidths(parse_arg(cfg, 1), INDEX_WIDTH),
        INDEX_WIDTH);

    else
      report "Unknown command '" & cmd & "'."
        severity FAILURE;

    end if;

    return (0 downto 0 => 0);
  end function;

  -- Returns the width of the user streams data vector used by the given
  -- configuration. main and secondary indicate which stream types to include
  -- in the count.
  function arcfg_userWidthInt(
    cfg         : string;
    INDEX_WIDTH : natural;
    main        : boolean;
    secondary   : boolean
  ) return natural is
    constant cmd    : string := parse_command(cfg);
    variable cnt    : natural;
    variable epc    : natural;
    variable lepc   : natural;
    variable width  : natural;
  begin
    cnt := 0;

    if cmd = "prim" then
      if main then
        width := strtoi(parse_arg(cfg, 0));
        epc := parse_param(cfg, "epc", 1);
        if epc > 1 then
          cnt := cnt + log2ceil(epc + 1); -- Number of elements valid
          cnt := cnt + width * epc; -- epc elements
        else
          cnt := cnt + width;
        end if;
      end if;

    elsif cmd = "arb" then
      cnt := cnt + arcfg_userWidthInt(parse_arg(cfg, 0), INDEX_WIDTH, main, secondary);

    elsif cmd = "null" then
      if main then
        cnt := cnt + 1; -- Null flag
      end if;

      cnt := cnt + arcfg_userWidthInt(parse_arg(cfg, 0), INDEX_WIDTH, main, secondary);

    elsif cmd = "list" then

      if main then
        cnt := cnt + INDEX_WIDTH; -- List length
      end if;

      -- All streams for the list element type are now secondary.
      cnt := cnt + arcfg_userWidthInt(parse_arg(cfg, 0), INDEX_WIDTH, secondary, secondary);

    elsif cmd = "listprim" then

      if main then
        lepc := parse_param(cfg, "lepc", 1);

        cnt := cnt + log2ceil(lepc + 1); -- Number of lengths valid
        cnt := cnt + INDEX_WIDTH * lepc; -- All lengths
      end if;
      if secondary then
        width := strtoi(parse_arg(cfg, 0));
        epc := parse_param(cfg, "epc", 1);

        cnt := cnt + log2ceil(epc + 1); -- Number of elements valid
        cnt := cnt + width * epc;       -- All elements
      end if;

    elsif cmd = "struct" then

      -- The main and secondary streams are simply concatenated by a struct, so
      -- we just have to sum.
      for i in 0 to 1 loop
        cnt := cnt + arcfg_userWidthInt(parse_arg(cfg, i), INDEX_WIDTH, main, secondary);
      end loop;

    else

      report "Unknown command '" & cmd & "'."
        severity FAILURE;

    end if;

    return cnt;
  end function;

  function arcfg_userWidth(cfg: string; INDEX_WIDTH: natural) return natural is
  begin
    return arcfg_userWidthInt(cfg, INDEX_WIDTH, true, true);
  end function;

  function arcfg_userWidthMain(cfg: string; INDEX_WIDTH: natural) return natural is
  begin
    return arcfg_userWidthInt(cfg, INDEX_WIDTH, true, false);
  end function;

  function arcfg_userWidthSecondary(cfg: string; INDEX_WIDTH: natural) return natural is
  begin
    return arcfg_userWidthInt(cfg, INDEX_WIDTH, false, true);
  end function;


end ArrayConfig_pkg;
