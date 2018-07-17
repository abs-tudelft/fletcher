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

library std;
use std.textio.all;

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

library work;
use work.SimUtils.all;

package Memory is

  -- pragma translate_off

  -----------------------------------------------------------------------------
  -- Type declarations
  -----------------------------------------------------------------------------
  -- Address and data types.
  subtype mem_address_type     is std_logic_vector(63 downto  0);
  subtype mem_data_type        is std_logic_vector( 7 downto  0);
  type mem_data_array          is array (natural range <>) of mem_data_type;

  -- Size definitions for the number of words in a leaf and the number of child
  -- nodes for a node. In total, i*MEM_NODE_SIZE_LOG2 + MEM_LEAF_SIZE_LOG2
  -- should equal 64 for some integer i, where i is the number of non-leaf
  -- levels in the tree.
  constant MEM_LEAF_SIZE_LOG2 : natural := 12;
  constant MEM_NODE_SIZE_LOG2 : natural := 13;

  -- Dynamically allocated memory tree types.
  subtype mem_bank_type is mem_data_array(0 to 2**MEM_LEAF_SIZE_LOG2-1);
  type mem_bank_ptr is access mem_bank_type;

  -- Pointer to a node list. The node list type is declared later. It's not
  -- an array directly, because ISim doesn't seem to approve of that, but
  -- rather a record containing the array.
  type mem_nodeList_type;
  type mem_nodeList_ptr is access mem_nodeList_type;

  -- Node type for the memory tree.
  type mem_node_type is record

    -- If this is a leaf node, this contains the data.
    leafData      : mem_bank_ptr;

    -- If this is not a leaf node, this contains pointers to the child nodes.
    children      : mem_nodeList_ptr;

  end record;

  -- Declare the node list type which was announced earlier.
  type mem_node_array is array (0 to 2**MEM_NODE_SIZE_LOG2-1) of mem_node_type;
  type mem_nodeList_type is record
    list          : mem_node_array;
  end record;

  -- Memory state type.
  type mem_state_type is record

    -- Memory data access.
    root                        : mem_node_type;

    -- Default value.
    dflt                     : mem_data_type;

  end record;

  -----------------------------------------------------------------------------
  -- Access methods
  -----------------------------------------------------------------------------
  -- Clears the memory specified by mem and sets the dflt read value of the
  -- memory to value.
  procedure mem_clear(
    mem   : inout mem_state_type;
    value : in    std_logic := 'U'
  );

  -- Returns a burst of bytes starting at the given address. Bytes are returned
  -- in little endian order. The burst may not pass 4k byte boundaries.
  procedure mem_read(
    mem   : inout mem_state_type;
    addr  : in    mem_address_type;
    value : out   std_logic_vector
  );

  -- Writes a burst of bytes to the given address. Bytes are written in little
  -- endian order. The burst may not pass 4k byte boundaries. Mask specifies a
  -- per-byte write mask in the same order as value. Out-of-range accesses
  -- assume '1', so mask can be omitted.
  procedure mem_write(
    mem   : inout mem_state_type;
    addr  : in    mem_address_type;
    value : in    std_logic_vector;
    mask  : in    std_logic_vector := "1"
  );

  -- Loads the specified s-record file into the memory, using the specified
  -- memory offset if specified.
  procedure mem_loadSRec(
    mem   : inout mem_state_type;
    fname : in    string;
    offset: in    mem_address_type := (others => '0')
  );

  -- Dumps the current memory contents to the specified s-record file.
  procedure mem_dumpSRec(
    mem   : inout mem_state_type;
    fname : in    string
  );

  -- Dumps the current memory contents to a human-readable ASCII file.
  procedure mem_dump(
    mem   : inout mem_state_type;
    fname : in    string
  );

  -- pragma translate_on

end Memory;

