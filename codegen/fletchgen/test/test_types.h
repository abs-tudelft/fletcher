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

#include "../src/types.h"

namespace fletchgen {

TEST(Types, Flatten) {
  auto a = bit();
  auto b = Vector::Make<8>();
  auto c = Stream::Make(b);

  auto d = Record::Make("inner", {RecordField::Make("x", a),
                                  RecordField::Make("y", b),
                                  RecordField::Make("z", c)});
  auto e = Stream::Make(c);
  auto f = Record::Make("outer", {RecordField::Make("q", d),
                                  RecordField::Make("r", e)});

  auto flat = Flatten(f);
  std::cout << ToString(flat);

}

}  // namespace fletchgen
