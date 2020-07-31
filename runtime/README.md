# Fletcher host-side platform agnostic run-time libraries

Host-side run-time libraries exist for the following languages:

* [C++](cpp) [Python](python)

These libraries are FPGA platform-agnostic, so you can develop on top of them
independent of the final FPGA platform your code will run on.

These libraries provide convenience wrappers around platform specific libraries,
that only implement very basic functions. [The platform-specific run-time
libraries can be found here.](../platforms)
