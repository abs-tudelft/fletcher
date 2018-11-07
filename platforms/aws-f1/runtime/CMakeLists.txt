cmake_minimum_required(VERSION 3.10)
include(GNUInstallDirs)

project(fletcher_aws VERSION 0.0.1 DESCRIPTION "Fletcher AWS platform")

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_FLAGS "-Wall -Wextra")
set(CMAKE_C_FLAGS_DEBUG "-g -DDEBUG")
set(CMAKE_C_FLAGS_RELEASE "-Ofast -march=native")

set(SOURCES
        src/fletcher_aws.c)

set(HEADERS
        src/fletcher_aws.h)

add_library(${PROJECT_NAME} SHARED ${HEADERS} ${SOURCES})
include_directories(../../../common/c/src)

set_target_properties(${PROJECT_NAME} PROPERTIES VERSION ${PROJECT_VERSION})
set_target_properties(${PROJECT_NAME} PROPERTIES SOVERSION 1)
set_target_properties(${PROJECT_NAME} PROPERTIES PUBLIC_HEADER ${HEADERS})

# Attempt to find AWS FPGA lib
find_library(LIB_AWS_FPGA_MGMT fpga_mgmt)

if (NOT EXISTS "$ENV{SDK_DIR}")
    message(WARNING "Attempting to CMake with AWS EC2 F1 support, but SDK_DIR is not set. Please source the sdk_setup.sh script first.")
endif ()

# Point to include directories
include_directories($ENV{SDK_DIR}/userspace/include)

# Link the library dynamically
target_link_libraries(${PROJECT_NAME} ${LIB_AWS_FPGA_MGMT})

install(TARGETS ${PROJECT_NAME}
        LIBRARY DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/fletcher)

message("[FLETCHER] After running installation, please refresh your dynamic library cache (e.g. sudo ldconfig).")
