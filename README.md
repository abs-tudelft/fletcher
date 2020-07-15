![Fletcher logo](docs/fletcher_notext.svg)

# Fletcher: A framework to integrate FPGA accelerators with Apache Arrow

[![License](https://badgen.net/github/license/abs-tudelft/fletcher)](https://github.com/abs-tudelft/fletcher/blob/develop/LICENSE)
[![Last Commit](https://badgen.net/github/last-commit/abs-tudelft/fletcher/develop)](https://badgen.net/github/last-commit/abs-tudelft/fletcher/develop)

Fletcher is a framework that helps to integrate FPGA accelerators with tools and
frameworks that use Apache Arrow in their back-ends.

[Apache Arrow](https://arrow.apache.org/) specifies an in-memory format
targeting large datasets and provides libraries for various languages to
interface with the data in that format. Arrow prevents the need for
serialization between different language run-times and provides zero-copy
inter-process communication of datasets. Languages that have Arrow libraries
(under development) include C, C++, Go, Java, JavaScript, Python, Ruby and
Rust.

While many software projects can benefit from these advantages, hardware
accelerated applications have also seen serious serialization bottlenecks.
Fletcher focuses on FPGA accelerators. Through Fletcher and Arrow, interfacing
_efficiently_ between FPGA accelerator and high-level language runtimes is made
available to all the supported languages.

Given a set of Arrow [Schemas](https://arrow.apache.org/docs/metadata.html),
Fletcher generates the following:

- A **high-performance, easy-to-use hardware interface** for your accelerator
  kernel:
  - You provide a range indices of your Arrow RecordBatch (rather than byte
    address).
  - You receive (or supply) streams of the data-type specified by the schema
    (rather than bus words).
  - No pointer arithmetic, reordering, buffering, etc.. required - Fletcher
    does this for you, with high throughput (think system bandwidth).
- A **template** for the accelerator kernel (to be implemented manually or
  using high-level synthesis)
  - You connect directly to **streams** of data from/to your RecordBatch rather
    than some memory bus interface.

![Fletcher overview](fletcher.svg)

## Apache Arrow support

- Fletcher currently supports reading/writing from/to multiple Arrow
  RecordBatches with an Arrow Schema created from any (nested) combination of:

  - Fixed-width primitives (ints, float, etc...)
  - Lists (strings, vectors, etc...)
  - Structs
  - Validity bitmaps

- Once the Arrow reference implementation and format specific reaches ensured
  stability (i.e. version 1.0), we would like to support:
  - Sparse and dense unions
  - Dictionaries
  - Chunked tabular structures (`Arrow::Table`)

## Platform support

- Fletcher is **vendor-agnostic**. Our core hardware descriptions and
  generated code are vendor independent; we don't use any vendor IP.
- You can simulate a Fletcher based design without a specific target platform.
- Tested simulators include the free and open-source
  [GHDL](https://github.com/ghdl/ghdl) and the proprietary Mentor Graphics
  Questa/Modelsim, and Xilinx Vivado XSIM.

- We provide top-level wrappers for the following platforms:
  - [Amazon EC2 F1](https://github.com/aws/aws-fpga)
  - [OpenPOWER CAPI SNAP](https://github.com/open-power/snap)
  - Our top-level can be generated to speak AXI, so it should be easy to
    integrate with many existing systems. Requirements for a platform are that
    it provides:
    - An AXI4 (full) interface to memory holding Arrow data structures to
      operate on (data path), and
    - An AXI4-lite interface for MMIO to (control path) registers.

## Current state

Our framework is functional, but at the same time it is under heavy development.

Especially the development branch (which is currently our main branch) is very
active and may break without notice. Some larger examples and the several
supported platforms are quite hard to integrate in a CI pipeline (they would
take multiple days to complete and would incur significant costs for platforms
such as Amazon's EC F1). For now, these larger examples and platform support
resides in separate repositories and are tested against a specific tag of this
repository.

As of 2020, the main developers are focusing on generalizing the Fletcher
framework in the form of Tydi, a streaming interface specification and
toolchain based on some initial findings during the work on Fletcher.
[This project can be found here.](https://github.com/abs-tudelft/tydi)

## Further reading

Tutorials:

- [Simple column sum example](examples/sum/README.md) - The "Hello, World!"
  of Fletcher.

Hardware design flow:

- [Fletcher Design Generator](codegen/cpp/fletchgen/README.md) - The design
  generator converts a set of Arrow Schemas
  to a hardware design and provides templates for your kernel.
- [Hardware library](hardware) - All Fletcher core hardware components used
  by the design generator.

Software design flow:

- [Host-side run-time libraries](runtime) - Software libraries for run-time
  support on the host-machine.

## Example projects

- [Simple column sum example](examples/sum/README.md) - The "Hello, World!"
  of Fletcher.
- [String writer](examples/stringwrite) - Writes at over 10 GB/s to a column
  of strings.
- [Primitive map](codegen/test/primmap) - Maps two primitives to two
  primitives (simulation-only, used in testing).
- [String reader](codegen/test/stringread) - Reads some strings
  (simulation-only, used in testing).

External projects using Fletcher:

- [Regular Expression Matching](https://github.com/abs-tudelft/fletcher-example-regexp)
- [K-Means clustering](https://github.com/abs-tudelft/fletcher-example-kmeans)
- [Posit BLAS operations](https://github.com/lvandam/posit_blas_hdl)
- [Posit PairHMM](https://github.com/lvandam/pairhmm_posit_hdl_arrow)
