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

"""This package contains a python object representation of Arrow fields
(= columns etc.) that includes defaults for all the configuration keys
supported by the VHDL ColumnReader."""

import random
from .configurable import *

__all__ = ["Field", "NullField", "ScalarField", "BytesField", "ListField",
           "StructField", "UnionField"]


def weighted_choice(choices):
    """Weighted version of random.choice.
    stackoverflow.com/questions/3679694"""
    total = sum(w for c, w in choices)
    r = random.uniform(0, total)
    upto = 0
    for c, w in choices:
        if upto + w >= r:
            return c
        upto += w
    return choices[-1][0]


class Field(Configurable):
    """Represents an Arrow field."""

    def __init__(self, name="el", nullable=True, **config):
        super().__init__(**config)
        self.name = name
        self.nullable = nullable

    def _params(self):
        """Returns a list of parameters that get added to the __str__
        representation of this field."""
        return ["name=%s" % self.name, "nullable=%s" % self.nullable] + super()._params()

    def _pprint_params(self):
        """Returns a list of parameters that get added to the pprint
        representation of this field."""
        return ["nullable=%s" % self.nullable] + super()._params()

    def _pprint_children(self):
        """Returns a list of children that get added to the pprint
        representation of this field."""
        return []

    def pprint(self):
        """Pretty-prints this field as a multi-line string."""
        header = "%s: %s" % (self.name, self.__class__.__name__)
        params = [' = '.join(["%s" % x for x in param.split("=", 1)]).strip() for param in self._pprint_params()]
        children = self._pprint_children()
        indent = "    "
        rls = []
        for child in reversed(children):
            cls = child.pprint().split("\n")
            for cl in reversed(cls[1:]):
                rls.append(indent + cl)
            if not indent.strip():
                indent = " '- "
            else:
                indent = " |- "
            rls.append(indent + cls[0])
            indent = " |  "
            rls.append(indent)
        if not indent.strip():
            indent = " :  "
        for param in reversed(params):
            rls.append(indent + param)
        rls.append(header)
        rls.reverse()
        return '\n'.join(rls)

    def is_null(self):
        """Returns True if this field has a null type, i.e. has no value
        buffers. Such fields are ignored by the VHDL generator."""
        raise NotImplemented()

    def widest(self):
        """Returns the widest type of all the fields children. Useful for
        constraining interface requirements such as burst step length."""
        raise NotImplemented()

    @classmethod
    def randomized(cls, name="el", listdepth=0):
        """Generates a random Field."""

        # Prevent infinite recursion in case a child Field decides to not
        # override this method.
        if cls != Field:
            raise NotImplemented()

        choices = [
            (NullField,   0.1),
            (ScalarField, 1.0),
            (BytesField,  1.0 / 4**listdepth),
            (ListField,   1.0 / 4**listdepth),
            (StructField, 2.0 / 4**listdepth)
        ]
        return weighted_choice(choices).randomized(name, listdepth)

    @classmethod
    def from_arrow(cls, *args, **kwargs):
        """Returns a Field based on the given Arrow column, or something. Stub
        method for now. TODO: implement this."""
        raise NotImplemented()


class NullField(Field):
    """Represents an Arrow Null field."""

    def is_null(self):
        """Returns True if this field has a null type, i.e. has no value
        buffers. Such fields are ignored by the VHDL generator."""
        return True

    def widest(self):
        return 1

    @classmethod
    def randomized(cls, name="el", listdepth=0):
        """Generates a random Field."""
        return cls(name=name)


