##############################################################################
# Configuration
##############################################################################
cmake_minimum_required(VERSION 3.10)
project(cerata)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Ofast -march=native")

##############################################################################
# Targets
##############################################################################
# Sources
set(HEADERS
    src/cerata/utils.h
    src/cerata/node_array.h
    src/cerata/edge.h
    src/cerata/object.h
    src/cerata/type.h
    src/cerata/node.h
    src/cerata/expression.h
    src/cerata/graph.h
    src/cerata/flattype.h
    src/cerata/output.h
    src/cerata/transform.h
    src/cerata/logging.h
    src/cerata/pool.h

    src/cerata/vhdl/architecture.h
    src/cerata/vhdl/block.h
    src/cerata/vhdl/declaration.h
    src/cerata/vhdl/design.h
    src/cerata/vhdl/identifier.h
    src/cerata/vhdl/instantiation.h
    src/cerata/vhdl/resolve.h
    src/cerata/vhdl/vhdl.h
    src/cerata/vhdl/vhdl_types.h
    src/cerata/vhdl/template.h

    src/cerata/dot/dot.h
    src/cerata/dot/style.h
    )

set(SOURCES
    src/cerata/utils.cc
    src/cerata/node_array.cc
    src/cerata/edge.cc
    src/cerata/object.cc
    src/cerata/type.cc
    src/cerata/node.cc
    src/cerata/expression.cc
    src/cerata/graph.cc
    src/cerata/flattype.cc
    src/cerata/output.cc
    src/cerata/transform.cc
    src/cerata/pool.cc

    src/cerata/vhdl/architecture.cc
    src/cerata/vhdl/block.cc
    src/cerata/vhdl/declaration.cc
    src/cerata/vhdl/design.cc
    src/cerata/vhdl/identifier.cc
    src/cerata/vhdl/instantiation.cc
    src/cerata/vhdl/resolve.cc
    src/cerata/vhdl/vhdl.cc
    src/cerata/vhdl/vhdl_types.cc
    src/cerata/vhdl/template.cc

    src/cerata/dot/dot.cc
    src/cerata/dot/style.cc
    )

include_directories(src)

add_library(${PROJECT_NAME} STATIC ${HEADERS} ${SOURCES})

########################################################################################################################
# TESTS
########################################################################################################################
if (CERATA_TESTS)
  if (NOT TARGET gtest)
    include(../../BuildGTest.cmake)
  endif ()
  include(GoogleTest)
  enable_testing()

  set(TEST_SOURCES
      # Intermeditate
      test/cerata/test.cc
      test/cerata/test_types.h
      test/cerata/test_expressions.h
      test/cerata/test_designs.h
      test/cerata/test_pool.h

      # Back-ends
      test/cerata/dot/test_graphs.h

      test/cerata/vhdl/test_declarators.h
      test/cerata/vhdl/test_instantiators.h
      )
  include_directories(test)
  add_executable(${PROJECT_NAME}-test ${TEST_HEADERS} ${TEST_SOURCES})
  target_link_libraries(${PROJECT_NAME}-test gtest gtest_main)
  target_link_libraries(${PROJECT_NAME}-test ${PROJECT_NAME})

  gtest_discover_tests(cerata-test)
endif (CERATA_TESTS)
