##############################################################################
# Configuration
##############################################################################
cmake_minimum_required(VERSION 3.10)

# Turn ON to enable tests for any subproject.
option(FLETCHER_TESTS "Build tests." ON)
if (FLETCHER_TESTS)
  enable_testing()
  include(BuildGTest.cmake)
endif ()

# Fletcher common library
option(FLETCHER_COMMON "Build Fletcher Common static library" ON)
if (FLETCHER_COMMON)
  add_subdirectory(common/cpp fletcher-common)
endif ()

# Turn ON to use Arrow's logging facility.
option(ARROW_LOGGING "Use Arrow's logging facility" OFF)
if (ARROW_LOGGING)
  # Force the setting onto all subprojects.
  set(ARROW_LOGGING ON CACHE BOOL "")
endif ()

##############################################################################
# Platforms:
##############################################################################
# Echo: the default platform that just outputs your fpga interactions on stdout
option(FLETCHER_ECHO "Build with ECHO support (simulating platform interface on STDOUT)" ON)
if (FLETCHER_ECHO)
  add_subdirectory(platforms/echo/runtime)
endif ()

# AWS EC2 f1
option(FLETCHER_AWS "Build with AWS EC2 f1 support." OFF)
if (FLETCHER_AWS)
  add_subdirectory(platforms/aws-f1/runtime)
endif ()

# OpenPOWER SNAP
option(FLETCHER_SNAP "Build with OpenPOWER SNAP support." OFF)
if (FLETCHER_SNAP)
  add_subdirectory(platforms/snap/runtime)
endif ()

##############################################################################
# Runtimes
##############################################################################
# CPP runtime
option(FLETCHER_CPP "Build Fletcher C++ run-time library" ON)
if (FLETCHER_CPP)
  add_subdirectory(runtime/cpp)
endif ()

##############################################################################
# Tools
##############################################################################
# Fletcher design generator
option(FLETCHER_GEN "Build with Fletchgen - Fletcher's design generator." ON)
if (FLETCHER_GEN)
  if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS "4.9")
      message(WARNING "Skipping Fletchgen compilation. This requires a GCC version of 4.9+")
    else ()
      if (FLETCHER_TESTS)
        set(FLETCHGEN_TESTS ON)
        set(CERATA_TESTS ON)
      endif ()
      add_subdirectory(codegen/fletchgen)
    endif ()
  else ()
    add_subdirectory(codegen/fletchgen)
  endif ()
endif ()
