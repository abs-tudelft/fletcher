source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

proc yo {} {
  compile_sources
  simulate busburstmodel_tb                   
}


proc go {} {
  compile_sources
  simulate busburstmodel_tb {{"Test Bench " sim:/busburstmodel_tb/*} 
                             {"Read Slave " sim:/busburstmodel_tb/slave_inst/*}
                             {"Buffer 0 "   sim:/busburstmodel_tb/cons_gen(0)/buf/*}
                             {"Consumer 0 " sim:/busburstmodel_tb/cons_gen(0)/uut/*}
                             {"Buffer 1 "   sim:/busburstmodel_tb/cons_gen(1)/buf/*}
                             {"Consumer 1 " sim:/busburstmodel_tb/cons_gen(1)/uut/*}}
}

add_fletcher
add_fletcher_tb
recompile_sources

go
