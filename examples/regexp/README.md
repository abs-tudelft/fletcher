# Regular Expression Matching example hardware description

This is an example in which some [ColumnReaders](../../../hardware) are
used to read a column with UTF8 strings. The config string for the 
columns is therefore "listprim(8)", to generate an interface to a 
non-nullable list of non-nullable 8-bit wide elements.

The design instantiates N of these ColumnReaders, attached to 
N regular expression matching units, that can all work in parallel.

N depends on the platform, how much room there is in the FPGA, etc.
Currently, for AWS EC2 F1 instances N=16 and for CAPI SNAP on a ADKU3 N=8.

The ColumnReaders are attached to our internal bus arbiter/interconnect,
but we inserted an `axi_read_converter` to convert the `bsize` 
(Burst Size) signal properly to match the AWS Shell requirement of 
setting this to 2^6=64 bytes fixed burst beat size. This is because 
the ColumnReaders bus data width is 32-bits. `axi_read_converter` also 
converts our internal bus burst lengths to AXI specification. Furthermore, 
it includes a read response FIFO as we don't want to lock up the arbiter
dumping bursts into the ColumnReaders, which are less wide.

## Design files description

### Hardware implementation:

| File                            | Description                                                                                                                |
| :------------------------------ | :------------------------------------------------------------------------------------------------------------------------- |
| hardware/animals/*.vhd          | The regular expression matchers generated using [VHDRE](../../codegen/vhdre). They all match to some names of pet animals. |
| hardware/arrow_regexp.vhd       | The top-level for this platform-independent design. |
| hardware/arrow_regexp_unit.vhd  | One regular expression matching unit which is instantiated N times to work in parallel. |
| hardware/arrow_regexp_pkg.vhd   | The package for this example containing some constants and definitions. |
| hardware/axi_read_converter.vhd | A helper unit that converts internal bus signals to AXI spec and converts wide bus interfaces to smaller bus interfaces. |

### Software implementation:

| File                            | Description                                                                                                                |
| :------------------------------ | :------------------------------------------------------------------------------------------------------------------------- |
| software/regexp.cpp             | The main file for this example |
| software/RegExUserCore.cpp      | The implementation of the UserCore abstract class |
| software/RegExUserCore.h        | Header for previous item |


# Build

### 1. First build the [runtime library](../../../runtime).

### 2. Build the example

You have to pick a run-time platform to build the example host-side software for.

Currently you can choose the CMake option RUNTIME_PLATFORM to be:

* 0 : Echo platform: just uses the STDIO to simulate the FPGA
* 1 : [AWS EC2 F1](../../platforms/aws-f1/)
* 2 : [CAPI SNAP](../../platforms/snap/)

Make sure to compile the run-time library with support for that platform first.

Proceed to build this application:

    $ cd $FLETCHER_EXAMPLES_DIR/regexp/software
    $ mkdir build
    $ cd build
    $ cmake .. -DRUNTIME_PLATFORM=?
    $ make
    
Make sure to replace ? with your chosen platform.

### 3. Run the example:

* Note: you probably need sudo rights for most platforms:

    $ ./regexp 
    
Optional parameters:

    $ ./regexp <no. strings> <no. repeats> <experiment mask> <num. threads>
    

