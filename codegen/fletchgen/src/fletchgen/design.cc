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

#include <cerata/api.h>

#include "fletchgen/design.h"
#include "fletchgen/recordbatch.h"

namespace fletchgen {

using OutputSpec=cerata::OutputGenerator::OutputSpec;

fletchgen::Design fletchgen::Design::GenerateFrom(const std::shared_ptr<Options> &opts) {
  Design ret;
  ret.options = opts;

  // Read schemas
  FLETCHER_LOG(INFO, "Reading Arrow Schema files.");
  ret.schemas = fletcher::ReadSchemasFromFiles(ret.options->schema_paths);
  FLETCHER_LOG(INFO, "Creating SchemaSet.");
  ret.schema_set = SchemaSet::Make(ret.options->kernel_name, ret.schemas);

  FLETCHER_LOG(INFO, "Generating Mantle...");
  ret.mantle = Mantle::Make(ret.schema_set);
  ret.kernel = ret.mantle->kernel_;
  for (const auto rbri : ret.mantle->recordbatch_instances) {
    ret.readers.push_back(*Cast<RecordBatch>(rbri->component));
  }

  return ret;
}

std::deque<OutputSpec> Design::GetOutputSpec() {
  std::deque<OutputSpec> ret;

  // Mantle
  OutputSpec omantle(mantle);
  omantle.meta["overwrite"] = "true";
  ret.push_back(omantle);

  // Kernel
  OutputSpec okernel(kernel);
  okernel.meta["overwrite"] = "false";
  ret.push_back(okernel);

  // Readers
  for (const auto& r : readers) {
    OutputSpec oreader(r);
    oreader.meta["overwrite"] = "true";
    ret.push_back(oreader);
  }

  return ret;
}

} // namespace fletchgen
