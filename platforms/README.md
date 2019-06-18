# Fletcher platform-specific libraries

Currently there are two FPGA platforms supported by Fletcher:
* [AWS EC2 f1](aws-f1)
* [CAPI SNAP](snap)

A third library exists, named [Echo](echo), that can be used for debugging purposes or as a reference implement a new platform 
libraries. This implementation simply prints out any commands that a language run-time library requests on the standard
output.

If you want to use a specific platform, you can build and install the libraries in the runtime folder of the specific 
platform.
