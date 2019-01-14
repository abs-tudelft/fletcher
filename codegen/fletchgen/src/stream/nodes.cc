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

#include "nodes.h"

namespace fletchgen {
namespace stream {

std::deque<std::shared_ptr<Edge>> Node::edges() const {
  std::deque<std::shared_ptr<Edge>> ret;
  for (const auto &e : ins) {
    ret.push_back(e);
  }
  for (const auto &e : outs) {
    ret.push_back(e);
  }
  return ret;
}

std::shared_ptr<Node> Node::Make(std::string name, const std::shared_ptr<NodeType> &type) {
  return std::make_shared<Node>(name, type);
}

}  // namespace stream
}  // namespace fletchgen
