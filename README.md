# Fletcher: A framework to integrate FPGA accelerators with Apache Arrow

[![Build Status](https://travis-ci.org/johanpel/fletcher.svg?branch=master)](https://travis-ci.org/johanpel/fletcher)
[![pipeline status](https://gitlab.com/mbrobbel/fletcher/badges/master/pipeline.svg)](https://gitlab.com/mbrobbel/fletcher/commits/master)

Fletcher is a framework that helps to integrate FPGA accelerators with tools and
frameworks that use Apache Arrow in their back-ends.

[Apache Arrow](https://arrow.apache.org/) specifies an in-memory format for
data and provides libraries to various languages to interface with the data in
that format. The format prevents the need for serialization and through the
libraries Arrow, zero-copy interprocess communication is possible. Languages
that have Arrow libraries (under development) include C, C++, Go, Java,
JavaScript, Python, Ruby and Rust.

While many software projects can benefit from these advantages, also hardware
accelerated applications have seen serious serialization bottlenecks. Fletcher
focuses on FPGA accelerators. Through Fletcher and Arrow, interfacing
efficiently between FPGA and language runtime is made available to all the
supported languages.

Given an Arrow Schema (description of a tabular datastructure), Fletcher
generates the following:

* An **easy-to-use hardware interface** for the functional part of the
accelerator:
  * You provide a range of Arrow RecordBatch indices (rather than byte address)
  * You receive streams of the datatype specified by the schema (rather than
    bus words)
  * No pointer arithmetic, reordering, buffering, etc.. required - Fletcher does
    this for you.
* A **template** for the functional part of accelerator (to be implemented
  manually or using high-level synthesis)
  * You connect directly to streams of data from/to your RecordBatch rather than
  some memory bus interface.
  * This allows you to immediately work with stream arguments (in e.g. Vivado
    HLS `hls::stream<type>`) to HLS functions, without the need to pre-process
    the data.

<img src="fletcher.svg">

## Current state
Our framework is functional, but in early stages of development. It currently
supports the following features:

### Apache Arrow support
* Fletcher currently supports:
  * Reading/writing an Arrow Schema created from any combination of:
    - Fixed-width primitives
    - Lists
    - Structs
* Validity bitmaps:


* We are working on support for:
  - Sparse and dense unions
  - Dictionaries
  - Chunked tabular structures (`Arrow::Table`)

### Platform support
* Our __core hardware descriptions__ are vendor independent; __we don't use any
  vendor IP__.
  * You can simulate a Fletcher based design without a specific target platform.
  * Tested simulators include Questa/Modelsim, GHDL and XSIM.
* We provide top-level wrappers for the following platforms:
  * [Amazon's EC2 f1](https://github.com/aws/aws-fpga) platform.
  * [OpenPOWER's CAPI SNAP framework](https://github.com/open-power/snap).
  * Our bus interconnect is similar to AXI, so it should be easy to integrate
    in many existing platforms.

## Further reading
  * [Fletcher wrapper generator](codegen/fletchgen) - The wrapper generator
    converts Arrow schema's to wrappers around ArrayReaders/ArrayWriters.
    It also provides instantiation templates for your hardware accelerator
    implementation for a HDL or HLS design flow.
  * [Host-side run-time libraries](runtime) - How to integrate host-side
    software with Fletcher.
  * [Array Readers/Writers](hardware) - The workhorses of Fletcher, that
    implement the actual hardware interface for reading and writing from/to
    Arrow Arrays. Read this if you want to go in depth.

## Example projects  
  * [Simple column sum](examples/sum)
  * [Regular Expression Matching](examples/regexp)
  * [String writer](examples/stringwrite)
  * [K-Means clustering](examples/k-means)

External projects using Fletcher:
  * [Posit BLAS operations](https://github.com/lvandam/posit_blas_hdl)
  * [Posit PairHMM](https://github.com/lvandam/pairhmm_posit_hdl_arrow)
