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
#include <memory>

#include <arrow/api.h>
#include <arrow/builder.h>
#include <arrow/record_batch.h>

#include <gtest/gtest.h>

#include "vhdl/test_declarators.h"
#include "vhdl/test_instantiators.h"

#include "dot/test_graphs.h"

#include "fletcher/test_fletcher.h"

int main(int argc, char **argv) {

  ::testing::InitGoogleTest(&argc, argv);
  return RUN_ALL_TESTS();
}