#include <utility>

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

#include "../graphs.h"

namespace fletchgen {
namespace dot {

std::deque<std::shared_ptr<Edge>> GetAllEdges(const std::shared_ptr<Graph> &graph);

struct Style {
  // 0 ff8181
  // 1 ffe081
  // 2 bfff81
  // 3 81ffd1
  // 4 81ceff
  // 5 9381ff
  // 6 f281ff

  // 0 e85858
  // 1 e8c558
  // 2 9fe858
  // 3 58e8b3
  // 4 58b0e8
  // 5 6c58e8
  // 6 d958e8

  // 0 c04040
  // 1 c0a140
  // 2 7fc040
  // 3 40c091
  // 4 408fc0
  // 5 5340c0
  // 6 b340c0

  struct TableStyle {
    std::string stream = "#58b0e8"; // 4
    std::string record = "#58e8b3"; // 3
  } tables;

  struct EdgeStyle {
    std::string base = "penwidth=1";
    std::string port_to_sig = "arrowhead=none, arrowtail=inv, dir=both";
    std::string sig_to_port = "arrowhead=normal, arrowtail=none, dir=both";
    std::string stream = "penwidth=2, color=\"#408fc0\"";
    std::string lit = "style=dotted, arrowhead=none, arrowtail=none";
    std::string clock = "shape=diamond, color=\"#000000\", penwidth=1";
    std::string reset = "shape=diamond, color=\"#000000\", penwidth=1";
  } edge;

  struct NodeStyle {
    std::string base = "margin=0.15, width=0, height=0";
    std::string port = "shape=rect";
    std::string sig = "shape=rect, style=filled, fillcolor=\"#bfff81\", margin=0.05, width=0, height=0";
    std::string param = "shape=note";
    std::string lit = "shape=plaintext, margin=0.05, width=0, height=0";

    struct TypeStyle {
      std::string stream = "style=filled, fillcolor=\"#81ceff\", color=\"#408fc0\", penwidth=2";
      std::string clock;
      std::string reset;
      std::string vector;
      std::string bit;
    } type;
  } node;
};

struct NodeConfig {
  bool parameters = false;
  bool literals = false;
  bool signals = true;
  bool ports = true;
  struct TypeConfig {
    bool clock = false;
    bool reset = false;
  } types;
};

struct Config {
  NodeConfig nodes;
};

struct Grapher {
  Style style;
  Config config;
  std::deque<std::shared_ptr<Edge>> drawn_edges;

  Grapher() = default;
  explicit Grapher(Style style) : style(std::move(style)) {}

  std::string GenCell(const std::shared_ptr<Type> &type, std::string name, int level = 0);
  std::string GenEdges(const std::shared_ptr<Graph> &comp, int level = 0);
  std::string GenNodes(const std::shared_ptr<Graph> &comp, int level = 0);
  std::string GenGraph(const std::shared_ptr<Graph> &graph, int level = 0);
  std::string GenFile(const std::shared_ptr<Graph> &graph, std::string path);
};

std::string NodeName(const std::shared_ptr<Node> &n);

}  // namespace dot
}  // namespace fletchgen
