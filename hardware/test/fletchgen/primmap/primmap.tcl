source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

proc run_sim {} {
  compile_sources
  simulate work.sim_top {{"Testbench" sim:/sim_top/* }
                            {"Memory" sim:/sim_top/rmem_inst/*}
                            {"Wrapper" sim:/sim_top/primmap_wrapper_inst/*}
                            {"UserCore" sim:/sim_top/primmap_wrapper_inst/primmap_inst/*}
                           }
}

add_fletcher
add_fletcher_tb

add_source primmap.vhd
add_source primmap_wrapper.vhd
add_source sim_top.vhd

run_sim
