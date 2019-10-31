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

TEST(VHDL_DECL, Signal) {
  auto sig = signal("test", vector(8));
  auto code = vhdl::Decl::Generate(*sig).ToString();
  ASSERT_EQ(code, "signal test : std_logic_vector(7 downto 0);\n");
}

TEST(VHDL_DECL, SignalRecord) {
  auto sig = signal("test",
                    record({field("a", vector(8)),
                            field("b", bit())}));
  auto code = vhdl::Decl::Generate(*sig).ToString();
  ASSERT_EQ(code, "signal test_a : std_logic_vector(7 downto 0);\n"
                  "signal test_b : std_logic;\n");
}

TEST(VHDL_DECL, SignalArray) {
  auto size = intl(2);
  auto sig_array = signal_array("test", bit(), size);
  auto code = vhdl::Decl::Generate(*sig_array).ToString();
  ASSERT_EQ(code, "signal test : std_logic_vector(1 downto 0);\n");
}

TEST(VHDL_DECL, SignalRecordArray) {
  auto size = intl(2);
  auto sig_array = signal_array("test",
                                record({field("a", vector(8)),
                                        field("b", bit())}),
                                size);
  auto code = vhdl::Decl::Generate(*sig_array).ToString();
  ASSERT_EQ(code, "signal test_a : std_logic_vector(15 downto 0);\n"
                  "signal test_b : std_logic_vector(1 downto 0);\n");
}

TEST(VHDL_DECL, SignalRecordArrayParam) {
  auto size = parameter("SIZE", integer());
  auto sig_array = signal_array("test",
                                record({field("a", vector(8)),
                                        field("b", bit())}),
                                size);
  auto code = vhdl::Decl::Generate(*sig_array).ToString();
  ASSERT_EQ(code, "signal test_a : std_logic_vector(SIZE*8-1 downto 0);\n"
                  "signal test_b : std_logic_vector(SIZE-1 downto 0);\n");
}

TEST(VHDL_DECL, SignalRecordParamArrayParam) {
  auto size = parameter("SIZE", integer());
  auto width = parameter("WIDTH", integer());
  auto sig_array = signal_array("test",
                                record({field("a", vector(width)),
                                        field("b", bit())}),
                                size);
  auto code = vhdl::Decl::Generate(*sig_array).ToString();
  ASSERT_EQ(code, "signal test_a : std_logic_vector(SIZE*WIDTH-1 downto 0);\n"
                  "signal test_b : std_logic_vector(SIZE-1 downto 0);\n");
}

TEST(VHDL_DECL, ArrayPort) {
  default_component_pool()->Clear();

  auto size = parameter("size", integer(), intl(0));
  auto data = vector(8);
  auto A = port_array("A", data, size, Term::OUT);
  auto B = port("B", data, Term::IN);
  auto C = port("C", data, Term::IN);
  auto top = component("top");
  auto X = component("X", {size, A});
  auto Y = component("Y", {B, C});
  auto x_inst = top->Instantiate(X);
  auto y_inst = top->Instantiate(Y);

  auto xa = x_inst->prt_arr("A");
  auto xa0 = xa->Append();
  auto xa1 = xa->Append();

  auto yb = y_inst->prt("B");
  auto yc = y_inst->prt("C");

  Connect(yb, xa0);
  Connect(yc, xa1);

  GenerateDebugOutput(top);
}

}  // namespace cerata
