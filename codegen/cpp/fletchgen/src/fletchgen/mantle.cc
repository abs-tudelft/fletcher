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

#include "fletchgen/mantle.h"

#include <cerata/api.h>
#include <fletcher/common.h>

#include <memory>
#include <deque>
#include <utility>
#include <string>
#include <vector>

#include "fletchgen/basic_types.h"
#include "fletchgen/schema.h"
#include "fletchgen/bus.h"
#include "fletchgen/mmio.h"
#include "fletchgen/profiler.h"
#include "fletchgen/nucleus.h"

namespace fletchgen {

using cerata::intl;

static std::string ArbiterMasterName(BusSpec spec) {
  return std::string(spec.function == BusFunction::READ ? "rd" : "wr") + "_mst";
}

Mantle::Mantle(std::string name,
               SchemaSet schema_set,
               const std::vector<fletcher::RecordBatchDescription> &batch_desc)
    : Component(std::move(name)), schema_set_(std::move(schema_set)) {

  // Add default ports
  auto bcr = Port::Make("bcd", cr(), Port::Dir::IN, bus_cd());
  auto kcr = Port::Make("kcd", cr(), Port::Dir::IN, kernel_cd());
  auto regs = MmioPort::Make(Port::Dir::IN);
  AddObject(bcr);
  AddObject(kcr);
  AddObject(regs);

  AddObject(bus_addr_width());

  // Create and add every RecordBatch/Writer.
  for (const auto &fs : schema_set_.schemas()) {
    auto rb = RecordBatch::Make(fs);
    recordbatch_components_.push_back(rb);
    auto rb_inst = AddInstanceOf(rb.get());
    recordbatch_instances_.push_back(rb_inst);
    rb_inst->port("kcd") <<= kcr;
    rb_inst->port("bcd") <<= bcr;
  }

  // Create and add the Nucleus.
  nucleus_ = Nucleus::Make(schema_set_.name(), cerata::ToRawPointers(recordbatch_components()), batch_desc);
  nucleus_inst_ = AddInstanceOf(nucleus_.get());
  nucleus_inst_->port("kcd") <<= kcr;
  nucleus_inst_->port("mmio") <<= regs;

  // Connect all Arrow field derived ports.
  for (const auto &r : recordbatch_instances_) {
    auto field_ports = r->GetAll<FieldPort>();
    for (const auto &fp : field_ports) {
      if (fp->function_ == FieldPort::Function::ARROW) {
        // If the port is an output, it's an input for the kernel and vice versa.
        // Connect the ports and remember the edge.
        std::shared_ptr<cerata::Edge> e;
        if (fp->dir() == cerata::Term::Dir::OUT) {
          e = Connect(nucleus_inst_->port(fp->name()), fp);
        } else {
          e = Connect(fp, nucleus_inst_->port(fp->name()));
        }
        // if profiling enabled...insert a signal between the edge.
        auto s = cerata::insert(e.get(), "p_", this);
        s->meta[PROFILE] = "true";

      } else if (fp->function_ == FieldPort::Function::COMMAND) {
        Connect(fp, nucleus_inst_->port(fp->name()));
      } else if (fp->function_ == FieldPort::Function::UNLOCK) {
        Connect(nucleus_inst_->port(fp->name()), fp);
      }
    }
  }

  std::deque<BusSpec> bus_specs;
  std::deque<BusPort *> bus_ports;

  // For all the bus interfaces, figure out which unique bus specifications there are.
  for (const auto &r : recordbatch_instances_) {
    auto r_bus_ports = r->GetAll<BusPort>();
    for (const auto &b : r_bus_ports) {
      bus_specs.push_back(b->spec_);
      bus_ports.push_back(b);
    }
  }

  // Leave only unique bus specs.
  auto last = std::unique(bus_specs.begin(), bus_specs.end());
  bus_specs.erase(last, bus_specs.end());

  // Generate a BusArbiterVec for every unique bus specification.
  for (const auto &spec : bus_specs) {
    FLETCHER_LOG(DEBUG, "Adding bus arbiter for: " + spec.ToString());
    auto arbiter_instance = BusArbiterInstance(spec);
    auto arbiter = arbiter_instance.get();
    AddChild(std::move(arbiter_instance));
    arbiter->par(bus_addr_width()->name()) <<= intl(spec.addr_width);
    arbiter->par(bus_data_width()->name()) <<= intl(spec.data_width);
    arbiter->par(bus_len_width()->name()) <<= intl(spec.len_width);
    if (spec.function == BusFunction::WRITE) {
      arbiter->par(bus_strobe_width()->name()) <<= intl(static_cast<int>(spec.data_width / 8));
    }
    arbiters_[spec] = arbiter;
    // Create the bus port on the mantle level.
    auto master = BusPort::Make(ArbiterMasterName(spec), Port::Dir::OUT, spec);
    AddObject(master);
    // TODO(johanpel): actually support multiple bus specs
    // Connect the arbiter master port to the mantle master port.
    master <<= arbiter->port("mst");
    // Connect the bus clock domain.
    arbiter->port("bcd") <<= bcr;
  }

  // Connect bus ports to the arbiters.
  for (const auto &bp : bus_ports) {
    // Get the arbiter port.
    auto arbiter = arbiters_.at(bp->spec_);
    auto arbiter_port_array = arbiter->porta("bsv");
    // Generate a mapper. TODO(johanpel): implement bus ports with same spec to map automatically.
    auto mapper = TypeMapper::MakeImplicit(bp->type(), arbiter_port_array->type());
    bp->type()->AddMapper(mapper);
    Connect(arbiter_port_array->Append(), bp);
  }
}

std::shared_ptr<Mantle> Mantle::Make(std::string name,
                                     const SchemaSet &schema_set,
                                     const std::vector<fletcher::RecordBatchDescription> &batch_desc) {
  auto mantle = new Mantle(std::move(name), schema_set, batch_desc);
  auto mantle_shared = std::shared_ptr<Mantle>(mantle);
  cerata::default_component_pool()->Add(mantle_shared);
  return mantle_shared;
}

std::shared_ptr<Mantle> Mantle::Make(const SchemaSet &schema_set,
                                     const std::vector<fletcher::RecordBatchDescription> &batch_desc) {
  return Make("Mantle", schema_set, batch_desc);
}

}  // namespace fletchgen
