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

package Utils is

  -- Array of naturals.
  type nat_array is array (natural range <>) of natural;

  -- Takes a natural array of lengths and returns an index array with similar
  -- semantics to Arrow offsets buffers. That is, the output is one entry longer
  -- than the input, the first (low) entry is zero, the last (high) entry is
  -- the sum of the sizes array, and the values in between are the sum of the
  -- sizes array up to the index.
  function cumulative(sizes: nat_array) return nat_array;

  -- Returns the sum of an array of naturals.
  function sum(nats: nat_array) return natural;

  -- Returns (s ? t : f).
  function sel(s: boolean; t: integer; f: integer) return integer;
  function sel(s: boolean; t: boolean; f: boolean) return boolean;

  -- Returns min(a, b).
  function min(a: integer; b: integer) return integer;

  -- Returns max(a, b).
  function max(a: integer; b: integer) return integer;

  -- Returns ceil(log2(i)).
  function log2ceil(i: natural) return natural;

  -- Returns floor(log2(i)).
  function log2floor(i: natural) return natural;

  -- Returns a with its byte endianness swapped.
  function endian_swap(a : in std_logic_vector) return std_logic_vector;

  function is_full(a : in std_logic_vector; b : in std_logic_vector) return std_logic;
  function is_full(a : in unsigned; b : in unsigned) return std_logic;

  function is_empty(a : in std_logic_vector; b : in std_logic_vector) return std_logic;
  function is_empty(a : in unsigned; b : in unsigned) return std_logic;

  -- Returns a as integer
  function int(a : in std_logic_vector) return integer;
  function int(a : in unsigned) return integer;
  function int(a : in signed) return integer;

  -- Returns a as std_logic_vector
  function slv(a : in integer; b : in natural) return std_logic_vector;
  function slv(a : in unsigned) return std_logic_vector;

  -- Returns the sign-extended version of a with length b
  function sext(a : in unsigned; b : in natural) return unsigned;

  -- Returns a as unsigned
  function u(a : in integer; b : in natural) return unsigned;
  function u(a : in std_logic_vector) return unsigned;
  function u(a : in std_logic) return unsigned;

  -- Returns a as std_logic
  function l(a : in boolean) return std_logic;

  -- Returns the number of '1''s in a
  function ones(a : in std_logic_vector) return natural;

  -- Shifts a right b by and cuts off lost bits
  function shift_right_cut(a : in unsigned; b : in natural) return unsigned;

  -- Shifts a left by b if b is positive, shifts a right by |b| if b is negative
  function shift_left_with_neg (a: in unsigned; b : in integer) return unsigned;

  -- Shifts a left by b if b is positive, shifts a right by |b| if b is negative and rounds up if non-zero bits are shifted out.
  function shift_left_with_neg_round_up (a: in unsigned; b : in integer) return unsigned;

  -- Returns ceil(a / (2^b))
  function shift_right_round_up (a: in unsigned; b : in natural) return unsigned;

  -- Returns floor(a / b) where b is a power of 2
  function div_floor(a : in unsigned; b : in natural) return unsigned;

  -- Return ceil(a / b) where b is a power of 2
  function div_ceil(a : in unsigned; b : in natural) return unsigned;

  -- Returns a*b where b is a power of 2
  function mul(a : in unsigned; b : in natural) return unsigned;

  -- Returns the first integer multiple of 2^b below or equal to a
  function align_beq(a : in unsigned; b : in natural) return unsigned;

  -- Returns the first integer multiple of 2^b above or equal to a
  function align_aeq(a : in unsigned; b : in natural) return unsigned;

  -- Returns true if a is an integer multiple of 2^b, false otherwise
  function is_aligned(a : in unsigned; b : natural) return boolean;

  -- Returns the thermometer/unary-coded version of a count with implicit '1' MSB
  function cnt2th(a: in unsigned; bits : natural) return std_logic_vector;

  -- Returns the count with implicit '1' MSB of a one-hot- or thermometer/unary-encoded value
  function th2cnt(a: in std_logic_vector) return unsigned;

  -- 1-read 1-write RAM.
  component Ram1R1W is
    generic (
      WIDTH                     : natural;
      DEPTH_LOG2                : natural;
      RAM_CONFIG                : string := ""
    );
    port (
      w_clk                     : in  std_logic;
      w_ena                     : in  std_logic;
      w_addr                    : in  std_logic_vector(DEPTH_LOG2-1 downto 0);
      w_data                    : in  std_logic_vector(WIDTH-1 downto 0);
      r_clk                     : in  std_logic;
      r_ena                     : in  std_logic := '1';
      r_addr                    : in  std_logic_vector(DEPTH_LOG2-1 downto 0);
      r_data                    : out std_logic_vector(WIDTH-1 downto 0)
    );
  end component;

