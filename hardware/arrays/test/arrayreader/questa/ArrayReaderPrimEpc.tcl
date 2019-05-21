source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

add_fletcher
add_fletcher_tb

add_source ../ArrayReaderPrimEpc_tb.vhd

compile_sources

simulate work.ArrayReaderPrimEpc_tb

