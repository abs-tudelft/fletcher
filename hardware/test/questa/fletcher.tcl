# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Check if environment variables are set
if {![info exists ::env(FLETCHER_HARDWARE_DIR)]} {
  error "Environment variable FLETCHER_HARDWARE_DIR not set. Please source fletcher/env.sh."
}

# Load compilation script and utilities
source $::env(FLETCHER_HARDWARE_DIR)/test/questa/compile.tcl
source $::env(FLETCHER_HARDWARE_DIR)/test/questa/utils.tcl

proc source_dir_or_default {source_dir} {
  if {$source_dir == ""} {
    return $::env(FLETCHER_HARDWARE_DIR)
  } else {
    return $source_dir
  }
}

proc add_utils {{source_dir ""}} {
  echo "- Utilities."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/utils/SimUtils.vhd
  add_source $source_dir/utils/Memory.vhd
  add_source $source_dir/utils/Ram1R1W.vhd
  add_source $source_dir/utils/Utils.vhd
}

proc add_arrow {{source_dir ""}} {
  echo "- Arrow specifics."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/arrow/Arrow.vhd
}

proc add_streams {{source_dir ""}} {
  echo "- Streams library."
  set source_dir [source_dir_or_default $source_dir]

  # Synthesis package
  add_source $source_dir/streams/Streams.vhd

  # Buffers
  add_source $source_dir/streams/StreamSlice.vhd
  add_source $source_dir/streams/StreamFIFOCounter.vhd
  add_source $source_dir/streams/StreamFIFO.vhd
  add_source $source_dir/streams/StreamBuffer.vhd

  # Split & merge
  add_source $source_dir/streams/StreamSync.vhd
  add_source $source_dir/streams/StreamArb.vhd

  # Pipelines
  add_source $source_dir/streams/StreamPipelineControl.vhd
  add_source $source_dir/streams/StreamPipelineBarrel.vhd

  # Reshapers
  add_source $source_dir/streams/StreamSerializer.vhd
  add_source $source_dir/streams/StreamParallelizer.vhd
  add_source $source_dir/streams/StreamGearbox.vhd
  add_source $source_dir/streams/StreamNormalizer.vhd
  add_source $source_dir/streams/StreamReshaper.vhd

  # Arithmetic
  add_source $source_dir/streams/StreamAccumulator.vhd
  add_source $source_dir/streams/StreamElementCounter.vhd
  add_source $source_dir/streams/StreamPseudoRandomGenerator.vhd
  add_source $source_dir/streams/StreamPrefixSum.vhd
}

proc add_streams_tb {{source_dir ""}} {
  echo "- Streams library simulation support."
  set source_dir [source_dir_or_default $source_dir]
  # Simulation package
  add_source $source_dir/streams/test/StreamSim.vhd -2008
  # Stream endpoint models
  add_source $source_dir/streams/test/StreamTbProd.vhd -2008
  add_source $source_dir/streams/test/StreamTbMon.vhd -2008
  add_source $source_dir/streams/test/StreamTbCons.vhd -2008
}

proc add_interconnect {{source_dir ""}} {
  echo "- Bus infrastructure."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/interconnect/Interconnect.vhd
  add_source $source_dir/interconnect/BusReadArbiter.vhd
  add_source $source_dir/interconnect/BusReadArbiterVec.vhd
  add_source $source_dir/interconnect/BusReadBuffer.vhd
  add_source $source_dir/interconnect/BusWriteArbiter.vhd
  add_source $source_dir/interconnect/BusWriteArbiterVec.vhd
  add_source $source_dir/interconnect/BusWriteBuffer.vhd
}

proc add_interconnect_tb {{source_dir ""}} {
  echo "- Bus infrastructure simulation support."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/interconnect/test/BusChecking.vhd
  add_source $source_dir/interconnect/test/BusProtocolChecker.vhd
  add_source $source_dir/interconnect/test/BusReadSlaveMock.vhd
  add_source $source_dir/interconnect/test/BusReadMasterMock.vhd
  add_source $source_dir/interconnect/test/BusWriteSlaveMock.vhd
  add_source $source_dir/interconnect/test/BusWriteMasterMock.vhd
  add_source $source_dir/interconnect/test/BusReadArbiter_tb.vhd
}

