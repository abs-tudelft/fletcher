cmake_minimum_required(VERSION 3.10)
include(GNUInstallDirs)
include(ExternalProject)

########################################################################################################################
# LIBRARY
########################################################################################################################
project(fletcher VERSION 0.0.1 DESCRIPTION "Fletcher C++ runtime library")

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC -D_GLIBCXX_USE_CXX11_ABI=0")
#set(CMAKE_CXX_FLAGS "-Wall -Wextra -fPIC")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast -march=native")

set(SOURCES
        src/fletcher/platform.cc
        src/fletcher/context.cc
        src/fletcher/usercore.cc)

set(HEADERS
        ../../common/cpp/src/fletcher.h
        src/fletcher/platform.h
        src/fletcher/context.h
        src/fletcher/status.h
        src/fletcher/usercore.h)

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
find_library(LIB_ARROW arrow PATHS /usr/local/lib/python3.6/dist-packages/pyarrow NO_DEFAULT_PATH)
#find_library(LIB_ARROW arrow)
target_link_libraries(${PROJECT_NAME} ${LIB_ARROW})
message(${LIB_ARROW})

set_target_properties(${PROJECT_NAME} PROPERTIES PUBLIC_HEADER src/${PROJECT_NAME}/api.h)

# Install .so
install(TARGETS ${PROJECT_NAME}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
        PUBLIC_HEADER DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME})

# Install headers
install(FILES ${HEADERS}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME}
        )

# Headers from common library
set(COMMON_HEADERS
        ../../common/cpp/src/common/arrow-utils.h
        ../../common/cpp/src/common/hex-view.h
        ../../common/cpp/src/common/timer.h)

install(FILES ${COMMON_HEADERS}
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME}/common
        )

########################################################################################################################
# TESTS
########################################################################################################################

if (FLETCHER_TESTS)
    set(TEST_SOURCES test/test.cpp)
    add_executable(test_${PROJECT_NAME} ${TEST_HEADERS} ${TEST_SOURCES})
    target_link_libraries(test_${PROJECT_NAME} ${PROJECT_NAME})
endif (FLETCHER_TESTS)