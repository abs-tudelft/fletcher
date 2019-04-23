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

# TODO:
# Add check if CL_DIR and HDK_SHELL_DIR directories exist
# Add check if /build and /build/src_port_encryption directories exist
# Add check if the vivado_keyfile exist

set HDK_SHELL_DIR $::env(HDK_SHELL_DIR)
set HDK_SHELL_DESIGN_DIR $::env(HDK_SHELL_DESIGN_DIR)
set CL_DIR $::env(CL_DIR)
set FLETCHER_HARDWARE_DIR $::env(FLETCHER_HARDWARE_DIR)
set FLETCHER_EXAMPLES_DIR $::env(FLETCHER_EXAMPLES_DIR)

set TARGET_DIR $CL_DIR/build/src_post_encryption
set UNUSED_TEMPLATES_DIR $HDK_SHELL_DESIGN_DIR/interfaces


# Remove any previously encrypted files, that may no longer be used
if {[llength [glob -nocomplain -dir $TARGET_DIR *]] != 0} {
  eval file delete -force [glob $TARGET_DIR/*]
}

#---- Developr would replace this section with design files ----

## Change file names and paths below to reflect your CL area.  DO NOT include AWS RTL files.

# Fletcher files:
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/utils/Utils.vhd                         $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/utils/SimUtils.vhd                      $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/utils/Ram1R1W.vhd                       $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/Buffers.vhd                     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/interconnect/Interconnect.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/Streams.vhd                     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamArb.vhd                   $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamBuffer.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamFIFOCounter.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamFIFO.vhd                  $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamGearbox.vhd               $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamNormalizer.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamParallelizer.vhd          $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamSerializer.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamSlice.vhd                 $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamSync.vhd                  $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamElementCounter.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamMaximizer.vhd             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamPseudoRandomGenerator.vhd $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamBarrel.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/streams/StreamAccumulator.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayConfigParse.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayConfig.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/Arrays.vhd                     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrow/Arrow.vhd                         $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReaderCmdGenBusReq.vhd    $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReaderCmd.vhd             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReaderPost.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReaderRespCtrl.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReaderResp.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReader.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferWriterCmdGenBusReq.vhd    $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferWriterPreCmdGen.vhd       $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferWriterPrePadder.vhd       $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferWriterPre.vhd             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferWriter.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/interconnect/BusReadArbiter.vhd         $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/interconnect/BusReadArbiterVec.vhd      $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/interconnect/BusReadBuffer.vhd          $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/interconnect/BusWriteArbiter.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/interconnect/BusWriteArbiterVec.vhd     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/interconnect/BusWriteBuffer.vhd         $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayConfigParse.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayConfig.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayReaderArb.vhd             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayReaderLevel.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayReaderListPrim.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayReaderListSyncDecoder.vhd $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayReaderListSync.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayReaderList.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayReaderNull.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayReaderStruct.vhd          $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayReaderUnlockCombine.vhd   $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayReader.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayWriterArb.vhd             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayWriterLevel.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayWriterListPrim.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayWriterListSync.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrays/ArrayWriter.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/wrapper/Wrapper.vhd                     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/wrapper/UserCoreController.vhd          $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/axi/axi.vhd                             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/axi/axi_mmio.vhd                        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/axi/axi_read_converter.vhd              $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/axi/axi_write_converter.vhd             $TARGET_DIR

# Copy all project files
file copy -force $FLETCHER_EXAMPLES_DIR/filter_hls/hardware/filter_hls_fletcher.vhd   $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/filter_hls/hardware/filter_usercore.vhd       $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/filter_hls/hardware/filter_wrapper.vhd        $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/filter_hls/hardware/axi_top.vhd               $TARGET_DIR

# Create a directory for VHDL 93 abominations
file mkdir $TARGET_DIR/vhdl93

# Copy the vivado HLS output that can only be compiled in vhdl 93 mode
file copy -force $FLETCHER_EXAMPLES_DIR/filter_hls/hardware/filter_hls_fletchbkb.vhd  $TARGET_DIR/vhdl93

# AWS EC2 F1 files:
file copy -force $CL_DIR/design/cl_arrow_defines.vh                   $TARGET_DIR
file copy -force $CL_DIR/design/cl_id_defines.vh                      $TARGET_DIR
file copy -force $CL_DIR/design/cl_arrow_pkg.sv                       $TARGET_DIR
file copy -force $CL_DIR/design/cl_arrow.sv                           $TARGET_DIR

#---- End of section replaced by Developr ---

# Make sure files have write permissions for the encryption

exec chmod +w {*}[glob $TARGET_DIR/*]

set TOOL_VERSION $::env(VIVADO_TOOL_VERSION)
set vivado_version [version -short]
set ver_2017_4 2017.4
puts "AWS FPGA: VIVADO_TOOL_VERSION $TOOL_VERSION"
puts "vivado_version $vivado_version"

# As we open-source everything, we don't care about encrypting the sources and
# skip the encryption step. Re-enable if you want your sources to become
# encrypted in the checkpoints.

# encrypt .v/.sv/.vh/inc as verilog files
# encrypt -k $HDK_SHELL_DIR/build/scripts/vivado_keyfile.txt -lang verilog  [glob -nocomplain -- $TARGET_DIR/*.{v,sv}] [glob -nocomplain -- $TARGET_DIR/*.vh] [glob -nocomplain -- $TARGET_DIR/*.inc]

# encrypt *vhdl files
# encrypt -k $HDK_SHELL_DIR/build/scripts/vivado_vhdl_keyfile.txt -lang vhdl -quiet [ glob -nocomplain -- $TARGET_DIR/*.vhd? ]