proc add_buffers {{source_dir ""}} {
  echo "- Buffer Readers/Writers."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/buffers/Buffers.vhd
  add_source $source_dir/buffers/BufferReaderCmdGenBusReq.vhd
  add_source $source_dir/buffers/BufferReaderCmd.vhd
  add_source $source_dir/buffers/BufferReaderPost.vhd
  add_source $source_dir/buffers/BufferReaderRespCtrl.vhd
  add_source $source_dir/buffers/BufferReaderResp.vhd
  add_source $source_dir/buffers/BufferReader.vhd
  add_source $source_dir/buffers/BufferWriterCmdGenBusReq.vhd
  add_source $source_dir/buffers/BufferWriterPrePadder.vhd
  add_source $source_dir/buffers/BufferWriterPreCmdGen.vhd
  add_source $source_dir/buffers/BufferWriterPre.vhd
  add_source $source_dir/buffers/BufferWriter.vhd
}

proc add_arrays {{source_dir ""}} {
  echo "- Array Readers/Writers."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/arrays/ArrayConfigParse.vhd
  add_source $source_dir/arrays/ArrayConfig.vhd
  add_source $source_dir/arrays/Arrays.vhd
  add_source $source_dir/arrays/ArrayReaderArb.vhd
  add_source $source_dir/arrays/ArrayReaderLevel.vhd
  add_source $source_dir/arrays/ArrayReaderList.vhd
  add_source $source_dir/arrays/ArrayReaderListPrim.vhd
  add_source $source_dir/arrays/ArrayReaderListSync.vhd
  add_source $source_dir/arrays/ArrayReaderListSyncDecoder.vhd
  add_source $source_dir/arrays/ArrayReaderNull.vhd
  add_source $source_dir/arrays/ArrayReaderStruct.vhd
  add_source $source_dir/arrays/ArrayReaderUnlockCombine.vhd
  add_source $source_dir/arrays/ArrayReader.vhd
  add_source $source_dir/arrays/ArrayWriterArb.vhd
  add_source $source_dir/arrays/ArrayWriterListSync.vhd
  add_source $source_dir/arrays/ArrayWriterListPrim.vhd
  add_source $source_dir/arrays/ArrayWriterLevel.vhd
  add_source $source_dir/arrays/ArrayWriter.vhd
}

proc add_axi {{source_dir ""}} {
  echo "- AXI support."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/axi/axi.vhd
  add_source $source_dir/axi/axi_mmio.vhd
  add_source $source_dir/axi/axi_write_converter.vhd
  add_source $source_dir/axi/axi_read_converter.vhd
}

proc add_axi_tb {{source_dir ""}} {
  echo "- AXI tests."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/axi/test/axi_mmio_tb.vhd
}


proc add_wrapper {{source_dir ""}} {
  echo "- Wrapper components."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/wrapper/UserCoreController.vhd
  add_source $source_dir/wrapper/Wrapper.vhd
}

proc add_wrapper_tb {{source_dir ""}} {
  echo "- Wrapper simulation support."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/wrapper/test/UserCoreMock.vhd -2008
}

# Add all sources
proc add_fletcher {{source_dir ""}} {
  echo "Adding Fletcher sources:"
  set source_dir [source_dir_or_default $source_dir]
  add_utils $source_dir
  add_arrow $source_dir
  add_streams $source_dir
  add_interconnect $source_dir
  add_buffers $source_dir
  add_arrays $source_dir
  add_wrapper $source_dir
  add_axi $source_dir
}

# Compile all Fletcher simulation sources.
proc add_fletcher_tb {{source_dir ""}} {
  echo "Adding Fletcher simulation sources:"
  set source_dir [source_dir_or_default $source_dir]
  add_streams_tb $source_dir
  add_interconnect_tb $source_dir
  add_wrapper_tb $source_dir
  add_axi_tb $source_dir
}
