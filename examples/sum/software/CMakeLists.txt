cmake_minimum_required(VERSION 3.5.1)

project(sum)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "-Wall -Wextra")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-O3")

add_executable(${PROJECT_NAME} 
	sum.cpp
)

find_library(LIB_FLETCHER fletcher)
find_library(LIB_ARROW arrow)

option(RUNTIME_PLATFORM "The run-time platform to use. Currently 0: ECHO, 1: AWS EC2 F1, 2: CAPI SNAP" 0)

# ECHO
if (${RUNTIME_PLATFORM} EQUAL 0)
  message("You used the Echo FPGA platform to build this example. Use CMake with -DRUNTIME_PLATFORM=<num> where for num=0 > Echo, num=1 > AWS EC2 F1, num=2 > CAPI SNAP")
endif()

# AWS
if (${RUNTIME_PLATFORM} EQUAL 1)
  message("Chose AWS EC2 F1 as run-time platform.")
  if(NOT EXISTS "$ENV{SDK_DIR}")
    message(FATAL_ERROR "Attempting to CMake with AWS EC2 F1 support, but SDK_DIR is not set. Please source the sdk_setup.sh script first.")
  endif()

  find_library(LIB_AWS_FPGA_MGMT fpga_mgmt)
  message(STATUS "AWS EC2 F1 libfpga_mgmt.so at: " ${LIB_AWS_FPGA_MGMT})
  set(LIB_PLATFORM ${LIB_AWS_FPGA_MGMT})
endif()

# SNAP
if (${RUNTIME_PLATFORM} EQUAL 2)
  message("Chose CAPI SNAP as run-time platform.")

  if(NOT EXISTS "$ENV{SNAP_ROOT}")
    message(FATAL_ERROR "Attempting to CMake with SNAP support, but SNAP_ROOT is not set. Please do something to fix that.")
  endif()

  set(PLATFORM_INCLUDE_DIRS ${PLATFORM_INCLUDE_DIRS} $ENV{SNAP_ROOT}/software/include)

  find_library(LIB_SNAP snap HINTS $ENV{SNAP_ROOT}/software/lib)
  message(STATUS "SNAP libsnap.so at: " ${LIB_SNAP})
  set(LIB_PLATFORM ${LIB_SNAP})
endif()

option(ENABLE_DEBUG "Enable debugging" OFF)

if (ENABLE_DEBUG)
  target_compile_definitions(${PROJECT_NAME}  PRIVATE DEBUG)
endif()

target_compile_definitions(${PROJECT_NAME}  PRIVATE PLATFORM=${RUNTIME_PLATFORM})

target_link_libraries(${PROJECT_NAME} 
  ${REQUIRED}
  ${LIB_ARROW}
  ${LIB_FLETCHER}
  ${LIB_PLATFORM}
)

