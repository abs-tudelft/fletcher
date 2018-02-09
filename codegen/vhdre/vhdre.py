#!/usr/bin/env python3

__license__ = """
MIT License

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
"""

__version__ = "0.2"

r"""
vhdre.py 

Generates a VHDL entity that matches one or more (simple) regular expressions
against a UTF-8 bytestream.

Dependencies:
 - Python 3
 - funcparserlib

Regular expression syntax support:
 - x -> match x exactly
 - x* -> match x zero or more times
 - x+ -> match x one or more times
 - x? -> match x zero or one times
 - xy -> match x followed by y
 - x|y -> match x or y
 - (x) -> parentheses are for disambiguation only (there are no capture groups)
 - [x] -> character class
 - [^x] -> inverted character class

Note that a lot of the more advanced regex features are not supported because
they require backtracking. This engine specifically can never do that, because
it is based on a NFAE.

Character classes:
 - [ab] -> match either a or b
 - [a-z] -> match anything in the a-z code point range (inclusive)

Escape sequences:
 - \xHH     -> HH = 2-digit hexadecimal code point
 - \uHHHHHH -> HHHHHH = 6-digit hexadecimal code point
 - \d       -> [0-9]
 - \w       -> [0-9a-zA-Z_]
 - \s       -> [ \a\b\t\n\v\f\r]
 - \a\b\t\n\v\f\r -> the usual control character escape sequences
 - anything else matches the character behind the \ literally

Reserved characters (these must be escaped):
 - outside character classes: [\^$.|?*+()
 - inside character classes: ]-

The matcher does regex *matching*. That is, the given string must match the
regular expression exactly, as if it is surrounded by a ^ and a $. To do
searching instead, prefix and/or append /.*/.

The matcher is only designed to return a yes/no response. It cannot track
capture groups. It is designed to do extremely fast yes/no pattern matching to
merely "find a needle in a haystack" in applications such as big data or deep
packet inspection. If you need more information in case of a "yes" response,
have a processor do that computation for you, and only use this unit for
preprocessing.

Hardware interface:
 - rising-edge clk and synchronous, active-high reset for synchronization.
 - UTF-8 input stream (using valid-only handshaking) with the UTF-8 bytes and a
   "last" flag to indicate the last byte in a string.
 - output stream (also using valid-only handshaking) with a match flag for each
   regex and a UTF-8 decoding error flag. One transfer is generated for every
   string/"last" transfer on the input stream.

To interface this design in a streaming system that uses valid/ready signalling
(like AXI4), tie the output of this unit to a FIFO and signal not ready to the
UTF-8 source whenever there are less than 5 entries available in the FIFO (this
is the pipeline depth). The input valid signal should then be tied to AXI4
valid and ready, so it only strobes when the incoming transfer is actually
acknowledged.

The UTF-8 decoding error detector may give false negatives (i.e. be fine with
an input stream that isn't valid UTF-8) for streams with the following
problems:
 - usage of reserved code points 0x10FFFF to 0x13FFFF
 - usage of overlong sequences which are not apparent from the first byte
All other problems should be detected properly.

The pattern matcher still "works" in the presence of errors. Overlong sequences
are interpreted as if they weren't overlong (i.e. the code point is consumed
anyway). All other errors cause the erroneous byte/sequence to be ignored.
"""

from funcparserlib.parser import some, many, skip, finished, maybe, with_forward_decls
import string

__all__ = ["CharSet", "Star", "Plus", "Maybe", "Concatenate", "Alternate",
           "regex_parse", "NFAEState", "NFAE", "regex_to_nfae", "RegexMatcher"]


#------------------------------------------------------------------------------
# Regex AST classes
#------------------------------------------------------------------------------

class CharSet(tuple):
    """Represents a set of characters as a list of code point ranges (which is
    significantly more efficient than an actual set, considering the amount of
    Unicode code points."""
    
    # Number of possible code points.
    CHAR_COUNT = 1<<21
    
    def __new__(cls, a=()):
        a = sorted(a)
        for x in a:
            if not isinstance(x, tuple):
                raise TypeError()
            if len(x) != 2:
                raise ValueError()
            for y in x:
                if not isinstance(y, int):
                    raise TypeError()
            if x[1] <= x[0]:
                raise ValueError()
        
        return super(CharSet, cls).__new__(cls, a)
    
    @classmethod
    def from_str(cls, s):
        return cls([(ord(c), ord(c)+1) for c in set(s)])
    
    def minimize(self):
        ranges = []
        for start, stop in self:
            if not ranges:
                ranges.append((start, stop))
                continue
            
            prevstart, prevstop = ranges[-1]
            
            # If the previous range and the current range overlap or touch,
            # combine them.
            if prevstop >= start:
                ranges[-1] = (prevstart, max(prevstop, stop))
                continue
            
            # Need a new range.
            ranges.append((start, stop))
        
        return self.__class__(ranges)
    
    def __contains__(self, a):
        if isinstance(a, str):
            a = ord(a)
        for start, stop in self:
            if a >= start and a < stop:
                return True
        return False
    
    def __add__(self, a):
        if isinstance(a, CharSet):
            return self.__class__(tuple.__add__(self, a))
        elif isinstance(a, tuple):
            return self.__class__(tuple.__add__(self, (a,)))
        elif isinstance(a, int):
            return self.__class__(tuple.__add__(self, ((a, a+1),)))
        elif isinstance(a, str):
            return self + self.__class__.from_str(a)
        else:
            raise TypeError()
    
    def __sub__(self, a):
        if isinstance(a, CharSet):
            to_subtract = a.minimize()
        elif isinstance(a, tuple):
            to_subtract = [a]
        elif isinstance(a, int):
            to_subtract = [(a, a+1)]
        elif isinstance(a, str):
            to_subtract = [(a, a+1)]
        elif isinstance(a, str):
            return self - self.__class__.from_str(a)
        else:
            raise TypeError()
        
        ranges = list(self)
        for sub_start, sub_stop in to_subtract:
            new_ranges = []
            for start, stop in ranges:
                if stop <= sub_start:
                    new_ranges.append((start, stop))
                    continue
                if start > sub_stop:
                    new_ranges.append((start, stop))
                    continue
                if start < sub_start:
                    new_ranges.append((start, sub_start))
                if stop > sub_stop:
                    new_ranges.append((sub_stop, stop))
            ranges = new_ranges
        return self.__class__(ranges)
    
    def __neg__(self):
        return self.__class__([(0, self.CHAR_COUNT)]) - self
    
    def __repr__(self):
        return self.__class__.__name__ + tuple.__str__(self)

    def __str__(self):
        
        # Special cases:
        if len(self) == 1 and self[0][0] == 0 and self[0][1] == self.CHAR_COUNT:
            return "."
        if len(self) == 0:
            return "[]"
        if self[-1][1] == self.CHAR_COUNT:
            charset = -self
            negate = True
        else:
            charset = self
            negate = False
        
        def printable(cp):
            if cp == 0x0A:
                return "\\n"
            elif cp == 0x0D:
                return "\\r"
            elif cp >= 32 and cp <= 126:
                c = chr(cp)
                if c in "[]\^$.|?*+()-":
                    return "\\" + c
                else:
                    return c
            elif cp < 256:
                return "\\x%02X" % cp
            else:
                return "\\u%06X" % cp
        
        s = ""
        cnt = 0
        for start, stop in charset:
            cnt += stop-start
            if stop-start <= 2:
                for cp in range(start, stop):
                    s += printable(cp)
            else:
                s += printable(start) + "-" + printable(stop-1)
        
        if negate:
            return "[^%s]" % s
        elif cnt == 1:
            return s
        else:
            return "[%s]" % s


class Star(object):
    """Represents a star quantifier."""
    
    def __init__(self, child):
        super().__init__()
        self.child = child
    
    def __str__(self):
        return "Star(%s)" % (self.child,)


class Plus(object):
    """Represents a plus quantifier."""
    
    def __init__(self, child):
        super().__init__()
        self.child = child
    
    def __str__(self):
        return "Plus(%s)" % (self.child,)


class Maybe(object):
    """Represents a maybe (question mark) quantifier."""
    
    def __init__(self, child):
        super().__init__()
        self.child = child
    
    def __str__(self):
        return "Maybe(%s)" % (self.child,)


class Concatenate(object):
    """Represents a concatenation."""
    
    def __init__(self, *children):
        super().__init__()
        self.children = children
    
    def __str__(self):
        return "Concatenate(%s)" % ", ".join(map(str, self.children))


class Alternate(object):
    """Represents an alternation."""
    
    def __init__(self, *children):
        super().__init__()
        self.children = children
    
    def __str__(self):
        return "Alternate(%s)" % ", ".join(map(str, self.children))


#------------------------------------------------------------------------------
# Regex tokenizer
#------------------------------------------------------------------------------

class Token(object):
    """Represents a regex token, either a character or an escape sequence."""
    
    def __init__(self, value, regex, pos):
        self.value = value
        self.regex = regex
        self.pos = pos
    
    def __str__(self):
        return "\n%s\n%s%s\n" % (self.regex, " "*self.pos, "^"*len(self.value))
    
    def __repr__(self):
        return "Token(%r)" % self.value


