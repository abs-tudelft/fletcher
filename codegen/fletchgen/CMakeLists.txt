##############################################################################
# Configuration
##############################################################################
cmake_minimum_required(VERSION 3.10)
set(FLETCHGEN fletchgen)
project(${FLETCHGEN})

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror -Wno-error=unused-function")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Ofast -march=native")

##############################################################################
# Targets
##############################################################################
set(HEADERS
    src/fletchgen/schema.h
    src/fletchgen/bus.h
    src/fletchgen/mmio.h
    src/fletchgen/array.h
    src/fletchgen/basic_types.h
    src/fletchgen/mantle.h
    src/fletchgen/kernel.h
    src/fletchgen/options.h
    src/fletchgen/design.h
    src/fletchgen/utils.h
    src/fletchgen/recordbatch.h

    src/fletchgen/srec/recordbatch.h
    src/fletchgen/srec/srec.h

    src/fletchgen/top/sim.h
    src/fletchgen/top/axi.h

    src/fletchgen/hls/vivado.h
    )

set(SOURCES
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
    )

set(THIRD_PARTY_HEADERS
    src/CLI/CLI11.hpp
    )

include_directories(src)

add_executable(${FLETCHGEN} ${HEADERS} ${THIRD_PARTY_HEADERS} ${SOURCES} src/fletchgen/fletchgen.cc)

# Turn ON to use Arrow's logging facility.
option(ARROW_LOGGING "Use Arrow's logging facility" OFF)
if (ARROW_LOGGING)
  add_definitions(-DFLETCHER_USE_ARROW_LOGGING)
endif ()

##############################################################################
# Dependencies & Linking
##############################################################################
# Arrow
find_library(LIB_ARROW arrow)
target_link_libraries(${FLETCHGEN} ${LIB_ARROW})

# Cerata
# add_compile_definitions(LOGGING_ARROW)
add_subdirectory(../cerata cerata)
include_directories(../cerata/src)
target_link_libraries(${FLETCHGEN} cerata)

# Fletcher Common static library

# Enable tests for the common library before adding
if (FLETCHGEN_TESTS)
  set(FLETCHER_TESTS ON)
endif ()

# Add the common library
add_subdirectory(../../common/cpp fletcher-common)
include_directories(../../common/cpp/src)
include_directories(../../common/c/src)
target_link_libraries(${FLETCHGEN} fletcher-common)

##############################################################################
# Installation
##############################################################################
install(TARGETS ${FLETCHGEN} DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES ${RESOURCES} DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/fletcher/fletchgen)

##############################################################################
# Testing
##############################################################################
if (FLETCHGEN_TESTS)
  if (NOT TARGET gtest)
    include(../../BuildGTest.cmake)
  endif ()
  include(GoogleTest)
  enable_testing()

  set(TEST_SOURCES
      test/fletchgen/test.cc
      test/fletchgen/test_utils.h
      test/fletchgen/test_recordbatch.h
      test/fletchgen/test_kernel.h
      test/fletchgen/test_mantle.h
      test/fletchgen/test_bus.h
      test/fletchgen/srec/test_srec.h
      )

  include_directories(test)

  add_executable(${FLETCHGEN}-test ${HEADERS} ${THIRD_PARTY_HEADERS} ${SOURCES} ${TEST_HEADERS} ${TEST_SOURCES})

  # External libraries
  target_link_libraries(${FLETCHGEN}-test fletcher-common)
  include_directories(../../common/cpp/src)

  target_link_libraries(${FLETCHGEN}-test fletcher-common-examples)
  include_directories(../../common/cpp/test)

  target_link_libraries(${FLETCHGEN}-test cerata)
  target_link_libraries(${FLETCHGEN}-test ${LIB_ARROW})
  target_link_libraries(${FLETCHGEN}-test gtest gtest_main)

  # GoogleTest
  gtest_discover_tests(${FLETCHGEN}-test PROPERTIES ENVIRONMENT "LD_LIBRARY_PATH=${FLETCHER_ECHO_LIBDIR}")
endif (FLETCHGEN_TESTS)
