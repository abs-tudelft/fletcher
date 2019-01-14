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

#include "components.h"

namespace fletchgen {
namespace stream {

std::shared_ptr<ComponentType> ComponentType::Make(std::string name,
                                                   std::initializer_list<std::shared_ptr<Parameter>> parameter_types,
                                                   std::initializer_list<std::shared_ptr<Port>> port_types) {
  auto ret = std::make_shared<ComponentType>(name);
  for (const auto &parameter_type : parameter_types) {
    ret->AddParameter(parameter_type);
  }
  for (const auto &port_type : port_types) {
    ret->AddPort(port_type);
  }
  return ret;
}

ComponentType &ComponentType::AddPort(const std::shared_ptr<Port> &port_type) {
  ports_.push_back(port_type);
  return *this;
}

ComponentType &ComponentType::AddParameter(const std::shared_ptr<Parameter> &parameter_type) {
  parameters_.push_back(parameter_type);
  return *this;
}

std::shared_ptr<Component> Component::Instantiate(std::string name, const std::shared_ptr<ComponentType> &type) {
  auto ret = std::make_shared<Component>(name, type);
  return ret;
}

Component::Component(std::string name, const std::shared_ptr<ComponentType> &type)
    : Named(std::move(name)), type(type) {
  // Create nodes for each parameter and port
  for (const auto &par : type->parameters()) {
    nodes.push_back(Node::Make(par->name(), par));
  }
  for (const auto &port : type->ports()) {
    nodes.push_back(Node::Make(port->name(), port));
  }
}

std::shared_ptr<Node> Component::GetNode(NodeType::ID id, std::string name) {
  for (const auto &n : nodes) {
    if ((n->name() == name) && (n->type->id == id)) {
      return n;
    }
  }
  return nullptr;
}

Component &Component::AddNode(std::shared_ptr<Node> node) {
  nodes.push_back(node);
  return *this;
}

size_t Component::CountNodes(NodeType::ID id) {
  size_t count = 0;
  for (const auto& n : nodes) {
    if (n->type->id == id) {
      count++;
    }
  }
  return count;
}

}  // namespace stream
}  // namespace fletchgen
