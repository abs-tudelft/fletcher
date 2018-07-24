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

"""This package contains a python object representation for ColumnReaders, and
the functions needed to generate a ColumnReader from an Arrow field
(represented as the objects in fields.py)."""

from itertools import zip_longest
import random

from .configurable import *
from .fields import *
from .streams import *
from .lines import *
from .testbench import *

__all__ = ["ColumnReader", "BUS_ADDR_WIDTH", "INDEX_WIDTH", "CMD_TAG_WIDTH"]

# Define the generics used by ColumnReaders.
BUS_ADDR_WIDTH = Generic("BUS_ADDR_WIDTH")
BUS_LEN_WIDTH  = Generic("BUS_LEN_WIDTH")
BUS_DATA_WIDTH = Generic("BUS_DATA_WIDTH")
INDEX_WIDTH    = Generic("INDEX_WIDTH")
CMD_TAG_WIDTH  = Generic("CMD_TAG_WIDTH")


class ReaderLevel(Configurable):
    """Represents an abstract ColumnReaderLevel(Level)."""

    def __init__(self, **config):
        super().__init__(**config)

    @property
    def _cmdname(self):
        """Returns the cfg string command name for this ReaderLevel."""
        return "?"

    @property
    def _children(self):
        """Returns a list of child ReaderLevels or parameters."""
        return []

    def bus_count(self):
        """Returns the number of busses used by this ReaderLevel."""
        raise NotImplemented()

    @classmethod
    def _write_buffer(cls, memory, bits, data):
        """Writes an arrow buffer to the given Memory given a list of integers
        and bit width."""
        memory.align(max(8*64, bits))
        addr = memory.byte_addr()
        for entry in data:
            memory.write(entry, bits)
        return addr

    def test_vectors(self, memory, row_count, commands):
        """Returns a set of test vectors for all the signals defined by this
        ReaderLevel (both command and response), given a row count and a list
        of commands (represented as a list of two-tuples, where the first entry
        is the inclusive start index and the second is the exclusive stop
        index). The Memory object that should be passed to memory is updated
        accordingly, with new data sets generated at the current memory
        pointer."""
        raise NotImplemented()

    def __str__(self):
        """Returns the cfg string for this ReaderLevel."""
        children = ",".join(map(str, self._children))
        attrs = ",".join(map(lambda x: "%s=%s" % x, self._config.items()))

        attrs = []
        for key, value in self._config.items():
            if isinstance(value, int) or isinstance(value, bool):
                value = str(int(value))
            attrs.append("%s=%s" % (key, value))
        attrs = ",".join(attrs)
        if attrs:
            attrs = ";" + attrs
        return "%s(%s%s)" % (self._cmdname, children, attrs)


class PrimReaderLevel(ReaderLevel):
    """A reader for a primitive data type."""

    def __init__(
        self,
        bit_width,
        cmd_stream,
        cmd_val_base,
        out_stream,
        out_val,
        **kwargs
    ):
        super().__init__(**kwargs)

        # Check and save the bit width.
        if not bit_width or bit_width & (bit_width-1):
            raise ValueError("bit width must be a power of two")
        self.bit_width = bit_width

        self.cmd_stream = cmd_stream
        self.cmd_val_base = cmd_val_base
        self.out_stream = out_stream
        self.out_val = out_val

    @property
    def _cmdname(self):
        """Returns the cfg string command name for this ReaderLevel."""
        return "prim"

    @property
    def _children(self):
        """Returns a list of child ReaderLevels or parameters."""
        return [self.bit_width]

    @property
    def _config_defaults(self):
        return { # NOTE: the defaults here MUST correspond to VHDL defaults.
            "cmd_in_slice":             False,
            "bus_req_slice":            True,
            "bus_fifo_depth":           16,
            "bus_fifo_ram_config":      "",
            "unlock_slice":             True,
            "shr2gb_slice":             False,
            "gb2fifo_slice":            False,
            "fifo_size":                64,
            "fifo_ram_config":          "",
            "fifo_xclk_stages":         0,
            "fifo2post_slice":          False,
            "out_slice":                True
        }

    def bus_count(self):
        """Returns the number of busses used by this ReaderLevel."""
        return 2

    def test_vectors(self, memory, row_count, commands):
        """Returns a set of test vectors for all the signals defined by this
        ReaderLevel (both command and response), given a row count and a list
        of commands (represented as a list of two-tuples, where the first entry
        is the inclusive start index and the second is the exclusive stop
        index). The Memory object that should be passed to memory is updated
        accordingly, with new data sets generated at the current memory
        pointer."""

        # Generate memory for 4 buffers of the given row count. We randomly
        # select which buffer to use for each command.
        buffers = []
        for _ in range(4):
            data = [random.randrange(1 << self.bit_width) for _ in range(row_count)]
            addr = self._write_buffer(memory, self.bit_width, data)
            buffers.append((addr, data))

        # Generate test vectors for our signals.
        base_tv = TestVectors(self.cmd_val_base)
        val_tv = TestVectors(self.out_val, self.out_stream.name + "dvalid = '1'")
        for start, stop in commands:
            buf_idx = random.randrange(4)
            addr, data = buffers[buf_idx]
            base_tv.append(addr)
            val_tv.extend(data[start:stop])

        return [base_tv, val_tv]


class ArbReaderLevel(ReaderLevel):
    """A wrapper for readers that instantiates a bus arbiter and optionally
    slices for all the other streams."""

    def __init__(self, child, **kwargs):
        super().__init__(**kwargs)
        self.child = child

    @property
    def _cmdname(self):
        """Returns the cfg string command name for this ReaderLevel."""
        return "arb"

    @property
    def _children(self):
        """Returns a list of child ReaderLevels or parameters."""
        return [self.child]

    @property
    def _config_defaults(self):
        return { # NOTE: the defaults here MUST correspond to VHDL defaults.
            "method":                   "ROUND-ROBIN",
            "max_outstanding":          2,
            "ram_config":               "",
            "req_in_slices":            False,
            "req_out_slice":            True,
            "resp_in_slice":            False,
            "resp_out_slices":          True,
            "cmd_stream_slice":         True,
            "unlock_stream_slice":      True,
            "out_stream_slice":         True
        }

    def bus_count(self):
        """Returns the number of busses used by this ReaderLevel."""
        return 1

    def test_vectors(self, memory, row_count, commands):
        """Returns a set of test vectors for all the signals defined by this
        ReaderLevel (both command and response), given a row count and a list
        of commands (represented as a list of two-tuples, where the first entry
        is the inclusive start index and the second is the exclusive stop
        index). The Memory object that should be passed to memory is updated
        accordingly, with new data sets generated at the current memory
        pointer."""
        return self.child.test_vectors(memory, row_count, commands)


