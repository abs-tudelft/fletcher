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

#include "cerata/nodes.h"
#include "cerata/dot/dot.h"

namespace cerata {

TEST(Expressions, Add) {
  auto a = Literal::Make(string(), "a");
  auto b = Parameter::Make("b", string());
  auto c = Literal::Make(string(), "c");
  auto d = Parameter::Make("d", string());
  auto e = intl<10>();

  auto f = a+b-c*d/e+a*b-c/d+e;

  ASSERT_EQ(f->ToString(), "a+b-c*d/10+a*b-c/d+10");
}

TEST(Expressions, IntLits) {
  auto i0 = intl<0>();
  auto i1 = intl<1>();

  auto e0 = i0 + i0;
  auto e1 = i0 + i1;
  auto e2 = i1 + i0;
  auto e3 = i1 + i1;

  ASSERT_EQ(e0->ToString(),"0");
  ASSERT_EQ(e1->ToString(),"1");
  ASSERT_EQ(e2->ToString(),"1");
  ASSERT_EQ(e3->ToString(),"2");
}

}