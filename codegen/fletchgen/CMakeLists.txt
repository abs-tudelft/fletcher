cmake_minimum_required(VERSION 3.5)
set(FLETCHGEN fletchgen)
project(${FLETCHGEN})

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_DEBUG} -Wall")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Ofast -march=native")

set(HEADERS
        src/stream.h
        src/types.h
        src/nodes.h
        src/components.h
        src/fletcher_types.h
        src/fletcher_components.h
        src/vhdl/vhdl.h
        src/vhdl/block.h
        src/dot/dot.h
        )

set(SOURCES
        src/stream.cc
        src/types.cc
        src/nodes.cc
        src/components.cc
        src/fletcher_types.cc
        src/fletcher_components.cc
        src/vhdl/vhdl.cc
        src/vhdl/block.cc
        src/dot/dot.cc
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
endif ()
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

    set(TEST_SOURCES
            test/test.cc
            test/test_designs.h
            test/dot/test_graphs.h
            test/vhdl/test_declarators.h
            test/vhdl/test_instantiators.h
            test/vhdl/test_fletcher_components.h
            )
    add_executable(${FLETCHGEN}-test ${TEST_HEADERS} ${TEST_SOURCES})
    target_link_libraries(${FLETCHGEN}-test ${FLETCHGEN}-static)
    target_link_libraries(${FLETCHGEN}-test ${LIB_ARROW})
    target_link_libraries(${FLETCHGEN}-test GTest::GTest GTest::Main)
    target_include_directories(${FLETCHGEN}-test PUBLIC ../../platforms/echo/runtime/src)

    gtest_discover_tests(${FLETCHGEN}-test PROPERTIES ENVIRONMENT "LD_LIBRARY_PATH=${FLETCHER_ECHO_LIBDIR}")
endif (FLETCHER_TESTS)
