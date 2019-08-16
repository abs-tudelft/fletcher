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

#include "cerata/dot/dot.h"

#include <sstream>

#include "cerata/logging.h"
#include "cerata/edge.h"
#include "cerata/type.h"
#include "cerata/output.h"
#include "cerata/utils.h"
#include "cerata/node.h"
#include "cerata/expression.h"

namespace cerata::dot {

void DOTOutputGenerator::Generate() {
  CreateDir(root_dir_ + "/" + subdir());
  cerata::dot::Grapher dot;
  for (const auto &o : outputs_) {
    if (o.comp != nullptr) {
      CERATA_LOG(INFO, "DOT: Generating output for Graph: " + o.comp->name());
      dot.GenFile(*o.comp, root_dir_ + "/" + subdir() + "/" + o.comp->name() + ".dot");
    }
  }
}

static std::string ToHex(const Node &n) {
  std::stringstream ret;
  ret << std::hex << reinterpret_cast<uint64_t>(&n);
  return ret.str();
}

std::string Grapher::GenEdges(const Graph &graph, int level) {
  std::stringstream ret;
  auto all_edges = GetAllEdges(graph);
  int ei = 0;
  for (const auto &e : all_edges) {
    if (!Contains(drawn_edges, e)) {
      // Remember we've drawn this edge
      drawn_edges.push_back(e);

      // Check if edge is complete
      auto dst = e->dst();
      auto src = e->src();
      // Don't draw literals
      if (dst->IsLiteral() || src->IsLiteral()) {
        continue;
      }

      // Draw edge
      ret << tab(level);
      if (src->IsExpression() && style.config.nodes.expand.expression) {
        auto srcname = ToHex(*src);
        ret << "\"" + srcname + "\"";
      } else {
        auto srcname = NodeName(*src);
        ret << srcname;
      }
      ret << " -> ";
      ret << NodeName(*dst);

      // Set style
      StyleBuilder sb;
      ret << " [";
      switch (src->type()->id()) {
        case Type::STREAM: {
          sb << style.edge.stream;
          sb << awq("color", style.edge.color.stream);
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

      // Put array index label
      if (src->array() && !dst->array()) {
        sb << "label=\"" + std::to_string((*src->array())->IndexOf(*src)) + "\"";
      }
      if (!src->array() && dst->array()) {
        sb << "label=\"" + std::to_string((*dst->array())->IndexOf(*dst)) + "\"";
      }
      if (src->array() && dst->array()) {
        sb << "label=\"" + std::to_string((*src->array())->IndexOf(*src)) + " to "
            + std::to_string((*dst->array())->IndexOf(*dst)) + "\"";
      }

      if ((src->IsPort()) && style.config.nodes.ports) {
        if (dst->IsSignal()) {
          // Port to signal
          sb << style.edge.port_to_sig;
        } else if (dst->IsPort()) {
          sb << style.edge.port_to_port;
        }
      } else if (src->IsSignal() && style.config.nodes.signals) {
        if (dst->IsPort()) {
          // Signal to port
          sb << style.edge.sig_to_port;
        }
      } else if (src->IsParameter() && style.config.nodes.parameters) {
        sb << style.edge.param;
      } else if (src->IsLiteral() && style.config.nodes.literals) {
        sb << style.edge.lit;
      } else if (src->IsExpression() && style.config.nodes.expressions) {
        sb << style.edge.expr;
        if (style.config.nodes.expand.expression) {
          sb << "lhead=\"cluster_" + NodeName(*src) + "\"";
        }
      } else {
        continue;
      }
      ret << sb.ToString();
      // Generic edge
      ret << "]\n";
    }
  }
  ei++;

  return ret.str();
}

std::string Style::GenHTMLTableCell(const Type &t,
                                    const std::string &name,
                                    int level) {
  std::stringstream str;
  // Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn
  if (t.Is(Type::STREAM)) {
    auto stream = dynamic_cast<const Stream &>(t);
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
    str << GenHTMLTableCell(*stream.element_type(), stream.element_name(), level + 1);
    str << "</TD>";
    str << "</TR>";
    str << "</TABLE>";
  } else if (t.Is(Type::RECORD)) {
    auto rec = dynamic_cast<const Record &>(t);
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
    for (const auto &f : rec.fields()) {
      str << "<TR><TD>";
      str << GenHTMLTableCell(*f->type(), f->name(), level + 1);
      str << "</TD></TR>";
    }
    str << "</TABLE>";
    str << "</TD>";
    str << "</TR></TABLE>";
  } else {
    str << name;
    if (t.Is(Type::VECTOR)) {
      auto vec = dynamic_cast<const Vector &>(t);
      auto width = vec.width();
      if (width) {
        str << "[" + width.value()->ToString() + "]";
      } else {
        str << "[..]";
      }
    }
  }
  return str.str();
}

std::string Style::GenDotRecordCell(const Type &t,
                                    const std::string &name,
                                    int level) {
  std::stringstream str;
  // Ph'nglui mglw'nafh Cthulhu R'lyeh wgah'nagl fhtagn
  if (t.Is(Type::STREAM)) {
    auto stream = dynamic_cast<const Stream &>(t);
    if (level == 0) {
      str << "<cell>";
    }
    str << name;
    str << "|";
    str << "{";
    str << GenDotRecordCell(*stream.element_type(), stream.element_name(), level + 1);
    str << "}";
  } else if (t.Is(Type::RECORD)) {
    auto rec = dynamic_cast<const Record &>(t);
    if (level == 0) {
      str << "<cell>";
    }
    str << name;
    str << "|";
    str << "{";
    auto record_fields = rec.fields();
    for (const auto &f : record_fields) {
      str << GenDotRecordCell(*f->type(), f->name(), level + 1);
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

std::string Grapher::GenNode(const Node &n, int level) {
  std::stringstream str;
  if (n.IsExpression() && style.config.nodes.expand.expression) {
    str << GenExpr(n);
  } else {
    // Indent
    str << tab(level);
    str << NodeName(n);
    // Draw style
    str << " [";
    str << style.GetStyle(n);
    str << "];\n";
  }
  return str.str();
}

std::string Grapher::GenNodes(const Graph &graph, Node::NodeID id, int level, bool nogroup) {
  std::stringstream ret;
  auto nodes = graph.GetNodesOfType(id);
  auto arrays = graph.GetArraysOfType(id);
  if (!nodes.empty() || !arrays.empty()) {
    if (!nogroup) {
      ret << tab(level) << "subgraph cluster_" << sanitize(graph.name()) + "_" + ToString(id) << " {\n";
      // ret << tab(level + 1) << "label=\"" << ToString(id) << "s\";\n";
      ret << tab(level + 1) << "rankdir=LR;\n";
      ret << tab(level + 1) << "label=\"\";\n";
      ret << tab(level + 1) << "style=" + style.nodegroup.base + ";\n";
      ret << tab(level + 1) << "color=\"" + style.nodegroup.color + "\";\n";
    }
    for (const auto &n : nodes) {
      ret << GenNode(*n, level + nogroup + 1);
    }
    for (const auto &a : arrays) {
      ret << GenNode(*a->base(), level + nogroup + 1);
    }
    if (!nogroup) {
      ret << tab(level) << "}\n";
    }
  }
  return ret.str();
}

std::string Grapher::GenGraph(const Graph &graph, int level) {
  std::stringstream ret;

  // (sub)graph header
  if (level == 0) {
    ret << "digraph {\n";

    // Preferably we would want to use splines=ortho, but dot is bugged when using html tables w.r.t. arrow directions
    // resulting from this setting
    ret << tab(level + 1) << "splines=ortho;\n";
    ret << tab(level + 1) << "rankdir=LR;\n";
  } else {
    ret << tab(level) << "subgraph cluster_" << sanitize(graph.name()) << " {\n";
    ret << tab(level + 1) << "rankdir=TB;\n";
    ret << tab(level + 1) << "style=" + style.subgraph.base + ";\n";
    ret << tab(level + 1) << "color=\"" + style.subgraph.color + "\";\n";
    ret << tab(level + 1) << "label=\"" << sanitize(graph.name()) << "\";\n";
  }

  // Nodes
  if (style.config.nodes.expressions)
    ret << GenNodes(graph, Node::NodeID::EXPRESSION, level + 1);

  // if (config.nodes.literals)
  //   ret << GenNodes(graph, Node::LITERAL, level + 1);

  if (style.config.nodes.parameters)
    ret << GenNodes(graph, Node::NodeID::PARAMETER, level + 1);

  if (style.config.nodes.ports)
    ret << GenNodes(graph, Node::NodeID::PORT, level + 1);

  if (style.config.nodes.signals)
    ret << GenNodes(graph, Node::NodeID::SIGNAL, level + 1, true);

  if (graph.IsComponent()) {
    auto &comp = dynamic_cast<const Component &>(graph);
    if (!comp.children().empty()) {
      ret << "\n";
    }


    // Graph children
    for (const auto &child : comp.children()) {
      ret << GenGraph(*child, level + 1);
    }
    if (level == 0) {
      ret << GenEdges(graph, level + 1);
    }
  }

  ret << tab(level) << "}\n";

  return ret.str();
}

std::string Grapher::GenFile(const Graph &graph, const std::string &path) {
  std::string dot = GenGraph(graph);
  std::ofstream out(path);
  out << dot;
  out.close();
  return dot;
}

std::string Grapher::GenExpr(const Node &node, const std::string &prefix, int level) {
  std::stringstream str;

  std::string node_id;
  if (!prefix.empty()) {
    node_id = prefix + "_";
  }
  node_id += ToHex(node);

  if (level == 0) {
    str << "subgraph cluster_" + NodeName(node) + " {\n";
  }

  str << "\"" + node_id + "\" [label=\"" + sanitize(node.name()) + "\" ";
  if (level == 0) {
    str << ", color=red";
  }
  str << "];\n";
  if (node.IsExpression()) {
    auto expr = dynamic_cast<const Expression &>(node);
    auto left_node_id = node_id + "_" + ToHex(*expr.lhs());
    auto right_node_id = node_id + "_" + ToHex(*expr.rhs());
    str << "\"" + node_id + "\" -> \"" + left_node_id + "\"\n";
    str << "\"" + node_id + "\" -> \"" + right_node_id + "\"\n";
    str << GenExpr(*expr.lhs(), node_id, level + 1);
    str << GenExpr(*expr.rhs(), node_id, level + 1);
  }
  if (level == 0) {
    str << "}\n";
  }
  return str.str();
}

std::string NodeName(const Node &node, const std::string &suffix) {
  std::stringstream ret;
  if (node.parent()) {
    auto name = (*node.parent())->name();
    ret << name + ":" + ToString(node.node_id()) + ":";
  }
  if (node.IsExpression()) {
    ret << "Anon_" + ToString(node.node_id()) + "_" + ToHex(node);
  } else if (!node.name().empty()) {
    ret << node.name();
  }

  return sanitize(ret.str()) + suffix;
}

}  // namespace cerata::dot
