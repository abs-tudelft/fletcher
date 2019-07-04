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

#include "cerata/test_designs.h"

namespace cerata {

TEST(VHDL_INST, TypeMapper) {
  default_component_pool()->Clear();
  auto top = GetTypeConvComponent();
  auto code = vhdl::Design(top);
  std::cout << code.Generate().ToString();
}

TEST(VHDL_INST, StreamTypeMapper) {
  default_component_pool()->Clear();
  auto top = GetStreamConcatComponent();
  auto code = vhdl::Design(top);
  std::cout << code.Generate().ToString();
}

TEST(VHDL_INST, ArrayTypeMapper) {
  default_component_pool()->Clear();
  auto top = GetArrayTypeConvComponent();
  auto code = vhdl::Design(top);
  std::cout << code.Generate().ToString();
  ASSERT_EQ(code.Generate().ToString(),
            "library ieee;\n"
            "use ieee.std_logic_1164.all;\n"
            "use ieee.numeric_std.all;\n"
            "entity top is\n"
            "  port (\n"
            "    B_r : out std_logic_vector(1 downto 0);\n"
            "    B_s : out std_logic_vector(1 downto 0);\n"
            "    C_r : out std_logic_vector(1 downto 0);\n"
            "    C_s : out std_logic_vector(1 downto 0)\n"
            "  );\n"
            "end entity;\n"
            "architecture Implementation of top is\n"
            "  component X is\n"
            "    generic (\n"
            "      ARRAY_SIZE : integer := 0\n"
            "    );\n"
            "    port (\n"
            "      A_q : out std_logic_vector(ARRAY_SIZE*4-1 downto 0)\n"
            "    );\n"
            "  end component;\n"
            "begin\n"
            "  X_inst : X\n"
            "    generic map (\n"
            "      ARRAY_SIZE => 2\n"
            "    )\n"
            "    port map (\n"
            "      A_q(1 downto 0) => B_r,\n"
            "      A_q(3 downto 2) => B_s,\n"
            "      A_q(5 downto 4) => C_r,\n"
            "      A_q(7 downto 6) => C_s\n"
            "    );\n"
            "end architecture;\n");
}

TEST(VHDL_INST, ArrayArray) {
  default_component_pool()->Clear();
  auto top = GetArrayToArrayComponent();
  auto code = vhdl::Design(top);
  std::cout << code.Generate().ToString();
}

TEST(VHDL_INST, AllPortTypes) {
  default_component_pool()->Clear();
  auto top = GetAllPortTypesComponent();
  auto code = vhdl::Design(top);
  std::cout << code.Generate().ToString();
}

}  // namespace cerata
