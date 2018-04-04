# Compile design for Questasim

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

  vcom -quiet -work work -93 $source_dir/utils/SimUtils.vhd
  vcom -quiet -work work -93 $source_dir/utils/Memory.vhd
  vcom -quiet -work work -93 $source_dir/utils/Utils.vhd
  vcom -quiet -work work -93 $source_dir/utils/Ram1R1W.vhd

  vcom -quiet -work work -93 $source_dir/streams/Streams.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamArb.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamBuffer.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamFIFOCounter.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamFIFO.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamGearbox.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamNormalizer.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamParallelizer.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamSerializer.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamSlice.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamSync.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamAccumulator.vhd
  vcom -quiet -work work -93 $source_dir/streams/StreamElementCounter.vhd

  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderConfigParse.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnReaderConfig.vhd
  vcom -quiet -work work -93 $source_dir/arrow/Arrow.vhd

  vcom -quiet -work work -93 $source_dir/arrow/BufferReaderCmdGenBusReq.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferReaderCmd.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferReaderPost.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferReaderRespCtrl.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferReaderResp.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BufferReader.vhd
  
  vcom -quiet -work work -93 $source_dir/arrow/BusArbiter.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BusArbiterVec.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BusBuffer.vhd
  
  vcom -quiet -work work -93 $source_dir/arrow/BusWriteArbiter.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BusWriteArbiterVec.vhd
  vcom -quiet -work work -93 $source_dir/arrow/BusWriteBuffer.vhd
  
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
  
  vcom -quiet -work work -93 $source_dir/arrow/ColumnWriterListSync.vhd
  vcom -quiet -work work -93 $source_dir/arrow/ColumnWriterListPrim.vhd
  
  vcom -quiet -work work -93 $source_dir/arrow/BufferWriter.vhd

  ###############################################################################
  # Testbenches
  ###############################################################################

  # vcom -work work -2008 streams/StreamSync_tb.vhd
  # vcom -work work -2008 streams/StreamSlice_tb.vhd
  # vcom -work work -2008 streams/StreamArb_tb.vhd
  # vcom -work work -2008 streams/StreamFIFOCounter_tb.vhd
  # vcom -work work -2008 streams/StreamFIFO_tb.vhd
  # vcom -work work -2008 streams/StreamParallelizer_tb.vhd < TODO: Fix gen. maps
  # vcom -work work -2008 streams/StreamSerializer_tb.vhd
  vcom -quiet -work work -2008 $source_dir/streams/StreamTbCons.vhd
  vcom -quiet -work work -2008 $source_dir/streams/StreamTbProd.vhd

  # vcom -work work -2008 arrow/BusArbiter_tb.vhd

  # vcom -work work -2008 arrow/BusMasterMock.vhd
  # vcom -work work -2008 arrow/BusSlaveMock.vhd
  # vcom -work work -2008 arrow/UserCoreMock.vhd

  # vcom -work work -2008 arrow/BufferReader_tb.vhd

  # vcom -work work -2008 arrow/ColumnReaderListSyncDecoder_tb.vhd
  # vcom -work work -2008 arrow/ColumnReaderListSync_tb.vhd
  
  vcom -quiet -work work -2008 $source_dir/arrow/BusWriteMasterMock.vhd
  vcom -quiet -work work -2008 $source_dir/arrow/BusWriteSlaveMock.vhd
  vcom -quiet -work work -2008 $source_dir/arrow/BusWriteArbiter_tb.vhd
  
}
