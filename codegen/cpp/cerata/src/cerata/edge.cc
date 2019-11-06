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

#include "cerata/edge.h"

#include <memory>
#include <utility>
#include <vector>
#include <string>
#include <optional>

#include "cerata/graph.h"
#include "cerata/node.h"
#include "cerata/logging.h"

namespace cerata {

Edge::Edge(std::string name, Node *dst, Node *src)
    : Named(std::move(name)), dst_(dst), src_(src) {
  if ((dst == nullptr) || (src == nullptr)) {
    CERATA_LOG(FATAL, "Cannot construct edge with nullptr nodes.");
  }
}

std::shared_ptr<Edge> Edge::Make(const std::string &name,
                                 Node *dst,
                                 Node *src) {
  auto e = new Edge(name, dst, src);
  return std::shared_ptr<Edge>(e);
}

static void CheckDomains(Node *src, Node *dst) {
  if ((src->IsPort() || src->IsSignal()) && (dst->IsPort() || dst->IsSignal())) {
    auto src_dom = dynamic_cast<Synchronous *>(src)->domain();
    auto dst_dom = dynamic_cast<Synchronous *>(dst)->domain();
    if (src_dom != dst_dom) {
      std::stringstream warning;
      warning << "Attempting to connect Synchronous nodes, but clock domains differ.\n";

      warning << "Src: [" + src->ToString() + "] in domain: [" + dst_dom->name() + "]";
      if (src->parent()) {
        warning << " on parent: [" + src->parent().value()->name() + "]";
      }

      warning << "\nDst: [" + dst->ToString() + "] in domain: [" + src_dom->name() + "]";
      if (dst->parent()) {
        warning << " on parent: [" + dst->parent().value()->name() + "]";
      }

      warning << "\nAutomated CDC crossings are not yet implemented or instantiated.";
      warning << "This behavior may cause incorrect designs.";
      CERATA_LOG(WARNING, warning.str());
    }
  }
}

std::shared_ptr<Edge> Connect(Node *dst, Node *src) {
  // Check for potential errors
  if (src == nullptr) {
    CERATA_LOG(FATAL, "Source node is null");
    return nullptr;
  } else if (dst == nullptr) {
    CERATA_LOG(FATAL, "Destination node is null");
    return nullptr;
  }

  // Check if the clock domains correspond. Currently, this doesn't result in an error as automated CDC support is not
  // in place yet. Just generate a warning for now:
  CheckDomains(src, dst);

  // Check if either source or destination is a signal or port.
  if (src->IsPort() || src->IsSignal()) {
    // Check if the types can be mapped onto each other.
    if (!src->type()->GetMapper(dst->type())) {
      CERATA_LOG(ERROR, "No known type mapping available for connection between node ["
          + dst->ToString() + "] and ["
          + src->ToString() + "]");
    }
    // TODO(johanpel): do something similar for parameters, literals, etc...
  }

  // Deal with specific of nodes that are on a graph.
  if (src->parent() && dst->parent()) {
    auto sp = src->parent().value();
    auto dp = dst->parent().value();
    if (dp->IsComponent()) {
      if (sp->IsComponent() && (sp != dp)) {
        // Check if we're not making a component to component connection on different components.
        CERATA_LOG(ERROR, "Edge between component " + dp->name() + " node " + dst->name() +
            " and component " + sp->name() + " node " + src->name() + " not allowed.");
      }
      auto si = dynamic_cast<Instance *>(sp);
      auto dc = dynamic_cast<Component *>(dp);
      // Check if we're not sourcing from an instance parameter into a node on the instance parent:
      if (dc->HasChild(*si) && src->IsParameter()) {
        CERATA_LOG(ERROR, "Instance parameters can not source component nodes.");
      }
    }
  }
  if (dst->parent()) {
    auto dp = dst->parent().value();
    if (dp->IsInstance()) {
      auto ip = dynamic_cast<Instance *>(dp);
      // When we're connecting a parameter node of an instance, add it to the instance-to-component rebind map.
      // We must do this because otherwise, if we e.g. attach signals to instance ports, the signal type generics
      // could be bound to the instance parameter. They should be rebound to the source of the parameter.
      auto map = dynamic_cast<Component *>(ip->parent())->inst_to_comp_map();
      (*map)[dst] = src;
    }
  }

  // If the destination is a terminator
  if (dst->IsPort()) {
    auto port = dynamic_cast<Port *>(dst);
    // Check if it has a parent
    if (dst->parent()) {
      auto parent = *dst->parent();
      if (parent->IsInstance() && port->IsOutput()) {
        // If the parent is an instance, and the terminator node is an output, then we may not drive it.
        CERATA_LOG(FATAL,
                   "Cannot drive instance " + dst->parent().value()->ToString() + " port " + dst->ToString()
                       + " of mode output with " + src->ToString());
      } else if (parent->IsComponent() && port->IsInput()) {
        // If the parent is a component, and the terminator node is an input, then we may not drive it.
        CERATA_LOG(FATAL,
                   "Cannot drive component " + dst->parent().value()->ToString() + " port " + dst->ToString()
                       + " of mode input with " + src->ToString());
      }
    }
  }

  // If the source is a terminator
  if (src->IsPort()) {
    auto port = dynamic_cast<Port *>(src);
    // Check if it has a parent
    if (src->parent()) {
      auto parent = *src->parent();
      if (parent->IsInstance() && port->IsInput()) {
        // If the parent is an instance, and the terminator node is an input, then we may not source from it.
        CERATA_LOG(FATAL,
                   "Cannot source from instance port " + src->ToString() + " of mode input on " + parent->ToString());
      } else if (parent->IsComponent() && port->IsOutput()) {
        // If the parent is a component, and the terminator node is an output, then we may not source from it.
        CERATA_LOG(FATAL,
                   "Cannot source from component port " + src->ToString() + " of mode output on " + parent->ToString());
      }
    }
  }

  std::string edge_name = src->name() + "_to_" + dst->name();
  auto edge = Edge::Make(edge_name, dst, src);
  src->AddEdge(edge);
  dst->AddEdge(edge);
  return edge;
}

std::shared_ptr<Edge> operator<<=(Node *dst, const std::shared_ptr<Node> &src) {
  return Connect(dst, src.get());
}

std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &dst, const std::shared_ptr<Node> &src) {
  return Connect(dst.get(), src.get());
}

