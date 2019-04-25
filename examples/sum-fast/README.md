# Fast Parallel Summing Example

This is an adapted version of the [simple summing](../sum/) example to
take advantage of the resources available on the FPGA.
The array reader is widened from 64 bits to 512 bits, making it return
eight elements per cycle. These are then summed in parallel using an adder tree.
Additional logic was introduced to make this work for inputs which are not a
multiple of eight rows.

This hardware design should be a drop-in replacement for the simple summing
example, since it's host interface is unchanged. It can thus be used with the
[runtime](../sum/software/sum.cpp) of that example.
