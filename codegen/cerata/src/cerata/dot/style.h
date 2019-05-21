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

#include "cerata/graphs.h"
#include "cerata/nodes.h"

namespace cerata::dot {

inline std::string tab(uint n) {
  return std::string(2 * n, ' ');
}

inline std::string tab(int n) {
  return tab(static_cast<uint>(n));
}

inline std::string sanitize(std::string in) {
  std::replace(in.begin(), in.end(), ':', '_');
  std::replace(in.begin(), in.end(), '-', '_');
  std::replace(in.begin(), in.end(), '"', '_');
  return in;
}

// Assign with quotes
inline std::string awq(const std::string &attribute, const std::string &style) {
  if (!style.empty()) {
    return attribute + "=\"" + style + "\"";
  } else {
    return "";
  }
}

std::deque<std::shared_ptr<Edge>> GetAllEdges(const Graph *graph);

struct Palette {
  int num_colors;
  std::string black;
  std::string white;
  std::string gray;
  std::string darker;
  std::string dark;
  std::string light;
  std::string lighter;

  std::vector<std::string> b; // Bright
  std::vector<std::string> m; // Medium
  std::vector<std::string> d; // Dark

  // Default palette
  static Palette normal();
};

/**
 * @brief Convenience structure to build up dot styles
 */
struct StyleBuilder {
  std::vector<std::string> parts;
  StyleBuilder &operator<<(const std::string &part);
  std::string ToString();
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

  static Config all();
  static Config normal();
  static Config streams();
  bool operator()(const std::shared_ptr<Node> &node);
};

/**
 * @brief Dot style configuration
 */
struct Style {
  using str = std::string;

  /// @brief Subgraph configuration
  struct SubGraph {
    str base;
    str color;
  } subgraph;

  /// @brief Node group configuration
  struct NodeGroup {
    str base;
    str color;
  } nodegroup;

  struct EdgeStyle {
    struct Colors {
      str stream;
    } color;

    str base;
    str port_to_sig;
    str sig_to_port;
    str port_to_port;
    str param;
    str stream;
    str lit;
    str expr;
    str clock;
    str reset;
  } edge;

  /// @brief Node style configuration
  struct NodeStyle {
    /// @brief Colors for nodes
    struct Colors {
      str stream;
      str stream_border;
      str stream_child;
      str record;
      str record_border;
      str record_child;
    } color;
    str base;
    str port;
    str signal;
    str parameter;
    str literal;
    str expression;
    str nested;

    /// @brief Styles for specific node types.
    struct TypeStyle {
      str clock;
      str reset;
      str bit;
      str boolean;
      str vector;
      str stream;
      str record;
      str integer;
      str string;
    } type;
  } node;

  Config config;

  /// @brief Generate a HTML table cell from a type.
  std::string GenHTMLTableCell(const std::shared_ptr<Type> &t,
                               const std::string &name,
                               int level = 0);

  /// @brief Generate a DOT record cell from a type
  static std::string GenDotRecordCell(const std::shared_ptr<Type> &t,
                                      const std::string &name,
                                      int level = 0);

  /// @brief Get the label for a node.
  std::string GetLabel(const std::shared_ptr<Node> &n);

  /// @brief Get the style for a node
  std::string GetStyle(const std::shared_ptr<Node> &n);

  /// @brief Default style
  static Style normal();
};

}  // namespace cerata::dot
