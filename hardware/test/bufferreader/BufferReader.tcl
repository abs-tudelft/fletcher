# BufferReader testbench setup
proc t {} {
  set vhdl_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl

  vcom -work work -2008 $vhdl_dir/arrow/BusReadMasterMock.vhd
  vcom -work work -2008 $vhdl_dir/arrow/BusReadSlaveMock.vhd
  vcom -work work -2008 $vhdl_dir/arrow/UserCoreMock.vhd
  vcom -work work -2008 $vhdl_dir/arrow/BufferReader_tb.vhd

  simulate work.bufferreader_tb {{"Testbench"     sim:/bufferreader_tb/*                                      }
                                 {"Host Mem"      sim:/bufferreader_tb/host_mem/*                             }
                                 {"User Core"     sim:/bufferreader_tb/user_core/*                            }
                                 {"Buffer Reader" sim:/bufferreader_tb/dut/*                                  }
                                 {"Command"       sim:/bufferreader_tb/dut/cmd_inst/*                         }
                                 {"Bus Request"   sim:/bufferreader_tb/dut/cmd_inst/bus_request_gen_inst/*    }
                                 {"Bus Buffer"    sim:/bufferreader_tb/dut/buffer_inst/*                      }
                                 {"Response ICS"  sim:/bufferreader_tb/dut/resp_inst/ctrl_inst/*              }}
}

do ../compile.tcl
do ../utils.tcl

compile_fletcher $::env(FLETCHER_HARDWARE_DIR)/vhdl
t
