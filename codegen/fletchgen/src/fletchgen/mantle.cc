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

#include <memory>
#include <deque>
#include <utility>
#include <cerata/api.h>
#include <fletcher/common/api.h>

#include "fletchgen/basic_types.h"
#include "fletchgen/array.h"
#include "fletchgen/schema.h"
#include "fletchgen/bus.h"

namespace fletchgen {

Mantle::Mantle(std::string name, std::shared_ptr<SchemaSet> schema_set)
    : Component(std::move(name)), schema_set_(std::move(schema_set)) {
  // Create and add every RecordBatchReader/Writer
  for (const auto &fs : schema_set_->read_schemas) {
    auto rbr = RecordBatchReader::Make(fs);
    auto rbr_inst = Instance::Make(rbr);
    rb_reader_instances_.push_back(rbr_inst.get());
    AddChild(std::move(rbr_inst));
  }

  // Create and add the kernel
  kernel_ = Kernel::Make(schema_set_->name(), reader_components());
  auto ki = Instance::Make(kernel_);
  kernel_inst_ = ki.get();
  AddChild(std::move(ki));

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

  // Create and add the bus read arbiter
  auto brai = Instance::Make(BusReadArbiter());
  auto bra_inst = brai.get();
  AddChild(std::move(brai));

  // Connect all buses
  for (const auto &r : rb_reader_instances_) {
    // Connect all request channels
    for (const auto& req : r->porta("bus_rreq")->nodes()) {
      bra_inst->porta("bsv_rreq")->Append() <<= req;
    }
    for (const auto& dat : r->porta("bus_rdat")->nodes()) {
      dat <<= bra_inst->porta("bsv_rdat")->Append();
    }
  }

  // arrays aan arrays, veel plezier morgen!

}

std::shared_ptr<Mantle> Mantle::Make(std::string name, const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<Mantle>(name, schema_set);
}

std::shared_ptr<Mantle> Mantle::Make(const std::shared_ptr<SchemaSet> &schema_set) {
  return std::make_shared<Mantle>(schema_set->name() + "_mantle", schema_set);
}

std::deque<std::shared_ptr<RecordBatchReader>> Mantle::reader_components() {
  std::deque<std::shared_ptr<RecordBatchReader>> result;
  for (const auto &r : rb_reader_instances_) {
    result.push_back(*cerata::Cast<RecordBatchReader>(r->component));
  }
  return result;
}

}  // namespace fletchgen
