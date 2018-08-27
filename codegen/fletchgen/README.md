# Fletcher Wrapper Generator
This tool generates a VHDL wrapper for an Arrow Schema. 
This wrapper contains the following:
* A ColumnReader/Writer instance for each Arrow Field of a Schema.
* Bus arbiters for reading and writing to/from the ColumnReader/Writers.
* A state machine to support the start(), stop(), reset(), etc. commands of the run-time library.
* The Hardware-Accelerated Function (HAF). This component is to be implemented by the user. Only a template is generated.

# Requirements
It should not be a surprise that we require Apache Arrow. We use Boost.Program_options to parse command line options. You also need a C++14 compliant compiler, such as Clang.
* [C++14 compliant compiler](https://clang.llvm.org/)
* [Apache Arrow 0.10+](https://github.com/apache/arrow) with Plasma (-DARROW_PLASMA=ON)
* [libboost 1.58+](https://www.boost.org/)

# Build
Currently you can make a simple debug build as follows (on Ubuntu):
```console
cd /path/to/fletcher/codegen/fletchgen
mkdir debug
cd debug
cmake ..
make
sudo make install
```

# Usage
* Read the command-line options.
```console
fletchgen -h
```
* Generate a wrapper from a Schema file:
```console
fletchgen -I <schema file> -O <wrapper name>
```

## From a Schema file

### Shortest version:
* Generate a schema in whatever language Arrow has an API for.
* Export the schema as a Flatbuffer file.
* Run fletchgen with the Flatbuffer file as parameter.

### Short version:

* Generate the schema in a programming language that Arrow an API for.

We give the example in C++, as this API is most matured at the time of writing.

For example, if you want a schema that can describe the datatypes in a table or recordbatch with just a column of 8-bit unsigned integers:

```cpp
// Create a vector of fields that will form the schema.
std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
  arrow::field("Num", arrow::uint8(), false)
};

// Create the schema
auto schema = std::make_shared<arrow::Schema>(schema_fields, genMeta(Mode::READ));
```

Note that if fields are not nullable, this can save a considerable amount of
resources in hardware. Therefore, the third parameter of the arrow::field constructor is set to false.

* Export the schema as a Flatbuffer file.

In C++, you can use the SerializeSchema function of the arrow::ipc namespace for this. 
Example following the previous code block:

```cpp
  // Create buffer to store the serialized schema in:
  auto buffer =
      std::static_pointer_cast<arrow::Buffer>(std::make_shared<arrow::PoolBuffer>(arrow::default_memory_pool()));

  // Serialize the schema into the buffer:
  arrow::ipc::SerializeSchema(*schema, arrow::default_memory_pool(), &buffer);

  // Write the buffer to a file:
  std::shared_ptr<arrow::io::FileOutputStream> fos;
  if (arrow::io::FileOutputStream::Open("myschema.fbs", &fos).ok()) {
    fos->Write(buffer->data(), buffer->size());
  } else {
    throw std::runtime_error("Could not open schema file for writing: " + file_name);
  }
```

* Run fletchgen with the Flatbuffer file as parameter.

`fletchgen /path/to/myschema.fbs`

This produces the wrapper on stdout. If you want to save it in a file:

`fletchgen /path/to/myschema.fbs > wrapper.vhd`

# Supported metadata for Arrow Schemas

## Schema metadata:
* `"fletcher_mode" : "read" | "write"` - Determines whether the datastructure in host memory will be read or written.

## Field metadata:
* `"fletcher_ignore" : "true" | "false"` - Whether the field must ignored in interface generation.
* `"fletcher_epc" : "0" | "1" | "2" | "4" | ...` - The number of elements per clock cycle to deliver of this field. Must be power of 2. Only works on lists of primitives or primitive fields.

# Further reading

You can generate a simulation top level and provide a Flatbuffer file with a RecordBatch to the simulation environment.
You can use this to debug your designs in simulation, independent of an FPGA platform specific simulation environment.
[An example is shown here.](../../hardware/test/fletchgen/stringread).
