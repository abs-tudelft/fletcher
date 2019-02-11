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

#include "./fletcher_components.h"

#include <arrow/api.h>
#include <memory>
#include <deque>
#include <utility>

#include "./edges.h"
#include "./nodes.h"
#include "./fletcher_types.h"

#include "../../../common/cpp/src/fletcher/common/arrow-utils.h"

namespace fletchgen {

static Port::Dir mode2dir(fletcher::Mode mode) {
  if (mode == fletcher::Mode::READ) {
    return Port::Dir::IN;
  } else {
    return Port::Dir::OUT;
  }
}

ArrowPort::ArrowPort(std::string name, std::shared_ptr<arrow::Field> field, fletcher::Mode mode, Port::Dir dir)
    : Port(std::move(name), GetStreamType(field, mode), dir), field_(std::move(field)) {}

std::shared_ptr<ArrowPort> ArrowPort::Make(std::shared_ptr<arrow::Field> field, fletcher::Mode mode, Port::Dir dir) {
  return std::make_shared<ArrowPort>(field->name(), field, mode, dir);
}

std::shared_ptr<SchemaSet> SchemaSet::Make(std::string name, std::deque<std::shared_ptr<arrow::Schema>> schema_list) {
  return std::make_shared<SchemaSet>(name, schema_list);
}

std::shared_ptr<Component> BusReadArbiter() {
  auto nslaves = Parameter::Make("NUM_SLAVE_PORTS", integer(), intl<0>());
  auto slaves_rreq_array = ArrayPort::Make("bsv_rreq", bus_read_request(), nslaves, Port::Dir::IN);
  auto slaves_rdat_array = ArrayPort::Make("bsv_rdat", bus_read_data(), nslaves, Port::Dir::OUT);

  static auto ret = Component::Make("BusReadArbiterVec",
                                    {bus_addr_width(),
                                     bus_len_width(),
                                     bus_data_width(),
                                     nslaves,
                                     Parameter::Make("ARB_METHOD", string(), strl("ROUND-ROBIN")),
                                     Parameter::Make("MAX_OUTSTANDING", integer(), intl<4>()),
                                     Parameter::Make("RAM_CONFIG", string(), strl("")),
                                     Parameter::Make("SLV_REQ_SLICES", boolean(), bool_true()),
                                     Parameter::Make("MST_REQ_SLICE", boolean(), bool_true()),
                                     Parameter::Make("MST_DAT_SLICE", boolean(), bool_true()),
                                     Parameter::Make("SLV_DAT_SLICES", boolean(), bool_true())},
                                    {Port::Make(bus_clk()),
                                     Port::Make(bus_reset()),
                                     Port::Make("mst_rreq", bus_read_request(), Port::Dir::OUT),
                                     Port::Make("mst_rdat", bus_read_data(), Port::Dir::IN),
                                     slaves_rreq_array,
                                     slaves_rdat_array
                                    },
                                    {});
  return ret;
};

std::shared_ptr<Component> ColumnReader() {
  static auto ret = Component::Make("ColumnReader",
                                    {bus_addr_width(), bus_len_width(), bus_data_width(),
                                     Parameter::Make("BUS_BURST_STEP_LEN", integer(), intl<4>()),
                                     Parameter::Make("BUS_BURST_MAX_LEN", integer(), intl<16>()),
                                     Parameter::Make("INDEX_WIDTH", integer(), intl<32>()),
                                     Parameter::Make("CFG", string(), strl("\"\"")),
                                     Parameter::Make("CMD_TAG_ENABLE", boolean(), bool_false()),
                                     Parameter::Make("CMD_TAG_WIDTH", integer(), intl<1>())},
                                    {Port::Make(bus_clk()),
                                     Port::Make(bus_reset()),
                                     Port::Make(acc_clk()),
                                     Port::Make(acc_reset()),
                                     Port::Make("cmd", cmd(), Port::Dir::IN),
                                     Port::Make("unlock", unlock(), Port::Dir::OUT),
                                     Port::Make("bus_rreq", bus_read_request(), Port::Dir::OUT),
                                     Port::Make("bus_rdat", bus_read_data(), Port::Dir::IN),
                                     Port::Make("out", read_data(), Port::Dir::OUT)
                                    },
                                    {}
  );
  return ret;
}

UserCore::UserCore(std::string name, std::shared_ptr<SchemaSet> schema_set)
    : Component(std::move(name)), schema_set_(std::move(schema_set)) {
  for (const auto &s : schema_set_->schema_list_) {
    auto mode = fletcher::getMode(s);
    for (const auto &f : s->fields()) {
      if (!fletcher::mustIgnore(f)) {
        AddNode(ArrowPort::Make(f, mode, mode2dir(mode)));
        AddNode(Port::Make(f->name() + "_cmd", cmd(), Port::OUT));
      }
    }
  }
}

std::shared_ptr<UserCore> UserCore::Make(std::shared_ptr<SchemaSet> schema_set) {
  return std::make_shared<UserCore>("uc_" + schema_set->name(), schema_set);
}

std::shared_ptr<ArrowPort> UserCore::GetArrowPort(std::shared_ptr<arrow::Field> field) {
  for (const auto &n : nodes_) {
    auto ap = Cast<ArrowPort>(n);
    if (ap) {
      if ((*ap)->field_ == field) {
        return *ap;
      }
    }
  }
  throw std::runtime_error("Field " + field->name() + " did not generate an ArrowPort for UserCore " + name() + ".");
}
std::deque<std::shared_ptr<ArrowPort>> UserCore::GetAllArrowPorts() {
  std::deque<std::shared_ptr<ArrowPort>> result;
  for (const auto &n : nodes_) {
    auto ap = Cast<ArrowPort>(n);
    if (ap) {
      result.push_back(*ap);
    }
  }
  return result;
}

FletcherCore::FletcherCore(std::string name, const std::shared_ptr<SchemaSet> &schema_set)
    : Component(std::move(name)), schema_set_(schema_set) {

  // Create and instantiate a UserCore
  user_core_ = UserCore::Make(schema_set_);
  user_core_inst_ = Instance::Make(user_core_);
  AddChild(user_core_inst_);

  // Connect Fields
  auto arrow_ports = user_core_->GetAllArrowPorts();

  // Instantiate ColumnReaders/Writers for each field.
  for (const auto &p : arrow_ports) {
    if (p->dir == Port::IN) {
      auto cr_inst = Instance::Make(p->field_->name() + "_cr_inst", ColumnReader());
      column_readers.push_back(cr_inst);
      AddChild(cr_inst);
    } else {
      // TODO(johanpel): ColumnWriters
    }
  }

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

  auto num_read_slaves = Parameter::Make("NUM_READ_SLAVES", integer(), intl<0>());
  auto bus_rreq_array = ArrayPort::Make("bus_rreq", bus_read_request(), num_read_slaves, Port::Dir::OUT);
  auto bus_rdat_array = ArrayPort::Make("bus_rdat", bus_read_data(), num_read_slaves, Port::Dir::IN);

  auto num_write_slaves = Parameter::Make("NUM_WRITE_SLAVES", integer(), intl<0>());
  auto bus_wreq_array = ArrayPort::Make("bus_wreq", bus_write_request(), num_write_slaves, Port::Dir::OUT);
  auto bus_wdat_array = ArrayPort::Make("bus_wdat", bus_write_data(), num_write_slaves, Port::Dir::OUT);

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

std::shared_ptr<FletcherCore> FletcherCore::Make(std::string name, const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<FletcherCore>(name, schema_set);
}

std::shared_ptr<FletcherCore> FletcherCore::Make(const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<FletcherCore>("FletcherCore:" + schema_set->name(), schema_set);
}

} // namespace fletchgen
