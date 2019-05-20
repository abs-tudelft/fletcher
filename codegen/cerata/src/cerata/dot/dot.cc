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
#include <fstream>

#include "cerata/logging.h"
#include "cerata/edges.h"
#include "cerata/types.h"
#include "cerata/output.h"
#include "cerata/utils.h"

namespace cerata::dot {

void DOTOutputGenerator::Generate() {
  CreateDir(subdir());
  cerata::dot::Grapher dot;
  for (const auto &o : outputs_) {
    if (o.graph != nullptr) {
      CERATA_LOG(INFO, "DOT: Generating output for Graph: " + o.graph->name());
      dot.GenFile(o.graph, subdir() + "/" + o.graph->name() + ".dot");
    }
  }
}

static std::string ToHex(const std::shared_ptr<Node> &n) {
  std::stringstream ret;
  ret << std::hex << reinterpret_cast<uint64_t>(n.get());
  return ret.str();
}

std::string Grapher::GenEdges(const Graph *graph, int level) {
  std::stringstream ret;
  auto all_edges = GetAllEdges(graph);
  int ei = 0;
  for (const auto &e : all_edges) {
    if (!contains(drawn_edges, e)) {
      // Remember we've drawn this edge
      drawn_edges.push_back(e);

      // Check if edge is complete
      if (e->IsComplete()) {
        auto dst = *e->dst;
        auto src = *e->src;
        // Don't draw literals
        if (dst->IsLiteral() || src->IsLiteral()) {
          continue;
        }

        // Draw edge
        ret << tab(level);
        if (src->IsExpression() && config.nodes.expand.expression) {
          auto srcname = ToHex(src);
          ret << "\"" + srcname + "\"";
        } else {
          auto srcname = NodeName(src);
          ret << srcname;
        }
        ret << " -> ";
        ret << NodeName(dst);

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
          sb << "label=\"" + std::to_string((*src->array())->IndexOf(src)) + "\"";
        }
        if (!src->array() && dst->array()) {
          sb << "label=\"" + std::to_string((*dst->array())->IndexOf(dst)) + "\"";
        }
        if (src->array() && dst->array()) {
          sb << "label=\"" + std::to_string((*src->array())->IndexOf(src)) + " to "
              + std::to_string((*dst->array())->IndexOf(dst)) + "\"";
        }

        if ((src->IsPort()) && config.nodes.ports) {
          if (dst->IsSignal()) {
            // Port to signal
            sb << style.edge.port_to_sig;
          } else if (dst->IsPort()) {
            sb << style.edge.port_to_port;
          }
        } else if (src->IsSignal() && config.nodes.signals) {
          if (dst->IsPort()) {
            // Signal to port
            sb << style.edge.sig_to_port;
          }
        } else if (src->IsParameter() && config.nodes.parameters) {
          sb << style.edge.param;
        } else if (src->IsLiteral() && config.nodes.literals) {
          sb << style.edge.lit;
        } else if (src->IsExpression() && config.nodes.expressions) {
          sb << style.edge.expr;
          if (config.nodes.expand.expression) {
            sb << "lhead=\"cluster_" + NodeName(src) + "\"";
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
  }
  return ret.str();
}

std::string Style::GenHTMLTableCell(const std::shared_ptr<Type> &t,
                                    const std::string &name,
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
      auto width = (*vec)->width();
      if (width) {
        str << "[" + (*width)->ToString() + "]";
      } else {
        str << "[..]";
      }
    }
  }
  return str.str();
}

std::string Style::GenDotRecordCell(const std::shared_ptr<Type> &t,
                                    const std::string &name,
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
  if (n->IsExpression() && config.nodes.expand.expression) {
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

std::string Grapher::GenNodes(const Graph *graph, Node::NodeID id, int level, bool nogroup) {
  std::stringstream ret;
  auto nodes = graph->GetNodesOfType(id);
  auto arrays = graph->GetArraysOfType(id);
  if (!nodes.empty() || !arrays.empty()) {
    if (!nogroup) {
      ret << tab(level) << "subgraph cluster_" << sanitize(graph->name()) + "_" + ToString(id) << " {\n";
      // ret << tab(level + 1) << "label=\"" << ToString(id) << "s\";\n";
      ret << tab(level + 1) << "rankdir=LR;\n";
      ret << tab(level + 1) << "label=\"\";\n";
      ret << tab(level + 1) << "style=" + style.nodegroup.base + ";\n";
      ret << tab(level + 1) << "color=\"" + style.nodegroup.color + "\";\n";
    }
    for (const auto &n : nodes) {
      ret << GenNode(n, level + nogroup + 1);
    }
    for (const auto &a : arrays) {
      ret << GenNode(a->base(), level + nogroup + 1);
    }
    if (!nogroup) {
      ret << tab(level) << "}\n";
    }
  }
  return ret.str();
}

std::string Grapher::GenGraph(const Graph *graph, int level) {
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
  if (config.nodes.expressions)
    ret << GenNodes(graph, Node::EXPRESSION, level + 1);

  // if (config.nodes.literals)
  //   ret << GenNodes(graph, Node::LITERAL, level + 1);

  if (config.nodes.parameters)
    ret << GenNodes(graph, Node::PARAMETER, level + 1);

  if (config.nodes.ports)
    ret << GenNodes(graph, Node::PORT, level + 1);

  if (config.nodes.signals)
    ret << GenNodes(graph, Node::SIGNAL, level + 1, true);

  if (!graph->children.empty()) {
    ret << "\n";
  }

  // Graph children
  for (const auto &child : graph->children) {
    ret << GenGraph(child.get(), level + 1);
  }
  if (level == 0) {
    ret << GenEdges(graph, level + 1);
  }
  ret << tab(level) << "}\n";

  return ret.str();
}

std::string Grapher::GenFile(const std::shared_ptr<Graph> &graph, const std::string &path) {
  std::string dot = GenGraph(graph.get());
  std::ofstream out(path);
  out << dot;
  out.close();
  return dot;
}

std::string Grapher::GenExpr(const std::shared_ptr<Node> &node, const std::string &prefix, int level) {
  std::stringstream str;

  std::string node_id;
  if (!prefix.empty()) {
    node_id = prefix + "_";
  }
  node_id += ToHex(node);

  if (level == 0) {
    str << "subgraph cluster_" + NodeName(node) + " {\n";
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
    str << "\"" + node_id + "\" -> \"" + left_node_id + "\"\n";
    str << "\"" + node_id + "\" -> \"" + right_node_id + "\"\n";
    str << GenExpr((*n_expr)->lhs, node_id, level + 1);
    str << GenExpr((*n_expr)->rhs, node_id, level + 1);
  }
  if (level == 0) {
    str << "}\n";
  }
  return str.str();
}

std::deque<std::shared_ptr<Edge>> GetAllEdges(const Graph *graph) {
  std::deque<std::shared_ptr<Edge>> all_edges;

  // Get all normal nodes
  for (const auto &node : graph->GetAll<Node>()) {
    auto out_edges = node->sinks();
    for (const auto &e : out_edges) {
      all_edges.push_back(e);
    }
    auto in_edges = node->sources();
    for (const auto &e : in_edges) {
      all_edges.push_back(e);
    }
  }

  for (const auto &array : graph->GetAll<NodeArray>()) {
    for (const auto &node : array->nodes()) {
      auto out_edges = node->sinks();
      for (const auto &e : out_edges) {
        all_edges.push_back(e);
      }
      auto in_edges = node->sources();
      for (const auto &e : in_edges) {
        all_edges.push_back(e);
      }
    }
  }

  for (const auto &g : graph->children) {
    auto child_edges = GetAllEdges(g.get());
    all_edges.insert(all_edges.end(), child_edges.begin(), child_edges.end());
  }

  return all_edges;
}

std::string NodeName(const std::shared_ptr<Node> &node, const std::string &suffix) {
  std::stringstream ret;
  if (node->parent()) {
    auto name = (*node->parent())->name();
    ret << name + ":" + ToString(node->node_id()) + ":";
  }
  if (node->IsExpression()) {
    ret << "Anon_" + ToString(node->node_id()) + "_" + ToHex(node);
  } else if (!node->name().empty()) {
    ret << node->name();
  }

  return sanitize(ret.str()) + suffix;
}

}  // namespace cerata::dot
