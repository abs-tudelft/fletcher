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

#include <gtest/gtest.h>

// Graph layer tests
#include "cerata/test_expressions.h"
#include "cerata/test_types.h"
#include "cerata/test_pool.h"

// VHDL backend tests
#include "cerata/vhdl/test_declarators.h"
#include "cerata/vhdl/test_instantiators.h"
#include "cerata/vhdl/test_designs.h"

// DOT backend tests
#include "cerata/dot/test_graphs.h"

void Log(int level, const std::string &msg, char const *source_fun, char const *source_file, int line_num) {
  std::cout << source_file << ":" << line_num << ":" << source_fun << ": " << msg << std::endl;
}

int main(int argc, char **argv) {
  cerata::logger().enable(Log);
  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}
