# Fletcher host runtime library

This library is meant to be used on the host-machine to interface with the FPGA 
accelerator by providing the library with Arrow Columns.

Please take a look at the examples for the platforms:

* [AWS EC2 F1](../platforms/aws-f1/regexp)
* [CAPI SNAP](../platforms/snap/regexp)

The source code of the run-time host program can be found [here](../example/regexp).
Check it out for an example on how to use this library in your source code.

# Build

## Determine what platform support you want to include in the run-time library

### For Amazon EC2 F1

Clone the repository:

    $ git clone https://github.com/aws/aws-fpga
    $ cd aws-fpga
    
Source the sdk_setup script:

    $ source sdk_setup.sh

Use the CMake option: `-DPLATFORM_AWS=ON`

### For CAPI SNAP

Clone the repository

    $ https://github.com/open-power/snap.git
    $ cd snap
    
Set up the SNAP environment using `make snap_config`. See the SNAP repository for more 
help.
    
Use the CMake option: `-DPLATFORM_SNAP=ON`
    
## Clone the repository and set up environmental variables

    $ git clone https://github.com/johanpel/fletcher.git
    $ cd fletcher
    $ source env.sh

## Create a build directory

    $ cd runtime
    $ mkdir build
    $ cd build
    
## Invoke CMake with your prefered platform(s):
  
### Example without any platform support

    $ cmake .. 
    $ make
    $ sudo make install
    
This will only include the "echo" platform which simply outputs any commands to your 
Hardware Accelerated Function on the standard output. Can be useful for debugging.
    
### Example with AWS EC2 F1 support

    $ cmake .. -DPLATFORM_AWS=ON
    $ make
    $ sudo make install

To do this properly, make sure the sdk_setup script has been sourced (see above).

### Example with CAPI SNAP support

    $ cmake .. -DPLATFORM_SNAP=ON
    $ make
    $ sudo make install

To do this properly, make sure SNAP_ROOT has been set to point to the CAPI SNAP directory.
