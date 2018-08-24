# SimpleReadColumn test setup
do $::env(FLETCHER_HARDWARE_DIR)/test/compile.tcl
do $::env(FLETCHER_HARDWARE_DIR)/test/utils.tcl

proc comp_sim {} {
  vcom -quiet -work work test.vhd
  vcom -quiet -work work test_wrapper.vhd
  vcom -quiet -work work sim_top.vhd
}

proc run_sim {} {
  set vhdl_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl

  simulate work.sim_top {{"Testbench" sim:/sim_top/* }
                            {"Memory" sim:/sim_top/rmem_inst/*}
                            {"Wrapper" sim:/sim_top/test_wrapper_inst/*}
                            {"UserCore" sim:/sim_top/test_wrapper_inst/test_inst/*}
                            {"ColumnReader" sim:/sim_top/test_wrapper_inst/Name_read_inst/*}
                            {"Offsets buffer" sim:/sim_top/test_wrapper_inst/Name_read_inst/arb_inst/a_inst/listprim_gen/list_inst/a_inst/*}
                            {"Values buffer" sim:/sim_top/test_wrapper_inst/Name_read_inst/arb_inst/a_inst/listprim_gen/list_inst/b_inst/*}
                           } 1000ns
}

compile_fletcher $::env(FLETCHER_HARDWARE_DIR)/vhdl
compile_interconnect_tb $::env(FLETCHER_HARDWARE_DIR)/vhdl

comp_sim
run_sim
