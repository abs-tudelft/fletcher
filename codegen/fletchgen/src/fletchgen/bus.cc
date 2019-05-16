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

#include <memory>
#include <cerata/api.h>

#include "fletchgen/basic_types.h"

namespace fletchgen {

using cerata::Parameter;
using cerata::Port;
using cerata::PortArray;
using cerata::intl;
using cerata::integer;
using cerata::string;
using cerata::strl;
using cerata::boolean;
using cerata::integer;
using cerata::bit;
using cerata::bool_true;
using cerata::bool_false;
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

  auto r = Record::Make("r", {RecField::Make("rreq", rreq),
                              RecField::Make("rdat", rdat, true)});

  return r;
}

std::shared_ptr<Type> bus_write(const std::shared_ptr<Node> &addr_width,
                                const std::shared_ptr<Node> &len_width,
                                const std::shared_ptr<Node> &data_width) {
  auto waddr = RecField::Make(Vector::Make("addr", addr_width));
  auto wlen = RecField::Make(Vector::Make("len", len_width));
  auto wreq_record = Record::Make("wreq:rec", {waddr, wlen});
  auto wreq = Stream::Make("wreq:stm", wreq_record);

  auto wdata = RecField::Make(Vector::Make("data", data_width));
  auto wstrobe = RecField::Make(Vector::Make("strobe", data_width / intl<8>()));
  auto wlast = RecField::Make("last", last());
  auto wdat_record = Record::Make("wdat:rec", {wdata, wstrobe, wlast});
  auto wdat = Stream::Make("wdat:stm", wdat_record);

  auto w = Record::Make("r", {RecField::Make("wreq", wreq),
                              RecField::Make("wdat", wdat)});

  return w;
}

std::shared_ptr<Component> BusArbiter(BusSpec spec) {
  auto nslaves = Parameter::Make("NUM_SLAVE_PORTS", integer(), intl<0>());

  auto mst = BusPort::Make("mst", Port::Dir::OUT, spec);

  auto slaves_array = PortArray::Make("bsv", (*Cast<BusPort>(mst->Copy()))->InvertDirection(), nslaves);

  std::deque<std::shared_ptr<cerata::Object>> objects;
  objects.insert(objects.end(), {bus_addr_width(), bus_len_width(), bus_data_width()});
  if (spec.function == BusFunction::WRITE) {
    objects.push_back(bus_strobe_width());
  }
  objects.insert(objects.end(), {
      nslaves,
      Parameter::Make("ARB_METHOD", string(), strl("ROUND-ROBIN")),
      Parameter::Make("MAX_OUTSTANDING", integer(), intl<4>()),
      Parameter::Make("RAM_CONFIG", string(), strl("")),
      Parameter::Make("SLV_REQ_SLICES", boolean(), bool_true()),
      Parameter::Make("MST_REQ_SLICE", boolean(), bool_true()),
      Parameter::Make("MST_DAT_SLICE", boolean(), bool_true()),
      Parameter::Make("SLV_DAT_SLICES", boolean(), bool_true()),
      Port::Make(bus_cr()),
      mst,
      slaves_array,
  });

  auto name = std::string("Bus") + (spec.function == BusFunction::READ ? "Read" : "Write") + "ArbiterVec";
  auto ret = Component::Make(name, objects);

  ret->meta["primitive"] = "true";
  ret->meta["library"] = "work";
  ret->meta["package"] = "Interconnect";
  return
      ret;
}

std::shared_ptr<Component> BusReadSerializer() {
  auto aw = Parameter::Make("ADDR_WIDTH", integer(), {});
  auto mdw = Parameter::Make("MASTER_DATA_WIDTH", integer(), {});
  auto mlw = Parameter::Make("MASTER_LEN_WIDTH", integer(), {});
  auto sdw = Parameter::Make("SLAVE_DATA_WIDTH", integer(), {});
  auto slw = Parameter::Make("SLAVE_LEN_WIDTH", integer(), {});
  static auto ret = Component::Make("BusReadSerializer", {
      aw, mdw, mlw, sdw, slw,
      Parameter::Make("SLAVE_MAX_BURST", integer(), {}),
      Parameter::Make("ENABLE_FIFO", boolean(), bool_false()),
      Parameter::Make("SLV_REQ_SLICE_DEPTH", integer(), intl<2>()),
      Parameter::Make("SLV_DAT_SLICE_DEPTH", integer(), intl<2>()),
      Parameter::Make("MST_REQ_SLICE_DEPTH", integer(), intl<2>()),
      Parameter::Make("MST_DAT_SLICE_DEPTH", integer(), intl<2>()),
      Port::Make(bus_cr()),
      Port::Make("mst", bus_read(aw, mlw, mdw), Port::Dir::OUT),
      Port::Make("slv", bus_read(aw, slw, sdw), Port::Dir::OUT),
  });
  ret->meta["primitive"] = "true";
  ret->meta["library"] = "work";
  ret->meta["package"] = "Interconnect";
  return ret;
}

bool operator==(const BusSpec &lhs, const BusSpec &rhs) {
  return (lhs.data_width == rhs.data_width) && (lhs.addr_width == rhs.addr_width) && (lhs.len_width == rhs.len_width) &&
      (lhs.burst_step == rhs.burst_step) && (lhs.max_burst == rhs.max_burst) && (lhs.function == rhs.function);
}

std::shared_ptr<BusPort> BusPort::Make(std::string name, Port::Dir dir, BusSpec spec) {
  return std::make_shared<BusPort>(dir, spec, name);
}

std::shared_ptr<BusPort> BusPort::Make(Port::Dir dir, BusSpec spec) {
  return std::make_shared<BusPort>(dir, spec);
}

std::shared_ptr<cerata::Object> BusPort::Copy() const {
  auto result = Make(name(), dir_, spec_);
  result->SetType(type());
  return result;
}

std::string BusSpec::ToShortString() const {
  std::stringstream str;
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
  str << "fun:" << (function == BusFunction::READ ? "read" : "write");
  str << ", addr:" << addr_width;
  str << ", len:" << len_width;
  str << ", dat:" << data_width;
  str << ", step:" << burst_step;
  str << ", max:" << max_burst;
  str << "]";
  return str.str();
}

std::shared_ptr<Type> BusSpec::ToType() {
  switch (function) {
    case BusFunction::READ:
      return bus_read(Literal::Make(addr_width),
                      Literal::Make(len_width),
                      Literal::Make(data_width));
    case BusFunction::WRITE:
      return bus_write(Literal::Make(addr_width),
                       Literal::Make(len_width),
                       Literal::Make(data_width));
    default:throw std::runtime_error("Unknown Bus function.");
  }
}

}  // namespace fletchgen
