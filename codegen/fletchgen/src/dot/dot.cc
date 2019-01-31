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

std::string Grapher::GenEdges(const std::shared_ptr<Graph> &graph, int level) {
  std::stringstream ret;

  for (const auto &e : GetAllEdges(graph)) {
    if (!contains(drawn_edges, e)) {
      StyleBuilder sb;
      // Remember we've drawn this edge
      drawn_edges.push_back(e);

      // Draw edge
      ret << tab(level);
      // if (IsNested(e->src->type())) {
      //   ret << NodeName(e->src, ":cell");
      // } else {
      ret << NodeName(e->src);
      // }
      ret << " -> ";
      // if (IsNested(e->dst->type())) {
      //   ret << NodeName(e->dst, ":cell");
      // } else {
      ret << NodeName(e->dst);
      // }

      // Set style
      ret << " [";
      sb << style.edge.base;

      switch (e->src->type()->id()) {
        case Type::STREAM: {
          sb << style.edge.stream;
          sb << assign_quotes("color", style.edge.color.stream);
          break;
        }
        case Type::CLOCK: {
          sb << style.edge.clock;
          break;
        }
        case Type::RESET: {
          sb << style.edge.reset;
          break;
        }
        default: {
          sb << style.edge.base;
          break;
        }
      }

      if (e->src->IsPort() && config.nodes.ports) {
        if (e->dst->IsSignal()) {
          // Port to signal
          sb << style.edge.port_to_sig;
        } else if (e->dst->IsPort()) {
          sb << style.edge.port_to_port;
        }
      } else if (e->src->IsSignal() && config.nodes.signals) {
        if (e->dst->IsPort()) {
          // Signal to port
          sb << style.edge.sig_to_port;
        }
      } else if (e->src->IsParameter() && config.nodes.parameters) {
      } else if (e->src->IsLiteral() && config.nodes.literals) {
        sb << style.edge.lit;
      } else {
        continue;
      }
      ret << sb.ToString();
      // Generic edge
      ret << "]\n";
    }
  }
  return ret.str();
}

std::string Style::GenHTMLTableCell(const std::shared_ptr<Type> &t,
                                    std::string name,
                                    int level) {
  std::stringstream str;
  auto stream = Cast<Stream>(t);
  auto rec = Cast<Record>(t);
  // Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn
  if (stream) {
    str << R"(<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0")";
    if (level == 0) {
      str << R"( PORT="cell")";
    }
    str << ">";
    str << "<TR>";
    str << "<TD";
    str << R"( BGCOLOR=")" + node.color.stream + R"(">)";
    str << name;
    str << "</TD>";
    str << "<TD ";
    str << R"( BGCOLOR=")" + node.color.stream_child + R"(">)";
    str << GenHTMLTableCell((*stream)->element_type(), (*stream)->element_name(), level + 1);
    str << "</TD>";
    str << "</TR>";
    str << "</TABLE>";
  } else if (rec) {
    str << R"(<TABLE BORDER="1" CELLBORDER="0" CELLSPACING="0")";
    if (level == 0) {
      str << R"( PORT="cell")";
    }
    str << ">";
    str << "<TR>";
    str << "<TD";
    str << R"( BGCOLOR=")" + node.color.record + R"(">)";
    str << name;
    str << "</TD>";
    str << "<TD ";
    if (level == 0) {
      str << R"( PORT="cell")";
    }
    str << R"( BGCOLOR=")" + node.color.record_child + R"(">)";
    str << R"(<TABLE BORDER="0" CELLBORDER="0" CELLSPACING="0">)";
    for (const auto &f : (*rec)->fields()) {
      str << "<TR><TD>";
      str << GenHTMLTableCell(f->type(), f->name(), level + 1);
      str << "</TD></TR>";
    }
    str << "</TABLE>";
    str << "</TD>";
    str << "</TR></TABLE>";
  } else {
    str << name;
    auto vec = Cast<Vector>(t);
    if (vec) {
      str << "[" + (*vec)->width()->ToString() + "]";
    }
  }
  return str.str();
}

