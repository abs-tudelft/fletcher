cmake_minimum_required(VERSION 3.10)

project(sum)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "-Wall -Wextra")
set(CMAKE_CXX_FLAGS_DEBUG "-g -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

add_executable(${PROJECT_NAME}
        sum.cpp)

find_library(LIB_ARROW arrow)
target_link_libraries(${PROJECT_NAME} ${LIB_ARROW})

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

