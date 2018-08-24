# Compile design for Questasim

proc compile_utils {source_dir} {
  echo "- Utilities."
  vcom -quiet -work work -93 $source_dir/utils/SimUtils.vhd
  vcom -quiet -work work -93 $source_dir/utils/Memory.vhd
  vcom -quiet -work work -93 $source_dir/utils/Ram1R1W.vhd
  vcom -quiet -work work -93 $source_dir/utils/Utils.vhd
}

proc compile_arrow {source_dir} {
  echo "- Arrow specifics."
  vcom -quiet -work work -93 $source_dir/arrow/Arrow.vhd
}

proc compile_streams {source_dir} {
  echo "- Streams library."
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

proc compile_streams_tb {source_dir} {
  vcom -quiet -work work -2008 $source_dir/streams/StreamTbCons.vhd
  vcom -quiet -work work -2008 $source_dir/streams/StreamTbProd.vhd
}

proc compile_interconnect {source_dir} {
  echo "- Bus infrastructure."
  vcom -quiet -work work -93 $source_dir/interconnect/Interconnect.vhd
  vcom -quiet -work work -93 $source_dir/interconnect/BusReadArbiter.vhd
  vcom -quiet -work work -93 $source_dir/interconnect/BusReadArbiterVec.vhd
  vcom -quiet -work work -93 $source_dir/interconnect/BusReadBuffer.vhd

  vcom -quiet -work work -93 $source_dir/interconnect/BusWriteArbiter.vhd
  vcom -quiet -work work -93 $source_dir/interconnect/BusWriteArbiterVec.vhd
  vcom -quiet -work work -93 $source_dir/interconnect/BusWriteBuffer.vhd
}

proc compile_interconnect_tb {source_dir} {
  vcom -quiet -work work -2008 $source_dir/interconnect/BusReadSlaveMock.vhd
  #vcom -quiet -work work -2008 $source_dir/BusReadArbiter_tb.vhd
  #vcom -quiet -work work -2008 $source_dir/BusWriteArbiter_tb.vhd
}

proc compile_buffers {source_dir} {
  echo "- Buffer Readers/Writers."
  vcom -quiet -work work -93 $source_dir/buffers/Buffers.vhd
  vcom -quiet -work work -93 $source_dir/buffers/BufferReaderCmdGenBusReq.vhd
  vcom -quiet -work work -93 $source_dir/buffers/BufferReaderCmd.vhd
  vcom -quiet -work work -93 $source_dir/buffers/BufferReaderPost.vhd
  vcom -quiet -work work -93 $source_dir/buffers/BufferReaderRespCtrl.vhd
  vcom -quiet -work work -93 $source_dir/buffers/BufferReaderResp.vhd
  vcom -quiet -work work -93 $source_dir/buffers/BufferReader.vhd

  vcom -quiet -work work -93 $source_dir/buffers/BufferWriterCmdGenBusReq.vhd
  vcom -quiet -work work -93 $source_dir/buffers/BufferWriterPrePadder.vhd
  vcom -quiet -work work -93 $source_dir/buffers/BufferWriterPreCmdGen.vhd
  vcom -quiet -work work -93 $source_dir/buffers/BufferWriterPre.vhd
  vcom -quiet -work work -93 $source_dir/buffers/BufferWriter.vhd
}

proc compile_columns {source_dir} {
  echo "- Column Readers/Writers."
  vcom -quiet -work work -93 $source_dir/columns/ColumnConfigParse.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnConfig.vhd
  vcom -quiet -work work -93 $source_dir/columns/Columns.vhd

  vcom -quiet -work work -93 $source_dir/columns/ColumnReaderArb.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnReaderLevel.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnReaderList.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnReaderListPrim.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnReaderListSync.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnReaderListSyncDecoder.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnReaderNull.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnReaderStruct.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnReaderUnlockCombine.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnReader.vhd

  vcom -quiet -work work -93 $source_dir/columns/ColumnWriterArb.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnWriterListSync.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnWriterListPrim.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnWriterLevel.vhd
  vcom -quiet -work work -93 $source_dir/columns/ColumnWriter.vhd
}

proc compile_wrapper {source_dir} {
  echo "- Wrapper components."
  vcom -quiet -work work -93 $source_dir/wrapper/UserCoreController.vhd
  vcom -quiet -work work -93 $source_dir/wrapper/Wrapper.vhd
}

proc compile_fletcher {source_dir} {

  echo "Compiling Fletcher sources:"

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
  compile_arrow $source_dir
  compile_streams $source_dir
  compile_interconnect $source_dir
  compile_buffers $source_dir
  compile_columns $source_dir
  compile_wrapper $source_dir
  compile_columns $source_dir

}
