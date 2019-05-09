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

#include <unordered_map>
#include <memory>
#include <deque>
#include <utility>
#include <cerata/api.h>
#include <fletcher/common/api.h>

#include "fletchgen/basic_types.h"
#include "fletchgen/array.h"
#include "fletchgen/schema.h"
#include "fletchgen/bus.h"
#include "fletchgen/mmio.h"

namespace fletchgen {

Mantle::Mantle(std::string name, std::shared_ptr<SchemaSet> schema_set)
    : Component(std::move(name)), schema_set_(std::move(schema_set)) {

  // Add default ports
  AddObject(Port::Make(bus_cr()));
  AddObject(Port::Make(kernel_cr()));
  AddObject(Port::Make(mmio()));

  // Create and add every RecordBatchReader/Writer
  for (const auto &fs : schema_set_->read_schemas) {
    auto rbr = RecordBatchReader::Make(fs);
    auto rbr_inst = Instance::Make(rbr);
    rb_reader_instances_.push_back(rbr_inst.get());
    AddChild(std::move(rbr_inst));
  }

  // Create and add the kernel
  kernel_ = Kernel::Make(schema_set_->name(), reader_components());
  kernel_inst_ = AddInstanceOf(kernel_);

  // Connect all Arrow field derived
  for (const auto &r : rb_reader_instances_) {
    auto field_ports = r->GetAll<FieldPort>();
    for (const auto &fp : field_ports) {
      if (fp->function_ == FieldPort::Function::ARROW) {
        kernel_inst_->port(fp->name()) <<= fp;
      } else if (fp->function_ == FieldPort::Function::COMMAND) {
        fp <<= kernel_inst_->port(fp->name());
      }
    }
  }

  std::deque<BusSpec> bus_specs;
  std::deque<std::shared_ptr<BusPort>> bus_ports;

  // For all the bus interfaces, figure out which unique bus specifications there are.
  for (const auto &rbri : rb_reader_instances_) {
    // Figure out what bus channels the component has
    auto rbr = *Cast<RecordBatchReader>(rbri->component);
    for (const auto &b : rbr->bus_ports()) {
      bool add_spec = true;
      for (const auto &spec : bus_specs) {
        if (spec == b->spec_) {
          add_spec = false;
          break;
        }
      }
      if (add_spec) {
        bus_specs.push_back(b->spec_);
      }
      bus_ports.push_back(b);
    }
  }

  // Generate a BusArbiterVec for every unique bus specification
  for (const auto &spec : bus_specs) {
    LOG(DEBUG, "Adding bus arbiter for: " + spec.ToString());
    auto arbiter = AddInstanceOf(BusReadArbiter());
    arbiter->par(bus_addr_width()->name()) <<= Literal::Make(spec.addr_width);
    arbiter->par(bus_data_width()->name()) <<= Literal::Make(spec.data_width);
    arbiter->par(bus_len_width()->name()) <<= Literal::Make(spec.len_width);
    arbiters_[spec] = arbiter;
    auto master = *Cast<BusPort>(arbiter->port("mst")->Copy());
    master->SetName(spec.ToShortString());
    master <<= arbiter->port("mst");
    AddObject(master);
  }

  // Connect bus ports to the arbiters
  for (const auto &bp : bus_ports) {
    auto arb = arbiters_.at(bp->spec_);
    arb->porta("bsv")->Append() <<= bp;
  }
}

std::shared_ptr<Mantle> Mantle::Make(std::string name, const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<Mantle>(name, schema_set);
}

std::shared_ptr<Mantle> Mantle::Make(const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<Mantle>(schema_set->name() + "_Mantle", schema_set);
}

std::deque<std::shared_ptr<RecordBatchReader>> Mantle::reader_components() {
  std::deque<std::shared_ptr<RecordBatchReader>> result;
  for (const auto &r : rb_reader_instances_) {
    result.push_back(*cerata::Cast<RecordBatchReader>(r->component));
  }
  return result;
}

}  // namespace fletchgen