class ScalarField(Field):
    """Represents an Arrow scalar field (i.e., one of type Int, FloatingPoint,
    Bool, Decimal, Date, Time, Timestamp, or Interval)."""

    def __init__(self, bit_width, **kwargs):
        super().__init__(**kwargs)
        self.bit_width = bit_width

    def _params(self):
        """Returns a list of parameters that get added to the __str__
        representation of this field."""
        return ["%d" % self.bit_width] + super()._params()

    def _pprint_params(self):
        """Returns a list of parameters that get added to the pprint
        representation of this field."""
        return ["bit_width=%s" % self.bit_width] + super()._pprint_params()

    @property
    def _config_defaults(self):
        return {

            # Default value buffer reader configuration.
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
            "out_slice":                True,

            # Default null buffer reader configuration.
            "null_cmd_in_slice":        False,
            "null_bus_req_slice":       True,
            "null_bus_fifo_depth":      16,
            "null_bus_fifo_ram_config": "",
            "null_unlock_slice":        True,
            "null_shr2gb_slice":        False,
            "null_gb2fifo_slice":       False,
            "null_fifo_size":           64,
            "null_fifo_ram_config":     "",
            "null_fifo_xclk_stages":    0,
            "null_fifo2post_slice":     False,
            "null_out_slice":           True
        }

    def is_null(self):
        """Returns True if this field has a null type, i.e. has no value
        buffers. Such fields are ignored by the VHDL generator."""
        return False

    def widest(self):
        return self.bit_width

    @classmethod
    def randomized(cls, name="el", listdepth=0):
        """Generates a random Field."""
        return cls(
            bit_width = random.choice([1, 8, 16, 32, 64, 128]),
            name = name,
            nullable = random.choice([True, True, False]),

            cmd_in_slice =             random.choice([True, False]),
            bus_req_slice =            random.choice([True, False]),
            bus_fifo_depth =           1 << random.randint(1, 8),
            unlock_slice =             random.choice([True, False]),
            shr2gb_slice =             random.choice([True, False]),
            gb2fifo_slice =            random.choice([True, False]),
            fifo_size =                1 << random.randint(1, 8),
            fifo_xclk_stages =         random.choice([0, 2, 3]),
            fifo2post_slice =          random.choice([True, False]),
            out_slice =                random.choice([True, False]),

            null_cmd_in_slice =        random.choice([True, False]),
            null_bus_req_slice =       random.choice([True, False]),
            null_bus_fifo_depth =      1 << random.randint(1, 8),
            null_unlock_slice =        random.choice([True, False]),
            null_shr2gb_slice =        random.choice([True, False]),
            null_gb2fifo_slice =       random.choice([True, False]),
            null_fifo_size =           1 << random.randint(1, 8),
            null_fifo_xclk_stages =    random.choice([0, 2, 3]),
            null_fifo2post_slice =     random.choice([True, False]),
            null_out_slice =           random.choice([True, False])
          )


class BytesField(Field):
    """Represents an Arrow Binary or Utf8 field."""

    def __init__(self, bit_width=8, **kwargs):
        super().__init__(**kwargs)
        self.bit_width = bit_width

    def _params(self):
        """Returns a list of parameters that get added to the __str__
        representation of this field."""
        return ["%s" % self.bit_width] + super()._params()

    def _pprint_params(self):
        """Returns a list of parameters that get added to the pprint
        representation of this field."""
        return (["bit_width=%s" % self.bit_width] if self.bit_width != 8 else []) + super()._pprint_params()

    @property
    def _config_defaults(self):
        return {

            # Default number of bytes returned per cycle.
            "bytes_per_cycle":          1,

            # Default value buffer reader configuration.
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

            # Default index buffer reader configuration.
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

            # Default list synchronization unit configuration.
            "len_out_slice":            True,
            "data_in_slice":            False,
            "len_sync_slice":           True,
            "data_out_slice":           True,

            # Default null buffer reader configuration.
            "null_cmd_in_slice":        False,
            "null_bus_req_slice":       True,
            "null_bus_fifo_depth":      16,
            "null_bus_fifo_ram_config": "",
            "null_unlock_slice":        True,
            "null_shr2gb_slice":        False,
            "null_gb2fifo_slice":       False,
            "null_fifo_size":           64,
            "null_fifo_ram_config":     "",
            "null_fifo_xclk_stages":    0,
            "null_fifo2post_slice":     False,
            "null_out_slice":           True
        }

    def is_null(self):
        """Returns True if this field has a null type, i.e. has no value
        buffers. Such fields are ignored by the VHDL generator."""
        return False

    def widest(self):
        return self.bit_width

    @classmethod
    def randomized(cls, name="el", listdepth=0):
        """Generates a random Field."""
        return cls(
            name = name,
            nullable = random.choice([True, True, False]),
            bytes_per_cycle = random.randint(1, 8),

            cmd_in_slice =             random.choice([True, False]),
            bus_req_slice =            random.choice([True, False]),
            bus_fifo_depth =           1 << random.randint(1, 8),
            unlock_slice =             random.choice([True, False]),
            shr2gb_slice =             random.choice([True, False]),
            gb2fifo_slice =            random.choice([True, False]),
            fifo_size =                1 << random.randint(1, 8),
            fifo_xclk_stages =         random.choice([0, 2, 3]),
            fifo2post_slice =          random.choice([True, False]),
            out_slice =                random.choice([True, False]),

            idx_cmd_in_slice =         random.choice([True, False]),
            idx_bus_req_slice =        random.choice([True, False]),
            idx_bus_fifo_depth =       1 << random.randint(1, 8),
            idx_cmd_out_slice =        random.choice([True, False]),
            idx_unlock_slice =         random.choice([True, False]),
            idx_shr2gb_slice =         random.choice([True, False]),
            idx_gb2fifo_slice =        random.choice([True, False]),
            idx_fifo_size =            1 << random.randint(1, 8),
            idx_fifo_xclk_stages =     random.choice([0, 2, 3]),
            idx_fifo2post_slice =      random.choice([True, False]),

            len_out_slice =            random.choice([True, False]),
            data_in_slice =            random.choice([True, False]),
            len_sync_slice =           random.choice([True, False]),
            data_out_slice =           random.choice([True, False]),

            null_cmd_in_slice =        random.choice([True, False]),
            null_bus_req_slice =       random.choice([True, False]),
            null_bus_fifo_depth =      1 << random.randrange(1, 8),
            null_unlock_slice =        random.choice([True, False]),
            null_shr2gb_slice =        random.choice([True, False]),
            null_gb2fifo_slice =       random.choice([True, False]),
            null_fifo_size =           1 << random.randrange(1, 8),
            null_fifo_xclk_stages =    random.choice([0, 2, 3]),
            null_fifo2post_slice =     random.choice([True, False]),
            null_out_slice =           random.choice([True, False])
          )


