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

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use IEEE.math_real.all;

library std;
use std.textio.all;

--=============================================================================
-- This package contains basic simulation/elaboration-only utilities, primarily
-- focussed on string manipulation.
-------------------------------------------------------------------------------
package SimUtils is
--=============================================================================

  -----------------------------------------------------------------------------
  -- Basic string manipulation
  -----------------------------------------------------------------------------
  -- Returns true if given character is alphabetical.
  function isAlphaChar(c: character) return boolean;

  -- Returns true if given character is numeric.
  function isNumericChar(c: character) return boolean;

  -- Returns true if given character is alphanumerical.
  function isAlphaNumericChar(c: character) return boolean;

  -- Returns true if given character is whitespace.
  function isWhitespaceChar(c: character) return boolean;

  -- Returns true if given character is a special character (not alphanumerical
  -- and not whitespace).
  function isSpecialChar(c: character) return boolean;

  -- Converts a character to uppercase.
  function upperChar(c: character) return character;

  -- Converts a character to its numeric value, supporting all hexadecimal
  -- digits. Returns -1 when the character is not hexadecimal.
  function charToDigitVal(c: character) return integer;

  -- Converts a hex character to an std_logic_vector of length 4. U and X are
  -- supported.
  function charToStdLogic(c: character) return std_logic_vector;

  -- Tests whether two characters match, ignoring case.
  function charsEqual(a: character; b: character) return boolean;

  -- Tests whether line equals match, case insensitive.
  function matchStr(
    s1    : in string;
    s2    : in string
  ) return boolean;

  -- Tests whether line contains match at position pos (case insensitive).
  function matchAt(
    line  : in string;   -- String to match in.
    pos   : in positive; -- Position in line where matching should start.
    match : in string    -- The string to match.
  ) return boolean;

  -----------------------------------------------------------------------------
  -- Fixed-length string manipulation
  -----------------------------------------------------------------------------
  -- Global string length for all operations which operate on fixed string
  -- lengths for simplicity.
  constant SIM_STR_LEN         : positive := 256;

  -- Fixed string type.
  subtype sim_string_type is string(1 to SIM_STR_LEN);
  type sim_string_array is array (natural range <>) of sim_string_type;

  -- "String builder" type. This includes an integer with the current string
  -- length to prevent recomputation all the time.
  type sim_string_builder_type is record
    s: sim_string_type;
    len: natural range 0 to SIM_STR_LEN;
  end record;
  type sim_string_builder_array is array (natural range <>) of sim_string_builder_type;

  -- Empty string builder constant.
  constant SIM_EMPTY: sim_string_builder_type := (
    s => (others => ' '),
    len => 0
  );

  -- Clears a string builder.
  procedure sim_clear(sb: inout sim_string_builder_type);

  -- Removes trailing spaces from a string builder.
  procedure sim_trimTrailingSpaces(sb: inout sim_string_builder_type);

  -- Capitalizes the first character in a string builder.
  procedure sim_capitalize(sb: inout sim_string_builder_type);

  -- Converts a VHDL unbounded string to a string builder.
  function to_ssb(input: string) return sim_string_builder_type;

  -- Appends a character to a string builder.
  procedure sim_append(sb: inout sim_string_builder_type; c: character);
  function "&"(L: sim_string_builder_type; R: character) return sim_string_builder_type;

  -- Appends a VHDL string to a string builder.
  procedure sim_append(sb: inout sim_string_builder_type; s: string);
  function "&"(L: sim_string_builder_type; R: string) return sim_string_builder_type;

  -- Appends a string builder to a string builder.
  procedure sim_append(sb: inout sim_string_builder_type; sb2: sim_string_builder_type);
  function "&"(L: sim_string_builder_type; R: sim_string_builder_type) return sim_string_builder_type;

  -- Converts a string builder into a whitespace-terminated fixed length string
  -- for simulation.
  function ssb2sim(input: sim_string_builder_type) return sim_string_type;

  -- Converts a string builder or fixed-length string into a variable-length string.
  function ssb2str(input: sim_string_builder_type) return string;
  function ssb2str(input: sim_string_type) return string;

  -- Converts an unsigned std_logic_vector to a string, representing it in
  -- decimal notation.
  function sim_uint(value: std_logic_vector) return string;

  -- Converts a signed std_logic_vector to a string, representing it in decimal
  -- notation.
  function sim_int(value: std_logic_vector) return string;

  -- Converts an std_logic_vector to a string in hexadecimal notation,
  -- prefixing 0x.
  function sim_hex(value: std_logic_vector) return string;
  function sim_hex(value: std_logic_vector; digits: natural) return string;

  -- Converts an std_logic_vector to a string in hexadecimal notation,
  -- WITHOUT prefixing 0x.
  function sim_hex_no0x(value: std_logic_vector) return string;
  function sim_hex_no0x(value: std_logic_vector; digits: natural) return string;

  -- Converts an std_logic_vector to a string in binary notation,
  -- prefixing 0b.
  function sim_bin(value: std_logic_vector) return string;
  function sim_bin(value: std_logic_vector; digits: natural) return string;

  -- Converts an std_logic_vector to a string in binary notation,
  -- WITHOUT prefixing 0b.
  function sim_bin_no0b(value: std_logic_vector) return string;
  function sim_bin_no0b(value: std_logic_vector; digits: natural) return string;

  -----------------------------------------------------------------------------
  -- Misc. methods
  -----------------------------------------------------------------------------
  -- Extracts the range (high downto low) from value, with safeguards to
  -- prevent errors when the range does not (fully) exist in value of when
  -- value has an ascending (x to y) range. Bits which do not exist in value
  -- are substituted with def.
  function sim_extractStdLogicVectRange(value: std_logic_vector; high: natural; low: natural; def: std_logic) return std_logic_vector;

  -- Randomizes the contents of the supplied std_logic_vector.
  procedure sim_randomVect(seed1: inout positive; seed2: inout positive; value: inout std_logic_vector);

  -- Dumps the given string to stdout. Works like a report statement, but
  -- doesn't have all the simulator fluff around it.
  procedure dumpStdOut(s: string);
  
  -- Short-hand for integer'image(i)
  function ii(i : integer) return string;
  
  -- Short-hand for integer'image(to_integer(u))
  function ii(u : unsigned) return string;
  
  -- Short-hand for integer'image(to_integer(s))
  function ii(s : signed) return string;

