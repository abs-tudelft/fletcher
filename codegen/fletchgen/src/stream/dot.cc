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

#include "dot.h"
#include "./edges.h"

std::string fletchgen::dot::Grapher::Edges(const std::shared_ptr<fletchgen::stream::Component> &comp) {
  std::stringstream str;

  std::deque<std::shared_ptr<Edge>> all_edges;

  for (const auto& n : comp->nodes) {
    auto edges = n->edges();
    for (const auto& e : edges) {
      all_edges.push_back(e);
    }
  }

  for (const auto& e : all_edges) {
    str << "  " << e->src->name() << " -> " << e->dst->name() << ";\n";
  }

  return str.str();
}

std::string fletchgen::dot::Grapher::Nodes(const std::shared_ptr<fletchgen::stream::Component> &comp) {
  std::stringstream str;

  for (const auto& n : comp->nodes) {
    str << "  " << n->name();
    if (n->type->id == fletchgen::stream::NodeType::PORT) {
      str << "[shape=square]";
    }
    str << ";\n";
  }

  return str.str();
}