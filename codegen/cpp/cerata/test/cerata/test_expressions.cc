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
#include <memory>

#include "cerata/api.h"

namespace cerata {

TEST(Expressions, OpStringLiterals) {
  auto a = strl("a");
  auto b = strl("b");
  auto f = a + b;
  auto g = a - b;
  auto h = a * b;
  auto i = a / b;
  ASSERT_EQ(f->ToString(), "a+b");
  ASSERT_EQ(g->ToString(), "a-b");
  ASSERT_EQ(h->ToString(), "a*b");
  ASSERT_EQ(i->ToString(), "a/b");
}

TEST(Expressions, OpIntLiterals) {
  auto a = intl(1);
  auto b = intl(2);
  auto f = a + b;
  auto g = a - b;
  auto h = a * b;
  auto i = a / b;
  ASSERT_EQ(f->ToString(), "3");
  ASSERT_EQ(g->ToString(), "-1");
  ASSERT_EQ(h->ToString(), "2");
  ASSERT_EQ(i->ToString(), "0");
}

TEST(Expressions, Minimize) {
  auto a = strl("a");
  auto b = parameter("b", string());
  auto c = strl("c");
  auto d = parameter("d", string());
  auto e = intl(10);

  std::shared_ptr<Node> f = intl(10) + intl(10);
  std::shared_ptr<Node> g = a + intl(0);
  std::shared_ptr<Node> h = a * intl(0);
  std::shared_ptr<Node> i = a + b;
  std::shared_ptr<Node> j = a + b - c;
  std::shared_ptr<Node> k = a + b - c * d;

  ASSERT_EQ(f->ToString(), "20");
  ASSERT_EQ(g->ToString(), "a");
  ASSERT_EQ(h->ToString(), "0");
  ASSERT_EQ(i->ToString(), "a+b");
  ASSERT_EQ(j->ToString(), "a+b-c");
  ASSERT_EQ(k->ToString(), "a+b-c*d");
}

TEST(Expressions, IntLits) {
  auto i0 = intl(0);
  auto i1 = intl(1);
  auto e0 = i0 + i0;
  auto e1 = i0 + i1;
  auto e2 = i1 + i0;
  auto e3 = i1 + i1;
  ASSERT_EQ(e0->ToString(), "0");
  ASSERT_EQ(e1->ToString(), "1");
  ASSERT_EQ(e2->ToString(), "1");
  ASSERT_EQ(e3->ToString(), "2");
}

}
