# Cerata 
<small><i>Making pure structural hardware design less painful since 2019.</i></small>

Cerata is a library that allows you to describe hardware structures with abstract and nested types as graphs. 
Cerata's graphs are like an intermediate representation for these structures. 
Several (or your own) back-end can that turn the graph into something else, like source code (e.g. VHDL), or 
documentation (e.g. DOT graph).
Rather than suffering from the verbosity of languages such as VHDL and Verilog, a developer can use Cerata to 
programmatically construct more complex types and "drag" them around the design with a few lines of code. 
The hassle of turning that graph representation into something synthesizeable for various output targets is left to 
Cerata. 

There is no front-end language for Cerata, and at the moment its main use case/application is in the wrapper generator 
of Fletcher.

## C++ example
```cpp
  auto my_type = Stream::Make("my_stream_type", Vector
  auto  = Port::Make("B", data, Term::IN);
```

## Overview

Objects:
- Graph
  - Component
  - Instance
- Node
  - Literal
  - Expression
  - Parameter
  - Port
  - Signal
- NodeArray
  - SignalArray
  - PortArray