class ListField(Field):
    """Represents an Arrow List field."""

    def __init__(self, child, **kwargs):
        super().__init__(**kwargs)
        self.child = child

    def _params(self):
        """Returns a list of parameters that get added to the __str__
        representation of this field."""
        return ["%s" % self.child] + super()._params()

    def _pprint_children(self):
        """Returns a list of children that get added to the pprint
        representation of this field."""
        return [self.child]

    @property
    def _config_defaults(self):
        return {

            # Default index buffer reader configuration.
            "cmd_in_slice":             False,
            "bus_req_slice":            True,
            "bus_fifo_depth":           16,
            "bus_fifo_ram_config":      "",
            "cmd_out_slice":            True,
            "unlock_slice":             True,
            "shr2gb_slice":             False,
            "gb2fifo_slice":            False,
            "fifo_size":                64,
            "fifo_ram_config":          "",
            "fifo_xclk_stages":         0,
            "fifo2post_slice":          False,

            # Default list synchronization unit configuration.
            "len_out_slice":            True,
            "len_sync_slice":           True,
            "data_in_slice":            False,
            "data_out_slice":           True,

            # Default null buffer reader configuration.
            "null_cmd_in_slice":        False,
            "null_bus_req_slice":       True,
            "null_bus_fifo_depth":      16,
            "null_bus_fifo_ram_config": "",
            "null_unlock_slice":        True,
            "null_shr2gb_slice":        False,
            "null_gb2fifo_slice":       False,
            "null_fifo_size":           64,
            "null_fifo_ram_config":     "",
            "null_fifo_xclk_stages":    0,
            "null_fifo2post_slice":     False,
            "null_out_slice":           True
        }

    def is_null(self):
        """Returns True if this field has a null type, i.e. has no value
        buffers. Such fields are ignored by the VHDL generator."""
        return self.child.is_null()

    def widest(self):
        return max(32, self.child.widest())

    @classmethod
    def randomized(cls, name="el", listdepth=0):
        """Generates a random Field."""
        return cls(
            Field.randomized(listdepth=listdepth+1),
            name = name,
            nullable = random.choice([True, True, False]),

            cmd_in_slice =             random.choice([True, False]),
            bus_req_slice =            random.choice([True, False]),
            bus_fifo_depth =           1 << random.randint(1, 8),
            cmd_out_slice =            random.choice([True, False]),
            unlock_slice =             random.choice([True, False]),
            shr2gb_slice =             random.choice([True, False]),
            gb2fifo_slice =            random.choice([True, False]),
            fifo_size =                1 << random.randint(1, 8),
            fifo_xclk_stages =         random.choice([0, 2, 3]),
            fifo2post_slice =          random.choice([True, False]),

            len_out_slice =            random.choice([True, False]),
            len_sync_slice =           random.choice([True, False]),
            data_in_slice =            random.choice([True, False]),
            data_out_slice =           random.choice([True, False]),

            null_cmd_in_slice =        random.choice([True, False]),
            null_bus_req_slice =       random.choice([True, False]),
            null_bus_fifo_depth =      1 << random.randint(1, 8),
            null_unlock_slice =        random.choice([True, False]),
            null_shr2gb_slice =        random.choice([True, False]),
            null_gb2fifo_slice =       random.choice([True, False]),
            null_fifo_size =           1 << random.randint(1, 8),
            null_fifo_xclk_stages =    random.choice([0, 2, 3]),
            null_fifo2post_slice =     random.choice([True, False]),
            null_out_slice =           random.choice([True, False])
        )


