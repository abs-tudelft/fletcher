cmake_minimum_required(VERSION 3.10)
set(FLETCHGEN fletchgen)
project(${FLETCHGEN})

include(GNUInstallDirs)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -DDEBUG")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Ofast -march=native")

# Dependencies

# Arrow
find_library(LIB_ARROW arrow)
# Common library, if not already built
if (NOT TARGET fletcher-common-static)
    add_subdirectory(../../common/cpp fletcher-common)
endif ()

# Cerata
add_subdirectory(../cerata cerata)
include_directories(../cerata/src)

# Sources
set(HEADERS
        src/fletchgen/schema.h
        src/fletchgen/bus.h
        src/fletchgen/array.h
        src/fletchgen/basic_types.h
        src/fletchgen/mantle.h
        src/fletchgen/kernel.h
        src/fletchgen/constants.h
        src/fletchgen/logging.h
        src/fletchgen/options.h

        src/fletchgen/srec/recordbatch.h
        src/fletchgen/srec/srec.h
        )

set(SOURCES
        src/fletchgen/schema.cc
        src/fletchgen/bus.cc
        src/fletchgen/array.cc
        src/fletchgen/basic_types.cc
        src/fletchgen/mantle.cc
        src/fletchgen/kernel.cc
        src/fletchgen/logging.cc
        src/fletchgen/options.cc

        src/fletchgen/srec/recordbatch.cc
        src/fletchgen/srec/srec.cc
        )

set(THIRD_PARTY_HEADERS
        src/fletchgen/cli/CLI11.hpp
        )

# Linking
include_directories(src)

add_library(${FLETCHGEN}-static STATIC ${HEADERS} ${THIRD_PARTY_HEADERS} ${SOURCES})
target_link_libraries(${FLETCHGEN}-static ${LIB_ARROW})
target_link_libraries(${FLETCHGEN}-static fletcher-common-static)

add_executable(${FLETCHGEN} src/fletchgen/fletchgen.cc)
target_link_libraries(${FLETCHGEN} ${LIB_ARROW})
target_link_libraries(${FLETCHGEN} fletchgen-static)
target_link_libraries(${FLETCHGEN} fletcher-common-static)
target_link_libraries(${FLETCHGEN} cerata)

install(TARGETS ${FLETCHGEN} DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES ${RESOURCES} DESTINATION ${CMAKE_INSTALL_DATAROOTDIR}/fletcher/fletchgen)

########################################################################################################################
# TESTS
########################################################################################################################
if (FLETCHGEN_TESTS)
    enable_testing()
    include(GoogleTest)
    find_package(GTest REQUIRED)

    set(TEST_SOURCES
            # Intermeditate
            test/fletchgen/test.cc

            # Front-ends
            test/fletchgen/test_kernel.h
            test/fletchgen/test_mantle.h
            test/fletchgen/test_bus.h

            )

    add_executable(${FLETCHGEN}-test ${TEST_HEADERS} ${TEST_SOURCES})

    target_link_libraries(${FLETCHGEN}-test fletchgen-static)
    target_link_libraries(${FLETCHGEN}-test fletcher-common-generate-static)
    include_directories(../../common/cpp/test)

    target_link_libraries(${FLETCHGEN}-test cerata)

    target_link_libraries(${FLETCHGEN}-test ${LIB_ARROW})
    target_link_libraries(${FLETCHGEN}-test GTest::GTest GTest::Main)

    gtest_discover_tests(${FLETCHGEN}-test PROPERTIES ENVIRONMENT "LD_LIBRARY_PATH=${FLETCHER_ECHO_LIBDIR}")
endif (FLETCHGEN_TESTS)
