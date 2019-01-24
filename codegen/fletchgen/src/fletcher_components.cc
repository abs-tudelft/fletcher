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

namespace fletchgen {

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
  TypeList stream_types;
  ArrowFieldList arrow_fields;
  for (const auto &s : schema_set_->schema_list_) {
    for (const auto &f : s->fields()) {
      if (!fletcher::mustIgnore(f)) {
        auto type = GetStreamType(f);
        stream_types.push_back(type);
        arrow_fields.push_back(f);
      }
    }
  }
  for (size_t f = 0; f < stream_types.size(); f++) {
    auto port_name = arrow_fields[f]->name();
    Add(Port::Make(port_name, stream_types[f]));
  }
}

std::shared_ptr<UserCore> UserCore::Make(std::shared_ptr<SchemaSet> schema_set) {
  std::shared_ptr<UserCore> ret = std::make_shared<UserCore>("UserCore", schema_set);
  return ret;
}

FletcherCore::FletcherCore(std::string name, const std::shared_ptr<SchemaSet>& schema_set)
    : Component(std::move(name)), schema_set_(schema_set) {

  user_core_ = UserCore::Make(schema_set_);
  user_core_inst_ = Instance::Make(schema_set_->name(), user_core_);
  Add(user_core_inst_);

  for (const auto &s : schema_set_->schema_list_) {
    if (fletcher::getMode(s) == fletcher::Mode::READ) {
      for (const auto &f : s->fields()) {
        auto cr_inst = Instance::Make(f->name() + "_cr_inst", ColumnReader());
        column_readers.push_back(cr_inst);
        Add(cr_inst);
      }
    } else {
      // TODO(johanpel): ColumnWriters
    }
  }

  // Connect Fields
  auto uc_ports = user_core_inst_->GetAll<Port>();
  for (size_t i = 0; i < uc_ports.size(); i++) {
    if (uc_ports[i]->IsInput()) {
      auto data_stream = column_readers[i]->Get(Node::PORT, "data_out");
      auto uc_port = uc_ports[i];
      uc_port <<= data_stream;
    }
  }
}

std::shared_ptr<FletcherCore> FletcherCore::Make(std::string name, const std::shared_ptr<SchemaSet>& schema_set) {
  return std::make_shared<FletcherCore>(name, schema_set);
}

std::shared_ptr<FletcherCore> FletcherCore::Make(const std::shared_ptr<SchemaSet>& schema_set) {
  return std::make_shared<FletcherCore>("FletcherCore:" + schema_set->name(), schema_set);
}

}