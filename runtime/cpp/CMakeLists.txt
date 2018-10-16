cmake_minimum_required(VERSION 3.10)
include(GNUInstallDirs)
include(ExternalProject)

########################################################################################################################
# LIBRARY
########################################################################################################################
project(fletcher VERSION 0.0.1 DESCRIPTION "Fletcher C++ runtime library")

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

set(SOURCES
        src/platform.cpp
        src/context.cpp)

set(HEADERS
        ../../common/cpp/src/fletcher.h
        src/platform.h
        src/context.h
        src/status.h)

add_library(${PROJECT_NAME} SHARED ${HEADERS} ${SOURCES})

set_target_properties(${PROJECT_NAME} PROPERTIES VERSION ${PROJECT_VERSION})
set_target_properties(${PROJECT_NAME} PROPERTIES SOVERSION 1)
set_target_properties(${PROJECT_NAME} PROPERTIES PUBLIC_HEADER ../../common/cpp/src/fletcher.h)

# Include common functions, build it and link statically
add_subdirectory(../../common/cpp ${PROJECT_NAME}-common)
target_link_libraries(${PROJECT_NAME} ${PROJECT_NAME}-common)
include_directories(../../common/cpp/src)

# Dynamically link the dynamically library linking library
target_link_libraries(${PROJECT_NAME} ${CMAKE_DL_LIBS})

# Dynamically link Arrow
find_library(LIB_ARROW arrow)
target_link_libraries(${PROJECT_NAME} ${LIB_ARROW})

target_include_directories(${PROJECT_NAME} PRIVATE include)
target_include_directories(${PROJECT_NAME} PRIVATE src)

install(TARGETS ${PROJECT_NAME}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

########################################################################################################################
# TESTS
########################################################################################################################

set(TEST_SOURCES test/test.cpp)

add_executable(test_${PROJECT_NAME} ${TEST_HEADERS} ${TEST_SOURCES})

target_link_libraries(test_${PROJECT_NAME} ${PROJECT_NAME})
