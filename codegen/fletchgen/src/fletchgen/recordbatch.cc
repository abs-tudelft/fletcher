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

#include "fletchgen/recordbatch.h"

#include <cerata/api.h>

#include "fletchgen/array.h"
#include "fletchgen/bus.h"

namespace fletchgen {

using cerata::Cast;
using cerata::Instance;
using cerata::Component;
using cerata::Port;
using cerata::Literal;

RecordBatchReader::RecordBatchReader(const std::string &name, const std::shared_ptr<arrow::Schema> &schema)
    : Component(name + "_RecordBatchReader") {
  // Get mode/direction
  auto mode = fletcher::getMode(schema);

  // Get name, if available
  auto schema_name = fletcher::getMeta(schema, "fletcher_name");
  if (schema_name.empty()) schema_name = "<Anonymous>";

  // Iterate over all fields and add ArrayReader data and control ports.
  for (const auto &f : schema->fields()) {
    // Check if we must ignore a field
    if (!fletcher::mustIgnore(f)) {
      LOG(DEBUG, "Hardware-izing field: " + f->name());
      // Convert to and add an ArrowPort
      AddObject(FieldPort::MakeArrowPort(f, mode));
      // Add a command stream for the ArrayReader
      AddObject(FieldPort::MakeCommandPort(f, Port::IN));
    } else {
      LOG(DEBUG, "Ignoring field " + f->name());
    }
  }

  // Instantiate ColumnReaders/Writers for each field.
  for (const auto &ap : GetFieldPorts(FieldPort::ARROW)) {
    // Handle anything that must read from memory
    if (ap->dir() == Port::IN) {
      // Instantiate an ArrayReader
      auto ar_inst = AddInstanceOf(ArrayReader(), ap->field_->name() + "_Instance");
      // Generate a configuration string
      auto config_string_node = ar_inst->GetNode(Node::PARAMETER, "CFG");
      // Set the configuration string
      config_string_node <<= cerata::strl(GenerateConfigString(ap->field_));
      // Keep the instance pointer
      readers_.push_back(ar_inst);
    }
  }

  // Add bus
  //auto num_read_slaves = cerata::Parameter::Make("NUM_READ_SLAVES", cerata::integer(), cerata::intl<0>());
  //auto bus_rreq_array = cerata::PortArray::Make("bus_rreq", bus_read_request(), num_read_slaves, Port::Dir::OUT);
  //auto bus_rdat_array = cerata::PortArray::Make("bus_rdat", bus_read_data(), num_read_slaves, Port::Dir::IN);

  //AddObject(num_read_slaves);
  //AddObject(bus_rreq_array);
  //AddObject(bus_rdat_array);

  for (const auto &cr : readers_) {
    auto cr_rreq = cr->port("bus_rreq");
    auto cr_rdat = cr->port("bus_rdat");
    //bus_rreq_array->Append() <<= cr_rreq;
    //cr_rdat <<= bus_rdat_array->Append();
  }
}

std::shared_ptr<FieldPort> RecordBatchReader::GetArrowPort(const std::shared_ptr<arrow::Field> &field) {
  for (const auto &n : objects_) {
    auto ap = Cast<FieldPort>(n);
    if (ap) {
      if (((*ap)->function_ == FieldPort::ARROW) && ((*ap)->field_ == field)) {
        return *ap;
      }
    }
  }
  throw std::runtime_error("Field " + field->name() + " did not generate an ArrowPort for Core " + name() + ".");
}

std::deque<std::shared_ptr<FieldPort>> RecordBatchReader::GetFieldPorts(const std::optional<FieldPort::Function> &function) {
  std::deque<std::shared_ptr<FieldPort>> result;
  for (const auto &n : objects_) {
    auto ap = Cast<FieldPort>(n);
    if (ap) {
      if ((function && ((*ap)->function_ == *function)) || !function) {
        result.push_back(*ap);
      }
    }
  }
  return result;
}

} // namespace fletchgen