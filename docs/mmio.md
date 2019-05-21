# MMIO Register mapping
Fletcher currently uses MMIO to pass control information (status, control, buffer addresses, user arguments, etc...) to 
the accelerator during run-time.

Several registers are fixed. Other registers are derived from the Arrow schema and the number of application-specific 
registers required. All registers are 32-bits. The addressing of the registers shown here is per register, not per byte 
as used in for example AXI4-lite. If you are using AXI4-lite you have to multiply the addresses by 4.

In the following definition read/write access is from the context of the host system.
The Fletcher run-time libraries will set these register automatically on the host-side during run-time, given a
bunch of RecordBatches. See [the run-time documentation](../runtime/README.md).

## Default registers

The default (fixed) registers are as follows.

| Index | Name      | Read/Write | Description                                                       |
|-------|-----------|------------|-------------------------------------------------------------------|
| 0     | control   | Write-only | Used to signal start, stop, reset, etc. to the accelerator.       |
| 1     | status    | Read-only  | Used to signal accelerator status to host: idle, busy, done, etc. |
| 2     | return0   | Read-only  | Return value register 0.                                          |
| 3     | return1   | Read-only  | Return value register 1.                                          |

#### Control register bits
- control(0): start
- control(1): stop
- control(2): reset

#### Status register bits
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
[here](../common/cpp/src/fletcher/arrow-utils.h).

When the number of RecordBatches used in the accelerator design is N and the number of Arrow Buffers used in all 
RecordBatches (either read or write) is M, the register mapping is defined as follows:

| Index          | Name             | Read/Write | Description               |
|----------------|------------------|------------|---------------------------|
| 4              | RB0_FIRSTIDX     | Write-only | RecordBatch 0 First Index |
| 5              | RB0_LASTIDX      | Write-only | RecordBatch 0 Last Index  |
| 6              | RB1_FIRSTIDX     | Write-only | RecordBatch 1 First Index |
| 7              | RB1_LASTIDX      | Write-only | RecordBatch 1 Last Index  |
| ...            | ...              | ...        | ...                       |
| 4 + 2(N-1)     | RB(N-1)_FIRSTIDX | Write-only | RecordBatch N First Index |
| 4 + 2(N-1) + 1 | RB(N-1)_LASTIDX  | Write-only | RecordBatch N Last Index  |

Assuming the number of Arrow Buffers in all used RecordBatches (either read or write) is N, the register mapping after 
the default registers will look as follows:

| Index               | Name                    | Read/Write | Description                                   |
|---------------------|-------------------------|------------|-----------------------------------------------|
| 4 + 2N              | Buffer 0 address low    | Write-only | Least-significant part of buffer 0 address.   |
| 4 + 2N + 1          | Buffer 0 address high   | Write-only | Most-significant part of buffer 0 address.    |
| 4 + 2N + 2          | Buffer 1 address low    | Write-only | Least-significant part of buffer 1 address.   |
| 4 + 2N + 3          | Buffer 2 address high   | Write-only | Most-significant part of buffer 1 address.    |
| ...                 | ...                     | ...        | ...                                           |
| 4 + 2N + 2(M-1)     | Buffer M-1 address low  | Write-only | Least-significant part of buffer M-1 address. |
| 4 + 2N + 2(M-1) + 1 | Buffer M-1 address high | Write-only | Most-significant part of buffer M-1 address.  |

## Custom registers

Through Fletchgen (through meta data supplied with the schema or through command-line parameters) or through hardware 
generics, a user may request more custom registers to be mapped to be used for their accelerator implementation. These
custom registers follow the indices of the schema-derived registers.

| Index         | Name     | Read/Write   | Description       |
|---------------|----------|--------------|-------------------|
| 4 + 2N+2M     | custom0  | User defined | Custom register 0 |
| 4 + 2N+2M + 1 | custom1  | User defined | Custom register 1 |
| ...           | ...      | ...          | ...               |

## Possible future improvements

- Passing schema-derived information (buffer addresses, first and last indices, etc...) could also be implemented 
through memory in the form of work-element descriptors similar
