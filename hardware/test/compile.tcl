# Compile design for Questasim

proc compile_utils {source_dir} {
  vcom -quiet -work work -93 $source_dir/utils/SimUtils.vhd
  vcom -quiet -work work -93 $source_dir/utils/Memory.vhd
  vcom -quiet -work work -93 $source_dir/utils/Utils.vhd
  vcom -quiet -work work -93 $source_dir/utils/Ram1R1W.vhd
}

proc compile_streams {source_dir} {
  vcom -quiet -work work -93 $source_dir/streams/Streams.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamArb.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamBuffer.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamFIFOCounter.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamFIFO.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamGearbox.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamNormalizer.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamMaximizer.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamParallelizer.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamSerializer.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamSlice.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamSync.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamAccumulator.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamElementCounter.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamBarrel.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamPseudoRandomGenerator.vhd
}

proc compile_bus {source_dir} {
  vcom -quiet -work work -93 $source_dir/arrow/BusArbiter.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BusArbiterVec.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BusBuffer.vhd
  
  vcom -quiet -work work -93 $source_dir/arrow/BusWriteArbiter.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BusWriteArbiterVec.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BusWriteBuffer.vhd
}

proc compile_fletcher {source_dir} {
  
  echo "Compiling Fletcher sources"

  vlib work

  ###############################################################################
  # Libraries
  ###############################################################################

  # Delete what was already in "work". It's optional, but recommended if changes
  # to the compile script are still being made.

  catch {vdel -all -lib work}

  vlib work

  ###############################################################################
  # Sources
  ###############################################################################

  compile_utils $source_dir
   
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderConfigParse.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderConfig.vhd
  vcom -quiet -work work -93 $source_dir/arrow/Arrow.vhd

  compile_streams $source_dir
  compile_bus $source_dir

  vcom -quiet -work work -93 $source_dir/arrow/BufferReaderCmdGenBusReq.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferReaderCmd.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferReaderPost.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferReaderRespCtrl.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferReaderResp.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferReader.vhd
    
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderArb.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderLevel.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderList.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderListPrim.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderListSync.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderListSyncDecoder.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderNull.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderStruct.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderUnlockCombine.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReader.vhd
  
  vcom -quiet -work work -93 $source_dir/arrow/BufferWriterCmdGenBusReq.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferWriterPrePadder.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferWriterPreCmdGen.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferWriterPre.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferWriter.vhd  
  
  
  vcom -quiet -work work -93 $source_dir/arrow/ColumnWriterArb.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnWriterListSync.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnWriterListPrim.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnWriterLevel.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnWriter.vhd
  
}
