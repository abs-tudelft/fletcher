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
source $::env(FLETCHER_HARDWARE_DIR)/test/compile.tcl
source $::env(FLETCHER_HARDWARE_DIR)/test/utils.tcl

proc source_dir_or_default {source_dir} {
  if {$source_dir == ""} {
    return $::env(FLETCHER_HARDWARE_DIR)/vhdl
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
  add_source $source_dir/utils/Ram1R1W_NP2.vhd
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
}

proc add_streams_tb {{source_dir ""}} {
  echo "- Streams library simulation support."
  set source_dir [source_dir_or_default $source_dir]

  # Simulation package
  add_source $source_dir/streams/StreamSim.vhd -2008

  # Stream endpoint models
  add_source $source_dir/streams/StreamTbProd.vhd -2008
  add_source $source_dir/streams/StreamTbMon.vhd -2008
  add_source $source_dir/streams/StreamTbCons.vhd -2008
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
  
  add_source $source_dir/interconnect/BusReadBenchmarker.vhd
}

proc add_interconnect_tb {{source_dir ""}} {
  echo "- Bus infrastructure simulation support."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/interconnect/BusChecking.vhd
  add_source $source_dir/interconnect/BusProtocolChecker.vhd

  add_source $source_dir/interconnect/BusReadSlaveMock.vhd
  add_source $source_dir/interconnect/BusReadMasterMock.vhd
  
  add_source $source_dir/interconnect/BusWriteSlaveMock.vhd
  add_source $source_dir/interconnect/BusWriteMasterMock.vhd
  
  add_source $source_dir/interconnect/BusReadArbiter_tb.vhd
  
  add_source $source_dir/interconnect/BusReadBenchmarker_tb.vhd
  add_source $source_dir/interconnect/BusBurstModel_tb.vhd
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

proc add_columns {{source_dir ""}} {
  echo "- Column Readers/Writers."
  set source_dir [source_dir_or_default $source_dir]
  add_source $source_dir/columns/ColumnConfigParse.vhd
  add_source $source_dir/columns/ColumnConfig.vhd
  add_source $source_dir/columns/Columns.vhd
  
  add_source $source_dir/columns/ColumnReaderArb.vhd
  add_source $source_dir/columns/ColumnReaderLevel.vhd
  add_source $source_dir/columns/ColumnReaderList.vhd
  add_source $source_dir/columns/ColumnReaderListPrim.vhd
  add_source $source_dir/columns/ColumnReaderListSync.vhd
  add_source $source_dir/columns/ColumnReaderListSyncDecoder.vhd
  add_source $source_dir/columns/ColumnReaderNull.vhd
  add_source $source_dir/columns/ColumnReaderStruct.vhd
  add_source $source_dir/columns/ColumnReaderUnlockCombine.vhd
  add_source $source_dir/columns/ColumnReader.vhd
  
  add_source $source_dir/columns/ColumnWriterArb.vhd
  add_source $source_dir/columns/ColumnWriterListSync.vhd
  add_source $source_dir/columns/ColumnWriterListPrim.vhd
  add_source $source_dir/columns/ColumnWriterLevel.vhd
  add_source $source_dir/columns/ColumnWriter.vhd
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
  add_source $source_dir/wrapper/UserCoreMock.vhd -2008
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
  add_columns $source_dir
  add_wrapper $source_dir
}

# Compile all Fletcher simulation sources.
proc add_fletcher_tb {{source_dir ""}} {
  echo "Adding Fletcher simulation sources:"
  set source_dir [source_dir_or_default $source_dir]
  add_streams_tb $source_dir
  add_interconnect_tb $source_dir
  add_wrapper_tb $source_dir
}
