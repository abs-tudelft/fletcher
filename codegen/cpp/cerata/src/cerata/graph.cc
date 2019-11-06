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

#include "cerata/graph.h"

#include <string>
#include <memory>
#include <map>

#include "cerata/utils.h"
#include "cerata/node.h"
#include "cerata/logging.h"
#include "cerata/object.h"
#include "cerata/pool.h"
#include "cerata/edge.h"
#include "cerata/parameter.h"
#include "cerata/expression.h"

namespace cerata {

Graph &Graph::Add(const std::shared_ptr<Object> &object) {
  // Check for duplicates in name / ownership
  for (const auto &o : objects_) {
    if (o->name() == object->name()) {
      if (o.get() == object.get()) {
        // Graph already owns object. We can skip adding.
        return *this;
      } else {
        CERATA_LOG(ERROR, "Graph " + name() + " already contains an object with name " + object->name());
      }
    }
  }

  // Check if it already has a parent. At this point we may want to move to unique ptrs to objects.
  if (object->parent() && object->parent().value() != this) {
    CERATA_LOG(FATAL, "Object " + object->name() + " already has parent " + object->parent().value()->name());
  }

  // Get any objects referenced by this object. They must already be on this graph.
  std::vector<Object *> references;
  object->AppendReferences(&references);
  for (const auto &ref : references) {
    // If the sub-object has a parent and it is this graph, everything is OK.
    if (ref->parent()) {
      if (ref->parent().value() == this) {
        continue;
      }
    }
    if (ref->IsNode()) {
      // There are two special cases where a references doesn't yet have to be owned by this graph.
      auto gen_node = dynamic_cast<Node *>(ref);
      // Literals are owned by the literal pool, so everything is OK as well in that case.
      if (gen_node->IsLiteral()) {
        continue;
      }
      if (gen_node->IsExpression()) {
        continue;
      }
    }
    // Otherwise throw an error.
    CERATA_LOG(ERROR, "Object [" + ref->name()
        + "] bound to object [" + object->name()
        + "] is not present on Graph " + name());
  }
  // No conflicts, add the object
  objects_.push_back(object);
  // Set this graph as parent.
  object->SetParent(this);

  return *this;
}

Graph &Graph::Add(const std::vector<std::shared_ptr<Object>> &objects) {
  for (const auto &obj : objects) {
    Add(obj);
  }
  return *this;
}

Graph &Graph::Remove(Object *obj) {
  for (auto o = objects_.begin(); o < objects_.end(); o++) {
    if (o->get() == obj) {
      objects_.erase(o);
    }
  }
  return *this;
}

std::optional<Node *> Graph::FindNode(const std::string &node_name) const {
  for (const auto &n : GetAll<Node>()) {
    if (n->name() == node_name) {
      return n;
    }
  }
  return std::nullopt;
}

Node *Graph::GetNode(const std::string &node_name) const {
  for (const auto &n : GetAll<Node>()) {
    if (n->name() == node_name) {
      return n;
    }
  }
  CERATA_LOG(FATAL, "Node with name " + node_name + " does not exist on Graph " + this->name());
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

std::vector<Node *> Graph::GetNodesOfType(Node::NodeID id) const {
  std::vector<Node *> result;
  for (const auto &n : GetAll<Node>()) {
    if (n->Is(id)) {
      result.push_back(n);
    }
  }
  return result;
}

std::vector<NodeArray *> Graph::GetArraysOfType(Node::NodeID id) const {
  std::vector<NodeArray *> result;
  auto arrays = GetAll<NodeArray>();
  for (const auto &a : arrays) {
    if (a->node_id() == id) {
      result.push_back(a);
    }
  }
  return result;
}

Port *Graph::prt(const std::string &name) const {
  return Get<Port>(name);
}

Signal *Graph::sig(const std::string &name) const {
  return Get<Signal>(name);
}

Parameter *Graph::par(const std::string &name) const {
  return Get<Parameter>(name);
}

Parameter *Graph::par(const Parameter &param) const {
  return Get<Parameter>(param.name());
}

Parameter *Graph::par(const std::shared_ptr<Parameter> &param) const {
  return Get<Parameter>(param->name());
}

PortArray *Graph::prt_arr(const std::string &name) const {
  return Get<PortArray>(name);
}

SignalArray *Graph::sig_arr(const std::string &name) const {
  return Get<SignalArray>(name);
}

std::vector<Node *> Graph::GetImplicitNodes() const {
  std::vector<Node *> result;
  for (const auto &n : GetAll<Node>()) {
    for (const auto &i : n->sources()) {
      if (i->src()) {
        if (!i->src()->parent()) {
          result.push_back(i->src());
        }
      }
    }
  }
  FilterDuplicates(&result);
  return result;
}

std::vector<Node *> Graph::GetNodesOfTypes(std::initializer_list<Node::NodeID> ids) const {
  std::vector<Node *> result;
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

bool Graph::Has(const std::string &name) {
  for (const auto &o : objects_) {
    if (o->name() == name) {
      return true;
    }
  }
  return false;
}

std::string Graph::ToStringAllOjects() const {
  std::stringstream ss;
  for (const auto &o : objects_) {
    ss << o->name();
    if (o != objects_.back()) {
      ss << ", ";
    }
  }
  return ss.str();
}

Component &Component::AddChild(std::unique_ptr<Instance> child) {
  // Add this graph to the child's parent graphs
  child->SetParent(this);
  // Add the child graph
  children_.push_back(std::move(child));
  return *this;
}

std::shared_ptr<Component> component(std::string name,
                                     const std::vector<std::shared_ptr<Object>> &objects,
                                     ComponentPool *component_pool) {
  // Create the new component.
  auto *ptr = new Component(std::move(name));
  auto ret = std::shared_ptr<Component>(ptr);
  // Add the component to the pool.
  component_pool->Add(ret);
  // Add the objects shown in the vector.
  for (const auto &object : objects) {
    // Add the object to the graph.
    ret->Add(object);
  }
  return ret;
}

std::shared_ptr<Component> component(std::string name, ComponentPool *component_pool) {
  return component(std::move(name), {}, component_pool);
}

std::vector<const Component *> Component::GetAllInstanceComponents() const {
  std::vector<const Component *> ret;
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
        // If so, push it onto the vector
        ret.push_back(comp);
      }
    }
  }
  return ret;
}

