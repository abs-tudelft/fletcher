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

#include <string>
#include <memory>

#include "./nodes.h"

namespace fletchgen {
namespace stream {

class ComponentType : public Named {
 public:
  /**
   * @brief Construct an empty ComponentType
   * @param name        The name of the ComponentType
   */
  explicit ComponentType(std::string name) : Named(std::move(name)) {}

  /**
   * @brief Construct a ComponentType with initial Ports
   * @param name        The name of the ComponentType
   * @param port_types  The PortTypes to add
   */
  static std::shared_ptr<ComponentType> Make(std::string name,
                                             std::initializer_list<std::shared_ptr<Parameter>> parameter_types,
                                             std::initializer_list<std::shared_ptr<Port>> port_types);

  ComponentType &AddPort(const std::shared_ptr<Port> &port_type);
  ComponentType &AddParameter(const std::shared_ptr<Parameter> &parameter_type);

  std::deque<std::shared_ptr<Port>> ports() { return ports_; }
  std::deque<std::shared_ptr<Parameter>> parameters() { return parameters_; }
  std::shared_ptr<Port> port(size_t i) const { return ports_[i]; }
  std::shared_ptr<Parameter> parameter(size_t i) const { return parameters_[i]; }
 private:
  std::deque<std::shared_ptr<Port>> ports_;
  std::deque<std::shared_ptr<Parameter>> parameters_;
};

struct Component : public Named {
  Component(std::string name, const std::shared_ptr<ComponentType> &type);

  /**
   * @brief Instantiate a component based on a ComponentType, instantiating all nodes
   * @param type    The ComponentType to instantiate
   * @param name    The name of this component instantiation
   * @return        A shared pointer to the component
   */
  static std::shared_ptr<Component> Instantiate(std::string name, const std::shared_ptr<ComponentType> &type);

  /**
   * @brief         Get a node of a specific type with a specific name
   * @param id      The node type id
   * @param name    The name
   * @return        The node
   */
  std::shared_ptr<Node> GetNode(NodeType::ID id, std::string name);

  /**
   * @brief         Add a node to the component
   * @param node    The node to add
   * @return        A reference to this component
   */
  Component &AddNode(std::shared_ptr<Node> node);

  /**
   * @brief         Count nodes of a specific node type
   * @param id      The node type to count
   * @return        The count
   */
  size_t CountNodes(NodeType::ID id);

  std::shared_ptr<ComponentType> type;
  std::deque<std::shared_ptr<Node>> nodes;
};

}  // namespace stream
}  // namespace fletchgen
