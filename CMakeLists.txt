cmake_minimum_required(VERSION 3.14.0 FATAL_ERROR)

project(fletcher)

###############################################################################
# Configuration                                                               #
###############################################################################
set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror")

###############################################################################
# Options                                                                     #
###############################################################################
option(ARROW_LOGGING "Use Arrow's logging facility" OFF)

if (ARROW_LOGGING)
  add_definitions(-DFLETCHER_USE_ARROW_LOGGING)
endif()

###############################################################################
# Dependencies                                                                #
###############################################################################
find_package(arrow 0.13 CONFIG REQUIRED)

include(FetchContent)

FetchContent_Declare(CLI11
  GIT_REPOSITORY  https://github.com/CLIUtils/CLI11.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(CLI11)

FetchContent_Declare(cmake-modules
  GIT_REPOSITORY  https://github.com/abs-tudelft/cmake-modules.git
  GIT_TAG         master
)
FetchContent_MakeAvailable(cmake-modules)

###############################################################################
# Compilation units                                                           #
###############################################################################
include(CompileUnits)

add_subdirectory(codegen)
add_subdirectory(common/cpp)
add_subdirectory(runtime/cpp)
add_subdirectory(platforms)

compile_units()
