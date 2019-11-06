// Copyright 2018-2019 Delft University of Technology
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
#include "cerata/test_designs.h"
#include "cerata/test_utils.h"

namespace cerata {

TEST(VHDL_INST, TypeMapper) {
  default_component_pool()->Clear();
  auto top = GetTypeConvComponent();
  GenerateDebugOutput(top);
}

TEST(VHDL_INST, StreamTypeMapper) {
  default_component_pool()->Clear();
  auto top = GetStreamConcatComponent();
  GenerateDebugOutput(top);
}

TEST(VHDL_INST, ArrayTypeMapper) {
  default_component_pool()->Clear();

  auto t_wide = vector(4);
  auto t_narrow = vector(2);
  // Flat indices:
  auto tA = record("TA", {   // 0
      field("q", t_wide),    // 1
  });

  auto tB = record("TB", {   // 0
      field("r", t_narrow),  // 1
      field("s", t_narrow),  // 2
  });

  // Create a type mapping from tA to tE
  auto mapper = std::make_shared<TypeMapper>(tA.get(), tB.get());
  mapper->Add(1, 1);
  mapper->Add(1, 2);
  tA->AddMapper(mapper);

  // Array component
  auto parSize = parameter("ARRAY_SIZE", integer(), intl(0));
  auto pA = port_array("A", tA, parSize, Port::OUT);
  auto x_comp = component("X", {parSize, pA});

  // Ports
  auto pB = port("B", tB, Port::OUT);
  auto pC = port("C", tB, Port::OUT);
  // Components and instantiations
  auto top = component("top", {pB, pC});
  auto x = top->Instantiate(x_comp);

  // Drive B and C from A
  pB <<= x->prt_arr("A")->Append();
  pC <<= x->prt_arr("A")->Append();

  auto src = GenerateDebugOutput(top);
  ASSERT_EQ(src,
            "library ieee;\n"
            "use ieee.std_logic_1164.all;\n"
            "use ieee.numeric_std.all;\n"
            "\n"
            "entity top is\n"
            "  port (\n"
            "    B_r : out std_logic_vector(1 downto 0);\n"
            "    B_s : out std_logic_vector(1 downto 0);\n"
            "    C_r : out std_logic_vector(1 downto 0);\n"
            "    C_s : out std_logic_vector(1 downto 0)\n"
            "  );\n"
            "end entity;\n"
            "\n"
            "architecture Implementation of top is\n"
            "  component X is\n"
            "    generic (\n"
            "      ARRAY_SIZE : integer := 0\n"
            "    );\n"
            "    port (\n"
            "      A_q : out std_logic_vector(ARRAY_SIZE*4-1 downto 0)\n"
            "    );\n"
            "  end component;\n"
            "\n"
            "  signal X_inst_A_q : std_logic_vector(7 downto 0);\n"
            "\n"
            "begin\n"
            "  X_inst : X\n"
            "    generic map (\n"
            "      ARRAY_SIZE => 2\n"
            "    )\n"
            "    port map (\n"
            "      A_q => X_inst_A_q\n"
            "    );\n"
            "\n"
            "  B_r <= X_inst_A_q(1 downto 0);\n"
            "  B_s <= X_inst_A_q(3 downto 2);\n"
            "\n"
            "  C_r <= X_inst_A_q(5 downto 4);\n"
            "  C_s <= X_inst_A_q(7 downto 6);\n"
            "\n"
            "end architecture;\n");
}

TEST(VHDL_INST, ArrayArray) {
  default_component_pool()->Clear();
  auto top = GetArrayToArrayComponent();
  GenerateDebugOutput(top);
}

TEST(VHDL_INST, ArrayArrayInverted) {
  default_component_pool()->Clear();
  auto top = GetArrayToArrayComponent(true);
  GenerateDebugOutput(top);
}

TEST(VHDL_INST, ArrayArrayInternal) {
  default_component_pool()->Clear();
  auto top = GetArrayToArrayInternalComponent();
  GenerateDebugOutput(top);
}

TEST(VHDL_INST, ArrayArrayInternalInverted) {
  default_component_pool()->Clear();
  auto top = GetArrayToArrayInternalComponent(true);
  GenerateDebugOutput(top);
}

TEST(VHDL_INST, AllPortTypes) {
  default_component_pool()->Clear();
  auto top = GetAllPortTypesComponent();
  GenerateDebugOutput(top);
}

TEST(VHDL_INST, NonLocallyStaticArrayMap) {
  default_component_pool()->Clear();
  auto child_out_size = parameter("IN_SIZE", integer());
  auto child_in_size = parameter("OUT_SIZE", integer());
  auto child_width = parameter("WIDTH", integer());
  auto child_vec = vector("VecType", child_width);
  auto child_po = port_array("po", child_vec, child_out_size, Port::Dir::OUT);
  auto child_pi = port_array("pi", child_vec, child_in_size, Port::Dir::IN);
  auto child = component("child", {child_width,
                                   child_in_size,
                                   child_out_size,
                                   child_po,
                                   child_pi});

  auto top_width = parameter("TOP_WIDTH", integer());
  auto top_vec = vector("VecType", top_width);
  auto top_pi0 = port("pi0", top_vec, Port::Dir::IN);
  auto top_pi1 = port("pi1", top_vec, Port::Dir::IN);
  auto top_po0 = port("po0", top_vec, Port::Dir::OUT);
  auto top_po1 = port("po1", top_vec, Port::Dir::OUT);
  auto top = component("top", {top_width, top_pi0, top_pi1, top_po0, top_po1});
  auto child_inst = top->Instantiate(child.get());

  Connect(child_inst->par("WIDTH"), top_width);
  Connect(top_po0, child_inst->prt_arr("po")->Append());
  Connect(top_po1, child_inst->prt_arr("po")->Append());
  Connect(child_inst->prt_arr("pi")->Append(), top_pi0);
  Connect(child_inst->prt_arr("pi")->Append(), top_pi1);

  GenerateDebugOutput(top);
}

}  // namespace cerata
