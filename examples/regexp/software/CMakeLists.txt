cmake_minimum_required(VERSION 3.10)

project(regexp)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fopenmp")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

add_executable(${PROJECT_NAME}
        src/regex-usercore.cc
        src/regex-usercore.h
        src/regexp.cc
        )

find_library(LIB_FLETCHER fletcher)
find_library(LIB_ARROW arrow)
find_library(LIB_RE2 re2)

option(ENABLE_DEBUG "Enable debugging" OFF)

if (ENABLE_DEBUG)
  target_compile_definitions(${PROJECT_NAME}  PRIVATE DEBUG)
endif()

target_compile_definitions(${PROJECT_NAME}  PRIVATE PLATFORM=${RUNTIME_PLATFORM})

target_link_libraries(${PROJECT_NAME}
        ${REQUIRED}
        ${LIB_ARROW}
        ${LIB_FLETCHER}
        ${LIB_RE2}
        )

