set vhdl_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl

do $::env(FLETCHER_HARDWARE_DIR)/test/compile.tcl
do $::env(FLETCHER_HARDWARE_DIR)/test/utils.tcl

compile_utils $::env(FLETCHER_HARDWARE_DIR)/vhdl
compile_streams $::env(FLETCHER_HARDWARE_DIR)/vhdl

proc simtest {unit_name} {
  # Put all files being worked on here:

  # adsdsfghadfsj tcl
  set lcname [string tolower $unit_name]
  set tbname sim:/${lcname}_tb/*
  set uutname sim:/${lcname}_tb/uut/*
  set tbsig [list "TB" $tbname]
  set uutsig [list "UUT" $uutname]
  set siglist [list $tbsig $uutsig]
  
  # Common tb stuff
  vcom -work work -93  $::env(FLETCHER_HARDWARE_DIR)/vhdl/streams/StreamTbProd.vhd
  vcom -work work -93  $::env(FLETCHER_HARDWARE_DIR)/vhdl/streams/StreamTbCons.vhd
  
  vcom -work work -93  $::env(FLETCHER_HARDWARE_DIR)/vhdl/streams/${unit_name}.vhd
  vcom -work work -93  $::env(FLETCHER_HARDWARE_DIR)/vhdl/streams/${unit_name}_tb.vhd
  
  simulate work.${unit_name}_tb $siglist

}
