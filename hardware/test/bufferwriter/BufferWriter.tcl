source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

# BufferWriter testbench setup
proc t {} {
  compile_sources
  simulate work.bufferwriter_tb {{"Testbench"         sim:/bufferwriter_tb/*                          }
                                 {"Buffer Writer"     sim:/bufferwriter_tb/uut/*                      }
                                 {"Preprocessor"      sim:/bufferwriter_tb/uut/pre_inst/*             }
                                 {"Padder"            sim:/bufferwriter_tb/uut/pre_inst/padder_inst/* }
                                 {"CmdGenBusReq"      sim:/bufferwriter_tb/uut/cmdgen_inst/*          }
                                 {"Bus Write Buffer"  sim:/bufferwriter_tb/uut/buffer_inst/*          }}
}

# BufferWriters testbench setup
proc a {} {
  compile_sources
  simulate work.bufferwriters_tb  {
    {"Inst 0" sim:/bufferwriters_tb/inst0/* }
    {"Inst 1" sim:/bufferwriters_tb/inst1/* }
    {"Inst 2" sim:/bufferwriters_tb/inst2/* }
    {"Inst 3" sim:/bufferwriters_tb/inst3/* }
    {"Inst 4" sim:/bufferwriters_tb/inst4/* }
    {"Inst 5" sim:/bufferwriters_tb/inst5/* }
    {"Testbench"         sim:/bufferwriters_tb/inst1/*                          }
    {"Buffer Writer"     sim:/bufferwriters_tb/inst1/uut/*                      }
    {"Preprocessor"      sim:/bufferwriters_tb/inst1/uut/pre_inst/*             }
    {"Padder"            sim:/bufferwriters_tb/inst1/uut/pre_inst/padder_inst/* }
    {"CmdGenBusReq"      sim:/bufferwriters_tb/inst1/uut/cmdgen_inst/*          }
    {"Bus Write Buffer"  sim:/bufferwriters_tb/inst1/uut/buffer_inst/*          }
  }
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

add_source BufferWriter_tb.vhd -2008
add_source BufferWriters_tb.vhd -2008
add_source BusWriteArbiter_tb.vhd -2008

echo "Testbench loaded, use \"t\" to start one, or a to start all, or b to start the bus infrastructure test."
