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

// Bus channel

std::shared_ptr<Type> bus_read_request(const std::shared_ptr<Node> &addr_width,
                                       const std::shared_ptr<Node> &len_width) {
  static auto bus_addr = RecField::Make("addr", Vector::Make("addr", addr_width));
  static auto bus_len = RecField::Make("len", Vector::Make("len", len_width));
  static auto bus_rreq_record = Record::Make("rreq:rec", {bus_addr, bus_len});
  static auto bus_rreq = Stream::Make("rreq:stream", bus_rreq_record);
  return bus_rreq;
}

std::shared_ptr<Type> bus_write_request(const std::shared_ptr<Node> &addr_width,
                                        const std::shared_ptr<Node> &len_width) {
  static auto bus_addr = RecField::Make(Vector::Make("addr", addr_width));
  static auto bus_len = RecField::Make(Vector::Make("len", len_width));
  static auto bus_wreq_record = Record::Make("wreq:rec", {bus_addr, bus_len});
  static auto bus_wreq = Stream::Make("wreq:stream", bus_wreq_record);
  return bus_wreq;
}

std::shared_ptr<Type> bus_read_data(const std::shared_ptr<Node> &width) {
  auto bus_rdata = RecField::Make(Vector::Make("data", width));
  auto bus_rlast = RecField::Make(last());
  auto bus_rdat_record = Record::Make("bus_rdat_rec", {bus_rdata, bus_rlast});
  auto bus_rdat = Stream::Make("bus_rdat", bus_rdat_record);
  return bus_rdat;
}

std::shared_ptr<Type> bus_write_data(const std::shared_ptr<Node> &width) {
  auto bus_wdata = RecField::Make(Vector::Make("data", width));
  auto bus_wstrobe = RecField::Make(Vector::Make("strobe", width / intl<8>()));
  auto bus_wlast = RecField::Make("last", bit());
  auto bus_wdat_record = Record::Make("bus_wdat_rec", {bus_wdata, bus_wstrobe, bus_wlast});
  auto bus_wdat = Stream::Make("bus_wdat", bus_wdat_record);
  return bus_wdat;
}

std::shared_ptr<Component> BusReadArbiter() {
  auto nslaves = Parameter::Make("NUM_SLAVE_PORTS", integer(), intl<0>());
  auto slaves_rreq_array = PortArray::Make("bsv_rreq", bus_read_request(), nslaves, Port::Dir::IN);
  auto slaves_rdat_array = PortArray::Make("bsv_rdat", bus_read_data(), nslaves, Port::Dir::OUT);

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
                                     Port::Make("mst_rreq", bus_read_request(), Port::Dir::OUT),
                                     Port::Make("mst_rdat", bus_read_data(), Port::Dir::IN),
                                     slaves_rreq_array,
                                     slaves_rdat_array
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
      Port::Make("mst_rreq", bus_read_request(aw, mlw), Port::Dir::OUT),
      Port::Make("mst_rdat", bus_read_data(mdw), Port::Dir::IN),
      Port::Make("slv_rreq", bus_read_request(aw, slw), Port::Dir::IN),
      Port::Make("slv_rdat", bus_read_data(sdw), Port::Dir::OUT),
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
    auto req_array = PortArray::Make("bus" + slave_width->ToString() + "_rreq",
                                     bus_read_request(),
                                     num_slaves_par,
                                     Port::IN);
    auto dat_array = PortArray::Make("bus" + slave_width->ToString() + "_rdat",
                                     bus_read_data(slave_width),
                                     num_slaves_par,
                                     Port::OUT);
    AddObject(req_array);
    AddObject(dat_array);

    // Create a bus read arbiter vector instance
    auto read_arb = Instance::Make("arb_" + slave_width->ToString(), BusReadArbiter());

    // Set its parameters
    read_arb->par("bus_addr_width") <<= address_width_;
    read_arb->par("bus_data_width") <<= slave_width;

    // Connect its ports
    read_arb->porta("bsv_rreq")->Append() <<= req_array->Append();
    dat_array->Append() <<= read_arb->porta("bsv_rdat")->Append();

    // Create a bus read serializer for other widths than master.
    if (slave_width != master_width_) {
      // Create bus read serializer
      auto read_ser = Instance::Make("ser_" + slave_width->ToString(), BusReadSerializer());
      // Connet
      read_ser->port("slv_rreq") <<= read_arb->port("mst_rreq");
      read_arb->port("mst_rdat") <<= read_ser->port("slv_rdat");
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
    case Function::READ_REQ: return "rreq";
    case Function::READ_DAT: return "rdat";
    case Function::WRITE_REQ: return "wreq";
    case Function::WRITE_DAT: return "wdat";
    default:
      throw std::runtime_error("Compiler broke in " + std::string(__FILE__));
  }
}

std::shared_ptr<Type> BusChannel::fun2type(BusChannel::Function fun,
                                           size_t data_width,
                                           size_t addr_width,
                                           size_t len_width) {
  switch (fun) {
    case Function::READ_REQ: return bus_read_request(Literal::Make(addr_width), Literal::Make(len_width));
    case Function::READ_DAT: return bus_read_data(Literal::Make(data_width));
    case Function::WRITE_REQ: return bus_write_request(Literal::Make(addr_width), Literal::Make(len_width));
    case Function::WRITE_DAT: return bus_write_data(Literal::Make(data_width));
    default:
      throw std::runtime_error("Compiler broke in " + std::string(__FILE__));
  }
}
}  // namespace fletchgen
