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
exec rm -f $TARGET_DIR/*

#---- Developr would replace this section with design files ----

## Change file names and paths below to reflect your CL area.  DO NOT include AWS RTL files.

# Fletcher files:
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/utils/SimUtils.vhd                      $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/utils/Utils.vhd                         $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/utils/Ram1R1W.vhd                       $TARGET_DIR

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

file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnConfigParse.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnConfig.vhd                $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/Columns.vhd                     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/arrow/Arrow.vhd                         $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/Buffers.vhd                     $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReaderCmdGenBusReq.vhd    $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReaderCmd.vhd             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReaderPost.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReaderRespCtrl.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReaderResp.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/buffers/BufferReader.vhd                $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/vhdl/interconnect/Interconnect.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/interconnect/BusReadArbiter.vhd         $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/interconnect/BusReadArbiterVec.vhd      $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/interconnect/BusReadBuffer.vhd          $TARGET_DIR

file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnReaderArb.vhd             $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnReaderLevel.vhd           $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnReaderList.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnReaderListPrim.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnReaderListSync.vhd        $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnReaderListSyncDecoder.vhd $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnReaderNull.vhd            $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnReaderStruct.vhd          $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnReaderUnlockCombine.vhd   $TARGET_DIR
file copy -force $FLETCHER_HARDWARE_DIR/vhdl/columns/ColumnReader.vhd                $TARGET_DIR

# Regexp example files:

file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/axi_read_converter.vhd  $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/arrow_regexp_unit.vhd   $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/arrow_regexp_pkg.vhd    $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/arrow_regexp.vhd        $TARGET_DIR

file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/bird.vhd        $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/bunny.vhd       $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/cat.vhd         $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/dog.vhd         $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/ferret.vhd      $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/fish.vhd        $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/gerbil.vhd      $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/hamster.vhd     $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/horse.vhd       $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/kitten.vhd      $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/lizard.vhd      $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/mouse.vhd       $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/puppy.vhd       $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/rabbit.vhd      $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/rat.vhd         $TARGET_DIR
file copy -force $FLETCHER_EXAMPLES_DIR/regexp/hardware/animals/turtle.vhd      $TARGET_DIR

# AWS EC2 F1 files:

file copy -force $CL_DIR/design/cl_arrow_defines.vh                   $TARGET_DIR
file copy -force $CL_DIR/design/cl_id_defines.vh                      $TARGET_DIR
file copy -force $CL_DIR/design/cl_arrow_pkg.sv                       $TARGET_DIR
file copy -force $CL_DIR/design/cl_arrow.sv                           $TARGET_DIR

#---- End of section replaced by Developr ---

# Make sure files have write permissions for the encryption

exec chmod +w {*}[glob $TARGET_DIR/*]

# As we open-source everything, we don't care about encrypting the sources and
# skip the encryption step. Re-enable if you want your sources to become
# encrypted in the checkpoints.

# encrypt .v/.sv/.vh/inc as verilog files
# encrypt -k $HDK_SHELL_DIR/build/scripts/vivado_keyfile.txt -lang verilog  [glob -nocomplain -- $TARGET_DIR/*.{v,sv}] [glob -nocomplain -- $TARGET_DIR/*.vh] [glob -nocomplain -- $TARGET_DIR/*.inc]

# encrypt *vhdl files
# encrypt -k $HDK_SHELL_DIR/build/scripts/vivado_vhdl_keyfile.txt -lang vhdl -quiet [ glob -nocomplain -- $TARGET_DIR/*.vhd? ]

