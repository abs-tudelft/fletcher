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

#include "fletchgen/mantle.h"

#include <cerata/api.h>
#include <fletcher/common.h>

#include <memory>
#include <vector>
#include <utility>
#include <string>
#include <vector>

#include "fletchgen/basic_types.h"
#include "fletchgen/bus.h"
#include "fletchgen/nucleus.h"
#include "fletchgen/axi4_lite.h"

namespace fletchgen {

using cerata::intl;

//static std::string ArbiterMasterName(BusFunction function) {
//  return std::string(function == BusFunction::READ ? "rd" : "wr") + "_mst";
//}

Mantle::Mantle(std::string name,
               const std::vector<std::shared_ptr<RecordBatch>> &recordbatches,
               const std::shared_ptr<Nucleus> &nucleus,
               BusDim bus_dim)
    : Component(std::move(name)), bus_dim_(bus_dim) {

  using std::pair;

  // Add some default parameters.
  auto iw = index_width();
  auto tw = tag_width();
  Add({iw, tw});

  // Top level bus parameters.
  auto bus_params = BusDimParams(this, bus_dim);
  auto bus_rd_spec = BusSpecParams{bus_params, BusFunction::READ};
  auto bus_wr_spec = BusSpecParams{bus_params, BusFunction::WRITE};
  std::shared_ptr<Port> bus_rd = bus_port("rd_mst", Port::OUT, bus_rd_spec);
  std::shared_ptr<Port> bus_wr = bus_port("wr_mst", Port::OUT, bus_wr_spec);

  // Add default ports; bus clock/reset, kernel clock/reset and AXI4-lite port.
  auto bcr = port("bcd", cr(), Port::Dir::IN, bus_cd());
  auto kcr = port("kcd", cr(), Port::Dir::IN, kernel_cd());
  auto axi = axi4_lite(Port::Dir::IN, bus_cd());
  Add({bcr, kcr, axi});

  // Handle the Nucleus.
  // Instantiate the nucleus and connect some default parameters.
  nucleus_inst_ = Instantiate(nucleus.get());
  nucleus_inst_->prt("kcd") <<= kcr;
  nucleus_inst_->prt("mmio") <<= axi;

  nucleus_inst_->par("INDEX_WIDTH")->SetValue(iw);
  nucleus_inst_->par("TAG_WIDTH")->SetValue(tw);

  // Handle RecordBatches.
  // We've instantiated the Nucleus, and now we should feed it with data from the RecordBatch components.
  // We're going to do the following while iterating over the RecordBatch components.
  // 1. Instantiate every RecordBatch component.
  // 2. Remember the memory interface ports (bus_ports) for bus infrastructure generation later on.
  // 3. Connect all field-derived ports between RecordBatches and Nucleus.

  std::vector<BusPort *> rb_bus_ports;

  for (const auto &rb : recordbatches) {
    // Instantiate the RecordBatch
    auto rbi = Instantiate(rb.get());
    recordbatch_instances_.push_back(rbi);

    // Connect bus clock/reset and kernel clock/reset.
    rbi->prt("bcd") <<= bcr;
    rbi->prt("kcd") <<= kcr;

    rbi->par("INDEX_WIDTH")->SetValue(iw);
    rbi->par("TAG_WIDTH")->SetValue(tw);

    // Look up its bus ports and remember them.
    auto rbi_bus_ports = rbi->GetAll<BusPort>();
    rb_bus_ports.insert(rb_bus_ports.end(), rbi_bus_ports.begin(), rbi_bus_ports.end());

    // Obtain all the field-derived ports from the RecordBatch Instance.
    auto field_ports = rbi->GetAll<FieldPort>();
    // Depending on their function (and direction), connect all of them to the nucleus.
    for (const auto &fp : field_ports) {
      if (fp->function_ == FieldPort::Function::ARROW) {
        // Connect the address width parameter on the nucleus.
        auto prefix = rb->schema()->name() + "_" + fp->field_->name();
        Connect(nucleus_inst_->par(bus_addr_width(0, prefix)), par(bus_addr_width()));

        // Connect the other bus params.
        ConnectBusParam(rbi, prefix + "_", bus_params, inst_to_comp_map());

        if (fp->dir() == cerata::Term::Dir::OUT) {
          Connect(nucleus_inst_->prt(fp->name()), fp);
        } else {
          Connect(fp, nucleus_inst_->prt(fp->name()));
        }
      } else if (fp->function_ == FieldPort::Function::COMMAND) {
        Connect(fp, nucleus_inst_->prt(fp->name()));
      } else if (fp->function_ == FieldPort::Function::UNLOCK) {
        Connect(nucleus_inst_->prt(fp->name()), fp);
      }
    }
  }

  // Handle the bus infrastructure.
  // Now that we've instantiated and connected all RecordBatches on the Nucleus side, we need to connect their bus
  // ports to bus arbiters. We don't have an elaborate interconnection generation step yet, so we just discern between
  // read and write ports, assuming they will all get the same bus parametrization.
  //
  // Therefore, we only need a read and/or write arbiter, whatever mode RecordBatch is instantiated.
  // We take the following steps.
  // 1. instantiate them and connect them to the top level ports.
  // 2. Connect every RecordBatch bus port to the corresponding arbiter.

  // Instantiate and connect arbiters to top level.
  // Instance *arb_read = nullptr;
  // Instance *arb_write = nullptr;

  // Gather all unique bus specs from RecordBatch bus interfaces.
  std::vector<BusSpec> bus_specs;
  for (const auto &bp : rb_bus_ports) {
    bus_specs.push_back(BusSpec(bp->spec_));
  }
  cerata::FilterDuplicates(&bus_specs);

  // For every required bus, instantiate a bus arbiter.
  std::unordered_map<BusSpec, Instance *> arb_map;
  for (const auto &b : bus_specs) {
    auto prefix = b.ToName();
    Instance *inst = Instantiate(bus_arbiter(b.func), prefix + "_inst");

    // Connect clock and reset
    inst->prt("bcd") <<= bcr;

    // TODO(johanpel): for now, we only support one top-level bus spec, so we connect all arbiter generics to it.
    //  Also we just connect the top-level port directly.
    ConnectBusParam(inst, "", bus_params, this->inst_to_comp_map());
    if (b.func == BusFunction::READ) {
      Connect(bus_rd, inst->Get<Port>("mst"));
      Add(bus_rd);
    } else {
      Connect(bus_wr, inst->Get<Port>("mst"));
      Add(bus_wr);
    }
    arb_map[b] = inst;
  }

  // Now we loop over all bus ports again and connect them to the arbiters.
  for (const auto &bp : rb_bus_ports) {
    // Select the corresponding arbiter.
    auto arb = arb_map[BusSpec(bp->spec_)];
    // Get the PortArray.
    auto array = arb->prt_arr("bsv");
    // Append the PortArray and connect.
    Connect(array->Append(), bp);
  }
}

/// @brief Construct a Mantle and return a shared pointer to it.
std::shared_ptr<Mantle> mantle(const std::string &name,
                               const std::vector<std::shared_ptr<RecordBatch>> &recordbatches,
                               const std::shared_ptr<Nucleus> &nucleus,
                               BusDim bus_spec) {
  return std::make_shared<Mantle>(name, recordbatches, nucleus, bus_spec);
}

}  // namespace fletchgen
