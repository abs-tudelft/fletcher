# Regular Expression Matching example on CAPI SNAP

### NOTE: this has only been tested on a Power8 machine with an ADKU3 (Kintex Ultrascale) device.

This example wraps the Regular Expression Matching example for CAPI SNAP. Please read 
[the documentation on this example](../../../example/regexp) first.

Also if this is the first time using CAPI SNAP, it's recommended to go through the HDL 
design flow first. At least try to build and run the `hdl_example` action 
[in their repository](https://github.com/open-power/snap).

This implementation uses N=8 units that perform 16 regular expressions each on the same
data stream.

One of the advantages of using CAPI is that we don't need to copy any buffers to on-board
memory, but we can just process the data as it streams in. That is because CAPI provides
an address translation service which allows the FPGA to use the same virtual address space
as the program that controls it, which in our case, is the host side implementation that
can load a table in the Arrow format. Furthermore, this application is fully streamable,
so as long as we can have enough data sinks, the application throughput is equal to the
bandwidth to the host-side memory.

### Design files description

| File                   | Description                                                                                                       |
| :--------------------- | :---------------------------------------------------------------------------------------------------------------- |
| hw/action_wrapper.vhd_source  | SNAP default "action" wrapper. Look at the SNAP repository to figure out why it's using .vhd_source. |
| hw/action_regexp.vhd   | The wrapper for this implementation. It provides access to SNAP required MMIO and instantiates the RegExp top level |

You could use this project as a baseline for your own projects.

# Requirements

### Clone the repository and set up environmental variables
    $ git clone https://github.com/johanpel/fletcher.git
    $ cd fletcher
    $ source env.sh
    
# Simulate using Vivado XSIM

#### Install the CAPI SNAP development kit.

#### Make the snap_config
    
    $ cd snap
    $ make snap_config
    
#### Point the ACTION_ROOT in snap_env.sh to this folder.

    $ vim snap_env.sh
    
    ACTION_ROOT=$FLETCHER_PLATFORM_DIR/snap/regexp

#### Set up the simulation
    
    $ make model
    
#### Run the simulation

    $ make sim
    
#### In the new terminal that pops up run:

    $ snap_maint -vv
    
#### Run the simulation

    $ $FLETCHER_PLATFORM_DIR/snap/regexp/sw/snap_regexp
    
* To do: SNAP allows for easy hardware/software cosimulation. We can also use the normal
  run time software in fletcher/example/regexp to simulate.

# Build
    
    $ make image
    
# Run on a CAPI enabled machine

#### Clone this repository and the SNAP repository on your CAPI enabled machine.
 
#### Build the [runtime library](../../../runtime) with the PLATFORM_SNAP option set to ON:

    $ cd $FLETCHER_RUNTIME_DIR
    $ mkdir build
    $ cd build
    $ cmake .. -DPLATFORM_SNAP=ON
    $ make
    $ sudo make install

#### Build the example for RUNTIME_PLATFORM=2 (SNAP)

    $ cd $FLETCHER_EXAMPLES_DIR/regexp/software
    $ mkdir build
    $ cd build
    $ cmake .. -DRUNTIME_PLATFORM=2
    $ make

#### Run the example:

    $ sudo ./regexp 

