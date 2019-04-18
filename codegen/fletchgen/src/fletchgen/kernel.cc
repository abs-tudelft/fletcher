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

#include <cerata/logging.h>
#include <fletcher/common/api.h>

#include "fletchgen/basic_types.h"
#include "fletchgen/schema.h"
#include "fletchgen/utils.h"
#include "fletchgen/recordbatch.h"

namespace fletchgen {

using cerata::Cast;

Kernel::Kernel(std::string name,
               std::deque<std::shared_ptr<RecordBatchReader>> readers,
               std::deque<std::shared_ptr<RecordBatchReader>> writers)
    : Component(std::move(name)) {
  for (const auto &r : readers) {
    auto field_ports = r->GetFieldPorts();
    for (const auto &fp : field_ports) {
      AddObject(fp->Copy());
    }
  }
}

std::shared_ptr<Kernel> Kernel::Make(std::string name,
                                     std::deque<std::shared_ptr<RecordBatchReader>> readers,
                                     std::deque<std::shared_ptr<RecordBatchReader>> writers) {
  return std::make_shared<Kernel>(name, readers, writers);
}

}  // namespace fletchgen
