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

#include <cerata/api.h>
#include <utility>
#include <string>

#include "fletchgen/basic_types.h"
#include "fletchgen/recordbatch.h"
#include "fletchgen/mmio.h"

namespace fletchgen {

Kernel::Kernel(std::string name, Component* nucleus)
    : Component(std::move(name)) {

  // Add clock/reset
  AddObject(Port::Make("kcd", cr(), Port::Dir::IN, kernel_cd()));

}

std::shared_ptr<Kernel> Kernel::Make(const std::string& name, Component* nucleus) {
  return std::make_shared<Kernel>(name, nucleus);
}

}  // namespace fletchgen
