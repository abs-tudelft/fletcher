##############################################################################
# Project configuration
##############################################################################
cmake_minimum_required(VERSION 3.10)
include(GNUInstallDirs)

set(FLETCHER fletcher)
project(${FLETCHER} VERSION 0.1.0 DESCRIPTION "Fletcher C++ runtime library")

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

##############################################################################
# Targets
##############################################################################
set(SOURCES
    src/fletcher/platform.cc
    src/fletcher/context.cc
    src/fletcher/kernel.cc)

set(HEADERS
    src/fletcher/platform.h
    src/fletcher/context.h
    src/fletcher/kernel.h)

include_directories(src)

add_library(${FLETCHER} SHARED ${HEADERS} ${SOURCES})

# Turn ON to use Arrow's logging facility.
option(ARROW_LOGGING "Use Arrow's logging facility" OFF)
message("[Fletcher] Runtime: Arrow logging is: ${ARROW_LOGGING}")
if (ARROW_LOGGING)
  add_definitions(-DFLETCHER_USE_ARROW_LOGGING)
endif ()

##############################################################################
# PyFletcher
##############################################################################
option(FLETCHER_PYTHON
    "Build Fletcher for use in building pyfletcher"
    OFF)

# Only needed when building for Python
set(PYARROW_DIR "/usr/" CACHE STRING "pyarrow install directory")

if (FLETCHER_PYTHON)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_GLIBCXX_USE_CXX11_ABI=0")
  find_library(LIB_ARROW arrow PATHS ${PYARROW_DIR} NO_DEFAULT_PATH)
  include_directories(${PYARROW_DIR}/include)
else ()
  find_library(LIB_ARROW arrow)
endif ()

##############################################################################
# Dependencies
##############################################################################

# Fletcher Common library
add_subdirectory(../../common/cpp fletcher-common)
include_directories(../../common/c/src)
include_directories(../../common/cpp/src)
# For now, we want to include all symbols from the common static library into the runtime shared library.
# At some point they should be exposed more programatically (in the api header, for example).
target_link_libraries(${FLETCHER} -Wl,-whole-archive fletcher-common -Wl,-no-whole-archive)

# Arrow
find_library(LIB_ARROW arrow)
target_link_libraries(${FLETCHER} ${LIB_ARROW})

# DL
target_link_libraries(${FLETCHER} ${CMAKE_DL_LIBS})

##############################################################################
# Installation
##############################################################################
set_target_properties(${FLETCHER} PROPERTIES VERSION ${PROJECT_VERSION})
set_target_properties(${FLETCHER} PROPERTIES SOVERSION 1)
set_target_properties(${FLETCHER} PROPERTIES PUBLIC_HEADER src/fletcher/api.h)

install(TARGETS ${FLETCHER}
    LIBRARY DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR}
    PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${FLETCHER})

# Install headers from cpp runtime
install(FILES ${HEADERS}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${FLETCHER}
    )

# Headers from common library
set(COMMON_HEADERS
    ../../common/cpp/src/fletcher/common.h
    ../../common/cpp/src/fletcher/logging.h
    ../../common/cpp/src/fletcher/arrow-utils.h
    ../../common/cpp/src/fletcher/hex-view.h
    ../../common/cpp/src/fletcher/timer.h)

install(FILES ${COMMON_HEADERS}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${FLETCHER}
    )

# Install C header
install(FILES ${GLOBAL_C_HEADER}
    DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${FLETCHER}
    )

##############################################################################
# Tests
##############################################################################
if (FLETCHER_TESTS)
  if (NOT TARGET gtest)
    include(../../BuildGTest.cmake)
  endif ()
  include(GoogleTest)
  enable_testing()

  set(TEST_SOURCES test/fletcher/test.cpp)
  set(TEST_HEADERS)
  include_directories(src)

  add_executable(${FLETCHER}-test ${TEST_HEADERS} ${TEST_SOURCES})

  # Linking

  # The echo platform is dynamically linked during run-time
  if (NOT TARGET fletcher_echo)
    message("[Fletcher] Runtime tests: Adding echo platform build.")
    add_subdirectory(../../platforms/echo/runtime ${CMAKE_BINARY_DIR}/echo)
    set(FLETCHER_ECHO_LIBDIR ${CMAKE_BINARY_DIR}/echo)
  else ()
    message("[Fletcher] Runtime tests: Using existing echo platform build.")
    set(FLETCHER_ECHO_LIBDIR ${CMAKE_BINARY_DIR}/platforms/echo/runtime)
  endif ()
  message("[Fletcher] Runtime tests: Echo platform library in: ${FLETCHER_ECHO_LIBDIR}")
  include_directories(../../platforms/echo/runtime/src)

  target_link_libraries(${FLETCHER}-test ${LIB_ARROW})
  target_link_libraries(${FLETCHER}-test fletcher-common)
  target_link_libraries(${FLETCHER}-test ${FLETCHER})

  target_link_libraries(${FLETCHER}-test gtest gtest_main)
  gtest_discover_tests(${FLETCHER}-test PROPERTIES ENVIRONMENT "LD_LIBRARY_PATH=${FLETCHER_ECHO_LIBDIR}")
endif (FLETCHER_TESTS)