end SimUtils;

--=============================================================================
package body SimUtils is
--=============================================================================

  -----------------------------------------------------------------------------
  -- Basic string manipulation
  -----------------------------------------------------------------------------
  -- Returns true if given character is alphabetical.
  function isAlphaChar(c: character) return boolean is
    variable result: boolean;
  begin
    case c is
      when 'a' => result := true; when 'A' => result := true;
      when 'b' => result := true; when 'B' => result := true;
      when 'c' => result := true; when 'C' => result := true;
      when 'd' => result := true; when 'D' => result := true;
      when 'e' => result := true; when 'E' => result := true;
      when 'f' => result := true; when 'F' => result := true;
      when 'g' => result := true; when 'G' => result := true;
      when 'h' => result := true; when 'H' => result := true;
      when 'i' => result := true; when 'I' => result := true;
      when 'j' => result := true; when 'J' => result := true;
      when 'k' => result := true; when 'K' => result := true;
      when 'l' => result := true; when 'L' => result := true;
      when 'm' => result := true; when 'M' => result := true;
      when 'n' => result := true; when 'N' => result := true;
      when 'o' => result := true; when 'O' => result := true;
      when 'p' => result := true; when 'P' => result := true;
      when 'q' => result := true; when 'Q' => result := true;
      when 'r' => result := true; when 'R' => result := true;
      when 's' => result := true; when 'S' => result := true;
      when 't' => result := true; when 'T' => result := true;
      when 'u' => result := true; when 'U' => result := true;
      when 'v' => result := true; when 'V' => result := true;
      when 'w' => result := true; when 'W' => result := true;
      when 'x' => result := true; when 'X' => result := true;
      when 'y' => result := true; when 'Y' => result := true;
      when 'z' => result := true; when 'Z' => result := true;
      when others => result := false;
    end case;
    return result;
  end isAlphaChar;

  -- Returns true if given character is numeric.
  function isNumericChar(c: character) return boolean is
    variable result: boolean;
  begin
    case c is
      when '0' => result := true; when '1' => result := true;
      when '2' => result := true; when '3' => result := true;
      when '4' => result := true; when '5' => result := true;
      when '6' => result := true; when '7' => result := true;
      when '8' => result := true; when '9' => result := true;
      when others => result := false;
    end case;
    return result;
  end isNumericChar;

  -- Returns true if given character is alphanumerical.
  function isAlphaNumericChar(c: character) return boolean is
  begin
    return isAlphaChar(c) or isNumericChar(c);
  end isAlphaNumericChar;

  -- Returns true if given character is whitespace.
  function isWhitespaceChar(c: character) return boolean is
    variable result: boolean;
  begin
    case c is
      when ' ' => result := true;
      when HT => result := true;
      when LF => result := true;
      when CR => result := true;
      when others => result := false;
    end case;
    return result;
  end isWhitespaceChar;

  -- Returns true if given character is a special character (not alphanumerical
  -- and not whitespace).
  function isSpecialChar(c: character) return boolean is
  begin
    return not isAlphaNumericChar(c) and not isWhitespaceChar(c);
  end isSpecialChar;

  -- Converts a character to uppercase.
  function upperChar(
    c: character
  ) return character is
    variable result: character;
  begin
    case c is
      when 'a' => result := 'A';
      when 'b' => result := 'B';
      when 'c' => result := 'C';
      when 'd' => result := 'D';
      when 'e' => result := 'E';
      when 'f' => result := 'F';
      when 'g' => result := 'G';
      when 'h' => result := 'H';
      when 'i' => result := 'I';
      when 'j' => result := 'J';
      when 'k' => result := 'K';
      when 'l' => result := 'L';
      when 'm' => result := 'M';
      when 'n' => result := 'N';
      when 'o' => result := 'O';
      when 'p' => result := 'P';
      when 'q' => result := 'Q';
      when 'r' => result := 'R';
      when 's' => result := 'S';
      when 't' => result := 'T';
      when 'u' => result := 'U';
      when 'v' => result := 'V';
      when 'w' => result := 'W';
      when 'x' => result := 'X';
      when 'y' => result := 'Y';
      when 'z' => result := 'Z';
      when others => result := c;
    end case;
    return result;
  end upperChar;

  -- Converts a character to its numeric value, supporting all hexadecimal
  -- digits. Returns -1 when the character is not hexadecimal.
  function charToDigitVal(
    c: character
  ) return integer is
    variable result: integer;
  begin
    case c is
      when '0' => result := 0;
      when '1' => result := 1;
      when '2' => result := 2;
      when '3' => result := 3;
      when '4' => result := 4;
      when '5' => result := 5;
      when '6' => result := 6;
      when '7' => result := 7;
      when '8' => result := 8;
      when '9' => result := 9;
      when 'a' => result := 10;
      when 'b' => result := 11;
      when 'c' => result := 12;
      when 'd' => result := 13;
      when 'e' => result := 14;
      when 'f' => result := 15;
      when 'A' => result := 10;
      when 'B' => result := 11;
      when 'C' => result := 12;
      when 'D' => result := 13;
      when 'E' => result := 14;
      when 'F' => result := 15;
      when others => result := -1;
    end case;
    return result;
  end charToDigitVal;

  -- Converts a hex character to an std_logic_vector of length 4. Special
  -- characters are supported.
  function charToStdLogic(c: character) return std_logic_vector is
    variable intVal : integer;
  begin
    intVal := charToDigitVal(c);
    if intVal > -1 then
      return std_logic_vector(to_unsigned(intVal, 4));
    end if;
    case c is
      when 'L' => return "LLLL";
      when 'H' => return "HHHH";
      when 'U' => return "UUUU";
      when 'Z' => return "ZZZZ";
      when '-' => return "----";
      when others => return "XXXX";
    end case;
  end charToStdLogic;

  -- Tests whether two characters match, ignoring case.
  function charsEqual(
    a: character;
    b: character
  ) return boolean is
  begin
    return upperChar(a) = upperChar(b);
  end charsEqual;

  -- Tests whether line equals match, case insensitive.
  function matchStr(
    s1    : in string;
    s2    : in string
  ) return boolean is
  begin
    if s1'length /= s2'length then
      return false;
    end if;
    for i in s1'range loop
      if not charsEqual(s1(i), s2(i+s2'low-s1'low)) then
        return false;
      end if;
    end loop;
    return true;
  end matchStr;

  -- Tests whether line contains match at position pos (case insensitive).
  function matchAt(
    line  : in string;
    pos   : in positive;
    match : in string
  ) return boolean is
    variable posInt: positive;
  begin
    posInt := pos;
    for matchPos in match'range loop
      if posInt > line'length then
        return false;
      end if;
      if not charsEqual(match(matchPos), line(posInt)) then
        return false;
      end if;
      posInt := posInt + 1;
    end loop;
    return true;
  end matchAt;

  -----------------------------------------------------------------------------
  -- Fixed-length string manipulation
  -----------------------------------------------------------------------------
  -- Clears a string builder.
  procedure sim_clear(sb: inout sim_string_builder_type) is
  begin
    sb.len := 0;
  end sim_clear;

  -- Removes trailing spaces from a string builder.
  procedure sim_trimTrailingSpaces(sb: inout sim_string_builder_type) is
  begin
    while sb.len > 0 loop
      exit when sb.s(sb.len) /= ' ';
      sb.len := sb.len - 1;
    end loop;
  end sim_trimTrailingSpaces;

  -- Capitalizes the first character in a string builder.
  procedure sim_capitalize(sb: inout sim_string_builder_type) is
  begin
    sb.s(1) := upperChar(sb.s(1));
  end sim_capitalize;

  -- Converts a VHDL unbounded string to a string builder.
  function to_ssb(input: string) return sim_string_builder_type is
    variable result: sim_string_builder_type;
  begin
    if input'high > SIM_STR_LEN then
      result.s := input(input'low to SIM_STR_LEN+input'low-1);
      result.len := SIM_STR_LEN;
    else
      result.s(1 to input'length) := input;
      result.len := input'length;
    end if;
    return result;
  end to_ssb;

  -- Appends a character to a string builder.
  procedure sim_append(sb: inout sim_string_builder_type; c: character) is
  begin
    if sb.len < SIM_STR_LEN then
      sb.len := sb.len + 1;
      sb.s(sb.len) := c;
    end if;
  end sim_append;
  function "&"(L: sim_string_builder_type; R: character) return sim_string_builder_type is
    variable result: sim_string_builder_type;
  begin
    result := L;
    sim_append(result, R);
    return result;
  end "&";

  -- Appends a VHDL string to a string builder.
  procedure sim_append(sb: inout sim_string_builder_type; s: string) is
  begin
    if sb.len + s'length <= SIM_STR_LEN then
      sb.s(sb.len+1 to sb.len+s'length) := s;
      sb.len := sb.len + s'length;
    else
      sb.s(sb.len+1 to sb.len+s'length) := s;
      sb.len := sb.len + s'length;
    end if;
  end sim_append;
  function "&"(L: sim_string_builder_type; R: string) return sim_string_builder_type is
    variable result: sim_string_builder_type;
  begin
    result := L;
    sim_append(result, R);
    return result;
  end "&";

  -- Appends a string builder to a string builder.
  procedure sim_append(sb: inout sim_string_builder_type; sb2: sim_string_builder_type) is
  begin
    if sb.len + sb2.len <= SIM_STR_LEN then
      sb.s(sb.len+1 to sb.len+sb2.len) := sb2.s(1 to sb2.len);
      sb.len := sb.len + sb2.len;
    else
      sb.s(sb.len+1 to SIM_STR_LEN) := sb2.s(1 to SIM_STR_LEN-sb.len);
      sb.len := SIM_STR_LEN;
    end if;
  end sim_append;
  function "&"(L: sim_string_builder_type; R: sim_string_builder_type) return sim_string_builder_type is
    variable result: sim_string_builder_type;
  begin
    result := L;
    sim_append(result, R);
    return result;
  end "&";

  -- Converts a string builder into a whitespace-terminated fixed length string
  -- for simulation.
  function ssb2sim(input: sim_string_builder_type) return sim_string_type is
    variable result: sim_string_type;
  begin
    result := (others => ' ');
    result(1 to input.len) := input.s(1 to input.len);
    return result;
  end ssb2sim;

  -- Converts a string builder or fixed-length string into a variable-length
  -- string.
  function ssb2str(input: sim_string_builder_type) return string is
  begin
    return input.s(1 to input.len);
  end ssb2str;
  function ssb2str(input: sim_string_type) return string is
    variable sb : sim_string_builder_type;
  begin
    sb := to_ssb(input);
    sim_trimTrailingSpaces(sb);
    return ssb2str(sb);
  end ssb2str;

  -- Converts an unsigned std_logic_vector to a string, representing it in
  -- decimal notation.
  function sim_uint(value: std_logic_vector) return string is
    variable temp : unsigned(value'length-1 downto 0);
    variable digit : integer;
    variable s : string(1 to SIM_STR_LEN);
    variable index : natural;
  begin
    temp := unsigned(value);
    if temp = 0 then
      return "0";
    end if;
    index := SIM_STR_LEN;
    while temp > 0 loop
      digit := to_integer(temp mod 10);
      temp := temp / 10;
      case digit is
        when 0 => s(index) := '0';
        when 1 => s(index) := '1';
        when 2 => s(index) := '2';
        when 3 => s(index) := '3';
        when 4 => s(index) := '4';
        when 5 => s(index) := '5';
        when 6 => s(index) := '6';
        when 7 => s(index) := '7';
        when 8 => s(index) := '8';
        when 9 => s(index) := '9';
        when others => s(index) := '?';
      end case;
      index := index - 1;
    end loop;
    return s(index+1 to SIM_STR_LEN);
  end sim_uint;

  -- Converts a signed std_logic_vector to a string, representing it in decimal
  -- notation.
  function sim_int(value: std_logic_vector) return string is
    variable temp : signed(value'length-1 downto 0);
  begin
    temp := signed(value);
    if temp = 0 then
      return "0";
    elsif temp > 0 then
      return sim_uint(std_logic_vector(temp));
    else
      return "-" & sim_uint(std_logic_vector(0-temp));
    end if;
  end sim_int;

  -- Converts an std_logic_vector to a string in hexadecimal notation,
  -- prefixing 0x.
  function sim_hex(value: std_logic_vector) return string is
  begin
    return "0x" & sim_hex_no0x(value);
  end sim_hex;
  function sim_hex(value: std_logic_vector; digits: natural) return string is
  begin
    return "0x" & sim_hex_no0x(value, digits);
  end sim_hex;

  -- Converts an std_logic_vector to a string in hexadecimal notation,
  -- WITHOUT prefixing 0x.
  function sim_hex_no0x(value: std_logic_vector) return string is
  begin
    return sim_hex_no0x(value, (value'length-1) / 4 + 1);
  end sim_hex_no0x;
  function sim_hex_no0x(value: std_logic_vector; digits: natural) return string is
    variable normalized : std_logic_vector(value'length-1 downto 0);
    variable s : string(1 to digits);
    variable temp : std_logic_vector(3 downto 0);
  begin
    normalized := value;
    for i in 0 to digits-1 loop
      temp := to_X01Z(sim_extractStdLogicVectRange(normalized, i*4+3, i*4, '0'));
      case temp is
        when "0000" => s(digits-i) := '0';
        when "0001" => s(digits-i) := '1';
        when "0010" => s(digits-i) := '2';
        when "0011" => s(digits-i) := '3';
        when "0100" => s(digits-i) := '4';
        when "0101" => s(digits-i) := '5';
        when "0110" => s(digits-i) := '6';
        when "0111" => s(digits-i) := '7';
        when "1000" => s(digits-i) := '8';
        when "1001" => s(digits-i) := '9';
        when "1010" => s(digits-i) := 'A';
        when "1011" => s(digits-i) := 'B';
        when "1100" => s(digits-i) := 'C';
        when "1101" => s(digits-i) := 'D';
        when "1110" => s(digits-i) := 'E';
        when "1111" => s(digits-i) := 'F';
        when others =>
          temp := sim_extractStdLogicVectRange(normalized, i*4+3, i*4, '0');
          case temp is
            when "XXXX" => s(digits-i) := 'X';
            when "UUUU" => s(digits-i) := 'U';
            when "LLLL" => s(digits-i) := 'L';
            when "HHHH" => s(digits-i) := 'H';
            when "ZZZZ" => s(digits-i) := 'Z';
            when "----" => s(digits-i) := '-';
            when others => s(digits-i) := '?';
          end case;
      end case;
    end loop;
    return s;
  end sim_hex_no0x;

  -- Converts an std_logic_vector to a string in binary notation,
  -- prefixing 0b.
  function sim_bin(value: std_logic_vector) return string is
  begin
    return "0b" & sim_bin_no0b(value);
  end sim_bin;
  function sim_bin(value: std_logic_vector; digits: natural) return string is
  begin
    return "0b" & sim_bin_no0b(value, digits);
  end sim_bin;

  -- Converts an std_logic_vector to a string in binary notation,
  -- WITHOUT prefixing 0b.
  function sim_bin_no0b(value: std_logic_vector) return string is
  begin
    return sim_bin_no0b(value, value'length);
  end sim_bin_no0b;
  function sim_bin_no0b(value: std_logic_vector; digits: natural) return string is
    variable normalized : std_logic_vector(value'length-1 downto 0);
    variable s : string(1 to digits);
    variable temp : std_logic_vector(0 downto 0);
  begin
    normalized := value;
    for i in 0 to digits-1 loop
      temp := sim_extractStdLogicVectRange(normalized, i, i, '0');
      case temp is
        when "0" => s(digits-i) := '0';
        when "1" => s(digits-i) := '1';
        when "X" => s(digits-i) := 'X';
        when "U" => s(digits-i) := 'U';
        when "L" => s(digits-i) := 'L';
        when "H" => s(digits-i) := 'H';
        when "Z" => s(digits-i) := 'Z';
        when "-" => s(digits-i) := '-';
        when others => s(digits-i) := '?';
      end case;
    end loop;
    return s;
  end sim_bin_no0b;

  -----------------------------------------------------------------------------
  -- Misc. methods
  -----------------------------------------------------------------------------
  -- Extracts the range (high downto low) from value, with safeguards to
  -- prevent errors when the range does not (fully) exist in value of when
  -- value has an ascending (x to y) range. Bits which do not exist in value
  -- are substituted with def.
  function sim_extractStdLogicVectRange(value: std_logic_vector; high: natural; low: natural; def: std_logic) return std_logic_vector is
    variable result: std_logic_vector(high downto low);
  begin
    for i in high downto low loop
      if (i < value'low) or (i > value'high) then
        result(i) := def;
      else
        result(i) := value(i);
      end if;
    end loop;
    return result;
  end sim_extractStdLogicVectRange;

  -- Randomizes the contents of the supplied std_logic_vector.
  procedure sim_randomVect(seed1: inout positive; seed2: inout positive; value: inout std_logic_vector) is
    variable rv     : real;
    variable iv     : natural;
    variable iters  : natural;
    variable remain : natural;
  begin
    for i in 0 to (value'length / 8) - 1 loop
      uniform(seed1, seed2, rv);
      iv := integer(trunc(rv * 256.0));
      value(value'low + i*8 + 7 downto value'low + i*8) := std_logic_vector(to_unsigned(iv, 8));
    end loop;
    if (value'length mod 8) /= 0 then
      uniform(seed1, seed2, rv);
      iv := integer(trunc(rv * 256.0));
      value(value'high downto value'high - 7) := std_logic_vector(to_unsigned(iv, 8));
    end if;
  end sim_randomVect;

  -- Dumps the given string to stdout. Works like a report statement, but
  -- doesn't have all the simulator fluff around it.
  procedure dumpStdOut(s: string) is
    variable ln : std.textio.line;
  begin
    -- pragma translate_off
    ln := new string(1 to s'length);
    ln.all := s;
    writeline(std.textio.output, ln);
    if ln /= null then
      deallocate(ln);
    end if;
    -- pragma translate_on
  end procedure;
  
  function ii(i : integer) return string is
  begin
    return integer'image(i);
  end function;
  
  function ii(u : unsigned) return string is
  begin
    return integer'image(to_integer(u));
  end function;
  
    function ii(s : signed) return string is
  begin
    return integer'image(to_integer(s));
  end function;

end SimUtils;
