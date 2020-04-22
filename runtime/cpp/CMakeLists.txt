cmake_minimum_required(VERSION 3.14 FATAL_ERROR)

project(fletcher VERSION 0.0.10 LANGUAGES CXX)

find_package(Arrow 0.17 CONFIG REQUIRED)

include(FetchContent)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

include(CompileUnits)

set(TEST_PLATFORM_DEPS)
if(BUILD_TESTS)
  if(NOT TARGET fletcher::echo)
    add_subdirectory(../../platforms/echo/runtime echo)
  endif()
  list(APPEND TEST_PLATFORM_DEPS "fletcher::echo")
  if(UNIX AND NOT APPLE)
    list(APPEND TEST_PLATFORM_DEPS "-Wl,--disable-new-dtags")
  endif()
endif()

if(NOT TARGET fletcher::common)
  add_subdirectory(../../common/cpp common)
endif()
if(NOT TARGET fletcher::c)
  add_subdirectory(../../common/c c)
endif()

add_compile_unit(
  NAME fletcher
  TYPE SHARED
  PRPS
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/fletcher/platform.cc
    src/fletcher/context.cc
    src/fletcher/kernel.cc
  DEPS
    fletcher::c
    fletcher::common
    arrow_shared
    ${CMAKE_DL_LIBS}
)

add_compile_unit(
  NAME fletcher::test
  TYPE TESTS
  PRPS
    CXX_STANDARD 11
    CXX_STANDARD_REQUIRED ON
  SRCS
    test/fletcher/test.cpp
  DEPS
    fletcher
    ${TEST_PLATFORM_DEPS}
)

compile_units()
