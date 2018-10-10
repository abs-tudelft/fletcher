#!/bin/bash

if [[ $# -lt 2 ]];
then
  echo "Usage: project-generate.sh PATH/TO/AWS-FPGA PROJECT-NAME [shell-version]"
  exit 1
fi

AWS_PATH="$1"
PROJ_NAME="$2"
if [[ $# -ge 3 ]];
then
  SHELL="$3"
  echo "Using shell: v$SHELL"
else
  SHELL="04261818"
#  SHELL="071417d3"
  echo "Using default shell: v$SHELL"
fi

SHELL_PATH="$AWS_PATH/hdk/common/shell_v$SHELL"
if [ ! -d "$SHELL_PATH" ];
then
  echo "Could not find shell at '$SHELL_PATH'"
  exit 1
fi

if [ -e "$PROJ_NAME" ];
then
  echo "Project name already exists"
  exit 1
fi

cp --recursive --no-dereference skeleton "$PROJ_NAME"
cd "$PROJ_NAME"

cp "$AWS_PATH/hdk/cl/examples/cl_dram_dma/build/constraints/cl_pnr_user.xdc" \
  "build/constraints/cl_pnr_user.xdc"
cp "$AWS_PATH/hdk/cl/examples/cl_dram_dma/build/constraints/cl_synth_user.xdc" \
  "build/constraints/cl_synth_user.xdc"

cp "$AWS_PATH/hdk/cl/examples/cl_dram_dma/verif/scripts/waves.tcl" \
  "verif/scripts/waves.tcl"

cp "$SHELL_PATH/build/scripts/aws_build_dcp_from_cl.sh" \
  "build/scripts/aws_build_dcp_from_cl.sh"

sed -e 's/cl_dram_dma/cl_arrow/g; s/write_checkpoint -encrypt /write_checkpoint /g' \
  < "$AWS_PATH/hdk/cl/examples/cl_dram_dma/build/scripts/create_dcp_from_cl.tcl" \
  > "build/scripts/create_dcp_from_cl.tcl"

sed -e 's<..C_SRC_DIR./common_dma.c<<g' \
  < "$AWS_PATH/hdk/cl/examples/cl_dram_dma/verif/scripts/Makefile" \
  > "verif/scripts/Makefile"

sed -e 's</top.vivado.f</top_verilog.vivado.f\n\tcd \$(SIM_DIR) \&\& xvhdl -m64 --initfile \$(XILINX_VIVADO)/data/xsim/ip/xsim_ip.ini --work xil_defaultlib --relax --2008 -f \$(SCRIPTS_DIR)/top_vhdl.vivado.f<g; s/-L xil_defaultlib/-L axi_interconnect_v1_7_13 -L axi_dwidth_converter_v2_1_12 -L xil_defaultlib/g; s/ -L / \\\n -L /g' \
  < "$AWS_PATH/hdk/cl/examples/cl_dram_dma/verif/scripts/Makefile.vivado" \
  > "verif/scripts/Makefile.vivado"


echo "Modify the following files to include the specific files used by your project:"
echo " * build/scripts/encrypt.tcl"
echo " * verif/scripts/top_vhdl.vivado.f"

