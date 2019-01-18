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

#include "./nodes.h"
#include "./types.h"

#include "./fletcher_types.h"

namespace fletchgen {

// Create basic types similar to Arrow cpp/type.cc for convenience
#define BIT_FACTORY(NAME)                                               \
  std::shared_ptr<Type> NAME() {                                        \
    static std::shared_ptr<Type> result = std::make_shared<Bit>(#NAME); \
    return result;                                                      \
}

#define VEC_FACTORY(NAME, WIDTH)                                      \
  std::shared_ptr<Type> NAME() {                                      \
    static std::shared_ptr<Type> result = Vector::Make(#NAME, lit<WIDTH>()); \
    return result;                                                    \
}

BIT_FACTORY(bit);
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

// Create basic clock domains
std::shared_ptr<ClockDomain> acc_domain() {
  static std::shared_ptr<ClockDomain> result = std::make_shared<ClockDomain>("acc");
  return result;
};

std::shared_ptr<ClockDomain> bus_domain() {
  static std::shared_ptr<ClockDomain> result = std::make_shared<ClockDomain>("acc");
  return result;
};

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
};

std::shared_ptr<Type> bus_reset() {
  static std::shared_ptr<Type> result = std::make_shared<Reset>("bus_reset", acc_domain());
  return result;
};

std::shared_ptr<Type> string() {
  static std::shared_ptr<Type> result = std::make_shared<String>("string");
  return result;
};

std::shared_ptr<Type> natural() {
  static std::shared_ptr<Type> result = std::make_shared<Natural>("natural");
  return result;
};

std::shared_ptr<Type> boolean() {
  static std::shared_ptr<Type> result = std::make_shared<Boolean>("boolean");
  return result;
};

std::shared_ptr<Literal> bool_true() {
  static auto result = Literal::Make("bool_true", true);
  return result;
}

std::shared_ptr<Literal> bool_false() {
  static auto result = Literal::Make("bool_true", false);
  return result;
}

// Bus channel

std::shared_ptr<Type> bus_read_request() {
  static std::shared_ptr<RecordField> bus_addr = RecordField::Make("addr", Vector::Make<64>("addr"));
  static std::shared_ptr<RecordField> bus_len = RecordField::Make("len", Vector::Make<7>("len"));
  static std::shared_ptr<Type> bus_req_record = Record::Make("", {bus_addr, bus_len});
  static std::shared_ptr<Type> bus_req = Stream::Make(bus_req_record);
  return bus_req;
}

std::shared_ptr<Type> bus_write_request() {
  static std::shared_ptr<RecordField> bus_addr = RecordField::Make("addr", Vector::Make<64>("addr"));
  static std::shared_ptr<RecordField> bus_len = RecordField::Make("len", Vector::Make<7>("len"));
  static std::shared_ptr<Type> bus_req_record = Record::Make("", {bus_addr, bus_len});
  static std::shared_ptr<Type> bus_req = Stream::Make(bus_req_record);
  return bus_req;
}

std::shared_ptr<Type> bus_read_data() {
  static std::shared_ptr<RecordField> bus_data = RecordField::Make("data", Vector::Make<64>("addr"));
  static std::shared_ptr<RecordField> bus_last = RecordField::Make("last", Vector::Make<7>("len"));
  static std::shared_ptr<Type> bus_rdat_record = Record::Make("", {bus_data, bus_last});
  static std::shared_ptr<Type> bus_rdat = Stream::Make(bus_rdat_record);
  return bus_rdat;
}

std::shared_ptr<Type> bus_write_data() {
  static std::shared_ptr<RecordField> bus_wdata = RecordField::Make("data", Vector::Make<64>("addr"));
  static std::shared_ptr<RecordField> bus_wstrobe = RecordField::Make("strobe", Vector::Make<64>("strobe"));
  static std::shared_ptr<RecordField> bus_wlast = RecordField::Make("last", Vector::Make<7>("len"));
  static std::shared_ptr<Type> bus_wdat_record = Record::Make("", {bus_wdata, bus_wstrobe, bus_wlast});
  static std::shared_ptr<Type> bus_wdat = Stream::Make(bus_wdat_record);
  return bus_wdat;
}

}  // namespace fletchgen
