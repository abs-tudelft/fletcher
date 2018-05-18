proc listsync {} {
  
  set source_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl
  
  vcom -work work -93   $source_dir/arrow/ColumnWriterListSync.vhd
  vcom -work work -2008 $source_dir/arrow/ColumnWriterListSync_tb.vhd
  
  simulate work.columnwriterlistsync_tb {{"Testbench" sim:/columnwriterlistsync_tb/*     }
                                         {"UUT"       sim:/columnwriterlistsync_tb/uut/* }}
  
}

proc lp {} {
  
  set source_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl
  
  vcom -quiet -work work -93 $source_dir/arrow/ColumnWriterArb.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnWriterListSync.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnWriterListPrim.vhd
  #vcom -quiet -work work -93 $source_dir/arrow/ColumnWriterLevel.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnWriter.vhd
  
  vcom -work work -2008 listprim8epc4_tb.vhd
  
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

do ../compile.tcl
do ../utils.tcl

compile_fletcher $::env(FLETCHER_HARDWARE_DIR)/vhdl

lp
