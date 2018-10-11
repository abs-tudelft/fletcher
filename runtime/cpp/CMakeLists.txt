cmake_minimum_required(VERSION 3.10)
include(GNUInstallDirs)

########################################################################################################################
# LIBRARY
########################################################################################################################
project(fletcher VERSION 0.0.1 DESCRIPTION "Fletcher C++ runtime library")

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-Wall -Wextra")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

set(SOURCES
        src/platform.cpp)

set(HEADERS
        src/fletcher.h
        src/platform.h)

add_library(${PROJECT_NAME} SHARED ${HEADERS} ${SOURCES})

set_target_properties(${PROJECT_NAME} PROPERTIES VERSION ${PROJECT_VERSION})
set_target_properties(${PROJECT_NAME} PROPERTIES SOVERSION 1)
set_target_properties(${PROJECT_NAME} PROPERTIES PUBLIC_HEADER src/fletcher.h)

# Dynamically link libraries library
target_link_libraries(${PROJECT_NAME} ${CMAKE_DL_LIBS})

target_include_directories(${PROJECT_NAME} PRIVATE include)
target_include_directories(${PROJECT_NAME} PRIVATE src)

install(TARGETS ${PROJECT_NAME}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR})

########################################################################################################################
# TESTS
########################################################################################################################

set(TEST_SOURCES src/test/test.cpp)
#set(TEST_HEADERS src/test/test.h)

add_executable(test_${PROJECT_NAME} ${TEST_HEADERS} ${TEST_SOURCES})

target_link_libraries(test_${PROJECT_NAME} ${PROJECT_NAME})