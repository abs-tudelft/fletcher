# Regular Expression Matching example on AWS F1

This implementation uses the hardware description 
[you can read about here](../../../examples/regexp).

This subfolder follows the structure of projects on the 
[AWS EC2 FPGA Hardware and Software Development Kits](https://github.com/aws/aws-fpga).

If you are totally unfamiliar with the examples there, it is highly
recommended to follow some of the guides on that repository first. At 
least try to build and run the "Hello World" example.

On the master side, the bus arbiter/interconnect is connected to an 
AXI interconnect that allows the PCI master interface of the Shell to 
write to the DDR controllers (DMA), and allows the ArrayReaders to read from 
them.

Because the Amazon Shell does not provide any address translation 
functionality, we have to make one copy of the Arrow buffers into the 
on-board DDR, because it would be infeasible to resolve physical 
addresses of the host memory everytime we cross a page boundary. 
Furthermore, the copy throughput offered by the shell is a bit low 
(just over 2 GiB/s). Amazon appears to be working on increasing this.

### Design files description

| File                   | Description                                                                                                       |
| :--------------------- | :---------------------------------------------------------------------------------------------------------------- |
| cl_arrow.sv            | Top level design instantiating `arrow_regexp` and AXI interconnect between PCI and DDR interface for DMA.         |
| cl_arrow_pkg.sv        | Package containing interfaces used in the top-level                                                               |
| cl_arrow_defines.vh    | Definitions used in the top-level                                                                                 |
| cl_id_defines.vh       | IDs used in the top-level                                                                                         |
| ip/                    | A folder containing the AXI interconnect IP configurations. You must generate them first before simulation (see below). |

You could use this project as a baseline for your own projects that just use the DRAM DMA.

# Requirements

This design was tested with:

* [AWS EC2 FPGA Hardware and Software Development Kits](https://github.com/aws/aws-fpga) 
  version 1.4.1RC (commit 8847d31) and its recommended Xilinx Vivado version

### Clone the repository and set up environmental variables
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
    $ cd $FLETCHER_PLATFORM_DIR/aws-f1/regexp
    $ export CL_DIR=$(pwd)

#### Generate the Xilinx IP output products for the AXI interconnects
    $ source generate_ip.sh
    
#### Set up the simulation
    $ cd verif/scripts
    $ make TEST=test_regexp
    
This sets up the simulation only. For normal CL designs this also starts and runs the simulation, but we've disabled this.

#### Run the simulation with GUI
    $ cd ../sim/test_regexp/
    $ xsim tb -gui

#### Run the simulation without GUI
    $ cd ../sim/test_regexp/
    $ xsim tb

#### Expected output
Eventually you should see the status register go from 0x0000FFFF (units are busy) to 0xFFFF0000 (units are done).
The simulation will poll for this status value on the slave interface.
The result (number of matches to each regular expression) will appear on the result registers.
The default test dataset that is being used is a file with some strings; [test.txt found here](../../../examples/regexp/hardware).
For this default test dataset, each regular expression should match twice in the file.
Therefore, after the tiresome DDR simulation models are finally initialized, it should not take too long to produce the output of the simple test:
<pre>
[            42702000] : UserCore status: ffff0000
[            42702000] : UserCore completed 
[            42722000] : Number of matches for RegExp  0:  2
[            42742000] : Number of matches for RegExp  1:  2
[            42762000] : Number of matches for RegExp  2:  2
[            42782000] : Number of matches for RegExp  3:  2
[            42802000] : Number of matches for RegExp  4:  2
[            42822000] : Number of matches for RegExp  5:  2
[            42842000] : Number of matches for RegExp  6:  2
[            42862000] : Number of matches for RegExp  7:  2
[            42882000] : Number of matches for RegExp  8:  2
[            42902000] : Number of matches for RegExp  9:  2
[            42922000] : Number of matches for RegExp 10:  2
[            42942000] : Number of matches for RegExp 11:  2
[            42962000] : Number of matches for RegExp 12:  2
[            42982000] : Number of matches for RegExp 13:  2
[            43002000] : Number of matches for RegExp 14:  2
[            43022000] : Number of matches for RegExp 15:  2
[            43042000] : Return register HI:           0
[            43062000] : Return register LO:           2
[            43662000] : Checking total error count...
[            43662000] : Detected   0 errors during this test
[            43662000] : Checking protocol checker error status...
[            43662000] : *** TEST PASSED ***
</pre>

Be aware that Vivado XSIM probably just crashes at the end, dumping a stack trace into the terminal.
This is normal behaviour of Vivado XSIM.
The simulation is still completed successfully and the waveforms can be viewed in the XSIM GUI if desired.

# Build
    $ cd $FLETCHER_PLATFORM_DIR/aws-f1/regexp
    $ export CL_DIR=$(pwd)
    $ cd build/scripts

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

* Make sure that your instance follows the requirements mentioned above, including sourcing the environment variables script.

* Load the FPGA image, follow the instructions from Amazon.

* Source the `sdk_setup.sh` script in the Amazon repository. On an F1 instance using the 
  FPGA AMI, this might already reside in the `~/src/project_data/aws-fpga` directory:

#### Source the Amazon sdk_setup.sh script:

    $ source ~/src/project_data/aws-fpga/sdk_setup.sh
 
#### Build the [runtime library](../../../runtime) with the PLATFORM_AWS option set to ON:

    $ cd $FLETCHER_RUNTIME_DIR
    $ mkdir build
    $ cd build
    $ cmake .. -DPLATFORM_AWS=ON
    $ make
    $ sudo make install

#### Build the example for RUNTIME_PLATFORM=1 (AWS)

    $ cd $FLETCHER_EXAMPLES_DIR/regexp/software
    $ mkdir build
    $ cd build
    $ cmake .. -DRUNTIME_PLATFORM=1
    $ make

#### Run the example:

    $ sudo ./regexp

