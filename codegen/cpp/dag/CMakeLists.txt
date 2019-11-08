cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(dag VERSION 0.0.10 LANGUAGES CXX)

include(FetchContent)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

include(CompileUnits)

add_compile_unit(
  OPT
  NAME dag::obj
  TYPE OBJECT
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/dag/cast.cc
    src/dag/dag.cc
    src/dag/dot.cc
    src/dag/index.cc
    src/dag/memory.cc
    src/dag/meta.cc
    src/dag/stream.cc
    src/dag/types.cc

    src/dag/transform/arith.cc
    src/dag/transform/comparison.cc
    src/dag/transform/compress.cc
    src/dag/transform/statistics.cc
    src/dag/transform/string.cc
    src/dag/transform/misc.cc
  TSTS
    test/dag/test_binop.cc
    test/dag/test_compop.cc
    test/dag/test_examples.cc
)

compile_units()
