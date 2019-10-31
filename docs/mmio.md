# MMIO Registers

### Table of Contents
1. [Introduction](#introduction)
2. [Default registers](#default-registers)
3. [Schema-derived registers](#schema-derived-registers)
4. [Custom registers](#custom-registers)
5. [Profiling registers](#profiling-registers)

# Introduction
Fletcher currently uses MMIO to pass control information (status, control, buffer addresses, user arguments, etc...) to 
the accelerator during run-time.

Several registers are fixed. Other registers are derived from the Arrow schema and the number of application-specific 
registers required. All registers are 32-bits. The addressing of the registers shown here is per register, not per byte 
as used in for example AXI4-lite. If you are using AXI4-lite you have to multiply the addresses by 4.

In the following definition read/write access is from the context of the host system.
The Fletcher run-time libraries will set these register automatically on the host-side during run-time, given a
bunch of RecordBatches. See [the run-time documentation](../runtime/README.md).

Handling of MMIO registers in hardware is done through the [vhdmmio](https://github.com/abs-tudelft/vhdmmio) tool. 
`fletchgen` will automatically run `vhdmmio` for you when it generates an interface.
`vhdmmio` will generate documentation specific to the registers of your design.
Once you've generated a design, check out the `vhdmmio-doc` sub-folder.
There will be an `index.html` that you can open and read.

Below, it will be explained what registers exist in general. Note that for a specific design, it will be easier
to read the documentation that `vhdmmio` generates.

## Default registers

The default (fixed) registers are as follows.

| Address (decimal) | Name      | Read / Write | Description                                                       |
|-------------------|-----------|--------------|-------------------------------------------------------------------|
| 0                 | control   | Read & Write | Used to signal start, stop, reset, etc. to the accelerator.       |
| 4                 | status    | Read-only    | Used to signal accelerator status to host: idle, busy, done, etc. |
| 8                 | return0   | Read-only    | Return value register 0.                                          |
| 12                | return1   | Read-only    | Return value register 1.                                          |

##### Control register bits
- control(0): start
- control(1): stop
- control(2): reset

##### Status register bits
- status(0): idle
- status(1): busy
- status(2): done

## Schema-derived registers

An Arrow Schema results in a specific in-memory format for an Arrow RecordBatch (or Arrow Table) consisting of Arrow 
Arrays (as columns of the tabular construct). Arrow Arrays of a specific type hold a specific set of Arrow Buffers that 
are related through some hierarchy. The specifics of this can be found in the 
[Arrow format specification](https://arrow.apache.org/docs/memory_layout.html).

Fletcher expects the raw data addresses of these Arrow Buffers to be supplied through MMIO. Therefore, the hierarchy of 
Arrow Buffers must first be flattened. This is done according to the currently following order at one level of 
hierarchy:

- validity buffer
- offsets buffer
- values buffer
- \<child buffers\>

To flatten any child buffers, a depth-first traversal of the hierarchy is applied. 

The implementation used in both Fletchgen and the C++ run-time library can be found 
[here](../common/cpp/include/fletcher/arrow-utils.h).

When the number of RecordBatches used in the accelerator design is N and the number of Arrow Buffers used in all 
RecordBatches (either read or write) is M, the register mapping is defined as follows:

| Address (decimal)    | Name             | Read / Write | Description               |
|----------------------|------------------|--------------|---------------------------|
| 16                   | RB0_FIRSTIDX     | Read & Write | RecordBatch 0 First Index |
| 20                   | RB0_LASTIDX      | Read & Write | RecordBatch 0 Last Index  |
| 24                   | RB1_FIRSTIDX     | Read & Write | RecordBatch 1 First Index |
| 28                   | RB1_LASTIDX      | Read & Write | RecordBatch 1 Last Index  |
| ...                  | ...              | Read & Write | ...                       |
| 16 + 4*2(N-1)        | RB(N-1)_FIRSTIDX | Read & Write | RecordBatch N First Index |
| 16 + 4*(2(N-1) + 1)  | RB(N-1)_LASTIDX  | Read & Write | RecordBatch N Last Index  |

Assuming the number of Arrow Buffers in all used RecordBatches (either read or write) is N, the register mapping after 
the default registers will look as follows:

| Address (decimal)          | Name                    | Read / Write | Description                                   |
|----------------------------|-------------------------|--------------|-----------------------------------------------|
| 16 + 4 * 2N                | Buffer 0 address low    | Read & Write | Least-significant part of buffer 0 address.   |
| 16 + 4 * (2N + 1)          | Buffer 0 address high   | Read & Write | Most-significant part of buffer 0 address.    |
| 16 + 4 * (2N + 2)          | Buffer 1 address low    | Read & Write | Least-significant part of buffer 1 address.   |
| 16 + 4 * (2N + 3)          | Buffer 2 address high   | Read & Write | Most-significant part of buffer 1 address.    |
| ...                        | ...                     | ...          | ...                                           |
| 16 + 4 * (2N + 2(M-1))     | Buffer M-1 address low  | Write-only   | Least-significant part of buffer M-1 address. |
| 16 + 4 * (2N + 2(M-1) + 1) | Buffer M-1 address high | Write-only   | Most-significant part of buffer M-1 address.  |

## Custom registers

Through Fletchge a user may request more custom registers to be mapped to be used for their kernel implementation.
This is done using the `--reg` flag, following a space-seperated list of strings of the following format:

```<behavior>:<width>:<name>:<init>```

Where:
* `<width>` is the bit-width of the register.
* `<behavior>` is one character from the following options:
  * `c` : (control) register content is controlled by host-side software.
  * `s` : (status) register content is set by the hardware kernel, and sent to the host as status information.
* `<name>` is the name of the register.
* `<init>` is optional, and can be used to automatically write to the register in the initialization during simulation. 
           Init must be a hexadecimal value in the form of 0x01234ABCD.

The first custom kernel register will appear at the next free multiple-of-4 address, after the schema-derived registers.
Any next custom kernel register address will be the next free multiple-of-4 address, after the previous custom register.
The address space used is always rounded up to a multiple of 4 bytes, and depends on the bit-width of the register.

Suppose the next free address after the schema-derived registers is `C`, then the register map of custom registers
supplied through `fletchgen` using `--reg c:16:cat s:64:dog s:32:fish` is:

| Address (decimal) | Name     | Read/Write   | Description                                         |
|-------------------|----------|--------------|-----------------------------------------------------|
| C                 | cat      | Read & Write | Custom register 0 (taking 4 bytes of address space) |
| C + 4             | dog      | Read-only    | Custom register 1 (taking 8 bytes of address space) |
| C + 12            | fish     | Read-only    | Custom register 2 (taking 4 bytes of address space) |
| ...               | ...      | ...          | ...                                                 |

## Profiling registers
Through Fletchgen (through meta data supplied with schema fields) it is possible to profile streams to the kernel.
The Arrow field should be supplied with the key-value pair metadata: `{"fletcher_profile", "true"}`.
The profiling registers are inserted at the next free multiple-of-4 address after the custom registers.
Suppose the next free multiple-of-4 address after the custom registers is P, then the register map will look as follows:

| Address (decimal) | Name                    | Read/Write   | Description       |
|-------------------|-------------------------|--------------|-------------------|
| P                 | Profile_enable          | Read & Write | Setting '1' to bit 0 enables the profiling components. |
| P + 4             | Profile_clear           | Read & Write | Writing '1' to bit 0 clears the profiling component counters. |
| P + 8             | `<R>_<F>_<I>_elements`  | Read-only    | Number of elements transferred. |
| P + 12            | `<R>_<F>_<I>_valids`    | Read-only    | Number of cycles stream was valid. |
| P + 16            | `<R>_<F>_<I>_readies`   | Read-only    | Number of cycles stream was ready. |
| P + 20            | `<R>_<F>_<I>_transfers` | Read-only    | Number of cycles stream was handshaked. |
| P + 24            | `<R>_<F>_<I>_packets`   | Read-only    | Number of handshaked `last` signals. |
| P + 28            | `<R>_<F>_<I>_cycles`    | Read-only    | Number of cycles profiler was enabled. |
| ...               | ...                     | ...          | ... |

Where:
* `<R>`: RecordBatch name.
* `<F>`: Field name.
* `<I>`: Stream index. Arrow types can generate multiple streams per field, so this is the flattened index of the 
         stream. For example, for the `utf8` type of Arrow, the first stream is the length stream (index 0) and the 
         second stream is the values stream (index 1).
