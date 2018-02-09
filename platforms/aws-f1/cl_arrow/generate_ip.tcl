# Script to generate the Xilinx IP used in Amazon EC2 F1 RegExp example.

source $::env(HDK_DIR)/common/shell_stable/build/scripts/device_type.tcl

create_project -in_memory -part [DEVICE_TYPE] -force

# Read Arrow RegExp example IP
read_ip [ list \
  $::env(CL_DIR)/design/ip/axi_interconnect_utf8/axi_interconnect_utf8.xci \
  $::env(CL_DIR)/design/ip/axi_interconnect_top/axi_interconnect_top.xci
]

# Generate the IP used in cl_arrow and arrow_regexp
generate_target all [get_files $::env(CL_DIR)/design/ip/axi_interconnect_utf8/axi_interconnect_utf8.xci]
synth_ip [get_files $::env(CL_DIR)/design/ip/axi_interconnect_utf8/axi_interconnect_utf8.xci] -force

generate_target all [get_files $::env(CL_DIR)/design/ip/axi_interconnect_top/axi_interconnect_top.xci]
synth_ip [get_files $::env(CL_DIR)/design/ip/axi_interconnect_top/axi_interconnect_top.xci] -force

