source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

proc run_sim {} {
  compile_sources
  simulate work.sim_top {{"Testbench" sim:/sim_top/* }
                         {"Kernel" sim:/sim_top/Mantle_inst/Kernel_inst/*}
                         {"HLS kernel" sim:/sim_top/Mantle_inst/Kernel_inst/ChooseDrink_inst/*}}
}

add_fletcher
add_fletcher_tb

# Vivado HLS output
add_source hls/generated/ChooseDrink.vhd
add_source hls/generated/ChooseDrink_name.vhd
add_source hls/generated/PullString.vhd
add_source hls/generated/PushString.vhd

# Fletchgen output
add_source vhdl/Hobbiton.vhd
add_source vhdl/Bywater.vhd
add_source vhdl/Soda.vhd
add_source vhdl/Beer.vhd
add_source vhdl/Kernel.vhd
add_source vhdl/Mantle.vhd
add_source vhdl/sim_top.vhd -2008

compile_sources

run_sim
