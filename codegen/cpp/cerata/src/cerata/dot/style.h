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

#include "cerata/graph.h"
#include "cerata/node.h"

namespace cerata::dot {

/// @brief Return indent string.
inline std::string tab(uint n) {
  return std::string(2 * n, ' ');
}

/// @brief Return indent string.
inline std::string tab(int n) {
  return tab(static_cast<uint>(n));
}

/// @brief Sanitize a string for usage in DOT.
inline std::string sanitize(std::string in) {
  std::replace(in.begin(), in.end(), ':', '_');
  std::replace(in.begin(), in.end(), '-', '_');
  std::replace(in.begin(), in.end(), '"', '_');
  return in;
}

/// @brief Assign with quotes.
inline std::string awq(const std::string &attribute, const std::string &style) {
  if (!style.empty()) {
    return attribute + "=\"" + style + "\"";
  } else {
    return "";
  }
}

/// A color Palette.
struct Palette {
  int num_colors;  ///< Number of colors of this Palette.
  std::string black;  ///< Black color
  std::string white;  ///< White color
  std::string gray;  ///< Gray color
  std::string darker;  ///< Darker gray color
  std::string dark;  ///< Very dark gray color
  std::string light;  ///< Light gray color
  std::string lighter;  ///< Lighter gray color

  std::vector<std::string> b;  ///< Bright
  std::vector<std::string> m;  ///< Medium
  std::vector<std::string> d;  ///< Dark

  /// @brief Default palette
  static Palette normal();
};

/// Convenience structure to build up dot styles
struct StyleBuilder {
  std::vector<std::string> parts;  ///< Parts of the style.
  /// @brief Append a part to the style.
  StyleBuilder &operator<<(const std::string &part);
  /// @brief Generate the style string.
  std::string ToString();
};

/// DOT output configuration. Determines what Cerata constructs will be used for generation.
struct Config {
  /// Node configuration.
  struct NodeConfig {
    bool parameters = true;    ///< Show parameters.
    bool literals = true;      ///< Show literals.
    bool signals = true;       ///< Show signals.
    bool ports = true;         ///< Show ports.
    bool expressions = true;   ///< Show expressions.

    /// Expansion configuration.
    struct ExpandConfig {
      bool record = false;      ///< Expand records.
      bool stream = false;      ///< Expand streams.
      bool expression = false;  ///< Expand expressions.
    } expand;  ///< Configures what types of nodes to expand.

    /// Type configuration.
    struct TypeConfig {
      bool bit = true;      ///< Show bit types.
      bool vector = true;   ///< Show vector types.
      bool record = true;   ///< Show record types.
      bool stream = true;   ///< Show stream types.
    } types;  ///< Type configuration.
  } nodes;  ///< Node configuration.

  /// @brief Return a configuration that will generate every construct.
  static Config all();
  /// @brief Return a configuration that will generate default constructs.
  static Config normal();
  /// @brief Return a configuration that will generate onnly stream constructs.
  static Config streams();
  /// @brief Return whether a node should be generated on the DOT graph.
  bool operator()(const Node &node);
};

/**
 * @brief Dot style configuration
 */
struct Style {
  /// Short-hand for std::string.
  using str = std::string;

  /// Subgraph style.
  struct SubGraph {
    str base;   ///< Subgraph base style.
    str color;  ///< Subgraph color.
  } subgraph;   ///< Style for sub graphs.

  /// @brief Node group configuration
  struct NodeGroup {
    str base;   ///< Base style for groups.
    str color;  ///< Color for groups.
  } nodegroup;  ///< Style for group of nodes.

  /// Style for edges.
  struct EdgeStyle {
    /// Specific edge colors.
    struct Colors {
      str stream;  ///< Colors for stream edges.
    } color;   ///< Colors for specific edges.

    str base;          ///< Base style.
    str port_to_sig;   ///< Style for port-to-signal.
    str sig_to_port;   ///< Style for signal-to-port.
    str port_to_port;  ///< Style for port-to-port.
    str param;         ///< Style for parameter edges.
    str stream;        ///< Style for stream edges.
    str lit;           ///< Style for literal edges.
    str expr;          ///< Style for expressions.
  } edge;              ///< Style for edges.

  /// Node style.
  struct NodeStyle {
    /// Colors for types
    struct Colors {
      str stream;         ///< Stream node color.
      str stream_border;  ///< Stream border color.
      str stream_child;   ///< Stream child color.
      str record;         ///< Record node color.
      str record_border;  ///< Record border color.
      str record_child;   ///< Record child color.
    } color;         ///< Colors for specific nodes.
    str base;        ///< Base node style.
    str port;        ///< Style for ports.
    str signal;      ///< Style for signals.
    str parameter;   ///< Style for parameters.
    str literal;     ///< Style for literals.
    str expression;  ///< Style for expressions.
    str nested;      ///< Style for nested nodes.

    /// Styles for specific node types.
    struct TypeStyle {
      str bit;      ///< Style for bits
      str boolean;  ///< Style for booleans
      str vector;   ///< Style for vectors
      str stream;   ///< Style for streams
      str record;   ///< Style for records
      str integer;  ///< Style for integers
      str string;   ///< Style for strings
    } type;         ///< Styles for types.
  } node;           ///< Style for nodes.

  /// Configuration of what types of constructs to show or hide for this style.
  Config config;

  /// @brief Generate a HTML table cell from a type.
  std::string GenHTMLTableCell(const Type &t,
                               const std::string &name,
                               int level = 0);

  /// @brief Generate a DOT record cell from a type
  static std::string GenDotRecordCell(const Type &t,
                                      const std::string &name,
                                      int level = 0);

  /// @brief Get the label for a node.
  std::string GetLabel(const Node &n);

  /// @brief Get the style for a node
  std::string GetStyle(const Node &n);

  /// @brief Default style
  static Style normal();
};

}  // namespace cerata::dot
