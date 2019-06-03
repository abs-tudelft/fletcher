add_compile_unit(
  OPT
  NAME fletcher::snap
  TYPE SHARED
  PRPS
    C_STANDARD 99
  SRCS
    src/fletcher_snap.c
  DEPS
    fletcher::common
    snap
)

if(BUILD_FLETCHER_SNAP)
  find_library(SNAP snap HINTS "$ENV{SNAP_ROOT}/software/lib")
  if(SNAP)
    add_library(snap INTERFACE IMPORTED GLOBAL)
    target_include_directories(snap INTERFACE "$ENV{SNAP_ROOT}/software/include")
  else()
    message(FATAL_ERROR "Dependency snap of fletcher::snap not found")
  endif()
endif()
