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

#include "fletchgen/kernel.h"

#include <cerata/api.h>
#include <utility>
#include <string>
#include <vector>

#include "fletchgen/basic_types.h"
#include "fletchgen/mmio.h"
#include "fletchgen/array.h"

namespace fletchgen {

static void CopyFieldPorts(Component *kernel, const RecordBatch &record_batch, FieldPort::Function fun) {
  // Add Arrow field derived ports with some function.
  auto field_ports = record_batch.GetFieldPorts(fun);
  cerata::NodeMap rebinding;
  for (const auto &fp : field_ports) {
    // Create a copy and invert for the Kernel
    auto copied_port = dynamic_cast<FieldPort *>(fp->CopyOnto(kernel, fp->name(), &rebinding));
    copied_port->Reverse();
  }
}

Kernel::Kernel(std::string name,
               const std::vector<std::shared_ptr<RecordBatch>> &recordbatches,
               const std::shared_ptr<Component> &mmio)
    : Component(std::move(name)) {

  // Add clock/reset
  Add(port("kcd", cr(), Port::Dir::IN, kernel_cd()));

  auto iw = index_width();
  auto tw = tag_width();
  Add({iw, tw});

  // Add ports going to/from RecordBatches.
  for (const auto &r : recordbatches) {
    // Copy over the Arrow data and unlock stream ports.
    CopyFieldPorts(this, *r, FieldPort::Function::ARROW);
    CopyFieldPorts(this, *r, FieldPort::Function::UNLOCK);

    // The command stream at the kernel interface enjoys some simplification towards the user; the buffer addresses
    // in the ctrl field are hidden.
    // We create new command ports based on the command ports of the RecordBatch, but leave out the ctrl field.
    auto rb_cmds = r->GetFieldPorts(FieldPort::Function::COMMAND);
    for (auto &rb_cmd : rb_cmds) {
      // Next, make a simplified version of the command stream for the kernel user.
      auto kernel_cmd =
          command_port(rb_cmd->fletcher_schema_, rb_cmd->field_, iw, tw, std::nullopt, kernel_cd());
      kernel_cmd->Reverse();
      Add(kernel_cmd);
    }
  }

  // Add ports from mmio
  for (const auto &p : mmio->GetAll<Port>()) {
    // Only copy over mmio ports that have the kernel function.
    auto mmio_port = dynamic_cast<MmioPort *>(p);
    if (mmio_port != nullptr) {
      if (ExposeToKernel(mmio_port->reg.function)) {
        auto kernel_port = std::dynamic_pointer_cast<MmioPort>(p->Copy());
        kernel_port->Reverse();
        kernel_port->SetName(mmio_port->reg.name);
        Add(kernel_port);
      }
    }
  }

}

std::shared_ptr<Kernel> kernel(const std::string &name,
                               const std::vector<std::shared_ptr<RecordBatch>> &recordbatches,
                               const std::shared_ptr<Component> &mmio) {
  return std::make_shared<Kernel>(name, recordbatches, mmio);
}

}  // namespace fletchgen
