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

"""This package contains classes that wrap generated VHDL code, providing
intuitive functions for indentation, alignment, and automatic comment line
wrapping."""

import textwrap

__all__ = ["Lines", "Line", "gen_template"]


class Lines(object):
    """Represents a block of VHDL code with nice indentation and wrapping
    features."""
    
    class Line(object):
        """Represents a line of VHDL code with nice indentation and wrapping
        features."""
        
        def __init__(self, *args, comment=None):
            """Constructs a line. The argument list should contain strings intermixed
            with ints; the strings representing code and the ints representing tab
            stops. If the initial tab stop is not specified, it is implicitly zero.
            Optionally, the comment parameter sets what comments are appended to the
            end of the line."""
            if not args:
                self._setline([0, ""])
            elif isinstance(args[0], int):
                self._setline(list(args))
            else:
                self._setline([0] + list(args))
            self.comm = comment
        
        def append(self, *args):
            """Appends code to the line. Same argument list format as __init__."""
            args = list(args)
            if not args:
                pass
            elif isinstance(args[0], str):
                self._setline(self.line[:-1] + [self.line[-1] + args[0]] + args[1:])
            else:
                self._setline(self.line + self.args)
        
        def prefix(self, *args):
            """Prefixes code to the line. Same argument list format as __init__."""
            args = list(args)
            if not args:
                pass
            elif isinstance(args[0], str):
                self._setline(self.line[:1] + args[:-1] + [args[-1] + self.line[1]] + self.line[2:])
            else:
                self._setline(self.args + self.line)
        
        def comment(self, comment):
            """Sets the comment string."""
            self.comm = comment
        
        def _setline(self, line):
            if len(line) % 2 != 0:
                raise ValueError()
            it = iter(line)
            for tab in it:
                code = next(it)
                if not isinstance(tab, int):
                    raise ValueError()
                if not isinstance(code, str):
                    raise ValueError()
            self.line = line
        
        def indent(self):
            """Increases indentation."""
            self.line[0] += 2
        
        def dedent(self):
            """Decreases indentation."""
            if self.line[0] <= 0:
                raise ValueError("Cannot set indentation to less than zero.")
            self.line[0] -= 2
        
        def trimsep(self):
            """Trims the final comma or semicolon from this line of code. Useful for
            correctly terminatng port and generic lists."""
            if self.line[-1] and self.line[-1][-1] in ",;":
                self.line[-1] = self.line[-1][:-1]
        
        def __bool__(self):
            """Returns whether this line contains code (comments not included)."""
            it = iter(self.line)
            for tab in it:
                code = next(it)
                if code.strip():
                    return True
            return False
        
        __nonzero__ = __bool__
        
        def __str__(self):
            """Pretty-prints this line."""
            l = ""
            it = iter(self.line)
            for tab in it:
                code = next(it)
                l += " " * (tab - len(l)) + code
            
            if self.comm is not None:
                if l.strip():
                    l += " "
                comment_indent = len(l)
                comment = textwrap.wrap(self.comm, max(80 - 3 - comment_indent, 20))
                
                l += "-- " + ("\n" + " " * comment_indent + "-- ").join(comment)
            
            l += "\n"
            return l
        
        def copy(self):
            """Returns a copy of this line."""
            return Line(*self.line, comment=self.comm)
    
    def __init__(self):
        """Constructs an empty block of VHDL code."""
        self.lines = []
    
    def __iadd__(self, x):
        """Appends blocks of VHDL code together. WARNING: Lines.Line objects
        should not be reused, or there will be unexpected behavior."""
        if isinstance(x, Lines):
            self.lines.extend(x.lines)
        elif isinstance(x, Lines.Line):
            self.lines.append(x)
        else:
            raise TypeError()
        return self
    
    def __add__(self, x):
        """Appends blocks of VHDL code together. WARNING: Lines.Line objects
        should not be reused, or there will be unexpected behavior."""
        ret = Lines()
        if isinstance(x, Lines):
            ret.lines = self.lines + x.lines
        elif isinstance(x, Lines.Line):
            ret.lines = self.lines + [x]
        else:
            raise TypeError()
        return ret
    
    def __radd__(self, x):
        """Appends blocks of VHDL code together. WARNING: Lines.Line objects
        should not be reused, or there will be unexpected behavior."""
        ret = Lines()
        if isinstance(x, Lines):
            ret.lines = x.lines + self.lines
        elif isinstance(x, Lines.Line):
            ret.lines = [x] + self.lines
        else:
            raise TypeError()
        return ret
    
    def __bool__(self):
        """Whether any line contains code."""
        return any(self.lines)
    
    __nonzero__ = __bool__
    
    def indent(self):
        """Increases indentation."""
        for line in self.lines:
            line.indent()
        return self
    
    def dedent(self):
        """Decreases indentation."""
        for line in self.lines:
            line.dedent()
        return self
    
    def trimsep(self):
        """Trims the final comma or semicolon from this line of code. Useful for
        correctly terminatng port and generic lists."""
        for line in reversed(self.lines):
            if line:
                line.trimsep()
                return self
        return self
    
    def prefix(self, text):
        """Prefixes code to the first line. Same argument list format as
        Lines.Line.__init__."""
        if not self.lines:
            self.lines.append(Line(*args))
        else:
            self.lines[0].prefix(*args)
        
    def append(self, *args):
        """Appends code to the last line. Same argument list format as
        Lines.Line.__init__."""
        if not self.lines:
            self.lines.append(Line(*args))
        else:
            self.lines[-1].append(*args)
        
    def __str__(self):
        """Pretty-prints this block of code."""
        return "".join(map(str, self.lines))

    def copy(self):
        """Returns a copy of these lines."""
        l = Lines()
        for line in self.lines:
            l += line.copy()
        return l


def Line(*args, **kwargs):
    """Constructs a VHDL line. See Lines.Line.__init__ for argument info."""
    return Lines() + Lines.Line(*args, **kwargs)


def gen_template(template, **kwargs):
    template = template.format(**kwargs)
    lines = []
    for line in template.split('\n'):
        line = line.split('@')
        if len(line) == 1:
            line = line[0]
        elif len(line) == 2:
            insert = kwargs[line[1]]
            if isinstance(insert, Lines):
                for _ in range(len(line[0]) // 2):
                    insert.indent()
                line = str(insert)
            else:
                line = '\n'.join([line[0] + l for l in str(insert).split('\n')])
        else:
            raise ValueError("Multiple @ on a single line")
        lines.append(line.rstrip())
    return '\n'.join(lines)
