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

#include <string>
#include <fstream>
#include <cerata/api.h>

namespace cerata {

TEST(Types, Flatten) {
  auto a = bit();                     // 2
  auto b = vector(8);                 // 3
  auto c = stream("stream", "q", b);  // 4
  // Stream::valid()                  // 5
  // Stream::ready()                  // 6

  auto d = record("inner", {          // 1
      field("k", a),
      field("l", b),
      field("m", c)});

  auto e = stream("n", c);            // 7
  // Stream::valid()                  // 8
  // Stream::ready()                  // 9
  // c                                // 10
  // Stream::valid()                  // 11
  // Stream::ready()                  // 12
  // b                                // 13

  auto f = record("outer", {          // 0
      field("a", d),
      field("b", e)});

  auto flat = Flatten(f.get());

  ASSERT_EQ(flat[ 0].type_, f.get());
  ASSERT_EQ(flat[ 1].type_, d.get());
  ASSERT_EQ(flat[ 2].type_, a.get());
  ASSERT_EQ(flat[ 3].type_, b.get());
  ASSERT_EQ(flat[ 4].type_, c.get());
  ASSERT_EQ(flat[ 5].type_, Stream::valid().get());
  ASSERT_EQ(flat[ 6].type_, Stream::ready().get());
  ASSERT_EQ(flat[ 7].type_, b.get());
  ASSERT_EQ(flat[ 8].type_, e.get());
  ASSERT_EQ(flat[ 9].type_, Stream::valid().get());
  ASSERT_EQ(flat[10].type_, Stream::ready().get());
  ASSERT_EQ(flat[11].type_, c.get());
  ASSERT_EQ(flat[12].type_, Stream::valid().get());
  ASSERT_EQ(flat[13].type_, Stream::ready().get());
  ASSERT_EQ(flat[14].type_, b.get());

  ASSERT_EQ(flat[ 0].name(NamePart("x"), "_"), "x");
  ASSERT_EQ(flat[ 1].name(NamePart("x"), "_"), "x_a");
  ASSERT_EQ(flat[ 2].name(NamePart("x"), "_"), "x_a_k");
  ASSERT_EQ(flat[ 3].name(NamePart("x"), "_"), "x_a_l");
  ASSERT_EQ(flat[ 4].name(NamePart("x"), "_"), "x_a_m");
  ASSERT_EQ(flat[ 5].name(NamePart("x"), "_"), "x_a_m_valid");
  ASSERT_EQ(flat[ 6].name(NamePart("x"), "_"), "x_a_m_ready");
  ASSERT_EQ(flat[ 7].name(NamePart("x"), "_"), "x_a_m_q");
  ASSERT_EQ(flat[ 8].name(NamePart("x"), "_"), "x_b");
  ASSERT_EQ(flat[ 9].name(NamePart("x"), "_"), "x_b_valid");
  ASSERT_EQ(flat[10].name(NamePart("x"), "_"), "x_b_ready");
  ASSERT_EQ(flat[11].name(NamePart("x"), "_"), "x_b_n");
  ASSERT_EQ(flat[12].name(NamePart("x"), "_"), "x_b_n_valid");
  ASSERT_EQ(flat[13].name(NamePart("x"), "_"), "x_b_n_ready");
  ASSERT_EQ(flat[14].name(NamePart("x"), "_"), "x_b_n_q");
}

TEST(Types, TypeMapper) {
  auto a = bit();
  auto b = vector(8);
  auto c = record("rec_K", {field("a", a),
                                  field("b", b)});
  auto d = stream(c);

  auto q = bit();
  auto r = vector(8);
  auto s = record("rec_L", {field("q", q),
                                  field("r0", r),
                                  field("r1", stream(r))});
  auto t = stream(s);

  TypeMapper conv(t.get(), d.get());

  // TODO(johanpel): make type converter mapping less obscure
  conv.Add(0, 0)
      .Add(2, 2)
      .Add(3, 3)
      .Add(4, 0)
      .Add(5, 3);

  auto ump = conv.GetUniqueMappingPairs();

  // TODO(johanpel): come up with some test.

  std::cout << conv.ToString();

}

}  // namespace cerata
