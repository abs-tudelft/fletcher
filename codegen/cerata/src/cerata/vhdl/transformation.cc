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

#include "cerata/vhdl/transformation.h"

#include <memory>
#include <deque>
#include <string>

#include "cerata/logging.h"
#include "cerata/types.h"
#include "cerata/graphs.h"
#include "cerata/edges.h"
#include "cerata/transform.h"
#include "vhdl_types.h"

namespace cerata::vhdl {

std::shared_ptr<Component> Transformation::ResolvePortToPort(std::shared_ptr<Component> comp) {
  std::deque<Node *> resolved;
  LOG(DEBUG, "VHDL: Resolve port-to-port connections...");
  for (const auto &inst : comp->GetAllInstances()) {
    for (const auto &port : inst->GetAll<Port>()) {
      for (const auto &edge : port->sinks()) {
        // If the edge is not complete, continue.
        if (!edge->IsComplete()) {
          continue;
        }
        // If either side is not a port, continue.
        if (!(*edge->src)->IsPort() || !(*edge->dst)->IsPort()) {
          continue;
        }
        // If either sides of the edges are a port node on this component, continue.
        if (((*edge->src)->parent() == comp.get()) || ((*edge->dst)->parent() == comp.get())) {
          continue;
        }
        // If the destination is already resolved, continue.
        if (contains(resolved, (*edge->dst).get())) {
          continue;
        }
        // Dealing with two port nodes that are not on the component itself. VHDL cannot handle port-to-port connections
        // of instances. Insert a signal in between and add it to the component.
        std::string prefix;
        if ((*edge->dst)->parent()) {
          prefix = (*(*edge->dst)->parent())->name() + "_";
        } else if ((*edge->src)->parent()) {
          prefix = (*(*edge->src)->parent())->name() + "_";
        }
        auto sig = insert(edge, prefix);
        // Add the signal to the component
        comp->AddObject(sig);
        // Remember we've touched these nodes already
        resolved.push_back((*edge->src).get());
        resolved.push_back((*edge->dst).get());
      }
    }
  }
  return comp;
}

/**
 * @brief Convert a type into a record type with valid and ready fields.
 *
 * This function may cause old stream types to be deleted. Any non-shared pointers to types might be invalidated.
 *
 * @param flattened_type  The flattened type to add valid and ready signals to.
 */
static void AddValidReady(const std::deque<FlatType> &flattened_type) {
  // Iterate over the flattened types
  for (auto &ft : flattened_type) {
    // If we encounter a stream type
    if (ft.type_->Is(Type::STREAM)) {
      Stream *st = (Stream *) *Cast<Stream>(ft.type_);
      if (st->meta.count("VHDL:ResolvedStream") == 0) {
        // Create a new record to hold valid, ready and the original element type
        auto new_elem_type = Record::Make(st->name() + "_vr");
        // Add valid and ready ports to a record
        new_elem_type->AddField(RecField::Make("valid", valid()));
        new_elem_type->AddField(RecField::Make("ready", ready()));
        // Add the original type to the record, without a field name
        new_elem_type->AddField(RecField::Make("", st->element_type()));
        // Set the new element type
        st->SetElementType(new_elem_type);
        // Mark the type to remember we've resolved it
        st->meta["VHDL:ResolvedStream"] = "true";
      }
    }
  }
}

static void ResolveMappers(const std::shared_ptr<Stream> &stream_type) {
  // Before doing anything, obtain the original mappers of this stream type.
  auto mappers = stream_type->mappers();
  LOG(DEBUG, "VHDL:   Stream type has " << mappers.size() << " mapper(s).");

  // Iterate over all previously existing mappers.
  for (const auto &mapper: mappers) {
    // Apply insertion of ready and valid to every stream type in the flattened type.
    AddValidReady(mapper->flat_a());
    AddValidReady(mapper->flat_b());

    // We have to be careful here because AddValidReady *could* and probably will invalidate some type pointers of the
    // flat types. Also, we need to recreate the mappers, otherwise any existing node connections that are based on the
    // mapper are now invalid.

    // Get a copy of the old matrix.
    auto old_matrix = mapper->map_matrix();

    // Create a new mapper
    auto new_mapper = TypeMapper::Make(stream_type.get(), mapper->b());

    // Get the properly sized matrix
    auto new_matrix = new_mapper->map_matrix();

    // To obtain the new mapping matrix, we iterate over the new mapping matrix in a row-wise fashion. When we see a
    // stream, we copy over the original row to the new rows containing the record, valid and ready.
    auto flat_a = new_mapper->flat_a();
    auto flat_b = new_mapper->flat_b();

    size_t old_row = 0;
    size_t row = 0;
    size_t old_col = 0;
    size_t col = 0;

    while (row < new_matrix.height()) {
      while (col < new_matrix.width()) {
      if ((flat_a[row].type_->Is(Type::STREAM) && flat_b[col].type_->Is(Type::STREAM))
        || ()
        || ())
      {
          new_matrix(row, col) = old_matrix(old_row, col);  // Retain old stream mapping for any other transformations
          new_matrix(row + 1, col + 1) = old_matrix(old_row, col); // Record
          new_matrix(row + 2, col + 2) = old_matrix(old_row, col); // Valid
          new_matrix(row + 3, col + 3) = old_matrix(old_row, col); // Ready
      } else {
        // Copy over the columns
        for (size_t col = 0; col < old_matrix.width(); col++) {
          new_matrix(row, col) = old_matrix(old_row, col);
        }
        row++;
      }
      old_row++;
    }

    new_mapper->SetMappingMatrix(new_matrix);

    LOG(DEBUG, "Old:\n" + mapper->ToString());
    LOG(DEBUG, "New:\n" + new_mapper->ToString());

    // Iterate over the columns of the old matrix
    for (size_t col = 0; col < mapper->map_matrix().width(); col++) {

    }
  }
}

std::shared_ptr<Component> Transformation::ResolveStreams(std::shared_ptr<Component> comp) {
  std::deque<std::shared_ptr<Type>> types;
  GetAllObjectTypesRecursive(&types, comp);

  LOG(DEBUG, "VHDL: Materialize stream abstraction...");
  for (const auto &t : types) {
    LOG(DEBUG, "VHDL: Checking type: " + t->ToString());
    if (t->Is(Type::STREAM)) {
      auto st = *Cast<Stream>(t);
      // Only resolve the Stream Type if it wasn't resolved already
      if (st->meta.count("VHDL:ResolvedStream") == 0) {
        LOG(DEBUG, "VHDL: Must resolve " + st->ToString());
        // Resolve the mappers of this Stream type.
        ResolveMappers(st);
      }
    }
  }

  return comp;
}

}  // namespace cerata::vhdl
