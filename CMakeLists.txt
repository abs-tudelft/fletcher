cmake_minimum_required(VERSION 3.10)

add_subdirectory(runtime/cpp)
add_subdirectory(codegen/fletchgen)

# Platforms
option(FLETCHER_AWS "Build with AWS EC2 f1 support." OFF)
if (FLETCHER_AWS)
    message("[FLETCHER] Building AWS EC2 f1 support...")
    add_subdirectory(platforms/aws-f1/runtime)
endif (FLETCHER_AWS)

option(FLETCHER_SNAP "Build with OpenPOWER SNAP support." OFF)
if (FLETCHER_SNAP)
    message("[FLETCHER] Building with SNAP support...")
    add_subdirectory(platforms/snap/runtime)
endif (FLETCHER_SNAP)

option(FLETCHER_ECHO "Build with ECHO support (simulating platform interface on STDOUT)" ON)
if (FLETCHER_ECHO)
    message("[FLETCHER] Building \"echo\" platform")
    add_subdirectory(platforms/echo/runtime)
endif (FLETCHER_ECHO)

option(FLETCHER_EXAMPLES "Build examples." OFF)
if (FLETCHER_EXAMPLES)
    find_library(LIB_FLETCHER fletcher)
    if (LIB_FLETCHER)
        message("[FLETCHER] Building examples.")
        add_subdirectory(examples/sum/software)
    else ()
        message(WARNING "[FLETCHER] Before building examples, build and install run-time library first. Skipping examples...")
    endif ()
endif (FLETCHER_EXAMPLES)

option(FLETCHER_TESTS "Build tests." OFF)