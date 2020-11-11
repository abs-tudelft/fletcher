// Copyright 2018-2020 Delft University of Technology
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

#include <map>
#include <cerata/api.h>

#include "fletchgen/external.h"
#include "fletchgen/status.h"

namespace fletchgen {

auto external() -> std::optional<std::shared_ptr<cerata::Type>> {
  auto opt = cerata::default_type_pool()->Get("_external");
  if (opt) {
    return opt.value()->shared_from_this();
  } else {
    return std::nullopt;
  }
}

}