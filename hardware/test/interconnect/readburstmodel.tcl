source $::env(FLETCHER_HARDWARE_DIR)/test/fletcher.tcl

add_fletcher
add_fletcher_tb
recompile_sources

simulate busburstmodel_tb {{TB  sim:/busburstmodel_tb/*} 
                           {ARB sim:/busburstmodel_tb/arb_inst/*} 
                           {SLAVE sim:/busburstmodel_tb/slave_inst/*} 
                           {CONS0 sim:/busburstmodel_tb/cons_gen(0)/uut/*} 
                           {CONS1 sim:/busburstmodel_tb/cons_gen(1)/uut/*}}
