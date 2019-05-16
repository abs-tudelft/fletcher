source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

proc run_sim {} {
  compile_sources
  simulate work.sim_top {{"Testbench" sim:/sim_top/* }
                         {"Memory" sim:/sim_top/rmem_inst/*}
                         {"Offsets BR" sim:/sim_top/Kernel_Mantle_inst/Strings_RecordBatchReader_inst/Name_ArrayReader_Inst/arb_inst/a_inst/listprim_gen/list_inst/a_inst/*}
                         {"Values BR" sim:/sim_top/Kernel_Mantle_inst/Strings_RecordBatchReader_inst/Name_ArrayReader_Inst/arb_inst/a_inst/listprim_gen/list_inst/b_inst/*}
                         {"ListPrim" sim:/sim_top/Kernel_Mantle_inst/Strings_RecordBatchReader_inst/Name_ArrayReader_Inst/arb_inst/a_inst/listprim_gen/list_inst/*}
                         {"ArrayReader" sim:/sim_top/Kernel_Mantle_inst/Strings_RecordBatchReader_inst/Name_ArrayReader_Inst/*}
                         {"String RecordBatch Reader" sim:/sim_top/Kernel_Mantle_inst/Strings_RecordBatchReader_inst/*}
                         {"Kernel" sim:/sim_top/Kernel_Mantle_inst/Kernel_inst/*}}
}

add_fletcher
add_fletcher_tb

add_source vhdl/PrimRead.vhd -2008
add_source vhdl/PrimWrite.vhd -2008
add_source vhdl/Mantle.vhd -2008
add_source vhdl/Kernel.vhd -2008
add_source vhdl/sim_top.vhd -2008

compile_sources

run_sim
