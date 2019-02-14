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
#include "../src/flattypes.h"

namespace fletchgen {

TEST(Types, Flatten) {
  auto a = bit();
  auto b = Vector::Make<8>();
  auto c = Stream::Make(b);

  auto d = Record::Make("inner", {RecordField::Make("a", a),
                                  RecordField::Make("b", b),
                                  RecordField::Make("c", c)});
  auto e = Stream::Make(c);
  auto f = Record::Make("outer", {RecordField::Make("d", d),
                                  RecordField::Make("e", e)});

  auto flat = Flatten(f.get());
  std::cout << ToString(flat);
}

TEST(Types, TypeMapper) {
  auto a = bit();
  auto b = Vector::Make<8>();
  auto c = Record::Make("rec_K", {RecordField::Make("a", a),
                                  RecordField::Make("b", b)});
  auto d = Stream::Make(c);

  auto q = bit();
  auto r = Vector::Make<8>();
  auto s = Record::Make("rec_L", {RecordField::Make("q", q),
                                  RecordField::Make("r0", r),
                                  RecordField::Make("r1", Stream::Make(r))});
  auto t = Stream::Make(s);

  auto k = Flatten(d.get());
  auto l = Flatten(t.get());

  TypeMapper conv(t.get(), d.get());

  // TODO(johanpel): type converter mapping is quite ugly at the moment
  conv.Add(0, 0)
      .Add(2, 2)
      .Add(3, 3)
      .Add(4, 0)
      .Add(5, 3);

  std::cout << ToString(k);
  std::cout << ToString(l);
  std::cout << conv.ToString();
}

}  // namespace fletchgen
