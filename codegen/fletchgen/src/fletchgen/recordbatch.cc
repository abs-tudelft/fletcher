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
#include <memory>
#include <deque>

#include "fletchgen/array.h"
#include "fletchgen/bus.h"
#include "fletchgen/schema.h"

namespace fletchgen {

using cerata::Instance;
using cerata::Component;
using cerata::Port;
using cerata::Literal;
using cerata::intl;

RecordBatch::RecordBatch(const std::shared_ptr<FletcherSchema> &fletcher_schema)
    : Component(fletcher_schema->name()), fletcher_schema_(fletcher_schema) {
  // Get Arrow Schema
  auto as = fletcher_schema_->arrow_schema();
  // Add default port nodes
  AddObject(Port::Make("bcd", cr(), Port::Dir::IN, bus_domain()));
  AddObject(Port::Make("kcd", cr(), Port::Dir::IN, kernel_domain()));
  AddObject(bus_addr_width());
  // Add and connect all array readers and resulting ports
  AddArrays(*fletcher_schema);
}

void RecordBatch::AddArrays(const FletcherSchema &fletcher_schema) {
  // Iterate over all fields and add ArrayReader/Writer data and control ports.
  for (const auto &field : fletcher_schema.arrow_schema()->fields()) {
    // Check if we must ignore the field
    if (fletcher::MustIgnore(*field)) {
      FLETCHER_LOG(DEBUG, "Ignoring field " + field->name());
    } else {
      FLETCHER_LOG(DEBUG, "Instantiating Array " << (fletcher_schema.mode() == Mode::READ ? "Reader" : "Writer")
                                                 << " for schema: " << fletcher_schema.name()
                                                 << " : " << field->name());
      // Convert to and add an Arrow port. We must invert it because it is an output of the RecordBatch.
      auto kernel_arrow_port = FieldPort::MakeArrowPort(fletcher_schema, field, fletcher_schema.mode(), true);
      auto kernel_arrow_type = kernel_arrow_port->type();
      AddObject(kernel_arrow_port);

      // Add a command port for the ArrayReader/Writer
      auto command_port = FieldPort::MakeCommandPort(fletcher_schema, field);
      AddObject(command_port);

      // Add an unlock port for the ArrayReader/Writer
      auto unlock_port = FieldPort::MakeUnlockPort(fletcher_schema, field);
      AddObject(unlock_port);

      // Instantiate an ArrayReader or Writer
      auto array_inst_unique = ArrayInstance(field->name() + "_inst",
                                             fletcher_schema.mode(),
                                             kernel_arrow_port->data_width(),
                                             ctrl_width(*field),
                                             tag_width(*field));
      auto array_inst = array_inst_unique.get();  // Remember the raw pointer
      array_instances_.push_back(array_inst);
      AddChild(std::move(array_inst_unique));  // Move ownership to this RecordBatchReader/Writer.

      // Generate a configuration string for the ArrayReader
      auto cfg_node = array_inst->GetNode(Node::NodeID::PARAMETER, "CFG");
      cfg_node <<= cerata::strl(GenerateConfigString(*field));  // Set the configuration string for this field

      // Drive the clocks and resets
      Connect(array_inst->port("kcd"), port("kcd"));
      Connect(array_inst->port("bcd"), port("bcd"));

      // Drive the RecordBatch Arrow data port with the ArrayReader/Writer data port, or vice versa
      if (fletcher_schema.mode() == Mode::READ) {
        auto array_data_port = array_inst->port("out");
        auto array_data_type = array_data_port->type();
        // Create a mapper between the Arrow port and the Array data port
        auto mapper = GetStreamTypeMapper(kernel_arrow_type, array_data_type);
        kernel_arrow_type->AddMapper(mapper);
        // Connect the ports
        kernel_arrow_port <<= array_data_port;
      } else {
        auto array_data_port = array_inst->port("in");
        auto array_data_type = array_data_port->type();
        // Create a mapper between the Arrow port and the Array data port
        auto mapper = GetStreamTypeMapper(kernel_arrow_type, array_data_type);
        kernel_arrow_type->AddMapper(mapper);
        // Connect the ports
        array_data_port <<= kernel_arrow_port;
      }

      // Drive the ArrayReader command port from the top-level command port
      array_inst->port("cmd") <<= command_port;
      // Drive the unlock port with the ArrayReader/Writer
      unlock_port <<= array_inst->port("unl");

      // Copy over the ArrayReader/Writer's bus channels
      auto bus = std::dynamic_pointer_cast<BusPort>(array_inst->port("bus")->Copy());
      // Give the new bus port a unique name
      // TODO(johanpel): move the bus renaming to the Mantle level
      bus->SetName(fletcher_schema.name() + "_" + field->name() + "_" + bus->name());
      AddObject(bus);  // Add them to the RecordBatch
      bus_ports_.push_back(bus);  // Remember the port
      bus <<= array_inst->port("bus");  // Connect them to the ArrayReader/Writer
    }
  }
}

std::shared_ptr<FieldPort> RecordBatch::GetArrowPort(const arrow::Field &field) const {
  for (const auto &n : objects_) {
    auto ap = std::dynamic_pointer_cast<FieldPort>(n);
    if (ap != nullptr) {
      if ((ap->function_ == FieldPort::ARROW) && (ap->field_->Equals(field))) {
        return ap;
      }
    }
  }
  throw std::runtime_error("Field " + field.name() + " did not generate an ArrowPort for Core " + name() + ".");
}

std::deque<std::shared_ptr<FieldPort>>
RecordBatch::GetFieldPorts(const std::optional<FieldPort::Function> &function) const {
  std::deque<std::shared_ptr<FieldPort>> result;
  for (const auto &n : objects_) {
    auto ap = std::dynamic_pointer_cast<FieldPort>(n);
    if (ap != nullptr) {
      if ((function && (ap->function_ == *function)) || !function) {
        result.push_back(ap);
      }
    }
  }
  return result;
}

std::shared_ptr<RecordBatch> RecordBatch::Make(const std::shared_ptr<FletcherSchema> &fletcher_schema) {
  auto rb = new RecordBatch(fletcher_schema);
  auto shared_rb = std::shared_ptr<RecordBatch>(rb);
  cerata::default_component_pool()->Add(shared_rb);
  return shared_rb;
}

std::shared_ptr<FieldPort> FieldPort::MakeArrowPort(const FletcherSchema &fletcher_schema,
                                                    const std::shared_ptr<arrow::Field> &field,
                                                    Mode mode,
                                                    bool invert,
                                                    const std::shared_ptr<ClockDomain> &domain) {
  Dir dir;
  if (invert) {
    dir = Term::Invert(mode2dir(mode));
  } else {
    dir = mode2dir(mode);
  }
  return std::make_shared<FieldPort>(fletcher_schema.name() + "_" + field->name(),
                                     ARROW, field, GetStreamType(*field, mode), dir, domain);
}

std::shared_ptr<FieldPort> FieldPort::MakeCommandPort(const FletcherSchema &fletcher_schema,
                                                      const std::shared_ptr<arrow::Field> &field,
                                                      const std::shared_ptr<ClockDomain> &domain) {
  return std::make_shared<FieldPort>(fletcher_schema.name() + "_" + field->name() + "_cmd",
                                     COMMAND,
                                     field,
                                     cmd(ctrl_width(*field), tag_width(*field)),
                                     Dir::IN,
                                     domain);
}

std::shared_ptr<FieldPort> FieldPort::MakeUnlockPort(const FletcherSchema &fletcher_schema,
                                                     const std::shared_ptr<arrow::Field> &field,
                                                     const std::shared_ptr<ClockDomain> &domain) {
  return std::make_shared<FieldPort>(fletcher_schema.name() + "_" + field->name() + "_unl",
                                     UNLOCK,
                                     field,
                                     unlock(tag_width(*field)),
                                     Dir::OUT,
                                     domain);
}

std::shared_ptr<Node> FieldPort::data_width() {
  std::shared_ptr<Node> width = intl(0);
  // Flatten the type
  auto flat_type = Flatten(type());
  for (const auto &ft : flat_type) {
    if (ft.type_->meta.count("array_data") > 0) {
      if (ft.type_->width()) {
        width = width + ft.type_->width().value();
      }
    }
  }
  return width;
}

std::shared_ptr<cerata::Object> FieldPort::Copy() const {
  // Take shared ownership of the type.
  auto typ = type()->shared_from_this();
  return std::make_shared<FieldPort>(name(), function_, field_, typ, dir(), domain_);
}

}  // namespace fletchgen