--=============================================================================
package body Memory is
--=============================================================================

  -- Normalizes an std_logic_vector, i.e.:
  --  - Converts to descending range.
  --  - Shifts lowest index to 0.
  -- It does not modify the value in any way.
  function norm(value: std_logic_vector) return std_logic_vector is
    variable result : std_logic_vector(value'length-1 downto 0);
  begin
    result := value;
    return result;
  end norm;

  -----------------------------------------------------------------------------
  -- Private methods for tree walking in the dynamically allocated memory
  -----------------------------------------------------------------------------
  -- pragma translate_off

  -- Deallocates everything in a node.
  procedure clearNode(
    node  : inout mem_node_type
  ) is
  begin

    -- If this was a leaf, deallocate the memory bank.
    if node.leafData /= null then
      deallocate(node.leafData);
      node.leafData := null;
    end if;

    -- If this was not a leaf, deallocate the children.
    if node.children /= null then

      -- Walk over the array of children and deallocate their contents.
      for i in node.children.all.list'range loop
        clearNode(node.children.all.list(i));
      end loop;

      -- Deallocate the array of children.
      deallocate(node.children);
      node.children := null;

    end if;

  end clearNode;

  -- Reads from a node at the specified address. def is returned if the
  -- addressed location has not been allocated.
  procedure readFromNode(
    node  : inout mem_node_type;
    addr  : in    std_logic_vector;
    def   : in    mem_data_type;
    res   : out   std_logic_vector
  ) is
    variable addrInt  : natural;
    variable memVal   : mem_data_type;
  begin

    -- Default to returning the dflt value.
    for i in 0 to res'length / 8 - 1 loop
      res(i*8+7 downto i*8) := def;
    end loop;

    if addr'length < MEM_LEAF_SIZE_LOG2 then

      -- We must end up at MEM_LEAF_SIZE_LOG2, or something went wrong.
      report "Leaf/node size configuration error or faulty code in "
           & "Memory package!"
        severity failure;

    elsif addr'length = MEM_LEAF_SIZE_LOG2 then

      -- We're reading from a leaf node now. Make sure the leaf data is
      -- initialized.
      if node.leafData = null then
        return;
      end if;

      -- Read the value.
      addrInt := to_integer(unsigned(addr));
      for i in 0 to res'length / 8 - 1 loop
        res(i*8+7 downto i*8) := node.leafData.all(addrInt);
        addrInt := addrInt + 1;
        addrInt := addrInt mod 2**MEM_LEAF_SIZE_LOG2;
      end loop;

    elsif addr'length < MEM_NODE_SIZE_LOG2 then

      -- We must end up at MEM_LEAF_SIZE_LOG2, or something went wrong.
      report "Leaf/node size configuration error or faulty code in "
           & "Memory package!"
        severity failure;

    else

      -- We're still in a non-leaf node. Make sure the array of child nodes is
      -- initialized.
      if node.children = null then
        return;
      end if;

      -- Make a recursive call to ourselves to handle the child node.
      addrInt := to_integer(unsigned(addr(addr'high downto (addr'high - MEM_NODE_SIZE_LOG2) + 1)));
      readFromNode(
        node  => node.children.all.list(addrInt),
        addr  => addr(addr'high - MEM_NODE_SIZE_LOG2 downto 0),
        def   => def,
        res   => res
      );

    end if;

  end readFromNode;

  -- Writes to a node, creating child nodes when needed. def specifies the
  -- dflt value for the memory, in case a new leaf needs to be initialized.
  procedure writeToNode(
    node  : inout mem_node_type;
    addr  : in    std_logic_vector;
    value : in    std_logic_vector;
    mask  : in    std_logic_vector;
    def   : in    mem_data_type
  ) is
    variable addrInt  : natural;
    variable memVal   : mem_data_type;
  begin

    if addr'length < MEM_LEAF_SIZE_LOG2 then

      -- We must end up at MEM_LEAF_SIZE_LOG2, or something went wrong.
      report "Leaf/node size configuration error or faulty code in "
           & "Memory package!"
        severity failure;

    elsif addr'length = MEM_LEAF_SIZE_LOG2 then

      -- We're writing to a leaf node. Make sure the leaf is initialized.
      if node.leafData = null then
        node.leafData := new mem_bank_type;
        node.leafData.all := (0 to 2**MEM_LEAF_SIZE_LOG2-1 => def);
      end if;

      -- Write the values.
      addrInt := to_integer(unsigned(addr));
      for i in 0 to value'length / 8 - 1 loop
        if i < mask'length then
          if to_X01(mask(i)) = '1' then
            node.leafData.all(addrInt) := value(i*8+7 downto i*8);
          elsif to_X01(mask(i)) = 'X' then
            node.leafData.all(addrInt) := (others => 'X');
          end if;
        else
          node.leafData.all(addrInt) := value(i*8+7 downto i*8);
        end if;
        addrInt := addrInt + 1;
        addrInt := addrInt mod 2**MEM_LEAF_SIZE_LOG2;
      end loop;

    elsif addr'length < MEM_NODE_SIZE_LOG2 then

      -- We must end up at MEM_LEAF_SIZE_LOG2, or something went wrong.
      report "Leaf/node size configuration error or faulty code in "
           & "Memory package!"
        severity failure;

    else

      -- We're still in a non-leaf node. Make sure the array of child nodes is
      -- initialized.
      if node.children = null then
        node.children := new mem_nodeList_type;
        node.children.all.list := (others => (
          leafData => null,
          children => null
        ));
      end if;

      -- Make a recursive call to ourselves to handle the child node.
      addrInt := to_integer(unsigned(addr(addr'high downto (addr'high - MEM_NODE_SIZE_LOG2) + 1)));
      writeToNode(
        node  => node.children.all.list(addrInt),
        addr  => addr(addr'high - MEM_NODE_SIZE_LOG2 downto 0),
        value => value,
        mask  => mask,
        def   => def
      );

    end if;

  end writeToNode;

  -- pragma translate_on

  -----------------------------------------------------------------------------
  -- Private types and methods for SREC parsing and generation
  -----------------------------------------------------------------------------
  -- Byte array type.
  subtype byte_type is std_logic_vector(7 downto 0);
  type byte_array is array (natural range <>) of byte_type;

  -- S-record types.
  type srec_record_type is (UNKNOWN_REC, HEADER_REC, DATA_REC, COUNT_REC, TERMINATION_REC);

  -- Describes a line in an S-record. For the count record, addr holds the
  -- count value.
  type srec_line_type is record
    rec       : srec_record_type;
    addr      : mem_address_type;
    data      : byte_array(0 to 255);
    dataCount : natural;
  end record;

  -- Parses a byte in an s-record.
  function str2srecByte(s: string; pos: positive) return byte_type is
    variable b : byte_type;
  begin
    b := charToStdLogic(s(pos)) & charToStdLogic(s(pos+1));
    return b;
  end str2srecByte;

  -- Returns the checksum for a parsed s-record.
  function srecChecksum(rec: srec_line_type) return byte_type is
    variable sum      : unsigned(7 downto 0);
    variable result   : std_logic_vector(7 downto 0);
  begin

    -- Start at 0.
    sum := (others => '0');

    -- Determine length byte and add to sum.
    sum := to_unsigned(5 + rec.dataCount, 8);
    --if rec.addr(31 downto 24) = X"00" then
    --  sum := sum - 1;
    --  if rec.addr(23 downto 16) = X"00" then
    --    sum := sum - 1;
    --  end if;
    --end if;

    -- Accumulate all address and data bytes.
    sum := sum + unsigned(rec.addr(31 downto 24));
    sum := sum + unsigned(rec.addr(23 downto 16));
    sum := sum + unsigned(rec.addr(15 downto  8));
    sum := sum + unsigned(rec.addr( 7 downto  0));
    for i in 0 to rec.dataCount-1 loop
      if not is_X(rec.data(i)) then
        sum := sum + unsigned(rec.data(i));
      end if;
    end loop;

    -- Return the one's complement of the sum.
    result := not std_logic_vector(sum);
    return result;

  end srecChecksum;

  -- Parses an S-record line.
  function str2srec(s: string; line: positive) return srec_line_type is
    variable result   : srec_line_type;
    variable addrSize : natural;
    variable slen     : integer;
    variable count    : integer;
    variable dataOff  : positive;
  begin

    -- Determine string length, trimming away any stray /r or /n.
    slen := s'length;
    if (slen > 0) and (s(slen) = LF) then
      slen := slen - 1;
    end if;
    if (slen > 0) and (s(slen) = CR) then
      slen := slen - 1;
    end if;

    -- Sanity checking.
    if slen = 0 then
      result.rec := UNKNOWN_REC;
      return result;
    elsif slen < 4 then
      report "Line " & integer'image(line) & " in SREC is invalid, ignoring."
        severity warning;
      result.rec := UNKNOWN_REC;
      return result;
    end if;

    -- Test for record type.
    if s(1) = 'S' then
      case s(2) is
        when '0' => result.rec := HEADER_REC;       addrSize := 2;
        when '1' => result.rec := DATA_REC;         addrSize := 2;
        when '2' => result.rec := DATA_REC;         addrSize := 3;
        when '3' => result.rec := DATA_REC;         addrSize := 4;
        when '5' => result.rec := COUNT_REC;        addrSize := 2;
        when '6' => result.rec := COUNT_REC;        addrSize := 3;
        when '7' => result.rec := TERMINATION_REC;  addrSize := 4;
        when '8' => result.rec := TERMINATION_REC;  addrSize := 3;
        when '9' => result.rec := TERMINATION_REC;  addrSize := 2;
        when others => result.rec := UNKNOWN_REC;
      end case;
    else
      result.rec := UNKNOWN_REC;
    end if;

    -- Return now if the record type is unknown.
    if result.rec = UNKNOWN_REC then
      report "Unknown record " & s(1 to 2) & " on line " & integer'image(line)
           & " in SREC file, ignoring."
        severity warning;
      return result;
    end if;

    -- Check the length of the record.
    count := to_integer(unsigned(str2srecByte(s, 3)));
    if slen /= count*2 + 4 then
      report "Record " & s(1 to 2) & " on line " & integer'image(line)
           & " in SREC file has incorrect length, ignoring."
        severity warning;
      result.rec := UNKNOWN_REC;
      return result;
    end if;

    -- Turn the count into a data byte count by getting rid of the size of the
    -- address and checksum.
    count := count - (addrSize + 1);

    -- This count should be 0 for COUNT and TERMINATION records and greater
    -- than or equal to zero for HEADER and DATA records.
    if (count < 0) or ((count > 0) and (result.rec = COUNT_REC or result.rec = TERMINATION_REC)) then
      report "Record " & s(1 to 2) & " on line " & integer'image(line)
           & " in SREC file has incorrect length, ignoring."
        severity warning;
      result.rec := UNKNOWN_REC;
      return result;
    end if;

    -- Store the byte count (can't do this earlier, because the computed byte
    -- count can be negative for invalid records and dataCount is a natural).
    result.dataCount := count;

    -- Parse the address field.
    case addrSize is
      when 2 => result.addr := X"000000000000" & str2srecByte(s, 5) & str2srecByte(s, 7);
      when 3 => result.addr := X"0000000000" & str2srecByte(s, 5) & str2srecByte(s, 7) & str2srecByte(s, 9);
      when others => result.addr := X"00000000" & str2srecByte(s, 5) & str2srecByte(s, 7) & str2srecByte(s, 9) & str2srecByte(s, 11);
    end case;

    -- Determine at which character in the string the data starts.
    dataOff := 5 + addrSize * 2;

    -- Parse the data.
    for i in 0 to result.dataCount-1 loop
      result.data(i) := str2srecByte(s, dataOff + 2*i);
    end loop;

    -- Verify checksum.
    if str2srecByte(s, dataOff + 2*result.dataCount) /= srecChecksum(result) then
      report "Record " & s(1 to 2) & " on line " & integer'image(line)
           & " in SREC file has incorrect checksum. Expected: " & integer'image(to_integer(unsigned((srecChecksum(result)))))
        severity warning;
    end if;

    -- Return the parsed record.
    return result;

  end str2srec;

  -- pragma translate_off

  -- Output file format for srec2str and dumpNode.
  type dumpFormat_type is (DUMP_SREC, DUMP_HUMAN);

  -- Converts a parsed s-record to a string. The DUMP_HUMAN format assumes that
  -- addresses are aligned to 16 byte boundaries and that each record holds 16
  -- bytes, otherwise the header won't look nice. When an empty line is
  -- returned, it should not be added to the file.
  function srec2str(sr: srec_line_type; format: dumpFormat_type) return sim_string_builder_type is
    variable sb       : sim_string_builder_type;
    variable addrSize : natural;
  begin
    sim_clear(sb);

    if format = DUMP_SREC then

      -- Dump as line in SREC file.

      -- Determine the number of bytes to use for the address field.
      addrSize := 4;
      if sr.addr(31 downto 24) = X"00" then
        addrSize := addrSize - 1;
        if sr.addr(23 downto 16) = X"00" then
          addrSize := addrSize - 1;
        end if;
      end if;

      -- Write the record type.
      case sr.rec is
        when UNKNOWN_REC =>
          return to_ssb("");

        when HEADER_REC =>
          sb := to_ssb("S0");

        when DATA_REC =>
          case addrSize is
            when 2 => sb := to_ssb("S1");
            when 3 => sb := to_ssb("S2");
            when others => sb := to_ssb("S3");
          end case;

        when COUNT_REC =>
          case addrSize is
            when 2 => sb := to_ssb("S5");
            when others => sb := to_ssb("S6");
          end case;

        when TERMINATION_REC =>
          case addrSize is
            when 2 => sb := to_ssb("S9");
            when 3 => sb := to_ssb("S8");
            when others => sb := to_ssb("S7");
          end case;

      end case;

      -- Write the length field.
      sim_append(sb, sim_hex_no0x(std_logic_vector(to_unsigned(
        addrSize + sr.dataCount + 1, 8
      )), 2));

      -- Write the address field.
      for i in addrSize-1 downto 0 loop
        sim_append(sb, sim_hex_no0x(sr.addr(i*8+7 downto i*8), 2));
      end loop;

      -- Write the data.
      for i in 0 to sr.dataCount-1 loop
        if is_X(sr.data(i)) then
          sim_append(sb, "00");
        else
          sim_append(sb, sim_hex_no0x(sr.data(i), 2));
        end if;
      end loop;

      -- Write the checksum.
      sim_append(sb, sim_hex_no0x(srecChecksum(sr), 2));

    elsif format = DUMP_HUMAN then

      -- Dump in human readable form.
      case sr.rec is
        when HEADER_REC =>
          return to_ssb("Address               00 01 02 03   04 05 06 07   08 09 0A 0B   0C 0D 0E 0F");

        when DATA_REC =>
          sim_append(sb, sim_hex(sr.addr, 16));
          sim_append(sb, " => ");
          for i in 0 to sr.dataCount-1 loop
            sim_append(sb, sim_hex_no0x(sr.data(i), 2));
            if i mod 4 = 3 then
              sim_append(sb, "   ");
            else
              sim_append(sb, " ");
            end if;
          end loop;

        when others =>
          return to_ssb("");

      end case;

    end if;

    -- Return.
    return sb;

  end srec2str;

  -- Dumps a node to a file.
  procedure dumpNode(
    node    : inout mem_node_type;
    file f  :       text;
    format  : in    dumpFormat_type;
    count   : inout natural;
    def     : in    mem_data_type;
    addr    : in    std_logic_vector := ""
  ) is
    variable sb   : sim_string_builder_type;
    variable flag : boolean;
    variable s    : line;
  begin

    -- If this is a leaf, dump its contents.
    if node.leafData /= null then
      for i in 0 to 2**(MEM_LEAF_SIZE_LOG2-4)-1 loop

        -- Figure out if there is nontrivial data in this 16-byte record.
        flag := false;
        for j in 0 to 15 loop
          if node.leafData.all(i*16+j) /= def then
            flag := true;
            exit;
          end if;
        end loop;

        if flag then
          sb := srec2str((
            rec => DATA_REC,
            addr => addr & std_logic_vector(to_unsigned(i, MEM_LEAF_SIZE_LOG2-4)) & "0000",
            data => (
              0  => node.leafData.all(i*16+0),
              1  => node.leafData.all(i*16+1),
              2  => node.leafData.all(i*16+2),
              3  => node.leafData.all(i*16+3),
              4  => node.leafData.all(i*16+4),
              5  => node.leafData.all(i*16+5),
              6  => node.leafData.all(i*16+6),
              7  => node.leafData.all(i*16+7),
              8  => node.leafData.all(i*16+8),
              9  => node.leafData.all(i*16+9),
              10 => node.leafData.all(i*16+10),
              11 => node.leafData.all(i*16+11),
              12 => node.leafData.all(i*16+12),
              13 => node.leafData.all(i*16+13),
              14 => node.leafData.all(i*16+14),
              15 => node.leafData.all(i*16+15),
              others => X"00"
            ),
            dataCount => 16
          ), format);
          if sb.len /= 0 then
            write(s, ssb2str(sb));
            writeline(f, s);
            count := count + 1;
          end if;
        end if;
      end loop;
    end if;

    -- If this is not a leaf, dump the children recursively.
    if node.children /= null then
      for i in node.children.all.list'range loop
        dumpNode(
          node    => node.children.all.list(i),
          f       => f,
          format  => format,
          count   => count,
          def     => def,
          addr    => addr & std_logic_vector(to_unsigned(i, MEM_NODE_SIZE_LOG2))
        );
      end loop;
    end if;

  end dumpNode;

  -- Dumps the current memory contents to the specified file in the specified
  -- format.
  procedure dumpMem(
    mem     : inout mem_state_type;
    fname   : in    string;
    format  : in    dumpFormat_type
  ) is
    file     f      : text;
    variable count  : natural;
    variable sb     : sim_string_builder_type;
    variable s      : line;
  begin
    file_open(f, fname, write_mode);

    -- Write header.
    sb := srec2str((
      rec => HEADER_REC,
      addr => X"0000000000000000",
      data => (
        0  => X"6D", -- m
        1  => X"65", -- e
        2  => X"6D", -- m
        3  => X"20",
        4  => X"64", -- d
        5  => X"75", -- u
        6  => X"6D", -- m
        7  => X"70", -- p
        others => X"00"
      ),
      dataCount => 9 -- Include null termination.
    ), format);
    if sb.len /= 0 then
      write(s, ssb2str(sb));
      writeline(f, s);
    end if;

    -- Store the number of data records written for the count record.
    count := 0;

    -- Dump the memory.
    dumpNode(
      node    => mem.root,
      f       => f,
      format  => format,
      count   => count,
      def     => mem.dflt,
      addr    => ""
    );

    -- Write the count record.
    sb := srec2str((
      rec => COUNT_REC,
      addr => std_logic_vector(to_unsigned(count, 64)),
      data => (others => X"00"),
      dataCount => 0
    ), format);
    if sb.len /= 0 then
      write(s, ssb2str(sb));
      writeline(f, s);
    end if;

    -- Write the termination record.
    sb := srec2str((
      rec => TERMINATION_REC,
      addr => X"0000000000000000",
      data => (others => X"00"),
      dataCount => 0
    ), format);
    if sb.len /= 0 then
      write(s, ssb2str(sb));
      writeline(f, s);
    end if;

    file_close(f);
  end dumpMem;

  -- pragma translate_on

  -----------------------------------------------------------------------------
  -- Public methods
  -----------------------------------------------------------------------------
  -- pragma translate_off

  -- Clears the memory specified by mem and sets the dflt read value of the
  -- memory to value.
  procedure mem_clear(
    mem   : inout mem_state_type;
    value : in    std_logic := 'U'
  ) is
  begin

    -- Deallocate the memory structure.
    clearNode(mem.root);

    -- Set the dflt value.
    mem.dflt := (others => value);

  end mem_clear;

  -- Returns a burst of bytes starting at the given address. Bytes are returned
  -- in little endian order. The burst may not pass 4k byte boundaries.
  procedure mem_read(
    mem   : inout mem_state_type;
    addr  : in    mem_address_type;
    value : out   std_logic_vector
  ) is
  begin

    -- If we're reading from an undefined address, always return X.
    if is_X(addr) then
      value := (value'range => 'X');
      return;
    end if;

    -- Defer to the private tree-walking read method.
    readFromNode(
      node  => mem.root,
      addr  => norm(addr),
      def   => mem.dflt,
      res   => value
    );

  end mem_read;

  -- Writes a burst of bytes to the given address. Bytes are written in little
  -- endian order. The burst may not pass 4k byte boundaries. Mask specifies a
  -- per-byte write mask in the same order as value. Out-of-range accesses
  -- assume '1', so mask can be omitted.
  procedure mem_write(
    mem   : inout mem_state_type;
    addr  : in    mem_address_type;
    value : in    std_logic_vector;
    mask  : in    std_logic_vector := "1"
  ) is
  begin

    -- An undefined address while writing is bad.
    if is_X(addr) then
      mem_clear(mem, 'X');
      report "System attempted to write to an undefined address! Entire "
           & "memory is reset to X!"
        severity warning;
      return;
    end if;

    -- Defer to the private tree-walking write method. Ignore the two LSBs in
    -- the memory address because the memory is word-aligned.
    writeToNode(
      node  => mem.root,
      addr  => norm(addr),
      value => norm(value),
      mask  => norm(mask),
      def   => mem.dflt
    );

  end mem_write;

  -- Loads the specified s-record file into the memory, using the specified
  -- memory offset if specified.
  procedure mem_loadSRec(
    mem   : inout mem_state_type;
    fname : in    string;
    offset: in    mem_address_type := (others => '0')
  ) is
    file     f    : text;
    variable l    : line;
    variable sr   : srec_line_type;
    variable lNr  : positive;
    variable addr : unsigned(63 downto 0);
    variable index: natural;
  begin
    file_open(f, fname, read_mode);
    lNr := 1;
    while not endfile(f) loop

      -- Parse the s-record on this line.
      readline(f, l);
      sr := str2srec(l.all, lNr);

      -- Increment line number.
      lNr := lNr + 1;

      -- Ignore non-DATA s-records.
      if sr.rec /= DATA_REC then
        next;
      end if;

      -- Write the bytes to the memory.
      index := 0;
      addr := unsigned(sr.addr) + unsigned(offset);
      while index < sr.dataCount loop

        -- Perform the write.
        mem_write(mem, std_logic_vector(addr), sr.data(index), "1");

        -- Increment address and index.
        index := index + 1;
        addr := addr + 1;

      end loop;

    end loop;
    file_close(f);
  end mem_loadSRec;

  -- Dumps the current memory contents to the specified s-record file.
  procedure mem_dumpSRec(
    mem   : inout mem_state_type;
    fname : in    string
  ) is
  begin
    dumpMem(
      mem     => mem,
      fname   => fname,
      format  => DUMP_SREC
    );
  end mem_dumpSRec;

  -- Dumps the current memory contents to a human-readable ASCII file.
  procedure mem_dump(
    mem   : inout mem_state_type;
    fname : in    string
  ) is
  begin
    dumpMem(
      mem     => mem,
      fname   => fname,
      format  => DUMP_HUMAN
    );
  end mem_dump;

  -- pragma translate_on

end Memory;