end Utils;

package body Utils is

  function cumulative(sizes: nat_array) return nat_array is
    variable result : nat_array(sizes'length downto 0);
  begin
    result(0) := 0;
    for i in 0 to sizes'length-1 loop
      result(i+1) := result(i) + sizes(i);
    end loop;
    return result;
  end cumulative;

  function sum(nats: nat_array) return natural is
    variable res  : natural;
  begin
    res := 0;
    for i in nats'range loop
      res := res + nats(i);
    end loop;
    return res;
  end function;

  function sel(s: boolean; t: integer; f: integer) return integer is
  begin
    if s then
      return t;
    else
      return f;
    end if;
  end sel;

  function sel(s: boolean; t: boolean; f: boolean) return boolean is
  begin
    if s then
      return t;
    else
      return f;
    end if;
  end sel;

  function min(a: integer; b: integer) return integer is
  begin
    return sel(a < b, a, b);
  end min;

  function max(a: integer; b: integer) return integer is
  begin
    return sel(a > b, a, b);
  end max;

  function log2ceil(i: natural) return natural is
    variable x, y : natural;
  begin
    x := i;
    y := 0;
    while x > 1 loop
      x := (x + 1) / 2;
      y := y + 1;
    end loop;
    return y;
  end log2ceil;

  function log2floor(i: natural) return natural is
    variable x, y : natural;
  begin
    x := i;
    y := 0;
    while x > 1 loop
      x := x / 2;
      y := y + 1;
    end loop;
    return y;
  end log2floor;

  function endian_swap (a : in std_logic_vector) return std_logic_vector is
    variable result         : std_logic_vector(a'range);
    constant bytes          : natural := a'length / 8;
  begin
    for i in 0 to bytes - 1 loop
      result(8 * i + 7 downto 8 * i) := a((bytes - 1 - i) * 8 + 7 downto (bytes - 1 - i) * 8);
    end loop;
    return                  result;
  end function endian_swap;

  function is_full (a : in std_logic_vector; b : in std_logic_vector) return std_logic is
    variable result         : std_logic;
  begin
    if a(a'high) /= b(b'high) and a(a'high - 1 downto a'low) = b(b'high - 1 downto b'low) then
      result                := '1';
    else
      result                := '0';
    end if;
    return                  result;
  end function is_full;

  function is_full (a : in unsigned; b : in unsigned) return std_logic is
    variable result         : std_logic;
  begin
    if a(a'high) /= b(b'high) and a(a'high - 1 downto a'low) = b(b'high - 1 downto b'low) then
      result                := '1';
    else
      result                := '0';
    end if;
    return                  result;
  end function is_full;

  function is_empty (a : in std_logic_vector; b : in std_logic_vector) return std_logic is
    variable result         : std_logic;
  begin
    if a = b then
      result                := '1';
    else
      result                := '0';
    end if;
    return                  result;
  end function is_empty;

  function is_empty (a : in unsigned; b : in unsigned) return std_logic is
    variable result         : std_logic;
  begin
    if a = b then
      result                := '1';
    else
      result                := '0';
    end if;
    return                  result;
  end function is_empty;

  function int (a : in std_logic_vector) return integer is
  begin
    return                  to_integer(unsigned(a));
  end function int;

  function int (a : in unsigned) return integer is
  begin
    return                  to_integer(a);
  end function int;

  function int (a : in signed) return integer is
  begin
    return                  to_integer(a);
  end function int;

  function slv (a : in integer; b : in natural) return std_logic_vector is
  begin
    return                  std_logic_vector(to_unsigned(a, b));
  end function slv;

  function slv (a : in unsigned) return std_logic_vector is
  begin
    return                  std_logic_vector(a);
  end function slv;

  function sext (a : in unsigned; b : in natural) return unsigned is
    variable result : unsigned(b-1 downto 0);
  begin
    result(a'high downto 0) := a;
    result(b-1 downto a'high+1) := (others => a(a'high));
    return result;
  end function sext;

  function u (a : in integer; b : in natural) return unsigned is
  begin
    return to_unsigned(a, b);
  end function u;

  function u (a : in std_logic_vector) return unsigned is
  begin
    return                  unsigned(a);
  end function u;

  function u (a : in std_logic) return unsigned is
    variable result         : unsigned(0 downto 0);
  begin
    if a='1' then
      result                := u("1");
    else
      result                := u("0");
    end if;
    return result;
  end function u;

  function l (a: in boolean) return std_logic is
    variable result         : std_logic;
  begin
    if a then
      result                := '1';
    else
      result                := '0';
    end if;
    return                  result;
  end function l;

  function ones (a : in std_logic_vector) return natural is
    variable result         : natural := 0;
  begin
    for i in a'range loop
      if a(i)='1' then
        result              := result + 1;
      end if;
    end loop;
    return                  result;
  end function ones;

  function shift_right_cut (a : in unsigned; b : in natural) return unsigned is
    variable shifted : unsigned(a'range);
  begin
    shifted := shift_right(a, b);
    return shifted(a'high-b downto 0);
  end function shift_right_cut;

  function shift_right_round_up(a : in unsigned; b : in natural) return unsigned is
    variable arg_v : unsigned(a'length-1 downto 0);
    variable lsb_v : unsigned(b-1 downto 0);
  begin
    if b /= 0 then -- prevent null ranges on lsb_v
      arg_v := shift_right(a, b);
      lsb_v := a(b-1 downto 0);
      if (lsb_v /= 0) then
        arg_v := arg_v + 1;
      end if;
    else
      arg_v := a;
    end if;
    return arg_v;
  end shift_right_round_up;

  function shift_left_with_neg (a: in unsigned; b : in integer) return unsigned is
  begin
    if b >= 0 then
      return shift_left(a, b);
    else
      return shift_right(a, -b);
    end if;
  end function shift_left_with_neg;

  function shift_left_with_neg_round_up (a: in unsigned; b : in integer) return unsigned is
  begin
    if b >= 0 then
      return shift_left(a, b);
    else
      return shift_right_round_up(a, -b);
    end if;
  end function shift_left_with_neg_round_up;

  function div_floor(a: in unsigned; b : in natural) return unsigned is
  begin
    assert log2ceil(b) = log2floor(b) report "div_p2_floor() second argument is not a power of 2." severity failure;
    return shift_right(a, log2floor(b));
  end div_floor;

  function div_ceil(a: in unsigned; b : in natural) return unsigned is
  begin
    assert log2ceil(b) = log2floor(b) report "div_p2_ceil() second argument is not a power of 2." severity failure;
    return shift_right_round_up(a, log2floor(b));
  end div_ceil;

  function mul(a: in unsigned; b : in natural) return unsigned is
  begin
    assert log2ceil(b) = log2floor(b) report "mul() second argument is not a power of 2." severity failure;
    return shift_left(a, log2floor(b));
  end mul;

  function align_beq(a : in unsigned; b : in natural) return unsigned is
    variable arg_v : unsigned(a'length-1 downto 0);
  begin
    if b /= 0 then
      arg_v := shift_right(a,b);
    else
      arg_v := a;
    end if;
    return shift_left(arg_v, b);
  end align_beq;

  function align_aeq(a : in unsigned; b : in natural) return unsigned is
    variable arg_v : unsigned(a'length-1 downto 0);
    variable lsb_v : unsigned(b-1 downto 0);
  begin
    -- Do this all over again because xsim seems to have trouble
    -- with specific functions in functions so we cant use
    -- shift_right_round_up
    if b /= 0 then -- prevent null ranges on lsb_v
      arg_v := shift_right(a, b);
      lsb_v := a(b-1 downto 0);
      if (lsb_v /= 0) then
        arg_v := arg_v + 1;
      end if;
    else
      arg_v := a;
    end if;
    return shift_left(arg_v, b);
  end align_aeq;

  function is_aligned(a : in unsigned; b : natural) return boolean is
    variable lsb_v : unsigned(b-1 downto 0);
  begin
    if b > 0 then
      lsb_v := a(b-1 downto 0);
      if (lsb_v = 0) then
        return true;
      else
        return false;
      end if;
    else
      return true;
    end if;
  end is_aligned;

  function cnt2th(a: in unsigned; bits: natural) return std_logic_vector is
    type ret_array_type is array(0 to bits-1) of std_logic_vector(bits-1 downto 0);
    variable ret_array : ret_array_type;
  begin
    for i in 0 to bits-1 loop
      for j in 0 to i loop
        ret_array(i)(j) := '1';
      end loop;
      for j in i to bits-1 loop
        ret_array(i)(j) := '0';
      end loop;
    end loop;

    -- all zeros is max count
    ret_array(0) := (others => '1');

    return ret_array(to_integer(a) mod bits);
  end cnt2th;

  function th2cnt(a: in std_logic_vector) return unsigned is
    variable cnt : unsigned(log2ceil(a'length)-1 downto 0) := (others => '0');
  begin
    for i in 0 to a'length-1 loop
      if a(i) = '1' then
        cnt := cnt or to_unsigned(i, log2ceil(a'length));
      end if;
    end loop;
    return cnt;
  end th2cnt;

end Utils;
