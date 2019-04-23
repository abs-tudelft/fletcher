source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

proc t {} { 
  compile_sources
  simulate work.bufferreader_tc {{"Testbench"     sim:/bufferreader_tc/*                                      }
                                 {"Host Mem"      sim:/bufferreader_tc/host_mem/*                             }
                                 {"User Core"     sim:/bufferreader_tc/user_core/*                            }
                                 {"Buffer Reader" sim:/bufferreader_tc/dut/*                                  }
                                 {"Command"       sim:/bufferreader_tc/dut/cmd_inst/*                         }
                                 {"Bus Request"   sim:/bufferreader_tc/dut/cmd_inst/bus_request_gen_inst/*    }
                                 {"Bus Buffer"    sim:/bufferreader_tc/dut/buffer_inst/*                      }
                                 {"Response ICS"  sim:/bufferreader_tc/dut/resp_inst/ctrl_inst/*              }}
}

add_fletcher
add_fletcher_tb

add_source ../BufferReader_tc.vhd -2008

t
