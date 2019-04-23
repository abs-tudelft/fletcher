# Regular Expression Matching example hardware description

This is an example in which some [ArrayReaders](../../hardware) are
used to read an Arrow Array with UTF8 strings. The config string for the 
ArrayReader is therefore "listprim(8)", to generate an interface to a 
non-nullable list of non-nullable 8-bit wide elements.

The design instantiates N of these ArrayReaders, attached to 
N regular expression matching units, that can all work in parallel.

N depends on the platform, how much room there is in the FPGA, etc.
Currently, for AWS EC2 F1 instances N=16 and for CAPI SNAP on a ADKU3 N=8.

The ArrayReaders are attached to our internal bus arbiter/interconnect,
but we inserted an `axi_read_converter` to convert the `bsize` 
(Burst Size) signal properly to match the AWS Shell requirement of 
setting this to 2^6=64 bytes fixed burst beat size. This is because 
the ArrayReaders bus data width is 32-bits. `axi_read_converter` also 
converts our internal bus burst lengths to AXI specification. Furthermore, 
it includes a read response FIFO as we don't want to lock up the arbiter
dumping bursts into the ArrayReaders, which are less wide.

## Design files description

### Hardware implementation:

| File                            | Description                                                                                                                |
| :------------------------------ | :------------------------------------------------------------------------------------------------------------------------- |
| hardware/animals/*.vhd          | The regular expression matchers generated using [VHDRE](../../codegen/vhdre). They all match to some names of pet animals. |
| hardware/arrow_regexp.vhd       | The top-level for this platform-independent design. |
| hardware/arrow_regexp_unit.vhd  | One regular expression matching unit which is instantiated N times to work in parallel. |
| hardware/arrow_regexp_pkg.vhd   | The package for this example containing some constants and definitions. |

### Software implementation:

| File                            | Description                                                                                                                |
| :------------------------------ | :------------------------------------------------------------------------------------------------------------------------- |
| software/src/regexp.cc          | The main file for this example |
| software/src/regex-usercore.cc  | The implementation of some convenience function of this specific application |
| software/src/regex-usercore.h   | Header for previous item |


# Build

### 1. First build and install, on the host machine:
 * The [platform agnostic runtime library](../../runtime).
 * The [platform-specific run-time library](../../platforms).

### 2. Build the example on the host machine.

Proceed to build this application:

    $ cd examples/regexp
    $ mkdir build
    $ cd build
    $ cmake ..
    $ make
    
### 3. Run the example:

```
./regexp
```

* Note: you probably need sudo rights for most platforms: 
    
Optional parameters:
```
./regexp <no. strings> <no. repeats> <experiment mask> <num. threads>
```