std::shared_ptr<Edge> operator<<=(const std::shared_ptr<Node> &dst, Node *src) {
  return Connect(dst.get(), src);
}

std::vector<Edge *> GetAllEdges(const Graph &graph) {
  std::vector<Edge *> all_edges;

  // Get all normal nodes
  for (const auto &node : graph.GetAll<Node>()) {
    auto out_edges = node->sinks();
    for (const auto &e : out_edges) {
      all_edges.push_back(e);
    }
    auto in_edges = node->sources();
    for (const auto &e : in_edges) {
      all_edges.push_back(e);
    }
  }

  for (const auto &array : graph.GetAll<NodeArray>()) {
    for (const auto &node : array->nodes()) {
      auto out_edges = node->sinks();
      for (const auto &e : out_edges) {
        all_edges.push_back(e);
      }
      auto in_edges = node->sources();
      for (const auto &e : in_edges) {
        all_edges.push_back(e);
      }
    }
  }

  if (graph.IsComponent()) {
    auto &comp = dynamic_cast<const Component &>(graph);
    for (const auto &g : comp.children()) {
      auto child_edges = GetAllEdges(*g);
      all_edges.insert(all_edges.end(), child_edges.begin(), child_edges.end());
    }
  }

  return all_edges;
}

std::shared_ptr<Edge> Connect(Node *dst, const std::shared_ptr<Node> &src) {
  return Connect(dst, src.get());
}

std::shared_ptr<Edge> Connect(const std::shared_ptr<Node> &dst, Node *src) {
  return Connect(dst.get(), src);
}

std::shared_ptr<Edge> Connect(const std::shared_ptr<Node> &dst, const std::shared_ptr<Node> &src) {
  return Connect(dst.get(), src.get());
}

std::optional<Node *> Edge::GetOtherNode(const Node &node) const {
  if (src_ == &node) {
    return dst_;
  } else if (dst_ == &node) {
    return src_;
  } else {
    return std::nullopt;
  }
}

static std::shared_ptr<ClockDomain> DomainOf(NodeArray *node_array) {
  std::shared_ptr<ClockDomain> result;
  auto base = node_array->base();
  if (base->IsSignal()) {
    result = std::dynamic_pointer_cast<Signal>(base)->domain();
  } else if (base->IsPort()) {
    result = std::dynamic_pointer_cast<Port>(base)->domain();
  } else {
    throw std::runtime_error("Base node is not a signal or port.");
  }
  return result;
}

