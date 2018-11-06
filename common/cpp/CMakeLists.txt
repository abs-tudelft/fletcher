cmake_minimum_required(VERSION 3.10)

set(FLETCHER_COMMON fletcher-common)

project(${FLETCHER_COMMON})

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

set(COMMON_SOURCES
        src/fletcher/common/arrow-utils.cc
        src/fletcher/common/hex-view.cc)

set(COMMON_HEADERS
        src/fletcher/common/arrow-utils.h
        src/fletcher/common/hex-view.h
        src/fletcher/common/timer.h)

add_library(${FLETCHER_COMMON} STATIC ${COMMON_HEADERS} ${COMMON_SOURCES})
target_link_libraries(${FLETCHER_COMMON} ${LIB_ARROW})
include_directories(../c/src)

########################################################################################################################
# Tests
########################################################################################################################

if (FLETCHER_TESTS)

    # Test Arrow objects; schemas, recordbatches, etc...
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

    # Test common library functions
    set(TEST_COMMON fletcher-test-common)
    set(TEST_COMMON_HEADERS )
    set(TEST_COMMON_SOURCES test/test-common.cc)

    add_executable(${TEST_COMMON}
            ${TEST_GEN_HEADERS} ${TEST_GEN_SOURCES}
            ${TEST_COMMON_HEADERS} ${TEST_COMMON_SOURCES})
    target_link_libraries(${TEST_COMMON} ${LIB_ARROW})
    target_link_libraries(${TEST_COMMON} ${FLETCHER_COMMON})
    include_directories(${TEST_COMMON} src)

endif (FLETCHER_TESTS)
