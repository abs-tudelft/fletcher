cmake_minimum_required(VERSION 3.10)

project(fletcher-common)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC  -D_GLIBCXX_USE_CXX11_ABI=0")
#set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

set(SOURCES
        src/common/arrow-utils.cpp
        src/common/hex-view.cpp)

set(HEADERS
        src/common/arrow-utils.h
        src/common/hex-view.h
        src/common/timer.h)

add_library(${PROJECT_NAME} STATIC ${HEADERS} ${SOURCES})
