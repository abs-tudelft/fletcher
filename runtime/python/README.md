# Python wrapper for the Fletcher runtime library
Fletcher is a framework for integrating FPGA accelerators with Apache Arrow that generates easy-to-use and efficient hardware interfaces allowing hardware addressing via table indices rather than byte addresses. Pyfletcher aims to make the Fletcher runtime library available in Python, allowing any Python programmer to easily interface with Fletcher enabled FPGA images. See the [repository](https://github.com/abs-tudelft/fletcher) for using Fletcher to generate hardware.

# Installing
The base pyfletcher library binary wheels can be easily installed on Linux:

```console
pip install pyfletcher
```

In order to use pyfletcher to interface with FPGA's, please install the correct driver for your platform from the [repository](../../platforms). It is recommended to install the echo platform for debugging and testing.

# Building from source
Before installing pyfletcher, you should install Cython, numpy and pyarrow.

```console
pip install Cython numpy pyarrow
python setup.py build install
```
