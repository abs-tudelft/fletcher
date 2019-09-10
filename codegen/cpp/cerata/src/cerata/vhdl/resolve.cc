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

#include "cerata/vhdl/resolve.h"

#include <memory>
#include <deque>
#include <string>
#include <unordered_map>

#include "cerata/logging.h"
#include "cerata/type.h"
#include "cerata/graph.h"
#include "cerata/edge.h"
#include "cerata/transform.h"
#include "cerata/vhdl/vhdl_types.h"
#include "cerata/vhdl/vhdl.h"

namespace cerata::vhdl {

Component *Resolve::ResolvePortToPort(Component *comp) {
  std::deque<Node *> resolved;
  CERATA_LOG(DEBUG, "VHDL: Resolve port-to-port connections...");
  for (const auto &inst : comp->children()) {
    for (const auto &port : inst->GetAll<Port>()) {
      for (const auto &edge : port->sinks()) {
        // If either side is not a port, continue with the next edge.
        if (!edge->src()->IsPort() || !edge->dst()->IsPort()) {
          continue;
        }
        // If either sides of the edges are a port node on this component, continue, since this is allowed in VHDL.
        if ((edge->src()->parent() == comp) || (edge->dst()->parent() == comp)) {
          continue;
        }
        // If the destination is already resolved, continue.
        if (Contains(resolved, edge->dst())) {
          continue;
        }
        // Dealing with two port nodes that are not on the component itself. VHDL cannot handle port-to-port connections
        // of instances. Insert a signal in between and add it to the component.
        CERATA_LOG(DEBUG, "VHDL:   Resolving " + edge->src()->ToString() + " --> " + edge->dst()->ToString());
        std::string prefix;
        if (edge->src()->parent()) {
          prefix = edge->src()->parent().value()->name() + "_";
        } else if (edge->dst()->parent()) {
          prefix = edge->dst()->parent().value()->name() + "_";
        }
        // Remember we've touched these nodes already
        resolved.push_back(edge->src());
        resolved.push_back(edge->dst());
        // Insert a new signal, after this, the original edge may potentially be destroyed.
        auto sig = insert(edge, prefix, comp);
      }
    }
  }
  return comp;
}

static bool IsExpandType(const Type *t, const std::string &str = "") {
  if (t->meta.count(metakeys::EXPAND_TYPE) > 0) {
    if (str.empty()) {
      return true;
    } else if (t->meta.at(metakeys::EXPAND_TYPE) == str) {
      return true;
    }
  }
  return false;
}

static bool HasStream(const std::deque<FlatType> &fts) {
  for (const auto &ft : fts) {
    if (ft.type_->Is(Type::STREAM)) {
      return true;
    }
  }
  return false;
}

/**
 * @brief Convert a type into a record type with valid and ready fields.
 *
 * This function may cause old stream types to be deleted. Any pointers to types might be invalidated.
 *
 * @param flattened_type  The flattened type to add valid and ready signals to.
 */
static void ExpandStreamType(Type *type) {
  // If the type was not expanded yet.
  if (type->meta.count(metakeys::WAS_EXPANDED) == 0) {
    // Expand it. First remember that it was expanded.
    type->meta[metakeys::WAS_EXPANDED] = "true";
    // Flatten the type.
    auto flattened_types = Flatten(type);
    // Check if it has any streams.
    if (HasStream(flattened_types)) {
      CERATA_LOG(DEBUG, "VHDL:   Expanding type " + type->ToString());
      // Iterate over the flattened type
      for (auto &flat : flattened_types) {
        // If we encounter a stream type
        if (flat.type_->Is(Type::STREAM)) {
          auto *stream_type = dynamic_cast<Stream *>(flat.type_);
          // Check if we didn't expand the type already.
          if (stream_type->meta.count(metakeys::EXPAND_TYPE) == 0) {
            // Create a new record to hold valid, ready and the original element type
            auto new_elem_type = Record::Make(stream_type->name() + "_vr");
            // Mark the record
            new_elem_type->meta[metakeys::EXPAND_TYPE] = "record";
            // Add valid, ready and original type to the record and set the new element type
            new_elem_type->AddField(RecField::Make("valid", valid()));
            new_elem_type->AddField(RecField::Make("ready", ready(), true));
            new_elem_type->AddField(RecField::Make(stream_type->element_name(), stream_type->element_type()));
            stream_type->SetElementType(new_elem_type);
            // Mark the stream itself to remember we've expanded it.
            stream_type->meta[metakeys::EXPAND_TYPE] = "stream";
          }
        }
      }
    }
  }
}

static void ExpandMappers(Type *type, const std::deque<std::shared_ptr<TypeMapper>> &mappers) {
  // TODO(johanpel): Generalize this type expansion functionality and add it to Cerata.
  // Iterate over all previously existing mappers.
  for (const auto &mapper : mappers) {
    // Skip mappers that don't contain streams.
    if (!HasStream(mapper->flat_a()) && !HasStream(mapper->flat_b())) {
      continue;
    }
    // Skip mappers that were already expanded.
    if (mapper->meta.count(metakeys::WAS_EXPANDED) > 0) {
      continue;
    }

    // Get a copy of the old matrix.
    auto old_matrix = mapper->map_matrix();
    // Create a new mapper
    auto new_mapper = TypeMapper::Make(type, mapper->b());
    // Get the properly sized matrix
    auto new_matrix = new_mapper->map_matrix();
    // Get the flattened type
    auto flat_a = new_mapper->flat_a();
    auto flat_b = new_mapper->flat_b();

    int64_t old_row = 0;
    int64_t old_col = 0;
    int64_t new_row = 0;
    int64_t new_col = 0;

    while (new_row < new_matrix.height()) {
      auto at = flat_a[new_row].type_;
      while (new_col < new_matrix.width()) {
        auto bt = flat_b[new_col].type_;
        // Figure out if we're dealing with a matching, expanded type on both sides.
        if (IsExpandType(at, "stream") && IsExpandType(bt, "stream")) {
          new_matrix(new_row, new_col) = old_matrix(old_row, old_col);
          new_col += 4;  // Skip over record, valid and ready
          old_col += 1;
        } else if (IsExpandType(at, "record") && IsExpandType(bt, "record")) {
          new_matrix(new_row, new_col) = old_matrix(old_row, old_col);
          new_col += 3;  // Skip over valid and ready
          old_col += 1;
        } else if (IsExpandType(at, "valid") && IsExpandType(bt, "valid")) {
          new_matrix(new_row, new_col) = old_matrix(old_row, old_col);
          new_col += 2;  // Skip over ready
          old_col += 1;
        } else if (IsExpandType(at, "ready") && IsExpandType(bt, "ready")) {
          new_matrix(new_row, new_col) = old_matrix(old_row, old_col);
          new_col += 1;
        } else {
          // We're not dealing with a *matching* expanded type. However, if the A side was expanded and the type is
          // not matching, we shouldn't make a copy. That will happen later on, on another row.
          if (!IsExpandType(at)) {
            new_matrix(new_row, new_col) = old_matrix(old_row, old_col);
          }
          new_col += 1;
        }
        // If this column was not expanded, or if it was the last expanded column, move to the next column in the old
        // matrix.
        if (!IsExpandType(bt) || IsExpandType(bt, "ready")) {
          old_col += 1;
        }
      }
      old_col = 0;
      new_col = 0;

      // Only move to the next row of the old matrix when we see the last expanded type or if it's not an expanded
      // type at all.
      if (!IsExpandType(at) || IsExpandType(at, "ready")) {
        old_row += 1;
      }
      new_row += 1;
    }

    // Set the mapping matrix of the new mapper to the new matrix
    new_mapper->SetMappingMatrix(new_matrix);
    new_mapper->meta[metakeys::WAS_EXPANDED] = "true";

    // Add the mapper to the type
    type->AddMapper(new_mapper);
  }
}

Component *Resolve::ExpandStreams(Component *comp) {
  CERATA_LOG(DEBUG, "VHDL: Materialize stream abstraction...");
  // List of types.
  std::deque<Type *> types;
  // List of mappers. Takes ownership of existing mappers before expansion.
  std::unordered_map<Type *, std::deque<std::shared_ptr<TypeMapper>>> mappers;

  // Populate the list.
  GetAllTypes(comp, &types, true);

  // First expand all the types.
  for (const auto &type : types) {
    auto type_mappers = type->mappers();
    if (!type_mappers.empty()) {
      mappers[type] = type_mappers;  // Remember and keep the old mappers for ExpandMappers
    }
    ExpandStreamType(type);
  }
  // Next, expand the mappers that were present for all types.
  for (const auto &type : types) {
    if (mappers.count(type) > 0) {
      ExpandMappers(type, mappers[type]);
    }
  }

  return comp;
}

}  // namespace cerata::vhdl
