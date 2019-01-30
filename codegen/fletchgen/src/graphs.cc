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

#include "graphs.h"

#include <string>
#include <memory>

#include "./nodes.h"
#include "./edges.h"

namespace fletchgen {

std::shared_ptr<Component> Component::Make(std::string name,
                                           std::initializer_list<std::shared_ptr<Parameter>> parameters,
                                           std::initializer_list<std::shared_ptr<Port>> ports,
                                           std::initializer_list<std::shared_ptr<Signal>> signals) {
  auto ret = std::make_shared<Component>(name);
  for (const auto &param : parameters) {
    ret->AddNode(param);
    // If the parameter node has edges
    if (!param->ins().empty()) {
      // It has been assigned
      std::shared_ptr<Node> val = param->in(0)->src;
      // Add the value to the node list
      ret->AddNode(val);
    } else if (param->default_value) {
      // Otherwise assign default value if any
      param <<= *param->default_value;
      ret->AddNode(*param->default_value);
    }
  }
  for (const auto &port : ports) {
    ret->AddNode(port);
  }
  for (const auto &signal : signals) {
    ret->AddNode(signal);
  }
  return ret;
}

Graph &Graph::AddNode(std::shared_ptr<Node> node) {
  nodes.push_back(node);
  node->SetParent(this);
  return *this;
}

std::shared_ptr<Node> Graph::Get(Node::ID id, const std::string &node_name) const {
  for (const auto &n : nodes) {
    if ((n->name() == node_name) && (n->Is(id))) {
      return n;
    }
  }
  throw std::runtime_error("Node of type " + ToString(id)
                               + " name " + node_name + " does not exist on Graph " + name());
}

Graph &Graph::AddChild(const std::shared_ptr<Graph> &child) {
  if (!contains(child->parents, this)) {
    child->parents.push_back(this);
  }
  children.push_back(child);
  return *this;
}

size_t Graph::CountNodes(Node::ID id) const {
  size_t count = 0;
  for (const auto &n : nodes) {
    if (n->Is(id)) {
      count++;
    }
  }
  return count;
}

std::shared_ptr<Graph> Graph::Copy() const {
  auto ret = std::make_shared<Graph>(name(), this->id);
  for (const auto &child : children) {
    ret->AddChild(child->Copy());
  }
  for (const auto &node : nodes) {
    ret->AddNode(node->Copy());
  }
  return ret;
}

std::deque<std::shared_ptr<Node>> Graph::GetAllNodesOfType(Node::ID id) const {
  std::deque<std::shared_ptr<Node>> result;
  for (const auto &n : nodes) {
    if (n->Is(id)) {
      result.push_back(n);
    }
  }
  return result;
}

std::shared_ptr<Instance> Instance::Make(std::string name, std::shared_ptr<Component> component) {
  return std::make_shared<Instance>(name, component);
}

std::shared_ptr<Instance> Instance::Make(std::shared_ptr<Component> component) {
  return std::make_shared<Instance>(component->name() + "_inst", component);
}

Instance::Instance(std::string name, std::shared_ptr<Component> comp)
    : Graph(std::move(name), INSTANCE), component(std::move(comp)) {
  // Make copies of ports and parameters
  for (const auto &port : component->GetAllNodesOfType<Port>()) {
    AddNode(port->Copy());
  }
  for (const auto &par : component->GetAllNodesOfType<Parameter>()) {
    AddNode(par->Copy());
  }
}

Graph &Instance::AddNode(std::shared_ptr<Node> node) {
  if (!node->Is(Node::SIGNAL)) {
    nodes.push_back(node);
    node->SetParent(this);
    return *this;
  } else {
    throw std::runtime_error("Cannot add signal nodes to Instance graph " + name());
  }
}

std::deque<std::shared_ptr<Component>> GetAllUniqueComponents(const std::shared_ptr<Graph> &graph) {
  std::deque<std::shared_ptr<Component>> ret;
  for (const auto &g : graph->children) {
    std::optional<std::shared_ptr<Component>> comp;
    if (g->id == Graph::COMPONENT) {
      // Graph itself is the component to potentially insert
      comp = Cast<Component>(g);
    } else if (g->id == Graph::INSTANCE) {
      // Graph is an instance, its component is the component to potentially insert
      comp = (*Cast<Instance>(g))->component;
    }
    if (comp) {
      if (!contains(ret, *comp)) {
        // If so, push it onto the deque
        ret.push_back(*comp);
      }
    }
  }
  return ret;
}

std::deque<std::shared_ptr<Instance>> Component::GetAllInstances() {
  std::deque<std::shared_ptr<Instance>> ret;
  for (const auto &g : children) {
    std::optional<std::shared_ptr<Instance>> inst;
    if (g->id == Graph::INSTANCE) {
      inst = Cast<Instance>(g);
      if (inst) {
        ret.push_back(*inst);
      }
    }
  }
  return ret;
}

Graph &Component::AddChild(const std::shared_ptr<Graph> &child) {
  // We may only add instance children by definition
  auto inst = Cast<Instance>(child);

  // If the cast was successful...
  if (inst) {
    // Add this graph to the child's parent graphs
    if (!contains(child->parents, *Cast<Graph>(this))) {
      child->parents.push_back(this);
    }

    // Add the child graph
    children.push_back(child);
    return *this;
  } else {
    // Otherwise throw an error.
    throw std::runtime_error("Component may only have Instance children. " + child->name() + " is not an Instance.");
  }
}

std::shared_ptr<Graph> Component::Copy() const {
  // TODO(johanpel): properly copy everything, including edges.

  auto ret = std::make_shared<Component>(name());
  for (const auto &child : this->children) {
    ret->AddChild(*Cast<Instance>(child));
  }
  for (const auto &node : this->nodes) {
    ret->AddNode(node->Copy());
  }
  return ret;
}

}  // namespace fletchgen
