# Regular Expression Matching example

This is an example in which some [ColumnReaders](../../../hardware) are
used to read a column with UTF8 strings. The config string for the 
columns is therefore "listprim(8)", to generate an interface to a 
non-nullable list of non-nullable 8-bit wide elements.

The design instantiates sixteen of these ColumnReader, attached to 
sixteen regular expression matching units, that can all work in parallel.

The ColumnReaders are attached to an AXI interconnect, but we inserted
an `axi_read_converter` to convert the `bsize` (Burst Size) signal 
properly to match the AWS Shell requirement of setting this to 2^6=64 
bytes fixed burst beat size. This is because the ColumnReaders bus data
width is 32-bits.

The AXI interconnect is attached to another AXI interconnect, that 
allows the PCI master interface of the Shell to write to the DDR 
controllers (DMA), and allows the RegEx interconnect to read from them.

Because the Amazon Shell does not provide any address translation 
functionality, we have to make one copy of the Arrow buffers into the 
on-board DDR, because it would be infeasible to resolve physical 
addresses of the host memory everytime we cross a page boundary. 
Furthermore, the copy throughput offered by the shell is quite low 
(a bit over 1 GiB/s). Amazon appears to be working on increasing this.

This subfolder follows the structure of projects on the 
[AWS EC2 FPGA Hardware and Software Development Kits](https://github.com/aws/aws-fpga).

If you are totally unfamiliar with the examples there, it is highly
recommended to follow some of the guides on that repository. At least 
try to build and run the "Hello World" example.

### Source file description:

| File                   | Description                                                                                                       |
| :--------------------- | :---------------------------------------------------------------------------------------------------------------- |
| cl_arrow.sv            | Top level design instantiating `arrow_regexp` and AXI interconnect between PCI and DDR interface for DMA.         |
| cl_arrow_pkg.sv        | Package containing interfaces used in the top-level                                                               |
| cl_arrow_defines.vh    | Definitions used in the top-level                                                                                 |
| cl_id_defines.vh       | IDs used in the top-level                                                                                         |
| arrow_regexp_pkg.vhd   | Package containing component declarations and records used in the example.                                        |
| arrow_regexp.vhd       | Component that handles memory mapped slave access and instantiates 16 regular expression matchers & interconnect. |
| arrow_regexp_unit.vhd  | A single regular expression matching unit, that also instantiates a ColumnReader.                                 |
| axi_read_converter.vhd | A helper component to convert to a fixed burst size on the AXI bus, as the AWS Shell doesn't support burst sizes other than 2^6 bytes |
| ip/                    | A folder containing the AXI interconnect IP configurations. You must generate them first before simulation (see below). |
| kitten_regexp.vhd      | A regular expression matching unit generated using [Jeroen van Straten's framework](../../../codegen/vhdre) (which is included in this repository). |

You can use this project as a baseline for your own projects that just use the DRAM DMA,
by just removing all of the VHDL files listed above.

# Requirements

This design was tested with:

* [AWS EC2 FPGA Hardware and Software Development Kits](https://github.com/aws/aws-fpga) 
  version 1.3.6 and its recommended Xilinx Vivado version
* [Apache Arrow 0.8](https://arrow.apache.org/install/)
* A compiler that supports C++14. If you are running on CentOS on the 
  Amazon F1 instances, which does not have this installed by default, 
  the easiest way to get it up and running is to use the 
  [Developer Toolset 6](https://www.softwarecollections.org/en/scls/rhscl/devtoolset-6/).

### Before any of the steps below, wether performing simulation, build or run:
    $ git clone https://github.com/johanpel/fletcher.git
    $ cd fletcher
    $ source env.sh
    
This also holds for when you run the example on the Amazon F1 instance.

# Simulate using Vivado XSIM

#### Install the AWS FPGA hardware development kit (HDK)

    $ cd <the dir where you want aws-fpga to live>

    $ git clone https://github.com/aws/aws-fpga
    $ cd aws-fpga
    $ source hdk_setup.sh

#### Set the CL_DIR environment variable
    $ cd $FLETCHER_PLATFORM_DIR/aws-f1/cl_arrow
    $ export CL_DIR=$(pwd)

#### Generate the Xilinx IP output products for the AXI interconnects
    $ source generate_ip.sh
    
#### Set up the simulation
    $ cd verif/scripts
    $ make TEST=test_arrow_regexp
    
This sets up the simulation only. For normal CL designs this also starts and runs the simulation, but we've disabled this.

#### Run the simulation with GUI
    $ cd ../sim/test_arrow_regexp/
    $ xsim tb -gui

#### Run the simulation without GUI
    $ cd ../sim/test_arrow_regexp/
    $ xsim tb

#### Expected output
Eventually you should see the status register go from 0x0000FFFF (units are busy) to 0xFFFF0000 (units are done).
The simulation will poll for this status value on the slave interface.
The result (number of matches to the regular expression) will appear on the return registers:
<pre>
  Return register HI:           0
  Return register LO:          13
</pre>

# Build
    $ cd $FLETCHER_PLATFORM_DIR/aws-f1/cl_arrow
    $ export CL_DIR=$(pwd)

Sometimes you have to fix the symbolic link to the build script in this directory. Remove the link if it's there (optionally):

    $ rm aws_build_dcp_from_cl.sh
    
Recreate the link (optionally):

    $ ln -s $HDK_DIR/common/shell_stable/build/scripts/aws_build_dcp_from_cl.sh

#### Continue to build:

    $ ./aws_build_dcp_from_cl.sh 
    
#### Submit the design to Amazon. Follow the instructions on their repository.
    
#### Optional parameters to aws_build_dcp_from_cl.sh

* 125 MHz clock: 

  `-clock_recipe_a A0`

* 250 MHz clock: 

  `-clock_recipe_a A1`

* On-premise build without enough recommended memory: 

  `-ignore_memory_requirement`

* Don't nohup the build:

  `-foreground`

# Run on an AWS EC2 F1 instance

#### Please check the Amazon documentation on how to start up an F1 instance.

* Start up an instance with the FPGA AMI from the Amazon marketplace.

* Make sure that your instance follows the requirements mentioned above.

* Load the FPGA image, follow the instructions from Amazon.

* Source the `sdk_setup.sh` script in the Amazon repository. On an F1 instance using the 
  FPGA AMI, this might already reside in the `~/src/project_data/aws-fpga` directory:

#### Source the Amazon sdk_setup.sh script:
    $ source ~/src/project_data/aws-fpga/sdk_setup.sh
 
#### Build the [runtime library](../../../runtime):

    $ cd $FLETCHER_RUNTIME_DIR
    $ make

#### Build the example:

    $ cd $FLETCHER_PLATFORM_DIR/aws-f1/cl_arrow/software/runtime/regexp
    $ make

#### Run the example:

    $ sudo ./regexp <no. rows>

