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

#include "./fletcher_types.h"

#include <memory>

#include "./nodes.h"
#include "./types.h"

namespace fletchgen {

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

std::shared_ptr<Type> dvalid() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("dvalid");
  return result;
}

std::shared_ptr<Type> last() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("last");
  return result;
}

// Bus channel

std::shared_ptr<Type> bus_read_request() {
  static auto bus_addr = RecordField::Make("addr", Vector::Make("addr", bus_addr_width()));
  static auto bus_len = RecordField::Make("len", Vector::Make("len", bus_len_width()));
  static auto bus_rreq_record = Record::Make("rreq:rec", {bus_addr, bus_len});
  static auto bus_rreq = Stream::Make("rreq:stream", bus_rreq_record);
  return bus_rreq;
}

std::shared_ptr<Type> bus_write_request() {
  static auto bus_addr = RecordField::Make(Vector::Make("addr", bus_addr_width()));
  static auto bus_len = RecordField::Make(Vector::Make("len", bus_len_width()));
  static auto bus_wreq_record = Record::Make("wreq:rec", {bus_addr, bus_len});
  static auto bus_wreq = Stream::Make("wreq:stream", bus_wreq_record);
  return bus_wreq;
}

std::shared_ptr<Type> bus_read_data() {
  static auto bus_rdata = RecordField::Make(Vector::Make("data", bus_data_width()));
  static auto bus_rlast = RecordField::Make("last", bit());
  static auto bus_rdat_record = Record::Make("rdat:rec", {bus_rdata, bus_rlast});
  static auto bus_rdat = Stream::Make("rdat:stream", bus_rdat_record);
  return bus_rdat;
}

std::shared_ptr<Type> bus_write_data() {
  static auto bus_wdata = RecordField::Make(Vector::Make("data", bus_data_width()));
  static auto bus_wstrobe = RecordField::Make(Vector::Make("strobe", bus_data_width() / intl<8>()));
  static auto bus_wlast = RecordField::Make("last", bit());
  static auto bus_wdat_record = Record::Make("wdat:rec", {bus_wdata, bus_wstrobe, bus_wlast});
  static auto bus_wdat = Stream::Make("wdat:stream", bus_wdat_record);
  return bus_wdat;
}

std::shared_ptr<Type> cmd() {
  static auto firstidx = RecordField::Make(Vector::Make<64>("firstIdx"));
  static auto lastidx = RecordField::Make(Vector::Make<64>("lastidx"));
  static auto ctrl = RecordField::Make(Vector::Make<64>("ctrl"));
  static auto tag = RecordField::Make(Vector::Make<8>("tag"));
  static auto cmd_record = Record::Make("cmd:rec", {firstidx, lastidx, ctrl, tag});
  static auto cmd_stream = Stream::Make("cmd:stream", cmd_record);
  return cmd_stream;
}

std::shared_ptr<Type> unlock() {
  static auto tag = Vector::Make<8>("tag");
  static std::shared_ptr<Type> unlock_stream = Stream::Make("unlock:stream", tag, "tag");
  return unlock_stream;
}

std::shared_ptr<Type> read_data() {
  static auto d = RecordField::Make(Vector::Make("data", {}));
  static auto dv = RecordField::Make(dvalid());
  static auto l = RecordField::Make("last", bit());
  static auto data_record = Record::Make("data:rec", {d, dv, l});
  static auto data_stream = Stream::Make("data:stream", data_record);
  return data_stream;
}

std::shared_ptr<Type> write_data() {
  static auto d = RecordField::Make(Vector::Make<64>("data"));
  static auto l = RecordField::Make("last", bit());
  static auto data_record = Record::Make("data:rec", {d, l});
  static auto data_stream = Stream::Make("data:stream", data_record);
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

}  // namespace fletchgen
