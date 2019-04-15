cmake_minimum_required(VERSION 3.10)

project(fletcher-common)

set(FLETCHER_COMMON fletcher-common)

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
endif ()

set(COMMON_SOURCES
        src/fletcher/common/arrow-utils.cc
        src/fletcher/common/hex-view.cc)

set(COMMON_HEADERS
        src/fletcher/common/status.h
        src/fletcher/common/arrow-utils.h
        src/fletcher/common/hex-view.h
        src/fletcher/common/timer.h)

set(COMMON_ALL ${COMMON_SOURCES} ${COMMON_HEADERS})

include_directories(../c/src)

find_library(LIB_ARROW arrow)

add_library(${FLETCHER_COMMON}-static STATIC ${COMMON_ALL})
target_link_libraries(${FLETCHER_COMMON}-static ${LIB_ARROW})

########################################################################################################################
# Tests
########################################################################################################################

if (FLETCHER_TESTS)
    enable_testing()
    include(GoogleTest)
    find_package(GTest REQUIRED)

    set(TEST_GEN_HEADERS
            test/test_generate.h
            test/test_schemas.h
            test/test_recordbatches.h)

    set(TEST_GEN_SOURCES
            test/test_schemas.cc
            test/test_recordbatches.cc)

    SET(TEST_GEN_ALL ${TEST_GEN_HEADERS} ${TEST_GEN_SOURCES})

    # Expose generation functions as a static library
    add_library(${FLETCHER_COMMON}-generate-static STATIC ${COMMON_ALL} ${TEST_GEN_ALL})
    target_link_libraries(${FLETCHER_COMMON}-generate-static ${LIB_ARROW})

    # Expose generation functions as an executable with main function
    add_executable(${FLETCHER_COMMON}-generate ${COMMON_ALL} ${TEST_GEN_ALL} test/test_generate.cc)
    target_link_libraries(${FLETCHER_COMMON}-generate ${LIB_ARROW})

    # Common library unit tests

    # Test common library functions
    set(TEST_HEADERS)
    set(TEST_SOURCES test/test-common.cc)

    add_executable(${FLETCHER_COMMON}-test ${COMMON_ALL} ${TEST_GEN_ALL} ${TEST_HEADERS} ${TEST_SOURCES})
    target_link_libraries(${FLETCHER_COMMON}-test ${LIB_ARROW})
    target_link_libraries(${FLETCHER_COMMON}-test ${FLETCHER_COMMON}-static)
    target_link_libraries(${FLETCHER_COMMON}-test GTest::GTest GTest::Main)

    gtest_discover_tests(${FLETCHER_COMMON}-test)

endif (FLETCHER_TESTS)
