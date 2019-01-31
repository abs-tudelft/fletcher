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

#pragma once

#include <gtest/gtest.h>

#include <string>
#include <fstream>

#include "../src/nodes.h"
#include "../src/dot/dot.h"

namespace fletchgen {

TEST(Expressions, Add) {
  auto a = Literal::Make(string(), "a");
  auto b = Parameter::Make("b", string());
  auto c = Literal::Make(string(), "c");
  auto d = Parameter::Make("d", string());
  auto e = intl<10>();

  auto f = a+b-c*d/e+a*b-c/d+e;

  std::cout << f->ToString() << std::endl;
  ASSERT_EQ(f->ToString(), "a+b-c*d/10+a*b-c/d+10");

  dot::Grapher dot;
  std::ofstream out("graph.dot");
  out << dot.GenExpr(f);
}

TEST(Expressions, IntLits) {
  auto z = intl<0>();
  auto o = intl<1>();

  //auto g0 = z + z;
  //auto g1 = z + o;
  //auto g2 = o + z;
  auto g3 = o + o;

  //std::cout << g0->ToString() << std::endl;
  //std::cout << g1->ToString() << std::endl;
  //std::cout << g2->ToString() << std::endl;
  std::cout << g3->ToString() << std::endl;

  dot::Grapher dot;
  std::ofstream out("graph.dot");
  out << dot.GenExpr(g3);
}

}