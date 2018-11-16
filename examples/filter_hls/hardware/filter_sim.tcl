source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

proc run_sim {} {
  compile_sources
  simulate work.sim_top {
    {"Testbench" sim:/sim_top/* }
    {"UserCore" sim:/sim_top/filter_wrapper_inst/filter_usercore_inst/*}
  }
}

add_fletcher
add_fletcher_tb

add_source filter_hls_fletchbkb.vhd
add_source filter_hls_fletcher.vhd
add_source filter_usercore.vhd -2008
add_source filter_wrapper.vhd
add_source sim_top.vhd

run_sim
