cmake_minimum_required(VERSION 3.10)

project(regexp)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fopenmp")
set(CMAKE_CXX_FLAGS_DEBUG "-g -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

add_executable(${PROJECT_NAME}
        src/regex-usercore.cc
        src/regex-usercore.h
        src/regexp.cc
        )

find_library(LIB_ARROW arrow)
find_library(LIB_RE2 re2)

target_link_libraries(${PROJECT_NAME} ${LIB_ARROW} ${LIB_RE2})

find_library(LIB_FLETCHER fletcher)
if (NOT LIB_FLETCHER)
    if (NOT TARGET fletcher)
        message("Fletcher is not installed. Building stand-alone.")
        add_subdirectory(../../../runtime/cpp fletcher-cpp)
    endif ()
    target_link_libraries(${PROJECT_NAME} fletcher)
    include_directories(../../../runtime/cpp/src)
    include_directories(../../../common/cpp/src)
    include_directories(../../../common/c/src)
else ()
    target_link_libraries(${PROJECT_NAME} ${LIB_FLETCHER})
endif ()

