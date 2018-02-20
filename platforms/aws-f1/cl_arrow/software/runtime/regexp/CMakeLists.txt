cmake_minimum_required(VERSION 3.5.1)

project(regexp)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

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

target_link_libraries(${PROJECT_NAME} 
  ${REQUIRED} 
  ${LIB_FLETCHER} 
  ${LIB_ARROW} 
  ${LIB_RE2}
)
