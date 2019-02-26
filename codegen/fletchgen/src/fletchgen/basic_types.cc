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

#include "fletchgen/basic_types.h"

#include <memory>

#include "fletcher/common/arrow-utils.h"

#include "cerata/nodes.h"
#include "cerata/types.h"

namespace fletchgen {

using cerata::Type;
using cerata::Vector;
using cerata::Bit;
using cerata::bit;
using cerata::intl;
using cerata::integer;
using cerata::Clock;
using cerata::Reset;
using cerata::Parameter;
using cerata::RecordField;
using cerata::Record;
using cerata::Stream;

// Create basic types similar to Arrow cpp/type.cc for convenience
#define BIT_FACTORY(NAME)                                               \
  std::shared_ptr<Type> NAME() {                                        \
    static std::shared_ptr<Type> result = std::make_shared<Bit>(#NAME); \
    return result;                                                      \
}

#define VEC_FACTORY(NAME, WIDTH)                                                     \
  std::shared_ptr<Type> NAME() {                                                     \
    static std::shared_ptr<Type> result = Vector::Make(#NAME, bit(), intl<WIDTH>()); \
    return result;                                                                   \
}

BIT_FACTORY(null);
VEC_FACTORY(int8, 8);
VEC_FACTORY(uint8, 8);
VEC_FACTORY(int16, 16);
VEC_FACTORY(uint16, 16);
VEC_FACTORY(int32, 32);
VEC_FACTORY(uint32, 32);
VEC_FACTORY(int64, 64);
VEC_FACTORY(uint64, 64);
VEC_FACTORY(float8, 8);
VEC_FACTORY(float16, 16);
VEC_FACTORY(float32, 32);
VEC_FACTORY(float64, 64);
VEC_FACTORY(date32, 32);
VEC_FACTORY(date64, 64);
VEC_FACTORY(utf8c, 8);
VEC_FACTORY(byte, 8);
VEC_FACTORY(offset, 32);
VEC_FACTORY(length, 32);

#define PARAM_FACTORY(NAME, TYPE, DEFAULT)                    \
std::shared_ptr<Node> NAME() {                                \
  static auto result = Parameter::Make(#NAME, TYPE, DEFAULT); \
  return result;                                              \
}                                                             \

PARAM_FACTORY(bus_addr_width, integer(), intl<64>());
PARAM_FACTORY(bus_data_width, integer(), intl<512>());
PARAM_FACTORY(bus_len_width, integer(), intl<7>());
PARAM_FACTORY(bus_burst_step_len, integer(), intl<4>());
PARAM_FACTORY(bus_burst_max_len, integer(), intl<16>());
PARAM_FACTORY(index_width, integer(), intl<32>());

// Create basic clock domains
std::shared_ptr<ClockDomain> acc_domain() {
  static std::shared_ptr<ClockDomain> result = std::make_shared<ClockDomain>("acc");
  return result;
}

std::shared_ptr<ClockDomain> bus_domain() {
  static std::shared_ptr<ClockDomain> result = std::make_shared<ClockDomain>("acc");
  return result;
}

// Create basic clocks & resets
std::shared_ptr<Type> acc_clk() {
  static std::shared_ptr<Type> result = std::make_shared<Clock>("acc_clk", acc_domain());
  return result;
}

std::shared_ptr<Type> acc_reset() {
  static std::shared_ptr<Type> result = std::make_shared<Reset>("acc_reset", acc_domain());
  return result;
}

std::shared_ptr<Type> bus_clk() {
  static std::shared_ptr<Type> result = std::make_shared<Clock>("bus_clk", acc_domain());
  return result;
}

std::shared_ptr<Type> bus_reset() {
  static std::shared_ptr<Type> result = std::make_shared<Reset>("bus_reset", acc_domain());
  return result;
}

// Data channel

std::shared_ptr<Type> incomplete_data() {
  static std::shared_ptr<Type> result = Vector::Make("data", {});
  return result;
}

std::shared_ptr<Type> dvalid() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("dvalid");
  return result;
}

std::shared_ptr<Type> last() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("last");
  return result;
}

// Bus channel

std::shared_ptr<Type> bus_read_request(std::shared_ptr<Node> addr_width, std::shared_ptr<Node> len_width) {
  static auto bus_addr = RecordField::Make("addr", Vector::Make("addr", addr_width));
  static auto bus_len = RecordField::Make("len", Vector::Make("len", len_width));
  static auto bus_rreq_record = Record::Make("rreq:rec", {bus_addr, bus_len});
  static auto bus_rreq = Stream::Make("rreq:stream", bus_rreq_record);
  return bus_rreq;
}

std::shared_ptr<Type> bus_write_request(std::shared_ptr<Node> addr_width, std::shared_ptr<Node> len_width) {
  static auto bus_addr = RecordField::Make(Vector::Make("addr", addr_width));
  static auto bus_len = RecordField::Make(Vector::Make("len", len_width));
  static auto bus_wreq_record = Record::Make("wreq:rec", {bus_addr, bus_len});
  static auto bus_wreq = Stream::Make("wreq:stream", bus_wreq_record);
  return bus_wreq;
}

std::shared_ptr<Type> bus_read_data(std::shared_ptr<Node> width) {
  auto bus_rdata = RecordField::Make(Vector::Make("data", width));
  auto bus_rlast = RecordField::Make(last());
  auto bus_rdat_record = Record::Make("bus_rdat_rec", {bus_rdata, bus_rlast});
  auto bus_rdat = Stream::Make("bus_rdat", bus_rdat_record);
  return bus_rdat;
}

std::shared_ptr<Type> bus_write_data(std::shared_ptr<Node> width) {
  auto bus_wdata = RecordField::Make(Vector::Make("data", width));
  auto bus_wstrobe = RecordField::Make(Vector::Make("strobe", width / intl<8>()));
  auto bus_wlast = RecordField::Make("last", bit());
  auto bus_wdat_record = Record::Make("bus_wdat_rec", {bus_wdata, bus_wstrobe, bus_wlast});
  auto bus_wdat = Stream::Make("bus_wdat", bus_wdat_record);
  return bus_wdat;
}

std::shared_ptr<Type> cmd() {
  static auto firstidx = RecordField::Make(Vector::Make<32>("firstIdx"));
  static auto lastidx = RecordField::Make(Vector::Make<32>("lastidx"));
  static auto ctrl = RecordField::Make(Vector::Make("ctrl", {}));
  static auto tag = RecordField::Make(Vector::Make<8>("tag"));
  static auto cmd_record = Record::Make("command_rec", {firstidx, lastidx, ctrl, tag});
  static auto cmd_stream = Stream::Make("command", cmd_record);
  return cmd_stream;
}

std::shared_ptr<Type> unlock() {
  static auto tag = Vector::Make<8>("tag");
  static std::shared_ptr<Type> unlock_stream = Stream::Make("unlock", tag, "tag");
  return unlock_stream;
}

std::shared_ptr<Type> read_data() {
  static auto d = RecordField::Make(incomplete_data());
  static auto dv = RecordField::Make(dvalid());
  static auto l = RecordField::Make(last());
  static auto data_record = Record::Make("arrow_read_data_rec", {d, dv, l});
  static auto data_stream = Stream::Make("arrow_read_data", data_record);
  return data_stream;
}

std::shared_ptr<Type> write_data() {
  static auto d = RecordField::Make(incomplete_data());
  static auto l = RecordField::Make(last());
  static auto data_record = Record::Make("arrow_write_data_rec", {d, l});
  static auto data_stream = Stream::Make("arrow_write_data", data_record);
  return data_stream;
}

std::shared_ptr<Type> GenTypeFrom(const std::shared_ptr<arrow::DataType> &arrow_type) {
  switch (arrow_type->id()) {
    case arrow::Type::LIST: return length();
    case arrow::Type::UINT8: return uint8();
    case arrow::Type::UINT16: return uint16();
    case arrow::Type::UINT32: return uint32();
    case arrow::Type::UINT64: return uint64();
    case arrow::Type::INT8: return int8();
    case arrow::Type::INT16: return int16();
    case arrow::Type::INT32: return int32();
    case arrow::Type::INT64: return int64();
    case arrow::Type::HALF_FLOAT: return float16();
    case arrow::Type::FLOAT: return float32();
    case arrow::Type::DOUBLE: return float64();
    default:throw std::runtime_error("Unsupported Arrow DataType: " + arrow_type->ToString());
  }
}

std::shared_ptr<TypeMapper> GetStreamTypeMapper(const std::shared_ptr<Type> &stream_type, fletcher::Mode mode) {
  std::shared_ptr<TypeMapper> conversion;
  if (mode == fletcher::Mode::READ) {
    conversion = std::make_shared<TypeMapper>(stream_type.get(), read_data().get());
  } else {
    conversion = std::make_shared<TypeMapper>(stream_type.get(), write_data().get());
  }

  size_t idx_stream = 0;
  auto idx_data = IndexOfFlatType(conversion->flat_b(), incomplete_data().get());
  auto idx_dvalid = IndexOfFlatType(conversion->flat_b(), dvalid().get());
  auto idx_last = IndexOfFlatType(conversion->flat_b(), last().get());

  auto flat_stream = conversion->flat_a();
  for (size_t i = 0; i < flat_stream.size(); i++) {
    auto t = flat_stream[i].type_;
    if (t->Is(Type::STREAM)) {
      conversion->Add(i, idx_stream);
    } else if (t == dvalid().get()) {
      conversion->Add(i, idx_dvalid);
    } else if (t == last().get()) {
      conversion->Add(i, idx_last);
    } else if (t->Is(Type::RECORD)) {
      // do nothing
    } else {
      // If it's not any of the default control signals on the stream, it must be data.
      conversion->Add(i, idx_data);
    }
  }
  return conversion;
}

std::shared_ptr<Type> GetStreamType(const std::shared_ptr<arrow::Field> &field, fletcher::Mode mode, int level) {
  // The ordering of the record fields in this function determines the order in which a nested stream is type converted
  // automatically using GetStreamTypeConverter. This corresponds to how the hardware is implemented. Do not touch.
  
  int epc = fletcher::getEPC(field);

  std::shared_ptr<Type> type;

  auto arrow_id = field->type()->id();
  auto name = field->name();

  switch (arrow_id) {

    case arrow::Type::BINARY: {
      // Special case: binary type has a length stream and bytes stream.
      // The EPC is assumed to relate to the list elements,
      // as there is no explicit child field to place this metadata in.
      auto slave = Stream::Make(name,
                                Record::Make("data", {
                                    RecordField::Make("dvalid", dvalid()),
                                    RecordField::Make("last", last()),
                                    RecordField::Make("data", byte())}),
                                "data", epc);
      type = Record::Make(name + "_rec", {
          RecordField::Make("length", length()),
          RecordField::Make("bytes", slave)
      });
      break;
    }

    case arrow::Type::STRING: {
      // Special case: string type has a length stream and utf8 character stream.
      // The EPC is assumed to relate to the list elements,
      // as there is no explicit child field to place this metadata in.
      auto slave = Stream::Make(name,
                                Record::Make("data", {
                                    RecordField::Make("dvalid", dvalid()),
                                    RecordField::Make("last", last()),
                                    RecordField::Make("data", utf8c())}),
                                "data", epc);
      type = Record::Make(name + "_rec", {
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
      auto element_type = GetStreamType(arrow_child, mode, level + 1);
      auto slave = Stream::Make(name,
                                Record::Make("data", {
                                    RecordField::Make("dvalid", dvalid()),
                                    RecordField::Make("last", last()),
                                    RecordField::Make("data", element_type)}),
                                "data", epc);
      type = Record::Make(name + "_rec", {
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
        auto child_type = GetStreamType(f, mode, level + 1);
        children.push_back(RecordField::Make(f->name(), child_type));
      }
      type = Record::Make(name + "_rec", children);
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
    if (!type->IsNested()) {
      elements_name = "data";
    }
    // Create the stream record
    auto record = Record::Make("data", {
        RecordField::Make("dvalid", dvalid()),
        RecordField::Make("last", last()),
        RecordField::Make(elements_name, type)});
    auto stream = Stream::Make(name, record, elements_name);
    stream->AddMapper(GetStreamTypeMapper(stream, mode));
    return stream;
  } else {
    // Otherwise just return the type
    return type;
  }
}

}  // namespace fletchgen
