cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletcher_echo VERSION 0.0.0 LANGUAGES C)

###############################################################################
# Dependencies                                                                #
###############################################################################
include(FetchContent)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

###############################################################################
# Compilation units                                                           #
###############################################################################
include(CompileUnits)

add_subdirectory(../../../common common)

add_compile_unit(
  NAME fletcher::echo
  TYPE SHARED
  PRPS
    C_STANDARD 99
  SRCS
    src/fletcher_echo.c
  DEPS
    fletcher::common
)

compile_units()
