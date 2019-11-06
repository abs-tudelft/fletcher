source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl
source $::env(FLETCHER_HARDWARE_DIR)/test/questa/compile.tcl
source $::env(FLETCHER_HARDWARE_DIR)/test/questa/utils.tcl

add_fletcher
add_fletcher_tb

add_source Axi_pkg.vhd
add_source AxiMmio.vhd
add_source test/AxiMmio_tc.vhd

compile_sources

simulate aximmio_tc {{"TB"  sim:/aximmio_tc/*}
                     {"UUT" sim:/aximmio_tc/uut/*}}
