cmake_minimum_required(VERSION 3.10)
project(cerata)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Ofast -march=native")

# Sources
set(HEADERS
        src/cerata/edges.h
        src/cerata/types.h
        src/cerata/nodes.h
        src/cerata/graphs.h
        src/cerata/flattypes.h
        src/cerata/utils.h

        src/cerata/vhdl/architecture.h
        src/cerata/vhdl/block.h
        src/cerata/vhdl/declaration.h
        src/cerata/vhdl/design.h
        src/cerata/vhdl/flatnode.h
        src/cerata/vhdl/identifier.h
        src/cerata/vhdl/instantiation.h
        src/cerata/vhdl/transformation.h
        src/cerata/vhdl/vhdl.h
        src/cerata/vhdl/vhdl_types.h

        src/cerata/dot/dot.h
        src/cerata/dot/style.h
        )

set(SOURCES
        src/cerata/edges.cc
        src/cerata/types.cc
        src/cerata/nodes.cc
        src/cerata/graphs.cc
        src/cerata/flattypes.cc

        src/cerata/vhdl/architecture.cc
        src/cerata/vhdl/block.cc
        src/cerata/vhdl/declaration.cc
        src/cerata/vhdl/design.cc
        src/cerata/vhdl/flatnode.cc
        src/cerata/vhdl/identifier.cc
        src/cerata/vhdl/instantiation.cc
        src/cerata/vhdl/transformation.cc
        src/cerata/vhdl/vhdl.cc
        src/cerata/vhdl/vhdl_types.cc

        src/cerata/dot/dot.cc
        src/cerata/dot/style.cc
        )

include_directories(src)

# Linking
add_library(${PROJECT_NAME} STATIC ${HEADERS} ${SOURCES})

########################################################################################################################
# TESTS
########################################################################################################################
if (CERATA_TESTS)
    enable_testing()
    include(GoogleTest)
    find_package(GTest REQUIRED)

    set(TEST_SOURCES
            # Intermeditate
            test/cerata/test.cc
            test/cerata/test_types.h
            test/cerata/test_expressions.h
            test/cerata/test_designs.h

            # Back-ends
            test/cerata/dot/test_graphs.h

            test/cerata/vhdl/test_declarators.h
            test/cerata/vhdl/test_instantiators.h
            )
    add_executable(${PROJECT_NAME}-test ${TEST_HEADERS} ${TEST_SOURCES})
    target_link_libraries(${PROJECT_NAME}-test GTest::GTest GTest::Main)
    target_link_libraries(${PROJECT_NAME}-test ${PROJECT_NAME})

    gtest_discover_tests(cerata-test)
endif (CERATA_TESTS)
