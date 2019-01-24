#include <utility>

#include <utility>

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

#include "./edges.h"
#include "./nodes.h"
#include "./fletcher_types.h"

#include "../../../common/cpp/src/fletcher/common/arrow-utils.h"
#include "fletcher_components.h"

namespace fletchgen {

static Port::Dir mode2dir(fletcher::Mode mode) {
  if (mode == fletcher::Mode::READ) {
    return Port::Dir::IN;
  } else {
    return Port::Dir::OUT;
  }
}

ArrowPort::ArrowPort(std::string name, std::shared_ptr<arrow::Field> field, Port::Dir dir)
    : Port(std::move(name), GetStreamType(field), dir), field_(field) {}

std::shared_ptr<ArrowPort> ArrowPort::Make(std::shared_ptr<arrow::Field> field, Port::Dir dir) {
  return std::make_shared<ArrowPort>(field->name(), field, dir);
}

std::shared_ptr<SchemaSet> SchemaSet::Make(std::string name, std::deque<std::shared_ptr<arrow::Schema>> schema_list) {
  return std::make_shared<SchemaSet>(name, schema_list);
}

std::shared_ptr<Component> BusReadArbiter() {
  static auto ret = Component::Make("BusReadArbiterVec",
                                    {Parameter::Make("BUS_ADDR_WIDTH", natural(), litint<32>()),
                                     Parameter::Make("BUS_LEN_WIDTH", natural(), litint<32>()),
                                     Parameter::Make("BUS_DATA_WIDTH", natural(), litint<32>()),
                                     Parameter::Make("NUM_SLAVE_PORTS", natural(), litint<32>()),
                                     Parameter::Make("ARB_METHOD", string(), Literal::Make("ROUND-ROBIN")),
                                     Parameter::Make("MAX_OUTSTANDING", natural(), litint<2>()),
                                     Parameter::Make("RAM_CONFIG", string(), Literal::Make("")),
                                     Parameter::Make("SLV_REQ_SLICES", boolean(), bool_true()),
                                     Parameter::Make("MST_REQ_SLICE", boolean(), bool_true()),
                                     Parameter::Make("MST_DAT_SLICE", boolean(), bool_true()),
                                     Parameter::Make("SLV_DAT_SLICES", boolean(), bool_true())},
                                    {Port::Make(bus_clk()),
                                     Port::Make(bus_reset()),
                                     Port::Make("mst_rreq", bus_read_request(), Port::Dir::OUT),
                                     Port::Make("mst_rdat", bus_read_data(), Port::Dir::IN),
                                     Port::Make("bsv_rreq", bus_read_request(), Port::Dir::IN),
                                     Port::Make("bsv_rdat", bus_read_data(), Port::Dir::OUT)
                                    },
                                    {});
  return ret;
};

std::shared_ptr<Component> ColumnReader() {
  static auto ret = Component::Make("ColumnReader",
                                    {Parameter::Make("BUS_ADDR_WIDTH", natural(), litint<32>()),
                                     Parameter::Make("BUS_LEN_WIDTH", natural(), litint<8>()),
                                     Parameter::Make("BUS_DATA_WIDTH", natural(), litint<32>()),
                                     Parameter::Make("BUS_BURST_STEP_LEN", natural(), litint<4>()),
                                     Parameter::Make("BUS_BURST_MAX_LEN", natural(), litint<16>()),
                                     Parameter::Make("INDEX_WIDTH", natural(), litint<32>()),
                                     Parameter::Make("CFG", string(), litstr("")),
                                     Parameter::Make("CMD_TAG_ENABLE", boolean(), bool_false()),
                                     Parameter::Make("CMD_TAG_WIDTH", natural(), litint<1>())},
                                    {Port::Make(bus_clk()),
                                     Port::Make(bus_reset()),
                                     Port::Make(acc_clk()),
                                     Port::Make(acc_reset()),
                                     Port::Make("cmd", cmd(), Port::Dir::IN),
                                     Port::Make("unlock", unlock(), Port::Dir::OUT),
                                     Port::Make("bus_rreq", bus_read_request(), Port::Dir::OUT),
                                     Port::Make("bus_rdat", bus_read_data(), Port::Dir::IN),
                                     Port::Make("data_out", read_data(), Port::Dir::OUT)
                                    },
                                    {}
  );
  return ret;
}

std::shared_ptr<Type> GetStreamType(const std::shared_ptr<arrow::Field> &field, int level) {
  int epc = fletcher::getEPC(field);

  std::shared_ptr<Type> type = nullptr;

  auto arrow_id = field->type()->id();
  auto name = field->name();

  switch (arrow_id) {

    case arrow::Type::BINARY: {
      // Special case: binary type has a length stream and bytes stream.
      // The EPC is assumed to relate to the list elements,
      // as there is no explicit child field to place this metadata in.
      auto slave = Stream::Make(name + ":stream", byte(), "data", epc);
      type = Record::Make(name + ":binary", {
          RecordField::Make("length", length()),
          RecordField::Make("bytes", slave)
      });
      break;
    }

    case arrow::Type::STRING: {
      // Special case: string type has a length stream and utf8 character stream.
      // The EPC is assumed to relate to the list elements,
      // as there is no explicit child field to place this metadata in.
      auto slave = Stream::Make(name + ":stream", utf8c(), "data", epc);
      type = Record::Make(name + ":string", {
          RecordField::Make("length", length()),
          RecordField::Make("chars", slave)
      });
      break;
    }

      // Lists
    case arrow::Type::LIST: {
      if (field->type()->num_children() != 1) {
        throw std::runtime_error("Encountered Arrow list type with other than 1 child.");
      }

      auto arrow_child = field->type()->child(0);
      auto element_type = GetStreamType(arrow_child, level + 1);
      auto slave = Stream::Make(arrow_child->name() + ":stream", element_type, "data");
      type = Record::Make(name + ":list", {
          RecordField::Make(length()),
          RecordField::Make(arrow_child->name(), slave)
      });
      break;
    }

      // Structs
    case arrow::Type::STRUCT: {
      if (field->type()->num_children() < 1) {
        throw std::runtime_error("Encountered Arrow struct type without any children.");
      }
      std::deque<std::shared_ptr<RecordField>> children;
      for (const auto &f : field->type()->children()) {
        auto child_type = GetStreamType(f, level + 1);
        children.push_back(RecordField::Make(f->name(), child_type));
      }
      type = Record::Make(name + ":struct", children);
      break;
    }

      // Non-nested types
    default: {
      type = GenTypeFrom(field->type());
      break;
    }
  }

  // If this is a top level field, create a stream out of it
  if (level == 0) {
    // Element name is empty by default.
    std::string elements_name;
    // Check if the type is nested. If it is not nested, the give the elements the name "data"
    if (!IsNested(type)) {
      elements_name = "data";
    }
    // Create the stream
    auto stream = Stream::Make(name + ":stream", type, elements_name);
    return stream;
  } else {
    // Otherwise just return the type
    return type;
  }
}

UserCore::UserCore(std::string name, std::shared_ptr<SchemaSet> schema_set)
    : Component(std::move(name)), schema_set_(std::move(schema_set)) {
  for (const auto &s : schema_set_->schema_list_) {
    for (const auto &f : s->fields()) {
      if (!fletcher::mustIgnore(f)) {
        Add(ArrowPort::Make(f, mode2dir(fletcher::getMode(s))));
        Add(Port::Make("cmd_" + f->name(), cmd(), Port::OUT));
      }
    }
  }
}

std::shared_ptr<UserCore> UserCore::Make(std::shared_ptr<SchemaSet> schema_set) {
  return std::make_shared<UserCore>("UserCore_" + schema_set->name(), schema_set);
}

std::shared_ptr<ArrowPort> UserCore::GetArrowPort(std::shared_ptr<arrow::Field> field) {
  for (const auto &n : nodes) {
    auto ap = Cast<ArrowPort>(n);
    if (ap != nullptr) {
      if (ap->field_ == field) {
        return ap;
      }
    }
  }
  throw std::runtime_error("Field " + field->name() + " did not generate an ArrowPort for UserCore " + name() + ".");
}
std::deque<std::shared_ptr<ArrowPort>> UserCore::GetAllArrowPorts() {
  std::deque<std::shared_ptr<ArrowPort>> result;
  for (const auto &n : nodes) {
    auto ap = Cast<ArrowPort>(n);
    if (ap != nullptr) {
      result.push_back(ap);
    }
  }
  return result;
}

FletcherCore::FletcherCore(std::string name, const std::shared_ptr<SchemaSet> &schema_set)
    : Component(std::move(name)), schema_set_(schema_set) {

  // Create and instantiate a UserCore
  user_core_ = UserCore::Make(schema_set_);
  user_core_inst_ = Instance::Make(user_core_);
  Add(user_core_inst_);

  // Instantiate ColumnReaders/Writers for each field.
  for (const auto &p : user_core_->GetAllArrowPorts()) {
    if (p->dir == Port::IN) {
      auto cr_inst = Instance::Make(p->field_->name() + "_cr_inst", ColumnReader());
      column_readers.push_back(cr_inst);
      Add(cr_inst);
    } else {
      // TODO(johanpel): ColumnWriters
    }
  }

  // Connect Fields
  auto arrow_ports = user_core_->GetAllArrowPorts();
  for (size_t i = 0; i < arrow_ports.size(); i++) {
    if (arrow_ports[i]->IsInput()) {
      // Get the user core instance ports
      auto uci_data_port = user_core_inst_->Get(Node::PORT, arrow_ports[i]->name());
      auto uci_cmd_port = user_core_inst_->Get(Node::PORT, "cmd_" + arrow_ports[i]->name());

      // Get the column reader ports
      auto cr_data_port = column_readers[i]->Get(Node::PORT, "data_out");
      auto cr_cmd_port = column_readers[i]->Get(Node::PORT, "cmd");

      // Connect the ports
      uci_data_port <<= cr_data_port;
      cr_cmd_port <<= uci_cmd_port;
    } else {
      // TODO(johanpel): ColumnWriters
    }
  }

  // Add and connect request and data channels
  auto brr = Port::Make("bus_rreq", bus_read_request());
  auto brd = Port::Make("bus_rdat", bus_read_data());
  auto bwr = Port::Make("bus_wreq", bus_write_request());
  auto bwd = Port::Make("bus_wdat", bus_write_data());

  Add(brr).Add(brd).Add(bwr).Add(bwd);

  for (const auto &cr: column_readers) {
    auto cr_rreq = cr->Get(Node::PORT, "bus_rreq");
    auto cr_rdat = cr->Get(Node::PORT, "bus_rdat");
    brr <<= cr_rreq;
    cr_rdat <<= brd;
  }

  for (const auto &cw: column_writers) {
    auto cr_wreq = cw->Get(Node::PORT, "bus_wreq");
    auto cr_wdat = cw->Get(Node::PORT, "bus_wdat");
    bwr <<= cr_wreq;
    bwd <<= cr_wdat;
  }
}

std::shared_ptr<FletcherCore> FletcherCore::Make(std::string name, const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<FletcherCore>(name, schema_set);
}

std::shared_ptr<FletcherCore> FletcherCore::Make(const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<FletcherCore>("FletcherCore:" + schema_set->name(), schema_set);
}

}