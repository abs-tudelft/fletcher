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

TEST(Nodes, ParamTrace) {
  auto lit = strl("foo");
  auto a = parameter("a", string(), lit);
  auto b = parameter("b", std::string("bdef"));
  auto c = parameter("c", std::string("cdef"));
  auto expr = c * 2;
  auto d = parameter("d", std::string("ddef"));

  a <<= lit;
  b <<= a;
  c <<= b;
  d <<= expr;

  std::vector<Node *> trace;
  d->TraceValue(&trace);

  for (const auto &t : trace) {
    std::cout << "T: " + t->ToString() << std::endl;
  }

  ASSERT_EQ(trace[0], d.get());
  ASSERT_EQ(trace[1], expr.get());

}

}  // namespace cerata
