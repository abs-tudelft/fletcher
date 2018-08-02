cmake_minimum_required(VERSION 3.5)
project(fletchgen)

# C++ standard
set(CMAKE_CXX_STANDARD 11)

# Compiler
# set(CMAKE_CXX_COMPILER "/usr/bin/clang++")

# Generic flags
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_DEBUG} -Wall")

# Debug flags
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -DDEBUG")

# Release flags
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -O3")

set(SOURCE_FILES
        src/logging.h
        src/meta.h
        src/constants.h
        src/common.h                src/common.cc
        src/arrow-utils.h           src/arrow-utils.cc
        src/printers.h              src/printers.cc

        src/vhdl/vhdl.h             src/vhdl/vhdl.cc
        src/stream.h                src/stream.cc

        src/column.h                src/column.cc
        src/arbiter.h               src/arbiter.cc
        src/fletcher-streams.h      src/fletcher-streams.cc
        src/fletcher-ports.h        src/fletcher-ports.cc
        src/column-wrapper.h        src/column-wrapper.cc
        src/usercore.h              src/usercore.cc
        src/usercore-controller.h   src/usercore-controller.cc

        src/srec/srec.cpp           src/srec/srec.h
        src/srec/recordbatch.cpp    src/srec/recordbatch.h

        src/vhdt/vhdt.cpp           src/vhdt/vhdt.h

        src/fletchgen.cc)

add_executable(${PROJECT_NAME} ${SOURCE_FILES})

find_library(LIB_ARROW arrow)

find_package(Boost COMPONENTS program_options REQUIRED)

target_link_libraries(${PROJECT_NAME} ${REQUIRED} Boost::program_options)
target_link_libraries(${PROJECT_NAME} ${REQUIRED} ${LIB_ARROW})

install(TARGETS ${PROJECT_NAME} DESTINATION bin)