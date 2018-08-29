source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

proc test_listsync {} {
  compile_sources
  simulate work.columnwriterlistsync_tb {{"Testbench" sim:/columnwriterlistsync_tb/*     }
                                         {"UUT"       sim:/columnwriterlistsync_tb/uut/* }}
  
}

proc test_listprim {} {
  compile_sources
  simulate work.listprim8epc4_tb {{"Testbench"    sim:/listprim8epc4_tb/*     }
                                  {"UUT"          sim:/listprim8epc4_tb/uut/* }
                                  {"Arb"          sim:/listprim8epc4_tb/uut/arb_inst/*}
                                  {"Arbiter inst" sim:/listprim8epc4_tb/uut/arb_inst/arb_gen/arb_inst/*}
                                  {"Level"        sim:/listprim8epc4_tb/uut/arb_inst/a_inst/*}
                                  {"ListPrim"     sim:/listprim8epc4_tb/uut/arb_inst/a_inst/listprim_gen/listprim_inst/*}
                                  {"ListSync"     sim:/listprim8epc4_tb/uut/arb_inst/a_inst/listprim_gen/listprim_inst/sync_inst/*}
                                  {"Writer A"     sim:/listprim8epc4_tb/uut/arb_inst/a_inst/listprim_gen/listprim_inst/a_inst/*}
                                  {"Writer B"     sim:/listprim8epc4_tb/uut/arb_inst/a_inst/listprim_gen/listprim_inst/b_inst/*}}
  
}

proc test_prim {} {
  compile_sources
  simulate work.prim32_tb {{"Testbench"    sim:/prim32_tb/*     }
                           {"UUT"          sim:/prim32_tb/uut/* }}
}

add_fletcher
add_fletcher_tb

add_source ColumnWriterListSync_tb.vhd -2008
add_source listprim8epc4_tb.vhd -2008
add_source prim32_tb.vhd -2008

test_prim
