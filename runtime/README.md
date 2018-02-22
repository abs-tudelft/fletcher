# Fletcher host runtime library

This library is meant to be used on the host-machine to interface with the FPGA 
accelerator by providing the library with Arrow Columns.

Please take a look at the [AWS EC2 F1 regular expression matching example](../platforms/aws-f1/regexp)
and its [source code](../example/regexp) on how to use this library in your source code.

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

coming soon...
    
## Clone the repository and set up environmental variables

    $ git clone https://github.com/johanpel/fletcher.git
    $ cd fletcher
    $ source env.sh

## Create a build directory

    $ cd runtime
    $ mkdir build
    $ cd build
    
## Invoke CMake with your prefered platform(s):
  
### Example without any platform support:

    $ cmake .. 
    $ make
    $ sudo make install
    
This will only include the "echo" platform which simply outputs any commands to your 
Hardware Accelerated Function on the standard output. Can be useful for debugging.
    
### Example with AWS EC2 F1 support:

    $ cmake .. -DPLATFORM_AWS=ON
    $ make
    $ sudo make install

To do this properly, make sure the sdk_setup script has been sourced (see above).
