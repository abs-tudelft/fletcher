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
#include <fstream>

#include "../edges.h"

#include "dot.h"

namespace fletchgen {
namespace dot {

std::string Grapher::GenEdges(const std::shared_ptr<Component> &comp, int level) {
  std::stringstream str;

  for (const auto &e : GetAllEdges(comp)) {
    if (std::find(generated.begin(), generated.end(), e) == generated.end()) {
      str << std::string(2 * level, ' ') << e->src->name() << " -> " << e->dst->name();
      str << " [";
      if (e->src->IsPort() && e->dst->IsSignal()) {
        str << style.port_to_sig;
      } else if (e->src->IsSignal() && e->dst->IsPort()) {
        str << style.sig_to_port;
      } else {
        str << style.edge;
      }
      if (!e->src->IsLiteral()) {
        if (e->src->type->Is(Type::STREAM)) {
          str << ", " << style.stream;
        }
      } else {
        str << ", " << style.litedge;
      }
      str << "]\n";
      generated.push_back(e);
    }
  }
  return str.str();
}

std::string Grapher::GenNodes(const std::shared_ptr<Component> &comp, int level) {
  std::stringstream str;
  for (const auto &n : comp->nodes) {
    str << std::string(2 * level, ' ') << n->name();
    str << " [";
    if (n->IsPort()) {
      str << style.port.base;
      if (n->type->Is(Type::STREAM)) {
        str << ", " << style.port.stream;
      } else if (n->type->Is(Type::CLOCK)) {
        str << ", " << style.port.clock;
      } else if (n->type->Is(Type::RESET)) {
        str << ", " << style.port.reset;
      } else {

      }
    } else if (n->IsSignal()) {
      str << style.sig.base;
    } else if (n->IsParameter()) {
      str << style.param.base;
    } else if (n->IsLiteral()) {
      str << style.lit.base;
    }
    str << "];\n";
  }
  return str.str();
}

std::string Grapher::GenComponent(const std::shared_ptr<Component> &comp, int level) {
  std::stringstream ret;

  // (sub)graph header
  if (level == 0) {
    ret << "digraph {\n";
    level++;
  }
    ret << std::string(2 * level, ' ') << "subgraph cluster_" << comp->name() << " {\n";
    ret << std::string(2 * (level + 1), ' ') << "label=\"" << comp->name() << "\";\n";

  // Nodes and edges
  ret << GenNodes(comp, level + 1);
  ret << GenEdges(comp, level + 1);

  if (!comp->children.empty()) {
    ret << "\n";
  }

  // Component children
  for (const auto &child : comp->children) {
    ret << GenComponent(child, level + 1);
  }
  ret << std::string(2 * level, ' ') << "}\n";
  if (level == 1) {
    ret << "}\n";
  }

  return ret.str();
}

std::string Grapher::GenFile(const std::shared_ptr<Component> &comp, std::string path) {
  std::string graph = GenComponent(comp);
  std::ofstream out(path);
  out << graph;
  out.close();
  return graph;
}

std::deque<std::shared_ptr<Edge>> GetAllEdges(const std::shared_ptr<Component> &comp) {
  std::deque<std::shared_ptr<Edge>> all_edges;

  for (const auto &n : comp->nodes) {
    auto edges = n->edges();
    for (const auto &e : edges) {
      all_edges.push_back(e);
    }
  }

  return all_edges;
}

Style Style::basic() {
  static Style style;
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

  style.port.base = "shape=circle";
  style.port.clock = "shape=diamond, color=\"#000000\", penwidth=1";
  style.port.reset = "shape=diamond, color=\"#000000\", penwidth=1";
  style.port.stream = "style=filled, fillcolor=\"#81ceff\", color=\"#408fc0\", penwidth=2";

  style.sig.base = "shape=plaintext, style=filled, fillcolor=\"#bfff81\", margin=0.05, width=0, height=0";

  style.param.base = "shape=note";

  style.lit.base = "shape=plaintext, margin=0.05, width=0, height=0";
  style.litedge = "style=dotted, arrowhead=none, arrowtail=none";

  style.port_to_sig = "arrowhead=none, arrowtail=inv, dir=both";
  style.sig_to_port = "arrowhead=normal, arrowtail=none, dir=both";
  style.stream = "penwidth=2, color=\"#408fc0\"";
  style.edge = "penwidth=1";
  return style;
}

}
}