Signal *AttachSignalToNode(Component *comp, NormalNode *node, NodeMap *rebinding, std::string name) {
  std::shared_ptr<Type> type = node->type()->shared_from_this();
  // Figure out if the type is a generic type.
  if (type->IsGeneric()) {
    // In that case, obtain the type generic nodes.
    auto generics = type->GetGenerics();
    // We need to copy over any type generic nodes that are not on the component yet.
    // Potentially produce new generics in the rebind map.
    ImplicitlyRebindNodes(comp, generics, rebinding);
    // Now we must rebind the type generics to the nodes on the component graph.
    // Copy the type and provide the rebind map.
    type = type->Copy(*rebinding);
  }

  // Get the clock domain of the node.
  auto domain = default_domain();
  if (node->IsSignal()) domain = node->AsSignal()->domain();
  if (node->IsPort()) domain = node->AsPort()->domain();

  // Get the name of the node if no name was supplied.
  if (name.empty()) {
    name = node->name();
    // Check if the node is on an instance, and prepend that.
    if (node->parent()) {
      if (node->parent().value()->IsInstance()) {
        name = node->parent().value()->name() + "_" + name;
      }
    }
    auto new_name = name;
    // Check if a node with this name already exists, generate a new name suffixed with a number if it does.
    int i = 0;
    while (comp->Has(new_name)) {
      i++;
      new_name = name + "_" + std::to_string(i);
    }
    name = new_name;
  }

  // Create the new signal.
  auto new_signal = signal(name, type, domain);

  // Copy metadata
  new_signal->meta = node->meta;

  comp->Add(new_signal);

  // Iterate over any existing edges that are sinks of the original node.
  for (auto &e : node->sinks()) {
    // Figure out the original destination of this edge.
    auto dst = e->dst();
    // Remove the edge from the original node and the destination node.
    node->RemoveEdge(e);
    dst->RemoveEdge(e);
    // Create a new edge, driving the destination with the new signal.
    Connect(dst, new_signal);
    Connect(new_signal, node);
  }

  // Iterate over any existing edges that source the original node.
  for (auto &e : node->sources()) {
    // Get the destination node.
    auto src = e->src();
    // Remove the original edge from the port array child node and source node.
    node->RemoveEdge(e);
    src->RemoveEdge(e);
    // Create a new edge, driving the new signal with the original source.
    Connect(new_signal, src);
    Connect(node, new_signal);
  }

  return new_signal.get();
}

SignalArray *AttachSignalArrayToNodeArray(Component *comp, NodeArray *array, NodeMap *rebinding) {
  // The size parameter must potentially be "rebound".
  ImplicitlyRebindNodes(comp, {array->size()}, rebinding);
  auto size = rebinding->at(array->size())->shared_from_this();

  // Get the base node.
  auto base = array->base();

  std::shared_ptr<Type> type = base->type()->shared_from_this();
  // Figure out if the type is a generic type.
  if (type->IsGeneric()) {
    // In that case, obtain the type generic nodes.
    auto generics = base->type()->GetGenerics();
    // We need to copy over any type generic nodes that are not on the component yet.
    // Potentially produce new generics in the rebind map.
    ImplicitlyRebindNodes(comp, generics, rebinding);
    // Now we must rebind the type generics to the nodes on the component graph.
    // Copy the type and provide the rebind map.
    type = array->type()->Copy(*rebinding);
  }

  // Get the clock domain of the array node
  auto domain = DomainOf(array);
  auto name = array->name();
  // Check if the array is on an instance, and prepend that.
  if (array->parent()) {
    if (array->parent().value()->IsInstance()) {
      name = array->parent().value()->name() + "_" + name;
    }
  }
  auto new_name = name;
  // Check if a node with this name already exists, generate a new name suffixed with a number if it does.
  int i = 0;
  while (comp->Has(new_name)) {
    i++;
    new_name = name + "_" + std::to_string(i);
  }

  // Create the new array.
  auto new_array = signal_array(new_name, type, size, domain);
  comp->Add(new_array);

  // Now iterate over all original nodes on the NodeArray and reconnect them.
  for (size_t n = 0; n < array->num_nodes(); n++) {
    // Create a new child node inside the array, but don't increment the size.
    // We've already (potentially) rebound the size from some other source and it should be set properly already.
    auto new_sig = new_array->Append(false);

    bool has_sinks = false;
    bool has_sources = false;

    // Iterate over any existing edges that are sinked by the original array node.
    for (auto &e : array->node(n)->sinks()) {
      // Figure out the original destination.
      auto dst = e->dst();
      // Source the destination with the new signal.
      Connect(dst, new_sig);
      // Remove the original edge from the port array child node and destination node.
      array->node(n)->RemoveEdge(e);
      dst->RemoveEdge(e);
      has_sinks = true;
    }

    // Iterate over any existing edges that source the original array node.
    for (auto &e : array->node(n)->sources()) {
      // Get the destination node.
      auto src = e->src();
      Connect(new_sig, src);
      // Remove the original edge from the port array child node and source node.
      array->node(n)->RemoveEdge(e);
      src->RemoveEdge(e);
      has_sources = true;
    }

    // Source the new signal node with the original node, depending on whether it had any sinks or sources.
    if (has_sinks) {
      Connect(new_sig, array->node(n));
    }
    if (has_sources) {
      Connect(array->node(n), new_sig);
    }
  }
  return new_array.get();
}

std::shared_ptr<Edge> Connect(Node *dst, std::string str) {
  return Connect(dst, strl(std::move(str)));
}

}  // namespace cerata