Instance *Component::Instantiate(const std::shared_ptr<Component> &comp, const std::string &name) {
  return Instantiate(comp.get(), name);
}

Instance *Component::Instantiate(Component *comp, const std::string &name) {
  // Mark the component as once instantiated.
  comp->was_instantiated = true;

  auto new_name = name;
  if (new_name.empty()) {
    new_name = comp->name() + "_inst";
  }
  int i = 1;
  while (HasChild(new_name)) {
    new_name = comp->name() + "_inst" + std::to_string(i);
    i++;
  }
  auto inst = Instance::Make(comp, new_name, this);

  // Now, all parameters are reconnected to their defaults. Add all these to the inst to component node map.
  // Whenever we derive stuff from instantiated nodes, like signalizing a port, we will know what value to use.
  for (const auto &param : inst->GetAll<Parameter>()) {
    inst_to_comp[param] = param->default_value();
  }

  auto raw_ptr = inst.get();
  AddChild(std::move(inst));

  return raw_ptr;
}

bool Component::HasChild(const std::string &name) const {
  for (const auto &g : this->children()) {
    if (g->name() == name) {
      return true;
    }
  }
  return false;
}

bool Component::HasChild(const Instance &inst) const {
  for (const auto &g : this->children()) {
    if (&inst == g) {
      return true;
    }
  }
  return false;
}

static void ThrowErrorIfInstantiated(const Graph &g, bool was_instantiated, const Object &o) {
  if (was_instantiated) {
    bool generate_warning = false;
    if (o.IsNode()) {
      auto &node = dynamic_cast<const Node &>(o);
      if (node.IsPort() || node.IsParameter()) {
        generate_warning = true;
      }
    } else if (o.IsArray()) {
      auto &array = dynamic_cast<const NodeArray &>(o);
      if (array.base()->IsPort() || array.base()->IsParameter()) {
        generate_warning = true;
      }
    }
    if (generate_warning) {
      CERATA_LOG(ERROR, "Mutating port or parameter nodes " + o.name() + " of component graph " + g.name()
          + " after instantiation is not allowed.");
    }
  }
}

Graph &Component::Add(const std::shared_ptr<Object> &object) {
  ThrowErrorIfInstantiated(*this, was_instantiated, *object);
  return Graph::Add(object);
}

Graph &Component::Remove(Object *object) {
  ThrowErrorIfInstantiated(*this, was_instantiated, *object);
  return Graph::Remove(object);
}

Graph &Component::Add(const std::vector<std::shared_ptr<Object>> &objects) { return Graph::Add(objects); }

std::unique_ptr<Instance> Instance::Make(Component *component, const std::string &name, Component *parent) {
  auto inst = new Instance(component, name, parent);
  return std::unique_ptr<Instance>(inst);
}

Instance::Instance(Component *comp, std::string name, Component *parent)
    : Graph(std::move(name), INSTANCE), component_(comp), parent_(parent) {
  // Copy over all parameters.
  for (const auto &param : component_->GetAll<Parameter>()) {
    param->CopyOnto(this, param->name(), &comp_to_inst);
  }

  // Copy over all ports.
  for (const auto &port : component_->GetAll<Port>()) {
    port->CopyOnto(this, port->name(), &comp_to_inst);
  }

  // Make copies of port arrays
  for (const auto &port_array : component_->GetAll<PortArray>()) {
    port_array->CopyOnto(this, port_array->name(), &comp_to_inst);
  }
}

Graph &Instance::Add(const std::shared_ptr<Object> &object) {
  if (object->IsNode()) {
    auto node = std::dynamic_pointer_cast<Node>(object);
    if (node->IsSignal()) {
      CERATA_LOG(FATAL, "Instance Graph cannot own Signal nodes. " + node->ToString());
    }
  }
  Graph::Add(object);
  object->SetParent(this);
  return *this;
}

Graph &Instance::SetParent(Graph *parent) {
  parent_ = parent;
  return *this;
}

}  // namespace cerata
