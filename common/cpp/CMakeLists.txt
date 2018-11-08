cmake_minimum_required(VERSION 3.10)

set(FLETCHER_COMMON fletcher-common)

project(${FLETCHER_COMMON})

option(FLETCHER_PYTHON
        "Build Fletcher for use in building pyfletcher"
        OFF)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

if (FLETCHER_PYTHON)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_GLIBCXX_USE_CXX11_ABI=0")
    include_directories(${PYARROW_DIR}/include)
    message("Building fletcher-common for Pyfletcher")
endif()

set(COMMON_SOURCES
        src/fletcher/common/arrow-utils.cc
        src/fletcher/common/hex-view.cc)

set(COMMON_HEADERS
        src/fletcher/common/status.h
        src/fletcher/common/arrow-utils.h
        src/fletcher/common/hex-view.h
        src/fletcher/common/timer.h)

include_directories(../c/src)

add_library(${FLETCHER_COMMON} STATIC ${COMMON_HEADERS} ${COMMON_SOURCES})

find_library(LIB_ARROW arrow)
target_link_libraries(${FLETCHER_COMMON} ${REQUIRED} ${LIB_ARROW})

########################################################################################################################
# Tests
########################################################################################################################

if (FLETCHER_TESTS)

    # File generation for Arrow objects in e.g. fletchgen or other tools. Schemas, recordbatches, etc...
    set(TEST_GEN fletcher-test-generate)

    set(TEST_GEN_HEADERS
            test/test_schemas.h
            test/test_recordbatches.h)

    set(TEST_GEN_SOURCES
            test/test_schemas.cc
            test/test_recordbatches.cc)

    add_executable(${TEST_GEN} ${TEST_GEN_HEADERS} ${TEST_GEN_SOURCES} test/test-generate.cc)
    target_link_libraries(${TEST_GEN} ${LIB_ARROW})
    target_link_libraries(${TEST_GEN} ${FLETCHER_COMMON})

    # Common library unit tests

    # Include GoogleTest CMake functionality
    include(GoogleTest)
    find_package(GTest REQUIRED)

    # Test common library functions
    set(TEST_COMMON fletcher-test-common)
    set(TEST_COMMON_HEADERS)
    set(TEST_COMMON_SOURCES test/test-common.cc)

    add_executable(${TEST_COMMON}
            ${TEST_GEN_HEADERS} ${TEST_GEN_SOURCES}
            ${TEST_COMMON_HEADERS} ${TEST_COMMON_SOURCES})
    target_link_libraries(${TEST_COMMON} ${LIB_ARROW})
    target_link_libraries(${TEST_COMMON} ${FLETCHER_COMMON})
    target_link_libraries(${TEST_COMMON} GTest::GTest GTest::Main)
    include_directories(${TEST_COMMON} src)

    gtest_discover_tests(${TEST_COMMON} WORKING_DIRECTORY ../../platforms/echo/runtime)

endif (FLETCHER_TESTS)
