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
#include "fletchgen/schema.h"

namespace fletchgen {

using cerata::Cast;
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
  AddObject(Port::Make(bus_cr()));
  AddObject(Port::Make(kernel_cr()));
  AddObject(bus_addr_width());
  // Add and connect all array readers and resulting ports
  AddArrays(*fletcher_schema);
}

void RecordBatch::AddArrays(const FletcherSchema &fs) {
  // Iterate over all fields and add ArrayReader data and control ports.
  for (const auto &f : fs.arrow_schema()->fields()) {
    // Check if we must ignore a field
    if (!fletcher::MustIgnore(*f)) {
      FLETCHER_LOG(DEBUG, "Instantiating Array " << (fs.mode() == Mode::READ ? "Reader" : "Writer")
                                                 << " for schema: " << fs.name() << " : " << f->name());
      // Convert to and add an Arrow port. We must invert it because it is an output of the RecordBatch.
      auto arrow_port = FieldPort::MakeArrowPort(fs, f, fs.mode(), true);
      AddObject(arrow_port);
      auto arrow_type = arrow_port->type();
      // Add a command port for the ArrayReader
      auto command_port = FieldPort::MakeCommandPort(fs, f);
      AddObject(command_port);
      // Add an unlock port for the ArrayReader
      auto unlock_port = FieldPort::MakeUnlockPort(fs, f);
      AddObject(unlock_port);
      // Instantiate an ArrayReader or Writer
      auto array_rw = AddInstanceOf(Array(arrow_port->data_width(), ctrl_width(*f), tag_width(*f), fs.mode()),
                                    f->name() + "_inst");
      // Generate a configuration string for the ArrayReader
      auto cfg_node = array_rw->GetNode(Node::PARAMETER, "CFG");
      // Set the configuration string for this field
      cfg_node <<= cerata::strl(GenerateConfigString(*f));
      // Drive the clocks and resets
      array_rw->port("kcd") <<= port("kcd");
      array_rw->port("bcd") <<= port("bcd");
      // Drive the RecordBatch Arrow data port with the ArrayReader/Writer data port, or vice versa
      if (fs.mode() == Mode::READ) {
        auto data_port = array_rw->port("out");
        // Create a mapper between the Arrow port and the Array data port
        arrow_type->AddMapper(GetStreamTypeMapper(arrow_type, data_port->type()));
        // Connect the ports
        arrow_port <<= data_port;
      } else {
        auto data_port = array_rw->port("in");
        // Create a mapper between the Arrow port and the Array data port
        arrow_port->type()->AddMapper(GetStreamTypeMapper(arrow_type, data_port->type()));
        // Connect the ports
        data_port <<= arrow_port;
      }
      // Drive the ArrayReader command port from the top-level command port
      array_rw->port("cmd") <<= command_port;
      // Drive the unlock port with the ArrayReader/Writer
      unlock_port <<= array_rw->port("unl");
      // Copy over the ArrayReader/Writer's bus channels
      auto bus = *Cast<BusPort>(array_rw->port("bus")->Copy());
      // Give the new bus port a unique name
      // TODO(johanpel): move the bus renaming to the Mantle level
      bus->SetName(fs.name() + "_" + f->name() + "_" + bus->name());
      // Add them to the RecordBatch
      AddObject(bus);
      // Remember the port
      bus_ports_.push_back(bus);
      // Connect them to the ArrayReader/Writer
      bus <<= array_rw->port("bus");
      // Remember where the ArrayReader/Writer is
      array_instances_.push_back(array_rw);
    } else {
      FLETCHER_LOG(DEBUG, "Ignoring field " + f->name());
    }
  }
}

std::shared_ptr<FieldPort> RecordBatch::GetArrowPort(const arrow::Field &field) const {
  for (const auto &n : objects_) {
    auto ap = Cast<FieldPort>(n);
    if (ap) {
      if (((*ap)->function_ == FieldPort::ARROW) && ((*ap)->field_->Equals(field))) {
        return *ap;
      }
    }
  }
  throw std::runtime_error("Field " + field.name() + " did not generate an ArrowPort for Core " + name() + ".");
}

std::deque<std::shared_ptr<FieldPort>> RecordBatch::GetFieldPorts(const std::optional<FieldPort::Function> &function) const {
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

std::shared_ptr<RecordBatch> RecordBatch::Make(const std::shared_ptr<FletcherSchema> &fletcher_schema) {
  return std::make_shared<RecordBatch>(fletcher_schema);
}

std::shared_ptr<FieldPort> FieldPort::MakeArrowPort(const FletcherSchema &fs,
                                                    const std::shared_ptr<arrow::Field> &field,
                                                    Mode mode,
                                                    bool invert) {
  Dir dir;
  if (invert) {
    dir = Term::Invert(mode2dir(mode));
  } else {
    dir = mode2dir(mode);
  }
  return std::make_shared<FieldPort>(fs.name() + "_" + field->name(), ARROW, field, GetStreamType(*field, mode), dir);
}

std::shared_ptr<FieldPort> FieldPort::MakeCommandPort(const FletcherSchema &fs,
                                                      const std::shared_ptr<arrow::Field> &field) {
  return std::make_shared<FieldPort>(fs.name() + "_" + field->name() + "_cmd",
                                     COMMAND,
                                     field,
                                     cmd(ctrl_width(*field), tag_width(*field)),
                                     Dir::IN);
}

std::shared_ptr<FieldPort> FieldPort::MakeUnlockPort(const FletcherSchema &fs,
                                                     const std::shared_ptr<arrow::Field> &field) {
  return std::make_shared<FieldPort>(fs.name() + "_" + field->name() + "_unl",
                                     UNLOCK,
                                     field,
                                     unlock(tag_width(*field)),
                                     Dir::OUT);
}

std::shared_ptr<Node> FieldPort::data_width() {
  std::shared_ptr<Node> width = intl<0>();
  // Flatten the type
  auto flat_type = Flatten(type().get());
  for (const auto &ft : flat_type) {
    if (ft.type_->meta.count("array_data") > 0) {
      if (ft.type_->width()) {
        width = width + *ft.type_->width();
      }
    }
  }
  return width;
}

std::shared_ptr<cerata::Object> FieldPort::Copy() const {
  return std::make_shared<FieldPort>(name(), function_, field_, type(), dir());
}

} // namespace fletchgen