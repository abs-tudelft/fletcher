cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletcher_common VERSION 0.0.0 LANGUAGES CXX)

###############################################################################
# Configuration                                                               #
###############################################################################
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror")

###############################################################################
# Dependencies                                                                #
###############################################################################
include(FetchContent)

find_package(arrow 0.13 CONFIG REQUIRED)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

###############################################################################
# Compilation units                                                           #
###############################################################################
include(CompileUnits)

add_compile_unit(
  NAME fletcher::common
  PRPS
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/fletcher/arrow-utils.cc
    src/fletcher/hex-view.cc
  DEPS
    arrow_shared
)

add_compile_unit(
  NAME fletcher::test::common
  TYPE TESTS
  PRPS
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
  SRCS
    test/fletcher/test-common.cc
  DEPS
    fletcher::common
    fletcher::test::utils
)

add_compile_unit(
  NAME fletcher::test::utils
  PRPS
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
  SRCS  
    test/fletcher/test_generate.cc
    test/fletcher/test_schemas.cc
    test/fletcher/test_recordbatches.cc
  DEPS
    arrow_shared
)

compile_units()
