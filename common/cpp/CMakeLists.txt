cmake_minimum_required(VERSION 3.10)

project(fletcher-common)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

set(SOURCES
        src/common/arrow-utils.cc
        src/common/hex-view.cc)

set(HEADERS
        src/common/arrow-utils.h
        src/common/hex-view.h
        src/common/timer.h)

add_library(${PROJECT_NAME} STATIC ${HEADERS} ${SOURCES})