def regex_tokenize(regex):
    """Tokenizes a regex."""
    
    x = iter(enumerate(regex))
    try:
        while True:
            
            try:
                i, c = next(x)
            except StopIteration:
                return
            
            if c != "\\":
                yield Token(c, regex, i)
                continue
            
            _, c = next(x)
            
            # Handle \x and \u, which map to ASCII/Unicode code points in hex
            # notation, requiring 2 and 6 hex digits respectively.
            if c in "xu":
                count = 2 if c == "x" else 6
                for _ in range(count):
                    _, c2 = next(x)
                    c += c2
            
            yield Token("\\" + c, regex, i)
        
    except StopIteration:
        raise ValueError("Incomplete escape sequence at end of regex")


#------------------------------------------------------------------------------
# Regex parser
#------------------------------------------------------------------------------

def gen_regex_parser():
    """Generates a regex parser using funcparserlib."""
    
    def charset_from_toks(*toks, negate=False):
        """Constructs a CharSet object from parsed regex tokens. toks is the list
        of tokens representing characters that are matched, negate specifies
        whether the matcher should be negated or not."""
        
        # Convert:
        #  - shorthands to lists of character ranges
        #  - literals and escape sequences to their respective code points
        #  - leave "-" characters intact
        new_toks = []
        for tok in toks:
            c = tok.value
            if c[0] == "\\":
                if c[1] in "xu":
                    try:
                        r = int(c[2:], 16)
                    except:
                        raise ValueError("Invalid \\x or \\u escape sequence:%s" % tok)
                elif c[1] == "d":
                    r = [(ord("0"), ord("9")+1)]
                elif c[1] == "w":
                    r = [(ord("a"), ord("z")+1),
                            (ord("A"), ord("Z")+1),
                            (ord("_"), ord("_")+1),
                            (ord("0"), ord("9")+1)]
                elif c[1] == "s":
                    r = [(0x09, 0x0D+1), # \t\n\v\f\r
                            (ord(" "), ord(" ")+1)]
                else:
                    r = {
                        "a": ord("\a"),
                        "b": ord("\b"),
                        "t": ord("\t"),
                        "n": ord("\n"),
                        "v": ord("\v"),
                        "f": ord("\f"),
                        "r": ord("\r")
                    }.get(c[1], ord(c[1]))
            elif c == "-":
                r = tok
            else:
                r = ord(c)
            new_toks.append(r)
        toks = new_toks
        
        # Create a single list of character ranges out of the literals and
        # range expressions we currently have.
        ranges = []
        tok_iter = iter(enumerate(toks))
        for i, tok in tok_iter:
            
            # Handle range expressions.
            if i < len(toks)-2 and isinstance(toks[i+1], Token) and toks[i+1].value == "-":
                _, tok_dash = next(tok_iter)
                _, tok2 = next(tok_iter)
                
                def to_cp(tok):
                    if isinstance(tok, Token):
                        return ord(tok.value)
                    elif isinstance(tok, int):
                        return tok
                    raise ValueError("Error parsing range:%s" % tok_dash)
                
                start = to_cp(tok)
                stop = to_cp(tok2)+1
                
                if start >= stop:
                    raise ValueError("Error parsing range, reverse range order/null range:%s" % tok_dash)
                
                ranges.append((start, stop))
            
            # Handle previously converted shorthands.
            elif isinstance(tok, list):
                ranges.extend(tok)
            
            # Handle dash characters not part of a range.
            elif isinstance(tok, Token):
                cp = ord(tok.value)
                ranges.append((cp, cp+1))
            
            # Handle literal characters not part of a range.
            elif isinstance(tok, int):
                ranges.append((tok, tok+1))
            
            else:
                raise Exception()
        
        # Construct the CharSet object and minimize it.
        charset = CharSet(ranges).minimize()
        
        # Negate if necessary.
        if negate:
            charset = -charset
        
        return charset

    def handle_literal(tok):
        """Creates a CharSet from a literal token."""
        return charset_from_toks(tok)

    def handle_dot(tok):
        """Creates a CharSet from a dot token (one that matches everything)."""
        return -CharSet([])

    def handle_charclass(toks):
        """Creates a CharSet from a regular expression character class."""
        negate = toks[0] is not None
        toks = toks[1]
        return charset_from_toks(*toks, negate=negate)

    def handle_quantify(toks):
        """Handles regex quantification."""
        
        # No quantifier:
        if toks[1] is None:
            return toks[0]
        
        # *+? quantifiers:
        elif isinstance(toks[1], Token):
            if toks[1].value == "*":
                return Star(toks[0])
            elif toks[1].value == "+":
                return Plus(toks[0])
            elif toks[1].value == "?":
                return Maybe(toks[0])
        
        # {} quantifiers are not yet supported:
        else:
            raise NotImplemented()

    def handle_concatenate(toks):
        """Handles regex concatenation."""
        
        # No concatenation:
        if len(toks[1]) == 0:
            return toks[0]
        
        # With concatenation:
        else:
            return Concatenate(toks[0], *toks[1])

    def handle_alternate(toks):
        """Handles regex alternation."""
        
        # No alternation:
        if len(toks[1]) == 0:
            return toks[0]
        
        # With alternation:
        else:
            return Alternate(toks[0], *toks[1])
    
    def a(value):
        return some(lambda tok: tok.value == value)
    
    def not_a(value):
        return some(lambda tok: tok.value != value)
    
    # Literal character.
    literal = some(lambda tok: tok.value not in "[\^$.|?*+()") >> handle_literal
    
    # Dot: match everything.
    dot = a(".") >> handle_dot
    
    # [...] character class.
    charclass = (some(lambda x: True) + many(not_a("]"))) >> (lambda x: [x[0]] + x[1])
    charclass = (skip(a("[")) + maybe(a("^")) + charclass + skip(a("]"))) >> handle_charclass
    
    # (...) grouping parentheses.
    @with_forward_decls
    def group():
        return (a("(") + alternated + a(")")) >> (lambda x: x[1])
    
    # Represents a matcher for a single character or a group.
    single = literal | dot | charclass | group
    
    # A*, A+, A?, etc. quantifiers.
    quantifier = a("*") | a("+") | a("?")
    quantified = (single + maybe(quantifier)) >> handle_quantify
    
    # Concatenation.
    concatenated = (quantified + many(quantified)) >> handle_concatenate
    
    # Alternation.
    alternated = (concatenated + many(skip(a("|")) + concatenated)) >> handle_alternate
    
    # Make sure we reach the end of the regex.
    regex = alternated + skip(finished)
    
    return regex


# Generate the parser.
regex_parser = gen_regex_parser()


def regex_parse(regex):
    """Parses a regex into a tree of Alternate, Concatenate, Star, Plus, Maybe,
    and CharSet objects."""
    return regex_parser.parse(list(regex_tokenize(regex)))


#------------------------------------------------------------------------------
# NFAE classes
#------------------------------------------------------------------------------

class NFAEState(object):
    """Represents a state of an NFA with epsilon moves."""
    
    def __init__(self):
        super().__init__()
        
        # Real _transition table. Mapping from an NFAEState to the CharSet that
        # triggers the _transition.
        self.real = {}
        
        # Epsilon _transition set of NFAEStates.
        self.epsilon = set()
    
    def add_transition(self, state, action=None):
        """Adds a _transition to the given state using the given action. The
        action must be a CharSet if specified. If not specified or None, an
        epsilon _transition is added."""
        
        # Handle epsilon transitions.
        if action is None:
            self.epsilon.add(state)
            return
        
        # If the action is empty, don't do anything.
        if not action:
            return
        
        # If there is no _transition to this state yet, add it.
        if state not in self.real:
            self.real[state] = action
        
        # Otherwise, make the _transition condition the union of the
        # existing and the new CharSet.
        else:
            self.real[state] = (self.real[state] + action).minimize()
    
    def trace_epsilon(self):
        """Returns all the states reachable through epsilon moves from this
        state."""
        pend = [self]
        reachable = set()
        while pend:
            state, *pend = pend
            if state in reachable:
                continue
            reachable.add(state)
            pend.extend(state.epsilon)
        
        return reachable


