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

#include <fstream>

// Macro to save the test to some VHDL files that can be used to syntax check the tests with e.g. GHDL
// At some point the reverse might be more interesting - load the test cases from file into the test.
#define VHDL_DUMP_TEST(str) \
  std::ofstream(std::string(::testing::UnitTest::GetInstance()->current_test_info()->test_suite_name()) \
  + "_" + ::testing::UnitTest::GetInstance()->current_test_info()->name() + ".vhd") << str
