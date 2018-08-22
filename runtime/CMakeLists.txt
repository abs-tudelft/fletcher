cmake_minimum_required(VERSION 3.5.1)

project(fletcher)

include(GNUInstallDirs)

####################################
# CPP options
####################################

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-Wall -Wextra")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

####################################
# Platform-independent sources
####################################
set(SOURCES
        src/logging.h
        src/common.h
        src/fletcher.h
        src/FPGAPlatform.h      src/FPGAPlatform.cpp
        src/UserCore.h          src/UserCore.cpp
        src/echo/echo.h         src/echo/echo.cpp
)

####################################
# Packages
####################################
find_package(OpenMP REQUIRED)
if (OPENMP_FOUND)
    set (CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${OpenMP_C_FLAGS}")
    set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} ${OpenMP_CXX_FLAGS}")
    set (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} ${OpenMP_EXE_LINKER_FLAGS}")
endif()

####################################
# Libraries
####################################
find_library(LIB_ARROW arrow)

####################################
# Platforms
####################################

# Empty by default
set(PLATFORM_LIBS "")
set(PLATFORM_SOURCES "")
set(PLATFORM_INCLUDE_DIRS "")

# AWS:
option(PLATFORM_AWS "Use the Amazon EC2 F1 instances FPGA platform." OFF)

if (PLATFORM_AWS)
  if(NOT EXISTS "$ENV{SDK_DIR}")
    message(FATAL_ERROR "Attempting to CMake with AWS EC2 F1 support, but SDK_DIR is not set. Please source the sdk_setup.sh script first.")
  endif()
  
  set(PLATFORM_SOURCES ${PLATFORM_SOURCES} src/aws/aws.cpp)

  set(PLATFORM_INCLUDE_DIRS ${PLATFORM_INCLUDE_DIRS} $ENV{SDK_DIR}/userspace/include)
  
  find_library(LIB_AWS_FPGA_MGMT fpga_mgmt)
  message(STATUS "AWS EC2 F1 libfpga_mgmt.so at: " ${LIB_AWS_FPGA_MGMT})
  set(PLATFORM_LIBS ${PLATFORM_LIBS} ${LIB_AWS_FPGA_MGMT})
endif()

# SNAP:
option(PLATFORM_SNAP "Use the CAPI SNAP FPGA platform." OFF)

if (PLATFORM_SNAP)

  if(NOT EXISTS "$ENV{SNAP_ROOT}")
    message(FATAL_ERROR "Attempting to CMake with SNAP support, but SNAP_ROOT is not set. Please do something to fix that.")
  endif()

  set(PLATFORM_SOURCES ${PLATFORM_SOURCES} src/snap/snap.cpp)

  set(PLATFORM_INCLUDE_DIRS ${PLATFORM_INCLUDE_DIRS} $ENV{SNAP_ROOT}/software/include)

  find_library(LIB_SNAP snap HINTS $ENV{SNAP_ROOT}/software/lib)
  message(STATUS "SNAP libsnap.so at: " ${LIB_SNAP})
  set(PLATFORM_LIBS ${PLATFORM_LIBS} ${LIB_SNAP})
endif()

##################
# Final settings
##################

set(SOURCES ${SOURCES} ${PLATFORM_SOURCES})

include_directories(${CMAKE_SOURCE_DIR}/include ${PLATFORM_INCLUDE_DIRS})
add_library(${PROJECT_NAME} SHARED ${SOURCES})

target_link_libraries(${PROJECT_NAME} ${REQUIRED} ${LIB_ARROW})

option(ENABLE_DEBUG "Enable debugging info" OFF)

if (ENABLE_DEBUG)
  target_compile_definitions(${PROJECT_NAME} PRIVATE DEBUG)
endif()

install(TARGETS ${PROJECT_NAME} DESTINATION lib)

install(DIRECTORY include/fletcher DESTINATION include)
