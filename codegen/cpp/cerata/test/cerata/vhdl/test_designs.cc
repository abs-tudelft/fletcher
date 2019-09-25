// Copyright 2018 Delft University of Technology
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include <gmock/gmock.h>
#include <cerata/api.h>
#include <iostream>
#include <string>

#include "cerata/test_designs.h"

namespace cerata {

#ifdef TEST_CERATA_DUMP_VHDL
// Macro to save the test to some VHDL files that can be used to syntax check the tests with e.g. GHDL
// At some point the reverse might be more interesting - load the test cases from file into the test.
#define VHDL_DUMP_TEST(str) \
    std::ofstream(std::string(::testing::UnitTest::GetInstance()->current_test_info()->test_suite_name()) \
    + "_" + ::testing::UnitTest::GetInstance()->current_test_info()->name() + ".vhd") << str
#else
#define VHDL_DUMP_TEST(str)
#endif

TEST(VHDL_DESIGN, Simple) {
  default_component_pool()->Clear();
  auto static_vec = Vector::Make<8>();
  auto param = Parameter::Make("vec_width", natural(), intl(8));
  auto param_vec = Vector::Make("param_vec_type", param);
  auto veca = Port::Make("static_vec", static_vec);
  auto vecb = Port::Make("param_vec", param_vec);
  auto comp = Component::Make("simple", {veca, vecb});
  auto design = vhdl::Design(comp);
  auto design_source = design.Generate().ToString();
  auto expected =
      "library ieee;\n"
      "use ieee.std_logic_1164.all;\n"
      "use ieee.numeric_std.all;\n"
      "entity simple is\n"
      "  generic (\n"
      "    VEC_WIDTH : natural := 8\n"
      "  );\n"
      "  port (\n"
      "    static_vec : in std_logic_vector(7 downto 0);\n"
      "    param_vec  : in std_logic_vector(vec_width-1 downto 0)\n"
      "  );\n"
      "end entity;\n"
      "architecture Implementation of simple is\n"
      "begin\n"
      "end architecture;\n";
  ASSERT_EQ(design_source, expected);
  VHDL_DUMP_TEST(expected);
}

TEST(VHDL_DESIGN, CompInst) {
  default_component_pool()->Clear();
  auto a = Port::Make("a", bit(), Port::Dir::IN);
  auto b = Port::Make("b", bit(), Port::Dir::OUT);
  auto ca = Component::Make("comp_a", {a});
  auto cb = Component::Make("comp_b", {b});
  auto top = Component::Make("top");
  auto ia = top->AddInstanceOf(ca.get());
  auto ib = top->AddInstanceOf(cb.get());
  Connect(ia->port("a"), ib->port("b"));
  auto design = vhdl::Design(top);
  auto design_source = design.Generate().ToString();
  std::cout << design_source;
  auto expected =
      "library ieee;\n"
      "use ieee.std_logic_1164.all;\n"
      "use ieee.numeric_std.all;\n"
      "entity top is\n"
      "end entity;\n"
      "architecture Implementation of top is\n"
      "  component comp_a is\n"
      "    port (\n"
      "      a : in std_logic\n"
      "    );\n"
      "  end component;\n"
      "  component comp_b is\n"
      "    port (\n"
      "      b : out std_logic\n"
      "    );\n"
      "  end component;\n"
      "  signal comp_b_inst_b : std_logic;\n"
      "begin\n"
      "  comp_a_inst : comp_a\n"
      "    port map (\n"
      "      a => comp_b_inst_b\n"
      "    );\n"
      "  comp_b_inst : comp_b\n"
      "    port map (\n"
      "      b => comp_b_inst_b\n"
      "    );\n"
      "end architecture;\n";
  ASSERT_EQ(design_source, expected);
  VHDL_DUMP_TEST(expected);
}

}  // namespace cerata

