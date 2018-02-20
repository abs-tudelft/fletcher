cmake_minimum_required(VERSION 3.5.1)

project(fletcher)

set(CMAKE_CXX_STANDARD 11)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(GNUInstallDirs)

include_directories(${CMAKE_SOURCE_DIR}/include)

add_library(${PROJECT_NAME} SHARED 
	src/fletcher/FPGAPlatform.cpp
	src/fletcher/UserCore.cpp
  src/fletcher/echo/echo.cpp
)

set(HEADERS 
  include/fletcher.h
  include/fletcher/common.h
  include/fletcher/logging.h
  include/fletcher/FPGAPlatform.h
  include/fletcher/UserCore.h
  include/fletcher/echo/echo.h
)

install(TARGETS ${PROJECT_NAME} DESTINATION lib)

install(DIRECTORY include/${PROJECT_NAME} DESTINATION include)
