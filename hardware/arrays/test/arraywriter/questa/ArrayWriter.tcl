source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

proc test_listsync {} {
  compile_sources
  simulate work.arraywriterlistsync_tc {{"Testbench" sim:/arraywriterlistsync_tc/*     }
                                         {"UUT"       sim:/arraywriterlistsync_tc/uut/* }}
  
}

proc test_listprim {} {
  compile_sources
  simulate work.listprim8epc4_tc {{"Testbench"    sim:/listprim8epc4_tc/*     }
                                  {"UUT"          sim:/listprim8epc4_tc/uut/* }
                                  {"Arb"          sim:/listprim8epc4_tc/uut/arb_inst/*}
                                  {"Arbiter inst" sim:/listprim8epc4_tc/uut/arb_inst/arb_gen/arb_inst/*}
                                  {"Level"        sim:/listprim8epc4_tc/uut/arb_inst/a_inst/*}
                                  {"ListPrim"     sim:/listprim8epc4_tc/uut/arb_inst/a_inst/listprim_gen/listprim_inst/*}
                                  {"ListSync"     sim:/listprim8epc4_tc/uut/arb_inst/a_inst/listprim_gen/listprim_inst/sync_inst/*}
                                  {"Writer A"     sim:/listprim8epc4_tc/uut/arb_inst/a_inst/listprim_gen/listprim_inst/a_inst/*}
                                  {"Writer B"     sim:/listprim8epc4_tc/uut/arb_inst/a_inst/listprim_gen/listprim_inst/b_inst/*}}
  
}

proc test_prim {} {
  compile_sources
  simulate work.prim32_tc {{"Testbench"    sim:/prim32_tc/*     }
                           {"UUT"          sim:/prim32_tc/uut/* }}
}

add_fletcher
add_fletcher_tb

add_source ../ArrayWriterListSync_tc.vhd -2008
add_source ../listprim8epc4_tc.vhd -2008
add_source ../prim32_tc.vhd -2008

test_prim
