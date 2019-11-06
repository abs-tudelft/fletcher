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

#pragma once

#include <memory>
#include <vector>
#include <string>
#include <sstream>
#include <utility>

#include "cerata/output.h"
#include "cerata/graph.h"
#include "cerata/dot/style.h"

/// Contains everything related to the DOT back-end.
namespace cerata::dot {

/// Dot graph output generator.
struct Grapher {
  /// The style.
  Style style;
  /// Edges that were already drawn.
  std::vector<Edge *> drawn_edges = {};
  Grapher() : Grapher(Style::normal()) {}
  /// Grapher constructor.
  explicit Grapher(Style style) : style(std::move(style)) {}
  /// @brief Generate edges.
  std::string GenEdges(const Graph &graph, int level = 0);
  /// @brief Generate a node.
  std::string GenNode(const Node &n, int level = 0);
  /// @brief Generate nodes.
  std::string GenNodes(const Graph &graph, Node::NodeID id, int level = 0, bool no_group = false);
  /// @brief Generate a graph.
  std::string GenGraph(const Graph &graph, int level = 0);
  /// @brief Generate a DOT file.
  std::string GenFile(const Graph &graph, const std::string &path);
  /// @brief Generate expressions.
  static std::string GenExpr(const Node &exp, const std::string &prefix = "", int level = 0);
};

/// @brief Return the DOT name of a node.
std::string NodeName(const Node &node, const std::string &suffix = "");

/// @brief OutputGenerator for DOT graphs.
class DOTOutputGenerator : public OutputGenerator {
 public:
  /// @brief DOTOutputGenerator constructor.
  explicit DOTOutputGenerator(std::string root_dir, std::vector<OutputSpec> graphs = {})
      : OutputGenerator(std::move(root_dir), std::move(graphs)) {}
  /// @brief Generate the DOT graphs.
  void Generate() override;
  /// @brief Returns the subdirectory used by this OutputGenerator.
  std::string subdir() override { return "dot"; }
};

}  // namespace cerata::dot