std::string Style::GenDotRecordCell(const std::shared_ptr<Type> &t,
                                    std::string name,
                                    int level) {
  std::stringstream str;
  // Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn
  auto stream = Cast<Stream>(t);
  auto rec = Cast<Record>(t);
  if (stream) {
    if (level == 0) {
      str << "<cell>";
    }
    str << name;
    str << "|";
    str << "{";
    str << GenDotRecordCell((*stream)->element_type(), (*stream)->element_name(), level + 1);
    str << "}";
  } else if (rec) {
    if (level == 0) {
      str << "<cell>";
    }
    str << name;
    str << "|";
    str << "{";
    auto record_fields = (*rec)->fields();
    for (const auto &f : record_fields) {
      str << GenDotRecordCell(f->type(), f->name(), level + 1);
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

std::string Grapher::GenNode(const std::shared_ptr<Node> &n, int level) {
  std::stringstream str;
  // Indent
  str << tab(level);
  str << NodeName(n);
  // Draw style
  str << " [";
  str << style.Get(n);
  str << "];\n";
  return str.str();
}

std::string Grapher::GenNodes(const std::shared_ptr<Graph> &graph, Node::ID id, int level, bool nogroup) {
  std::stringstream ret;
  auto nodes = graph->GetNodesOfType(id);
  if (!nodes.empty()) {
    if (!nogroup) {
      ret << tab(level) << "subgraph cluster_" << sanitize(graph->name()) + "_" + ToString(id) << " {\n";
      // ret << tab(level + 1) << "label=\"" << ToString(id) << "s\";\n";
      ret << tab(level + 1) << "rankdir=LR;\n";
      ret << tab(level + 1) << "label=\"\";\n";
      ret << tab(level + 1) << "style=" + style.nodegroup.base + ";\n";
      ret << tab(level + 1) << "color=\"" + style.nodegroup.color + "\";\n";
    }
    for (const auto &n : nodes) {
      ret << GenNode(n, level + nogroup);
    }
    if (!nogroup) {
      ret << tab(level) << "}\n";
    }
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
    ret << tab(level + 1) << "rankdir=TB;\n";
    ret << tab(level + 1) << "style=" + style.subgraph.base + ";\n";
    ret << tab(level + 1) << "color=\"" + style.subgraph.color + "\";\n";
    ret << tab(level + 1) << "label=\"" << sanitize(graph->name()) << "\";\n";
  }

  // Nodes
  ret << GenNodes(graph, Node::LITERAL, level + 1);
  ret << GenNodes(graph, Node::PARAMETER, level + 1);
  ret << GenNodes(graph, Node::PORT, level + 1);
  ret << GenNodes(graph, Node::SIGNAL, level + 1, true);

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

static std::string ToHex(const std::shared_ptr<Node> &n) {
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
  if (n->parent()) {
    auto name = (*n->parent())->name();
    ret << name + ":" + ToString(n->id()) + ":";
  }
  if (!n->name().empty()) {
    ret << n->name();
  } else {
    auto lit = Cast<Literal>(n);
    if (lit) {
      ret << "Anon_" + ToString(n->id()) + "_" + (*lit)->ToString();
    } else {
      // TODO(johanpel): resolve this madness
      ret << "Anon_" + ToString(n->id()) + "_" + ToHex(n);
    }
  }
  return sanitize(ret.str()) + suffix;
}

std::string Style::Get(const std::shared_ptr<Node> &n) {
  StyleBuilder str;

  str << node.base;

  // Add label
  switch (n->type()->id()) {
    case Type::RECORD: str << GetLabel(n);
      break;
    case Type::STREAM: str << GetLabel(n);
      break;
    case Type::CLOCK: str << node.type.clock;
      str << assign_quotes("label", sanitize(n->name()));
      break;
    case Type::RESET: str << node.type.reset;
      str << assign_quotes("label", sanitize(n->name()));
      break;
    case Type::VECTOR: str << node.type.vector;
      str << assign_quotes("label", sanitize(n->name()));
      break;
    case Type::BIT:str << node.type.bit;
      str << assign_quotes("label", sanitize(n->name()));
      break;
    case Type::NATURAL:str << node.type.natural;
      str << assign_quotes("label", sanitize(n->name()));
      break;
    case Type::STRING:str << node.type.string;
      str << assign_quotes("label", sanitize(n->name()));
      break;
    case Type::BOOLEAN:str << node.type.boolean;
      str << assign_quotes("label", sanitize(n->name()));
      break;
    default:str << assign_quotes("label", sanitize(n->name()));
      break;
  }

  // Add other style
  switch (n->id()) {
    case Node::PORT: str << node.port;
      break;
    case Node::SIGNAL:str << node.signal;
      break;
    case Node::PARAMETER:str << node.parameter;
      break;
    case Node::LITERAL:str << node.literal;
      break;
    case Node::EXPRESSION:str << node.expression;
      break;
  }

  return str.ToString();
}

std::string Style::GetLabel(const std::shared_ptr<Node> &n) {
  StyleBuilder sb;
  if (n->type()->Is(Type::STREAM)) {
    if (config.nodes.expand.stream) {
      sb << assign_quotes("color", node.color.stream_child);
    } else {
      sb << node.type.stream;
    }
  } else if (n->type()->Is(Type::RECORD)) {
    if (config.nodes.expand.record) {
      sb << assign_quotes("color", node.color.record_child);
    } else {
      sb << node.type.record;
    }
  }

  std::stringstream str;
  if (IsNested(n->type())) {
    str << "label=<";
    if (node.nested == "html") {
      str << GenHTMLTableCell(n->type(), n->name());
    } else {
      str << GenDotRecordCell(n->type(), n->name());
    }
    str << ">";
  } else {
    str << "label=\"" + sanitize(n->name()) + "\"";
  }
  sb << str.str();

  return sb.ToString();
}

}  // namespace dot
}  // namespace fletchgen
