cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletcher VERSION 0.0.0 LANGUAGES CXX)

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

add_subdirectory(../../platforms/echo/runtime echo)

add_compile_unit(
  NAME fletcher
  TYPE SHARED
  PRPS
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/fletcher/platform.cc
    src/fletcher/context.cc
    src/fletcher/kernel.cc
  DEPS
    fletcher::common
    fletcher::echo
    arrow_shared
    ${CMAKE_DL_LIBS}
  TSTS
    test/fletcher/test.cpp
)

compile_units()