class NFAE(object):
    """Represents an NFA with epsilon moves."""

    def __init__(self):
        super().__init__()
        
        # Set of initial states.
        self.initial = set()
        
        # Set of final/terminal states.
        self.final = set()
    
    def add_initial(self, state):
        """Marks the given state as an initial state for this NFAE. state may
        be a singular State or an iterable of States."""
        if isinstance(state, NFAEState):
            states = [state]
        else:
            states = state
        for s in states:
            self.initial.add(s)
        return state
    
    def add_final(self, state):
        """Marks the given state as a final state for this NFAE. state may
        be a singular State or an iterable of States."""
        if isinstance(state, NFAEState):
            states = [state]
        else:
            states = state
        for s in states:
            self.final.add(s)
        return state
    
    def get_states(self):
        """Returns the set of all states currently reachable from the initial
        states of this NFAE."""
        states = set()
        pend = list(self.initial)
        while pend:
            state, *pend = pend
            if state in states:
                continue
            states.add(state)
            pend.extend(state.real.keys())
            pend.extend(state.epsilon)
        return states
    
    def strip_epsilon(self):
        """Strips the epsilon moves from this NFAE. Also reduces the number of
        initial states to 1."""
        
        # Propagate initial states along epsilon paths.
        for state in list(self.initial):
            self.initial.update(state.trace_epsilon())
        
        # Get a set of all states.
        states = self.get_states()
        
        # Propagate final states along epsilon paths.
        for state in states:
            for reachable in state.trace_epsilon():
                if reachable in self.final:
                    self.final.add(state)
        
        # Propagate transitions along epsilon paths.
        for state in states:
            
            # Iterate over the transitions from this state.
            for to_state, action in list(state.real.items()):
                
                # Add the _transition to all states reachable by this one
                # through epsilon moves.
                _transition(state, to_state.trace_epsilon(), action)
        
        # All epsilon transitions should now be redundant, so we can remove
        # them.
        for state in states:
            state.epsilon.clear()
    
    def reverse(self):
        """Reverses the direction of all the transitions in this automaton."""
        
        # Get a set of all reachable states.
        states = self.get_states()
        
        # Make a new State for each.
        new_states = {state: NFAEState() for state in states}
        
        # Add the reverse transitions between all the new states.
        for from_state in states:
            for to_state, action in from_state.real.items():
                _transition(new_states[to_state], new_states[from_state], action)
            
            for to_state in from_state.epsilon:
                _transition(new_states[to_state], new_states[from_state])
        
        # Create the new set of initial and final states.
        new_initial = {new_states[state] for state in self.final if state in new_states}
        new_final = {new_states[state] for state in self.initial if state in new_states}
        
        # Save the new initial and final state sets.
        self.initial = new_initial
        self.final = new_final
    
    def reduce_outgoing(self):
        """Collapses states with identical outgoing transitions into one.
        Returns whether any states were collapsed."""
        
        any_collapsed = False
        
        # Get a set of all reachable states.
        states = self.get_states()
        
        while True:
            
            # Figure out which states are equivalent, and make a "change order"
            # to replace these states with their equivalents. key_map maps from
            # a key that identifies equivalent states to one of the equivalent
            # states, replace maps from redundant states to their (arbitrarily)
            # chosen equivalent state.
            key_map = {}
            replace = {}
            
            for state in list(states):
                
                key = (state in self.final, frozenset(state.real.items()), frozenset(state.epsilon))
                
                equiv_state = key_map.get(key, None)
                
                if equiv_state is None:
                    key_map[key] = state
                
                else:
                    replace[state] = equiv_state
                    states.discard(state)
            
            # If we didn't find any equivalent states, we're done.
            if not replace:
                return any_collapsed
            any_collapsed = True
            
            # Complete the change order.
            for from_state in states:
                
                for to_state, action in list(from_state.real.items()):
                    
                    new_to_state = replace.get(to_state, None)
                    
                    if new_to_state is not None:
                        _transition(from_state, new_to_state, action)
                        del from_state.real[to_state]
                
                for to_state in list(from_state.epsilon):
                    
                    new_to_state = replace.get(to_state, None)
                    
                    if new_to_state is not None:
                        _transition(from_state, new_to_state)
                        from_state.epsilon.discard(to_state)
    
    def minimize(self):
        """Tries to remove/collapse redundant states to decrease the size of
        the NFAE."""
        
        cont = True
        while cont:
            cont = self.reduce_outgoing()
            self.reverse()
            cont |= self.reduce_outgoing()
            self.reverse()
        
        # At this point there might still be a redundant initial+final state
        # without incoming or outgoing transitions if the regex matches an
        # empty string. This happens when there is another initial+final state
        # with both incoming and outgoing transitions. The NDFA is always in
        # this second state when it is in the first state (but not vice-versa),
        # making the first state redundant.
        nontrivial_initial_final = False
        for state in self.initial:
            if state not in self.final:
                continue
            if state.real or state.epsilon:
                nontrivial_initial_final = True
                break
        for state in list(self.initial):
            if state not in self.final:
                continue
            if state.real or state.epsilon:
                continue
            self.initial.remove(state)
    
    def graphviz(self):
        
        # Create unique IDs for all states.
        ids = {}
        states = []
        pend = list(self.initial)
        while pend:
            state, *pend = pend
            if state in ids:
                continue
            ids[state] = len(states)
            states.append(state)
            pend.extend(state.real.keys())
            pend.extend(state.epsilon)
        
        # Dump the graphviz representation.
        lines = ["digraph G {"]
        for id, state in enumerate(states):
            
            # Dump transitions.
            for target_state, charset in state.real.items():
                lines.append('    %d -> %d [label="%s"];' % (id, ids[target_state], str(charset)))
            
            for target_state in state.epsilon:
                lines.append("    %d -> %d [style=dotted];" % (id, ids[target_state]))
            
            # Dump state style.
            params = []
            
            if state in self.initial:
                params.append("shape=box")
            
            if state in self.final:
                params.append("peripheries=2")
            
            if params:
                lines.append("    %d [%s];" % (id, ",".join(params)))
        
        lines.append("}")
        
        return "\n".join(lines)


#------------------------------------------------------------------------------
# Regex NFAE builders
#------------------------------------------------------------------------------

def _transition(a, b, action=None):
    """Creates transitions from NFAEStates a to b. The action must be a CharSet
    if specified. If not specified or None, an epsilon _transition is added. a
    and b may be iterables of NFAEStates or singular NFAEStates."""
    if isinstance(a, NFAEState):
        a = [a]
    if isinstance(b, NFAEState):
        b = [b]
    for x in a:
        for y in b:
            x.add_transition(y, action)


def regex_to_nfae(node):
    """Builds a NFAE from a regex AST node."""
    
    n = NFAE()
    
    if isinstance(node, CharSet):
        
        a = n.add_initial(NFAEState())
        b = n.add_final(NFAEState())
        
        _transition(a, b, node)
    
    elif isinstance(node, Star):
        
        c = regex_to_nfae(node.child)
        _transition(c.final, c.initial)
        n.add_final(c.final)
        
        # It is not allowed to re-enter an initial state at this stage. That
        # would cause problems for regexs like a*|b*, making it match [ab]*
        # instead. Therefore, we need a dummy initial state. This state will be
        # optimized out later if it doesn't change the automaton.
        a = NFAEState()
        _transition(a, c.final)
        n.add_initial(a)
        
    elif isinstance(node, Plus):
        
        c = regex_to_nfae(node.child)
        _transition(c.final, c.initial)
        n.add_final(c.final)
        
        # It is not allowed to re-enter an initial state at this stage. That
        # would cause problems for regexs like a+|b+, making it match [ab]+
        # instead. Therefore, we need a dummy initial state. This state will be
        # optimized out later if it doesn't change the automaton.
        a = NFAEState()
        _transition(a, c.initial)
        n.add_initial(a)
        
    elif isinstance(node, Maybe):
        
        c = regex_to_nfae(node.child)
        
        _transition(c.initial, c.final)
    
        n.add_initial(c.initial)
        n.add_final(c.final)
        
    elif isinstance(node, Concatenate):
        
        children = [regex_to_nfae(child) for child in node.children]
        
        n.add_initial(children[0].initial)
        
        for i in range(len(children)-1):
            _transition(children[i].final, children[i+1].initial)
        
        n.add_final(children[-1].final)
    
    elif isinstance(node, Alternate):
        
        children = [regex_to_nfae(child) for child in node.children]
        
        for child in children:
            n.add_initial(child.initial)
            n.add_final(child.final)
    
    else:
        raise NotImplemented()
    
    return n


#------------------------------------------------------------------------------
# VHDL entity template
#------------------------------------------------------------------------------

