cmake_minimum_required(VERSION 3.10)
include(GNUInstallDirs)

project(fletcher_snap VERSION 0.0.1 DESCRIPTION "Fletcher SNAP platform")

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_FLAGS "-Wall -Wextra")
set(CMAKE_C_FLAGS_DEBUG "-g -DDEBUG")
set(CMAKE_C_FLAGS_RELEASE "-Ofast -march=native")

set(SOURCES
        src/fletcher_snap.c)

set(HEADERS
        src/fletcher_snap.h)

set(GLOBAL_C_HEADER
        ../../../common/c/src/fletcher/fletcher.h)

add_library(${PROJECT_NAME} SHARED ${GLOBAL_C_HEADER} ${HEADERS} ${SOURCES})

set_target_properties(${PROJECT_NAME} PROPERTIES VERSION ${PROJECT_VERSION})
set_target_properties(${PROJECT_NAME} PROPERTIES SOVERSION 1)
set_target_properties(${PROJECT_NAME} PROPERTIES PUBLIC_HEADER ${HEADERS})

install(TARGETS ${PROJECT_NAME}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/fletcher)

# Attempt to find SNAP lib and link it
if (NOT EXISTS "$ENV{SNAP_ROOT}")
    message(FATAL_ERROR "Attempting to CMake with SNAP support, but SNAP_ROOT is not set.")
endif ()
find_library(LIB_SNAP snap HINTS $ENV{SNAP_ROOT}/software/lib)
set(INCLUDE_DIRS ${INCLUDE_DIRS} $ENV{SNAP_ROOT}/software/include)
message(STATUS "SNAP libsnap.so at: " ${LIB_SNAP})
message(STATUS "SNAP includes at: " ${INCLUDE_DIRS})
target_link_libraries(${PROJECT_NAME} ${LIB_SNAP})

include_directories(${INCLUDE_DIRS})

install(TARGETS ${PROJECT_NAME}
        LIBRARY DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/fletcher)

message("[FLETCHER] After running installation, please refresh your dynamic library cache (e.g. sudo ldconfig).")
