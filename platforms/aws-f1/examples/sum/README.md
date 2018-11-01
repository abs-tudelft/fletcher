# Getting Started: Simple Summing on AWS-f1

To run the simple summing example on an Amazon f1 FPGA instance,
the *axi_top* entity must be mapped to an aws-fpga project,
and the host software must be compiled with AWS support.

## Requirements

  * A development environment with Vivado 2017.4. The Amazon
[FPGA Developer AMI](https://github.com/aws/aws-fpga#devAmi)
can be used if a local Vivado installation is not available.
  * C++14 compatible compiler (tested with GCC 5.5)
  * Boost development libraries
      * system
      * filesystem
      * regex
      * program_options

## Set up hardware/software development environment

For more information about the hardware development environment, refer to
the [documentation](https://github.com/aws/aws-fpga/blob/master/hdk/README.md).
The hardware development environment is needed when synthesizing or
simulating the design. The software development environment is needed when
compiling or running the host software and requires root privileges to install.

    $ curl "https://codeload.github.com/aws/aws-fpga/tar.gz/v1.4.2" \
        | tar --extract --gzip
    $ cd aws-fpga-1.4.2
    $ source hdk_setup.sh
    $ source sdk_setup.sh

## Create the project

A project can be created by adapting one of the examples delivered with
aws-fpga, or use the script [project-generate.sh](../project-generate.sh).
Important files hat need to be modified include:

  * build/scripts/synth_cl_arrow
  * build/scripts/encrypt.tcl
  * verif/scripts/top_verilog.vivado.f
  * verif/scripts/top_vhdl.vivado.f

After creating the project, set the CL_DIR environment variable.

    $ cd "$FLETCHER_PLATFORM_DIR/aws-f1/sum"
    $ export CL_DIR=$(pwd)

## Create testbench

A test bench can be created that simulates the FPGA card in its entirety.
An example testbench can be found in
[verif/tests/test_arrow_sum.sv](./verif/tests/test_arrow_sum.sv)

## Generate IP

The AXI IP needs to be generated before continuing with the rest of the steps.

    $ cd "$CL_DIR"
    $ source generate_ip.sh

## Run test

At the time of writing, xsim always exits with a segmentation fault.
The test itself runs fine though.

    $ cd "$CL_DIR/verif/scripts"
    $ make TEST=test_arrow_sum

To run the test in a GUI:

    $ cd "$CL_DIR/verif/sim/vivado/test_arrow_sum"
    $ xsim tb -gui

## Synthesize

Optionally add the `-foreground` switch to keep the synthesis running
in your shell. Synthesis will take about one to several hours,
depending on your hardware.

    $ cd "$CL_DIR/build/scripts"
    $ ./aws_build_dcp_from_cl.sh -foreground

## Create FPGA image

First set up access to Amazon via cli tools. And create a bucket and
directory to store your designs. Refer to the
[documentation](https://aws.amazon.com/cli/).
Then, upload your design file to an Amazon S3 bucket and create
an image from it. The unique afi id will be printed on the command line.

    $ designlocal=$(ls "$CL_DIR/build/checkpoints/to_aws/"*.tar | tail -n 1)
    $ designfile=$(basename "$designlocal")
    $ aws s3 cp \
        "$CL_DIR/build/checkpoints/to_aws/$designfile" \
        "s3://my_bucket/my_directory/"
    $ aws ec2 create-fpga-image \
        --name my_name \
        --description my_description \
        --input-storage-location Bucket=my_bucket,Key="my_directory/$designfile" \
        --logs-storage-location Bucket="my_bucket",Key="my_log_directory" \

You can delete the file from the S3 bucket after the image is created.

To see the state of the synthesis,
note the afi-id that was output by the previous command:

    $ aws ec2 describe-fpga-images \
        --fpga-image-ids "$afi-id"

To list all your FPGA images:

    $ aws ec2 describe-fpga-images \
        --owner self

## Compile run-time software

If you have not done so yet, start an AWS-f1 instance and continue the next
steps on the instance after setting up the SDK environment as described in
the first step of this readme.

Compile the fletcher run-time library with support for AWS:

    $ cd "$FLETCHER_RUNTIME_DIR"
    $ mkdir build
    $ cd build
    $ cmake \
        -DPLATFORM_AWS=ON \
        -DENABLE_DEBUG=ON \
        ..
    $ make install

Compile the host software:

    $ cd "$FLETCHER_EXAMPLES_DIR/sum/software"
    $ mkdir build
    $ cd build
    $ cmake \
        -DRUNTIME_PLATFORM=1 \
        ..
    $ make

## Load FPGA image

To load an FPGA image inside an f1 instance, install management software
and load system drivers. The management software is installed by sourcing the
`sdk_setup.sh` script, you should have done this in a previous step already.

    $ cd "$AWS_FPGA_REPO_DIR"
    $ cd sdk/linux_kernel_drivers/edma
    $ make
    $ sudo make install
    $ sudo modprobe edma-drv
    
    $ sudo fpga-clear-local-image -S 0 -H
    $ sudo fpga-load-local-image -S 0 -I agfi-xxxx456789abcxxxx

Finally, [compile](../../../examples/sum/) and run the software:

    $ sudo "$FLETCHER_EXAMPLES_DIR/sum/software/build/sum"
