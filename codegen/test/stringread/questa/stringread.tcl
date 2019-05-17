source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

proc run_sim {} {
  compile_sources
  simulate work.sim_top {{"Testbench" sim:/sim_top/* }
                         {"Kernel" sim:/sim_top/Mantle_inst/Kernel_inst/*}}
}

add_fletcher
add_fletcher_tb

add_source vhdl/Kernel.vhd -2008
add_source vhdl/StringRead.vhd -2008
add_source vhdl/Mantle.vhd -2008
add_source vhdl/sim_top.vhd -2008

compile_sources

run_sim
