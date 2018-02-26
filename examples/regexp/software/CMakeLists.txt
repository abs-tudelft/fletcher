cmake_minimum_required(VERSION 3.5.1)

project(regexp)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "-Wall -Wextra")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-O3")

add_executable(regexp
	regexp.cpp
	RegExUserCore.cpp
)

find_library(LIB_FLETCHER fletcher)
find_library(LIB_ARROW arrow)
find_library(LIB_RE2 re2)

find_package(OpenMP REQUIRED)
if (OPENMP_FOUND)
    set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS}")
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
    set (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${OpenMP_EXE_LINKER_FLAGS}")
endif()

option(ACTIVE_UNITS "Number of active RegEx units in the FPGA implementation" 16)
option(RUNTIME_PLATFORM "The run-time platform to use. Currently 0: ECHO, 1: AWS EC2 F1, 2: CAPI SNAP" 0)

# ECHO
if (${RUNTIME_PLATFORM} EQUAL 0)
  message("You used the Echo FPGA platform to build this example. Use CMake with -DRUNTIME_PLATFORM=<num> where for num=0 > Echo, num=1 > AWS EC2 F1, num=2 > CAPI SNAP")
endif()

# AWS
if (${RUNTIME_PLATFORM} EQUAL 1)
  set(DEF_ACTIVE_UNITS 16)
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
  set(DEF_ACTIVE_UNITS 8)

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
  target_compile_definitions(${PROJECT_NAME} PRIVATE DEBUG)
endif()

option(ACTIVE_UNITS "Number of active RegEx units in the FPGA implementation" 16)

if (ACTIVE_UNITS)
  set(DEF_ACTIVE_UNITS ${ACTIVE_UNITS})
endif()

target_compile_definitions(${PROJECT_NAME} PRIVATE REUC_ACTIVE_UNITS=${DEF_ACTIVE_UNITS})
target_compile_definitions(${PROJECT_NAME} PRIVATE PLATFORM=${RUNTIME_PLATFORM})

target_link_libraries(${PROJECT_NAME} 
  ${REQUIRED} 
  ${LIB_FLETCHER} 
  ${LIB_ARROW} 
  ${LIB_RE2}
  ${LIB_PLATFORM}
)
