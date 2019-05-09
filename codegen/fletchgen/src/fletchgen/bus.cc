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
  auto rlast = RecField::Make(last());
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
  auto wlast = RecField::Make("last", bit());
  auto wdat_record = Record::Make("wdat:rec", {wdata, wstrobe, wlast});
  auto wdat = Stream::Make("wdat:stm", wdat_record);

  auto w = Record::Make("r", {RecField::Make("wreq", wreq),
                              RecField::Make("wdat", wdat)});

  return w;
}

std::shared_ptr<Component> BusReadArbiter() {
  auto nslaves = Parameter::Make("NUM_SLAVE_PORTS", integer(), intl<0>());
  auto slaves_read_array = PortArray::Make("bsv", bus_read(), nslaves, Port::Dir::IN);

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
                                     Parameter::Make("SLV_DAT_SLICES", boolean(), bool_true()),
                                     Port::Make(bus_clk()),
                                     Port::Make(bus_reset()),
                                     Port::Make("mst_rreq", bus_read(), Port::Dir::OUT),
                                     slaves_read_array,
                                    });
  ret->meta["primitive"] = "true";
  ret->meta["library"] = "work";
  ret->meta["package"] = "Interconnect";
  return ret;
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
      Port::Make(bus_clk()),
      Port::Make(bus_reset()),
      Port::Make("mst", bus_read(aw, mlw, mdw), Port::Dir::OUT),
      Port::Make("slv", bus_read(aw, slw, sdw), Port::Dir::OUT),
  });
  ret->meta["primitive"] = "true";
  ret->meta["library"] = "work";
  ret->meta["package"] = "Interconnect";
  return ret;
}

Artery::Artery(
    const std::string &prefix,
    std::shared_ptr<Node> address_width,
    std::shared_ptr<Node> master_width,
    std::deque<std::shared_ptr<Node>> slave_widths)
    : Component(prefix + "_artery"),
      address_width_(std::move(address_width)),
      master_width_(std::move(master_width)),
      slave_widths_(std::move(slave_widths)) {

  if (address_width == nullptr) {
    LOG(WARNING, "Artery address width is not set.");
  }
  if (master_width == nullptr) {
    LOG(WARNING, "Artery top-level data width is not set.");
  }

  AddObject(bus_addr_width());
  AddObject(bus_data_width());
  // For each required slave width
  for (const auto &slave_width : slave_widths_) {
    // Create parameters
    auto num_slaves_par = Parameter::Make("NUM_SLV_W" + slave_width->ToString(), integer());
    AddObject(num_slaves_par);

    // Create ports
    auto read_array = PortArray::Make("bus" + slave_width->ToString() + "_rreq",
                                      bus_read(),
                                      num_slaves_par,
                                      Port::IN);
    AddObject(read_array);

    // Create a bus read arbiter vector instance
    auto read_arb = Instance::Make("arb_" + slave_width->ToString(), BusReadArbiter());

    // Set its parameters
    read_arb->par("bus_addr_width") <<= address_width_;
    read_arb->par("bus_data_width") <<= slave_width;

    // Connect its ports
    read_arb->porta("bsv")->Append() <<= read_array->Append();

    // Create a bus read serializer for other widths than master.
    if (slave_width != master_width_) {
      // Create bus read serializer
      auto read_ser = Instance::Make("ser_" + slave_width->ToString(), BusReadSerializer());
      // Connet
      read_ser->port("slv") <<= read_arb->port("mst");
      AddChild(std::move(read_ser));
    } else {

    }

    AddChild(std::move(read_arb));
  }
}

std::shared_ptr<Artery> Artery::Make(std::string prefix,
                                     std::shared_ptr<Node> address_width,
                                     std::shared_ptr<Node> master_width,
                                     std::deque<std::shared_ptr<Node>> slave_widths) {
  return std::make_shared<Artery>(prefix, address_width, master_width, slave_widths);
}

std::shared_ptr<PortArray> ArteryInstance::read_data(const std::shared_ptr<Node> &width) {
  return porta("bus" + width->ToString() + "_rdat");
}

std::shared_ptr<PortArray> ArteryInstance::read_request(const std::shared_ptr<Node> &width) {
  return porta("bus" + width->ToString() + "_rreq");
}

std::string BusChannel::fun2name(BusChannel::Function fun) {
  switch (fun) {
    case Function::READ: return "bus";
    case Function::WRITE: return "bus";
    default:throw std::runtime_error("Unknown Bus function.");
  }
}

std::shared_ptr<Type> BusChannel::fun2type(BusChannel::Function fun, BusSpec spec) {
  switch (fun) {
    case Function::READ:
      return bus_read(Literal::Make(spec.addr_width),
                      Literal::Make(spec.len_width),
                      Literal::Make(spec.data_width));
    case Function::WRITE:
      return bus_write(Literal::Make(spec.addr_width),
                       Literal::Make(spec.len_width),
                       Literal::Make(spec.data_width));
    default:throw std::runtime_error("Unknown Bus function.");
  }
}

std::shared_ptr<BusChannel> BusChannel::Make(BusChannel::Function fun, Port::Dir dir, BusSpec spec) {
  return std::make_shared<BusChannel>(fun, dir, spec);
}

std::shared_ptr<cerata::Object> BusChannel::Copy() const {
  auto result = Make(function_, dir_, spec_);
  result->SetType(type());
  return result;
}
}  // namespace fletchgen
