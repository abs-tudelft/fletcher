proc sim_prim {} {
  
  set source_dir $::env(FLETCHER_HARDWARE_DIR)/vhdl
    
  vcom -work work prim32_tb.vhd
  
  simulate work.prim32_tb {{"Testbench"    sim:/prim32_tb/*     }
                           {"UUT"          sim:/prim32_tb/uut/* }}
  
}

do ../compile.tcl
do ../utils.tcl

compile_fletcher $::env(FLETCHER_HARDWARE_DIR)/vhdl

sim_prim
