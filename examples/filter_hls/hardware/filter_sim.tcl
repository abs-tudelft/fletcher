source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

proc run_sim {} {
  compile_sources
  simulate work.sim_top {{"Testbench" sim:/sim_top/* }
                         {"Memory" sim:/sim_top/rmem_inst/*}
                         {"Wrapper" sim:/sim_top/filter_wrapper_inst/*}
                         {"UserCore" sim:/sim_top/filter_wrapper_inst/filter_usercore/*}
                         }
}

add_fletcher
add_fletcher_tb

add_source filter_usercore.vhd
add_source filter_wrapper.vhd
add_source sim_top.vhd

run_sim
