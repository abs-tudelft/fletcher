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

${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnConfigParse.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnConfig.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/columns/Columns.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/arrow/Arrow.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReaderCmdGenBusReq.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReaderCmd.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReaderPost.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReaderRespCtrl.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReaderResp.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/buffers/BufferReader.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/interconnect/BusReadArbiter.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/interconnect/BusReadArbiterVec.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/interconnect/BusReadBuffer.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnReaderArb.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnReaderLevel.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnReaderList.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnReaderListPrim.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnReaderListSync.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnReaderListSyncDecoder.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnReaderNull.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnReaderStruct.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnReaderUnlockCombine.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/columns/ColumnReader.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/wrapper/Wrapper.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/wrapper/UserCoreController.vhd

${FLETCHER_HARDWARE_DIR}/vhdl/axi/axi.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/axi/axi_mmio.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/axi/axi_read_converter.vhd
${FLETCHER_HARDWARE_DIR}/vhdl/axi/axi_write_converter.vhd

# Fletcher to AWS glue
$FLETCHER_EXAMPLES_DIR/k-means/hardware/fletcher_wrapper.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/axi_top.vhd

# User provided hardware accelerated function
$FLETCHER_EXAMPLES_DIR/k-means/hardware/kmeans.vhd

$FLETCHER_EXAMPLES_DIR/k-means/hardware/accumulator.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/adder.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/adder_tree.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/axi_funnel.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/distance.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/divider.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/filter.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/mask.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/point_accumulators.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/selector.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/selector_tree.vhd
$FLETCHER_EXAMPLES_DIR/k-means/hardware/square.vhd


# IP simulation files
#${CL_ROOT}/design/ip/floating_point_add_double/sim/floating_point_add_double.vhd
#${CL_ROOT}/design/ip/floating_point_lt_double/sim/floating_point_lt_double.vhd
#${CL_ROOT}/design/ip/floating_point_mult_double/sim/floating_point_mult_double.vhd
#${CL_ROOT}/design/ip/floating_point_sub_double/sim/floating_point_sub_double.vhd

