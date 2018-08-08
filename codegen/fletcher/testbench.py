# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""This package contains stuff for generating testbenches."""

import random
import collections
from functools import reduce
from .lines import *
from .streams import *

__all__ = ["Memory", "TestVectors", "Testbench"]


class Memory(object):
    """Represents a memory used for testing. The memory is filled using an
    auto-incremented pointer similar to how file objects work, except the
    pointer is bit-oriented."""

    def __init__(self):
        """Initializes an empty memory."""
        super().__init__()
        self.data = []
        self.ptr = 0
        self.ptrstack = []

    def push_ptr(self, new=None):
        """Push the current memory pointer to the stack."""
        self.ptrstack.append(self.ptr)
        if new is not None:
            self.ptr = new

    def pop_ptr(self):
        """Pop the previous memory pointer from the stack."""
        self.ptr = self.ptrstack.pop()

    def align(self, bits=8):
        """Aligns the current pointer to the given amount of bits."""
        while self.ptr % bits != 0:
            self.ptr += 1

    def byte_addr(self):
        """Returns the byte address of the current pointer."""
        if self.ptr % 8 != 0:
            raise ValueError("Cannot get byte address, pointer not aligned")
        return self.ptr // 8

    def write_bit(self, val):
        """Writes a bit to the memory."""
        if val != 0 and val != 1:
            raise ValueError()
        while len(self.data) < self.ptr:
            self.data.append(0)
        if len(self.data) == self.ptr:
            self.data.append(val)
        else:
            self.data[self.ptr] = val
        self.ptr += 1

    def read_bit(self):
        """Reads a bit from the memory."""
        self.ptr += 1
        if self.ptr <= len(self.data):
            return self.data[self.ptr - 1]
        return 0

    def write(self, val, bits=8):
        """Writes an integer to the memory."""
        for bit in range(bits):
            self.write_bit((val >> bit) & 1)

    def read(self, bits=8):
        """Reads an integer from the memory."""
        val = 0
        for bit in range(bits):
            val += self.read_bit() << bit
        return val

    def get_bytes(self):
        """Returns the contents of the memory as a bytes() object."""
        b = bytearray()
        self.push_ptr(0)
        for i in range((len(self.data)+7)//8):
            b.append(self.read())
        self.pop_ptr()
        return bytes(b)

    def hexdump(self):
        """Returns a hexdump of the memory."""
        bss = [[]]
        self.push_ptr(0)
        for b in self.get_bytes():
            bss[-1].append(b)
            if len(bss[-1]) == 16:
                bss.append([])
        self.pop_ptr()

        lines = []
        for a, bs in enumerate(bss):
            if not bs:
                continue
            s = ""
            i = 0
            for b in bs:
                s += "%02X " % b
                i += 1
                if i % 4 == 0:
                    s += " "
            s = "0x%08X | %-51s| " % (a * 16, s)
            for b in bs:
                if b < 32 or b > 127:
                    s += "."
                else:
                    s += "%c" % b
            lines.append(s)

        return "\n".join(lines)


class TestVectors(object):
    """Represents a set of test vectors for a stream signal."""

    def __init__(self, signal, condition="true"):
        super().__init__()
        self.signal = signal
        self.data = []
        self.condition = condition

    def append(self, data=None):
        self.data.append(data)

    def extend(self, data):
        self.data.extend(data)

    def __iter__(self):
        return iter(self.data)

    def __len__(self):
        return len(self.data)


class Testbench(object):
    """Class used to generate testbenches."""

    def __init__(self, name, clks=[""], timeout=10000000):
        """Constructs a testbench class object with the given name and
        clocks."""
        super().__init__()
        self.name = name
        self.clks = clks
        self.timeout = timeout
        self.consts = collections.OrderedDict()
        self.uuts = []
        self.streams = []
        self.memories = []
        self.tvs = []

    def set_const(self, const, value):
        self.consts[const] = value

    def append_uut(self, uut):
        """Appends a block of unit-under-test code."""
        self.uuts.append(uut)

    def _append_stream(self, stream, serialize, clk):
        for s, *_ in self.streams:
            if s is stream:
                raise ValueError("Stream is already present")
        self.streams.append((stream, serialize, clk))

    def append_input_stream(self, stream, clk=""):
        """Appends a stream to this testbench that must be serialized because
        it is consumed by a UUT."""
        self._append_stream(stream, True, clk)

    def append_output_stream(self, stream, clk=""):
        """Appends a stream to this testbench that must be deserialized because
        it is generated by a UUT."""
        self._append_stream(stream, False, clk)

    def append_memory(self, memory, req_stream, resp_stream, clk="",
                      random_request_timing=True, random_response_timing=True):
        """Appends a stream to this testbench that must be deserialized because
        it is generated by a UUT."""
        self.memories.append((memory, req_stream, resp_stream, clk,
                              random_request_timing, random_response_timing))

    def append_test_vector(self, tv):
        """Appends a set of test vectors to this testbench for the signal
        associated with the TestVectors object. This signal must be part of a
        stream previously added using append_*_stream()."""
        found_stream = None
        found_serialize = None
        found_clk = None

        def iter_substreams(streams):
            for stream, serialize, clk in streams:
                if isinstance(stream, StreamGroup):
                    for substream in iter_substreams([(s, serialize, clk) for s in stream.streams]):
                        yield substream
                else:
                    yield (stream, serialize, clk)

        for stream, serialize, clk in iter_substreams(self.streams):
            for signal in stream:
                if signal is tv.signal:
                    if found_stream is not None:
                        raise ValueError("Signal belongs to multiple streams")
                    found_stream = stream
                    found_serialize = serialize
                    found_clk = clk
        if found_stream is None:
            raise ValueError("Test vector does not belong to a known stream")
        for stream, _, _, tvs in self.tvs:
            if stream is found_stream:
                tvs.append(tv)
                return tv
        self.tvs.append((found_stream, found_serialize, found_clk, [tv]))
        return tv

    def __str__(self):
        blocks = []
        blocks.append(gen_template(self._HEADER, name=self.name))

        l = Lines()
        for name, value in self.consts.items():
            if isinstance(value, bool):
                init = "boolean := %s" % ("true" if value else "false")
            elif isinstance(value, int):
                init = "natural := %d" % value
            else:
                init = "string := %s" % (str(value).replace('"', '""'))
            l += Line("constant %s" % name, 32, ": %s;" % init)
        l += Line()
        for clk in self.clks:
            if clk and clk[-1] != "_":
                clk += "_"
            l += Line("signal %sclk" % clk, 32, ": std_logic := '1';")
            l += Line("signal %sreset" % clk, 32, ": std_logic := '1';")
            l += Line()
        for stream, *_ in self.streams:
            l += stream.def_signals()
            l += Line()
        for stream, produce, clk, tvs in self.tvs:
            for tv in tvs:
                l += Line("signal %s_remain" % tv.signal.name, 32, ": natural;")
        l.indent()
        blocks.append(str(l))

        blocks.append(gen_template(self._MIDDLE))

        for clk in self.clks:
            blocks.append(self._clk_gen(clk))

        l = Lines()
        for stream, serialize, *_ in self.streams:
            x = stream.arch_serdes(serialize)
            if x:
                l += x
                l += Line()
        l.indent()
        blocks.append(str(l))

        for stream, produce, clk, tvs in self.tvs:
            if clk and clk[-1] != "_":
                clk += "_"
            if produce:
                blocks.append(self._produce(stream, *tvs, clk=clk))
            else:
                blocks.append(self._consume(stream, *tvs, clk=clk))

        for args in self.memories:
            blocks.append(self._memory(*args))

        for uut in self.uuts:
            blocks.append(str(uut) + "\n")

        blocks.append(gen_template(self._FOOTER))

        return ''.join(blocks)

    def _strip(count, text):
        return '\n'.join(line[count:] for line in text.split('\n'))

    _HEADER = _strip(4, """
    -- Copyright (C) Delft University of Technology - All Rights Reserved
    -- (until further notice)

    library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

    library work;
    use work.Streams.all;
    use work.Columns.all;
    use work.Utils.all;

    entity {name} is
    end {name};

    architecture Behavioral of {name} is

      signal sim_complete           : std_logic;

    """)

    _MIDDLE = _strip(4, """\
    begin
    """)

    _FOOTER = _strip(4, """
    end Behavioral;
    """)

    _CLOCK_GEN = _strip(4, """
      {prefix}clk_proc: process is
        variable seed1              : positive := {seed};
        variable seed2              : positive := 1;
        variable rand               : real;
      begin
        {prefix}clk <= '1';
        wait for 5 ns;
        for i in 1 to {timeout} loop
          -- Simulate clock jitter on the rising edge of the clock. This
          -- desynchronizes the simulation clocks in designs with multiple, which
          -- ensures that the design does not assume that the different clocks are
          -- synchronized.
          uniform(seed1, seed2, rand);
          if rand > 0.5 then
            {prefix}clk <= '0';
            wait for 4.99 ns;
            {prefix}clk <= '1';
            wait for 5.01 ns;
          else
            {prefix}clk <= '0';
            wait for 5.01 ns;
            {prefix}clk <= '1';
            wait for 4.99 ns;
          end if;
          exit when sim_complete = '1';
        end loop;
        assert sim_complete = '1'
          report "Test not yet complete after {timeout} cycles"
          severity FAILURE;
        wait;
      end process;

      {prefix}reset_proc: process is
      begin
        {prefix}reset <= '1';
        wait for 100 ns;
        wait until rising_edge({prefix}clk);
        {prefix}reset <= '0';
        wait;
      end process;\n""")

    _PRODUCE_HEAD = _strip(4, """
      {prefix}block: block is
        signal {valid}_vect : std_logic;
        signal {valid}_prod : std_logic;
      begin

        {valid}_vect <= '1';
        {valid} <= {valid}_prod when {valid}_vect = '1' else '0';

        prod: StreamTbProd
          generic map (
            DATA_WIDTH              => 1,
            SEED                    => {seed}
          )
          port map (
            clk                     => {clk_prefix}clk,
            reset                   => {clk_prefix}reset,
            out_valid               => {valid}_prod,
            out_ready               => {ready}
          );
    """)

    _PRODUCE_SIGNAL = _strip(4, """
        {signal}_gen: process is
          type test_vector is array (1 to {vector_count}) of std_logic_vector({signal_width}-1 downto 0);
          function r(s: unsigned) return std_logic_vector is
          begin
            return std_logic_vector(resize(s, {signal_width}));
          end function r;
          constant vector : test_vector := (
            @vectors
          );
          variable data : std_logic_vector({signal_width}-1 downto 0);
        begin
          {valid}_vect <= '1';
          {signal}_remain <= 0;
          sim_complete <= '0';
          main: loop
            for i in 1 to {vector_count} loop
              {signal} <= vector(i){index};
              loop
                wait until rising_edge({clk_prefix}clk);
                exit main when to_X01({clk_prefix}reset) = '1';
                next when to_X01({valid}) = '0';
                next when to_X01({ready}) = '0';
                exit;
              end loop;
              {signal}_remain <= {vector_count} - i;
            end loop;
            {valid}_vect <= '0';
            sim_complete <= '1' after 10 us;
            loop
              wait until rising_edge({clk_prefix}clk);
              exit main when to_X01({clk_prefix}reset) = '1';
            end loop;
          end loop;
        end process;
    """)

    _PRODUCE_FOOT = _strip(4, """
      end block;
    """)

    _CONSUME_HEAD = _strip(4, """
      {prefix}cons: StreamTbCons
        generic map (
          DATA_WIDTH                => 1,
          SEED                      => {seed}
        )
        port map (
          clk                       => {clk_prefix}clk,
          reset                     => {clk_prefix}reset,
          in_valid                  => {valid},
          in_ready                  => {ready},
          in_data                   => "0"
        );
    """)

    _CONSUME_SIGNAL = _strip(4, """
      {signal}_check: process is
        type test_vector is array (1 to {vector_count}) of std_logic_vector({signal_width}-1 downto 0);
        function r(s: unsigned) return std_logic_vector is
        begin
          return std_logic_vector(resize(s, {signal_width}));
        end function r;
        constant vector : test_vector := (
          @vectors
        );
        variable data : std_logic_vector({signal_width}-1 downto 0);
      begin
        sim_complete <= '0';
        {signal}_remain <= 0;
        main: loop
          for i in 1 to {vector_count} loop
            loop
              loop
                wait until rising_edge({clk_prefix}clk);
                exit main when to_X01({clk_prefix}reset) = '1';
                exit when to_X01({valid}) = '1';
              end loop;
              data{index} := {signal};
              while to_X01({ready}) /= '1' loop
                wait until rising_edge({clk_prefix}clk);
                exit main when to_X01({clk_prefix}reset) = '1';
                assert {signal} = data{index}
                  report "Signal {signal} changed while valid high"
                  severity failure;
              end loop;
              exit when {check_condition};
            end loop;
            assert std_match(data, vector(i))
              report "Unexpected value for {signal} for transfer " & integer'image(i)
              severity failure;
            {signal}_remain <= {vector_count} - i;
          end loop;
          sim_complete <= '1' after 10 us;
          loop
            wait until rising_edge({clk_prefix}clk);
            exit main when to_X01({clk_prefix}reset) = '1';
            assert to_X01({valid}) = '0' or not ({check_condition})
              report "Received unexpected transfer on {signal}"
              severity failure;
          end loop;
        end loop;
      end process;
    """)

    _MEMORY = _strip(4, """
      {req_prefix}mem_block: block is

        signal {req_prefix}cons_valid : std_logic;
        signal {req_prefix}cons_ready : std_logic;

        signal {req_prefix}int_valid : std_logic;
        signal {req_prefix}int_ready : std_logic;

        signal {resp_prefix}prod_valid : std_logic;
        signal {resp_prefix}prod_ready : std_logic;

        signal {resp_prefix}int_valid : std_logic;
        signal {resp_prefix}int_ready : std_logic;

      begin

        random_request_timing_gen: if {random_request_timing} generate
        begin

          -- Request consumer and synchronizer. These two units randomize the rate at
          -- which requests are consumed.
          consumer_sync: StreamSync
            generic map (
              NUM_INPUTS                => 1,
              NUM_OUTPUTS               => 2
            )
            port map (
              clk                       => {clk_prefix}clk,
              reset                     => {clk_prefix}reset,
              in_valid(0)               => {req_prefix}valid,
              in_ready(0)               => {req_prefix}ready,
              out_valid(1)              => {req_prefix}cons_valid,
              out_valid(0)              => {req_prefix}int_valid,
              out_ready(1)              => {req_prefix}cons_ready,
              out_ready(0)              => {req_prefix}int_ready
            );

          consumer_inst: StreamTbCons
            generic map (
              SEED                      => {seed1}
            )
            port map (
              clk                       => {clk_prefix}clk,
              reset                     => {clk_prefix}reset,
              in_valid                  => {req_prefix}cons_valid,
              in_ready                  => {req_prefix}cons_ready,
              in_data                   => (others => '0')
            );

        end generate;

        fast_request_timing_gen: if not {random_request_timing} generate
        begin
          {req_prefix}int_valid <= {req_prefix}valid;
          {req_prefix}ready <= {req_prefix}int_ready;
        end generate;

        -- Request handler. First accepts and ready's a command, then outputs the a
        -- response burst as fast as possible.
        process is
          type rom_type is array (natural range <>) of std_logic_vector(511 downto 0);
          constant rom  : rom_type := (
            @rom
          );
          variable len  : natural;
          variable addr : unsigned(BUS_ADDR_WIDTH-1 downto 0);
          variable roma : natural;
          variable romi : natural;
        begin
          state: loop

            -- Reset state.
            {req_prefix}int_ready <= '0';
            {resp_prefix}int_valid <= '0';
            {resp_prefix}data <= (others => '0');
            {resp_prefix}last <= '0';

            -- Wait for request valid.
            loop
              wait until rising_edge({clk_prefix}clk);
              exit state when {clk_prefix}reset = '1';
              exit when {req_prefix}int_valid = '1';
            end loop;

            addr := unsigned({req_prefix}addr);
            len := to_integer(unsigned({req_prefix}len));

            -- Check that length is nonzero.
            assert len > 0
              report "ColumnReader requested burst length 0"
              severity FAILURE;

            -- Accept the request.
            {req_prefix}int_ready <= '1';
            wait until rising_edge({clk_prefix}clk);
            exit state when {clk_prefix}reset = '1';
            {req_prefix}int_ready <= '0';

            for i in 0 to len-1 loop

              -- Drive the response data signal.
              for i in 0 to (BUS_DATA_WIDTH / 8) - 1 loop
                if addr + i < {rom_size} then
                  roma := to_integer(addr + i);
                  romi := (roma mod 64) * 8;
                  roma := roma / 64;
                  {resp_prefix}data(i*8+7 downto i*8) <= rom(roma)(romi+7 downto romi);
                else
                  {resp_prefix}data(i*8+7 downto i*8) <= (others => 'U');
                end if;
              end loop;

              -- Drive the response control signals.
              {resp_prefix}int_valid <= '1';
              if i = len-1 then
                {resp_prefix}last <= '1';
              else
                {resp_prefix}last <= '0';
              end if;

              -- Wait for response ready.
              loop
                wait until rising_edge({clk_prefix}clk);
                exit state when {clk_prefix}reset = '1';
                exit when {resp_prefix}int_ready = '1';
              end loop;

              -- Increment address.
              addr := addr + (BUS_DATA_WIDTH / 8);

            end loop;

          end loop;
        end process;

        random_response_timing_gen: if {random_response_timing} generate
        begin

          -- Response producer and synchronizer. These two units randomize the rate at
          -- which burst beats are generated.
          producer_inst: StreamTbProd
            generic map (
              SEED                      => {seed2}
            )
            port map (
              clk                       => {clk_prefix}clk,
              reset                     => {clk_prefix}reset,
              out_valid                 => {resp_prefix}prod_valid,
              out_ready                 => {resp_prefix}prod_ready
            );

          producer_sync: StreamSync
            generic map (
              NUM_INPUTS                => 2,
              NUM_OUTPUTS               => 1
            )
            port map (
              clk                       => {clk_prefix}clk,
              reset                     => {clk_prefix}reset,
              in_valid(1)               => {resp_prefix}prod_valid,
              in_valid(0)               => {resp_prefix}int_valid,
              in_ready(1)               => {resp_prefix}prod_ready,
              in_ready(0)               => {resp_prefix}int_ready,
              out_valid(0)              => {resp_prefix}valid,
              out_ready(0)              => {resp_prefix}ready
            );

        end generate;

        fast_response_timing_gen: if not {random_response_timing} generate
        begin
          {resp_prefix}valid <= {resp_prefix}int_valid;
          {resp_prefix}int_ready <= {resp_prefix}ready;
        end generate;

      end block;
    """)

    def _clk_gen(self, clk=""):
        """Generates a producer for the given stream and test vectors."""
        clk_prefix = clk
        if clk_prefix and clk_prefix[-1] != "_":
            clk_prefix += "_"
        return gen_template(
            self._CLOCK_GEN,
            seed = random.randint(1, 2**31-1),
            timeout = self.timeout,
            prefix=clk_prefix)

    @classmethod
    def _prodcons(cls, template_head, template_signal, template_foot, undef, stream, *test_vectors, condition="true", clk=""):
        """Generates a producer or consumer for the given stream and test
        vectors using the given templates."""

        if isinstance(stream, StreamGroup):
            return "".join([cls._prodcons(
                template_head, template_signal, template_foot, undef, s, *test_vectors, clk=clk)
                for s in stream.streams])

        clk_prefix = clk
        if clk_prefix and clk_prefix[-1] != "_":
            clk_prefix += "_"

        # Generate the consumer instance.
        blocks = [gen_template(template_head,
            seed = random.randint(1, 2**31-1),
            clk_prefix = clk_prefix,
            prefix = stream.name,
            valid = stream.valid.name,
            ready = stream.ready.name
        )]

        # Generate the testers.
        for test_vector in test_vectors:
            vectors = Lines()
            for i, v in enumerate(test_vector):
                if v is None:
                    vectors.append("%d=>(others=>'%s')," % (i+1, undef))
                else:
                    vectors.append('%d=>r(X"%X"),' % (i+1, v))
                if len(str(vectors.lines[-1])) > 200:
                    vectors += Line()
            vectors.trimsep()

            blocks.append(gen_template(template_signal,
                signal = test_vector.signal.name,
                signal_width = test_vector.signal.width,
                vector_count = len(test_vector),
                clk_prefix = clk_prefix,
                ready = stream.ready.name,
                valid = stream.valid.name,
                index = "(0)" if test_vector.signal.typ is None else "",
                check_condition = test_vector.condition,
                vectors = vectors
            ))

        blocks.append(template_foot)

        return "".join(blocks)

    @classmethod
    def _produce(cls, stream, *test_vectors, clk=""):
        """Generates a producer for the given stream and test vectors."""
        return cls._prodcons(
            cls._PRODUCE_HEAD,
            cls._PRODUCE_SIGNAL,
            cls._PRODUCE_FOOT,
            "U",
            stream,
            *test_vectors,
            clk=clk)

    @classmethod
    def _consume(cls, stream, *test_vectors, clk=""):
        """Generates a consumer for the given stream and test vectors. A failure is
        reported if an unexpected transfer is received or if the data changes while
        valid is high."""
        return cls._prodcons(
            cls._CONSUME_HEAD,
            cls._CONSUME_SIGNAL,
            "",
            "-",
            stream,
            *test_vectors,
            clk=clk)

    @classmethod
    def _memory(cls, memory, req_stream, resp_stream, clk="", random_request_timing=True, random_response_timing=True):
        """Generates a memory model."""
        clk_prefix = clk
        if clk_prefix and clk_prefix[-1] != "_":
            clk_prefix += "_"

        if not isinstance(random_request_timing, str):
            random_request_timing = "true" if random_request_timing else "false"

        if not isinstance(random_response_timing, str):
            random_response_timing = "true" if random_response_timing else "false"

        bs = memory.get_bytes()
        rom_size = len(bs)
        ws = [[]]
        for b in bs:
            ws[-1].append(b)
            if len(ws[-1]) == 64:
                ws.append([])
        ws[-1].extend([0] * (64-len(ws[-1])))
        ws = [reduce(lambda x, y: (x << 8) | y, reversed(w)) for w in ws]

        rom = Lines()
        for i, w in enumerate(ws):
            rom.append('%d=>X"%0128X",' % (i, w))
            if len(str(rom.lines[-1])) > 200:
                rom += Line()
        rom.trimsep()

        return gen_template(cls._MEMORY,
            seed1 = random.randint(1, 2**31-1),
            seed2 = random.randint(1, 2**31-1),
            clk_prefix = clk_prefix,
            req_prefix = req_stream.name,
            resp_prefix = resp_stream.name,
            random_request_timing = random_request_timing,
            random_response_timing = random_response_timing,
            rom = rom,
            rom_size = rom_size
        )
