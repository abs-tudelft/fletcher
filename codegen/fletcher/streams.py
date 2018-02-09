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

"""This package contains a representation of streams as used by the
ColumnReader and TableReader units."""

from .lines import *
from enum import Enum

__all__ = ["Generic", "PortDir", "Signal", "SignalGroup", "Stream",
           "StreamGroup"]


class Generic(tuple):
    """Represents a linear expression of generics."""
    
    def __new__(cls, bits, **generics):
        if isinstance(bits, str) and not generics:
            return super(Generic, cls).__new__(cls, (0, (bits, 1)))
        else:
            return super(Generic, cls).__new__(cls, (bits,) + tuple((generic, amount) for generic, amount in sorted(generics.items()) if amount != 0))
    
    def __str__(self):
        s = []
        for generic, amount in self[1:]:
            if amount == 1:
                s.append("+%s" % generic)
            elif amount == -1:
                s.append("-%s" % generic)
            elif amount != 0:
                s.append("%+d*%s" % (amount, generic))
        if self[0] != 0:
            s.append("%+d" % self[0])
        elif not s:
            s.append("+0")
        s = "".join(s)
        if s[0] == "+":
            s = s[1:]
        return s
    
    def resolve(self, **generics):
        bits = self[0]
        d = {}
        for generic, amount in self[1:]:
            val = generics.get(generic, None)
            if val is None:
                d[generic] = amount
            else:
                bits += val * amount
        if d:
            return self.__class__(bits, **d)
        else:
            return bits
    
    @classmethod
    def add(cls, a, b):
        d = {}
        for generic, amount in a[1:] + b[1:]:
            d[generic] = d.get(generic, 0) + amount
        return cls(a[0] + b[0], **d)
    
    @classmethod
    def sub(cls, a, b):
        d = {}
        for generic, amount in a[1:]:
            d[generic] = d.get(generic, 0) + amount
        for generic, amount in b[1:]:
            d[generic] = d.get(generic, 0) - amount
        return cls(a[0] - b[0], **d)
    
    def __add__(self, other):
        if isinstance(other, int):
            other = self.__class__(other)
        if isinstance(other, Generic):
            return self.__class__.add(self, other)
        raise ValueError()
    
    def __sub__(self, other):
        if isinstance(other, int):
            other = self.__class__(other)
        if isinstance(other, Generic):
            return self.__class__.sub(self, other)
        raise ValueError()
    
    def __rsub__(self, other):
        if isinstance(other, int):
            other = self.__class__(other)
        if isinstance(other, Generic):
            return self.__class__.sub(other, self)
        raise ValueError()
    
    def __neg__(self):
        return 0 - self
    
    def __mul__(self, other):
        if isinstance(other, int):
            return self.__class__(self[0] * other, **{generic: amount * other for generic, amount in self[1:]})
        raise ValueError()
    
    __radd__ = __add__
    __rmul__ = __mul__


class PortDir(Enum):
    """Represents a VHDL port direction."""
    IN  = 0
    OUT = 1
    
    def __str__(self):
        return {
            self.__class__.IN: "in ",
            self.__class__.OUT: "out"
        }[self]
    
    def reverse(self):
        return {
            self.__class__.IN: self.__class__.OUT,
            self.__class__.OUT: self.__class__.IN
        }[self]


class Signal(object):
    """Represents a VHDL signal."""
    
    def __init__(self, name, typ=None, reverse_dir=False):
        """Constructs a signal. If typ is None, the signal is an std_logic,
        otherwise it is an std_logic_vector of the given typ in bits."""
        super().__init__()
        self.name = name
        self.typ = typ
        self.reverse_dir = reverse_dir
    
    @property
    def width(self):
        """Returns the width of the signal in bits."""
        if self.typ is None:
            return 1
        else:
            return self.typ
    
    def type_name(self):
        """Returns the VHDL type name."""
        if self.typ is None:
            return "std_logic"
        else:
            return "std_logic_vector(%s downto 0)" % (self.typ - 1,)
    
    def def_signal(self):
        """Returns the VHDL signal definition for this signal."""
        return Line("signal %s" % self.name, 32, ": %s;" % self.type_name())

    def def_port(self, portdir):
        """Returns the VHDL port definition for this signal."""
        if self.reverse_dir:
            portdir = portdir.reverse()
        return Line("%s" % self.name, 32, ": %s %s;" % (portdir, self.type_name()))


