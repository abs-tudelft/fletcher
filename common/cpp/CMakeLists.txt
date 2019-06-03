add_compile_unit(
  OPT
  NAME fletcher::common
  TYPE OBJECT
  SRCS
    src/fletcher/arrow-utils.cc
    src/fletcher/hex-view.cc
  DEPS
    arrow_shared
)

add_compile_unit(
  OPT
  NAME fletcher::test::common
  TYPE TESTS
  SRCS
    test/fletcher/test-common.cc
  DEPS
    fletcher::common
    fletcher::test::utils
)

add_compile_unit(
  OPT
  NAME fletcher::test::utils
  TYPE OBJECT
  SRCS  
    test/fletcher/test_generate.cc
    test/fletcher/test_schemas.cc
    test/fletcher/test_recordbatches.cc
  DEPS
    arrow_shared
)
