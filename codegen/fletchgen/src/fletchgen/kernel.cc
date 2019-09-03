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

#include "fletchgen/kernel.h"

#include <utility>
#include <string>

#include "fletchgen/basic_types.h"
#include "fletchgen/recordbatch.h"
#include "fletchgen/mmio.h"

namespace fletchgen {

Kernel::Kernel(std::string name, const std::deque<RecordBatch *> &recordbatches)
    : Component(std::move(name)) {

  // Add address width
  AddObject(bus_addr_width());

  // Add clock/reset
  AddObject(Port::Make("kcd", cr(), Port::Dir::IN, kernel_domain()));

  // Add MMIO
  AddObject(MmioPort::Make(Port::Dir::IN));

  // Add ports derived from arrow fields
  for (const auto &r : recordbatches) {
    auto field_ports = r->GetFieldPorts();
    for (const auto &fp : field_ports) {
      auto copied_port = std::dynamic_pointer_cast<FieldPort>(fp->Copy());
      copied_port->InvertDirection();
      AddObject(copied_port);
    }
  }
}

std::shared_ptr<Kernel> Kernel::Make(const std::string& name, const std::deque<RecordBatch *>& recordbatches) {
  return std::make_shared<Kernel>(name, recordbatches);
}

}  // namespace fletchgen
