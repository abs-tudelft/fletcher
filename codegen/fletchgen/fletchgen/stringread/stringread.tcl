source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

proc run_sim {} {
  compile_sources
  simulate work.sim_top {{"Testbench" sim:/sim_top/* }
                            {"Memory" sim:/sim_top/rmem_inst/*}
                            {"Wrapper" sim:/sim_top/test_wrapper_inst/*}
                            {"UserCore" sim:/sim_top/test_wrapper_inst/test_inst/*}
                            {"ArrayReader" sim:/sim_top/test_wrapper_inst/Name_read_inst/*}
                            {"Offsets buffer" sim:/sim_top/test_wrapper_inst/Name_read_inst/arb_inst/a_inst/listprim_gen/list_inst/a_inst/*}
                            {"Values buffer" sim:/sim_top/test_wrapper_inst/Name_read_inst/arb_inst/a_inst/listprim_gen/list_inst/b_inst/*}
                           }
}

add_fletcher
add_fletcher_tb

add_source test.vhd
add_source test_wrapper.vhd
add_source sim_top.vhd

run_sim
