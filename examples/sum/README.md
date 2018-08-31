# Getting Started: Simple Summing Example

This is a simple example with the goal of getting first-time users of
Fletcher started with a project. The core of this example is an
accumulator that sums all integers in a given Arrow column.

Be sure to read the sources as well, they contain useful hints.

## Generating the hardware skeleton files

Note: The produced files are available in the repository, so these steps
can be skipped if so desired. They also provide a reference for when
the tools are updated and their output changes. The goal is to track these
changes into this example as quickly as possible, but it may lag behind.

The main component of Fletcher is the
[ColumnReader](../../hardware/vhdl/columns/ColumnReader.vhd).
The column reader will transparently read rows of data from memory and
provide them on its output. Multiple column readers are supported with the
use of an [arbiter](../../hardware/vhdl/interconnect/BusReadArbiterVec.vhd),
though only one reader is used in this example.
Next to this, a controller is added, which communicates with the host software
and can be used to coordinate work in more complex designs.
A default controller is provided.
These components, together with the user provided accelerator, are combined
into one component named *fletcher_wrapper*.

The *fletcher_wrapper* component is platform independent. To communicate
with target platform host software, a host-specific interface must be added.
The [AWS F1](https://github.com/aws/aws-fpga)
and [CAPI SNAP](https://github.com/open-power/snap)
platforms use memory mapped IO and an AXI bus.
For these platforms, an interface layer is added that converts the
Fletcher bus requests to AXI format.
For configuration and control of the hardware function from the
host software, [MMIO registers](../../hardware/axi/axi_mmio.vhd) are used.

The above will be contained in the following files:

  * [sum.vhd](./hardware/axi_top.vhd)
Hardware accelerated function, provided by the user
  * [fletcher_wrapper.vhd](./hardware/fletcher_wrapper.vhd)
Readers and associated hardware (Fletcher)
  * [axi_top.vhd](./hardware/axi_top.vhd)
Interface for hosts using AXI.

The core accelerator function will be implemented inside the generated
template and will differ depending on the Arrow schema that is used
for storing the data.
The instantiation template for the accelerated function can be generated
automatically from an Arrow schema by [fletchgen](../../codegen/fletchgen/).

### Requirements
  * C++14 compatible compiler (tested with GCC 5.5)
  * Boost development libraries
      * system
      * filesystem
      * regex
      * program_options
  * A VHDL simulator (e.g. ModelSim)

### Install Apache Arrow

Install Apache Arrow. The supported release is
[0.10.0](https://github.com/apache/arrow/releases/tag/apache-arrow-0.10.0).

    $ curl "https://codeload.github.com/apache/arrow/tar.gz/apache-arrow-0.10.0" \
        | tar --extract --gzip
    $ cd arrow-apache-arrow-0.10.0
    $ mkdir cpp/build
    $ cd cpp/build
    $ cmake \
        -DARROW_PLASMA=ON \
        ..
    $ make install

### Get Fletcher

Clone the Fletcher repository and set up the environment.

    $ git clone https://github.com/johanpel/fletcher.git
    $ cd fletcher
    $ source env.sh

### Build fletchgen

Build [fletchgen](../../codegen/fletchgen/) as described in its README.

    $ cd "$FLETCHER_CODEGEN_DIR/fletchgen"
    $ mkdir debug
    $ cd debug
    $ cmake \
        ..
    $ make install

### Create a schema file

The schema that is used for the input data must be written to a file
in order for fletchgen to use it.
An example of how to generate such a file using Apache Arrow can be found
in [schema.cpp](./hardware-gen/schema.cpp).
The provided CMake project will create the schema file and the
hardware skeleton files.

    $ cd "FLETCHER_EXAMPLES_DIR/sum/hardware-gen"
    $ mkdir build
    $ cd build
    $ cmake ..
    $ make

To create a schema manually after compiling:

    $ ./schema

### Generate hardware skeleton files

With the schema file (*sum.fbs*) from the previous step,
generate the skeleton files.
The files will already have been generated if you used the CMake project in
the previous step. This will produce fletcher_wrapper.vhd and axi_top.vhd.

To run fletchgen manually:

    $ fletchgen --quiet \
        --input sum.fbs \
        --output fletcher_wrapper.vhd \
        --axi axi_top.vhd

## Implement accelerated function

Design the hardware accelerated function, using the component description of
*sum* in the generated [fletcher_wrapper.vhd](./hardware/fletcher_wrapper.vhd).
The design will need a simple state machine, control signals,
and status signals.
The finished design is included ([hardware/sum.vhd](./hardware/sum.vhd))
in the repository.

## Create testbench

TODO: Generate SREC file and run platform-independent simulation.

## Run on hardware

If the tests pass, pick a supported platform to synthesise the design for.
An [example](../../platforms/aws-f1/sum/) exist for AWS F1 instances.