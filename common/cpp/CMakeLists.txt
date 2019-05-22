##############################################################################
# Configuration
##############################################################################
# Prevent from building twice if included by multiple sub-projects
if (NOT TARGET fletcher-common)

  cmake_minimum_required(VERSION 3.10)

  project(fletcher-common)

  set(FLETCHER_COMMON fletcher-common)

  set(CMAKE_CXX_STANDARD 11)
  set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC")
  set(CMAKE_CXX_FLAGS_DEBUG "-g")
  set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

  ##########################################################################
  # PyFletcher
  ##########################################################################
  option(FLETCHER_PYTHON "Build Fletcher for use in building pyfletcher" OFF)

  if (FLETCHER_PYTHON)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_GLIBCXX_USE_CXX11_ABI=0")
    include_directories(${PYARROW_DIR}/include)
    message("Building fletcher-common for Pyfletcher")
  endif ()

  ##########################################################################
  # Target
  ##########################################################################
  set(COMMON_SOURCES
      src/fletcher/arrow-utils.cc
      src/fletcher/hex-view.cc)

  set(COMMON_HEADERS
      src/fletcher/arrow-utils.h
      src/fletcher/hex-view.h
      src/fletcher/timer.h
      src/fletcher/logging.h
      src/fletcher/common.h)

  include_directories(src)
  include_directories(../c/src)

  add_library(${FLETCHER_COMMON} STATIC ${COMMON_SOURCES} ${COMMON_HEADERS})

  # Turn ON to use Arrow's logging facility.
  option(ARROW_LOGGING "Use Arrow's logging facility" OFF)
  if (ARROW_LOGGING)
    add_definitions(-DFLETCHER_USE_ARROW_LOGGING)
  endif ()

  ##########################################################################
  # Dependencies
  ##########################################################################
  find_library(LIB_ARROW arrow)
  target_link_libraries(${FLETCHER_COMMON} ${LIB_ARROW})

  ##########################################################################
  # Tests
  ##########################################################################
  if (FLETCHER_TESTS)
    if (NOT TARGET gtest)
      include(../../BuildGTest.cmake)
    endif ()
    include(GoogleTest)
    enable_testing()

    # Sources that are used to generate data structures used testing
    set(TEST_GEN_HEADERS
        test/fletcher/test_generate.h
        test/fletcher/test_schemas.h
        test/fletcher/test_recordbatches.h)

    set(TEST_GEN_SOURCES
        test/fletcher/test_schemas.cc
        test/fletcher/test_recordbatches.cc)

    include_directories(test)

    SET(TEST_GEN_ALL ${TEST_GEN_HEADERS} ${TEST_GEN_SOURCES})

    # Expose example generators as statis library
    add_library(${FLETCHER_COMMON}-examples STATIC ${COMMON_ALL} ${TEST_GEN_ALL})

    # Expose generation functions as an executable with main function
    add_executable(${FLETCHER_COMMON}-generate ${TEST_GEN_ALL} test/fletcher/test_generate.cc)

    # Common library unit tests

    # Test common library functions
    set(TEST_HEADERS)
    set(TEST_SOURCES test/fletcher/test-common.cc)
    include_directories(src)

    add_executable(${FLETCHER_COMMON}-test ${TEST_GEN_ALL} ${TEST_HEADERS} ${TEST_SOURCES})

    # Link Fletcher Common to every target
    target_link_libraries(${FLETCHER_COMMON}-examples ${FLETCHER_COMMON})
    target_link_libraries(${FLETCHER_COMMON}-generate ${FLETCHER_COMMON})
    target_link_libraries(${FLETCHER_COMMON}-test ${FLETCHER_COMMON})

    # Link Arrow to every target
    target_link_libraries(${FLETCHER_COMMON}-examples ${LIB_ARROW})
    target_link_libraries(${FLETCHER_COMMON}-generate ${LIB_ARROW})
    target_link_libraries(${FLETCHER_COMMON}-test ${LIB_ARROW})

    # Link examples to test main
    target_link_libraries(${FLETCHER_COMMON}-test ${FLETCHER_COMMON}-examples)

    target_link_libraries(${FLETCHER_COMMON}-test gtest gtest_main)
    target_include_directories(${FLETCHER_COMMON}-test PUBLIC src)

    gtest_discover_tests(${FLETCHER_COMMON}-test)

  endif (FLETCHER_TESTS)
endif ()