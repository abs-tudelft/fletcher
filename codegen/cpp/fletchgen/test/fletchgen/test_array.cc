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
#include <arrow/api.h>
#include <string>
#include <memory>

#include "fletcher/common.h"
#include "fletchgen/array.h"
#include "fletchgen/test_utils.h"

namespace fletchgen {

// TODO(johanpel): load component decls from file and check for equivalence.

TEST(Array, TypeMapper) {
  using arrow::field;
  using std::pair;
  using fletcher::WithMetaEPC;

  constexpr int n_tests = 8;

  std::vector<std::shared_ptr<arrow::Field>> fields(n_tests);
  std::vector<pair<int, int>> specs(n_tests);
  std::vector<std::shared_ptr<Type>> kernel_types(n_tests);
  std::vector<std::shared_ptr<Type>> array_types(n_tests);
  std::vector<std::shared_ptr<TypeMapper>> mappers(n_tests);

  // Arrow type.                                                     (streams, data width + counts width + nullable )
  fields[0] = field("test", arrow::uint64(), false);                         // 1, 64      +   0   +   0
  fields[1] = field("test", arrow::uint64(), true);                          // 1, 64      +   0   +   1
  fields[2] = field("test", arrow::utf8(), false);                           // 2, 32+8    + 1+1   +   0
  fields[3] = WithMetaEPC(*arrow::field("test", arrow::utf8(), false), 4);   // 2, 4*8+32  + 1+3   +   0
  fields[4] = WithMetaEPC(*arrow::field("test", arrow::binary(), true), 8);  // 2, 8*8+32  + 1+4   +   1
  fields[5] = field("test",
                    arrow::list(
                        field("inner", arrow::utf8(), false)), false);       // 3, 32+32+8 + 1+1   +   0
  fields[6] = WithMetaEPC(*field("test", arrow::utf8(), false), 64);         // 2, 32+512  + 1+7   +   0
  fields[7] = WithMetaEPC(*field("test", arrow::float16(), false), 2);       // 1, 32      + 2     +   0

  // Array data spec must return correct pair.
  for (int i = 0; i < n_tests; i++) {
    specs[i] = GetArrayDataSpec(*fields[i]);
  }

  // Check specs
  ASSERT_EQ(specs[0], pair(1, 64));
  ASSERT_EQ(specs[1], pair(1, 64 + 1));
  ASSERT_EQ(specs[2], pair(2, 32 + 8 + 1 + 1));
  ASSERT_EQ(specs[3], pair(2, 4 * 8 + 32 + 1 + 3));
  ASSERT_EQ(specs[4], pair(2, 8 * 8 + 32 + 1 + 4 + 1));
  ASSERT_EQ(specs[5], pair(3, 32 + 32 + 8 + 1 + 1));
  ASSERT_EQ(specs[6], pair(2, 32 + 512 + 1 + 7));
  ASSERT_EQ(specs[7], pair(1, 32 + 2 + 0));

  // Generate types as seen by array(reader/writer) and kernel, and auto-generate mappers.
  for (int i = 0; i < n_tests; i++) {
    array_types[i] = array_reader_out(specs[i]);
    kernel_types[i] = GetStreamType(*fields[i], fletcher::Mode::READ);
    mappers[i] = GetStreamTypeMapper(kernel_types[i].get(), array_types[i].get());
    std::cout << mappers[i]->ToString() << std::endl;
  }

  // TODO(johanpel): Check mappers between concatenated array data and kernel data streams

}

TEST(Array, Reader) {
  auto top = array(fletcher::Mode::READ);
  auto generated = GenerateTestDecl(top);
}

TEST(Array, Writer) {
  auto top = array(fletcher::Mode::WRITE);
  GenerateTestDecl(top);
}

}  // namespace fletchgen