class SignalGroup(Signal):
    """Represents a signal that is the concatenation of a set of other
    signals. Provides the functions needed to generate the serialization/
    deserialization code."""
    
    def __init__(self, name, *signals, reverse_dir=False):
        """Constructs the serialized version of a group of signals."""
        super(Signal, self).__init__()
        self.name = name
        self.signals = list(signals)
        self.reverse_dir = reverse_dir
    
    def append(self, signal):
        """Appends a signal to the list. Signals are appended to the LSB-side
        of the concatenated signal. The signal is returned for convenience."""
        self.signals.append(signal)
        return signal
    
    def extend(self, signals):
        """Extends the signal list. Signals are appended to the LSB-side of the
        concatenated signal."""
        self.extend.extend(signals)
    
    def __iter__(self):
        """Iterates over the child signals from MSB to LSB. Multiple levels of
        SignalGroups are flattened."""
        for sig in self.signals:
            if isinstance(sig, SignalGroup):
                for subsig in sig:
                    yield subsig
            else:
                yield sig
    
    @property
    def width(self):
        """Returns the width of the concatenated signal in bits."""
        width = 0
        for signal in self:
            width += signal.width
        return width
    
    @property
    def typ(self):
        """Returns the type for the concatenated signal. This is just the
        width, but clamped to 1 to prevent null vectors."""
        w = self.width
        if w == 0:
            return 1
        return w
    
    def def_subsignals(self):
        """Returns VHDL signal definitions for all the subsignals in this
        group."""
        l = Lines()
        for signal in self:
            l += signal.def_signal()
        return l

    def def_subports(self, portdir):
        """Returns VHDL port definitions for all the subsignals in this
        group."""
        l = Lines()
        for signal in self:
            l += signal.def_port(portdir)
        return l
    
    def arch_serdes(self, serialize):
        """Returns the architecture code for serialization or deserialization
        depending on whether serialize is True or False."""
        if self.reverse_dir:
            serialize = not serialize
        l = Lines()
        pos = self.width
        for signal in self:
            t = signal.typ
            if t is None:
                pos -= 1
                r = "%s" % (pos,)
            else:
                frm = pos - 1
                pos -= t
                r = "%s downto %s" % (frm, pos)
            s = "%s(%s)" % (self.name, r)
            if serialize:
                l += Line(s, 32, "<= " + signal.name + ";")
            else:
                l += Line(signal.name, 32, "<= " + s + ";")
        return l
    
    def arch_serialize(self):
        """Returns the architecture code for serialization."""
        return self.arch_serdes(True)
    
    def arch_deserialize(self):
        """Returns the architecture code for deserialization."""
        return self.arch_serdes(False)


