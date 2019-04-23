# Fletcher files

${FLETCHER_HARDWARE_DIR}/vhdl/utils/Utils.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/utils/SimUtils.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/utils/Ram1R1W.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/buffers/Buffers.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/interconnect/Interconnect.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/streams/Streams.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamArb.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamBuffer.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamFIFOCounter.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamFIFO.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamGearbox.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamNormalizer.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamParallelizer.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamSerializer.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamSlice.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamSync.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamElementCounter.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamMaximizer.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamPseudoRandomGenerator.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamBarrel.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/streams/StreamAccumulator.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayConfigParse.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayConfig.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/Arrays.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/arrow/Arrow.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReaderCmdGenBusReq.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReaderCmd.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReaderPost.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReaderRespCtrl.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReaderResp.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReader.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferWriterCmdGenBusReq.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferWriterPreCmdGen.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferWriterPrePadder.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferWriterPre.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferWriter.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/interconnect/BusReadArbiter.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/interconnect/BusReadArbiterVec.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/interconnect/BusReadBuffer.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/interconnect/BusWriteArbiter.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/interconnect/BusWriteArbiterVec.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/interconnect/BusWriteBuffer.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayConfigParse.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayConfig.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayReaderArb.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayReaderLevel.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayReaderListPrim.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayReaderListSyncDecoder.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayReaderListSync.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayReaderList.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayReaderNull.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayReaderStruct.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayReaderUnlockCombine.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayReader.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayWriterArb.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayWriterLevel.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayWriterListPrim.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayWriterListSync.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/arrays/ArrayWriter.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/wrapper/Wrapper.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/wrapper/UserCoreController.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/axi/axi.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/axi/axi_mmio.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/axi/axi_read_converter.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/axi/axi_write_converter.vhd

# Fletcher to AWS glue
$FLETCHER_EXAMPLES_DIR/filter_hls/hardware/axi_top.vhd

# User provided hardware accelerated function
$FLETCHER_EXAMPLES_DIR/filter_hls/hardware/filter_hls_fletchbkb.vhd
$FLETCHER_EXAMPLES_DIR/filter_hls/hardware/filter_hls_fletcher.vhd
$FLETCHER_EXAMPLES_DIR/filter_hls/hardware/filter_usercore.vhd
$FLETCHER_EXAMPLES_DIR/filter_hls/hardware/filter_wrapper.vhd