TEMPLATE = """
{header}

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity {name} is
  generic (
    
    ----------------------------------------------------------------------------
    -- Configuration
    ----------------------------------------------------------------------------
    -- Number of bytes that can be handled per cycle.
    BPC                         : positive := 1;
    
    -- Whether or not the system is big endian. This determines in which order
    -- the incoming bytes are processed.
    BIG_ENDIAN                  : boolean := false;
    
    -- Pipeline configuration flags. Disabling stage registers reduces register
    -- usage but *may* come at the cost of performance.
    INPUT_REG_ENABLE            : boolean := false;
    S12_REG_ENABLE              : boolean := true;
    S23_REG_ENABLE              : boolean := true;
    S34_REG_ENABLE              : boolean := true;
    S45_REG_ENABLE              : boolean := true
    
  );
  port (
    
    ----------------------------------------------------------------------------
    -- Clock input
    ----------------------------------------------------------------------------
    -- `clk` is rising-edge sensitive.
    clk                         : in  std_logic;
    
    -- `reset` is an active-high synchronous reset, `aresetn` is an active-low
    -- asynchronous reset, and `clken` is an active-high global clock enable
    -- signal. The resets override the clock enable signal. If your system has
    -- no need for one or more of these signals, simply do not connect them.
    reset                       : in  std_logic := '0';
    aresetn                     : in  std_logic := '1';
    clken                       : in  std_logic := '1';
    
    ----------------------------------------------------------------------------
    -- Incoming UTF-8 bytestream
    ----------------------------------------------------------------------------
    -- AXI4-style handshake signals. If `out_ready` is not used, `in_ready` can
    -- be ignored because it will always be high.
    in_valid                    : in  std_logic := '1';
    in_ready                    : out std_logic;
    
    -- Incoming byte(s). Each byte has its own validity flag (`in_mask`). This
    -- is independent of the "last" flags, allowing empty strings to be
    -- encoded. Bytes are interpreted LSB-first by default, or MSB-first if the
    -- `BIG_ENDIAN` generic is set.
    in_mask                     : in  std_logic_vector(BPC-1 downto 0) := (others => '1');
    in_data                     : in  std_logic_vector(BPC*8-1 downto 0);
    
    -- "Last-byte-in-string" marker signal for systems which support at most
    -- one *string* per cycle.
    in_last                     : in  std_logic := '0';
    
    -- ^
    -- | Use exactly one of these!
    -- v
    
    -- "Last-byte-in-string" marker signal for systems which support multiple
    -- *strings* per cycle. Each bit corresponds to a byte in `in_mask` and
    -- `in_data`.
    in_xlast                    : in  std_logic_vector(BPC-1 downto 0) := (others => '0');
    
    ----------------------------------------------------------------------------
    -- Outgoing match stream
    ----------------------------------------------------------------------------
    -- AXI4-style handshake signals. `out_ready` can be left unconnected if the
    -- stream sink can never block (for instance a simple match counter), in
    -- which case the input stream can never block either.
    out_valid                   : out std_logic;
    out_ready                   : in  std_logic := '1';
    
    -- Outgoing match stream for one-string-per-cycle systems. match indicates
    -- which of the following regexs matched:
    {regex_comments:4}
    -- error indicates that a UTF-8 decoding error occured. Only the following
    -- decode errors are detected:
    --  - multi-byte sequence interrupted by last flag or a new sequence
    --    (interrupted sequence is ignored)
    --  - unexpected continuation byte (byte is ignored)
    --  - illegal bytes 0xC0..0xC1, 0xF6..0xF8 (parsed as if they were legal
    --    2-byte/4-byte start markers; for the latter three this means that
    --    oh3 will be "00000", which means the character won't match anything)
    --  - illegal bytes 0xF8..0xFF (ignored)
    -- Thus, the following decode errors pass silently:
    --  - code points 0x10FFFF to 0x13FFFF (these are out of range, at least
    --    at the time of writing)
    --  - overlong sequences which are not apparent from the first byte
    out_match                   : out std_logic_vector({regex_count_m1} downto 0);
    out_error                   : out std_logic;
    
    -- Outgoing match stream for multiple-string-per-cycle systems.
    out_xmask                   : out std_logic_vector(BPC-1 downto 0);
    out_xmatch                  : out std_logic_vector(BPC*{regex_count}-1 downto 0);
    out_xerror                  : out std_logic_vector(BPC-1 downto 0)
    
  );
end {name};

architecture Behavioral of {name} is
  
  -- This constant resolves to 'U' in simulation and '0' in synthesis. It's
  -- used as a value for stuff that's supposed to be invalid.
  constant INVALID              : std_logic := '0'
  -- pragma translate_off
  or 'U'
  -- pragma translate_on
  ;
  
  -- Number of regular expressions matched by this unit.
  constant NUM_RE               : natural := {regex_count};
  
  -- NOTE: in the records below, the unusual indentation implies a "validity"
  -- hierarchy; indented signals are valid iff the signal before the indented
  -- block is high and is itself valid.
  
  ------------------------------------------------------------------------------
  -- Stage 1 input record
  ------------------------------------------------------------------------------
  type si1_type is record
    
    -- Bytestream. `valid` is an active-high strobe signal indicating the
    -- validity of `data`.
    valid                       : std_logic;
      data                      : std_logic_vector(7 downto 0);
    
    -- Active-high strobe signal indicating:
    --  - `valid` is high -> the current byte is the last byte in the string.
    --  - `valid` is low -> the previous byte (if any) is the last in the
    --    string.
    last                        : std_logic;
    
  end record;
  
  type si1_array is array (natural range <>) of si1_type;
  
  constant SI1_RESET            : si1_type := (
    valid   => '0',
    data    => (others => INVALID),
    last    => '0'
  );
  
  ------------------------------------------------------------------------------
  -- Stage 1 to 2 record
  ------------------------------------------------------------------------------
  type s12_type is record
    
    -- Stream of bytes, decoded into signals that are easier to process by the
    -- next stage. `valid` is an active-high strobe signal indicating its
    -- validity.
    valid                       : std_logic;
    
      -- Active-high signal indicating that the received byte is a start byte.
      start                     : std_logic;
      
        -- The amount of continuation bytes expected, valid if `start` is high.
        follow                  : std_logic_vector(1 downto 0);
      
      -- Indicates that the received byte is reserved/illegal (0xF8..0xFF).
      illegal                   : std_logic;
      
      -- Copy of bit 6 of the received byte.
      bit6                      : std_logic;
      
      -- 63-bit thermometer code signal for bit 5..0 of the received byte.
      therm                     : std_logic_vector(62 downto 0);
    
    -- Copy of s01.last.
    last                        : std_logic;
    
  end record;
  
  type s12_array is array (natural range <>) of s12_type;
  
  constant S12_RESET            : s12_type := (
    valid   => '0',
    start   => INVALID,
    follow  => (others => INVALID),
    illegal => INVALID,
    bit6    => INVALID,
    therm   => (others => INVALID),
    last    => '0'
  );
  
  ------------------------------------------------------------------------------
  -- Stage 1 computation
  ------------------------------------------------------------------------------
  -- Preprocesses the incoming byte stream for the sequence decoder state
  -- machine. All bits signals generated and registered by this process can be
  -- created using a single level of 6-input LUTs.
  procedure s1_proc(i: in si1_type; o: inout s12_type) is
  begin
    
    -- Figure out the byte type.
    case i.data(7 downto 4) is
      
      when X"F" =>
        -- Start of a 4-byte sequence.
        o.start   := '1';
        o.follow  := "11";
        o.illegal := i.data(3);
        
      when X"E" =>
        -- Start of a 3-byte sequence.
        o.start   := '1';
        o.follow  := "10";
        o.illegal := '0';
        
      when X"D" | X"C" =>
        -- Start of a 2-byte sequence.
        o.start   := '1';
        o.follow  := "01";
        o.illegal := '0';
        
      when X"B" | X"A" | X"9" | X"8" =>
        -- Continuation byte.
        o.start   := '0';
        o.follow  := (others => INVALID);
        o.illegal := '0';
        
      when others =>
        -- Single-byte code point.
        o.start   := '1';
        o.follow  := "00";
        o.illegal := '0';
      
    end case;
    
    -- Save bit 6. This is necessary for decoding ASCII-range characters, as
    -- bit 6 is not used in the thermometer code.
    o.bit6 := i.data(6);
    
    -- Create a thermometer encoder for bits 5..0. Thermometer encoding
    -- allows efficient range checking. For the higher-order bits, the
    -- thermometer code is converted to one-hot. This allows any code point
    -- range that does not cross a 64-CP boundary to be tested for using a
    -- single 6-input LUT later.
    for x in 62 downto 0 loop
      if unsigned(i.data(5 downto 0)) > x then
        o.therm(x) := '1';
      else
        o.therm(x) := '0';
      end if;
    end loop;
    
    -- Store the `valid` and `last` flags.
    o.valid := i.valid;
    o.last  := i.last;
    
    -- In simulation, make signals undefined when their value is meaningless.
    -- pragma translate_off
    if to_X01(o.valid) /= '1' then
      o.start   := INVALID;
      o.illegal := INVALID;
      o.bit6    := INVALID;
      o.therm   := (others => INVALID);
    end if;
    if to_X01(o.start) /= '1' then
      o.follow  := (others => INVALID);
    end if;
    -- pragma translate_on
    
  end procedure;
  
  ------------------------------------------------------------------------------
  -- Stage 2 state record
  ------------------------------------------------------------------------------
  type s2s_type is record
    
    -- FSM state. Indicates the amount of continuation bytes still expected.
    state                       : std_logic_vector(1 downto 0);
    
    -- Error flag. This is set when any kind of error is detected and cleared
    -- by the `last` flag.
    error                       : std_logic;
    
    -- 5-bit one-hot signal for bit 20..18 of the code point.
    oh3                         : std_logic_vector(4 downto 0);
    
    -- 64-bit one-hot signal for bit 17..12 of the code point.
    oh2                         : std_logic_vector(63 downto 0);
    
    -- 64-bit one-hot signal for bit 11..6 of the code point.
    oh1                         : std_logic_vector(63 downto 0);
    
  end record;
  
  type s2s_array is array (natural range <>) of s2s_type;
  
  constant S2S_RESET            : s2s_type := (
    state   => "00",
    error   => '0',
    oh3     => (others => INVALID),
    oh2     => (others => INVALID),
    oh1     => (others => INVALID)
  );
  
  ------------------------------------------------------------------------------
  -- Stage 2 to 3 record
  ------------------------------------------------------------------------------
  type s23_type is record
    
    -- Stream of code points, encoded into one-hot and thermometer codes, such
    -- that any range that doesn't cross 64-CP boundaries to be matched against
    -- using a single 5-input LUT (one bit from oh3, one bit from oh2, one bit
    -- from oh1, and two bits from th0). `valid` is an active-high strobe
    -- signal indicating validity.
    valid                       : std_logic;
    
      -- 5-bit one-hot signal for bit 20..18 of the code point.
      oh3                       : std_logic_vector(4 downto 0);
      
      -- 64-bit one-hot signal for bit 17..12 of the code point.
      oh2                       : std_logic_vector(63 downto 0);
      
      -- 64-bit one-hot signal for bit 11..6 of the code point.
      oh1                       : std_logic_vector(63 downto 0);
      
      -- 63-bit thermometer code signal for bit 5..0 of the code point.
      th0                       : std_logic_vector(62 downto 0);
    
    -- Active-high strobe signal indicating:
    --  - `valid` is high -> the current code point is the last in the string.
    --  - `valid` is low -> the previous code point (if any) is the last in the
    --    string.
    last                        : std_logic;
    
      -- Active-high error flag, valid when `last` is asserted. The following
      -- decode errors are detected:
      --  - multi-byte sequence interrupted by last flag or a new sequence
      --    (interrupted sequence is ignored)
      --  - unexpected continuation byte (byte is ignored)
      --  - illegal bytes 0xC0..0xC1, 0xF6..0xF8 (parsed as if they were legal
      --    2-byte/4-byte start markers; for the latter three this means that
      --    oh3 will be "00000", which means the character won't match
      --    anything)
      --  - illegal bytes 0xF8..0xFF (ignored)
      -- Thus, the following decode errors pass silently:
      --  - code points 0x10FFFF to 0x13FFFF (these are out of range, at least
      --    at the time of writing)
      --  - overlong sequences which are not apparent from the first byte
      error                     : std_logic;
    
  end record;
  
  type s23_array is array (natural range <>) of s23_type;
  
  constant S23_RESET            : s23_type := (
    valid   => '0',
    oh3     => (others => INVALID),
    oh2     => (others => INVALID),
    oh1     => (others => INVALID),
    th0     => (others => INVALID),
    last    => '0',
    error   => INVALID
  );
  
  ------------------------------------------------------------------------------
  -- Stage 2 computation
  ------------------------------------------------------------------------------
  -- Contains the state machine that detects and decodes multi-byte sequences.
  -- The decoded code point is represented as follows:
  --  - oh3: a 5-bit one-hot signal for bit 21..19 of the code point.
  --  - oh2: a 64-bit one-hot signal for bit 18..13 of the code point.
  --  - oh1: a 64-bit one-hot signal for bit 12..7 of the code point.
  --  - th0: a 63-bit thermometer code signal for bit 6..0 of the code point.
  -- Also contains decoding error detection.
  procedure s2_proc(i: in s12_type; s: inout s2s_type; o: inout s23_type) is
    variable oh : std_logic_vector(63 downto 0);
  begin
    
    -- Don't assert output valid unless otherwise specified by the state
    -- machine. (not all bytes result in a code point)
    o.valid := '0';
    
    -- Convert thermometer to one-hot.
    oh := (i.therm & "1") and not ("0" & i.therm);
    
    -- Handle incoming byte, if any.
    if i.valid = '1' then
      
      -- Handle illegal bytes (0xF8..0xFF).
      if i.illegal = '1' then
        
        -- Reset the state and set the error flag.
        s.state := "00";
        s.error := '1';
      
      -- Handle start bytes.
      elsif i.start = '1' then
        
        -- If we were expecting a continuation byte, set the error flag, and
        -- drop the code point we were decoding in favor of this new start
        -- byte.
        if s.state /= "00" then
          s.error := '1';
        end if;
        
        -- Different behavior based on the amount of following bytes.
        case i.follow is
          
          -- Single byte: U+0000 to U+007F (00000000 to 00000177).
          when "00" =>
            s.oh3 := "00001"; -- 00......
            s.oh2 := X"0000000000000001"; -- ..00....
            if i.bit6 = '0' then
              s.oh1 := X"0000000000000001"; -- ....00..
            else
              s.oh1 := X"0000000000000002"; -- ....01..
            end if;
            
            -- This is the complete sequence already.
            o.valid := '1';
            s.state := "00";
            
          -- Two bytes: U+0080 to U+07FF (00000200 to 00003777).
          when "01" =>
            s.oh3 := "00001"; -- 00......
            s.oh2 := X"0000000000000001"; -- ..00....
            s.oh1 := X"00000000" & oh(31 downto 0);
            s.state := "01";
            
            -- The 6 LSBs of the received byte must be between "000010" = 2
            -- and "011111" = 31. Less than 2 is an overlong sequence, more
            -- than 31 should never happen.
            if i.therm(31) = '1' or i.therm(1) = '0' then -- byte > 31 or byte <= 1
              s.error := '1';
            end if;
          
          -- Three bytes: U+0800 to U+FFFF (00004000 to 00177777).
          when "10" =>
            s.oh3 := "00001"; -- 00......
            s.oh2 := X"000000000000" & oh(47 downto 32);
            -- pragma translate_off
            s.oh1 := (others => 'U');
            -- pragma translate_on
            s.state := "10";
            
            -- The 6 LSBs of the received byte must be between "100000" = 32
            -- and "101111" = 47. Values out of that range should never
            -- happen.
            if i.therm(47) = '1' or i.therm(32) = '0' then -- byte > 47 or byte <= 32
              s.error := '1';
            end if;
            
          -- Four bytes: U+10000 to U+10FFFF (00200000 to 04177777).
          when others =>
            s.oh3 := oh(52 downto 48);
            -- pragma translate_off
            s.oh2 := (others => 'U');
            s.oh1 := (others => 'U');
            -- pragma translate_on
            s.state := "11";
            
            -- The 6 LSBs of the received byte must be between "110000" = 48
            -- and "110100" = 52. Values out of that range should never
            -- happen or are above U+10FFFF (53..55).
            if i.therm(52) = '1' or i.therm(48) = '0' then -- byte > 52 or byte <= 48
              s.error := '1';
            end if;
            
        end case;
        
      -- Handle continuation bytes.
      else
        
        -- Different behavior based on the amount of following bytes.
        case s.state is
          
          -- Idle state; not expecting any continuation byte.
          when "00" =>
            s.error := '1';
            
          -- Last byte.
          when "01" =>
            -- Sequence complete, so we don't need to do anything else (the
            -- thermometer code for the last 6 bits are always registered).
            o.valid := '1';
            s.state := "00";
          
          -- Second to last byte.
          when "10" =>
            s.oh1   := oh;
            s.state := "01";
          
          -- Third to last byte.
          when others =>
            s.oh2   := oh;
            s.state := "10";
          
        end case;
        
      end if;
      
    end if;
    
    -- Copy the code point data to the output stream.
    o.oh3   := s.oh3;
    o.oh2   := s.oh2;
    o.oh1   := s.oh1;
    o.th0   := i.therm;
    
    -- Copy the last/error stream flags to the output stream. If we're not in
    -- state 0 and we receive a `last` flag, the string was cut off in the
    -- middle of a multibyte sequence, which is also an error.
    o.last  := i.last;
    o.error := s.error or s.state(0) or s.state(1);
    
    -- If the `last` flag is set, always return to the initial state.
    if i.last = '1' then
      s := S2S_RESET;
    end if;
    
    -- In simulation, make signals undefined when their value is meaningless.
    -- pragma translate_off
    if to_X01(o.valid) /= '1' then
      o.oh3 := (others => INVALID);
      o.oh2 := (others => INVALID);
      o.oh1 := (others => INVALID);
      o.th0 := (others => INVALID);
    end if;
    if to_X01(o.last) /= '1' then
      o.error := INVALID;
    end if;
    -- pragma translate_on
    
  end procedure;
  
  ------------------------------------------------------------------------------
  -- Stage 3 to 4 record
  ------------------------------------------------------------------------------
  type s34_type is record
    
    -- Code point subrange stream. Each flag signal represents one contiguous
    -- range of code points that does not cross a 64-CP boundary.
    valid                       : std_logic;
      {s34_entries:6}
    
    -- Copy of s23.last/error.
    last                        : std_logic;
      error                     : std_logic;
    
  end record;
  
  type s34_array is array (natural range <>) of s34_type;
  
  constant S34_RESET            : s34_type := (
    valid   => '0',
    last    => '0',
    error   => INVALID,
    others  => INVALID
  );
  
  ------------------------------------------------------------------------------
  -- Stage 3 computation
  ------------------------------------------------------------------------------
  -- Takes the one-hot and thermometer coded signals and converts them into
  -- subrange match signals, which together form the actual subset matchers
  -- used by the matchers.
  procedure s3_proc(i: in s23_type; o: inout s34_type) is
  begin
    
    -- Pass through control signals and decode range signals.
    o.valid         := i.valid;
    {s34_assigns:4}
    o.last          := i.last;
    o.error         := i.error;
    
    -- In simulation, make signals undefined when their value is meaningless.
    -- pragma translate_off
    if to_X01(o.valid) /= '1' then
      {s34_undefs:6}
    end if;
    if to_X01(o.last) /= '1' then
      o.error := INVALID;
    end if;
    -- pragma translate_on
    
  end procedure;
  
  ------------------------------------------------------------------------------
  -- Stage 4 to 5 record
  ------------------------------------------------------------------------------
  type s45_type is record
    
    -- Code point range stream. Each flag signal represents a set of code
    -- points as used by a transition in the NFAEs.
    valid                       : std_logic;
      match                     : std_logic_vector({cprange_count_m1} downto 0);
    
    -- Copy of s23.last/error.
    last                        : std_logic;
      error                     : std_logic;
    
  end record;
  
  type s45_array is array (natural range <>) of s45_type;
  
  constant S45_RESET            : s45_type := (
    valid   => '0',
    match   => (others => INVALID),
    last    => '0',
    error   => INVALID
  );
  
  ------------------------------------------------------------------------------
  -- Stage 4 computation
  ------------------------------------------------------------------------------
  -- Takes the subranges and maps them to the actual character sets that are
  -- used by the state machine transitions.
  procedure s4_proc(i: in s34_type; o: inout s45_type) is
  begin
    
    -- Pass through control signals and decode range signals by default.
    o.valid       := i.valid;
    {s45_assigns:4}
    o.last        := i.last;
    o.error       := i.error;
    
    -- In simulation, make signals undefined when their value is meaningless.
    -- pragma translate_off
    if to_X01(o.valid) /= '1' then
      o.match := (others => INVALID);
    end if;
    if to_X01(o.last) /= '1' then
      o.error := INVALID;
    end if;
    -- pragma translate_on
    
  end procedure;
  
  ------------------------------------------------------------------------------
  -- Stage 5 state type
  ------------------------------------------------------------------------------
  -- There is one bit for every NFAE state, which indicates whether the NFAE
  -- can be in that state.
  subtype s5s_type is std_logic_vector({state_count_m1} downto 0);
  
  type s5s_array is array (natural range <>) of s5s_type;
  
  constant S5S_RESET            : s5s_type := "{s5_initial}";
  
  ------------------------------------------------------------------------------
  -- Stage 5 output record
  ------------------------------------------------------------------------------
  type s5o_type is record
    
    -- String match stream. `valid` is an active-high strobe signal indicating
    -- validity, i.e. that a string has been completely processed.
    valid                       : std_logic;
    
      -- Active-high flag for each regular expression, indicating whether the
      -- regex matched the received string.
      match                     : std_logic_vector(NUM_RE-1 downto 0);
      
      -- Active-high UTF-8 decode error. If this is high, an error certainly
      -- occurred, but the following errors are not caught:
      --  - code points 0x10FFFF to 0x13FFFF (these are out of range, at least
      --    at the time of writing)
      --  - overlong sequences which are not apparent from the first byte
      error                     : std_logic;
    
  end record;
  
  type s5o_array is array (natural range <>) of s5o_type;
  
  constant S5O_RESET            : s5o_type := (
    valid   => '0',
    match   => (others => INVALID),
    error   => INVALID
  );
  
  ------------------------------------------------------------------------------
  -- Stage 5 computation
  ------------------------------------------------------------------------------
  -- Processes the actual NFAEs.
  procedure s5_proc(i: in s45_type; s: inout s5s_type; o: inout s5o_type) is
    variable si : s5s_type;
  begin
    
    -- Transition to the next state if there is an incoming character.
    if i.valid = '1' then
      si := s;
      {s5_transitions:6}
    end if;
    
    -- Save whether the next state will be a final state to determine whether
    -- a regex is matching or not. The timing of this corresponds to the last
    -- signal.
    {s5_final:4}
    
    -- Reset the state when we're resetting or receiving the last character.
    if reset = '1' or i.last = '1' then
      s := S5S_RESET;
    end if;
    
    -- Pass through control signals by default.
    o.valid := i.last;
    o.error := i.error;
    
    -- In simulation, make signals undefined when their value is meaningless.
    -- pragma translate_off
    if to_X01(o.valid) /= '1' then
      o.match := (others => INVALID);
      o.error := INVALID;
    end if;
    -- pragma translate_on
    
  end procedure;
  
  ------------------------------------------------------------------------------
  -- Signal declarations
  ------------------------------------------------------------------------------
  -- Internal copy of out_ready.
  signal out_valid_i            : std_logic;
  
  -- Internal ready signal.
  signal ready                  : std_logic;
  
  -- Internal clock enable signal. This is just `clken and ready`.
  signal iclken                 : std_logic;
  
  -- Input stream.
  signal inp                    : si1_array(BPC-1 downto 0);
  
  -- Interstage register signals.
  signal si1                    : si1_array(BPC-1 downto 0);
  signal s12                    : s12_array(BPC-1 downto 0);
  signal s23                    : s23_array(BPC-1 downto 0);
  signal s34                    : s34_array(BPC-1 downto 0);
  signal s45                    : s45_array(BPC-1 downto 0);
  
  -- Output stream.
  signal s5o                    : s5o_array(BPC-1 downto 0);
  
  -- State register signals.
  signal s2s                    : s2s_type;
  signal s5s                    : s5s_type;
  
begin
  
  ------------------------------------------------------------------------------
  -- Regex matcher logic
  ------------------------------------------------------------------------------
  match: process (clk, aresetn) is
    
    -- Reset procedure.
    procedure reset_all is
    begin
      si1 <= (others => SI1_RESET);
      s12 <= (others => S12_RESET);
      s23 <= (others => S23_RESET);
      s34 <= (others => S34_RESET);
      s45 <= (others => S45_RESET);
      s5o <= (others => S5O_RESET);
      s2s <= S2S_RESET;
      s5s <= S5S_RESET;
    end procedure;
    
    -- Slot pipeline generator.
    procedure slot_pipeline (
      i     : in natural range 0 to BPC-1;
      s2sv  : inout s2s_type;
      s5sv  : inout s5s_type
    ) is
      variable si1v : si1_type;
      variable s12v : s12_type;
      variable s23v : s23_type;
      variable s34v : s34_type;
      variable s45v : s45_type;
      variable s5ov : s5o_type;
    begin
      
      -- Load combinatorial input.
      si1v := inp(i);
      
      -- Input register.
      if INPUT_REG_ENABLE then
        si1(i)  <= si1v;
        si1v    := si1(i);
      end if;
      
      -- Stage 1.
      s1_proc(si1v, s12v);
      
      -- Stage 1-2 register.
      if S12_REG_ENABLE then
        s12(i)  <= s12v;
        s12v    := s12(i);
      end if;
      
      -- Stage 2.
      s2_proc(s12v, s2sv, s23v);
      
      -- Stage 2-3 register.
      if S23_REG_ENABLE then
        s23(i)  <= s23v;
        s23v    := s23(i);
      end if;
      
      -- Stage 3.
      s3_proc(s23v, s34v);
      
      -- Stage 3-4 register.
      if S34_REG_ENABLE then
        s34(i)  <= s34v;
        s34v    := s34(i);
      end if;
      
      -- Stage 4.
      s4_proc(s34v, s45v);
      
      -- Stage 4-5 register.
      if S45_REG_ENABLE then
        s45(i)  <= s45v;
        s45v    := s45(i);
      end if;
      
      -- Stage 5.
      s5_proc(s45v, s5sv, s5ov);
      
      -- Output register.
      s5o(i) <= s5ov;
      
    end procedure;
    
    -- Intermediate state variables.
    variable s2sv  : s2s_type;
    variable s5sv  : s5s_type;
    
  begin
    if aresetn = '0' then
      
      -- Asynchronous reset.
      reset_all;
      
    elsif rising_edge(clk) then
      if reset = '1' then
        
        -- Synchronous reset.
        reset_all;
        
      elsif iclken = '1' then
        
        -- Load state from previous cycle.
        s2sv := s2s;
        s5sv := s5s;
        
        -- Process the slots in order of endianness.
        if BIG_ENDIAN then
          for i in BPC-1 downto 0 loop
            slot_pipeline(i, s2sv, s5sv);
          end loop;
        else
          for i in 0 to BPC-1 loop
            slot_pipeline(i, s2sv, s5sv);
          end loop;
        end if;
        
        -- Register the state for the next cycle.
        s2s <= s2sv;
        s5s <= s5sv;
        
      end if;
    end if;
  end process;
  
  ------------------------------------------------------------------------------
  -- Interface stuff
  ------------------------------------------------------------------------------
  -- Desugar the backpressure signals into a simply clock enable signal. Note:
  -- this is why you probably don't want to use vhdre's backpressure ports if
  -- you want serious throughput. Refer to "Notes on backpressure and timing
  -- closure".
  ready <= out_ready or not out_valid_i;
  iclken <= clken and ready;
  in_ready <= ready;
  
  -- Put the input stream record signal together.
  inp_proc: process (in_valid, in_mask, in_data, in_last, in_xlast) is
    variable in_xlast_v : std_logic_vector(BPC-1 downto 0);
  begin
    
    -- Take the "last" flags from `in_xlast`.
    in_xlast_v := in_xlast;
    
    -- Allow `in_last` to override the "last" flag for the last slot.
    if BIG_ENDIAN then
      in_xlast_v(0) := in_xlast_v(0) or in_last;
    else
      in_xlast_v(BPC-1) := in_xlast_v(BPC-1) or in_last;
    end if;
    
    -- Assign the record signal.
    for i in 0 to BPC-1 loop
      inp(i) <= (
        valid => in_valid and in_mask(i),
        data  => in_data(8*i+7 downto 8*i),
        last  => in_valid and in_xlast_v(i)
      );
    end loop;
    
  end process;
  
  -- Unpack the output record.
  outp_proc: process (s5o) is
  begin
    
    -- Output is invalid unless any of the slots are valid.
    out_valid_i <= '0';
    
    -- Unpack the output record.
    for i in 0 to BPC-1 loop
      
      -- Make the output valid when any of the slots are valid.
      if s5o(i).valid = '1' then
        out_valid_i <= '1';
      end if;
      
      -- Unpack into the `out_x*` signals.
      out_xmask(i)                                  <= s5o(i).valid;
      out_xmatch(NUM_RE*i+NUM_RE-1 downto NUM_RE*i) <= s5o(i).match;
      out_xerror(i)                                 <= s5o(i).error;
      
    end loop;
    
    -- Unpack into the `out_*` signals.
    if BIG_ENDIAN then
      out_match <= s5o(0).match;
      out_error <= s5o(0).error;
    else
      out_match <= s5o(BPC-1).match;
      out_error <= s5o(BPC-1).error;
    end if;
    
  end process;
  
  out_valid <= out_valid_i;
  
end Behavioral;
"""

