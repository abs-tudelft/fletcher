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
  add_source $source_dir/vhlib/util/UtilStr_pkg.vhd
  add_source $source_dir/vhlib/util/UtilInt_pkg.vhd
  add_source $source_dir/vhlib/util/UtilConv_pkg.vhd
  add_source $source_dir/vhlib/util/UtilMisc_pkg.vhd
  add_source $source_dir/vhlib/util/UtilMem64_pkg.vhd
  add_source $source_dir/vhlib/util/UtilRam_pkg.vhd
  add_source $source_dir/vhlib/util/UtilRam1R1W.vhd
  add_source $source_dir/vhlib/sim/TestCase_pkg.sim.08.vhd -2008
  add_source $source_dir/vhlib/sim/SimDataComms_pkg.sim.08.vhd -2008
  add_source $source_dir/vhlib/sim/ClockGen_pkg.sim.08.vhd -2008
  add_source $source_dir/vhlib/sim/ClockGen_mdl.sim.08.vhd -2008
}

proc add_arrow {{source_dir ""}} {
  echo "- Arrow specifics."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/arrow/Arrow_pkg.vhd
}

proc add_streams {{source_dir ""}} {
  echo "- Streams library."
  set source_dir [source_dir_or_default $source_dir]

  # Synthesis package
  add_source $source_dir/vhlib/stream/Stream_pkg.vhd

  # Buffers
  add_source $source_dir/vhlib/stream/StreamSlice.vhd
  add_source $source_dir/vhlib/stream/StreamFIFOCounter.vhd
  add_source $source_dir/vhlib/stream/StreamFIFO.vhd
  add_source $source_dir/vhlib/stream/StreamBuffer.vhd

  # Split & merge
  add_source $source_dir/vhlib/stream/StreamSync.vhd
  add_source $source_dir/vhlib/stream/StreamArb.vhd

  # Pipelines
  add_source $source_dir/vhlib/stream/StreamPipelineControl.vhd
  add_source $source_dir/vhlib/stream/StreamPipelineBarrel.vhd

  # Reshapers
  add_source $source_dir/vhlib/stream/StreamGearboxSerializer.vhd
  add_source $source_dir/vhlib/stream/StreamGearboxParallelizer.vhd
  add_source $source_dir/vhlib/stream/StreamGearbox.vhd
  add_source $source_dir/vhlib/stream/StreamNormalizer.vhd
  add_source $source_dir/vhlib/stream/StreamReshaper.vhd

  # Arithmetic
  add_source $source_dir/vhlib/stream/StreamElementCounter.vhd
  add_source $source_dir/vhlib/stream/StreamPRNG.vhd
  add_source $source_dir/vhlib/stream/StreamPrefixSum.vhd

}

proc add_streams_tb {{source_dir ""}} {
  echo "- Streams library simulation support."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/vhlib/stream/model/StreamMonitor_pkg.sim.08.vhd -2008
  add_source $source_dir/vhlib/stream/model/StreamMonitor_mdl.sim.08.vhd -2008
  add_source $source_dir/vhlib/stream/model/StreamSource_pkg.sim.08.vhd -2008
  add_source $source_dir/vhlib/stream/model/StreamSource_mdl.sim.08.vhd -2008
  add_source $source_dir/vhlib/stream/model/StreamSink_pkg.sim.08.vhd -2008
  add_source $source_dir/vhlib/stream/model/StreamSink_mdl.sim.08.vhd -2008
}

proc add_interconnect {{source_dir ""}} {
  echo "- Bus infrastructure."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/interconnect/Interconnect_pkg.vhd
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
  add_source $source_dir/interconnect/test/BusChecking_pkg.vhd
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
  add_source $source_dir/buffers/Buffer_pkg.vhd
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
  add_source $source_dir/arrays/ArrayConfigParse_pkg.vhd
  add_source $source_dir/arrays/ArrayConfig_pkg.vhd
  add_source $source_dir/arrays/Array_pkg.vhd
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
  add_source $source_dir/axi/Axi_pkg.vhd
  add_source $source_dir/axi/AxiMmio.vhd
  add_source $source_dir/axi/AxiWriteConverter.vhd
  add_source $source_dir/axi/AxiReadConverter.vhd
}

proc add_axi_tb {{source_dir ""}} {
  echo "- AXI tests."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/axi/test/AxiMmio_tc.vhd
}


proc add_wrapper {{source_dir ""}} {
  echo "- Wrapper components."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/wrapper/UserCoreController.vhd
  add_source $source_dir/wrapper/Wrapper_pkg.vhd
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
