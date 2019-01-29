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

static inline std::string tab(int n) {
  return tab(static_cast<uint>(n));
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

  for (const auto &e : GetAllEdges(graph)) {
    if (!contains(drawn_edges, e)) {
      std::stringstream str;
      // Remember we've drawn this edge
      drawn_edges.push_back(e);

      // Draw edge
      str << tab(level);
      if (IsNested(e->src->type_)) {
        str << NodeName(e->src, ":cell");
      } else {
        str << NodeName(e->src);
      }
      str << " -> ";
      if (IsNested(e->dst->type_)) {
        str << NodeName(e->dst, ":cell");
      } else {
        str << NodeName(e->dst);
      }

      // Set style
      str << " [";
      str << style.edge.base;

      switch (e->src->type_->id) {
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

std::string Grapher::GenTableCell(const std::shared_ptr<Type> &type,
                                  const std::shared_ptr<Node> &node,
                                  std::string name,
                                  int level) {
  std::stringstream str;
  // Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn
  if (type->Is(Type::STREAM)) {
    str << R"(<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0")";
    if (level == 0) {
      str << R"( PORT="cell")";
    }
    str << ">";
    str << "<TR>";
    str << "<TD";
    str << R"( BGCOLOR=")" + style.node.color.stream + R"(">)";
    str << name;
    str << "</TD>";
    str << "<TD ";
    str << R"( BGCOLOR=")" + style.node.color.stream_child + R"(">)";
    auto stream = Cast<Stream>(type);
    str << GenTableCell(stream->element_type(), node, stream->element_name(), level + 1);
    str << "</TD>";
    str << "</TR>";
    str << "</TABLE>";
  } else if (type->Is(Type::RECORD)) {
    str << R"(<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0")";
    if (level == 0) {
      str << R"( PORT="cell")";
    }
    str << ">";
    str << "<TR>";
    str << "<TD";
    str << R"( BGCOLOR=")" + style.node.color.record + R"(">)";
    str << name;
    str << "</TD>";
    str << "<TD ";
    if (level == 0) {
      str << R"( PORT="cell")";
    }
    str << R"( BGCOLOR=")" + style.node.color.stream_child + R"(">)";
    str << R"(<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0">)";
    for (const auto &f : Cast<Record>(type)->fields()) {
      str << "<TR><TD>";
      str << GenTableCell(f->type(), node, f->name(), level + 1);
      str << "</TD></TR>";
    }
    str << "</TABLE>";
    str << "</TD>";
    str << "</TR></TABLE>";
  } else {
    str << name;
  }
  return str.str();
}

std::string Grapher::GenRecordCell(const std::shared_ptr<Type> &type,
                                   const std::shared_ptr<Node> &node,
                                   std::string name,
                                   int level) {
  std::stringstream str;
  // Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn
  if (type->Is(Type::STREAM)) {
    auto stream = Cast<Stream>(type);
    if (level == 0) {
      str << "<cell>";
    }
    str << name;
    str << "|";
    str << "{";
    str << GenRecordCell(stream->element_type(), node, stream->element_name(), level + 1);
    str << "}";
  } else if (type->Is(Type::RECORD)) {
    if (level == 0) {
      str << "<cell>";
    }
    str << name;
    str << "|";
    str << "{";
    auto record_fields = Cast<Record>(type)->fields();
    for (const auto &f : record_fields) {
      str << GenRecordCell(f->type(), node, f->name(), level + 1);
      if (f != record_fields.back()) {
        str << "|";
      }
    }
    str << "}";
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
    str << NodeName(n);

    // Draw style
    str << " [";
    if (IsNested(n->type_) && config.nodes.types.expand) {
      str << "shape=none, label=<";
      str << GenTableCell(n->type_, n, n->name());
      str << ">";

      // str << R"(shape=Mrecord, label=")";
      // str << GenRecordCell(n->type, n, n->name());
      // str << R"(")";

    } else {
      str << "label=\"" + sanitize(n->name()) + "\"";
    }

    str << stylize(style.node.base);

    if (n->IsPort() && config.nodes.ports) {
      // Port style
      str << stylize(style.node.port);
      if (n->type_->Is(Type::STREAM)) {
        str << stylize(style.node.type.stream);
        str << quotize("fillcolor", style.node.color.stream);
        str << quotize("color", style.node.color.stream_border);
      } else {
        // other port styles
        if (n->type_->Is(Type::CLOCK) && config.nodes.types.clock) {
          str << stylize(style.node.type.clock);
        } else if (n->type_->Is(Type::RESET) && config.nodes.types.reset) {
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

    // Preferably we would want to use splines=ortho, but dot is bugged when using html tables w.r.t. arrow directions
    // resulting from this setting
    ret << tab(level + 1) << "splines=ortho;\n";
    ret << tab(level + 1) << "rankdir=LR;\n";
  } else {
    ret << tab(level) << "subgraph cluster_" << sanitize(graph->name()) << " {\n";
    ret << tab(level + 1) << "label=\"" << sanitize(graph->name()) << "\";\n";
  }

  // Nodes
  ret << GenNodes(graph, level + 1);

  if (!graph->children.empty()) {
    ret << "\n";
  }

  // Graph children
  for (const auto &child : graph->children) {
    ret << GenGraph(child, level + 1);
  }
  if (level == 0) {
    ret << GenEdges(graph, level + 1);
  }
  ret << tab(level) << "}\n";

  return ret.str();
}

std::string Grapher::GenFile(const std::shared_ptr<Graph> &graph, std::string path) {
  std::string dot = GenGraph(graph);
  std::ofstream out(path);
  out << dot;
  out.close();
  return dot;
}

static std::string ToHex(std::shared_ptr<Node> n) {
  std::stringstream ret;
  ret << std::hex << reinterpret_cast<uint64_t>(n.get());
  return ret.str();
}

std::string Grapher::GenExpr(const std::shared_ptr<Node> &node, std::string prefix, int level) {
  std::stringstream str;

  std::string node_id;
  if (!prefix.empty()) {
    node_id = prefix + "_";
  }
  node_id += ToHex(node);

  if (level == 0) {
    str << "graph {\n";
  }

  auto n_expr = Cast<Expression>(node);
  str << "\"" + node_id + "\" [label=\"" + sanitize(node->name()) + "\" ";
  if (level == 0) {
    str << ", color=red";
  }
  str << "];\n";
  if (n_expr) {
    auto left_node_id = node_id + "_" + ToHex((*n_expr)->lhs);
    auto right_node_id = node_id + "_" + ToHex((*n_expr)->rhs);
    str << "\"" + node_id + "\" -- \"" + left_node_id + "\"\n";
    str << "\"" + node_id + "\" -- \"" + right_node_id + "\"\n";
    str << GenExpr((*n_expr)->lhs, node_id, level + 1);
    str << GenExpr((*n_expr)->rhs, node_id, level + 1);
  }
  if (level == 0) {
    str << "}\n";
  }
  return str.str();
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
  if (n->parent_) {
    ret << (*n->parent_)->name() + ":";
  }
  if (!n->name().empty()) {
    ret << n->name();
  } else {
    auto lit = Cast<Literal>(n);
    if (lit) {
      ret << "Anon_" + ToString(n->id_) + "_" + (*lit)->ToString();
    } else {
      // TODO(johanpel): resolve this madness
      ret << "Anon_" + ToString(n->id_) + "_" + std::to_string(reinterpret_cast<unsigned long>(n.get()));
    }
  }
  return sanitize(ret.str()) + suffix;
}

}
}
