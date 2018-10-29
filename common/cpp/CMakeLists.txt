cmake_minimum_required(VERSION 3.10)

project(fletcher-common)

option(FLETCHER_PYTHON
        "Build Fletcher for use in building pyfletcher"
        OFF)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

if (FLETCHER_PYTHON)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_GLIBCXX_USE_CXX11_ABI=0")
    message("Building fletcher-common for Pyfletcher")
endif()

set(SOURCES
        src/common/arrow-utils.cc
        src/common/hex-view.cc)

set(HEADERS
        src/common/arrow-utils.h
        src/common/hex-view.h
        src/common/timer.h)

add_library(${PROJECT_NAME} STATIC ${HEADERS} ${SOURCES})
