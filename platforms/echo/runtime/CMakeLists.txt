add_compile_unit(
  OPT
  NAME fletcher::echo
  TYPE SHARED
  PRPS
    C_STANDARD 99
  SRCS
    src/fletcher_echo.c
  DEPS
    fletcher::common
)
