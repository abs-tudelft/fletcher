# In-depth Hardware Guide

### Please note:
If you are just getting started with Fletcher, you might want to use the 
[Wrapper Generator](../codegen/fletchgen/README.md) to automatically generate a
wrapper that instantiates ArrayReader/ArrayWriters and sets their 
configuration. It is still worthwhile to read this page to get a basic 
understanding of the interfaces.

## Hardware Guide

Currently, the top-level component that you should use is called a 
ArrayReader or a ArrayWriter, depending on whether you wanto read or write 
data from/to an Arrow Array in a RecordBatch/Table.

For reading, because elements in an Arrow Recordbatch/Table can be processed 
in parallel, you are free to implement, for example:

- One ArrayReader for each Arrow Array
- Multiple ArrayReaders for each Arrow Array
- One ArrayReader for just one of the Arrays in a Table
- Multiple ArrayReaders for each Arrow Array

For writing, this depends on the datatype. For primitive fixed-width types, it 
is possible to have multiple ArrayWriters for a single array. However, for
variable length types (for example; strings), this is currently not possible.
Of course you are free to build up the dataset in parallel and merge them later
on your host system in software.

To configure a ArrayReader/ArrayWriter, you must set the generics to the HDL 
component appropriately. Things like bus data width, bus address width,
burst length, etc... should speak for itself. However, one important 
generic is the configuration string.

## ArrayReader/Writer configuration string

The configuration string provided to a ArrayReader/Writer is somewhat 
equivalent to an Arrow Schema. It conveys the same information about the
layout/structure of the Array in memory. There are some additional 
options to tweak internals (like FIFO depths), but we will ignore them 
for now.

[ArrayConfig.vhd](arrays/ArrayConfig.vhd) contains an in-depth guide 
on which entries of the config string are supported.

**Make sure not to use any whitespace characters in the configuration 
such as spaces or newlines.

The following elements are supported:

- prim(\<width\>)
  - Any type of fixed-width <width\>, such as ints, floats,
  doubles, bits, etc...
- list(\<A\>)
  - A list of any of the supported types
- struct(\<A\>,\<B\>)
  - A structure of any of the supported types
- listprim(\<width\>;epc=N)
  - A non-nullable list of non-nullable 
    primitives, where you will receive N of these primitive elements per 
    cycle at the output. epc is optional. (useful for UTF8 strings, 
    for example).
- null(\<A\>)
  - To allow an element to be nullable

For example, if you have the Schema of a RecordBatch as follows:
<pre>
  Schema {
    X: int32
    Y: string   // Using UTF8 characters
    Z: struct{
      A: int32  // Nullable
      B: double
    }
  }
</pre>
For simplicity, assume all elements are non-nullable, except those of field A 
in the struct of field Z. 

Suppose we would like to read from this RecordBatch in host memory. You can 
instantiate three ArrayReaders using the following three configuration 
strings:

- X: "prim(32)"
- Y: "listprim(8)"
- Z" "struct(null(prim(32)),prim(64))"

## ArrayReader/Writer interface

After you set the ArrayReader/Writer configuration string, the hardware
structure is generated.

Each ArrayReader/Writer has the following streams:

* From accelerator to ArrayReader/Writer:
  * Command (cmd): To issue commands to the ArrayReader/Writer

* From ArrayReader/Writer to accelerator:
  * Unlock:  To notify the accelerator the command has been executed.

A ArrayReader additionaly has the following streams:

* From ArrayReader to host memory interface:
  * Bus read request (bus_rreq): To issue burst read requests to the host
    memory.
* From host memory interface to ArrayReader:
  * Bus read data (bus_rdat): To receive requested data from host memory.
* From ArrayReader to accelerator:
* Data (out):
  * Streams of the datatype defined in the schema.

For ArrayWriters:

* From ArrayReader to host memory interface:
  * Bus write request (bus_wreq): To issue burst write requests to the host
    memory.
  * Bus write data (bus_wdat): To stream write data to host memory.
* From accelerator to ArrayWriter
* Data (in):
  * Streams of the datatype defined in the schema.

The streams follow the ready/valid handshaking methodology similar to AXI4.
This means a transaction is handshaked only when both the ready and valid
signal are asserted in a single clock cycle. Furthermore, it means any producer
of a stream may not wait for the ready signal to be asserted. However, a stream
consumer may assert ready before any valid signal is asserted. For more detail,
it is __highly recommended to read the AXI4 protocol specification chapter on 
"Basic read and write transactions"__.

### How to use a ArrayReader/ArrayWriter

For a ArrayReader:

1. Handshake a command on the Command stream (cmd). 
   - The _firstIdx_ and _lastIdx_ correspond to the first and (exclusively) last 
index in an Arrow RecordBatch or Table that you would like to load. For 
example, if you want to stream in elements 0, 1 and 2, you would issue the
command with _firstIdx_ = 0 and _lastIdx_ = 3. 
   - Furthermore, you must supply the addresses of the Arrow
