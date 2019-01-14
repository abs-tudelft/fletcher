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

#include <sstream>
#include <iostream>
#include <utility>
#include <vector>
#include <memory>

#include "./stream.h"
#include "./nodes.h"
#include "./types.h"

namespace fletchgen {
namespace stream {

std::shared_ptr<Edge> Connect(std::shared_ptr<Node> src, std::shared_ptr<Node> dst) {
  if (src == nullptr) {
    throw std::runtime_error("Left-hand side of edge connector is null");
  }
  if (dst == nullptr) {
    throw std::runtime_error("Right-hand side of edge connector is null");
  }
  if (src->type->type->id != dst->type->type->id) {
    throw std::runtime_error("Cannot connect nodes of different types.");
  }
  std::string edge_name = dst->name();
  auto edge = Edge::Make(edge_name, src, dst);
  src->outs.push_back(edge);
  dst->ins.push_back(edge);
  return edge;
}

std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &dst, const std::shared_ptr<Node> &src) {
  return Connect(dst, src);
}

std::shared_ptr<Edge> Edge::Make(std::string name, const std::shared_ptr<Node> &dst, const std::shared_ptr<Node> &src) {
  return std::make_shared<Edge>(name, dst, src);
}

}  // namespace stream
}  // namespace fletchgen
