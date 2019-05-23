source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

proc run_sim {} {
  compile_sources
  simulate work.sim_top {{"Testbench" sim:/sim_top/* }
                         {"Kernel" sim:/sim_top/Mantle_inst/Kernel_inst/*}}
}

add_fletcher
add_fletcher_tb

add_source vhdl/Hobbiton.vhd
add_source vhdl/Bywater.vhd
add_source vhdl/Soda.vhd
add_source vhdl/Beer.vhd
add_source vhdl/Kernel.vhd
add_source vhdl/Mantle.vhd
add_source vhdl/sim_top.vhd -2008

compile_sources

run_sim
