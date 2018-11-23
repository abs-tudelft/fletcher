# If this script fails, make sure to run hdk_setup.sh in aws-fpga first

export CL_DIR=$(pwd)

vivado -mode batch -source generate_ip.tcl
