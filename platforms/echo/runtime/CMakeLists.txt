cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletcher_echo VERSION 0.0.0 LANGUAGES C CXX)

include(FetchContent)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

include(CompileUnits)

if(NOT TARGET fletcher::c)
  add_subdirectory(../../../common/c c)
endif()

add_compile_unit(
  NAME fletcher::echo
  TYPE SHARED
  PRPS
    C_STANDARD 99
  SRCS
    src/fletcher_echo.c
  DEPS
    fletcher::c
)

compile_units()
