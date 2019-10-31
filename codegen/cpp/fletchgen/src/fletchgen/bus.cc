// Copyright 2018-2019 Delft University of Technology
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
#include <vector>

#include "fletchgen/basic_types.h"

namespace fletchgen {

using cerata::PortArray;
using cerata::record;
using cerata::integer;
using cerata::string;
using cerata::boolean;
using cerata::strl;
using cerata::intl;
using cerata::booll;
using cerata::component;
using cerata::parameter;
using cerata::stream;
using cerata::field;
using cerata::vector;

PARAM_FACTORY(bus_addr_width)
PARAM_FACTORY(bus_data_width)
PARAM_FACTORY(bus_len_width)
PARAM_FACTORY(bus_burst_step_len)
PARAM_FACTORY(bus_burst_max_len)

// Bus types
std::shared_ptr<Type> bus_read(const std::shared_ptr<Node> &addr_width,
                               const std::shared_ptr<Node> &data_width,
                               const std::shared_ptr<Node> &len_width) {
  auto rreq = stream(record("", {field("addr", vector(addr_width)),
                                 field("len", vector(len_width))}));
  auto rdat = stream(record("", {field("data", vector(data_width)),
                                 field("last", last())}));
  auto result = record("", {field("rreq", rreq),
                            field("rdat", rdat)->Reverse()});
  return result;
}

std::shared_ptr<Type> bus_write(const std::shared_ptr<Node> &addr_width,
                                const std::shared_ptr<Node> &data_width,
                                const std::shared_ptr<Node> &len_width) {
  auto wreq = stream(record("", {field("addr", vector(addr_width)),
                                 field("len", vector(len_width))}));
  auto wdat = stream(record("", {field("data", vector(data_width)),
                                 field("strobe", vector(data_width / 8)),
                                 field("last", last())}));
  auto result = record("", {field("wreq", wreq),
                            field("wdat", wdat)});
  return result;
}

static std::string GetBusArbiterName(BusFunction function) {
  return std::string("Bus") + (function == BusFunction::READ ? "Read" : "Write") + "ArbiterVec";
}

Component *bus_arbiter(BusFunction function) {
  // This component model corresponds to a VHDL primitive. Any modifications should be reflected accordingly.
  auto name = GetBusArbiterName(function);

  // If it already exists, just return the existing component.
  auto optional_existing_comp = cerata::default_component_pool()->Get(name);
  if (optional_existing_comp) {
    return *optional_existing_comp;
  }

  // Create a new component.
  auto result = component(name);

  // Parameters.
  BusDimParams params(result);
  BusSpecParams spec{params, function};

  // Remove unused params.
  result->Remove(params.bs.get());
  result->Remove(params.bm.get());

  auto num_slv = parameter("NUM_SLAVE_PORTS", 0);

  result->Add(num_slv);

  auto empty_str = strl("");

  result->Add({parameter("ARB_METHOD", std::string("RR-STICKY")),
               parameter("MAX_OUTSTANDING", 4),
               parameter("RAM_CONFIG", std::string("")),
               parameter("SLV_REQ_SLICES", true),
               parameter("MST_REQ_SLICE", true),
               parameter("MST_DAT_SLICE", true),
               parameter("SLV_DAT_SLICES", true)
              });

  // Clock/reset
  auto clk_rst = port("bcd", cr(), Port::Dir::IN, bus_cd());
  // Master port
  auto mst = bus_port("mst", Port::Dir::OUT, spec);
  // Slave ports
  auto slv_base = bus_port("slv", Port::Dir::OUT, spec);
  slv_base->SetName("bsv");
  slv_base->Reverse();
  auto slv_arr = port_array(slv_base, num_slv);
  // Add all ports.
  result->Add({clk_rst, mst, slv_arr});

  // This component is a primitive as far as Cerata is concerned.
  result->SetMeta(cerata::vhdl::meta::PRIMITIVE, "true");
  result->SetMeta(cerata::vhdl::meta::LIBRARY, "work");
  result->SetMeta(cerata::vhdl::meta::PACKAGE, "Interconnect_pkg");

  return result.get();
}

std::shared_ptr<Component> BusReadSerializer() {
  auto aw = parameter("ADDR_WIDTH", integer());
  auto mdw = parameter("MASTER_DATA_WIDTH", integer());
  auto mlw = parameter("MASTER_LEN_WIDTH", integer());
  auto sdw = parameter("SLAVE_DATA_WIDTH", integer());
  auto slw = parameter("SLAVE_LEN_WIDTH", integer());
  static auto ret = component("BusReadSerializer", {
      aw, mdw, mlw, sdw, slw,
      parameter("SLAVE_MAX_BURST", integer()),
      parameter("ENABLE_FIFO", boolean(), booll(false)),
      parameter("SLV_REQ_SLICE_DEPTH", integer(), intl(2)),
      parameter("SLV_DAT_SLICE_DEPTH", integer(), intl(2)),
      parameter("MST_REQ_SLICE_DEPTH", integer(), intl(2)),
      parameter("MST_DAT_SLICE_DEPTH", integer(), intl(2)),
      port("bcd", cr(), Port::Dir::IN, bus_cd()),
      port("mst", bus_read(aw, mlw, mdw), Port::Dir::OUT),
      port("slv", bus_read(aw, slw, sdw), Port::Dir::OUT),
  });
  ret->SetMeta(cerata::vhdl::meta::PRIMITIVE, "true");
  ret->SetMeta(cerata::vhdl::meta::LIBRARY, "work");
  ret->SetMeta(cerata::vhdl::meta::PACKAGE, "Interconnect_pkg");
  return ret;
}

bool operator==(const BusSpec &lhs, const BusSpec &rhs) {
  return (lhs.dim == rhs.dim) && (lhs.func == rhs.func);
}

std::shared_ptr<Type> bus(const BusSpecParams &spec) {
  std::shared_ptr<Type> result;
  if (spec.func == BusFunction::READ) {
    return bus_read(spec.dim.aw, spec.dim.dw, spec.dim.lw);
  } else {
    return bus_write(spec.dim.aw, spec.dim.dw, spec.dim.lw);
  }
}

std::shared_ptr<BusPort> bus_port(const std::string &name, Port::Dir dir, const BusSpecParams &params) {
  return std::make_shared<BusPort>(name, dir, params);
}

std::shared_ptr<BusPort> bus_port(Port::Dir dir, const BusSpecParams &params) {
  return std::make_shared<BusPort>(params.ToName(), dir, params);
}

#define BUS_PARAM_CONNECTION_FACTORY(NAME, ABBR) \
  auto ABBR##_name = prefix + NAME()->name();    \
    if (dst->Has(ABBR##_name)) {                 \
    auto dst_##ABBR = dst->par(ABBR##_name);     \
    Connect(dst_##ABBR, src.ABBR);               \
    (*rebinding)[src.ABBR.get()] = dst_##ABBR;   \
  }

void ConnectBusParam(cerata::Graph *dst,
                     const std::string &prefix,
                     const BusDimParams &src,
                     cerata::NodeMap *rebinding) {
  BUS_PARAM_CONNECTION_FACTORY(bus_addr_width, aw)
  BUS_PARAM_CONNECTION_FACTORY(bus_data_width, dw)
  BUS_PARAM_CONNECTION_FACTORY(bus_len_width, lw)
  BUS_PARAM_CONNECTION_FACTORY(bus_burst_step_len, bs)
  BUS_PARAM_CONNECTION_FACTORY(bus_burst_max_len, bm)
}

#undef BUS_PARAM_CONNECTION_FACTORY

bool operator==(const BusDim &lhs, const BusDim &rhs) {
  return (lhs.aw == rhs.aw) && (lhs.dw == rhs.dw) && (lhs.lw == rhs.lw) && (lhs.bs == rhs.bs) && (lhs.bm == rhs.bm);
}

std::shared_ptr<cerata::Object> BusPort::Copy() const {
  auto result = bus_port(name(), dir_, spec_);
  // Take shared ownership of the type
  auto typ = type()->shared_from_this();
  result->SetType(typ);
  return result;
}

std::string BusDim::ToName() const {
  std::stringstream str;
  str << "AW" << std::to_string(aw);
  str << "DW" << std::to_string(dw);
  str << "LW" << std::to_string(lw);
  str << "BS" << std::to_string(bs);
  str << "BM" << std::to_string(bm);
  return str.str();
}

static std::vector<int64_t> ParseCSV(std::string str) {
  std::vector<int64_t> result;
  str += ',';
  size_t pos = 0;
  while ((pos = str.find(',')) != std::string::npos) {
    result.push_back(std::strtoul(str.substr(0, pos).c_str(), nullptr, 10));
    str.erase(0, pos + 1);
  }
  return result;
}

BusDim BusDim::FromString(const std::string &str, BusDim default_to) {
  BusDim result = default_to;
  if (!str.empty()) {
    auto values = ParseCSV(str);
    if (values.size() != 5) {
      FLETCHER_LOG(FATAL, "Bus dimensions string is invalid: " + str
          + ". Expected: <address width>,<data width>,<len width>,<min burst>,<max burst>");
    }
    result.aw = static_cast<uint32_t>(values[0]);
    result.dw = static_cast<uint32_t>(values[1]);
    result.lw = static_cast<uint32_t>(values[2]);
    result.bs = static_cast<uint32_t>(values[3]);
    result.bm = static_cast<uint32_t>(values[4]);
  }
  return result;
}

std::string BusDim::ToString() const {
  std::stringstream str;
  str << "address width: " << std::to_string(aw);
  str << ", data width: " << std::to_string(dw);
  str << ", burst length width: " << std::to_string(lw);
  str << ", minimum burst size: " << std::to_string(bs);
  str << ", maximum burst size: " << std::to_string(bm);
  return str.str();
}

std::vector<std::shared_ptr<Object>> BusDimParams::all() const {
  return std::vector<std::shared_ptr<Object>>({aw, dw, lw, bs, bm});
}

BusDimParams::BusDimParams(cerata::Graph *parent, BusDim dim, const std::string &prefix) : plain(dim) {
  aw = bus_addr_width(dim.aw, prefix);
  dw = bus_data_width(dim.dw, prefix);
  lw = bus_len_width(dim.lw, prefix);
  bs = bus_burst_step_len(dim.bs, prefix);
  bm = bus_burst_max_len(dim.bm, prefix);
  parent->Add({aw, dw, lw, bs, bm});
}

std::string BusSpec::ToName() const {
  return (func == BusFunction::READ ? "RD" : "WR") + dim.ToName();
}

std::string BusSpecParams::ToName() const {
  return BusSpec{*this}.ToName();
}
}  // namespace fletchgen