class NullReaderLevel(ReaderLevel):
    """A reader for a null bitmap."""

    def __init__(
        self,
        child,
        cmd_stream,
        cmd_no_nulls,
        cmd_null_base,
        out_stream,
        out_not_null,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.child = child
        self.cmd_stream = cmd_stream
        self.cmd_no_nulls = cmd_no_nulls
        self.cmd_null_base = cmd_null_base
        self.out_stream = out_stream
        self.out_not_null = out_not_null

    @property
    def _cmdname(self):
        """Returns the cfg string command name for this ReaderLevel."""
        return "null"

    @property
    def _children(self):
        """Returns a list of child ReaderLevels or parameters."""
        return [self.child]

    @property
    def _config_defaults(self):
        return { # NOTE: the defaults here MUST correspond to VHDL defaults.
            "cmd_in_slice":             False,
            "bus_req_slice":            True,
            "bus_fifo_depth":           16,
            "bus_fifo_ram_config":      "",
            "unlock_slice":             True,
            "shr2gb_slice":             False,
            "gb2fifo_slice":            False,
            "fifo_size":                64,
            "fifo_ram_config":          "",
            "fifo_xclk_stages":         0,
            "fifo2post_slice":          False,
            "out_slice":                True
        }

    def bus_count(self):
        """Returns the number of busses used by this ReaderLevel."""
        return self.child.bus_count() + 1

    def test_vectors(self, memory, row_count, commands):
        """Returns a set of test vectors for all the signals defined by this
        ReaderLevel (both command and response), given a row count and a list
        of commands (represented as a list of two-tuples, where the first entry
        is the inclusive start index and the second is the exclusive stop
        index). The Memory object that should be passed to memory is updated
        accordingly, with new data sets generated at the current memory
        pointer."""

        # Generate memory for 3 buffers of the given row count. We randomly
        # select between one of the buffers and an implicit null bitmap for
        # each command.
        buffers = []
        for _ in range(3):
            data = [min(1, random.randrange(10)) for _ in range(row_count)]
            addr = self._write_buffer(memory, 1, data)
            buffers.append((addr, data))

        # Generate test vectors for our signals.
        impl_tv = TestVectors(self.cmd_no_nulls)
        base_tv = TestVectors(self.cmd_null_base)
        val_tv = TestVectors(self.out_not_null, self.out_stream.name + "dvalid = '1'")
        for start, stop in commands:
            buf_idx = random.randrange(4)
            if buf_idx < 3:
                addr, data = buffers[buf_idx]
                impl_tv.append(0)
                base_tv.append(addr)
                val_tv.extend(data[start:stop])
            else:
                impl_tv.append(1)
                base_tv.append(None)
                val_tv.extend([1 for _ in range(start, stop)])

        return [impl_tv, base_tv, val_tv] + self.child.test_vectors(memory, row_count, commands)


def _list_test_vectors(reader, memory, row_count, commands):
    """Test vector generation function shared by ListReaderLevel and
    ListPrimReaderLevel."""

    # Generate on average 4 items per list.
    child_length = row_count * 4
    child_commands = []
    child_idxs = []

    # Generate memory for 4 buffers of the given row count. We randomly
    # select one of the buffers for each command.
    buffers = []
    for _ in range(4):
        data = [random.randint(0, child_length) for _ in range(row_count-1)]
        data = [0] + sorted(data) + [child_length]
        addr = reader._write_buffer(memory, 32, data) # FIXME: this width is actually a generic!
        buffers.append((addr, data))

    # Generate test vectors for our signals and figure out the command
    # stream for the child.
    base_tv = TestVectors(reader.cmd_idx_base)
    len_tv  = TestVectors(reader.out_length, reader.out_stream.name + "dvalid = '1'")
    for start, stop in commands:
        buf_idx = random.randrange(4)
        addr, data = buffers[buf_idx]
        child_commands.append((data[start], data[stop]))
        child_idxs.append(list(zip(data[start:stop], data[start+1:stop+1])))
        base_tv.append(addr)
        len_tv.extend([data[i+1] - data[i] for i in range(start, stop)])

    return child_length, child_commands, child_idxs, [base_tv, len_tv]


class ListReaderLevel(ReaderLevel):
    """A reader for a list index buffer."""

    def __init__(
        self,
        child,
        cmd_stream,
        cmd_idx_base,
        out_stream,
        out_length,
        out_el_stream,
        **kwargs
    ):
        super().__init__(**kwargs)
        self.child = child
        self.cmd_stream = cmd_stream
        self.cmd_idx_base = cmd_idx_base
        self.out_stream = out_stream
        self.out_length = out_length
        self.out_el_stream = out_el_stream

    @property
    def _cmdname(self):
        """Returns the cfg string command name for this ReaderLevel."""
        return "list"

    @property
    def _children(self):
        """Returns a list of child ReaderLevels or parameters."""
        return [self.child]

    @property
    def _config_defaults(self):
        return { # NOTE: the defaults here MUST correspond to VHDL defaults.
            "cmd_in_slice":         False,
            "bus_req_slice":        True,
            "bus_fifo_depth":       16,
            "bus_fifo_ram_config":  "",
            "cmd_out_slice":        True,
            "unlock_slice":         True,
            "shr2gb_slice":         False,
            "gb2fifo_slice":        False,
            "fifo_size":            64,
            "fifo_ram_config":      "",
            "fifo_xclk_stages":     0,
            "fifo2post_slice":      False,
            "len_out_slice":        True,
            "len_sync_slice":       True,
            "data_in_slice":        False,
            "data_out_slice":       True
        }

    def bus_count(self):
        """Returns the number of busses used by this ReaderLevel."""
        return self.child.bus_count() + 1

    def test_vectors(self, memory, row_count, commands):
        """Returns a set of test vectors for all the signals defined by this
        ReaderLevel (both command and response), given a row count and a list
        of commands (represented as a list of two-tuples, where the first entry
        is the inclusive start index and the second is the exclusive stop
        index). The Memory object that should be passed to memory is updated
        accordingly, with new data sets generated at the current memory
        pointer."""

        # Figure out the test vectors for the list.
        child_length, child_commands, child_idxs, tvs = _list_test_vectors(
            self, memory, row_count, commands)

        # Figure out the test vectors for the child.
        tvs.extend(self.child.test_vectors(memory, child_length, child_commands))

        # Figure out the last/dvalid signals for the element stream.
        last_tv   = TestVectors(self.out_el_stream.signals[0])
        dvalid_tv = TestVectors(self.out_el_stream.signals[1])
        for idxs in child_idxs:
            for start, stop in idxs:
                l = stop - start
                if not l:
                    last_tv.append(1)
                    dvalid_tv.append(0)
                else:
                    for i in range(l):
                        last_tv.append(int(i == l - 1))
                        dvalid_tv.append(1)

        return tvs + [last_tv, dvalid_tv]


class ListPrimReaderLevel(ReaderLevel):
    """A reader for a list of non-nullable primitive data types."""

    def __init__(
        self,
        bit_width,
        cmd_stream,
        cmd_idx_base,
        cmd_val_base,
        out_stream,
        out_length,
        out_el_stream,
        out_el_values,
        out_el_count,
        **kwargs
    ):
        super().__init__(**kwargs)

        # Check and save the bit width.
        if not bit_width or bit_width & (bit_width-1):
            raise ValueError("bit width must be a power of two")
        self.bit_width = bit_width

        self.cmd_stream = cmd_stream
        self.cmd_idx_base = cmd_idx_base
        self.cmd_val_base = cmd_val_base
        self.out_stream = out_stream
        self.out_length = out_length
        self.out_el_stream = out_el_stream
        self.out_el_values = out_el_values
        self.out_el_count = out_el_count

    @property
    def _cmdname(self):
        """Returns the cfg string command name for this ReaderLevel."""
        return "listprim"

    @property
    def _children(self):
        """Returns a list of child ReaderLevels or parameters."""
        return [self.bit_width]

    @property
    def _config_defaults(self):
        return { # NOTE: the defaults here MUST correspond to VHDL defaults.
            "epc":                      1,
            "idx_cmd_in_slice":         False,
            "idx_bus_req_slice":        True,
            "idx_bus_fifo_depth":       16,
            "idx_bus_fifo_ram_config":  "",
            "idx_cmd_out_slice":        True,
            "idx_unlock_slice":         True,
            "idx_shr2gb_slice":         False,
            "idx_gb2fifo_slice":        False,
            "idx_fifo_size":            64,
            "idx_fifo_ram_config":      "",
            "idx_fifo_xclk_stages":     0,
            "idx_fifo2post_slice":      False,
            "cmd_in_slice":             False,
            "bus_req_slice":            True,
            "bus_fifo_depth":           16,
            "bus_fifo_ram_config":      "",
            "unlock_slice":             True,
            "shr2gb_slice":             False,
            "gb2fifo_slice":            False,
            "fifo_size":                64,
            "fifo_ram_config":          "",
            "fifo_xclk_stages":         0,
            "fifo2post_slice":          False,
            "out_slice":                False,
            "len_out_slice":            True,
            "data_in_slice":            False,
            "len_sync_slice":           True,
            "data_out_slice":           True
        }

    def bus_count(self):
        """Returns the number of busses used by this ReaderLevel."""
        return 2

    def test_vectors(self, memory, row_count, commands):
        """Returns a set of test vectors for all the signals defined by this
        ReaderLevel (both command and response), given a row count and a list
        of commands (represented as a list of two-tuples, where the first entry
        is the inclusive start index and the second is the exclusive stop
        index). The Memory object that should be passed to memory is updated
        accordingly, with new data sets generated at the current memory
        pointer."""

        # Figure out the test vectors for the list.
        child_length, child_commands, child_idxs, tvs = _list_test_vectors(
            self, memory, row_count, commands)

        # Generate memory for 4 buffers of the given child length. We randomly
        # select which buffer to use for each command.
        buffers = []
        for _ in range(4):
            data = [random.randrange(1 << self.bit_width) for _ in range(child_length)]
            addr = self._write_buffer(memory, self.bit_width, data)
            buffers.append((addr, data))

        # Generate test vectors for our signals.
        base_tv   = TestVectors(self.cmd_val_base)
        val_tvs   = [TestVectors(sig) for sig in self.out_el_values]
        cnt_tv    = TestVectors(self.out_el_count)
        last_tv   = TestVectors(self.out_el_stream.signals[0])
        dvalid_tv = TestVectors(self.out_el_stream.signals[1])
        for idxs in child_idxs:
            buf_idx = random.randrange(4)
            addr, cmd_data = buffers[buf_idx]
            base_tv.append(addr)
            for start, stop in idxs:
                data = cmd_data[start:stop]
                while True:
                    cnt = 0
                    for val_tv in val_tvs:
                        if data:
                            val_tv.append(data.pop(0))
                            cnt += 1
                        else:
                            val_tv.append()
                    cnt_tv.append(cnt)
                    dvalid_tv.append(1 if cnt > 0 else 0)
                    if not data:
                        last_tv.append(1)
                        break
                    else:
                        last_tv.append(0)

        return tvs + val_tvs + [base_tv, cnt_tv, last_tv, dvalid_tv]


class StructReaderLevel(ReaderLevel):
    """A reader for a struct of TWO child readers."""

    def __init__(self, a, b, **kwargs):
        super().__init__(**kwargs)
        self.a = a
        self.b = b

    @property
    def _cmdname(self):
        """Returns the cfg string command name for this ReaderLevel."""
        return "struct"

    @property
    def _children(self):
        """Returns a list of child ReaderLevels or parameters."""
        return [self.a, self.b]

    @property
    def _config_defaults(self):
        return { # NOTE: the defaults here MUST correspond to VHDL defaults.
        }

    def bus_count(self):
        """Returns the number of busses used by this ReaderLevel."""
        return self.a.bus_count() + self.b.bus_count()

    def test_vectors(self, memory, row_count, commands):
        """Returns a set of test vectors for all the signals defined by this
        ReaderLevel (both command and response), given a row count and a list
        of commands (represented as a list of two-tuples, where the first entry
        is the inclusive start index and the second is the exclusive stop
        index). The Memory object that should be passed to memory is updated
        accordingly, with new data sets generated at the current memory
        pointer."""
        return (
            self.a.test_vectors(memory, row_count, commands)
          + self.b.test_vectors(memory, row_count, commands)
        )


def _new_cmd_stream(prefix, field_prefix=""):
    """Constructs a command stream. Returns the stream and the ctrl
    SignalGroup."""
    p = prefix + "cmd_" + field_prefix
    s = Stream(p)
    s.append(Signal(p + "firstIdx", INDEX_WIDTH))
    s.append(Signal(p + "lastIdx", INDEX_WIDTH))
    ctrl = s.append(SignalGroup(p + "ctrl"))
    s.append(Signal(p + "tag", CMD_TAG_WIDTH))
    return s, ctrl


def _new_out_stream(prefix, field_prefix=""):
    """Constructs an output stream. Returns the stream and the data
    SignalGroup."""
    p = prefix + "out_" + field_prefix
    s = Stream(p)
    s.append(Signal(p + "last"))
    s.append(Signal(p + "dvalid"))
    data = s.append(SignalGroup(p + "data"))
    return s, data


def _maybe_wrap_in_arbiter(reader, **opts):
    """Wraps the given reader in a ArbReaderLevel if deemed necessary."""
    # TODO: make this stuff customizable using **opts.
    if reader.bus_count() > 3:
        reader = ArbReaderLevel(reader)
    return reader


def _scalar_reader(field, prefix, field_prefix, cmd_stream, cmd_ctrl, out_stream, out_data, **opts):
    """Internal function which converts a scalar field into a ReaderLevel."""

    # Add the signals to the streams.
    cmd_val_base = cmd_ctrl.append(Signal(prefix + "cmd_" + field_prefix + "valBase", BUS_ADDR_WIDTH))
    out_val      = out_data.append(Signal(prefix + "out_" + field_prefix + "val", field.bit_width))

    # Construct the primitive reader.
    reader = PrimReaderLevel(
        field.bit_width,
        cmd_stream,
        cmd_val_base,
        out_stream,
        out_val,
        **field.get_cfg_dict({
            "cmd_in_slice":        "cmd_in_slice",
            "bus_req_slice":       "bus_req_slice",
            "bus_fifo_depth":      "bus_fifo_depth",
            "bus_fifo_ram_config": "bus_fifo_ram_config",
            "unlock_slice":        "unlock_slice",
            "shr2gb_slice":        "shr2gb_slice",
            "gb2fifo_slice":       "gb2fifo_slice",
            "fifo_size":           "fifo_size",
            "fifo_ram_config":     "fifo_ram_config",
            "fifo_xclk_stages":    "fifo_xclk_stages",
            "fifo2post_slice":     "fifo2post_slice",
            "out_slice":           "out_slice"
        })
    )

    return reader, []


def _bytes_reader(field, prefix, field_prefix, cmd_stream, cmd_ctrl, out_stream, out_data, **opts):
    """Internal function which converts a UTF8/bytes field into a ReaderLevel."""

    # Add the signals to the existing streams.
    cmd_idx_base = cmd_ctrl.append(Signal(prefix + "cmd_" + field_prefix + "idxBase", BUS_ADDR_WIDTH))
    cmd_val_base = cmd_ctrl.append(Signal(prefix + "cmd_" + field_prefix + "valBase", BUS_ADDR_WIDTH))
    out_length   = out_data.append(Signal(prefix + "out_" + field_prefix + "len", INDEX_WIDTH))

    # Create a secondary output stream for the list elements.
    out_el_stream, out_el_data = _new_out_stream(prefix, field_prefix + "el_")

    # Populate the secondary output stream.
    epc = field.bytes_per_cycle
    out_el_count = out_el_data.append(Signal(prefix + "out_" + field_prefix + "el_cnt", int.bit_length(epc)))
    out_el_values = [
        Signal(prefix + "out_" + field_prefix + "el_val" + str(i), field.bit_width)
        for i in range(epc)
    ]
    # The elements are serialized MSB first!
    for sig in reversed(out_el_values):
        out_el_data.append(sig)

    # Construct the primitive reader.
    reader = ListPrimReaderLevel(
        field.bit_width,
        cmd_stream,
        cmd_idx_base,
        cmd_val_base,
        out_stream,
        out_length,
        out_el_stream,
        out_el_values,
        out_el_count,
        **field.get_cfg_dict({
            "bytes_per_cycle":          "epc",
            "idx_cmd_in_slice":         "idx_cmd_in_slice",
            "idx_bus_req_slice":        "idx_bus_req_slice",
            "idx_bus_fifo_depth":       "idx_bus_fifo_depth",
            "idx_bus_fifo_ram_config":  "idx_bus_fifo_ram_config",
            "idx_cmd_out_slice":        "idx_cmd_out_slice",
            "idx_unlock_slice":         "idx_unlock_slice",
            "idx_shr2gb_slice":         "idx_shr2gb_slice",
            "idx_gb2fifo_slice":        "idx_gb2fifo_slice",
            "idx_fifo_size":            "idx_fifo_size",
            "idx_fifo_ram_config":      "idx_fifo_ram_config",
            "idx_fifo_xclk_stages":     "idx_fifo_xclk_stages",
            "idx_fifo2post_slice":      "idx_fifo2post_slice",
            "cmd_in_slice":             "cmd_in_slice",
            "bus_req_slice":            "bus_req_slice",
            "bus_fifo_depth":           "bus_fifo_depth",
            "bus_fifo_ram_config":      "bus_fifo_ram_config",
            "unlock_slice":             "unlock_slice",
            "shr2gb_slice":             "shr2gb_slice",
            "gb2fifo_slice":            "gb2fifo_slice",
            "fifo_size":                "fifo_size",
            "fifo_ram_config":          "fifo_ram_config",
            "fifo_xclk_stages":         "fifo_xclk_stages",
            "fifo2post_slice":          "fifo2post_slice",
            "out_slice":                "out_slice",
            "len_out_slice":            "len_out_slice",
            "data_in_slice":            "data_in_slice",
            "len_sync_slice":           "len_sync_slice",
            "data_out_slice":           "data_out_slice"
        })
    )

    return reader, [out_el_stream]


def _list_reader(field, prefix, field_prefix, cmd_stream, cmd_ctrl, out_stream, out_data, **opts):
    """Internal function which converts a list field into a ReaderLevel."""

    # Add the signals to the existing streams.
    cmd_idx_base = cmd_ctrl.append(Signal(prefix + "cmd_" + field_prefix + "idxBase", BUS_ADDR_WIDTH))
    out_length   = out_data.append(Signal(prefix + "out_" + field_prefix + "len", INDEX_WIDTH))

    # Create a secondary output stream for the list elements.
    out_el_stream, out_el_data = _new_out_stream(prefix, field_prefix + field.child.name + "_")

    # Populate the secondary output stream with the child reader.
    reader, secondary_out_streams = _field_reader(
        field.child,
        prefix, field_prefix,
        cmd_stream, cmd_ctrl,
        out_el_stream, out_el_data,
        **opts)

    # Construct the primitive reader.
    reader = ListReaderLevel(
        reader,
        cmd_stream,
        cmd_idx_base,
        out_stream,
        out_length,
        out_el_stream,
        **field.get_cfg_dict({
            "cmd_in_slice":         "cmd_in_slice",
            "bus_req_slice":        "bus_req_slice",
            "bus_fifo_depth":       "bus_fifo_depth",
            "bus_fifo_ram_config":  "bus_fifo_ram_config",
            "cmd_out_slice":        "cmd_out_slice",
            "unlock_slice":         "unlock_slice",
            "shr2gb_slice":         "shr2gb_slice",
            "gb2fifo_slice":        "gb2fifo_slice",
            "fifo_size":            "fifo_size",
            "fifo_ram_config":      "fifo_ram_config",
            "fifo_xclk_stages":     "fifo_xclk_stages",
            "fifo2post_slice":      "fifo2post_slice",
            "len_out_slice":        "len_out_slice",
            "len_sync_slice":       "len_sync_slice",
            "data_in_slice":        "data_in_slice",
            "data_out_slice":       "data_out_slice"
        })
    )

    return reader, [out_el_stream] + secondary_out_streams


def _struct_reader(field, prefix, field_prefix, cmd_stream, cmd_ctrl, out_stream, out_data, **opts):
    """Internal function which converts a struct field into a ReaderLevel."""

    # Construct the child Reader objects.
    child_readers = []
    secondary_out_streams = []
    for child in field.iter_children():
        child_reader, child_secondary_out_stream = _field_reader(
            child,
            prefix, field_prefix,
            cmd_stream, cmd_ctrl,
            out_stream, out_data,
            **opts)
        child_readers.append(child_reader)
        secondary_out_streams.extend(child_secondary_out_stream)

    # Create a binary tree of readers.
    while True:

        # Stop if there's only one reader left.
        if len(child_readers) == 1:
            reader = child_readers[0]
            break

        # Add a level of structs.
        it = iter(child_readers)
        child_readers = []
        for a, b in zip_longest(*[it]*2, fillvalue=None):
            if b is None:
                # Odd amount of child readers at this level of the binary tree;
                # add the last reader without an additional struct level.
                child_readers.append(a)
            else:
                struct = StructReaderLevel(a, b)
                struct = _maybe_wrap_in_arbiter(struct, **opts)
                child_readers.append(struct)

    return reader, secondary_out_streams


def _field_reader(field, prefix, field_prefix, cmd_stream, cmd_ctrl, out_stream, out_data, **opts):
    """Internal function which converts a field into a ReaderLevel. This is
    appropriately called by the initializer of Reader()."""
    if not isinstance(field, Field):
        raise TypeError("field must be of type %s" % Field)
    if field.is_null():
        raise ValueError("cannot make a reader for a null field")

    # Update the field prefix.
    if field_prefix is None:
        field_prefix = ""
    else:
        field_prefix += field.name + "_"

    # Add the signals for the null reader if this field is nullable. This must
    # be done before going down the hierarchy.
    if field.nullable:
        cmd_no_nulls  = cmd_ctrl.append(Signal(prefix + "cmd_" + field_prefix + "noNulls"))
        cmd_null_base = cmd_ctrl.append(Signal(prefix + "cmd_" + field_prefix + "nullBase", BUS_ADDR_WIDTH))
        out_not_null  = out_data.append(Signal(prefix + "out_" + field_prefix + "notNull"))

    # Defer to the field-specific generators.
    for typ, gen in [
        (ScalarField, _scalar_reader),
        (BytesField,  _bytes_reader),
        (ListField,   _list_reader),
        (StructField, _struct_reader)
    ]:
        if isinstance(field, typ):
            reader, secondary_out_streams = gen(
                field,
                prefix, field_prefix,
                cmd_stream, cmd_ctrl,
                out_stream, out_data,
                **opts)
            break
    else:
        raise NotImplemented("No code generator is implemented for Field type %s" % type(field))

    # Generate the null() level if this field is nullable.
    if field.nullable:
        reader = NullReaderLevel(
            reader,
            cmd_stream,
            cmd_no_nulls,
            cmd_null_base,
            out_stream,
            out_not_null,
            **field.get_cfg_dict({
                "null_cmd_in_slice":        "cmd_in_slice",
                "null_bus_req_slice":       "bus_req_slice",
                "null_bus_fifo_depth":      "bus_fifo_depth",
                "null_bus_fifo_ram_config": "bus_fifo_ram_config",
                "null_unlock_slice":        "unlock_slice",
                "null_shr2gb_slice":        "shr2gb_slice",
                "null_gb2fifo_slice":       "gb2fifo_slice",
                "null_fifo_size":           "fifo_size",
                "null_fifo_ram_config":     "fifo_ram_config",
                "null_fifo_xclk_stages":    "fifo_xclk_stages",
                "null_fifo2post_slice":     "fifo2post_slice",
                "null_out_slice":           "out_slice"
            })
        )

    # Wrap the field in an arbiter based on the arbiter policy.
    reader = _maybe_wrap_in_arbiter(reader, **opts)

    return reader, secondary_out_streams


wrapper_body_template = """
-- Copyright (C) Delft University of Technology - All Rights Reserved
-- (until further notice)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.Streams.all;
use work.Utils.all;
use work.ColumnConfig.all;
use work.ColumnConfigParse.all;
use work.Columns.all;

entity {camelprefix}ColumnReader is
  generic (

    ---------------------------------------------------------------------------
    -- Bus metrics and configuration
    ---------------------------------------------------------------------------
    -- Bus address width.
    BUS_ADDR_WIDTH              : natural := 32;

    -- Bus burst length width.
    BUS_LEN_WIDTH               : natural := 8;

    -- Bus data width.
    BUS_DATA_WIDTH              : natural := 32;

    -- Number of beats in a burst step.
    BUS_BURST_STEP_LEN          : natural := 4;

    -- Maximum number of beats in a burst.
    BUS_BURST_MAX_LEN           : natural := 16;

    ---------------------------------------------------------------------------
    -- Arrow metrics and configuration
    ---------------------------------------------------------------------------
    -- Index field width.
    INDEX_WIDTH                 : natural := 32;

    ---------------------------------------------------------------------------
    -- Column metrics and configuration
    ---------------------------------------------------------------------------
    -- Enables or disables command stream tag system. When enabled, an
    -- additional output stream is created that returns tags supplied along
    -- with the command stream when all BufferReaders finish making bus
    -- requests for the command. This can be used to support chunking later.
    CMD_TAG_ENABLE              : boolean := false;

    -- Command stream tag width. Must be at least 1 to avoid null vectors.
    CMD_TAG_WIDTH               : natural := 1

  );
  port (

    ---------------------------------------------------------------------------
    -- Clock domains
    ---------------------------------------------------------------------------
    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- bus and control logic side of the BufferReader.
    bus_clk                     : in  std_logic;
    bus_reset                   : in  std_logic;

    -- Rising-edge sensitive clock and active-high synchronous reset for the
    -- accelerator side.
    acc_clk                     : in  std_logic;
    acc_reset                   : in  std_logic;

    ---------------------------------------------------------------------------
    -- Command streams
    ---------------------------------------------------------------------------
    -- Command stream input (bus clock domain). firstIdx and lastIdx represent
    -- a range of elements to be fetched from memory. firstIdx is inclusive,
    -- lastIdx is exclusive for normal buffers and inclusive for index buffers,
    -- in all cases resulting in lastIdx - firstIdx elements. The ctrl vector
    -- is a concatenation of the base address for each buffer and the null
    -- bitmap present flags, dependent on CFG.
    @cmd_ports

    -- Unlock stream (bus clock domain). Produces the chunk tags supplied by
    -- the command stream when all BufferReaders finish processing the command.
    unlock_valid                : out std_logic;
    unlock_ready                : in  std_logic := '1';
    unlock_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    ---------------------------------------------------------------------------
    -- Bus access ports
    ---------------------------------------------------------------------------
    -- Bus access port (bus clock domain).
    bus_rreq_valid              : out std_logic;
    bus_rreq_ready              : in  std_logic;
    bus_rreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_rreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    bus_rdat_valid              : in  std_logic;
    bus_rdat_ready              : out std_logic;
    bus_rdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_rdat_last               : in  std_logic;

    ---------------------------------------------------------------------------
    -- User streams
    ---------------------------------------------------------------------------
    @out_ports

  );
end {camelprefix}ColumnReader;

architecture Behavioral of {camelprefix}ColumnReader is

  @defs

begin

  @arch

  -- Wrap an arbiter and register slices around the requested column reader.
  {lowerprefix}inst: ColumnReaderLevel
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      CFG                       => "{cfg}",
      CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      acc_clk                   => acc_clk,
      acc_reset                 => acc_reset,

      cmd_valid                 => cmd_valid,
      cmd_ready                 => cmd_ready,
      cmd_firstIdx              => cmd_firstIdx,
      cmd_lastIdx               => cmd_lastIdx,
      cmd_ctrl                  => cmd_ctrl,
      cmd_tag                   => cmd_tag,

      unlock_valid              => unlock_valid,
      unlock_ready              => unlock_ready,
      unlock_tag                => unlock_tag,

      bus_rreq_valid(0)         => bus_rreq_valid,
      bus_rreq_ready(0)         => bus_rreq_ready,
      bus_rreq_addr             => bus_rreq_addr,
      bus_rreq_len              => bus_rreq_len,
      bus_rdat_valid(0)         => bus_rdat_valid,
      bus_rdat_ready(0)         => bus_rdat_ready,
      bus_rdat_data             => bus_rdat_data,
      bus_rdat_last(0)          => bus_rdat_last,

      out_valid                 => out_valids,
      out_ready                 => out_readys,
      out_last                  => out_lasts,
      out_dvalid                => out_dvalids,
      out_data                  => out_datas
    );

end Behavioral;
"""

wrapper_component_template = """
component {camelprefix}ColumnReader is
  generic (
    BUS_ADDR_WIDTH              : natural := 32;
    BUS_LEN_WIDTH               : natural := 8;
    BUS_DATA_WIDTH              : natural := 32;
    BUS_BURST_STEP_LEN          : natural := 4;
    BUS_BURST_MAX_LEN           : natural := 16;
    INDEX_WIDTH                 : natural := 32;
    CMD_TAG_ENABLE              : boolean := false;
    CMD_TAG_WIDTH               : natural := 1
  );
  port (
    bus_clk                     : in  std_logic;
    bus_reset                   : in  std_logic;
    acc_clk                     : in  std_logic;
    acc_reset                   : in  std_logic;

    @cmd_ports

    unlock_valid                : out std_logic;
    unlock_ready                : in  std_logic := '1';
    unlock_tag                  : out std_logic_vector(CMD_TAG_WIDTH-1 downto 0);

    bus_rreq_valid              : out std_logic;
    bus_rreq_ready              : in  std_logic;
    bus_rreq_addr               : out std_logic_vector(BUS_ADDR_WIDTH-1 downto 0);
    bus_rreq_len                : out std_logic_vector(BUS_LEN_WIDTH-1 downto 0);
    bus_rdat_valid              : in  std_logic;
    bus_rdat_ready              : out std_logic;
    bus_rdat_data               : in  std_logic_vector(BUS_DATA_WIDTH-1 downto 0);
    bus_rdat_last               : in  std_logic;

    @out_ports
  );
end component;
"""

uut_template_with_unlock = """
  uut: ColumnReaderLevel
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      CFG                       => "{cfg}",
      CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      acc_clk                   => {acc}_clk,
      acc_reset                 => {acc}_reset,

      cmd_valid                 => cmd_valid,
      cmd_ready                 => cmd_ready,
      cmd_firstIdx              => cmd_firstIdx,
      cmd_lastIdx               => cmd_lastIdx,
      cmd_ctrl                  => cmd_ctrl,
      cmd_tag                   => cmd_tag,

      unlock_valid              => unlock_valid,
      unlock_ready              => unlock_ready,
      unlock_tag                => unlock_tag,

      bus_rreq_valid(0)         => bus_rreq_valid,
      bus_rreq_ready(0)         => bus_rreq_ready,
      bus_rreq_addr             => bus_rreq_addr,
      bus_rreq_len              => bus_rreq_len,
      bus_rdat_valid(0)         => bus_rdat_valid,
      bus_rdat_ready(0)         => bus_rdat_ready,
      bus_rdat_data             => bus_rdat_data,
      bus_rdat_last(0)          => bus_rdat_last,

      out_valid                 => out_valids,
      out_ready                 => out_readys,
      out_last                  => out_lasts,
      out_dvalid                => out_dvalids,
      out_data                  => out_datas
    );
"""

uut_template_without_unlock = """
  uut: ColumnReaderLevel
    generic map (
      BUS_ADDR_WIDTH            => BUS_ADDR_WIDTH,
      BUS_LEN_WIDTH             => BUS_LEN_WIDTH,
      BUS_DATA_WIDTH            => BUS_DATA_WIDTH,
      BUS_BURST_STEP_LEN        => BUS_BURST_STEP_LEN,
      BUS_BURST_MAX_LEN         => BUS_BURST_MAX_LEN,
      INDEX_WIDTH               => INDEX_WIDTH,
      CFG                       => "{cfg}",
      CMD_TAG_ENABLE            => CMD_TAG_ENABLE,
      CMD_TAG_WIDTH             => CMD_TAG_WIDTH
    )
    port map (
      bus_clk                   => bus_clk,
      bus_reset                 => bus_reset,
      acc_clk                   => {acc}_clk,
      acc_reset                 => {acc}_reset,

      cmd_valid                 => cmd_valid,
      cmd_ready                 => cmd_ready,
      cmd_firstIdx              => cmd_firstIdx,
      cmd_lastIdx               => cmd_lastIdx,
      cmd_ctrl                  => cmd_ctrl,

      bus_rreq_valid(0)         => bus_rreq_valid,
      bus_rreq_ready(0)         => bus_rreq_ready,
      bus_rreq_addr             => bus_rreq_addr,
      bus_rreq_len              => bus_rreq_len,
      bus_rdat_valid(0)         => bus_rdat_valid,
      bus_rdat_ready(0)         => bus_rdat_ready,
      bus_rdat_data             => bus_rdat_data,
      bus_rdat_last(0)          => bus_rdat_last,

      out_valid                 => out_valids,
      out_ready                 => out_readys,
      out_last                  => out_lasts,
      out_dvalid                => out_dvalids,
      out_data                  => out_datas
    );
"""

class ColumnReader(object):
    """Represents a ColumnReader."""

    def __init__(self, field, instance_prefix=None, signal_prefix="", bus_clk_prefix="", main_clk_prefix="", **opts):
        """Generates a ColumnReader for the given Arrow field. prefix
        optionally specifies a name for the ColumnReader, which will be
        prefixed to all signals and instance names in the generated code."""
        super().__init__()

        # Basic error checking.
        if not isinstance(field, Field):
            raise TypeError("field must be of type %s" % Field)
        self.field = field

        # Figure out the prefixes.
        if instance_prefix is None:
            instance_prefix = field.name
        if instance_prefix and not instance_prefix[-1] == "_":
            instance_prefix += "_"
        self.instance_prefix = instance_prefix

        if signal_prefix is None:
            signal_prefix = field.name
        if signal_prefix and not signal_prefix[-1] == "_":
            signal_prefix += "_"
        self.signal_prefix = signal_prefix

        if bus_clk_prefix and not bus_clk_prefix[-1] == "_":
            bus_clk_prefix += "_"
        self.bus_clk_prefix = bus_clk_prefix

        if main_clk_prefix and not main_clk_prefix[-1] == "_":
            main_clk_prefix += "_"
        self.main_clk_prefix = main_clk_prefix

        # Construct the streams.
        self.cmd_stream, cmd_ctrl = _new_cmd_stream(self.signal_prefix)

        p = self.signal_prefix + "unlock_"
        self.unlock_stream = Stream(p)
        self.unlock_stream.append(Signal(p + "tag", CMD_TAG_WIDTH))

        p = self.signal_prefix + "bus_rreq_"
        self.bus_rreq_stream = Stream(p)
        self.bus_rreq_stream.append(Signal(p + "addr", BUS_ADDR_WIDTH))
        self.bus_rreq_stream.append(Signal(p + "len", BUS_LEN_WIDTH))

        p = self.signal_prefix + "bus_rdat_"
        self.bus_rdat_stream = Stream(p)
        self.bus_rdat_stream.append(Signal(p + "data", BUS_DATA_WIDTH))
        self.bus_rdat_stream.append(Signal(p + "last"))

        main_out_stream, out_data = _new_out_stream(self.signal_prefix)

        # Construct the field reader.
        reader, secondary_out_streams = _field_reader(
            self.field,
            self.signal_prefix, None,
            self.cmd_stream, cmd_ctrl,
            main_out_stream, out_data,
            **opts)

        # If the reader has more than one bus, wrap in an arbiter.
        if reader.bus_count() > 1:
            reader = ArbReaderLevel(reader)
        self.reader = reader

        # Construct the output stream group.
        self.out_stream = StreamGroup(main_out_stream, *secondary_out_streams)

    @property
    def _camel_prefix(self):
        """Returns the instance prefix in CamelCase."""
        return "".join([w[:1].upper() + w[1:] for w in self.instance_prefix.split("_")])

    @property
    def _lower_prefix(self):
        """Returns the instance prefix in lower_case."""
        return self.instance_prefix.lower()

    def cfg(self):
        """Returns the cfg string representation of this ColumnReader."""
        return str(self.reader)

    def wrapper_body(self):
        """Returns the VHDL entity and body for this ColumnReader's wrapper."""
        return gen_template(
            wrapper_body_template,
            camelprefix = self._camel_prefix,
            lowerprefix = self._lower_prefix,
            cfg = self.cfg(),
            cmd_ports = self.cmd_stream.def_ports(PortDir.IN, False),
            out_ports = self.out_stream.def_ports(PortDir.OUT, False).trimsep(),
            defs = self.cmd_stream.def_signals(False) + self.out_stream.def_signals(False),
            arch = self.cmd_stream.arch_serialize() + self.out_stream.arch_deserialize()
        )

    def wrapper_component(self):
        """Returns the VHDL entity and body for this ColumnReader's wrapper."""
        return gen_template(
            wrapper_component_template,
            camelprefix = self.instance_prefix[:-1],
            cmd_ports = self.cmd_stream.def_ports(PortDir.IN, False),
            out_ports = self.out_stream.def_ports(PortDir.OUT, False).trimsep()
        )

    def testbench(self, **kwargs):
        """Generates a randomized testbench for this ColumnReader."""

        # Randomize any parameters not explicitly given.
        params = []
        def get_param(name, default):
            value = kwargs.get(name, default)
            params.append((name, value))
            return value

        seed           = get_param("seed", random.randrange(1<<32))
        random.seed(seed)
        row_count      = get_param("row_count", 100)
        cmd_count      = get_param("cmd_count", 100)
        addr_width     = get_param("addr_width", random.randint(32, 64))
        data_width     = get_param("data_width", 1 << random.randint(5, 9))
        burst_step_len = get_param("burst_step_len", max(self.field.widest() // data_width, 1 << random.randint(0, 5)))
        burst_max_len  = get_param("burst_max_len", burst_step_len * (1 << random.randint(0, 4)))
        len_width      = get_param("len_width",  random.randint(1, 4) * int.bit_length(burst_max_len))
        tag_width      = get_param("tag_width", random.choice([0, 1, 4]))
        multi_clk      = get_param("multi_clk", True)
        random_bus_rreq_timing  = get_param("random_bus_rreq_timing", random.choice([True, False]))
        random_bus_rdat_timing = get_param("random_bus_rdat_timing", random.choice([True, False]))

        # Generate the testbench wrapper object.
        acc = "acc" if multi_clk else "bus"
        tb = Testbench(self._camel_prefix + "ColumnReader_tb", {"bus", acc})

        # Set constants.
        tb.set_const("BUS_ADDR_WIDTH",      addr_width)
        tb.set_const("BUS_LEN_WIDTH",       len_width)
        tb.set_const("BUS_DATA_WIDTH",      data_width)
        tb.set_const("BUS_BURST_STEP_LEN",  burst_step_len)
        tb.set_const("BUS_BURST_MAX_LEN",   burst_max_len)
        tb.set_const("INDEX_WIDTH",         32)
        tb.set_const("CMD_TAG_ENABLE",      tag_width > 0)
        tb.set_const("CMD_TAG_WIDTH",       max(1, tag_width))

        # Add the streams.
        tb.append_input_stream(self.cmd_stream, "bus")
        if tag_width > 0:
            tb.append_output_stream(self.unlock_stream, "bus")
        tb.append_output_stream(self.bus_rreq_stream, "bus")
        tb.append_input_stream(self.bus_rdat_stream, "bus")
        tb.append_output_stream(self.out_stream, acc)

        # Generate a random set of commands.
        commands = []
        for _ in range(cmd_count):
            a = random.randrange(row_count)
            b = random.randrange(row_count)
            commands.append((min(a, b), max(a, b) + 1))

        # Generate toplevel command stream signal test vectors.
        cmd_first_tv  = tb.append_test_vector(TestVectors(self.cmd_stream.signals[0]))
        cmd_last_tv   = tb.append_test_vector(TestVectors(self.cmd_stream.signals[1]))
        for start, stop in commands:
            cmd_first_tv.append(start)
            cmd_last_tv.append(stop)

        # Generate tag stream signal test vectors.
        if tag_width > 0:
            tags = [random.randrange(1 << tag_width) for _ in commands]
            tb.append_test_vector(TestVectors(self.cmd_stream.signals[-1])).extend(tags)
            tb.append_test_vector(TestVectors(self.unlock_stream.signals[0])).extend(tags)

        # Generate output stream master last/dvalid test vectors.
        out_last_tv   = tb.append_test_vector(TestVectors(self.out_stream.streams[0].signals[0]))
        out_dvalid_tv = tb.append_test_vector(TestVectors(self.out_stream.streams[0].signals[1]))
        for start, stop in commands:
            for i in range(start, stop):
                out_last_tv.append(int(i == stop - 1))
                out_dvalid_tv.append(1)

        # Generate a memory model.
        memory = Memory()
        tb.append_memory(memory, self.bus_rreq_stream, self.bus_rdat_stream, "bus",
                         random_bus_rreq_timing, random_bus_rdat_timing)

        # Generate the test vectors for the readers.
        tvs = self.reader.test_vectors(memory, row_count, commands)
        for tv in tvs:
            tb.append_test_vector(tv)

        # Append unit under test.
        template = uut_template_with_unlock if tag_width > 0 else uut_template_without_unlock
        tb.append_uut(template.format(cfg=self.cfg(), acc=acc))

        # Add documentation.
        doc = []
        doc.append("Memory dump:")
        doc.extend(["  " + x for x in memory.hexdump().split("\n")])
        doc.append("")
        doc.append("Command stream:")
        transfer = 1
        for i, (start, end) in enumerate(commands):
            doc.append("  Command %3d: %4d to %4d = out transfer %5d to %5d" % (
                i + 1, start, end - 1, transfer, transfer + (end - start - 1)))
            transfer += end - start
        doc.append("")
        doc.append("Generator parameters:")
        doc.extend(["  %s: %s" % x for x in params])
        doc.append("")
        doc.append("Schema:")
        doc.extend(["  " + x for x in self.field.pprint().split("\n")])


        tb.append_uut("\n".join(["  -- " + x for x in doc]))

        return str(tb)
