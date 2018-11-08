# Script to generate the Xilinx IP used in Amazon EC2 F1 example.

source $::env(HDK_DIR)/common/shell_stable/build/scripts/device_type.tcl

proc vivado_generate_ip {ip_name} {
  read_ip [ list \
    $::env(CL_DIR)/design/ip/$ip_name/$ip_name.xci
  ]
  generate_target all [get_files $::env(CL_DIR)/design/ip/$ip_name/$ip_name.xci]
  synth_ip [get_files $::env(CL_DIR)/design/ip/$ip_name/$ip_name.xci] -force
}

create_project -in_memory -part [DEVICE_TYPE] -force

# Read Fletcher example IP
vivado_generate_ip axi_interconnect_top
#vivado_generate_ip floating_point_sub_double
#vivado_generate_ip floating_point_add_double
#vivado_generate_ip floating_point_mult_double
#vivado_generate_ip floating_point_lt_double