TEMPLATE_TB = """
{header}

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity {name}_tb is
end {name}_tb;

architecture Testbench of {name}_tb is
  signal clk                    : std_logic := '1';
  signal reset                  : std_logic := '1';
  signal in_valid               : std_logic;
  signal in_data                : std_logic_vector(7 downto 0);
  signal in_last                : std_logic;
  signal out_valid              : std_logic;
  signal out_match              : std_logic_vector({regex_count_m1} downto 0);
  signal out_error              : std_logic;
  signal out_match_mon          : std_logic_vector({regex_count_m1} downto 0);
  signal out_error_mon          : std_logic;
begin
  
  clk_proc: process is
  begin
    clk <= '1';
    wait for 5 ns;
    clk <= '0';
    wait for 5 ns;
  end process;
  
  stim_proc: process is
    procedure x(data_x: std_logic_vector) is
      constant data: std_logic_vector(data_x'length-1 downto 0) := data_x;
    begin
      in_valid <= '1';
      in_last <= '0';
      for i in data'length/8-1 downto 0 loop
        in_data <= data(i*8+7 downto i*8);
        if i = 0 then
          in_last <= '1';
        end if;
        wait until falling_edge(clk);
      end loop;
      in_valid <= '0';
      in_data <= (others => '0');
      in_last <= '0';
    end procedure;
  begin
    reset <= '1';
    in_valid <= '0';
    in_data <= (others => '0');
    in_last <= '0';
    wait for 500 ns;
    wait until falling_edge(clk);
    reset <= '0';
    wait until falling_edge(clk);
    {stimuli:4}
    wait;
  end process;
  
  uut: entity work.{name}
    port map (
      clk                       => clk,
      reset                     => reset,
      in_valid                  => in_valid,
      in_data                   => in_data,
      in_last                   => in_last,
      out_valid                 => out_valid,
      out_match                 => out_match,
      out_error                 => out_error
    );
  
  mon_proc: process (clk) is
  begin
    if falling_edge(clk) then
      if to_X01(out_valid) = '1' then
        out_match_mon <= out_match;
        out_error_mon <= out_error;
      elsif to_X01(out_valid) = '0' then
        out_match_mon <= (others => 'Z');
        out_error_mon <= 'Z';
      else
        out_match_mon <= (others => 'X');
        out_error_mon <= 'X';
      end if;
    end if;
  end process;
  
end Testbench;
"""


