# BufferWriter testbench setup
proc t {} {
  set vhdl_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl
  
  # Put all files being worked on here:
  
  vcom -work work -2008 $vhdl_dir/arrow/Arrow.vhd
  vcom -work work -2008 $vhdl_dir/arrow/BusWriteBuffer.vhd
  vcom -work work -2008 $vhdl_dir/arrow/BufferWriterCmdGenBusReq.vhd
  vcom -work work -2008 $vhdl_dir/arrow/BufferWriterPrePadder.vhd
  vcom -work work -2008 $vhdl_dir/arrow/BufferWriterPre.vhd
  vcom -work work -2008 $vhdl_dir/arrow/BufferWriter.vhd
  vcom -work work -2008 $vhdl_dir/arrow/BufferWriter_tb.vhd

  simulate work.bufferwriter_tb {{"Testbench"         sim:/bufferwriter_tb/*                          }
                                 {"Buffer Writer"     sim:/bufferwriter_tb/uut/*                      }
                                 {"Preprocessor"      sim:/bufferwriter_tb/uut/pre_inst/*             }
                                 {"Padder"            sim:/bufferwriter_tb/uut/pre_inst/padder_inst/* }
                                 {"CmdGenBusReq"      sim:/bufferwriter_tb/uut/cmdgen_inst/*          }
                                 {"Bus Write Buffer"  sim:/bufferwriter_tb/uut/buffer_inst/*          }}
}

do ../compile.tcl
do ../utils.tcl

compile_fletcher $::env(FLETCHER_HARDWARE_DIR)/vhdl

echo "Testbench loaded, use \"t\" to start."
