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

#pragma once

#include <cerata/api.h>
#include <fletcher/common.h>

#include <deque>
#include <string>
#include <memory>

#include "fletchgen/schema.h"
#include "fletchgen/recordbatch.h"

namespace fletchgen {

using cerata::Port;
using cerata::Component;

/**
 * @brief The Kernel component to be implemented by the user
 */
struct Kernel : Component {
  explicit Kernel(std::string name, const std::deque<RecordBatch *> &recordbatches = {});
  static std::shared_ptr<Kernel> Make(std::string name, std::deque<RecordBatch *> recordbatches = {});
  std::shared_ptr<SchemaSet> schema_set_;
};

}  // namespace fletchgen
