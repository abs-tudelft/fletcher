# Cerata
A library for high-level structural hardware design.

Cerata is a library that allows you to describe hardware structures with abstract and nested types as graphs. 
Cerata's graphs are like an intermediate representation for these structures. 
Several back-ends (or your own back-end) can that turn the graph into something else, like source code (e.g. VHDL), 
or documentation (e.g. DOT graph).

Rather than suffering from the verbosity of languages such as VHDL and Verilog, a developer can use Cerata to 
programmatically construct more complex types and "drag" them around the design with a few lines of code. The hassle of
turning that graph representation into something synthesizable for various output targets is left to Cerata. 

Furthermore, it allows you to programmatically inspect and modify constructed graphs. This allows other code to 
reflect on designs that were generated, for whatever purpose. Examples include: adding profiling components to specific
streams or optimizing bus infrastructures. 

Currently, there is no front-end language for Cerata, or a storage format for the intermediate representation. 
