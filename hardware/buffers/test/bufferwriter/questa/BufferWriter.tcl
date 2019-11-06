source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

proc print_cases {} {
  echo "Test case names:"
  echo " - 2x32in64outMB1"
  echo " - 4x16in64out"
  echo " - 8x1in64out"
  echo " - 8x64in512out"
  echo " - 32in32out"
  echo " - 32in64out"
  echo " - Default"
  echo " - IndexBS4"
  echo " - IndexBuf"
  echo " - IndexBufMEPC"
}

# BufferWriter testbench setup
proc t {{name "Default"}} {
  compile_sources
  set lcname [string tolower $name]
  set fullname bufferwriter_${lcname}_tc
  set groups [list]
  lappend groups [list "Testbench"         sim:/$fullname/tb/*                          ]
  lappend groups [list "Buffer Writer"     sim:/$fullname/tb/uut/*                      ]
  lappend groups [list "Preprocessor"      sim:/$fullname/tb/uut/pre_inst/*             ]
  lappend groups [list "Padder"            sim:/$fullname/tb/uut/pre_inst/padder_inst/* ]
  lappend groups [list "CmdGenBusReq"      sim:/$fullname/tb/uut/cmdgen_inst/*          ]
  lappend groups [list "Bus Write Buffer"  sim:/$fullname/tb/uut/buffer_inst/*          ]
  simulate work.$fullname $groups
  print_cases
}

# Bus write infrastructure test
proc b {} {
  compile_sources
  simulate work.buswritearbiter_tb {{"Testbench" sim:/buswritearbiter_tb/*                  }
                                    {"Arbiter"   sim:/buswritearbiter_tb/uut/arb_inst/*     }
                                    {"Buffer A"  sim:/buswritearbiter_tb/mst_a_buffer_inst/*}
                                    {"Buffer B"  sim:/buswritearbiter_tb/mst_b_buffer_inst/*}}
}

add_fletcher
add_fletcher_tb

add_source ../BufferWriter_tb.vhd -2008
add_source ../BufferWriter_2x32in64outMB1_tc.vhd -2008
add_source ../BufferWriter_4x16in64out_tc.vhd -2008
add_source ../BufferWriter_8x1in64out_tc.vhd -2008
add_source ../BufferWriter_8x64in512out_tc.vhd -2008
add_source ../BufferWriter_32in32out_tc.vhd -2008
add_source ../BufferWriter_32in64out_tc.vhd -2008
add_source ../BufferWriter_Default_tc.vhd -2008
add_source ../BufferWriter_IndexBS4_tc.vhd -2008
add_source ../BufferWriter_IndexBuf_tc.vhd -2008
add_source ../BufferWriter_IndexBufMEPC_tc.vhd -2008
#add_source ../BusWriteArbiter_tb.vhd -2008

echo "Testbench loaded, use \"t <name>\" to start BufferWriter test case, or b to start the bus infrastructure test."
print_cases
