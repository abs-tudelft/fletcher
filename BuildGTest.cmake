if (NOT TARGET gtest AND NOT TARGET gtest_main)
  # Download and unpack googletest at configure time
  configure_file(${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt.in ${CMAKE_CURRENT_BINARY_DIR}/googletest-download/CMakeLists.txt)
  execute_process(COMMAND "${CMAKE_COMMAND}" -G "${CMAKE_GENERATOR}" .
      WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/googletest-download" )
  execute_process(COMMAND "${CMAKE_COMMAND}" --build .
      WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/googletest-download" )

  # Add googletest directly to our build. This adds
  # the following targets: gtest, gtest_main, gmock
  # and gmock_main
  add_subdirectory("${CMAKE_CURRENT_BINARY_DIR}/googletest-src"
                   "${CMAKE_CURRENT_BINARY_DIR}/googletest-build" EXCLUDE_FROM_ALL)
endif()
