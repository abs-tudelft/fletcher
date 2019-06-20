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

#include "cerata/graph.h"

#include <string>
#include <memory>
#include <map>

#include "cerata/utils.h"
#include "cerata/node.h"
#include "cerata/edge.h"
#include "cerata/logging.h"
#include "cerata/object.h"
#include "cerata/pool.h"

namespace cerata {

static void OwnParameterSources(Graph *comp, const Object &obj) {
  if (obj.IsNode()) {
    auto &node = dynamic_cast<const Node &>(obj);
    if (node.IsParameter()) {
      auto &par = dynamic_cast<const Parameter&>(node);
      // If the parameter has a value, take ownership of its value and add it to the component.
      if (par.val()) {
        comp->AddObject(par.val().value()->shared_from_this());
      }
    }
  }
}

static void AddParameterSources(Graph *comp, const Object &obj) {
  if (obj.IsNode()) {
    auto &node = dynamic_cast<const Node &>(obj);
    auto params = node.type()->GetParameters();
    for (const auto &p : params) {
      // Take ownership of the node and add it to the component.
      comp->AddObject(p->shared_from_this());
    }
  }
}

Graph &Graph::AddObject(const std::shared_ptr<Object> &obj) {
  if (!Contains(objects_, obj)) {
    objects_.push_back(obj);
    obj->SetParent(this);
    AddParameterSources(this, *obj);
    //OwnParameterSources(this, *obj);
  }
  return *this;
}

std::shared_ptr<Component> Component::Make(std::string name,
                                           const std::deque<std::shared_ptr<Object>> &objects,
                                           ComponentPool *component_pool) {
  // Create the new component.
  Component *ptr = new Component(std::move(name));
  auto ret = std::shared_ptr<Component>(ptr);

  // Add the component to the pool.
  component_pool->Add(ret);

  // Add the objects shown in the queue.
  for (const auto &object : objects) {
    // Add the object to the graph.
    ret->AddObject(object);
  }
  return ret;
}

Component &Component::AddChild(std::unique_ptr<Instance> child) {
  // Add this graph to the child's parent graphs
  child->SetParent(this);
  // Add the child graph
  children_.push_back(std::move(child));
  return *this;
}

Instance *Component::AddInstanceOf(Component *comp, std::string name) {
  auto inst = Instance::Make(comp, name);
  auto raw_ptr = inst.get();
  AddChild(std::move(inst));
  return raw_ptr;
}

std::deque<const Component *> Component::GetAllUniqueComponents() const {
  std::deque<const Component *> ret;
  for (const auto &child : children_) {
    const Component *comp = nullptr;
    if (child->IsComponent()) {
      // Graph itself is the component to potentially insert
      auto child_as_comp = dynamic_cast<Component *>(child.get());
      comp = child_as_comp;
    } else if (child->IsInstance()) {
      auto child_as_inst = dynamic_cast<Instance *>(child.get());
      // Graph is an instance, its component definition should be inserted.
      comp = child_as_inst->component();
    }
    if (comp != nullptr) {
      if (!Contains(ret, comp)) {
        // If so, push it onto the deque
        ret.push_back(comp);
      }
    }
  }
  return ret;
}

NodeArray *Graph::GetArray(Node::NodeID node_id, const std::string &array_name) const {
  for (const auto &a : GetAll<NodeArray>()) {
    if ((a->name() == array_name) && (a->node_id() == node_id)) return a;
  }
  throw std::logic_error("NodeArray " + array_name + " does not exist on Graph " + this->name());
  // TODO(johanpel): use std::optional
}

Node *Graph::GetNode(Node::NodeID node_id, const std::string &node_name) const {
  for (const auto &n : GetAll<Node>()) {
    if (n->name() == node_name)
      if (n->Is(node_id)) {
        return n;
      }
  }
  throw std::logic_error("Node " + node_name + " does not exist on Graph " + this->name());
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

std::deque<Node *> Graph::GetNodesOfType(Node::NodeID id) const {
  std::deque<Node *> result;
  for (const auto &n : GetAll<Node>()) {
    if (n->Is(id)) {
      result.push_back(n);
    }
  }
  return result;
}

std::deque<NodeArray *> Graph::GetArraysOfType(Node::NodeID id) const {
  std::deque<NodeArray *> result;
  auto arrays = GetAll<NodeArray>();
  for (const auto &a : arrays) {
    if (a->node_id() == id) {
      result.push_back(a);
    }
  }
  return result;
}

Port *Graph::port(const std::string &port_name) const {
  return dynamic_cast<Port *>(GetNode(Node::NodeID::PORT, port_name));
}
Signal *Graph::sig(const std::string &signal_name) const {
  return dynamic_cast<Signal *>(GetNode(Node::NodeID::SIGNAL, signal_name));
}
Parameter *Graph::par(const std::string &signal_name) const {
  return dynamic_cast<Parameter *>(GetNode(Node::NodeID::PARAMETER, signal_name));
}
PortArray *Graph::porta(const std::string &port_name) const {
  return dynamic_cast<PortArray *>(GetArray(Node::NodeID::PORT, port_name));
}

std::deque<Node *> Graph::GetImplicitNodes() const {
  std::deque<Node *> result;
  for (const auto &n : GetAll<Node>()) {
    for (const auto &i : n->sources()) {
      if (i->src()) {
        if (!i->src()->parent()) {
          result.push_back(i->src());
        }
      }
    }
  }
  auto last = std::unique(result.begin(), result.end());
  result.erase(last, result.end());
  return result;
}

std::deque<Node *> Graph::GetNodesOfTypes(std::initializer_list<Node::NodeID> ids) const {
  std::deque<Node *> result;
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

Graph &Graph::SetMeta(const std::string &key, std::string value) {
  meta_[key] = value;
  return *this;
}

std::unique_ptr<Instance> Instance::Make(Component *component, const std::string &name) {
  auto n = name;
  if (name.empty()) {
    n = component->name() + "_inst";
  }
  auto inst = new Instance(component, n);
  return std::unique_ptr<Instance>(inst);
}

std::unique_ptr<Instance> Instance::Make(Component *component) {
  return Make(component, component->name() + "_inst");
}

Instance::Instance(Component *comp, std::string name)
    : Graph(std::move(name), INSTANCE), component_(comp) {
  // Create a map that maps an "old" node to a "new" node.
  std::map<Object *, Object *> copies;
  // Make copies of ports
  for (const auto &port : component_->GetAll<Port>()) {
    auto inst_port = port->Copy();
    AddObject(inst_port);
    copies[port] = inst_port.get();
  }
  // Make copies of port arrays
  for (const auto &array_port : component_->GetAll<PortArray>()) {
    // Make a copy of the port
    auto instance_port = array_port->Copy();
    AddObject(instance_port);
    copies[array_port] = instance_port.get();

    // Figure out whether the size node was already copied
    Object *inst_size;
    if (copies.count(array_port->size()) > 0) {
      inst_size = copies[array_port->size()];
    } else {
      auto inst_size_copy = std::dynamic_pointer_cast<Node>(array_port->size()->Copy());
      AddObject(inst_size_copy);
      inst_size = inst_size_copy.get();
      copies[array_port->size()] = inst_size;
    }
    // Set the size for the copied node
    auto inst_size_node = dynamic_cast<Node *>(inst_size)->shared_from_this();
    auto inst_port_array = std::dynamic_pointer_cast<PortArray>(instance_port);
    inst_port_array->SetSize(inst_size_node);
  }

  // Make copies of parameters and literals
  for (const auto &node : component_->GetNodesOfTypes({Node::NodeID::PARAMETER, Node::NodeID::LITERAL})) {
    if (copies.count(node) == 0) {
      auto inst_node = node->Copy();
      AddObject(inst_node);
      copies[node] = inst_node.get();
    }
  }
}

Graph &Instance::AddObject(const std::shared_ptr<Object> &object) {
  objects_.push_back(object);
  object->SetParent(this);
  return *this;
}

Graph &Instance::SetParent(Graph *parent) {
  parent_ = parent;
  return *this;
}

}  // namespace cerata
