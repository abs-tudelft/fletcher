# Hardware Guide

Currently, the top-level component that you should use is called a 
ColumnReader. A ColumnReader is not surprisingly able to read from an 
Arrow Column. Because elements in columns in an Arrow Table have no
dependencies amongst eachother, you are free to implement, for example:

- One ColumnReader for each Arrow Column
- Multiple ColumnReaders for each Arrow Column
- One ColumnReader for just one of the Columns in a Table
- Multiple ColumnReaders for each Arrow Column

To configure a ColumnReader, you must set the generics to the HDL 
component appropriately. Things like bus data width, bus address width,
burst length, etc... should speak for itself. However, one important 
generic is the configuration string.

## ColumnReader configuration string

The configuration string provided to a ColumnReader is somewhat 
equivalent to an Arrow Schema. It conveys the same information about the
layout/structure of the Column in memory. There are some additional 
options to tweak internals (like FIFO depths), but we will ignore them 
for now.

[ColumnConfig.vhd](vhdl/columns/ColumnConfig.vhd) contains an in-depth guide on which entries of 
the config string are supported.

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
    afor example).
- null(\<A\>)
  - To allow an element to be nullable

For example, if you have a Schema like:
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

For simplicity, assume all elements are non-nullable, except those of
field A in the struct of field Z.

You can instantiate three ColumnReaders using the following three 
configuration strings:

- X: "prim(32)"
- Y: "listprim(8)"
- Z" "struct(null(prim(32)),prim(64))"

## ColumnReader interface

After you set the ColumnReader configuration string, the hardware
structure is generated, but as of now, we don't have a nice wrapper
generation tool (yet; incoming soon).

In any case, each ColumnReader allows to stream in a first and last 
index. It will subsequently absorb these indices and stream out the 
range of elements designated by those indices (exlusively the last 
index).

The data port on the output stream is dependent on the configuration
string. Here are some examples:

## Examples:
In these examples, whenever the (nested) field is nullable, the config string should be wrapped with null().

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

For more in-depth information, check out [ColumnConfig.vhd](vhdl/columns/ColumnConfig.vhd)
