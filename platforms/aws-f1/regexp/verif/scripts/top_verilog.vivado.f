# Amazon FPGA Hardware Development Kit
#
# Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.

--define VIVADO_SIM

--sourcelibext .v
--sourcelibext .sv
--sourcelibext .svh

--sourcelibdir ${CL_ROOT}/design
--sourcelibdir ${SH_LIB_DIR}
--sourcelibdir ${SH_INF_DIR}
--sourcelibdir ${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim

--include ${CL_ROOT}/../common/design
--include ${CL_ROOT}/verif/sv
--include ${SH_LIB_DIR}
--include ${SH_INF_DIR}
--include ${HDK_COMMON_DIR}/verif/include
--include ${SH_LIB_DIR}/../ip/cl_axi_interconnect/ipshared/7e3a/hdl
--include ${HDK_SHELL_DESIGN_DIR}/sh_ddr/sim

${SH_LIB_DIR}/../ip/axi_clock_converter_0/sim/axi_clock_converter_0.v
${SH_LIB_DIR}/../ip/axi_register_slice/sim/axi_register_slice.v
${SH_LIB_DIR}/../ip/axi_register_slice_light/sim/axi_register_slice_light.v

# Top level interconnect between PCI Slave and DDR C
${CL_ROOT}/design/ip/axi_interconnect_top/sim/axi_interconnect_top.v

# Interconnect between DDR C and all RegExp units
${CL_ROOT}/design/ip/axi_interconnect_utf8/sim/axi_interconnect_utf8.v

--define DISABLE_VJTAG_DEBUG
${CL_ROOT}/design/cl_arrow_defines.vh
${CL_ROOT}/design/cl_arrow_pkg.sv
${CL_ROOT}/design/cl_arrow.sv

-f ${HDK_COMMON_DIR}/verif/tb/filelists/tb.${SIMULATOR}.f

${TEST_NAME}
