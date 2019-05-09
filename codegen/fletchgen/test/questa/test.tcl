source $::env(FLETCHER_HARDWARE_DIR)/test/questa/fletcher.tcl

add_fletcher
add_fletcher_tb

add_source ../../cmake-build-debug/Mantle_StringRead.vhd -2008

compile_sources
