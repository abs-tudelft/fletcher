# SimpleReadColumn test setup
proc t {} {
  set vhdl_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl

  vcom -quiet -work work test.vhd
  vcom -quiet -work work test_wrapper.vhd
  vcom -quiet -work work ../wrapper_tb.vhd

  simulate work.wrapper_tb {{"Testbench" sim:/wrapper_tb/* }
                            {"Memory" sim:/wrapper_tb/rmem_inst/*}
                            {"Wrapper" sim:/wrapper_tb/test_wrapper_inst/*}
                            {"UserCore" sim:/wrapper_tb/test_wrapper_inst/test_inst/*}
                            {"ColumnReader" sim:/wrapper_tb/test_wrapper_inst/Name_read_inst/*}
                            {"Offsets buffer" sim:/wrapper_tb/test_wrapper_inst/Name_read_inst/arb_inst/a_inst/listprim_gen/list_inst/a_inst/*}
                            {"Values buffer" sim:/wrapper_tb/test_wrapper_inst/Name_read_inst/arb_inst/a_inst/listprim_gen/list_inst/b_inst/*}
                           } 1000ns
}

do $::env(FLETCHER_HARDWARE_DIR)/test/compile.tcl
do $::env(FLETCHER_HARDWARE_DIR)/test/utils.tcl

compile_fletcher $::env(FLETCHER_HARDWARE_DIR)/vhdl
compile_bus_tb $::env(FLETCHER_HARDWARE_DIR)/vhdl
t
