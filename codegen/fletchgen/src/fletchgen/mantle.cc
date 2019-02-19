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
#include "fletchgen/column.h"
#include "fletchgen/schema.h"

namespace fletchgen {

Mantle::Mantle(std::string name, const std::shared_ptr<SchemaSet> &schema_set)
    : Component(std::move(name)), schema_set_(schema_set) {

  // Create and instantiate a Core
  user_core_ = Core::Make(schema_set_);
  user_core_inst_ = Instance::Make(user_core_);
  AddChild(user_core_inst_);

  // Connect Fields
  auto arrow_ports = user_core_->GetAllArrowPorts();

  // Instantiate ColumnReaders/Writers for each field.
  for (const auto &p : arrow_ports) {
    if (p->dir == Port::IN) {
      auto cr_inst = Instance::Make(p->field_->name() + "_cr_inst", ColumnReader());
      auto config_node = cr_inst->Get(Node::PARAMETER, "CFG");
      config_node <<= cerata::strl(GenerateConfigString(p->field_));
      column_readers.push_back(cr_inst);
      AddChild(cr_inst);
    } else {
      // TODO(johanpel): ColumnWriters
    }
  }

  // Connect all Arrow data ports to the Core
  for (size_t i = 0; i < arrow_ports.size(); i++) {
    if (arrow_ports[i]->IsInput()) {
      // Get the user core instance ports
      auto uci_data_port = user_core_inst_->p(arrow_ports[i]->name());
      auto uci_cmd_port = user_core_inst_->p(arrow_ports[i]->name() + "_cmd");
      // Get the column reader ports
      auto cr_data_port = column_readers[i]->p("out");
      auto cr_cmd_port = column_readers[i]->p("cmd");
      // Connect the ports
      uci_data_port <<= cr_data_port;
      cr_cmd_port <<= uci_cmd_port;
    } else {
      // TODO(johanpel): ColumnWriters
      // TODO(johanpel): ColumnWriters
    }
  }

  auto num_read_slaves = cerata::Parameter::Make("NUM_READ_SLAVES", cerata::integer(), cerata::intl<0>());
  auto bus_rreq_array = cerata::ArrayPort::Make("bus_rreq", bus_read_request(), num_read_slaves, Port::Dir::OUT);
  auto bus_rdat_array = cerata::ArrayPort::Make("bus_rdat", bus_read_data(), num_read_slaves, Port::Dir::IN);

  auto num_write_slaves = cerata::Parameter::Make("NUM_WRITE_SLAVES", cerata::integer(), cerata::intl<0>());
  auto bus_wreq_array = cerata::ArrayPort::Make("bus_wreq", bus_write_request(), num_write_slaves, Port::Dir::OUT);
  auto bus_wdat_array = cerata::ArrayPort::Make("bus_wdat", bus_write_data(), num_write_slaves, Port::Dir::OUT);

  AddNode(num_read_slaves);
  AddNode(bus_rreq_array);
  AddNode(bus_rdat_array);

  AddNode(num_write_slaves);
  AddNode(bus_wreq_array);
  AddNode(bus_wdat_array);

  for (const auto &cr : column_readers) {
    auto cr_rreq = cr->p("bus_rreq");
    auto cr_rdat = cr->p("bus_rdat");
    bus_rreq_array <<= cr_rreq;
    cr_rdat <<= bus_rdat_array;
  }

  for (const auto &cw : column_writers) {
    auto cr_wreq = cw->p("bus_wreq");
    auto cr_wdat = cw->p("bus_wdat");
    bus_wreq_array <<= cr_wreq;
    bus_wdat_array <<= cr_wdat;
  }
}

std::shared_ptr<Mantle> Mantle::Make(std::string name, const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<Mantle>(name, schema_set);
}

std::shared_ptr<Mantle> Mantle::Make(const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<Mantle>("FletcherCore:" + schema_set->name(), schema_set);
}

}  // namespace fletchgen
