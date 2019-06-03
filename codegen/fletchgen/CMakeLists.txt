add_compile_unit(
  OPT
  NAME fletchgen::lib
  TYPE OBJECT
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/fletchgen/schema.cc
    src/fletchgen/bus.cc
    src/fletchgen/mmio.cc
    src/fletchgen/array.cc
    src/fletchgen/basic_types.cc
    src/fletchgen/mantle.cc
    src/fletchgen/kernel.cc
    src/fletchgen/options.cc
    src/fletchgen/design.cc
    src/fletchgen/utils.cc
    src/fletchgen/recordbatch.cc

    src/fletchgen/srec/recordbatch.cc
    src/fletchgen/srec/srec.cc

    src/fletchgen/top/sim.cc
    src/fletchgen/top/axi.cc

    src/fletchgen/hls/vivado.cc
  DEPS
    cerata
    arrow_shared
    fletcher::common
    CLI11::CLI11
)

add_compile_unit(
  OPT
  NAME fletchgen::test::utils
  TYPE OBJECT
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    test/fletchgen/test_utils.h
  DEPS
    arrow_shared
)

add_compile_unit(
  OPT
  NAME fletchgen::tests
  TYPE TESTS
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    test/fletchgen/test.cc
  DEPS
    cerata
    fletchgen::lib
    fletchgen::test::utils
    fletcher::test::utils
)

add_compile_unit(
  OPT
  NAME fletchgen
  TYPE EXECUTABLE
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/fletchgen/fletchgen.cc
  DEPS
    fletchgen::lib
)
