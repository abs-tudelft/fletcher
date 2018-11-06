cmake_minimum_required(VERSION 3.5)
project(fletchgen)

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS_DEBUG} -Wall")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Ofast -march=native")

set(HEADERS
        src/logging.h
        src/meta.h
        src/constants.h
        src/common.h
        src/arrow-meta.h
        src/printers.h
        src/vhdl/vhdl.h
        src/stream.h
        src/column.h
        src/arbiter.h
        src/fletcher-streams.h
        src/fletcher-ports.h
        src/column-wrapper.h
        src/usercore.h
        src/usercore-controller.h
        src/srec/srec.h
        src/srec/recordbatch.h
        src/vhdt/vhdt.h
        src/top/axi.h
        src/top/sim.h
        src/config.h
        )

set(SOURCES
        src/common.cc
        src/arrow-meta.cc
        src/printers.cc
        src/vhdl/vhdl.cc
        src/stream.cc
        src/column.cc
        src/arbiter.cc
        src/fletcher-streams.cc
        src/fletcher-ports.cc
        src/column-wrapper.cc
        src/usercore.cc
        src/usercore-controller.cc
        src/srec/srec.cc
        src/srec/recordbatch.cc
        src/vhdt/vhdt.cc
        src/top/axi.cc
        src/top/sim.cc
        src/config.cc
        )

set(RESOURCES
        ../../hardware/vhdl/sim/sim_top.vhdt
        ../../hardware/vhdl/axi/axi_top.vhdt)

add_library(${PROJECT_NAME}-static ${HEADERS} ${SOURCES})

add_executable(${PROJECT_NAME} src/fletchgen.cc)
target_link_libraries(${PROJECT_NAME} ${PROJECT_NAME}-static)

# Include common functions, build it and link statically
if (NOT TARGET fletcher-common)
    add_subdirectory(../../common/cpp fletcher-common)
endif()
target_link_libraries(${PROJECT_NAME} fletcher-common)
include_directories(../../common/cpp/src)

find_library(LIB_ARROW arrow)
target_link_libraries(${PROJECT_NAME} ${REQUIRED} ${LIB_ARROW})

find_package(Boost COMPONENTS program_options REQUIRED)
target_link_libraries(${PROJECT_NAME} ${REQUIRED} Boost::program_options)

install(TARGETS ${PROJECT_NAME} DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES ${RESOURCES} DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/fletcher/fletchgen)
