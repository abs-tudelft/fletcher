# Fletcher: A framework to integrate FPGA accelerators with Apache Arrow

[![pipeline status](https://gitlab.com/mbrobbel/fletcher/badges/master/pipeline.svg)](https://gitlab.com/mbrobbel/fletcher/commits/master)

Fletcher is a framework that helps to integrate FPGA accelerators with tools that use
Apache Arrow in their back-ends.

[Apache Arrow](https://arrow.apache.org/) specifies an in-memory format for data and
provides libraries to various languages to interface with the data in that format. The
format prevents the need for serialization and through the libraries Arrow, zero-copy
interprocess communication is possible. Languages that have Arrow libraries (under development)
include C, C++, Go, Java, JavaScript, Python, Ruby and Rust.

While many software projects can benefit from these advantages, also hardware accelerated
applications have seen serious serialization bottlenecks. Fletcher focuses on FPGA accelerators only.
Through Fletcher and Arrow, efficient FPGA acceleration is made available to all the supported languages.

<sup><sub>(If you are looking for GPGPU's, some work is being done as part of the Arrow project already, go check out
[the Arrow repository](https://github.com/apache/arrow).)</sub></sup>

Given an Arrow Schema (description of a tabular datastructure), Fletcher generates the following:

* An easy-to-use hardware interface for the functional part of the accelerator
  * You provide a range of RecordBatch indices (rather than byte address)
  * You receive streams of the datatype specified in the schema (rather than bus words)
  * No pointer arithmetic, reordering, parallelizing or serializing, buffering, etc.. required!
* A template for the functional part of accelerator (to be implemented manually or with HLS)

<img src="fletcher.svg">

## Current state
Our framework is functional, but in early stages of development. It currently supports the
following features:

### Apache Arrow support:
* Reading/writing an Arrow Schema created from any combination of:
  - Fixed-width primitives
  - Lists
  - Structs
* Validity bitmaps are supported.
* Not supported (yet):
  - Unions
  - Dictionaries
  - Chunks

### Platform support:
* Our core hardware descriptions are vendor independent; __we don't use any vendor IP__.
* [Amazon's EC2 f1](https://github.com/aws/aws-fpga) platform is supported.
* POWER8/9 CAPI 1.0/2.0 FPGA platform is supported through the use of [OpenPOWER's CAPI SNAP framework](https://github.com/open-power/snap).
* Our bus interconnect is similar to AXI, so it should be easy to integrate in many existing platforms.
* Output streams are AXI compatible as well, so it should be easy to integrate e.g. Vivado HLS with Fletcher
output streams through the use of `hls::stream<type>` interfaces.

## Further reading
  * [Fletcher wrapper generator](codegen/fletchgen) - The wrapper generator converts Arrow schema's to wrappers around ColumnReaders/ColumnWriters. It also provides instantiation templates for your hardware accelerator implementation.
  * [How to use the host-side run-time libraries](runtime).

## Example projects  
  * [Simple column sum example](examples/sum).
  * [How to generate a Column Reader](hardware) - A more flexible but low-level hardware design approach, using ColumnReader/ColumnWriters directly.  
  * [Regular Expression matching example](examples/regexp).

## External examples
  * [Posit BLAS operations using Fletcher](https://github.com/lvandam/posit_blas_hdl)
  * [Posit PairHMM using Fletcher](https://github.com/lvandam/pairhmm_posit_hdl_arrow)
