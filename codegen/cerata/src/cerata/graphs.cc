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
#include "cerata/logging.h"

namespace cerata {

static void CopyParameterSources(std::shared_ptr<Component> comp, std::shared_ptr<Object> obj) {
  auto ppar = Cast<Parameter>(obj);
  if (ppar) {
    auto par = *ppar;
    // If the parameter node has edges
    if (par->input()) {
      // It has been assigned
      auto edge = *par->input();
      auto val = edge->src;
      if (val) {
        // Add the value to the node list
        comp->AddObject(*val);
      }
    } else if (par->default_value) {
      // Otherwise assign default value if any
      par <<= *par->default_value;
      comp->AddObject(*par->default_value);
    }
  }
}

static void AddAnyObjectParams(std::shared_ptr<Component> comp, std::shared_ptr<Object> obj) {
  if (obj->IsNode()) {
    auto node = *Cast<Node>(obj);
    auto params = node->type()->GetParameters();
    for (const auto &p : params) {
      comp->AddObject(p);
    }
  }
}

std::shared_ptr<Component> Component::Make(std::string name, std::deque<std::shared_ptr<Object>> objects) {
  auto ret = std::make_shared<Component>(name);
  for (const auto &object : objects) {
    // Add the object to the graph.
    ret->AddObject(object);

    // Add any parameters of the types of all objects.
    AddAnyObjectParams(ret, object);
    // If there are any parameter nodes, also add its input to the component graph
    CopyParameterSources(ret, object);
  }
  return ret;
}

Graph &Graph::AddObject(const std::shared_ptr<Object> &obj) {
  if (!contains(objects_, obj)) {
    objects_.push_back(obj);
    obj->SetParent(this);
  } else {
    CERATA_LOG(DEBUG, "Object " + obj->name() + " already exists on graph " + this->name() + ". Skipping...");
  }
  return *this;
}

std::shared_ptr<NodeArray> Graph::GetArray(Node::NodeID node_id, const std::string &array_name) const {
  for (const auto &a : GetAll<NodeArray>()) {
    if ((a->name() == array_name) && (a->node_id() == node_id)) return a;
  }
  throw std::logic_error("NodeArray " + array_name + " does not exist on Graph " + this->name());
  // TODO(johanpel): use std::optional
}

std::shared_ptr<Node> Graph::GetNode(Node::NodeID node_id, const std::string &node_name) const {
  for (const auto &n : GetAll<Node>()) {
    if (n->name() == node_name)
      if (n->Is(node_id)) {
        return n;
      }
  }
  throw std::logic_error("Node " + node_name + " does not exist on Graph " + this->name());
}

Graph &Graph::AddChild(std::unique_ptr<Graph> child) {
  if (!contains(child->parents, this)) {
    child->parents.push_back(this);
  }
  children.push_back(std::move(child));
  return *this;
}

size_t Graph::CountNodes(Node::NodeID id) const {
  size_t count = 0;
  for (const auto &n : GetAll<Node>()) {
    if (n->Is(id)) {
      count++;
    }
  }
  return count;
}

size_t Graph::CountArrays(Node::NodeID id) const {
  size_t count = 0;
  for (const auto &n : GetAll<NodeArray>()) {
    if (n->node_id() == id) {
      count++;
    }
  }
  return count;
}

std::deque<std::shared_ptr<Node>> Graph::GetNodesOfType(Node::NodeID id) const {
  std::deque<std::shared_ptr<Node>> result;
  for (const auto &n : GetAll<Node>()) {
    if (n->Is(id)) {
      result.push_back(n);
    }
  }
  return result;
}

std::deque<std::shared_ptr<NodeArray>> Graph::GetArraysOfType(Node::NodeID id) const {
  std::deque<std::shared_ptr<NodeArray>> result;
  auto arrays = GetAll<NodeArray>();
  for (const auto &a : arrays) {
    if (a->node_id() == id) {
      result.push_back(a);
    }
  }
  return result;
}

std::shared_ptr<Port> Graph::port(const std::string &port_name) const {
  return std::dynamic_pointer_cast<Port>(GetNode(Node::PORT, port_name));
}
std::shared_ptr<Signal> Graph::sig(const std::string &signal_name) const {
  return std::dynamic_pointer_cast<Signal>(GetNode(Node::SIGNAL, signal_name));
}
std::shared_ptr<Parameter> Graph::par(const std::string &signal_name) const {
  return std::dynamic_pointer_cast<Parameter>(GetNode(Node::PARAMETER, signal_name));
}
std::shared_ptr<PortArray> Graph::porta(const std::string &port_name) const {
  return std::dynamic_pointer_cast<PortArray>(GetArray(Node::PORT, port_name));
}

std::deque<std::shared_ptr<Node>> Graph::GetImplicitNodes() const {
  std::deque<std::shared_ptr<Node>> result;
  for (const auto &n : GetAll<Node>()) {
    for (const auto &i : n->sources()) {
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

std::deque<std::shared_ptr<Node>> Graph::GetNodesOfTypes(std::initializer_list<Node::NodeID> ids) const {
  std::deque<std::shared_ptr<Node>> result;
  for (const auto &n : GetAll<Node>()) {
    for (const auto &id : ids) {
      if (n->node_id() == id) {
        result.push_back(n);
        break;
      }
    }
  }
  return result;
}

std::unique_ptr<Instance> Instance::Make(std::string name, std::shared_ptr<Component> component) {
  auto n = name;
  if (name.empty()) {
    n = component->name() + "_inst";
  }
  return std::make_unique<Instance>(n, component);
}

std::unique_ptr<Instance> Instance::Make(std::shared_ptr<Component> component) {
  return std::make_unique<Instance>(component->name() + "_inst", component);
}

Instance::Instance(std::string
                   name, std::shared_ptr<Component>
                   comp)
    : Graph(std::move(name), INSTANCE), component(std::move(comp)) {
  // Create a map that maps an "old" node to a "new" node.
  std::map<std::shared_ptr<Object>, std::shared_ptr<Object>> copies;
  // Make copies of ports
  for (const auto &port : component->GetAll<Port>()) {
    auto inst_port = port->Copy();
    AddObject(inst_port);
    copies[port] = inst_port;
  }
  // Make copies of port arrays
  for (const auto &array_port : component->GetAll<PortArray>()) {
    // Make a copy of the port
    auto inst_port = array_port->Copy();
    AddObject(inst_port);
    copies[array_port] = inst_port;

    // Figure out whether the size node was already copied
    std::shared_ptr<Object> inst_size;
    if (copies.count(array_port->size()) > 0) {
      inst_size = copies[array_port->size()];
    } else {
      inst_size = array_port->size()->Copy();
      AddObject(inst_size);
      copies[array_port->size()] = inst_size;
    }
    // Set the size for the copied node
    auto isn = *Cast<Node>(inst_size);
    auto ipa = *Cast<PortArray>(inst_port);
    ipa->SetSize(isn);
  }

  // Make copies of parameters and literals
  for (const auto &node : component->GetNodesOfTypes({Node::PARAMETER, Node::LITERAL})) {
    if (copies.count(node) == 0) {
      auto inst_node = node->Copy();
      AddObject(inst_node);
      copies[node] = inst_node;
    }
  }
}

Graph &Instance::AddObject(const std::shared_ptr<Object> &object) {
  objects_.push_back(object);
  object->SetParent(this);
  return *this;
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

Instance *Component::AddInstanceOf(std::shared_ptr<cerata::Component> comp, std::string name) {
  auto inst = Instance::Make(name, comp);
  auto raw_ptr = inst.get();
  AddChild(std::move(inst));
  return raw_ptr;
}

}  // namespace cerata
