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

#include <memory>
#include <deque>
#include <string>
#include <vector>
#include <sstream>

#include "cerata/output.h"
#include "cerata/graphs.h"
#include "cerata/dot/style.h"

namespace cerata::dot {

/**
 * @brief Dot graph output generator.
 */
struct Grapher {
  Style style;
  Config config;
  std::deque<std::shared_ptr<Edge>> drawn_edges = {};

  Grapher() : Grapher(Style::normal()) {};
  explicit Grapher(Style style) : style(std::move(style)) {}
  std::string GenEdges(const Graph *graph, int level = 0);
  std::string GenNode(const std::shared_ptr<Node> &n, int level = 0);
  std::string GenNodes(const Graph *graph, Node::NodeID id, int level = 0, bool nogroup = false);
  std::string GenGraph(const Graph *graph, int level = 0);
  std::string GenFile(const std::shared_ptr<Graph> &graph, const std::string& path);
  static std::string GenExpr(const std::shared_ptr<Node> &exp, const std::string& prefix = "", int level = 0);
};

std::string NodeName(const std::shared_ptr<Node> &node, const std::string& suffix = "");

class DOTOutputGenerator : public OutputGenerator {
 public:
  explicit DOTOutputGenerator(std::string root_dir, std::deque<OutputGenerator::OutputSpec> graphs = {})
  : OutputGenerator(std::move(root_dir), std::move(graphs)) {}
  void Generate() override;
  std::string subdir() override { return "dot"; }
};

}  // namespace cerata::dot
