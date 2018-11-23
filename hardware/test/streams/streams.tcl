source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

proc simtest {unit_name {tc_name ""}} {

  if {$tc_name eq ""} {
    set full_tc_name ${unit_name}
  } else {
    set full_tc_name ${unit_name}_${tc_name}
  }
  set lcname [string tolower ${full_tc_name}]
  set tbname sim:/${lcname}_tc/tb/*
  set uutname sim:/${lcname}_tc/tb/uut/*
  set tbsig [list "TB" $tbname]
  set uutsig [list "UUT" $uutname]
  set siglist [list $tbsig $uutsig]

  # Add UUT and testbench to sources to compile.
  add_source $::env(FLETCHER_HARDWARE_DIR)/test/streams/${unit_name}/${unit_name}_tb.vhd
  foreach test_vector [glob -nocomplain "$::env(FLETCHER_HARDWARE_DIR)/test/streams/${unit_name}/*_tv.vhd"] {
    add_source $test_vector
  }
  add_source $::env(FLETCHER_HARDWARE_DIR)/test/streams/${unit_name}/${full_tc_name}_tc.vhd

  compile_sources

  simulate work.${full_tc_name}_tc $siglist

}

add_fletcher
add_fletcher_tb

echo "Use simtest <unit name> [test case] to simulate any stream component with a testbench."
echo "Example: simtest StreamMaximizer"
