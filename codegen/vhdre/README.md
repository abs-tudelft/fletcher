vhdre: a VHDL regex matcher generator
================================================================================

This python script allows you to generate a hardware implementation of a regular
expression matcher operating on UTF-8-encoded strings. The regular expression
features are limited, regex compilation is done prior to synthesis, and the unit
will only tell you *if* a string matched, but it can do so extremely fast. It's
intended to be used for needle-in-a-haystack searching, where the initial
reduction is so large that you can just let a CPU figure out where and how the
strings matched after letting vhdre do the initial filtering.

### Highlights ###

 - UTF-8 bytestream decoding with error detection (for most errors).

 - Stream interfaces compatible with AXI4.

 - Can match multiple regular expressions simultaneously using shared decoding
   logic.

 - Can matches multiple bytes (or even strings) per clock cycle depending on
   configuration.

 - Optimized for FPGAs with 6-input LUTs, with a critical path of only 2 LUTs
   per cycle for most regular expressions when configured for one byte per
   cycle matching.

 - Different interface styles varying in complexity.

### Dependencies ###

 - Python script: only Python 3.x and funcparserlib.

 - Generated VHDL: no dependencies, should synthesize/simulate using any
   VHDL-93 tool.


Supported regex features
-------------------------------------------------------------------------------

### Supported syntax ###

 - `x`     -> match `x` exactly.
 - `x*`    -> match `x` zero or more times.
 - `x+`    -> match `x` one or more times.
 - `x?`    -> match `x` zero or one times.
 - `xy`    -> match `x` followed by `y`.
 - `x|y`   -> match `x` or `y`.
 - `(x)`   -> parentheses are for disambiguation only (there are no capture
              groups).
 - `[x]`   -> character class (matches `x`).
 - `[^x]`  -> inverted character class (matches everything except `x`).
 - `[ab]`  -> match either `a` or `b`.
 - `[a-z]` -> match anything in the `a-z` code point range (inclusive).

### Escape sequences ###

Note that the unicode escape sequences deviate from the norm.

 - `\xHH`           -> `HH` = 2-digit hexadecimal code point
 - `\uHHHHHH`       -> `HHHHHH` = 6-digit hexadecimal code point
 - `\d`             -> `[0-9]`
 - `\w`             -> `[0-9a-zA-Z_]`
 - `\s`             -> `[ \a\b\t\n\v\f\r]`
 - `\a\b\t\n\v\f\r` -> the usual control character escape sequences
 - anything else matches the character behind the \ literally

### Notes ###

 - The matcher does regex *matching*. That is, the given string must match the
   regular expression exactly, as if it is surrounded by a `^` and a `$`. To do
   searching instead, prefix and/or append `.*`.

 - The following characters must be escaped outside character classes:
   `[\^$.|?*+()`

 - The following characters must be escaped inside character classes:
   `]-`

 - There is no difference between greedy and lazy matching in this engine. Any
   string that conforms to the regex in any way is considered to be a match.

 - A lot of the more advanced regex features are not supported because they
   require backtracking. This engine specifically can never do that, because
   it is based on a NFAE.


Usage
-------------------------------------------------------------------------------

`vhdre.py` is an executable Python 3 script. Running it without arguments will
give you some basic usage information:

```
$ python3 vhdre.py
Usage: ./vhdre.py <entity-name> <regex> ... [-- <test-string> ...]

Generates a file by the name <entity-name>.vhd in the working directory
which matches against the given regular expressions. If one or more test
strings are provided, a testbench by the name <entity-name>_tb.vhd is
also generated. To insert a unicode code point, use {0xHHHHHH:u}. To
insert a raw byte (for instance to check error handling) use {0xHH:b}.
{{ and }} can be used for matching { and } literally.
```

The script will compile the regular expression(s) into a nondeterministic
finite automaton, which it then builds a VHDL unit for. Just to avoid confusion
here: yes, the regular expressions are fixed after generation. They are NOT
runtime-configurable. You need to resynthesize your design if you want to
change the regex.

The generated VHDL unit can be instantiated in many different ways, varying
in complexity and speed. This is the simplest form:

```vhdl
lbl: entity work.<entity-name>
  port map (
    clk          => -- clock signal.
    in_valid     => -- signal indicating that there is an incoming byte.
    in_data      => -- the incoming byte.
    in_last      => -- signal indicating whether this byte is the last in
                    --   the string.
    out_valid    => -- signal indicating that a string has been received.
    out_match    => -- indicates which regular expressions were matched if
                    --   `out_valid` is high.
  );
```

The above signalling doesn't support empty strings. If you need that, we need
to add a "valid" flag that is independent of `in_last`: `in_mask`. Whenever
an empty string is received, simply set `in_mask` low and `in_last` high.

```vhdl
lbl: entity work.<entity-name>
  port map (
    clk          => -- clock signal.
    in_valid     => -- signal indicating that there is an incoming byte
                    --   or empty string.
    in_mask(0)   => -- signal indicating that there is an incoming byte.
    in_data      => -- the incoming byte.
    in_last      => -- signal indicating that this byte is the last in the
                    --   string, or if there is no byte, that the previous
                    --   byte was the last one, if any.
    out_valid    => -- signal indicating that a string has been received.
    out_match    => -- indicates which regular expressions were matched if
                    --   `out_valid` is high.
  );
```

