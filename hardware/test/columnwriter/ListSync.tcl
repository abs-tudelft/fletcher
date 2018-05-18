proc l {} {
  
  set vhdl_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl
  
  vcom -work work -93 $vhdl_dir/arrow/ColumnWriterListSync.vhd
  vcom -work work -2008 $vhdl_dir/arrow/ColumnWriterListSync_tb.vhd
  
  simulate work.columnwriterlistsync_tb {{"Testbench" sim:/columnwriterlistsync_tb/*     }
                                         {"UUT"       sim:/columnwriterlistsync_tb/uut/* }}
  
}

do ../compile.tcl
do ../utils.tcl

compile_fletcher $::env(FLETCHER_HARDWARE_DIR)/vhdl

