source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

proc run_sim {} {
  compile_sources
  simulate work.sim_top {{"Testbench" sim:/sim_top/* }
                         {"Kernel" sim:/sim_top/Mantle_inst/Kernel_inst/*}
                         {"HLS" sim:/sim_top/Mantle_inst/Kernel_inst/ChooseDrink_inst/*}
                         {"Beer Writer" sim:/sim_top/Mantle_inst/Beer_inst/name_inst/arb_inst/a_inst/listprim_gen/listprim_inst/*}}
}

add_fletcher
add_fletcher_tb

# Vivado HLS output
add_directory hls/generated

# Fletchgen output
add_source vhdl/Hobbits.vhd
add_source vhdl/Soda.vhd
add_source vhdl/Beer.vhd
add_source vhdl/Kernel.vhd -2008
add_source vhdl/Mantle.vhd
add_source vhdl/sim_top.vhd -2008

compile_sources

run_sim
