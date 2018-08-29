source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

proc t {} { 
  compile_sources
  simulate work.bufferreader_tb {{"Testbench"     sim:/bufferreader_tb/*                                      }
                                 {"Host Mem"      sim:/bufferreader_tb/host_mem/*                             }
                                 {"User Core"     sim:/bufferreader_tb/user_core/*                            }
                                 {"Buffer Reader" sim:/bufferreader_tb/dut/*                                  }
                                 {"Command"       sim:/bufferreader_tb/dut/cmd_inst/*                         }
                                 {"Bus Request"   sim:/bufferreader_tb/dut/cmd_inst/bus_request_gen_inst/*    }
                                 {"Bus Buffer"    sim:/bufferreader_tb/dut/buffer_inst/*                      }
                                 {"Response ICS"  sim:/bufferreader_tb/dut/resp_inst/ctrl_inst/*              }}
}

add_fletcher
add_fletcher_tb

add_source BufferReader_tb.vhd -2008

t
