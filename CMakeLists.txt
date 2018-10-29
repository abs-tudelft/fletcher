cmake_minimum_required(VERSION 3.10)

add_subdirectory(runtime/cpp)

# Fletcher wrapper generator
option(FLETCHER_GEN "Build with Fletchgen - Fletcher's HDL wrapper generator." ON)
if (FLETCHER_GEN)
    add_subdirectory(codegen/fletchgen)
endif()

# Platforms
option(FLETCHER_AWS "Build with AWS EC2 f1 support." OFF)
if (FLETCHER_AWS)
    message("[FLETCHER] Building AWS EC2 f1 support...")
    add_subdirectory(platforms/aws-f1/runtime)
endif ()

option(FLETCHER_SNAP "Build with OpenPOWER SNAP support." OFF)
if (FLETCHER_SNAP)
    message("[FLETCHER] Building with SNAP support...")
    add_subdirectory(platforms/snap/runtime)
endif ()

option(FLETCHER_ECHO "Build with ECHO support (simulating platform interface on STDOUT)" ON)
if (FLETCHER_ECHO)
    message("[FLETCHER] Building \"echo\" platform")
    add_subdirectory(platforms/echo/runtime)
endif ()

option(FLETCHER_TESTS "Build tests." OFF)
