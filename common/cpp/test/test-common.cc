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

#include "fletcher/common/arrow-utils.h"

#include "test_schemas.h"

namespace fletcher {
namespace test {

void testFlattenFromField() {
  bool pass = true;
  // List of uint8's
  auto schema = genListUint8Schema();
  std::vector<std::string> bufs;
  appendExpectedBuffersFromField(&bufs, schema->field(0));
  pass |= bufs[0] == "list_offsets";
  pass |= bufs[1] == "uint8_values";

  schema = genStringSchema();
  // String is essentially a list of non-nullable utf8 bytes
  std::vector<std::string> bufs2;
  appendExpectedBuffersFromField(&bufs, schema->field(0));
  pass |= bufs[0] == "name_offsets";
  pass |= bufs[1] == "name_values";

  if (!pass) {
    exit(EXIT_FAILURE);
  }
}

}
}

int main() {
  fletcher::test::testFlattenFromField();
  return EXIT_SUCCESS;
}