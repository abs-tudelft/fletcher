cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletchgen VERSION 0.0.10 LANGUAGES CXX)

find_package(Arrow 0.17 CONFIG REQUIRED)

include(FindThreads)
include(FetchContent)

FetchContent_Declare(CLI11
  GIT_REPOSITORY  https://github.com/CLIUtils/CLI11.git
  GIT_TAG         v1.8.0
)
FetchContent_MakeAvailable(CLI11)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

FetchContent_Declare(cerata
    GIT_REPOSITORY  https://github.com/abs-tudelft/cerata.git
    GIT_TAG         develop
)
FetchContent_GetProperties(cerata)
if(NOT cerata_POPULATED)
  FetchContent_Populate(cerata)
  set(BUILD_CERATA_TESTS OFF CACHE BOOL "")
  set(BUILD_CERATA_DOT ON CACHE BOOL "")
  set(BUILD_CERATA_VHDL ON CACHE BOOL "")
  add_subdirectory(${cerata_SOURCE_DIR} ${cerata_BINARY_DIR})
endif()

include(CompileUnits)

if(NOT TARGET fletcher::common)
  add_subdirectory(../../../common/cpp common-cpp)
endif()
if(NOT TARGET fletcher::c)
  add_subdirectory(../../../common/c common-c)
endif()

add_compile_unit(
  OPT
  NAME fletchgen::obj
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
    src/fletchgen/fletchgen.cc
    src/fletchgen/nucleus.cc
    src/fletchgen/profiler.cc
    src/fletchgen/axi4_lite.cc

    src/fletchgen/srec/recordbatch.cc
    src/fletchgen/srec/srec.cc

    src/fletchgen/top/sim.cc
    src/fletchgen/top/axi.cc

    src/fletchgen/hls/vivado.cc
  TSTS
    test/fletchgen/test_array.cc
    test/fletchgen/test_bus.cc
    test/fletchgen/test_kernel.cc
    test/fletchgen/test_nucleus.cc
    test/fletchgen/test_mantle.cc
    test/fletchgen/test_misc.cc
    test/fletchgen/test_recordbatch.cc
    test/fletchgen/test_types.cc
    test/fletchgen/test_profiler.cc
    test/fletchgen/srec/test_srec.cc
  DEPS
    cerata
    arrow_shared
    fletcher::common
    fletcher::c
    CLI11::CLI11
    Threads::Threads
)

add_compile_unit(
  OPT
  NAME fletchgen::lib
  TYPE SHARED
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  DEPS
    fletchgen::obj
)

add_compile_unit(
  NAME fletchgen
  TYPE EXECUTABLE
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/fletchgen/main.cc
  DEPS
    fletchgen::obj
)

compile_units()

configure_file(src/fletchgen/config.h.in fletchgen_config/config.h)
include_directories(${PROJECT_BINARY_DIR})
