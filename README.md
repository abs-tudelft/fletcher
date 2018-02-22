# Fletcher: A framework to integrate FPGA accelerators with Apache Arrow

Fletcher is a framework that helps to integrate FPGA accelerators with tools that use
Apache Arrow in their back-ends.

<img src="fletcher.svg">

[Apache Arrow](https://arrow.apache.org/) specifies an in-memory format for data and 
provides libraries to various languages to interface with the data in that format. The
format prevents the need for serialization and through the libraries Arrow, zero-copy 
interprocess communication is possible.

While many software projects can benefit from these advantages, also hardware accelerated
applications have seen serious bottlenecks, especially when working with execution 
frameworks that employ implicit memory mangement, because they always require some sort of
serialization to take place. Therefore, if hardware accelerators such as FPGAs can make 
use of the Arrow format, serialization bottlenecks may be alleviated. FPGA accelerators 
are the main focus of this project. (If you are looking for GPGPU's, some work is being
done as part of the Arrow project already, go check out 
[the Arrow repository](https://github.com/apache/arrow).)

Because the in-memory format of Arrow is standardized, it is possible to generate 
easy-to-use interfaces that allow hardware accelerated functions to refer to the data
through row indices rather than byte addresses. In turn, the hardware accelerated function
can receive one or multiple streams (depending on the type of the data) that have the 
actual representation desired by the designer, and will not just be some bus word with the
elements of interest somewhere in between a bunch of other bytes, forcing you to think
about all the alignment issues that could arise from the vast range of types that you can
express through Arrow. (Not to mention to figure out all the Arrow buffers that may be 
involved.)

We think the two advantages of no serialization and format standardization is paramount to
efficient and highly-programmable deployment of FPGA accelerators in cluster-computing
frameworks and data centers. This is why we've created Fletcher; a framework to integrate
FPGA accelerators with Apache Arrow.

More specifically, you provide an Arrow Schema to an interface generation framework, 
and you get a hardware interface that allows you to refer to data in Arrow tables as row 
indices, in contrast to having to deal with addresses of possibly several nested field 
types, all in hardware. The interface will then provide the user with ordered and aligned
streams of the requested data in the type specified through the schema. 

During run time, you simple pass the Arrow table to the Fletcher run-time library, and any
preperation of the data will be handled by the framework. There are a few software layers 
that abstract platform-specific implementation details. In this way it should be able to 
move over both your hardware and software more easily to another platform.

## Current state
Our framework is functional, but in early stages of development. It currently supports the
following features:

### Apache Arrow support:
* Any Arrow Schema created from any combination of:
  - Fixed-width primitives
  - Lists
  - Structs
* Validity bitmaps are supported.
* Not supported (yet):
  - Unions
  - Dictionaries
  - Chunks

### Platform support:
* Our hardware descriptions are vendor independent; we don't use any vendor IP.
* There is an example project for Amazon EC2 F1 instances
* Our bus interface speaks AXI, so it should be easy to integrate in many existing 
  platforms
* Upcoming: OpenCAPI support

## Credits
This work was mainly performed by people from the Computer Engineering Lab at the Delft 
University of Technology. Most code is written by Jeroen van Straten and Johan Peltenburg.
If you would like to contribute, open issues, make pull requests, or drop us an email 
(<a href='m&#97;il&#116;o&#58;j&#46;w&#37;2Epeltenbur&#103;&#64;%74ud%65&#108;ft&#46;n&#108;'>&#106;&#46;w&#46;pe&#108;ten&#98;&#117;&#114;&#103;&#64;t&#117;d&#101;l&#102;&#116;&#46;n&#108;</a>).

## Further reading
  * [How to generate a Column Reader](hardware). 
    * For the current state of the project, this would be your starting
      point in hardware design.
  * [How to use the host-side run-time library](runtime).
  * [Regular Expression matching example on Amazon EC2 F1](platforms/aws-f1/regexp)