#------------------------------------------------------------------------------
# VHDL generator
#------------------------------------------------------------------------------

class CPSubRangeSig(tuple):
    """Represents a flag signal that is asserted when a character within a
    certain range of code points is being processed. The range can not cross a
    64-CP boundary."""
    
    def __new__(cls, block, start=0, end=63):
        """Creates a subrange. block is the 64-CP block (= code point >> 6),
        start and end represent the INCLUSIVE range of characters within the
        block to be matched."""
        if start < 0 or start > 62:
            raise ValueError("start out of range")
        if end < 1 or end > 63:
            raise ValueError("end out of range")
        return super(CPSubRangeSig, cls).__new__(cls, [block, start, end])
    
    @property
    def block(self):
        return self[0]
    
    @property
    def start(self):
        return self[1]
    
    @property
    def end(self):
        return self[2]
    
    def comment(self):
        return str(CharSet([(self.block*64+self.start, self.block*64+self.end+1)]))
    
    def __str__(self):
        """Return the name of the signal representing this subrange."""
        s = "b%05o" % self.block
        if self.start > 0:
            s += "f%02o" % self.start
        if self.end < 63:
            s += "t%02o" % self.end
        return s
    
    def entry(self):
        """Returns the signal definition."""
        return "%-26s: std_logic; -- %s" % (self, self.comment())
    
    def assign(self):
        """Returns the signal assignment code."""
        s = "o.%s  := i.oh3(%2d) and i.oh2(%2d) and i.oh1(%2d)" % (
            self, (self.block >> 12) & 0x3F, (self.block >> 6) & 0x3F, self.block & 0x3F)
        if self.start > 0:
            s += " and i.th0(%2d)" % (self.start - 1)
        if self.end < 63:
            s += " and not i.th0(%2d)" % (self.end)
        s += "; -- %s" % self.comment()
        return s

    def undef(self):
        """Returns the code for assigning 'U' to the signal."""
        return "o.%s := 'U';" % (self,)


