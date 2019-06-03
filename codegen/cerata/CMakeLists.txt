add_compile_unit(
  OPT
  NAME cerata
  TYPE OBJECT
  PRPS
    CXX_STANDARD 17
    CXX_STANDARD_REQUIRED ON
  SRCS
    src/cerata/utils.cc
    src/cerata/arrays.cc
    src/cerata/edges.cc
    src/cerata/objects.cc
    src/cerata/types.cc
    src/cerata/nodes.cc
    src/cerata/graphs.cc
    src/cerata/flattypes.cc
    src/cerata/output.cc
    src/cerata/transform.cc

    src/cerata/vhdl/architecture.cc
    src/cerata/vhdl/block.cc
    src/cerata/vhdl/declaration.cc
    src/cerata/vhdl/design.cc
    src/cerata/vhdl/identifier.cc
    src/cerata/vhdl/instantiation.cc
    src/cerata/vhdl/resolve.cc
    src/cerata/vhdl/vhdl.cc
    src/cerata/vhdl/vhdl_types.cc
    src/cerata/vhdl/template.cc

    src/cerata/dot/dot.cc
    src/cerata/dot/style.cc
  TSTS
    # Intermeditate
    test/cerata/test.cc
    test/cerata/test_types.h
    test/cerata/test_expressions.h
    test/cerata/test_designs.h

    # Back-ends
    test/cerata/dot/test_graphs.h

    test/cerata/vhdl/test_declarators.h
    test/cerata/vhdl/test_instantiators.h
)
