############################################################
## This file is generated automatically by Vivado HLS.
## Please DO NOT edit it.
## Copyright (C) 1986-2018 Xilinx, Inc. All Rights Reserved.
############################################################
open_project sodabeer
set_top ChooseDrink
add_files ../src/fletcher/vivado_hls.h
add_files ../src/SodaBeer.h
add_files ../src/SodaBeer.cpp
add_files -tb ../src/SodaBeer_test.cpp -cflags "-Wno-unknown-pragmas"
open_solution "solution0"
set_part {xcvu9p-flgc2104-3-e} -tool vivado
create_clock -period 4 -name default
#source "./sodabeer/solution0/directives.tcl"
csim_design -clean
csynth_design
cosim_design -trace_level all -rtl vhdl -tool modelsim
export_design -format ip_catalog
