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

#include "./dot.h"

#include <sstream>
#include <fstream>

#include "../edges.h"
#include "../types.h"

namespace fletchgen {
namespace dot {

static inline std::string tab(uint n) {
  return std::string(2 * n, ' ');
}

static inline std::string sanitize(std::string in) {
  std::replace(in.begin(), in.end(), ':', '_');
  return in;
}

static inline std::string stylize(const std::string &style) {
  if (!style.empty()) {
    return ", " + style;
  } else {
    return "";
  }
}

static inline std::string stylize(const std::string &attribute, const std::string &style) {
  if (!style.empty()) {
    return ", " + attribute + "=" + style;
  } else {
    return "";
  }
}

static inline std::string quotize(const std::string &attribute, std::string style) {
  if (!style.empty()) {
    return ", " + attribute + "=\"" + style + "\"";
  } else {
    return "";
  }
}

std::string Grapher::GenEdges(const std::shared_ptr<Graph> &graph, int level) {
  std::stringstream ret;

  // TODO(johanpel): this could be optimized to not take worst case O(E^2)
  for (const auto &e : GetAllEdges(graph)) {
    if (std::find(drawn_edges.begin(), drawn_edges.end(), e) == drawn_edges.end()) {
      std::stringstream str;
      // Remember we've drawn this edge
      drawn_edges.push_back(e);

      // Draw edge
      str << tab(level);
      if (IsNested(e->src->type)) {
        str << NodeName(e->src, ":cell");
      } else {
        str << NodeName(e->src);
      }
      str << " -> ";
      if (IsNested(e->dst->type)) {
        str << NodeName(e->dst, ":cell");
      } else {
        str << NodeName(e->dst);
      }

      // Set style
      str << " [";
      str << style.edge.base;

      if (e->src->type != nullptr) {
        switch (e->src->type->id) {
          case Type::STREAM: {
            str << stylize(style.edge.stream);
            str << quotize("color", style.edge.color.stream);
            break;
          }
          case Type::CLOCK: {
            str << stylize(style.edge.clock);
            break;
          }
          case Type::RESET: {
            str << stylize(style.edge.reset);
            break;
          }
          default: {
            str << stylize(style.edge.base);
            break;
          }
        }
      }

      if (e->src->IsPort() && config.nodes.ports) {
        if (e->dst->IsSignal()) {
          // Port to signal
          str << stylize(style.edge.port_to_sig);
        } else if (e->dst->IsPort()) {
          str << stylize(style.edge.port_to_port);
        }
      } else if (e->src->IsSignal() && config.nodes.signals) {
        if (e->dst->IsPort()) {
          // Signal to port
          str << stylize(style.edge.sig_to_port);
        }
      } else if (e->src->IsParameter() && config.nodes.parameters) {

      } else if (e->src->IsLiteral() && config.nodes.literals) {
        str << stylize(style.edge.lit);
      } else {
        continue;
      }
      // Generic edge
      str << "]\n";
      ret << str.str();
    }
  }
  return ret.str();
}

std::string Grapher::GenCell(const std::shared_ptr<Type> &type,
                             const std::shared_ptr<Node> &node,
                             std::string name,
                             int level) {
  std::stringstream str;
  // Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn
  if (type->Is(Type::STREAM)) {
    str << R"(<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0">)";
    {
      str << R"(<TR>)";
      {
        str << R"(<TD)";
        {
          str << R"( BGCOLOR="#81ceff">)" + name;
        }
        str << R"(</TD>)";
      }
      {
        str << R"(<TD )";
        if (level == 0) {
          str << R"( PORT=")" + NodeName(node, ":cell") + R"(")";
        }
        str << R"( BGCOLOR=")" + style.node.color.stream_child + R"(">)";
        {
          auto stream = Cast<Stream>(type);
          str << GenCell(stream->element_type(), node, stream->element_name(), level + 1);
        }
        str << R"(</TD>)";
      }
      str << R"(</TR>)";
    }
    str << R"(</TABLE>)";
  } else if (type->Is(Type::RECORD)) {
    str << R"(<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0">)";
    {
      str << R"(<TR>)";
      {
        str << R"(<TD)";
        {
          str << R"( BGCOLOR="#81ceff">)" + name;
        }
        str << R"(</TD>)";
      }
      {
        str << R"(<TD )";
        if (level == 0) {
          str << R"( PORT=")" + NodeName(node, ":cell") + R"(")";
        }
        str << R"( BGCOLOR=")" + style.node.color.stream_child + R"(">)";
        {
          str << R"(<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0">)";
          for (const auto &f : Cast<Record>(type)->fields()) {
            str << R"(<TR><TD>)";
            str << GenCell(f->type(), node, f->name(), level + 1);
            str << R"(</TD></TR>)";
          }
          str << R"(</TABLE>)";
          str << R"(</TD>)";
        }
    str << R"(</TR></TABLE>)";
  } else {
    str << name;
  }
  return str.str();
}

std::string Grapher::GenNodes(const std::shared_ptr<Graph> &graph, int level) {
  std::stringstream ret;
  for (const auto &n : graph->nodes) {
    std::stringstream str;

    // Indent
    str << tab(level);
    str << sanitize(NodeName(n));

    // Draw style
    str << " [";
    if (IsNested(n->type)) {
      str << R"(shape=none, label=<)";
      str << GenCell(n->type, n, n->name());
      str << R"(>)";
    } else {
      str << quotize("label", sanitize(n->name()));
    }

    str << stylize(style.node.base);

    if (n->IsPort() && config.nodes.ports) {
      // Port style
      str << stylize(style.node.port);
      if (n->type->Is(Type::STREAM)) {
        str << stylize(style.node.type.stream);
        str << quotize("fillcolor", style.node.color.stream);
        str << quotize("color", style.node.color.stream_border);
      } else {
        // other port styles
        if (n->type->Is(Type::CLOCK) && config.nodes.types.clock) {
          str << stylize(style.node.type.clock);
        } else if (n->type->Is(Type::RESET) && config.nodes.types.reset) {
          str << stylize(style.node.type.reset);
        } else {
          continue;
        }
      }
    } else if (n->IsSignal() && config.nodes.signals) {
      // Signal style
      str << stylize(style.node.sig);
    } else if (n->IsParameter() && config.nodes.parameters) {
      // Parameter style
      str << stylize(style.node.param);
    } else if (n->IsLiteral() && config.nodes.literals) {
      // Literal style
      str << stylize(style.node.lit);
    } else {
      continue;
    }
    str << "];\n";
    ret << str.str();
  }
  return ret.str();
}

std::string Grapher::GenGraph(const std::shared_ptr<Graph> &graph, int level) {
  std::stringstream ret;

  // (sub)graph header
  if (level == 0) {
    ret << "digraph {\n";
    level++;
  }
  ret << tab(level) << "subgraph cluster_" << sanitize(graph->name()) << " {\n";
  ret << std::string(2 * (level + 1), ' ') << "label=\"" << sanitize(graph->name()) << "\";\n";

  // Nodes
  ret << GenNodes(graph, level + 1);

  if (!graph->children.empty()) {
    ret << "\n";
  }

  // Graph children
  for (const auto &child : graph->children) {
    ret << GenGraph(child, level + 1);
  }
  ret << tab(level) << "}\n";
  if (level == 1) {
    ret << GenEdges(graph, level);
    ret << "}\n";
  }

  return ret.str();
}

std::string Grapher::GenFile(const std::shared_ptr<Graph> &graph, std::string path) {
  std::string dot = GenGraph(graph);
  std::ofstream out(path);
  out << dot;
  out.close();
  return dot;
}

std::deque<std::shared_ptr<Edge>> GetAllEdges(const std::shared_ptr<Graph> &graph) {
  std::deque<std::shared_ptr<Edge>> all_edges;

  for (const auto &n : graph->nodes) {
    auto edges = n->edges();
    for (const auto &e : edges) {
      all_edges.push_back(e);
    }
  }

  for (const auto &g : graph->children) {
    auto child_edges = GetAllEdges(g);
    all_edges.insert(all_edges.end(), child_edges.begin(), child_edges.end());
  }

  return all_edges;
}

std::string NodeName(const std::shared_ptr<Node> &n, std::string suffix) {
  std::stringstream ret;
  ret << sanitize(n->parent->name() + ":");
  if (!n->name().empty()) {
    ret << n->name();
  } else {
    if (n->IsLiteral()) {
      ret << "Anon_" + ToString(n->id) + "_" + Cast<Literal>(n)->ToValueString();
    } else {
      // TODO(johanpel): resolve this madness
      ret << "Anon_" + ToString(n->id) + "_" + std::to_string(reinterpret_cast<unsigned long>(n.get()));
    }
  }
  ret << suffix;
  return ret.str();
}

}
}
