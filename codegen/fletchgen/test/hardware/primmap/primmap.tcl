source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

proc run_sim {} {
  compile_sources
  simulate work.sim_top {{"Testbench" sim:/sim_top/* }
                            {"Read Memory" sim:/sim_top/rmem_inst/*}
                            {"Write Memory" sim:/sim_top/wmem_inst/*}
                            {"Wrapper" sim:/sim_top/primmap_wrapper_inst/*}
                            {"UserCore" sim:/sim_top/primmap_wrapper_inst/primmap_inst/*}
                            {"ArrayReader" sim:/sim_top/primmap_wrapper_inst/primread_read_inst/*}
                            {"ArrayWriter" sim:/sim_top/primmap_wrapper_inst/primwrite_write_inst/*}
                            {"Read Arbiter" sim:/sim_top/primmap_wrapper_inst/BusReadArbiterVec_inst/*}
                            {"Write Arbiter" sim:/sim_top/primmap_wrapper_inst/BusWriteArbiterVec_inst/*}
                           }
}

add_fletcher
add_fletcher_tb

add_source primmap.vhd
add_source primmap_wrapper.vhd
add_source sim_top.vhd

run_sim
