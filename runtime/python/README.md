#Python wrapper for the Fletcher runtime library
Fletcher is a framework for integrating FPGA accelerators with Apache Arrow that generates easy-to-use and efficient hardware interfaces allowing hardware addressing via table indices rather than byte addresses. Pyfletcher aims to make the Fletcher runtime library available in Python, allowing any Python programmer to easily interface with Fletcher enabled FPGA images. See the [repository](https://github.com/johanpel/fletcher) for using Fletcher to generate hardware.

#Installing
The base pyfletcher library binary wheels can be easily installed on Linux:

    pip install pyfletcher

In order to use pyfletcher to interface with FPGA's, please install the correct driver for your platform from the [repository](https://github.com/johanpel/fletcher/tree/master/platforms). It is recommended to install the echo platform for debugging and testing.

#Building from source
Coming soon.