buffers of the RecordBatch on the _ctrl_ port. This should be done in a 
specific order seen in [ArrayConfig.vhd](vhdl/arrays/ArrayConfig.vhd). 
   - Finally, you may provide a _tag_ with your command that will appear on the 
unlock stream when the command is finished.

2. The ArrayReader will now start requesting and receiving bursts through the
bus request and data streams (bus_rreq and bus_rdat_.

2. Absorb the data from the output stream (out).
   - The signals of all output streams are all concatenated onto this stream.
   This is also explained in [ArrayConfig.vhd](vhdl/arrays/ArrayConfig.vhd).
   More examples are at the end of this page.
   - The [Wrapper Generator](../codegen/fletchgen/README.md) automatically 
   "unwraps" these concatenated streams into more readable streams 
   corresponding to your schema.
   
3. Wait for the unlock stream (unlock) to deliver the tag of your command.
   - The command has now been successfully executed.
   
For a ArrayWriter, the bus data stream is reversed, and the user is to supply
the data to the ArrayWriter as an input stream (in). In terms of using the 
command stream and unlock stream, the behaviour is similar. There is one 
exception to the command stream. If you do not know (or care) in hardware how
large your Array will be, you may set lastIdx = 0. In this case, the last 
signal of the top-most input stream will determine the last index.

## Additional configuration string examples:
Here are some examples that show the lay-out of the output (out) or input (in)
streams for specific schema's.

In these examples, whenever the (nested) field is nullable, the config string
should be wrapped with null().

### Int32 Array
#### Config string
`prim(32)`
or
`null(prim(32))` 
if it is nullable.
#### User signals
##### Stream 0
* data(32): (optional) '1' when this element is not null, '0' otherwise
* data(31 ... 0): Int32 element
* last: '1' when element is last in request, '0' otherwise

### List\<Char\>
#### Config string
`list(prim(8))`
or
`null(list(null(prim(8))))`
if both the list and the char are nullable.
or
`null(list(prim(8)))`
if only the list is nullable
or
`list(null(prim(8)))`
if only the char is nullable.

Assuming the null() examples are clear, we omit them in further examples.

#### User signals
##### Stream 0
* data(32): (optional) '1' when this list is not null, '0' otherwise
* data(31 ... 0): length of list of chars
* last: '1' when list is last in request, '0' otherwise
##### Stream 1
* data(8): (optional) '1' when this element is not null, '0' otherwise
* data(7 ... 0): Char element
* last: '1' when element is last in request, '0' otherwise

### List\<List\<Byte\>\>
#### Config string
`list(list(prim(8))`
#### User signals
##### Stream 0
* data(32): (optional) '1' when this list (of lists of lists) is not null, '0' otherwise
* data(31 ... 0): length of list (of lists of lists)
* last: '1' when list (of lists) is last in request, '0' otherwise
##### Stream 1
* data(32): (optional) '1' when this list (of lists) is not null, '0' otherwise
* data(31 ... 0): length of list (of bytes)
* last: '1' when list (of lists) is last in request, '0' otherwise
##### Stream 2
* data(8): (optional) '1' when this element is not null, '0' otherwise
* data(7 ... 0): Byte element
* last: '1' when element is last in request, '0' otherwise

### Struct\<List\<Char\>, Int32\>
#### Config string
`struct(list(prim(8)),prim(32))`
#### User signals
##### Stream 0
**Note well: when any of the "not null" bits are unused, the bit indices shift accordingly.**
* data(66): (optional) '1' when the whole struct is not null, '0' otherwise
* data(65): (optional) '1' when the list field in the struct is not null, '0' otherwise
* data(64 ... 33): length of list (of chars)
* data(32): (optional) '1' when the int32 field in the struct is not null, '0' otherwise
* data(31 ...  0): Int32 element
* last: '1' when struct is last in request, '0' otherwise
##### Stream 1
* data(8): (optional) '1' when this element is not null, '0' otherwise
* data(7 ... 0): Char element
* last: '1' when element is last in list, '0' otherwise

### List\<Struct\<List\<Char\>, Int32\>>
#### Config string
`list(struct(list(prim(8)),prim(32)))`
#### User signals
#### Stream 0
* data(32): (optional) '1' when this list (of structs) is not null, '0' otherwise
* data(31 ... 0): length of list (of structs)
* last: '1' when list (of structs) is last in request, '0' otherwise
#### Stream 1
**Note well: when any of the "not null" bits are unused, the bit indices shift accordingly.**
* data(66): (optional) '1' when this struct is not null, '0' otherwise
* data(65): (optional) '1' when the list field in the struct is not null, '0' otherwise
* data(64 ... 33): length of list (of chars)
* data(32): (optional) '1' when the int32 field in the struct is not null, '0' otherwise
* data(31 ...  0): Int32 element
* last: '1' when struct is last in list (of structs), '0' otherwise
#### Stream 2
* data(8): (optional) '1' when this element is not null, '0' otherwise
* data(7 ... 0): Char element
* last: '1' when element is last in list, '0' otherwise

# More information

For more in-depth information, check out [ArrayConfig.vhd](vhdl/arrays/ArrayConfig.vhd)
