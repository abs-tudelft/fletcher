cmake_minimum_required(VERSION 3.5.1)

project(sum-hdl)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "-Wall -Wextra")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-O3")

add_executable(schema
	schema.cpp
)

find_library(LIB_ARROW arrow)

option(ENABLE_DEBUG "Enable debugging" OFF)

if (ENABLE_DEBUG)
  target_compile_definitions(schema  PRIVATE DEBUG)
endif()

target_compile_definitions(schema  PRIVATE)

target_link_libraries(schema
  ${REQUIRED}
  ${LIB_ARROW}
)

# Wrapper generation
add_custom_command(OUTPUT sum.fbs COMMAND schema)
# We need two user registers, one for the start and one for the end row number
add_custom_command(OUTPUT fletcher_wrapper.vhd
  COMMAND fletchgen
    --quiet
    --input sum.fbs
    --output fletcher_wrapper.vhd
    --axi axi_top.vhd
  DEPENDS sum.fbs)
add_custom_target(wrapper ALL DEPENDS fletcher_wrapper.vhd)

