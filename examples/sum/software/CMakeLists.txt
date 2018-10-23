cmake_minimum_required(VERSION 3.10)

project(sum)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
#set(CMAKE_CXX_FLAGS "-Wall -Wextra")
set(CMAKE_CXX_FLAGS "-Wall -Wextra  -D_GLIBCXX_USE_CXX11_ABI=0")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

add_executable(${PROJECT_NAME} 
	sum.cpp
)

find_library(LIB_FLETCHER fletcher)
#find_library(LIB_ARROW arrow)
find_library(LIB_ARROW arrow PATHS /usr/local/lib/python3.6/dist-packages/pyarrow NO_DEFAULT_PATH)

option(ENABLE_DEBUG "Enable debugging" OFF)

if (ENABLE_DEBUG)
  target_compile_definitions(${PROJECT_NAME}  PRIVATE DEBUG)
endif()

target_compile_definitions(${PROJECT_NAME}  PRIVATE PLATFORM=${RUNTIME_PLATFORM})

target_link_libraries(${PROJECT_NAME} 
  ${REQUIRED}
  ${LIB_ARROW}
  ${LIB_FLETCHER}
  ${LIB_PLATFORM}
)

