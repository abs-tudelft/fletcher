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

#include "fletchgen/mantle.h"

#include <arrow/api.h>
#include <memory>
#include <deque>
#include <utility>

#include "fletcher/common/arrow-utils.h"

#include "cerata/edges.h"
#include "cerata/nodes.h"

#include "fletchgen/basic_types.h"
#include "fletchgen/array.h"
#include "fletchgen/schema.h"

namespace fletchgen {

Mantle::Mantle(std::string name, const std::shared_ptr<SchemaSet> &schema_set)
    : Component(std::move(name)), schema_set_(schema_set) {

  // Create and instantiate a Core
  user_core_ = Kernel::Make(schema_set_);
  auto ucinst = Instance::Make(user_core_);
  user_core_inst_ = ucinst.get();
  AddChild(std::move(ucinst));

  // Connect Fields
  auto arrow_ports = user_core_->GetAllArrowPorts();

  // Instantiate ColumnReaders/Writers for each field.
  for (const auto &p : arrow_ports) {
    if (p->dir() == Port::IN) {
      auto cr_inst = Instance::Make(p->field_->name() + "_cr_inst", ArrayReader());
      auto config_node = cr_inst->GetNode(Node::PARAMETER, "CFG");
      config_node <<=
          cerata::Literal::Make(p->field_->name() + "_cfgstr", cerata::string(), GenerateConfigString(p->field_));
      column_readers.push_back(cr_inst.get());
      AddChild(std::move(cr_inst));
    } else {
      // TODO(johanpel): ColumnWriters
    }
  }

  // Connect all Arrow data ports to the Core
  for (size_t i = 0; i < arrow_ports.size(); i++) {
    if (arrow_ports[i]->IsInput()) {
      // Get the user core instance ports
      auto uci_data_port = user_core_inst_->port(arrow_ports[i]->name());
      auto uci_cmd_port = user_core_inst_->port(arrow_ports[i]->name() + "_cmd");
      // Get the column reader ports
      auto cr_data_port = column_readers[i]->port("out");
      auto cr_cmd_port = column_readers[i]->port("cmd");
      // Connect the ports
      uci_data_port <<= cr_data_port;
      cr_cmd_port <<= uci_cmd_port;
    } else {
      // TODO(johanpel): ColumnWriters
      // TODO(johanpel): ColumnWriters
    }
  }

  auto num_read_slaves = cerata::Parameter::Make("NUM_READ_SLAVES", cerata::integer(), cerata::intl<0>());
  auto bus_rreq_array = cerata::PortArray::Make("bus_rreq", bus_read_request(), num_read_slaves, Port::Dir::OUT);
  auto bus_rdat_array = cerata::PortArray::Make("bus_rdat", bus_read_data(), num_read_slaves, Port::Dir::IN);

  auto num_write_slaves = cerata::Parameter::Make("NUM_WRITE_SLAVES", cerata::integer(), cerata::intl<0>());
  auto bus_wreq_array = cerata::PortArray::Make("bus_wreq", bus_write_request(), num_write_slaves, Port::Dir::OUT);
  auto bus_wdat_array = cerata::PortArray::Make("bus_wdat", bus_write_data(), num_write_slaves, Port::Dir::OUT);

  AddObject(num_read_slaves);
  AddObject(bus_rreq_array);
  AddObject(bus_rdat_array);

  AddObject(num_write_slaves);
  AddObject(bus_wreq_array);
  AddObject(bus_wdat_array);

  for (const auto &cr : column_readers) {
    auto cr_rreq = cr->port("bus_rreq");
    auto cr_rdat = cr->port("bus_rdat");
    bus_rreq_array->Append() <<= cr_rreq;
    cr_rdat <<= bus_rdat_array->Append();
  }

  for (const auto &cw : column_writers) {
    auto cw_wreq = cw->port("bus_wreq");
    auto cw_wdat = cw->port("bus_wdat");
    bus_wreq_array->Append() <<= cw_wreq;
    bus_wdat_array->Append() <<= cw_wdat;
  }
}

std::shared_ptr<Mantle> Mantle::Make(std::string name, const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<Mantle>(name, schema_set);
}

std::shared_ptr<Mantle> Mantle::Make(const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<Mantle>(schema_set->name() + "_mantle", schema_set);
}

}  // namespace fletchgen
