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
#include "cerata/logging.h"
#include "cerata/object.h"
#include "cerata/pool.h"

namespace cerata {

static void AddParamSources(Graph *graph, const Object &obj) {
  if (obj.IsNode()) {
    auto &node = dynamic_cast<const Node &>(obj);
    if (node.IsParameter()) {
      auto &par = node.AsParameter();
      // If the parameter node has edges
      if (par.GetValue()) {
        // Obtain shared ownership of the value and add it to the graph
        auto val = par.GetValue().value()->shared_from_this();
        graph->AddObject(val);
      }
    }
  }
}

static void AddObjectParams(Graph *comp, const Object &obj) {
  if (obj.IsNode()) {
    auto &node = dynamic_cast<const Node &>(obj);
    auto params = node.type()->GetParameters();
    for (const auto &p : params) {
      // Take ownership of the node and add it to the component.
      comp->AddObject(p->shared_from_this());
      AddParamSources(comp, obj);
    }
  } else if (obj.IsArray()) {
    auto &array = dynamic_cast<const NodeArray &>(obj);
    auto array_size = array.size()->shared_from_this();
    comp->AddObject(array_size);
    AddParamSources(comp, *array_size);
  }
}

Graph &Graph::AddObject(const std::shared_ptr<Object> &obj) {
  // Check for duplicates in name / ownership
  for (const auto &o : objects_) {
    if (o->name() == obj->name()) {
      if (o.get() == obj.get()) {
        CERATA_LOG(DEBUG, "Graph " + name() + " already owns object " + obj->name() + ". Skipping...");
        return *this;
      } else {
        CERATA_LOG(FATAL, "Graph " + name() + " already contains an object with name " + obj->name());
      }
    }
  }
  objects_.push_back(obj);
  obj->SetParent(this);
  AddObjectParams(this, *obj);
  return *this;
}

Graph &Graph::RemoveObject(Object *obj) {
  for (auto o = objects_.begin(); o < objects_.end(); o++) {
    if (o->get() == obj) {
      objects_.erase(o);
    }
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

Instance *Component::AddInstanceOf(Component *comp, const std::string &name) {
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
  CERATA_LOG(FATAL, "NodeArray " + array_name + " does not exist on Graph " + this->name());
  // TODO(johanpel): use std::optional
}

std::optional<Node *> Graph::GetNode(const std::string &node_name) const {
  for (const auto &n : GetAll<Node>()) {
    if (n->name() == node_name) {
      return n;
    }
  }
  return std::nullopt;
}

Node *Graph::GetNode(Node::NodeID node_id, const std::string &node_name) const {
  for (const auto &n : GetAll<Node>()) {
    if (n->name() == node_name) {
      if (n->Is(node_id)) {
        return n;
      }
    }
  }
  CERATA_LOG(FATAL, "Node " + node_name + " does not exist on Graph " + this->name());
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
  meta_[key] = std::move(value);
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
    auto instance_port = port->Copy();
    AddObject(instance_port);
    copies[port] = instance_port.get();
  }

  // Make copies of port arrays
  for (const auto &array_port : component_->GetAll<PortArray>()) {
    auto original_size_node = array_port->size();
    // Make a copy of the port.
    auto instance_port_array = std::dynamic_pointer_cast<PortArray>(array_port->Copy());
    copies[array_port] = instance_port_array.get();
    AddObject(instance_port_array);

    // This has created a copy of the size node as well, but it might be that the size node was already copied before.
    // In this case, we want the size node to be the same node as copied before.

    // Figure out whether the size node was already copied.
    Object *copied_size_node = instance_port_array->size();
    if (copies.count(original_size_node) > 0) {
      // It was already copied, obtain a pointer to it.
      copied_size_node = copies[original_size_node];
      // Obtain ownership of the copied size node and supply it as size node to the port array.
      auto inst_size_node = dynamic_cast<Node *>(copied_size_node)->shared_from_this();
      instance_port_array->SetSize(inst_size_node);
    } else {
      copies[original_size_node] = copied_size_node;
    }
  }

  // Make copies of parameters and literals
  auto pars_lits = component_->GetNodesOfTypes({Node::NodeID::PARAMETER, Node::NodeID::LITERAL});
  for (const auto &node : pars_lits) {
    // Copies might have already been made by adding ports with node parametrized types to the graph.
    // We therefore just check if those nodes are already present by name.
    auto potential_node = GetNode(node->name());
    if (!potential_node) {
      if (copies.count(node) == 0) {
        auto inst_node = node->Copy();
        AddObject(inst_node);
        copies[node] = inst_node.get();
      }
    }
  }
}

Graph &Instance::AddObject(const std::shared_ptr<Object> &object) {
  if (object->IsNode()) {
    auto node = std::dynamic_pointer_cast<Node>(object);
    if (node->IsSignal()) {
      CERATA_LOG(FATAL, "Instance Graph cannot own Signal nodes. " + node->ToString());
    }
  }
  Graph::AddObject(object);
  object->SetParent(this);
  return *this;
}

Graph &Instance::SetParent(Graph *parent) {
  parent_ = parent;
  return *this;
}

}  // namespace cerata
