cmake_minimum_required(VERSION 3.5)
set(FLETCHGEN fletchgen)
project(${FLETCHGEN})

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_DEBUG} -Wall")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Ofast -march=native")

set(HEADERS
        src/logging.h
        src/meta.h
        src/constants.h
        src/common.h
        src/arrow-meta.h
        src/printers.h
        src/vhdl/vhdl.h
        src/stream.h
        src/column.h
        src/arbiter.h
        src/fletcher-streams.h
        src/fletcher-ports.h
        src/column-wrapper.h
        src/usercore.h
        src/usercore-controller.h
        src/srec/srec.h
        src/srec/recordbatch.h
        src/vhdt/vhdt.h
        src/top/axi.h
        src/top/sim.h
        src/config.h
        src/stream/stream.h
        src/stream/vhdl.h
        src/stream/types.h
        src/stream/nodes.h
        src/stream/components.h
        src/stream/dot.h
        )

set(SOURCES
        src/common.cc
        src/arrow-meta.cc
        src/printers.cc
        src/vhdl/vhdl.cc
        src/stream.cc
        src/column.cc
        src/arbiter.cc
        src/fletcher-streams.cc
        src/fletcher-ports.cc
        src/column-wrapper.cc
        src/usercore.cc
        src/usercore-controller.cc
        src/srec/srec.cc
        src/srec/recordbatch.cc
        src/vhdt/vhdt.cc
        src/top/axi.cc
        src/top/sim.cc
        src/config.cc
        src/stream/stream.cc
        src/stream/vhdl.cc
        src/stream/types.cc
        src/stream/nodes.cc
        src/stream/components.cc
        src/stream/dot.cc
        )

set(RESOURCES
        ../../hardware/vhdl/sim/sim_top.vhdt
        ../../hardware/vhdl/axi/axi_top.vhdt)

add_library(${FLETCHGEN}-static ${HEADERS} ${SOURCES})

add_executable(${FLETCHGEN} src/fletchgen.cc)
target_link_libraries(${FLETCHGEN} ${FLETCHGEN}-static)

# Include common functions, build it and link statically
if (NOT TARGET fletcher-common)
    add_subdirectory(../../common/cpp fletcher-common)
endif()
target_link_libraries(${FLETCHGEN} fletcher-common)
include_directories(../../common/cpp/src)

find_library(LIB_ARROW arrow)
target_link_libraries(${FLETCHGEN} ${REQUIRED} ${LIB_ARROW})

find_package(Boost COMPONENTS program_options REQUIRED)
target_link_libraries(${FLETCHGEN} ${REQUIRED} Boost::program_options)

install(TARGETS ${FLETCHGEN} DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES ${RESOURCES} DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/fletcher/fletchgen)

########################################################################################################################
# TESTS
########################################################################################################################
if (FLETCHER_TESTS)
    enable_testing()
    include(GoogleTest)
    find_package(GTest REQUIRED)

    set(TEST_SOURCES test/test.cc)
    add_executable(${FLETCHGEN}-test ${TEST_HEADERS} ${TEST_SOURCES})
    target_link_libraries(${FLETCHGEN}-test ${FLETCHGEN}-static)
    target_link_libraries(${FLETCHGEN}-test ${LIB_ARROW})
    target_link_libraries(${FLETCHGEN}-test GTest::GTest GTest::Main)
    target_include_directories(${FLETCHGEN}-test PUBLIC ../../platforms/echo/runtime/src)

    gtest_discover_tests(${FLETCHGEN}-test PROPERTIES ENVIRONMENT "LD_LIBRARY_PATH=${FLETCHER_ECHO_LIBDIR}")
endif (FLETCHER_TESTS)
