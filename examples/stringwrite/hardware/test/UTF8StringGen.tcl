set vhdl_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl

do $::env(FLETCHER_HARDWARE_DIR)/test/compile.tcl
do $::env(FLETCHER_HARDWARE_DIR)/test/utils.tcl

compile_fletcher $::env(FLETCHER_HARDWARE_DIR)/vhdl

# UTF8 String Streams generator test
proc t {} {
  # Put all files being worked on here:

  vcom -work work -93  $::env(FLETCHER_EXAMPLES_DIR)/stringwrite/hardware/stringwrite_pkg.vhd
  vcom -work work -93  $::env(FLETCHER_EXAMPLES_DIR)/stringwrite/hardware/UTF8StringGen.vhd
  vcom -work work -93  UTF8StringGen_tb.vhd

  simulate work.UTF8StringGen_tb {{"TB"        sim:/utf8stringgen_tb/*}
                                  {"StringGen" sim:/utf8stringgen_tb/uut/*}}

}

echo "Testbench loaded, use \"t\" to start."
