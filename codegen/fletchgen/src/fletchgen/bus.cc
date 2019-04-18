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
#include <cerata/types.h>

#include "cerata/graphs.h"
#include "cerata/types.h"
#include "cerata/edges.h"
#include "cerata/arrays.h"
#include "cerata/logging.h"

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
using cerata::bool_true;
using cerata::bool_false;

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

}  // namespace fletchgen
