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
#include <cerata/api.h>
#include <string>
#include <fstream>

namespace cerata {

TEST(Pool, IntPool) {
  cerata::default_node_pool()->Clear();
  auto zero = intl(0);
  auto one = intl(1);
  auto rzero = rintl(0);
  auto rone = rintl(1);

  ASSERT_EQ(zero.get(), rzero);
  ASSERT_EQ(one.get(), rone);
}

TEST(Pool, StringPool) {
  cerata::default_node_pool()->Clear();
  auto empty = strl("");
  auto some = strl("a");
  auto rempty = rstrl("");
  auto rsome = rstrl("a");

  ASSERT_EQ(empty.get(), rempty);
  ASSERT_EQ(some.get(), rsome);
}

}
