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

#include "dag/transform/string.h"

#include <memory>

#include "dag/dag.h"

namespace dag::transform {

Transform Match(const std::string &str) {
  Transform result;
  result.name = "Match";
  result.constants.push_back(constant("match", str));
  result += in("in", utf8());
  result += out("out", boolean());
  return result;
}

Transform Split(const std::string &str) {
  Transform result;
  result.name = "SplitBy";
  result.constants.push_back(constant("match", str));
  result += in("in", utf8());
  result += out("out", list(utf8()));
  return result;
}

Transform SplitByRegex(const std::string &regex) {
  Transform result;
  result.name = "SplitByRegex";
  result.constants.push_back(constant("expr", regex));
  result += in("in", utf8());
  result += out("out", utf8());
  return result;
}

}  // namespace dag::transform