class CPRangeSigs(object):
    """Code point range signal name registry. Prevents the creation of
    duplicate signals, and makes sure each code point range has a unique
    name."""
    
    def __init__(self):
        super().__init__()
        self.names = {}
        self.cpranges = []
    
    def register(self, cprange):
        """Registers a code point range and returns its name. If a duplicate
        cprange is being registered, the original name is returned and the
        duplicate is not registered."""
        key = cprange.min_charset
        name = self.names.get(key, None)
        if name is None:
            name = "match(%3d)" % len(self.cpranges)
            self.names[key] = name
            self.cpranges.append(cprange)
        return name
    
    def __iter__(self):
        return iter(self.cpranges)
    
    def __len__(self):
        return len(self.cpranges)
    
    def new(self, charset):
        return CPRangeSig(self, charset)


class CPRangeSig(object):
    """Represents a signal indicating that we're receiving one of some
    arbitraty set of code points."""
    
    def __init__(self, cpranges, charset):
        """Creates a CPRangeSig object from the given charset. This is done such
        that any representation of some charset or its negation results in the
        use of the same set of CPSubRanges."""
        super().__init__()
        
        self.charset = charset
        
        # Figure out if the normal or negated version of this charset gives
        # the least subranges.
        def count_subranges(charset):
            count = 0
            for start, stop in charset:
                end = stop - 1
                start_block = start // 64
                end_block = end // 64
                count += end_block - start_block + 1
            return count
        
        normal = charset.minimize()
        normal_count = count_subranges(normal)
        negated = -normal
        negated_count = count_subranges(negated)
        
        if (normal_count, normal) < (negated_count, negated):
            self.min_charset = normal
            self.negate = False
            count = normal_count
        else:
            self.min_charset = negated
            self.negate = True
            count = negated_count
        
        # Register this subrange only if it's not always true or false.
        if count:
            self.name = cpranges.register(self)
        else:
            self.name = "'0'"
        
        # Figure out which subranges need to be checked.
        self.subranges = []
        for start, stop in self.min_charset:
            end = stop - 1
            
            start_block = start // 64
            start_mod = start % 64
            end_block = end // 64
            end_mod = end % 64
            
            if start_block == end_block:
                self.subranges.append(CPSubRangeSig(start_block, start=start_mod, end=end_mod))
                continue
            
            self.subranges.append(CPSubRangeSig(start_block, start=start_mod))
            for block in range(start_block+1, end_block):
                self.subranges.append(CPSubRangeSig(block))
            self.subranges.append(CPSubRangeSig(end_block, end=end_mod))
    
    def prefix(self, s=""):
        """Return the name of the signal, prefixed with s, representing this
        subrange with a not in front if this subrange is inverted."""
        if self.name == "'0'":
            if self.negate:
                return "'1'"
            else:
                return "'0'"
        return "not " + s + self.name if self.negate else s + self.name
    
    __str__ = prefix
    
    def assign(self):
        """Returns the signal assignment code."""
        s = "o.%s  := " % self.name
        if self.negate:
            s += "not ("
        s += " or ".join(["i.%s" % (x,) for x in self.subranges])
        if self.negate:
            s += ")"
        s += "; -- %s" % (self.min_charset,)
        return s


