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

#include "../graphs.h"

namespace fletchgen {
namespace dot {

inline std::string tab(uint n) {
  return std::string(2 * n, ' ');
}

inline std::string tab(int n) {
  return tab(static_cast<uint>(n));
}

inline std::string sanitize(std::string in) {
  // Replace :
  std::replace(in.begin(), in.end(), ':', '_');

  // Replace "
  size_t idx = 0;
  while (true) {
    idx = in.find('"', idx);
    if (idx == std::string::npos)
      break;
    in.replace(idx, 2, "\\\"");
    idx += 2;
  }
  return in;
}

inline std::string assign_quotes(const std::string &attribute, const std::string &style) {
  if (!style.empty()) {
    return attribute + "=\"" + style + "\"";
  } else {
    return "";
  }
}

std::deque<std::shared_ptr<Edge>> GetAllEdges(const std::shared_ptr<Graph> &graph);

struct Palette {
  std::string black = "#000000";
  std::string white = "#ffffff";
  std::string gray = "#808080";
  std::string darker = "#202020";
  std::string dark = "#404040";
  std::string light = "#B0B0B0";
  std::string lighter = "#D0D0D0";
  // Bright
  std::string b[7] = {"#ff8181", "#ffe081", "#bfff81", "#81ffd1", "#81ceff", "#9381ff", "#f281ff"};
  // Medium
  std::string m[7] = {"#e85858", "#e8c558", "#9fe858", "#58e8b3", "#58b0e8", "#6c58e8", "#d958e8"};
  // Dark
  std::string d[7] = {"#c04040", "#c0a140", "#7fc040", "#40c091", "#408fc0", "#5340c0", "#b340c0"};
};

static Palette p() {
  static Palette ret;
  return ret;
}

struct StyleBuilder {
  std::vector<std::string> parts;
  StyleBuilder &operator<<(const std::string &part) {
    parts.push_back(part);
    return *this;
  }
  std::string ToString() {
    std::stringstream str;
    for (const auto &p : parts) {
      if (!p.empty()) {
        str << p;
        if (p != parts.back()) {
          str << ", ";
        }
      }
    }
    return str.str();
  }
};

struct Config {
  struct NodeConfig {
    bool parameters = true;
    bool literals = true;
    bool signals = true;
    bool ports = true;
    bool expressions = true;
    struct ExpandConfig {
      bool record = false;
      bool stream = false;
      bool expression = false;
    } expand;
    struct TypeConfig {
      bool clock = true;
      bool reset = true;
      bool bit = true;
      bool vector = true;
      bool record = true;
      bool stream = true;
    } types;
  } nodes;

  static Config all() {
    static Config ret;
    return ret;
  }

  static Config streams() {
    Config ret;
    ret.nodes.parameters = false;
    ret.nodes.literals = false;
    ret.nodes.signals = true;
    ret.nodes.ports = true;
    ret.nodes.expressions = false;
    ret.nodes.types.clock = false;
    ret.nodes.types.reset = false;
    ret.nodes.types.bit = false;
    ret.nodes.types.vector = false;
    ret.nodes.types.record = false;
    ret.nodes.types.stream = true;
    return ret;
  }

  bool operator()(const std::shared_ptr<Node> &node) {
    switch (node->id()) {
      case Node::PARAMETER: return nodes.parameters;
      case Node::LITERAL: return nodes.literals;
      case Node::SIGNAL: return nodes.signals;
      case Node::PORT: return nodes.ports;
      case Node::EXPRESSION: return nodes.expressions;
      case Node::ARRAY_PORT: return nodes.ports;
      case Node::ARRAY_SIGNAL: return nodes.signals;
    }
    return true;
  }
};

struct Style {
  using str = std::string;

  struct SubGraph {
    str base = "filled";
    str color = p().light;
  } subgraph;

  struct NodeGroup {
    str base = "filled";
    str color = p().lighter;
  } nodegroup;

  struct EdgeStyle {
    struct Colors {
      str stream = p().d[3];
    } color;

    str base = "penwidth=1";
    str port_to_sig = "dir=forward";
    str sig_to_port = "dir=forward";
    str port_to_port = "dir=forward";
    str stream = "penwidth=3";
    str lit = "style=dotted, arrowhead=none, arrowtail=none";
    str expr = "style=dotted, arrowhead=none, arrowtail=none";
    str clock = "shape=diamond, color=\"#000000\", penwidth=1";
    str reset = "shape=diamond, color=\"#000000\", penwidth=1";
  } edge;

  struct NodeStyle {
    struct Colors {
      str stream = p().b[3];
      str stream_border = p().d[3];
      str stream_child = p().m[3];

      str record = p().b[4];
      str record_child = p().m[4];
    } color;

    str base = "style=filled, width=0, height=0, margin=0.025";

    str port = "shape=rect";
    str signal = "shape=rect, style=\"rounded, filled\", margin=0.1";
    str parameter = "shape=note, fontsize = 8";
    str literal = "shape=plaintext, fontsize = 8";
    str expression = "shape=signature";

    str nested = "html";

    struct TypeStyle {
      str clock = assign_quotes("fillcolor", p().gray);
      str reset = assign_quotes("fillcolor", p().gray);
      str bit = assign_quotes("fillcolor", p().b[0]);
      str boolean = assign_quotes("fillcolor", p().b[1]);
      str vector = assign_quotes("fillcolor", p().b[2]);
      str stream = assign_quotes("fillcolor", p().b[3]);
      str record = assign_quotes("fillcolor", p().b[4]);
      str integer = assign_quotes("fillcolor", p().b[5]);
      str string = assign_quotes("fillcolor", p().b[6]);
    } type;
  } node;

  Config config = Config::all();

  std::string GenHTMLTableCell(const std::shared_ptr<Type> &t,
                               std::string name,
                               int level = 0);
  std::string GenDotRecordCell(const std::shared_ptr<Type> &t,
                               std::string name,
                               int level = 0);

  std::string GetLabel(const std::shared_ptr<Node> &n);
  std::string Get(const std::shared_ptr<Node> &type);

  static Style def() {
    static Style ret;
    return ret;
  }
};

struct Grapher {
  Style style;
  Config config;
  std::deque<std::shared_ptr<Edge>> drawn_edges={};

  Grapher() = default;
  explicit Grapher(Style style) : style(std::move(style)) {}
  std::string GenEdges(const std::shared_ptr<Graph> &comp, int level = 0);
  std::string GenNode(const std::shared_ptr<Node> &n, int level = 0);
  std::string GenNodes(const std::shared_ptr<Graph> &comp, Node::ID id, int level = 0, bool nogroup=false);
  std::string GenGraph(const std::shared_ptr<Graph> &graph, int level = 0);
  std::string GenFile(const std::shared_ptr<Graph> &graph, std::string path);
  std::string GenExpr(const std::shared_ptr<Node> &exp, std::string prefix = "", int level = 0);
};

std::string NodeName(const std::shared_ptr<Node> &n, std::string suffix = "");

}  // namespace dot
}  // namespace fletchgen
