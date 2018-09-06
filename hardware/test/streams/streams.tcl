source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

proc simtest {unit_name} {
  # adsdsfghadfsj tcl
  set lcname [string tolower $unit_name]
  set tbname sim:/${lcname}_tb/*
  set uutname sim:/${lcname}_tb/uut/*
  set tbsig [list "TB" $tbname]
  set uutsig [list "UUT" $uutname]
  set siglist [list $tbsig $uutsig]
  
  # Add UUT and testbench to sources to compile.
  add_source $::env(FLETCHER_HARDWARE_DIR)/vhdl/streams/${unit_name}.vhd
  add_source $::env(FLETCHER_HARDWARE_DIR)/vhdl/streams/${unit_name}_tb.vhd
  
  compile_sources
  
  simulate work.${unit_name}_tb $siglist

}

add_fletcher
add_fletcher_tb

echo "Use simtest <unit name> to simulate any stream component with a testbench."
echo "Example: simtest StreamMaximizer"