class StateSig(object):
    """Represents an NFAE state signal."""
    
    def __init__(self, index, initial=False):
        super().__init__()
        self.index = index
        self.initial = initial
        self.transitions = []
    
    def incoming_transition(self, src, cprange):
        """Adds a transition. src should be the *index* of the source state.
        cprange should be the associated range object."""
        self.transitions.append((src, cprange))
    
    def assign(self):
        """Returns the assignment statement determining whether we'll be in
        this state in the next cycle."""
        s = "s(%3d) := " % self.index
        s += ("\n" + (" " * (len(s) - 3)) + "or ").join([
            "(si(%3d) and %s)" % (src, cprange.prefix('i.'))
            for src, cprange in self.transitions])
        if not self.transitions:
            s += "'0'"
        s += ";"
        return s


class RegexMatcher(object):
    """Represents a regex matching entity."""
    
    class Formatter(string.Formatter):
        def __init__(self, ob):
            super().__init__()
            self.ob = ob
        
        def get_value(self, key, args, kwds):
            if isinstance(key, str):
                try:
                    return getattr(self.ob, "_fmt_" + key)()
                except AttributeError:
                    return str(kwds[key])
            else:
                raise ValueError("Only named format codes are supported")
        
        def format_field(self, value, format_spec):
            if format_spec:
                value = value.replace("\n", "\n" + " "*int(format_spec))
            return value
    
    def __init__(self, name, *regexs):
        super().__init__()
        
        # Save the name.
        self.name = name
        
        # Create a formatter for this object.
        self.formatter = self.Formatter(self)
        
        # List of original regexs matched by this matcher.
        self.orig_regexs = []
        
        # List of parsed regexs matched by this matcher.
        self.regexs = []
        
        # Dict from charsets used in the regexs to CPRangeSig objects.
        self.charsets = {}
        
        # Set of all code point range signals.
        self.cpranges = CPRangeSigs()
        
        # Set of all code point subranges.
        self.cpsubranges = set()
        
        # Mapping from NFAEState objects to state indices.
        self.statemap = {}
        
        # List of states.
        self.states = []
        
        # Set of final state indices for every regex matched by this matcher.
        self.regex_finals = []
        
        # Add the initial set of regexs.
        for regex in regexs:
            self.append_re(regex)
    
    def append_re(self, regex):
        """Adds a regex to this matcher."""
        
        # Build the regex NFAE.
        pregex = regex_parse(regex)
        pregex = regex_to_nfae(pregex)
        pregex.strip_epsilon()
        pregex.minimize()
        
        # Reverse the regex so we get the incoming transitions for each state.
        pregex.reverse()
        
        # Figure out the states for this regex once.
        nfaestates = pregex.get_states()
        
        # Add the charsets needed by the regex to the list of charsets we need
        # to be able to match against.
        for nfaestate in nfaestates:
            for charset in nfaestate.real.values():
                cprange = self.cpranges.new(charset)
                self.charsets[charset] = cprange
                self.cpsubranges.update(cprange.subranges)
        
        # Assign numbers to the states of the regex.
        for nfaestate in nfaestates:
            if nfaestate not in self.statemap:
                state = StateSig(len(self.states), nfaestate in pregex.final)
                self.statemap[nfaestate] = state
                self.states.append(state)
        
        # Add the transitions between the states.
        for nfaestate in nfaestates:
            state = self.statemap[nfaestate]
            for src_nfaestate, transition in nfaestate.real.items():
                state.incoming_transition(self.statemap[src_nfaestate].index, self.charsets[transition])
        
        # Save the final states for this regex.
        self.regex_finals.append([self.statemap[s].index for s in nfaestates if s in pregex.initial])
        
        # Append the regex itself.
        self.orig_regexs.append(regex)
        self.regexs.append(pregex)
    
    def _fmt_header(self):
        s = "-- Generated by vhdre.py version %s\n" % __version__
        s += "\n".join("-- " + s for s in __license__.split("\n"))
        return s
    
    def _fmt_name(self):
        return self.name
    
    def _fmt_regex_comments(self):
        return "\n".join(["--  - %d: /%s/" % x for x in enumerate(self.orig_regexs)])
    
    def _fmt_regex_count_m1(self):
        return str(len(self.regexs) - 1)
    
    def _fmt_regex_count(self):
        return str(len(self.regexs))
    
    def _fmt_s34_entries(self):
        return "\n".join([x.entry() for x in sorted(self.cpsubranges)])
    
    def _fmt_s34_assigns(self):
        return "\n".join([x.assign() for x in sorted(self.cpsubranges)])
    
    def _fmt_s34_undefs(self):
        return "\n".join([x.undef() for x in sorted(self.cpsubranges)])
    
    def _fmt_cprange_count_m1(self):
        return str(len(self.cpranges) - 1)
    
    def _fmt_s45_assigns(self):
        return "\n".join([x.assign() for x in self.cpranges])
    
    def _fmt_state_count_m1(self):
        return str(len(self.states) - 1)
    
    def _fmt_s5_initial(self):
        return "".join(["1" if state.initial else "0" for state in reversed(self.states)])
    
    def _fmt_s5_transitions(self):
        return "\n".join([x.assign() for x in self.states])
    
    def _fmt_s5_final(self):
        ss = []
        for index, finals in enumerate(self.regex_finals):
            s = "o.match(%d) := " % index
            s += ("\n" + (" " * (len(s) - 3)) + "or ").join([
                "s(%3d)" % i for i in finals])
            if not finals:
                s += "'0'"
            s += ";"
            ss.append(s)
        return "\n".join(ss)
    
    def __str__(self):
        """Returns the VHDL code for this RegexMatcher."""
        return self.formatter.format(TEMPLATE)
    
    def testbench(self, test_strings):
        """Returns a testbench for this RegexMatcher."""
        
        class TestVecFormatter(string.Formatter):
            def __init__(self, ob):
                super().__init__()
                self.ob = ob
            
            def get_value(self, key, args, kwds):
                if isinstance(key, str):
                    return int(key, 0)
                else:
                    return key
            
            def format_field(self, value, format_spec):
                if format_spec == "u":
                    return chr(value)
                elif format_spec == "b":
                    return chr(value + 0x10FF00)
                return value
        
        tvfmt = TestVecFormatter(self)
        
        def stim(s):
            s = tvfmt.format(s)
            bs = bytearray()
            for c in s:
                cp = ord(c)
                if cp >= 0x10FF00:
                    bs.append(cp - 0x10FF00)
                else:
                    bs.extend(c.encode('utf-8'))
            s = 'x(X"'
            for b in bs:
                s += "%02X" % b
            s += '");'
            return s
        
        return self.formatter.format(
            TEMPLATE_TB,
            stimuli='\n'.join([stim(s) for s in test_strings])
        )


#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

if __name__ == "__main__":
    import sys
    
    def usage():
        print(r"Usage: %s <entity-name> <regex> ... [-- <test-string> ...]" % sys.argv[0])
        print(r"")
        print(r"Generates a file by the name <entity-name>.vhd in the working directory")
        print(r"which matches against the given regular expressions. If one or more test")
        print(r"strings are provided, a testbench by the name <entity-name>_tb.vhd is")
        print(r"also generated. To insert a unicode code point, use {0xHHHHHH:u}. To")
        print(r"insert a raw byte (for instance to check error handling) use {0xHH:b}.")
        print(r"{{ and }} can be used for matching { and } literally.")
        sys.exit(2)
    
    if len(sys.argv) < 3:
        usage()
    
    # Figure out where the -- is (if it exists).
    split = len(sys.argv)
    for i, arg in enumerate(sys.argv[3:]):
        if arg == "--":
            split = i + 3
    
    # Generate the matcher.
    matcher = RegexMatcher(*sys.argv[1:split])
    
    # Generate the main file.
    vhd = str(matcher)
    with open(sys.argv[1] + ".vhd", "w") as f:
        f.write(vhd)
    
    # Generate the testbench if desired.
    vectors = sys.argv[split+1:]
    if vectors:
        vhd_tb = matcher.testbench(vectors)
        with open(sys.argv[1] + "_tb.vhd", "w") as f:
            f.write(vhd_tb)

