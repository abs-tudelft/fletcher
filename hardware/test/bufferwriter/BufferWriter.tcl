# BufferWriter testbench setup
proc t {} {
  set vhdl_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl
  
  # Put all files being worked on here:
  
  vcom -work work -93 $vhdl_dir/arrow/Arrow.vhd
  vcom -work work -93 $vhdl_dir/arrow/BusWriteBuffer.vhd
  vcom -work work -93 $vhdl_dir/arrow/BufferWriterCmdGenBusReq.vhd
  vcom -work work -93 $vhdl_dir/arrow/BufferWriterPrePadder.vhd
  vcom -work work -93 $vhdl_dir/arrow/BufferWriterPre.vhd
  vcom -work work -93 $vhdl_dir/arrow/BufferWriter.vhd
  
  vcom -work work -2008 $vhdl_dir/arrow/BufferWriter_tb.vhd

  simulate work.bufferwriter_tb {{"Testbench"         sim:/bufferwriter_tb/*                          }
                                 {"Buffer Writer"     sim:/bufferwriter_tb/uut/*                      }
                                 {"Preprocessor"      sim:/bufferwriter_tb/uut/pre_inst/*             }
                                 {"Padder"            sim:/bufferwriter_tb/uut/pre_inst/padder_inst/* }
                                 {"CmdGenBusReq"      sim:/bufferwriter_tb/uut/cmdgen_inst/*          }
                                 {"Bus Write Buffer"  sim:/bufferwriter_tb/uut/buffer_inst/*          }}
}

# BufferWriters testbench setup
proc a {} {
  set vhdl_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl
  
  # Put all files being worked on here:
  
  vcom -work work -93 $vhdl_dir/arrow/Arrow.vhd
  vcom -work work -93 $vhdl_dir/arrow/BusWriteBuffer.vhd
  vcom -work work -93 $vhdl_dir/arrow/BufferWriterCmdGenBusReq.vhd
  vcom -work work -93 $vhdl_dir/arrow/BufferWriterPrePadder.vhd
  vcom -work work -93 $vhdl_dir/arrow/BufferWriterPre.vhd
  vcom -work work -93 $vhdl_dir/arrow/BufferWriter.vhd
  
  vcom -work work -2008 $vhdl_dir/arrow/BufferWriter_tb.vhd
  vcom -work work -2008 $vhdl_dir/arrow/BufferWriters_tb.vhd

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
  set vhdl_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl
  
  # Put all files being worked on here:
  
  vcom -work work -93 $vhdl_dir/arrow/Arrow.vhd
  vcom -work work -93 $vhdl_dir/arrow/BusWriteBuffer.vhd
  vcom -work work -93 $vhdl_dir/arrow/BusWriteArbiter.vhd
  vcom -work work -93 $vhdl_dir/arrow/BusWriteArbiterVec.vhd
  vcom -work work -93 $vhdl_dir/arrow/BusWriteBuffer.vhd
  
  vcom -work work -2008 $vhdl_dir/arrow/BusWriteMasterMock.vhd
  vcom -work work -2008 $vhdl_dir/arrow/BusWriteSlaveMock.vhd
  vcom -work work -2008 $vhdl_dir/arrow/BusWriteArbiter_tb.vhd

  simulate work.buswritearbiter_tb {{"Testbench" sim:/buswritearbiter_tb/*              }
                                    {"Arbiter"   sim:/buswritearbiter_tb/uut/arb_inst/* }
                                    {"Buffer A"  sim:/buswritearbiter_tb/mst_a_buffer_inst/*}
                                    {"Buffer B"  sim:/buswritearbiter_tb/mst_b_buffer_inst/*}}
                                    
}

do ../compile.tcl
do ../utils.tcl

compile_fletcher $::env(FLETCHER_HARDWARE_DIR)/vhdl

echo "Testbench loaded, use \"t\" to start one, or a to start all."
