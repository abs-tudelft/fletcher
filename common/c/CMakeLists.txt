cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletcher_c VERSION 0.0.0 LANGUAGES CXX)

include(FetchContent)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

include(CompileUnits)

add_compile_unit(
  NAME fletcher::c
  TYPE INTERFACE
)

compile_units()
