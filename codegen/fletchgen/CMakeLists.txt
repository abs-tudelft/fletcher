cmake_minimum_required(VERSION 3.10)
set(FLETCHGEN fletchgen)
project(${FLETCHGEN})

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Ofast -march=native")

# Dependencies

# Arrow
find_library(LIB_ARROW arrow)
# Common library, if not already built
if (NOT TARGET fletcher-common-static)
    add_subdirectory(../../common/cpp fletcher-common)
endif()

# Sources

set(HEADERS
        src/edges.h
        src/types.h
        src/nodes.h
        src/graphs.h

        src/fletcher_types.h
        src/fletcher_components.h

        src/vhdl/architecture.h
        src/vhdl/block.h
        src/vhdl/declaration.h
        src/vhdl/design.h
        src/vhdl/flatnode.h
        src/vhdl/identifier.h
        src/vhdl/instantiation.h
        src/vhdl/transformation.h
        src/vhdl/vhdl.h
        src/vhdl/vhdl_types.h

        src/dot/dot.h
        )

set(SOURCES
        src/edges.cc
        src/types.cc
        src/nodes.cc
        src/graphs.cc
        src/fletcher_types.cc
        src/fletcher_components.cc

        src/vhdl/architecture.cc
        src/vhdl/block.cc
        src/vhdl/declaration.cc
        src/vhdl/design.cc
        src/vhdl/flatnode.cc
        src/vhdl/identifier.cc
        src/vhdl/instantiation.cc
        src/vhdl/transformation.cc
        src/vhdl/vhdl.cc
        src/vhdl/vhdl_types.cc

        src/dot/dot.cc
        )

set(RESOURCES
        ../../hardware/vhdl/sim/sim_top.vhdt
        ../../hardware/vhdl/axi/axi_top.vhdt)

# Linking

add_library(${FLETCHGEN}-static STATIC ${HEADERS} ${SOURCES})
target_link_libraries(${FLETCHGEN}-static ${LIB_ARROW})
target_link_libraries(${FLETCHGEN}-static fletcher-common-static)

add_executable(${FLETCHGEN} src/fletchgen.cc)
target_link_libraries(${FLETCHGEN} ${LIB_ARROW})
target_link_libraries(${FLETCHGEN} fletchgen-static)
target_link_libraries(${FLETCHGEN} fletcher-common-static)

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

            test/fletcher/test_fletcher_designs.h
            test/fletcher/test_fletcher.h
            )
    add_executable(${FLETCHGEN}-test ${TEST_HEADERS} ${TEST_SOURCES})
    target_link_libraries(${FLETCHGEN}-test ${LIB_ARROW})
    target_link_libraries(${FLETCHGEN}-test fletchgen-static)
    target_link_libraries(${FLETCHGEN}-test fletcher-common-generate-static)
    target_link_libraries(${FLETCHGEN}-test GTest::GTest GTest::Main)
    target_include_directories(${FLETCHGEN}-test PUBLIC ../../common/cpp/src)
    target_include_directories(${FLETCHGEN}-test PUBLIC ../../common/cpp/test)

    gtest_discover_tests(${FLETCHGEN}-test PROPERTIES ENVIRONMENT "LD_LIBRARY_PATH=${FLETCHER_ECHO_LIBDIR}")
endif (FLETCHER_TESTS)
