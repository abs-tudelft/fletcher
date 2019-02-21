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

#include "cerata/graphs.h"

#include <string>
#include <memory>
#include <map>

#include "cerata/utils.h"
#include "cerata/nodes.h"
#include "cerata/edges.h"

namespace cerata {

std::shared_ptr<Component> Component::Make(std::string name,
                                           std::initializer_list<std::shared_ptr<Node>> parameters,
                                           std::initializer_list<std::shared_ptr<Node>> ports,
                                           std::initializer_list<std::shared_ptr<Node>> signals) {
  auto ret = std::make_shared<Component>(name);
  for (const auto &param : parameters) {
    // Check if actually a param
    if (!param->IsParameter()) {
      throw std::runtime_error("Node " + param->ToString() + " is not a parameter node.");
    }
    auto p = *Cast<Parameter>(param);
    ret->AddNode(p);
    // If the parameter node has edges
    if (p->input()) {
      // It has been assigned
      auto edge = *p->input();
      auto val = edge->src;
      if (val) {
        // Add the value to the node list
        ret->AddNode(*val);
      }
    } else if (p->default_value) {
      // Otherwise assign default value if any
      p <<= *p->default_value;
      ret->AddNode(*p->default_value);
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

Graph &Graph::AddNode(const std::shared_ptr<Node> &node) {
  nodes_.push_back(node);
  node->SetParent(this);
  return *this;
}

std::shared_ptr<Node> Graph::Get(Node::ID node_id, const std::string &node_name) const {
  for (const auto &n : nodes_) {
    if ((n->name() == node_name) && (n->Is(node_id))) {
      return n;
    }
  }
  throw std::runtime_error(
      "Node of type " + ToString(node_id) + " name " + node_name + " does not exist on Graph " + name());
}

Graph &Graph::AddChild(std::unique_ptr<Graph> child) {
  if (!contains(child->parents, this)) {
    child->parents.push_back(this);
  }
  children.push_back(std::move(child));
  return *this;
}

size_t Graph::CountNodes(Node::ID id) const {
  size_t count = 0;
  for (const auto &n : nodes_) {
    if (n->Is(id)) {
      count++;
    }
  }
  return count;
}

std::deque<std::shared_ptr<Node>> Graph::GetNodesOfType(Node::ID id) const {
  std::deque<std::shared_ptr<Node>> result;
  for (const auto &n : nodes_) {
    if (n->Is(id)) {
      result.push_back(n);
    }
  }
  return result;
}

std::shared_ptr<Port> Graph::port(const std::string &port_name) const {
  return std::dynamic_pointer_cast<Port>(Get(Node::PORT, port_name));
}

std::shared_ptr<Signal> Graph::sig(const std::string &signal_name) const {
  return std::dynamic_pointer_cast<Signal>(Get(Node::SIGNAL, signal_name));
}

std::shared_ptr<ArrayPort> Graph::aport(const std::string &port_name) const {
  return std::dynamic_pointer_cast<ArrayPort>(Get(Node::ARRAY_PORT, port_name));
}

std::shared_ptr<Parameter> Graph::par(const std::string &signal_name) const {
  return std::dynamic_pointer_cast<Parameter>(Get(Node::PARAMETER, signal_name));
}

std::deque<std::shared_ptr<Node>> Graph::GetImplicitNodes() const {
  std::deque<std::shared_ptr<Node>> result;
  for (const auto &n : nodes_) {
    for (const auto &i : n->inputs()) {
      if (i->src) {
        if (!(*i->src)->parent()) {
          result.push_back(*i->src);
        }
      }
    }
  }
  auto last = std::unique(result.begin(), result.end());
  result.erase(last, result.end());
  return result;
}

std::deque<std::shared_ptr<Node>> Graph::GetNodesOfTypes(std::initializer_list<Node::ID> ids) const {
  std::deque<std::shared_ptr<Node>> result;
  for (const auto &n : nodes_) {
    for (const auto &id : ids) {
      if (n->id() == id) {
        result.push_back(n);
        break;
      }
    }
  }
  return result;
}

std::unique_ptr<Instance> Instance::Make(std::string name, std::shared_ptr<Component> component) {
  return std::make_unique<Instance>(name, component);
}

std::unique_ptr<Instance> Instance::Make(std::shared_ptr<Component> component) {
  return std::make_unique<Instance>(component->name() + "_inst", component);
}

Instance::Instance(std::string name, std::shared_ptr<Component> comp)
    : Graph(std::move(name), INSTANCE), component(std::move(comp)) {
  // Create a map that maps an "old" node to a "new" node.
  std::map<std::shared_ptr<Node>, std::shared_ptr<Node>> copied;
  // Make copies of ports
  for (const auto &port : component->GetNodesOfType<Port>()) {
    auto inst_port = port->Copy();
    AddNode(inst_port);
    copied[port] = inst_port;
  }
  // Make copies of array ports
  for (const auto &array_port : component->GetNodesOfType<ArrayPort>()) {
    // Make a copy of the port
    auto inst_port = array_port->Copy();
    AddNode(inst_port);
    copied[array_port] = inst_port;

    // Figure out whether the size node was already copied
    std::shared_ptr<Node> inst_size;
    if (copied.count(array_port->size()) > 0) {
      inst_size = copied[array_port->size()];
    } else {
      inst_size = array_port->size()->Copy();
      AddNode(inst_size);
      copied[array_port->size()] = inst_size;
    }
    // Set the size for the copied node
    (*Cast<ArrayPort>(inst_port))->SetSize(inst_size);
  }
  // Make copies of parameters and literals
  for (const auto &node : component->GetNodesOfTypes({Node::PARAMETER, Node::LITERAL})) {
    if (copied.count(node) == 0) {
      auto inst_node = node->Copy();
      AddNode(inst_node);
      copied[node] = inst_node;
    }
  }
}

Graph &Instance::AddNode(const std::shared_ptr<Node> &node) {
  if (!node->Is(Node::SIGNAL)) {
    nodes_.push_back(node);
    node->SetParent(this);
    return *this;
  } else {
    throw std::runtime_error("Cannot add signal nodes to Instance graph " + name());
  }
}

std::deque<const Component *> GetAllUniqueComponents(const Graph *graph) {
  std::deque<const Component *> ret;
  for (const auto &g : graph->children) {
    Component *comp = nullptr;
    if (g->id_ == Graph::COMPONENT) {
      // Graph itself is the component to potentially insert
      comp = (*Cast<Component>(g.get()));
    } else if (g->id_ == Graph::INSTANCE) {
      // Graph is an instance, its component is the component to potentially insert
      comp = (*Cast<Instance>(g.get()))->component.get();
    }
    if (comp != nullptr) {
      if (!contains(ret, comp)) {
        // If so, push it onto the deque
        ret.push_back(comp);
      }
    }
  }
  return ret;
}

std::deque<Instance *> Component::GetAllInstances() const {
  std::deque<Instance *> ret;
  for (const auto &g : children) {
    if (g->id_ == Graph::INSTANCE) {
      auto inst = Cast<Instance>(g.get());
      if (inst) {
        ret.push_back(*inst);
      }
    }
  }
  return ret;
}

Graph &Component::AddChild(std::unique_ptr<Graph> child) {
  // We may only add instance children by definition
  auto inst = Cast<Instance>(child.get());

  // If the cast was successful...
  if (inst) {
    // Add this graph to the child's parent graphs
    if (!contains(child->parents, *Cast<Graph>(this))) {
      child->parents.push_back(this);
    }

    // Add the child graph
    children.push_back(std::move(child));
    return *this;
  } else {
    // Otherwise throw an error.
    throw std::runtime_error("Component may only have Instance children. " + child->name() + " is not an Instance.");
  }
}

}  // namespace cerata
