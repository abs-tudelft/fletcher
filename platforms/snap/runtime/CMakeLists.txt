cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletcher_snap VERSION 0.0.0 LANGUAGES C CXX)

find_library(SNAP snap HINTS "$ENV{SNAP_ROOT}/software/lib")
if(SNAP)
  add_library(snap INTERFACE IMPORTED GLOBAL)
  target_include_directories(snap INTERFACE "$ENV{SNAP_ROOT}/software/include")
else()
  message(FATAL_ERROR "Dependency snap not found")
endif()

include(FetchContent)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

include(CompileUnits)

add_subdirectory(../../../common/cpp common)

add_compile_unit(
  NAME fletcher::snap
  TYPE SHARED
  PRPS
    C_STANDARD 99
  SRCS
    src/fletcher_snap.c
  DEPS
    fletcher::common
    snap
)

compile_units()
