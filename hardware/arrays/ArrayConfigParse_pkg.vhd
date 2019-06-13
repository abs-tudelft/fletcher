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
use work.UtilInt_pkg.all;
use work.UtilMisc_pkg.all;

package ArrayConfigParse_pkg is

  -- Implementations of integer'image and integer'value, because these
  -- constructs are not supported everywhere. Only supports positive
  -- integers!
  function strtoi(str: string) return natural;
  function itostr(val: natural) return string;

  -- Returns the toplevel command name for the given configuration string.
  function parse_command(cfg: string) return string;

  -- Returns the number of arguments for the given configuration string.
  function parse_nargs(cfg: string) return natural;

  -- Returns the idx'th argument.
  function parse_arg(cfg: string; idx: natural) return string;

  -- Returns the parameter named "param", or the given default value if it is
  -- not specified.
  function parse_param(cfg: string; param: string; default_val: string) return string;
  function parse_param(cfg: string; param: string; default_val: integer) return integer;
  function parse_param(cfg: string; param: string; default_val: boolean) return boolean;

end ArrayConfigParse_pkg;

package body ArrayConfigParse_pkg is

  -- Implementations of integer'image and integer'value, because these
  -- constructs are not supported everywhere. Only supports positive
  -- integers!
  function strtoi(str: string) return natural is
    variable res  : natural;
  begin
    res := 0;
    for i in str'range loop
      if str(i) = '0' then
        res := res * 10;
      elsif str(i) = '1' then
        res := res * 10 + 1;
      elsif str(i) = '2' then
        res := res * 10 + 2;
      elsif str(i) = '3' then
        res := res * 10 + 3;
      elsif str(i) = '4' then
        res := res * 10 + 4;
      elsif str(i) = '5' then
        res := res * 10 + 5;
      elsif str(i) = '6' then
        res := res * 10 + 6;
      elsif str(i) = '7' then
        res := res * 10 + 7;
      elsif str(i) = '8' then
        res := res * 10 + 8;
      elsif str(i) = '9' then
        res := res * 10 + 9;
      else
        report "Cannot convert " & str & " to integer" severity FAILURE;
      end if;
    end loop;
    return res;
  end function;

  function itostr(val: natural) return string is
    variable remain : natural;
    variable modulo : natural;
    variable res    : string(1 to 7);
    variable start  : natural;
  begin
    remain := val;
    res := (others => '0');
    start := 7;
    for i in 7 downto 0 loop
      exit when remain = 0;
      start := i;

      modulo := remain mod 10;
      remain := remain / 10;

      if modulo = 1 then
        res(i) := '1';
      elsif modulo = 2 then
        res(i) := '2';
      elsif modulo = 3 then
        res(i) := '3';
      elsif modulo = 4 then
        res(i) := '4';
      elsif modulo = 5 then
        res(i) := '5';
      elsif modulo = 6 then
        res(i) := '6';
      elsif modulo = 7 then
        res(i) := '7';
      elsif modulo = 8 then
        res(i) := '8';
      elsif modulo = 9 then
        res(i) := '9';
      end if;

    end loop;

    return res(start to 7);
  end function;

  -- Returns true if given character is alphanumerical.
  function isAlphaNumeric(c: character) return boolean is
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
      when '0' => result := true; when '1' => result := true;
      when '2' => result := true; when '3' => result := true;
      when '4' => result := true; when '5' => result := true;
      when '6' => result := true; when '7' => result := true;
      when '8' => result := true; when '9' => result := true;
      when others => result := false;
    end case;
    return result;
  end isAlphaNumeric;

  -- Normalizes a string range to (1 to length).
  function norm(s: string) return string is
    constant sn : string(1 to s'length) := s;
  begin
    return sn;
  end function;

  -- Returns the toplevel command name for the given configuration string.
  function parse_command(cfg: string) return string is
  begin

    -- Empty strings are an error.
    if cfg'length = 0 then
      report "Configuration string parse error: expecting name, got ''."
        severity FAILURE;
    end if;

    -- Strings that don't start with an alphanumeric character are an error.
    if not isAlphaNumeric(cfg(1)) then
      report "Configuration string parse error: expecting name, got '" & cfg & "'."
        severity FAILURE;
    end if;

    -- Find the open-parenthesis, then return up to that point.
    for i in 2 to cfg'length loop

      -- If this is the open-parenthesis, return up to this point.
      if cfg(i) = '(' then
        return cfg(1 to i-1);
      end if;

      -- All characters in a name must be alphanumeric.
      if not isAlphaNumeric(cfg(i)) then
        report "Configuration string parse error: expecting name character or '(', got '" & cfg(i to i) & "'."
          severity FAILURE;
      end if;

    end loop;

    -- Commands must end in an open-parenthesis.
    report "Configuration string parse error: expecting '(' after '" & cfg & "'."
      severity FAILURE;
    return " ";

  end function;

  -- Returns the number of arguments for the given configuration string.
  function parse_nargs(cfg: string) return natural is
    variable nargs      : natural;
    variable depth      : natural;
    variable in_params  : boolean;
  begin
    nargs := 1;
    depth := 0;
    in_params := false;
    for i in 1 to cfg'length loop

      -- Add 1 to the parenthesis depth for '('.
      if cfg(i) = '(' then
        depth := depth + 1;

      -- Subtract 1 from the parenthesis depth for '('.
      elsif cfg(i) = ')' then

        -- If we're already at depth 0, we have an unmatched ')'.
        if depth = 0 then
          report "Configuration string parse error: unmatched ')'."
            severity FAILURE;
        end if;

        depth := depth - 1;

      -- Ignore non-parenthesis characters except when we're within our
      -- command's argument list.
      elsif depth = 1 then

        -- When we find a ; in our level, we've reached the end of the argument
        -- list.
        if cfg(i) = ';' then
          in_params := true;
        end if;

        -- When we find a , in our level and we're not in the parameter list,
        -- we've found another argument.
        if cfg(i) = ',' and not in_params then
          nargs := nargs + 1;
        end if;

      end if;
    end loop;

    -- If we're not at depth 0, we have an unmatched '('.
    if depth /= 0 then
      report "Configuration string parse error: unmatched '('."
        severity FAILURE;
    end if;

    return nargs;
  end function;

  -- Returns the i'th argument.
  function parse_arg(cfg: string; idx: natural) return string is
    variable curarg     : natural;
    variable depth      : natural;
    variable start      : positive;
    variable stop       : positive;
  begin
    curarg := 0;
    depth := 0;
    start := 1;
    stop := 1;
    for i in 1 to cfg'length loop

      -- Add 1 to the parenthesis depth for '('.
      if cfg(i) = '(' then
        depth := depth + 1;

        -- If we're now at depth 1, we've found the start of the first
        -- argument.
        if depth = 1 then
          start := i;
        end if;

      -- Subtract 1 from the parenthesis depth for '('.
      elsif cfg(i) = ')' then

        -- If we're already at depth 0, we have an unmatched ')'.
        if depth = 0 then
          report "Configuration string parse error: unmatched ')'."
            severity FAILURE;
        end if;

        -- If we're at depth 1, we've found the end of the last argument.
        if depth = 1 then
          stop := i;
          exit;
        end if;

        depth := depth - 1;

      -- Ignore non-parenthesis characters except when we're within our
      -- command's argument list.
      elsif depth = 1 then

        -- When we find a ; in our level, we've found the end of the last
        -- argument.
        if cfg(i) = ';' then
          stop := i;
          exit;
        end if;

        -- When we find a , in our level, we've found the end of an argument.
        if cfg(i) = ',' then

          -- End of an argument.
          stop := i;

          -- If this is the end of the argument we were looking for, return it.
          if curarg = idx then
            exit;
          end if;

          -- Start of a new argyment.
          curarg := curarg + 1;
          start := i;

        end if;

      end if;
    end loop;

    -- If we didn't find the argument, return an empty string. We do this in
    -- favor of reporting an error to prevent problems when synthesizers don't
    -- do lazy evaluation properly.
    if curarg /= idx or start+1 > stop-1 then
      return " ";
    end if;

    return norm(cfg(start+1 to stop-1));

  end function;

  -- Returns the parameter named "param", or the given default value if it is
  -- not specified.
  function parse_param(cfg: string; param: string; default_val: string) return string is
    variable depth      : natural;
    variable in_params  : boolean;
    variable start      : natural;
  begin
    depth := 0;
    in_params := false;
    start := 0;
    for i in 1 to cfg'length loop

      -- Add 1 to the parenthesis depth for '('.
      if cfg(i) = '(' then
        depth := depth + 1;

      -- Subtract 1 from the parenthesis depth for '('.
      elsif cfg(i) = ')' then

        -- If we're already at depth 0, we have an unmatched ')'.
        if depth = 0 then
          report "Configuration string parse error: unmatched ')'."
            severity FAILURE;
        end if;

        -- If we're at depth 1, we're at the end of our parameter list. If
        -- we've found the start of our parameter already, we can now return
        -- it.
        if depth = 1 and start > 0 then
          return norm(cfg(start to i - 1));
        end if;

        depth := depth - 1;

      -- Ignore non-parenthesis characters except when we're within our
      -- command's argument list.
      elsif depth = 1 then

        -- If we've found the start of our parameter already, return it if we
        -- encounter the comma separating it and the next parameter.
        if cfg(i) = ',' and start > 0 then
          return norm(cfg(start to i - 1));
        end if;

        -- When we find a ; in our level, we've reached the first parameter.
        -- If we're already in the parameter list and we encounter a ',', same
        -- story.
        if cfg(i) = ';' or (cfg(i) = ',' and in_params) then
          in_params := true;

          -- Match this parameter name against param.
          if i + param'length + 1 <= cfg'length then
            if cfg(i + 1 to i + param'length + 1) = param & "=" then

              -- Found the parameter.
              start := i + 1 + param'length + 1;

            end if;
          end if;

        end if;

      end if;
    end loop;

    -- If we're not at depth 0, we have an unmatched '('.
    if depth /= 0 then
      report "Configuration string parse error: unmatched '('."
        severity FAILURE;
    end if;

    return default_val;
  end function;

  function parse_param(cfg: string; param: string; default_val: integer) return integer is
  begin
    return strtoi(parse_param(cfg, param, integer'image(default_val)));
  end function;

  function parse_param(cfg: string; param: string; default_val: boolean) return boolean is
  begin
    if strtoi(parse_param(cfg, param, itostr(sel(default_val, 1, 0)))) = 0 then
      return false;
    else
      return true;
    end if;
  end function;

end ArrayConfigParse_pkg;
