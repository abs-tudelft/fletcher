cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(cerata VERSION 0.0.0 LANGUAGES CXX)

include(FetchContent)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

include(CompileUnits)

add_compile_unit(
  NAME cerata::core
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/cerata/domain.cc
    src/cerata/edge.cc
    src/cerata/expression.cc
    src/cerata/flattype.cc
    src/cerata/graph.cc
    src/cerata/literal.cc
    src/cerata/node.cc
    src/cerata/node_array.cc
    src/cerata/object.cc
    src/cerata/output.cc
    src/cerata/pool.cc
    src/cerata/port.cc
    src/cerata/transform.cc
    src/cerata/type.cc
    src/cerata/utils.cc
  TSTS
    test/cerata/test_expressions.cc
    test/cerata/test_pool.cc
    test/cerata/test_types.cc
)

add_compile_unit(
  NAME cerata::dot
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/cerata/dot/dot.cc
    src/cerata/dot/style.cc
  TSTS
    test/cerata/dot/test_graphs.cc
  DEPS
    cerata::core
)

add_compile_unit(
  NAME cerata::vhdl
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/cerata/vhdl/architecture.cc
    src/cerata/vhdl/block.cc
    src/cerata/vhdl/declaration.cc
    src/cerata/vhdl/design.cc
    src/cerata/vhdl/identifier.cc
    src/cerata/vhdl/instantiation.cc
    src/cerata/vhdl/resolve.cc
    src/cerata/vhdl/template.cc
    src/cerata/vhdl/vhdl.cc
    src/cerata/vhdl/vhdl_types.cc
  TSTS
    test/cerata/vhdl/test_declarators.cc
    test/cerata/vhdl/test_designs.cc
    test/cerata/vhdl/test_instantiators.cc
  DEPS
    cerata::core
    cerata::dot
)

set(CERATA_BACKENDS)
if(BUILD_CERATA_DOT)
  list(APPEND CERATA_BACKENDS "cerata::dot")
endif()
if(BUILD_CERATA_VHDL)
  list(APPEND CERATA_BACKENDS "cerata::vhdl")
endif()

add_compile_unit(
  NAME cerata
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  DEPS
    cerata::core
    ${CERATA_BACKENDS}
)

compile_units()
