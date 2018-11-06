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

#include <vector>
#include <string>
#include <iostream>

#include "common/arrow-utils.h"

#include "test_schemas.h"

namespace fletcher {
namespace test {

void test_flatten() {
  auto schema = genListUint8Schema();
  std::vector<std::string> bufs;
  appendExpectedBuffersFromField(&bufs, schema->field(0));
  for (const auto &str : bufs) {
    std::cout << str << std::endl;
  }
}

}
}

int main() {
  fletcher::test::test_flatten();
  return EXIT_SUCCESS;
}