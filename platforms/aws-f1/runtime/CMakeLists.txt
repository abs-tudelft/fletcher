cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletcher_aws VERSION 0.0.0 LANGUAGES C CXX)

find_library(AWS_FPGA fpga_mgmt HINTS "$ENV{SDK_DIR}/userspace/lib/so")
if(AWS_FPGA)
  add_library(fpga_mgmt INTERFACE IMPORTED GLOBAL)
  target_include_directories(fpga_mgmt INTERFACE "$ENV{SDK_DIR}/userspace/include")
else()
  message(FATAL_ERROR "Dependency fpga_mgmt not found")
endif()

include(FetchContent)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

include(CompileUnits)

add_subdirectory(../../../common common)

add_compile_unit(
  NAME fletcher::aws
  TYPE SHARED
  PRPS
    C_STANDARD 99
  SRCS
    src/fletcher_aws.c
  DEPS
    fletcher::common
    fpga_mgmt
)

compile_units()
