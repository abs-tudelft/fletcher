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

#include <memory>
#include <vector>

#include <arrow/api.h>

#include <cerata/graphs.h>
#include <cerata/logging.h>

#include <fletcher/common/arrow-utils.h>

#include "fletchgen/schema.h"
#include "fletchgen/options.h"
#include "fletchgen/kernel.h"
#include "fletchgen/mantle.h"
#include "fletchgen/bus.h"
#include "fletchgen/recordbatch.h"

namespace fletchgen {

struct Design {
  static Design GenerateFrom(const std::shared_ptr<Options>& opts);
  std::shared_ptr<Options> options;
  std::vector<std::shared_ptr<arrow::Schema>> schemas;
  std::shared_ptr<SchemaSet> schema_set;
  std::deque<std::shared_ptr<RecordBatchReader>> readers;
  //std::deque<std::shared_ptr<RecordBatchWriter>> writers;
  std::shared_ptr<cerata::Component> kernel;
  std::shared_ptr<cerata::Component> mantle;
  std::shared_ptr<cerata::Component> artery;
  std::shared_ptr<cerata::Component> wrapper;

  std::deque<std::shared_ptr<cerata::Graph>> GetAllComponents();
};

}