class StructField(Field):
    """Represents an Arrow Struct field."""

    def __init__(self, *children, **kwargs):
        super().__init__(**kwargs)
        self.children = children

    def _params(self):
        """Returns a list of parameters that get added to the __str__
        representation of this field."""
        return ["children=%s" % self.children] + super()._params()

    def _pprint_children(self):
        """Returns a list of children that get added to the pprint
        representation of this field."""
        return self.children

    @property
    def _config_defaults(self):
        return {

            # Default null buffer reader configuration.
            "null_cmd_in_slice":        False,
            "null_bus_req_slice":       True,
            "null_bus_fifo_depth":      16,
            "null_bus_fifo_ram_config": "",
            "null_unlock_slice":        True,
            "null_shr2gb_slice":        False,
            "null_gb2fifo_slice":       False,
            "null_fifo_size":           64,
            "null_fifo_ram_config":     "",
            "null_fifo_xclk_stages":    0,
            "null_fifo2post_slice":     False,
            "null_out_slice":           True
        }

    def is_null(self):
        """Returns True if this field has a null type, i.e. has no value
        buffers. Such fields are ignored by the VHDL generator."""
        for child in self.children:
            if not child.is_null():
                return False
        return True

    def widest(self):
        widest = 1;
        for child in self.children:
            if not child.is_null():
                widest = max(widest, child.widest())
        return widest

    def iter_children(self):
        """Iterates over all non-null children."""
        for child in self.children:
            if not child.is_null():
                yield child

    @classmethod
    def randomized(cls, name="el", listdepth=0):
        """Generates a random Field."""
        children = []
        while (len(children) < 2 or random.randrange(2) != 0) and len(children) < 26:
            children.append(Field.randomized(name=chr(ord('a') + len(children)), listdepth=listdepth+1))
        return cls(
            *children,
            name = name,
            nullable = random.choice([True, True, False]),

            null_cmd_in_slice =        random.choice([True, False]),
            null_bus_req_slice =       random.choice([True, False]),
            null_bus_fifo_depth =      1 << random.randint(1, 8),
            null_unlock_slice =        random.choice([True, False]),
            null_shr2gb_slice =        random.choice([True, False]),
            null_gb2fifo_slice =       random.choice([True, False]),
            null_fifo_size =           1 << random.randint(1, 8),
            null_fifo_xclk_stages =    random.choice([0, 2, 3]),
            null_fifo2post_slice =     random.choice([True, False]),
            null_out_slice =           random.choice([True, False])
        )


class UnionField(Field):
    """Represents an Arrow Union field."""

    def __init__(self, *args, **kwargs):
        raise NotImplemented("Arrow unions are not yet supported")

    def _params(self):
        raise NotImplemented("Arrow unions are not yet supported")

    @property
    def _config_defaults(self):
        raise NotImplemented("Arrow unions are not yet supported")

    def is_null(self):
        raise NotImplemented("Arrow unions are not yet supported")

