cmake_minimum_required(VERSION 3.10)
include(GNUInstallDirs)

project(fletcher_echo VERSION 0.0.1 DESCRIPTION "Fletcher Echo platform")

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_FLAGS "-Wall -Wextra")
set(CMAKE_C_FLAGS_DEBUG "-g")
set(CMAKE_C_FLAGS_RELEASE "-Ofast -march=native")

set(SOURCES
        src/fletcher_echo.c)

set(HEADERS
        src/fletcher_echo.h)

add_library(${PROJECT_NAME} SHARED ${HEADERS} ${SOURCES})
include_directories(../../../common/c/src)

set_target_properties(${PROJECT_NAME} PROPERTIES VERSION ${PROJECT_VERSION})
set_target_properties(${PROJECT_NAME} PROPERTIES SOVERSION 1)
set_target_properties(${PROJECT_NAME} PROPERTIES PUBLIC_HEADER ${HEADERS})

install(TARGETS ${PROJECT_NAME}
        LIBRARY DESTINATION ${CMAKE_INSTALL_FULL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/fletcher)

message("[FLETCHER] After running installation, please refresh your dynamic library cache (e.g. sudo ldconfig).")
