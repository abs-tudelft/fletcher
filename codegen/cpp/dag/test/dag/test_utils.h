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

#include <gtest/gtest.h>
#include <sstream>
#include <fstream>

#include "dag/api.h"

namespace dag {

inline void DumpToDot(const Graph &g, std::string name = "", bool simple = false) {
  if (name.empty()) {
    std::stringstream n;
    n << ::testing::UnitTest::GetInstance()->current_test_info()->test_suite_name();
    n << "_";
    n << ::testing::UnitTest::GetInstance()->current_test_info()->test_case_name();
    n << "_";
    n << ::testing::UnitTest::GetInstance()->current_test_info()->name();
    name = n.str();
  }
  auto graph = AsDotGraph(g, simple);
  std::cout << std::endl << graph << std::endl;
  system("mkdir -p test_graphs");
  std::ofstream("test_graphs/" + name + ".dot") << graph;
}

} // namespace dag
