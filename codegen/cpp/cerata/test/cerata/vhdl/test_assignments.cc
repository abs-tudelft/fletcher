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

namespace cerata {

TEST(VHDL_ASSIGN, Signal) {
  auto a = signal("a", bit());
  auto b = signal("b", bit());
  Connect(a, b);
  auto ca = vhdl::Arch::Generate(*a).ToString();
  auto cb = vhdl::Arch::Generate(*b).ToString();
  ASSERT_EQ(ca, "a <= b;\n");
  ASSERT_EQ(cb, "");
}

TEST(VHDL_ASSIGN, SignalVec) {
  auto a = signal("a", vector(8));
  auto b = signal("b", vector(8));
  Connect(a, b);
  auto ca = vhdl::Arch::Generate(*a).ToString();
  auto cb = vhdl::Arch::Generate(*b).ToString();
  ASSERT_EQ(ca, "a <= b;\n");
  ASSERT_EQ(cb, "");
}

TEST(VHDL_ASSIGN, SignalRecord) {
  auto rec = record({field("x", vector(8)),
                     field("y", bit())});
  auto a = signal("a", rec);
  auto b = signal("b", rec);
  Connect(a, b);
  auto ca = vhdl::Arch::Generate(*a).ToString();
  auto cb = vhdl::Arch::Generate(*b).ToString();
  ASSERT_EQ(ca, "a_x <= b_x;\n"
                "a_y <= b_y;\n");
  ASSERT_EQ(cb, "");
}

TEST(VHDL_ASSIGN, SignalRecordArray) {
  auto size = intl(0);
  auto rec = record({field("x", vector(8)),
                     field("y", bit())});
  auto a = signal_array("a", rec, size);
  auto b = signal_array("b", rec, size);

  Connect(a->Append(), b->Append());
  Connect(a->Append(), b->Append());

  auto ca = vhdl::Arch::Generate(*a).ToString();
  auto cb = vhdl::Arch::Generate(*b).ToString();

  ASSERT_EQ(ca, "a_y(0)           <= b_y(0);\n"
                "a_y(1)           <= b_y(1);\n"
                "a_x(7 downto 0)  <= b_x(7 downto 0);\n"
                "a_x(15 downto 8) <= b_x(15 downto 8);\n");
  ASSERT_EQ(cb, "");
}

TEST(VHDL_ASSIGN, SignalRecordArrayParam) {
  auto a_size = parameter("A_SIZE", integer(), intl(0));
  auto b_size = parameter("B_SIZE", integer(), intl(0));
  auto rec = record({field("x", vector(8)),
                     field("y", bit())});
  auto a = signal_array("a", rec, a_size);
  auto b = signal_array("b", rec, b_size);

  auto a0 = a->Append();
  auto a1 = a->Append();
  auto b0 = b->Append();
  auto b1 = b->Append();
  Connect(a0, b0);
  Connect(a1, b1);

  auto ca = vhdl::Arch::Generate(*a).ToString();
  auto cb = vhdl::Arch::Generate(*b).ToString();

  ASSERT_EQ(ca, "a_y(0)           <= b_y(0);\n"
                "a_y(1)           <= b_y(1);\n"
                "a_x(7 downto 0)  <= b_x(7 downto 0);\n"
                "a_x(15 downto 8) <= b_x(15 downto 8);\n");
  ASSERT_EQ(cb, "");
}

TEST(VHDL_ASSIGN, SignalRecordParamArrayParam) {
  auto a_size = parameter("A_SIZE", integer(), intl(0));
  auto b_size = parameter("B_SIZE", integer(), intl(0));
  auto width = parameter("WIDTH", integer(), intl(8));
  auto rec = record({field("x", vector(width)),
                     field("y", bit())});
  auto a = signal_array("a", rec, a_size);
  auto b = signal_array("b", rec, b_size);

  Connect(a->Append(), b->Append());
  Connect(a->Append(), b->Append());

  auto ca = vhdl::Arch::Generate(*a).ToString();
  auto cb = vhdl::Arch::Generate(*b).ToString();

  ASSERT_EQ(ca, "a_y(0)                          <= b_y(0);\n"
                "a_y(1)                          <= b_y(1);\n"
                "a_x(WIDTH-1 downto 0)           <= b_x(WIDTH-1 downto 0);\n"
                "a_x(WIDTH+WIDTH-1 downto WIDTH) <= b_x(WIDTH+WIDTH-1 downto WIDTH);\n");
  ASSERT_EQ(cb, "");
}

TEST(VHDL_ASSIGN, VecOneToBit) {
  auto vec = vector(1);

  auto mapper = TypeMapper::Make(bit(), vec);
  mapper->Add(0, 0);
  bit()->AddMapper(mapper);

  auto a = signal("a", bit());
  auto b = signal("b", vec);
  auto c = signal("c", vec);
  auto d = signal("d", bit());

  Connect(a, b);
  Connect(c, d);

  auto ca = vhdl::Arch::Generate(*a).ToString();
  auto cc = vhdl::Arch::Generate(*c).ToString();

  ASSERT_EQ(ca, "a <= b(0);\n");
  ASSERT_EQ(cc, "c(0) <= d;\n");
}

}  // namespace cerata
