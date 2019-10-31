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

#include "fletchgen/recordbatch.h"

#include <cerata/api.h>
#include <memory>
#include <vector>
#include <utility>

#include "fletchgen/array.h"
#include "fletchgen/bus.h"
#include "fletchgen/schema.h"

namespace fletchgen {

using cerata::Instance;
using cerata::Component;
using cerata::Port;
using cerata::Literal;
using cerata::intl;
using cerata::Term;

RecordBatch::RecordBatch(const std::string &name,
                         const std::shared_ptr<FletcherSchema> &fletcher_schema,
                         fletcher::RecordBatchDescription batch_desc)
    : Component(name),
      fletcher_schema_(fletcher_schema),
      mode_(fletcher_schema->mode()),
      batch_desc_(std::move(batch_desc)) {
  // Get Arrow Schema
  auto as = fletcher_schema_->arrow_schema();

  // Add default port nodes
  Add(port("bcd", cr(), Port::Dir::IN, bus_cd()));
  Add(port("kcd", cr(), Port::Dir::IN, kernel_cd()));

  // Add and connect all array readers and resulting ports
  AddArrays(fletcher_schema);
}

void RecordBatch::AddArrays(const std::shared_ptr<FletcherSchema> &fletcher_schema) {
  // Prepare a rebind map
  cerata::NodeMap rebinding;

  // Add Array type generics.
  auto iw = index_width();
  auto tw = tag_width();
  Add({iw, tw});

  // Iterate over all fields and add ArrayReader/Writer data and control ports.
  for (const auto &field : fletcher_schema->arrow_schema()->fields()) {
    // Name prefix for all sorts of stuff.
    auto prefix = fletcher_schema->name() + "_" + field->name();

    // Check if we must ignore the field
    if (fletcher::GetBoolMeta(*field, fletcher::meta::IGNORE, false)) {
      FLETCHER_LOG(DEBUG, "Ignoring field " + field->name());
    } else {
      FLETCHER_LOG(DEBUG, "Instantiating Array" << (mode_ == Mode::READ ? "Reader" : "Writer")
                                                << " for schema: " << fletcher_schema->name()
                                                << " : " << field->name());
      // Generate a warning for Writers as they are still experimental.
      if (mode_ == Mode::WRITE) {
        FLETCHER_LOG(WARNING, "ArrayWriter implementation is highly experimental. Use with caution! Features that are "
                              "not implemented include:\n"
                              "  - dvalid bit is ignored (so you cannot supply handshakes on the values stream for "
                              "empty lists or use empty handshakes to close streams)\n"
                              "  - lists of primitives (e.g. strings) values stream last signal must signal the last "
                              "value for all lists, not single lists in the Arrow Array).\n"
                              "  - clock domain crossings.");
      }

      // Generate the schema-defined Arrow data port for the kernel.
      // This is the un-concatenated version w.r.t. the streams visible on the Array primitive component.
      auto kernel_arrow_port = arrow_port(fletcher_schema, field, true, kernel_cd());
      auto kernel_arrow_type = kernel_arrow_port->type();
      Add(kernel_arrow_port);

      // Instantiate an ArrayReader/Writer.
      auto a = Instantiate(array(mode_), field->name() + "_inst");
      array_instances_.push_back(a);

      // Generate and set a configuration string for the ArrayReader.
      Connect(a->Get<Parameter>("CFG"), GenerateConfigString(*field));

      // Drive the clocks and resets.
      Connect(a->prt("kcd"), prt("kcd"));
      Connect(a->prt("bcd"), prt("bcd"));

      // Connect some global parameters.
      a->par("CMD_TAG_WIDTH") <<= tw;
      a->par(index_width()) <<= iw;

      // Connect the bus ports.
      ConnectBusPorts(a, prefix, &rebinding);

      // Drive the RecordBatch Arrow data port with the ArrayReader/Writer data port, or vice versa.
      if (mode_ == Mode::READ) {
        auto a_data_port = a->prt("out");
        // Rebind the type because now we know the field (also see array()).
        auto a_data_spec = GetArrayDataSpec(*field);
        auto a_data_type = array_reader_out(a_data_spec.first, a_data_spec.second);
        a_data_port->SetType(a_data_type);
        // Create a mapper between the Arrow port and the Array data port.
        auto mapper = GetStreamTypeMapper(kernel_arrow_type, a_data_type.get());
        kernel_arrow_type->AddMapper(mapper);
        // Connect the ports.
        kernel_arrow_port <<= a_data_port;
      } else {
        auto a_data_port = a->prt("in");
        // Rebind the type because now we know the field (also see array()).
        auto a_data_spec = GetArrayDataSpec(*field);
        auto a_data_type = array_writer_in(a_data_spec.first, a_data_spec.second);
        a_data_port->SetType(a_data_type);
        // Create a mapper between the Arrow port and the Array data port.
        auto mapper = GetStreamTypeMapper(kernel_arrow_type, a_data_type.get());
        kernel_arrow_type->AddMapper(mapper);
        // Connect the ports.
        a_data_port <<= kernel_arrow_port;
      }

      // Get the command stream and unlock stream ports and set their real type and connect.
      auto a_cmd = a->Get<Port>("cmd");
      auto ct = cmd_type(iw,
                         tw,
                         a->par(bus_addr_width())->shared_from_this() * GetCtrlBufferCount(*field));
      a_cmd->SetType(ct);

      auto aw = Get<Parameter>(prefix + "_" + bus_addr_width()->name())->shared_from_this();
      auto cmd = command_port(fletcher_schema, field, iw, tw, aw, kernel_cd());
      Connect(a_cmd, cmd);
      Add(cmd);

      auto a_unl = a->Get<Port>("unl");
      auto ut = unlock_type(a->par("CMD_TAG_WIDTH")->shared_from_this());
      a_unl->SetType(ut);

      auto unl = unlock_port(fletcher_schema, field, tw, kernel_cd());
      Connect(unl, a_unl);
      Add(unl);
    }
  }
}

std::vector<std::shared_ptr<FieldPort>>
RecordBatch::GetFieldPorts(const std::optional<FieldPort::Function> &function) const {
  std::vector<std::shared_ptr<FieldPort>> result;
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

void RecordBatch::ConnectBusPorts(Instance *array, const std::string &prefix, cerata::NodeMap *rebinding) {
  auto a_bus_ports = array->GetAll<BusPort>();
  for (const auto &a_bus_port : a_bus_ports) {
    auto rb_port_prefix = prefix + "_bus";
    auto a_bus_spec = a_bus_port->spec_;
    // Create new bus parameters to bind to and prefix it with the bus name.
    auto rb_bus_params = BusDimParams(this, a_bus_spec.dim.plain, prefix);
    auto rb_bus_spec = BusSpecParams{rb_bus_params, a_bus_spec.func};
    // Copy over the ArrayReader/Writer's bus port
    auto rb_bus_port = bus_port(rb_port_prefix, a_bus_port->dir(), rb_bus_spec);
    // Add them to the RecordBatch
    Add(rb_bus_port);
    // Connect them to the ArrayReader/Writer
    Connect(rb_bus_port, array->prt("bus"));
    // Connect the bus parameters. Array bus port has no prefix.
    ConnectBusParam(array, "", rb_bus_params, rebinding);
  }
}

std::shared_ptr<RecordBatch> record_batch(const std::string &name,
                                          const std::shared_ptr<FletcherSchema> &fletcher_schema,
                                          const fletcher::RecordBatchDescription &batch_desc) {
  auto rb = new RecordBatch(name, fletcher_schema, batch_desc);
  auto shared_rb = std::shared_ptr<RecordBatch>(rb);
  cerata::default_component_pool()->Add(shared_rb);
  return shared_rb;
}

std::shared_ptr<FieldPort> arrow_port(const std::shared_ptr<FletcherSchema> &fletcher_schema,
                                      const std::shared_ptr<arrow::Field> &field,
                                      bool reverse,
                                      const std::shared_ptr<ClockDomain> &domain) {
  auto name = fletcher_schema->name() + "_" + field->name();
  auto type = GetStreamType(*field, fletcher_schema->mode());
  Port::Dir dir;
  if (reverse) {
    dir = Term::Reverse(mode2dir(fletcher_schema->mode()));
  } else {
    dir = mode2dir(fletcher_schema->mode());
  }
  // Check if the Arrow data stream should be profiled. This is disabled by default but can be conveyed through
  // the schema.
  bool profile = fletcher::GetBoolMeta(*field, fletcher::meta::PROFILE, false);

  return std::make_shared<FieldPort>(name, FieldPort::ARROW, field, fletcher_schema, type, dir, domain, profile);
}

std::shared_ptr<FieldPort> command_port(const std::shared_ptr<FletcherSchema> &schema,
                                        const std::shared_ptr<arrow::Field> &field,
                                        const std::shared_ptr<Node> &index_width,
                                        const std::shared_ptr<Node> &tag_width,
                                        std::optional<std::shared_ptr<Node>> addr_width,
                                        const std::shared_ptr<ClockDomain> &domain) {
  std::shared_ptr<cerata::Type> type;
  if (addr_width) {
    type = cmd_type(index_width, tag_width, *addr_width * GetCtrlBufferCount(*field));
  } else {
    type = cmd_type(index_width, tag_width);
  }
  auto name = schema->name() + "_" + field->name() + "_cmd";

  return std::make_shared<FieldPort>(name, FieldPort::COMMAND, field, schema, type, Port::Dir::IN, domain, false);
}

std::shared_ptr<FieldPort> unlock_port(const std::shared_ptr<FletcherSchema> &schema,
                                       const std::shared_ptr<arrow::Field> &field,
                                       const std::shared_ptr<Node> &tag_width,
                                       const std::shared_ptr<ClockDomain> &domain) {
  auto type = unlock_type(tag_width);
  auto name = schema->name() + "_" + field->name() + "_unl";

  return std::make_shared<FieldPort>(name, FieldPort::UNLOCK, field, schema, type, Port::Dir::OUT, domain, false);
}

std::shared_ptr<cerata::Object> FieldPort::Copy() const {
  // Take shared ownership of the type.
  auto typ = type()->shared_from_this();
  auto result = std::make_shared<FieldPort>(name(), function_, field_, fletcher_schema_, typ, dir(), domain_, profile_);
  result->meta = meta;
  return result;
}

}  // namespace fletchgen
