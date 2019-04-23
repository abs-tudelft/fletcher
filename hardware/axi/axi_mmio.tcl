source $::env(FLETCHER_HARDWARE_DIR)/test/compile.tcl
source $::env(FLETCHER_HARDWARE_DIR)/test/utils.tcl

add_source $::env(FLETCHER_HARDWARE_DIR)/vhdl/utils/Utils.vhd
add_source axi.vhd
add_source axi_mmio.vhd
add_source test/axi_mmio_tb.vhd

compile_sources

simulate axi_mmio_tb {{"TB"  sim:/axi_mmio_tb/*}
                      {"UUT" sim:/axi_mmio_tb/uut/*}}
