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

#include "cerata/dot/style.h"

#include <string>
#include <sstream>

#include "cerata/api.h"

namespace cerata::dot {

Style Style::normal() {
  static Style ret;

  ret.config = Config::normal();

  ret.subgraph.base = "filled";
  ret.subgraph.color = Palette::normal().light;

  ret.nodegroup.base = "filled";
  ret.nodegroup.color = Palette::normal().lighter;

  ret.edge.color.stream = Palette::normal().d[3];

  ret.edge.base = "penwidth=1";
  ret.edge.port_to_sig = "dir=forward";
  ret.edge.sig_to_port = "dir=forward";
  ret.edge.port_to_port = "dir=forward";
  ret.edge.param = "style=dotted, arrowhead=none, arrowtail=none";
  ret.edge.stream = "penwidth=3";
  ret.edge.lit = "style=dotted, arrowhead=none, arrowtail=none";
  ret.edge.expr = "style=dotted, arrowhead=none, arrowtail=none";

  ret.node.color.stream = Palette::normal().b[3];
  ret.node.color.stream_border = Palette::normal().d[3];
  ret.node.color.stream_child = Palette::normal().m[3];

  ret.node.color.record = Palette::normal().b[4];
  ret.node.color.record_border = Palette::normal().d[4];
  ret.node.color.record_child = Palette::normal().m[4];

  ret.node.base = "style=filled, width=0, height=0, margin=0.025";

  ret.node.port = "shape=rect";
  ret.node.signal = "shape=ellipse, margin=-0.2";
  ret.node.parameter = "shape=note, fontsize = 8";
  ret.node.literal = "shape=plaintext, fontsize = 8";
  ret.node.expression = "shape=signature";

  ret.node.nested = "html";

  ret.node.type.bit = awq("fillcolor", Palette::normal().b[0]);
  ret.node.type.boolean = awq("fillcolor", Palette::normal().b[1]);
  ret.node.type.vector = awq("fillcolor", Palette::normal().b[2]);
  ret.node.type.stream = awq("fillcolor", Palette::normal().b[3]);
  ret.node.type.record = awq("fillcolor", Palette::normal().b[4]);
  ret.node.type.integer = awq("fillcolor", Palette::normal().b[5]);
  ret.node.type.string = awq("fillcolor", Palette::normal().b[6]);

  return ret;
}

std::string StyleBuilder::ToString() {
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

StyleBuilder &StyleBuilder::operator<<(const std::string &part) {
  parts.push_back(part);
  return *this;
}

bool Config::operator()(const Node &node) {
  switch (node.node_id()) {
    case Node::NodeID::PARAMETER: return nodes.parameters;
    case Node::NodeID::LITERAL: return nodes.literals;
    case Node::NodeID::SIGNAL: return nodes.signals;
    case Node::NodeID::PORT: return nodes.ports;
    case Node::NodeID::EXPRESSION: return nodes.expressions;
  }
  return true;
}

Config Config::streams() {
  static Config ret;
  ret.nodes.parameters = false;
  ret.nodes.literals = false;
  ret.nodes.signals = true;
  ret.nodes.ports = true;
  ret.nodes.expressions = false;
  ret.nodes.types.bit = false;
  ret.nodes.types.vector = false;
  ret.nodes.types.record = false;
  ret.nodes.types.stream = true;
  return ret;
}

Config Config::normal() {
  static Config ret;
  ret.nodes.parameters = false;
  ret.nodes.literals = false;
  ret.nodes.signals = true;
  ret.nodes.ports = true;
  ret.nodes.expressions = false;

  ret.nodes.expand.record = false;
  ret.nodes.expand.stream = false;
  ret.nodes.expand.expression = false;

  ret.nodes.types.bit = true;
  ret.nodes.types.vector = true;
  ret.nodes.types.record = true;
  ret.nodes.types.stream = true;

  return ret;
}

Config Config::all() {
  static Config ret;

  ret.nodes.parameters = true;
  ret.nodes.literals = true;
  ret.nodes.signals = true;
  ret.nodes.ports = true;
  ret.nodes.expressions = true;

  ret.nodes.expand.record = true;
  ret.nodes.expand.stream = true;
  ret.nodes.expand.expression = true;

  ret.nodes.types.bit = true;
  ret.nodes.types.vector = true;
  ret.nodes.types.record = true;
  ret.nodes.types.stream = true;

  return ret;
}

Palette Palette::normal() {
  static Palette ret;
  ret.black = "#000000";
  ret.white = "#ffffff";
  ret.gray = "#A0A0A0";
  ret.dark = "#808080";
  ret.darker = "#404040";
  ret.light = "#D0D0D0";
  ret.lighter = "#E0E0E0";
  ret.num_colors = 7;
  ret.b = {"#ff8181", "#ffe081", "#bfff81", "#81ffd1", "#81ceff", "#9381ff", "#f281ff"};
  ret.m = {"#e85858", "#e8c558", "#9fe858", "#58e8b3", "#58b0e8", "#6c58e8", "#d958e8"};
  ret.d = {"#c04040", "#c0a140", "#7fc040", "#40c091", "#408fc0", "#5340c0", "#b340c0"};
  return ret;
}

std::string Style::GetStyle(const Node &n) {
  StyleBuilder sb;

  sb << node.base;

  // Add label
  switch (n.type()->id()) {
    case Type::RECORD:break;
    case Type::VECTOR: sb << node.type.vector;
      break;
    case Type::BIT:sb << node.type.bit;
      break;
    case Type::INTEGER:sb << node.type.integer;
      break;
    case Type::STRING:sb << node.type.string;
      break;
    case Type::BOOLEAN:sb << node.type.boolean;
      break;
    default:break;
  }

  sb << GetLabel(n);

  // Add other style
  switch (n.node_id()) {
    case Node::NodeID::PORT: sb << node.port;
      break;
    case Node::NodeID::SIGNAL:sb << node.signal;
      break;
    case Node::NodeID::PARAMETER:sb << node.parameter;
      break;
    case Node::NodeID::LITERAL:sb << node.literal;
      break;
    case Node::NodeID::EXPRESSION:sb << node.expression;
      break;
  }

  return sb.ToString();
}

std::string Style::GetLabel(const Node &n) {
  StyleBuilder sb;
  bool expand = false;

  if (n.type()->Is(Type::RECORD)) {
    expand |= config.nodes.expand.record;
    if (config.nodes.expand.record) {
      sb << awq("fillcolor", node.color.record_child);
      sb << awq("color", node.color.record_border);
    } else {
      sb << node.type.record;
    }
  }

  std::stringstream str;
  if (n.type()->IsNested() && expand) {
    str << "label=<";
    if (node.nested == "html") {
      str << GenHTMLTableCell(*n.type(), n.name());
    } else {
      str << GenDotRecordCell(*n.type(), n.name());
    }
    str << ">";
  } else if (n.IsParameter()) {
    auto par = dynamic_cast<const Parameter &>(n);
    str << "label=\"" + sanitize(par.name());
    auto val = par.value();
    str << ":" << sanitize(val->ToString());
    str << "\"";
  } else {
    str << "label=\"" + sanitize(n.name()) + "\"";
  }

  sb << str.str();

  return sb.ToString();
}

}  // namespace cerata::dot