Before we make things difficult, you can extend any of the port maps listed
here with one or more of the following signals depending on your needs:
 - `reset`: an active-high synchronous reset.
 - `aresetn`: an active-low asynchronous reset.
 - `clken`: active-high global clock enable signal.
 - `in_ready` & `out_ready`: AXI4-compatible backpressure signals, in case
   your output can stall. NOTE: backpressure is implemented trivially. If
   it gives you timing problems, read the "notes on backpressure and
   timing closure" section below.
 - `out_error` or `out_xerror`: output signal indicating whether an UTF-8
   decoding error occurred. `out_xerror` should be used instead of
   `out_error` ONLY by systems which handle multiple strings per cycle.

To get more speed, vhdre supports handling multiple bytes per cycle. Two
flavors are supported: one where the amount of *strings* per cycle is still
limited to one, and one where there is no such limitation. The latter
requires you to use a more complex output stream.

Here's the first flavor (at most one string per cycle):

```vhdl
lbl: entity work.<entity-name>
  generic map (
    BPC          => -- number of bytes per cycle.
  )
  port map (
    clk          => -- clock signal.
    in_valid     => -- signal indicating that there are incoming control
                    --   or data signals.
    in_mask      => -- signal indicating which of the incoming bytes are
                    --   valid. Its width is equal to BPC.
    in_data      => -- the incoming bytes. Its width is equal to BPC*8.
    in_last      => -- signal indicating that the last byte received so far
                    --   is the last byte of a string, if any.
    out_valid    => -- signal indicating that a string has been received.
    out_match    => -- indicates which regular expressions were matched if
                    --   `out_valid` is high.
  );
```

And here's the second flavor (no limitations). We use the word "slots" to
refer to the parallel matching engines since they no longer necessarily
correspond to valid bytes at this point.

```vhdl
lbl: entity work.<entity-name>
  generic map (
    BPC          => -- number of bytes per cycle.
  )
  port map (
    clk          => -- clock signal.
    in_valid     => -- signal indicating that there are incoming control
                    --   or data signals.
    in_mask      => -- signal indicating which of the incoming bytes are
                    --   valid. Its width is equal to BPC.
    in_data      => -- the incoming bytes for each slot. Its width is equal
                    --   to BPC*8.
    in_xlast     => -- signal indicating which of the byte slots are to be
                    --   interpreted as string boundaries. Its width is
                    --   equal to BPC.
    out_valid    => -- signal indicating that one or more strings have been
                    --   received.
    out_xmask    => -- indicates which of the parallel slots received a
                    --   string terminator. Its width is BPC.
    out_xmatch   => -- indicates which regular expressions were matched by
                    --   each slot. Its width is BPC.
  );
```

It is guaranteed that matches are reported by the same slot for which
`in_xlast` was set. Let's say that you have a system that can handle 8 bytes
per cycle, but strings always start at 4-byte boundaries, and you only want
to worry about handling at most two strings per cycle. In this case, you can
use only `in_xlast(3)` and `in_xlast(7)` (appropriately setting
`in_mask(1..3)` and `in_mask(5..7)` low for strings that are not multiples
of four in length), which means that you only need to look at `out_xmask(3)`
and `out_xmask(7)` because of this guarantee.

By default, vhdre is little endian; i.e., lower indexed bytes/slots are
matched first. As a little convenience thing for big endian systems, you can
swap the order by setting the `BIG_ENDIAN` generic to true. Of course this
means that you need to use reversed indices in the above example.

### Notes on backpressure and timing closure ###

The `in_ready` and `out_ready` signals in this unit are implemented in a very
trivial way: they are practically just passed through the entire unit
combinatorially. This can lead to timing problems in high-throughput systems.

There are a couple things you can do to work around this, ordered by effort
vs. improvement in timing:

 - Insert an 2-stage AXI4 stream slice directly after the output of this unit
   to break the critical path from your stream sink's ready signal to the
   matcher.

 - Insert an 2-stage AXI4 stream slice directly before the input of this unit
   to break the critical path from the regex matcher's ready signal to your
   data source.

 - Bypass vhdre's backpressure logic entirely by placing a FIFO after this
   unit's output and tying its almost-empty signal to the source stream's
   ready signal. This unit's `in_valid` signal must be tied to
   `valid and ready`, so it is strobed only when a transfer is acknowledged.
   The FIFO must be configured such that it releases its almost-empty signal
   when there are less than 6 free entries in the FIFO. This ensures that
   the FIFO can never become full, because vhdre's pipeline isn't deep
   enough to generate more data than that when it doesn't receive any input.
   This allows this unit to ignore the `ready` signal from the FIFO. NOTE:
   do NOT connect the FIFO `ready` signal to `out_ready`! Doing that
   would essentially make a false path through vhdre's silly backpressure
   system.


License
-------------------------------------------------------------------------------
vhdre-py follows the MIT license:

```
Copyright (c) 2017-2018 Jeroen van Straten, Delft University of Technology

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
