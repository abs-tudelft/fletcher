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

#include "fletchgen/bus.h"

#include <cerata/api.h>

#include <memory>
#include <deque>

#include "fletchgen/basic_types.h"

namespace fletchgen {

using cerata::Parameter;
using cerata::Port;
using cerata::PortArray;
using cerata::intl;
using cerata::strl;
using cerata::booll;
using cerata::integer;
using cerata::string;
using cerata::boolean;
using cerata::integer;
using cerata::bit;
using cerata::RecField;
using cerata::Vector;
using cerata::Record;
using cerata::Stream;

// Bus types
std::shared_ptr<Type> bus_read(const std::shared_ptr<Node> &addr_width,
                               const std::shared_ptr<Node> &len_width,
                               const std::shared_ptr<Node> &data_width) {
  auto raddr = RecField::Make("addr", Vector::Make("addr", addr_width));
  auto rlen = RecField::Make("len", Vector::Make("len", len_width));
  auto rreq_record = Record::Make("rreq:rec", {raddr, rlen});
  auto rreq = Stream::Make("rreq:str", rreq_record);
  auto rdata = RecField::Make(Vector::Make("data", data_width));
  auto rlast = RecField::Make("last", last());
  auto rdat_record = Record::Make("rdat:rec", {rdata, rlast});
  auto rdat = Stream::Make("rdat:str", rdat_record);
  auto result = Record::Make("BusRead", {RecField::Make("rreq", rreq), RecField::Make("rdat", rdat, true)});
  return result;
}
std::shared_ptr<Type> bus_write(const std::shared_ptr<Node> &addr_width,
                                const std::shared_ptr<Node> &len_width,
                                const std::shared_ptr<Node> &data_width) {
  auto waddr = RecField::Make(Vector::Make("addr", addr_width));
  auto wlen = RecField::Make(Vector::Make("len", len_width));
  auto wreq_record = Record::Make("wreq:rec", {waddr, wlen});
  auto wreq = Stream::Make("wreq:stm", wreq_record);
  auto wdata = RecField::Make(Vector::Make("data", data_width));
  auto wstrobe = RecField::Make(Vector::Make("strobe", data_width / 8));
  auto wlast = RecField::Make("last", last());
  auto wdat_record = Record::Make("wdat:rec", {wdata, wstrobe, wlast});
  auto wdat = Stream::Make("wdat:stm", wdat_record);
  auto result = Record::Make("BusWrite", {RecField::Make("wreq", wreq), RecField::Make("wdat", wdat)});
  return result;
}

static std::string BusArbiterName(BusSpec spec) {
  return std::string("Bus") + (spec.function == BusFunction::READ ? "Read" : "Write") + "ArbiterVec";
}

static std::shared_ptr<Component> BusArbiter(BusSpec spec) {
  // Number of slave ports
  auto nslaves = Parameter::Make("NUM_SLAVE_PORTS", integer(), intl(0));

  // Master port
  auto mst = BusPort::Make("mst", Port::Dir::OUT, spec);

  // Slave ports
  auto slave_base = std::dynamic_pointer_cast<BusPort>(mst->Copy());
  slave_base->SetName("bsv");
  slave_base->InvertDirection();
  auto slaves_array = PortArray::Make(slave_base, nslaves);

  std::deque<std::shared_ptr<cerata::Object>> objects;
  objects.insert(objects.end(), {bus_addr_width(), bus_len_width(), bus_data_width()});
  if (spec.function == BusFunction::WRITE) {
    objects.push_back(bus_strobe_width());
  }
  auto empty_str = strl("");
  objects.insert(objects.end(), {
      nslaves,
      Parameter::Make("ARB_METHOD", string(), strl("ROUND-ROBIN")),
      Parameter::Make("MAX_OUTSTANDING", integer(), intl(4)),
      Parameter::Make("RAM_CONFIG", string(), empty_str),
      Parameter::Make("SLV_REQ_SLICES", boolean(), booll(true)),
      Parameter::Make("MST_REQ_SLICE", boolean(), booll(true)),
      Parameter::Make("MST_DAT_SLICE", boolean(), booll(true)),
      Parameter::Make("SLV_DAT_SLICES", boolean(), booll(true)),
      Port::Make("bcd", cr(), Port::Dir::IN, bus_cd()),
      mst,
      slaves_array,
  });

  auto ret = Component::Make(BusArbiterName(spec), objects);

  ret->SetMeta(cerata::vhdl::metakeys::PRIMITIVE, "true");
  ret->SetMeta(cerata::vhdl::metakeys::LIBRARY, "work");
  ret->SetMeta(cerata::vhdl::metakeys::PACKAGE, "Interconnect_pkg");
  return ret;
}

std::unique_ptr<Instance> BusArbiterInstance(BusSpec spec) {
  auto optional_existing_component = cerata::default_component_pool()->Get(BusArbiterName(spec));
  if (optional_existing_component) {
    return Instance::Make(*optional_existing_component);
  } else {
    auto new_component = BusArbiter(spec);
    return BusArbiterInstance(spec);
  }
}

std::shared_ptr<Component> BusReadSerializer() {
  auto aw = Parameter::Make("ADDR_WIDTH", integer());
  auto mdw = Parameter::Make("MASTER_DATA_WIDTH", integer());
  auto mlw = Parameter::Make("MASTER_LEN_WIDTH", integer());
  auto sdw = Parameter::Make("SLAVE_DATA_WIDTH", integer());
  auto slw = Parameter::Make("SLAVE_LEN_WIDTH", integer());
  static auto ret = Component::Make("BusReadSerializer", {
      aw, mdw, mlw, sdw, slw,
      Parameter::Make("SLAVE_MAX_BURST", integer()),
      Parameter::Make("ENABLE_FIFO", boolean(), booll(false)),
      Parameter::Make("SLV_REQ_SLICE_DEPTH", integer(), intl(2)),
      Parameter::Make("SLV_DAT_SLICE_DEPTH", integer(), intl(2)),
      Parameter::Make("MST_REQ_SLICE_DEPTH", integer(), intl(2)),
      Parameter::Make("MST_DAT_SLICE_DEPTH", integer(), intl(2)),
      Port::Make("bcd", cr(), Port::Dir::IN, bus_cd()),
      Port::Make("mst", bus_read(aw, mlw, mdw), Port::Dir::OUT),
      Port::Make("slv", bus_read(aw, slw, sdw), Port::Dir::OUT),
  });
  ret->SetMeta(cerata::vhdl::metakeys::PRIMITIVE, "true");
  ret->SetMeta(cerata::vhdl::metakeys::LIBRARY, "work");
  ret->SetMeta(cerata::vhdl::metakeys::PACKAGE, "Interconnect_pkg");
  return ret;
}

bool operator==(const BusSpec &lhs, const BusSpec &rhs) {
  return (lhs.data_width == rhs.data_width) && (lhs.addr_width == rhs.addr_width) && (lhs.len_width == rhs.len_width) &&
      (lhs.burst_step == rhs.burst_step) && (lhs.max_burst == rhs.max_burst) && (lhs.function == rhs.function);
}
std::shared_ptr<Type> bus(BusSpec spec) {
  std::shared_ptr<Type> result;
  // Check if the bus type already exists in the type pool
  auto bus_typename = spec.ToBusTypeName();
  auto optional_existing_bus_type = cerata::default_type_pool()->Get(bus_typename);
  if (optional_existing_bus_type) {
    FLETCHER_LOG(DEBUG, "BUS type already exists in default pool.");
    result = optional_existing_bus_type.value()->shared_from_this();
  } else {
    auto addr_width = intl(spec.addr_width);
    auto len_width = intl(spec.len_width);
    auto data_width = intl(spec.data_width);
    switch (spec.function) {
      case BusFunction::READ:result = bus_read(addr_width, len_width, data_width);
        break;
      case BusFunction::WRITE:result = bus_write(addr_width, len_width, data_width);
        break;
      default:FLETCHER_LOG(FATAL, "Corrupted bus function field.");
        break;
    }
  }
  return result;
}

std::shared_ptr<BusPort> BusPort::Make(std::string name, Port::Dir dir, BusSpec spec) {
  return std::make_shared<BusPort>(dir, spec, name);
}

std::shared_ptr<BusPort> BusPort::Make(Port::Dir dir, BusSpec spec) {
  return std::make_shared<BusPort>(dir, spec);
}

std::shared_ptr<cerata::Object> BusPort::Copy() const {
  auto result = Make(name(), dir_, spec_);
  // Take shared ownership of the type
  auto typ = type()->shared_from_this();
  result->SetType(typ);
  return result;
}

std::string BusSpec::ToBusTypeName() const {
  std::stringstream str;
  str << "BUS" << (function == BusFunction::READ ? "RD" : "WR");
  str << "A" << addr_width;
  str << "L" << len_width;
  str << "D" << data_width;
  str << "S" << burst_step;
  str << "M" << max_burst;
  return str.str();
}

std::string BusSpec::ToString() const {
  std::stringstream str;
  str << "BusSpec[";
  str << "fun=" << (function == BusFunction::READ ? "read" : "write");
  str << ", addr=" << addr_width;
  str << ", len=" << len_width;
  str << ", dat=" << data_width;
  str << ", step=" << burst_step;
  str << ", max=" << max_burst;
  str << "]";
  return str.str();
}

}  // namespace fletchgen