class Stream(object):
    """Represents a stream."""
    
    def __init__(self, prefix, *signals):
        super().__init__()
        
        # Construct valid/ready signals.
        if prefix and not prefix[-1] == "_":
            prefix += "_"
        self.name = prefix
        self.valid = Signal(prefix + "valid")
        self.ready = Signal(prefix + "ready", reverse_dir=True)
        self.signals = list(signals)
    
    def append(self, signal):
        """Appends a signal to the stream and returns it for convenience."""
        self.signals.append(signal)
        return signal
    
    def extend(self, signals):
        """Extends the signal list."""
        self.signals.extend(signals)
    
    def __iter__(self, normal=True, serialized=True, deserialized=True):
        """Iterates over the specified kinds of signals in logical order."""
        if normal:
            yield self.valid
            yield self.ready
        for sig in self.signals:
            if isinstance(sig, SignalGroup):
                if serialized:
                    yield sig
                if deserialized:
                    for subsig in sig:
                        yield subsig
            elif normal:
                yield sig
    
    def def_ports(self, portdir, serialized):
        """Returns port declarations for this stream. serialized determines
        whether the serialized or deserialized ports are returned for
        SignalGroups."""
        l = Lines()
        for sig in self.__iter__(serialized=serialized, deserialized=not serialized):
            l += sig.def_port(portdir)
        return l
    
    def def_signals(self, port_serialized=None):
        """Returns signal declarations for this stream. port_serialized must
        be set to the serialized parameter passed to def_ports() if part of the
        signals are ports; in this case those signals will not be redefined."""
        if port_serialized is None:
            normal = True
            serialized = True
            deserialized = True
        else:
            normal = False
            serialized = not port_serialized
            deserialized = port_serialized
        
        l = Lines()
        for sig in self.__iter__(normal=normal, serialized=serialized, deserialized=deserialized):
            l += sig.def_signal()
        return l
    
    def arch_serdes(self, serialize):
        """Returns the architecture code for serialization or deserialization
        depending on whether serialize is True or False."""
        l = Lines()
        for group in self.__iter__(normal=False, deserialized=False):
            l += group.arch_serdes(serialize)
        return l
    
    def arch_serialize(self):
        """Returns the architecture code for serialization."""
        return self.arch_serdes(True)
    
    def arch_deserialize(self):
        """Returns the architecture code for deserialization."""
        return self.arch_serdes(False)


class StreamGroup(object):
    """Represents a serialized group of streams."""
    
    def __init__(self, *streams):
        """Constucts a stream group. The serialized signals take the names of
        the signals in the first stream, suffixed with an s. Each stream must
        have the same amount of signals (they SHOULD have exactly the same
        buildup for this grouping to make any sense). The first stream in the
        list gets the lower index (unlike the ordering in SignalGroup)."""
        super().__init__()
        
        streams = list(streams)
        self.streams = streams
        
        self.valid = SignalGroup(streams[0].valid.name + "s")
        self.ready = SignalGroup(streams[0].ready.name + "s", reverse_dir=True)
        self.signals = [SignalGroup(signal.name + "s") for signal in streams[0].signals]
        for stream in reversed(streams):
            self.valid.append(stream.valid)
            self.ready.append(stream.ready)
            for i in range(len(self.signals)):
                self.signals[i].append(stream.signals[i])
    
    def __iter__(self, serialized=True, deserialized=True, breaks=False):
        """Iterates over the specified kinds of signals in logical order."""
        if serialized:
            yield self.valid
            yield self.ready
            for sig in self.signals:
                yield sig
        if deserialized:
            enable_breaks = breaks and serialized
            for stream in self.streams:
                if enable_breaks:
                    yield None
                enable_breaks = breaks
                for sig in stream.__iter__(serialized=False):
                    yield sig
    
    @property
    def name(self):
        """Returns the name of the first stream in the group."""
        return self.streams[0].name
    
    def def_ports(self, portdir, serialized):
        """Returns port declarations for this stream. serialized determines
        whether the serialized or deserialized ports are returned for
        SignalGroups."""
        l = Lines()
        for sig in self.__iter__(serialized=serialized, deserialized=not serialized, breaks=True):
            if sig is None:
                l += Line()
            else:
                l += sig.def_port(portdir)
        return l
    
    def def_signals(self, port_serialized=None):
        """Returns signal declarations for this stream. port_serialized must
        be set to the serialized parameter passed to def_ports() if part of the
        signals are ports; in this case those signals will not be redefined."""
        if port_serialized is None:
            serialized = True
            deserialized = True
        else:
            serialized = not port_serialized
            deserialized = port_serialized
        
        l = Lines()
        for sig in self.__iter__(serialized=serialized, deserialized=deserialized, breaks=True):
            if sig is None:
                l += Line()
            else:
                l += sig.def_signal()
        return l
    
    def arch_serdes(self, serialize):
        """Returns the architecture code for serialization or deserialization
        depending on whether serialize is True or False."""
        l = Lines()
        for group in self.__iter__(deserialized=False):
            l += group.arch_serdes(serialize)
        return l
    
    def arch_serialize(self):
        """Returns the architecture code for serialization."""
        return self.arch_serdes(True)
    
    def arch_deserialize(self):
        """Returns the architecture code for deserialization."""
        return self.arch_serdes(False)

