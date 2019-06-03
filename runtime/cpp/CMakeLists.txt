add_compile_unit(
  NAME fletcher
  TYPE SHARED
  SRCS
    src/fletcher/platform.cc
    src/fletcher/context.cc
    src/fletcher/kernel.cc
  DEPS
    fletcher::common
    fletcher::echo
    arrow_shared
    ${CMAKE_DL_LIBS}
  TSTS
    test/fletcher/test.cpp
)

# ##############################################################################
# # PyFletcher
# ##############################################################################
# option(FLETCHER_PYTHON
#     "Build Fletcher for use in building pyfletcher"
#     OFF)

# # Only needed when building for Python
# set(PYARROW_DIR "/usr/" CACHE STRING "pyarrow install directory")

# if (FLETCHER_PYTHON)
#   set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_GLIBCXX_USE_CXX11_ABI=0")
#   find_library(LIB_ARROW arrow PATHS ${PYARROW_DIR} NO_DEFAULT_PATH)
#   include_directories(${PYARROW_DIR}/include)
# else ()
#   find_library(LIB_ARROW arrow)
# endif ()
