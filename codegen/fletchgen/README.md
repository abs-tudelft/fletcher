# Fletchgen: The Fletcher Design Generator
Fletchgen is a command-line utility that generates the upper layers of a hardware design, including simulation and 
platform-specific top-levels, based on Arrow Schemas and Recordbatches. 

Currently, the overall structure of a Fletcher hardware design is as follows:

* For each Arrow Field, an ArrayReader/Writer is instantiated.
* For each Arrow Schema, a RecordBatch/Writer is generated and wrapper around all ArrayReader/Writer instances.
* For the combination of all Arrow Schemas, a Kernel is generated.
* All RecordBatch/Writers and the Kernel is wrapped by a Mantle. The Mantle also instantiate the required 
  memory bus interconnection logic.

# Prerequisites
* [C++17 compliant compiler](https://clang.llvm.org/)
* [Apache Arrow 0.13+](https://github.com/apache/arrow)
* [CMake 3.10+](https://cmake.org/)

# Build
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
fletchgen -i <schema file> -o <wrapper name>
```

## From a Schema file

### Shortest version:
* Generate a schema in whatever language Arrow has an API for.
* Export the schema as a Flatbuffer file.
* Run fletchgen with the Flatbuffer file as parameter.

### Short version:

* Generate the schema in a programming language that Arrow an API for.

We give the example in C++, as this API is most matured at the time of writing.

For example, if you want a schema that can describe the datatypes in a table or
recordbatch with just a column of 8-bit unsigned integers:

```cpp
// Create a vector of fields that will form the schema.
std::vector<std::shared_ptr<arrow::Field>> schema_fields = {
  arrow::field("Num", arrow::uint8(), false)
};

// Create the schema
auto schema = std::make_shared<arrow::Schema>(schema_fields, genMeta(Mode::READ));
```

Note that if fields are not nullable, this can save a considerable amount of
resources in hardware. Therefore, the third parameter of the arrow::field 
constructor is set to false.

* Export the schema as a Flatbuffer file.

In C++, you can use the SerializeSchema function of the arrow::ipc namespace 
for this. Example following the previous code block:

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

# Supported/required metadata for Arrow Schemas
Fletchgen derives how to use an Arrow Schema from attached key-value metadata that is stored in Arrow Schemas as 
strings. You can use this to, for example, prevent the generation of hardware structures for fields that you're not 
going to use in your kernel implementation.

## Schema metadata:
### Access mode (required)
| Key                    | Possible values     | Default | Description                                                |
|------------------------|---------------------|---------|------------------------------------------------------------|
| fletcher_mode          | read / write        | read    | Determines whether a RecordBatch of this schema will be read or written by the kernel. |

## Field metadata:

| Key                    | Possible values | Default | Description                                  |
|------------------------|-----------------|---------|----------------------------------------------|
| fletcher_ignore        | true / false    | false   | Whether to ignore a specific Schema field, preventing generation of hardware to read/write from/to it. |
| fletcher_offsets_width | 1 / 2 / 4 / ... | 32      | For `List<>` fields only. Width of offsets.  |
| fletcher_epc           | 1 / 2 / 4 / ... | 1       | Number of elements per cycle for this field. For `List<X>` fields where X is a fixed-width type, this applies to the `values` stream. |
| fletcher_lepc          | 1 / 2 / 4 / ... | 1       | For `List<>` fields only. Number of elements per cycle on the `length` stream. |
| fletcher_tag_width     | 1 / 2 / 3 / ... | 1       | Tag width of command and unlock streams for the field. |

# Further reading

You can generate a simulation top level and provide a Flatbuffer file with a RecordBatch to the simulation environment. 
You can use this to debug your designs in simulation, independent of an FPGA platform specific simulation environment. 
[An example is shown here.](test/hardware/stringread).
