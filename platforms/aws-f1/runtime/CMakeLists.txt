add_compile_unit(
  OPT
  NAME fletcher::aws
  TYPE SHARED
  PRPS
    C_STANDARD 99
  SRCS
    src/fletcher_aws.c
  DEPS
    fletcher::common
    fpga_mgmt
)

if(BUILD_FLETCHER_AWS)
  find_library(AWS_FPGA fpga_mgmt HINTS "$ENV{SDK_DIR}/userspace/lib/so")
  if(AWS_FPGA)
    add_library(fpga_mgmt INTERFACE IMPORTED GLOBAL)
    target_include_directories(fpga_mgmt INTERFACE "$ENV{SDK_DIR}/userspace/include")
  else()
    message(FATAL_ERROR "Dependency fpga_mgmt of fletcher::aws not found")
  endif()
endif()
