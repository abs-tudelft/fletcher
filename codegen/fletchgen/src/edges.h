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

#include <iostream>
#include <algorithm>

#include "./utils.h"
#include "./nodes.h"

namespace fletchgen {

/**
 * @brief A directed edge between two nodes
 */
struct Edge : public Named {
  std::shared_ptr<Node> dst;
  std::shared_ptr<Node> src;

  Edge(std::string name, std::shared_ptr<Node> dst, std::shared_ptr<Node> src)
      : Named(std::move(name)), dst(std::move(dst)), src(std::move(src)) {}

  static std::shared_ptr<Edge> Make(std::string name,
                                    const std::shared_ptr<Node> &dst,
                                    const std::shared_ptr<Node> &src);

  std::shared_ptr<Node> GetOtherNode(const std::shared_ptr<Node> &node);
  std::deque<std::shared_ptr<Edge>> GetAllSiblings(const std::shared_ptr<Node> &node);
  bool HasSiblings(const std::shared_ptr<Node> &node);
  static void CheckEdgeOfNode(const std::shared_ptr<Edge> &edge, const std::shared_ptr<Node> &node);
  static int CountAllEdges(const std::shared_ptr<Node> &node);

  static int GetIndexOf(const std::shared_ptr<Edge> &edge, const std::shared_ptr<Node> &node);
  static int GetVectorOffsetOf(const std::shared_ptr<Edge> &edge, const std::shared_ptr<Node> &node);
};

std::shared_ptr<Edge> Connect(std::shared_ptr<Node> dst, std::shared_ptr<Node> src);
std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &left, const std::shared_ptr<Node> &right);

}  // namespace fletchgen
