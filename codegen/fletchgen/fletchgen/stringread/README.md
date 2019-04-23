# Simple string read test

This is a simple test for Fletchgen to read strings from an Arrow Recordbatch
in simulation.

The files in this folder contain the following:
<pre>
test.vhd : Accelerator implementation
test.fbs : Schema Flatbuffer file
test.rb  : A RecordBatch based on the schema with some strings (human names)
</pre>

Running fletchgen with:

```console
fletchgen \
  -i test.fbs \
  -o test_wrapper.vhd  \
  -n test \
  -w test_wrapper \
  -s test.fbs \
  -d test.rb \
  --sim sim_top.vhd \
  -x test.srec
```

Will produce:

<pre>
test_wrapper.vhd : Generated wrapper
sim_top.vhd      : Simulation (testbench) top-level
test.srec        : An SREC file for the memory model in simulation.
</pre>

Now, sim_top.vhd can be simulated. There is a TCL script for QuestaSim:

```console
vsim -do stringread.tcl
```

After expanding the UserCore wave group in the wave window, you can change the 
radix of the output data to ASCII and observe the names being streamed into the
accelerator core. To change the radix you may issue the TCL command:

```tcl
property wave -radix ASCII *chars_out_data
```

In this test, the elements per cycle is set to 4, so we will see the first four
characters from right to left, A, l, i and c, on the output:

![Test output](test.png)
