cmake_minimum_required(VERSION 3.10)

# Tests for any subproject
option(FLETCHER_TESTS "Build tests." OFF)

########################################################################################################################
# Runtimes
########################################################################################################################

# CPP runtime
option(FLETCHER_CPP "Build Fletcher C++ run-time library" ON)
if (FLETCHER_CPP)
    add_subdirectory(runtime/cpp)
endif()

########################################################################################################################
# Platforms:
########################################################################################################################

# Echo: the default platform that just outputs your fpga interactions on stdout
option(FLETCHER_ECHO "Build with ECHO support (simulating platform interface on STDOUT)" ON)
if (FLETCHER_ECHO)
    message("[FLETCHER] Building \"echo\" platform")
    add_subdirectory(platforms/echo/runtime)
endif ()

# AWS EC2 f1
option(FLETCHER_AWS "Build with AWS EC2 f1 support." OFF)
if (FLETCHER_AWS)
    message("[FLETCHER] Building AWS EC2 f1 support...")
    add_subdirectory(platforms/aws-f1/runtime)
endif ()

# OpenPOWER SNAP
option(FLETCHER_SNAP "Build with OpenPOWER SNAP support." OFF)
if (FLETCHER_SNAP)
    message("[FLETCHER] Building with SNAP support...")
    add_subdirectory(platforms/snap/runtime)
endif ()

########################################################################################################################
# Tools
########################################################################################################################

# Fletcher wrapper generator
option(FLETCHER_GEN "Build with Fletchgen - Fletcher's HDL wrapper generator." ON)
if (FLETCHER_GEN)
    if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
        if (CMAKE_CXX_COMPILER_VERSION VERSION_LESS "4.9")
            message(WARNING "Skipping Fletchgen compilation. This requires a GCC version of 4.9+")
        else ()
            add_subdirectory(codegen/fletchgen)
        endif ()
    else ()
        add_subdirectory(codegen/fletchgen)
    endif ()
endif ()