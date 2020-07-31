# Fletcher runtime library for Python
Fletcher is a framework for integrating FPGA accelerators with Apache Arrow that
generates easy-to-use and efficient hardware interfaces allowing hardware
addressing via table indices rather than byte addresses. Pyfletcher aims to make
the Fletcher runtime library available in Python, allowing any Python programmer
to easily interface with Fletcher enabled FPGA images. See the
[repository](https://github.com/abs-tudelft/fletcher) for using Fletcher to
generate hardware.

# Installing
The base pyfletcher library binary wheels can be easily installed on Linux:

```console
pip install pyfletcher
```

In order to use pyfletcher to interface with FPGA's, please install the correct
driver for your platform from the
[repository](https://github.com/abs-tudelft/fletcher/tree/develop/platforms).
It is recommended to install the echo platform for debugging and testing.

# Building from source
Before installing pyfletcher, you should install Cython, numpy and pyarrow.

```console
pip install Cython numpy pyarrow
```

Install the 
[Fletcher C++ run-time library](https://github.com/abs-tudelft/fletcher/tree/develop/runtime/cpp) 
as follows:

```console
mkdir build
cmake .. -DFLETCHER_PYTHON=ON -DPYARROW_DIR=<pyarrow_install_dir>
make
sudo make install
```

Here, <pyarrow\_install\_dir> should be the path to where pyarrow is installed
on your system. This can easily be found by running the following code in
Python:

    import pyarrow as pa
    print(pa.get_library_dirs())

You can now install pyfletcher.

```console
python setup.py install
```
