source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

proc run_sim {} {
  compile_sources
  simulate work.sim_top {{"Testbench" sim:/sim_top/* }
                         {"Kernel" sim:/sim_top/Mantle_inst/Sum_inst/*}}
}

add_fletcher
add_fletcher_tb

# RecordBatch reader:
add_source vhdl/ExampleBatch.vhd -2008

# Kernel:
add_source vhdl/Sum.vhd -2008

# Wrapper:
add_source vhdl/Mantle.vhd -2008

# Simulation top-level:
add_source vhdl/sim_top.vhd -2008

compile_sources

run_sim
