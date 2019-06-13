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

#include "fletcher/common.h"
#include "fletchgen/design.h"
#include "fletchgen/recordbatch.h"

namespace fletchgen {

using OutputSpec=cerata::OutputGenerator::OutputSpec;
using RBVector=std::vector<std::shared_ptr<arrow::RecordBatch>>;

static std::optional<std::shared_ptr<arrow::RecordBatch>> GetRecordBatchWithName(const RBVector &batches,
                                                                                 const std::string &name) {
  for (const auto &b :  batches) {
    if (fletcher::GetMeta(*b->schema(), "fletcher_name") == name) {
      return b;
    }
  }
  return std::nullopt;
}

fletchgen::Design fletchgen::Design::GenerateFrom(const std::shared_ptr<Options> &opts) {
  Design ret;
  ret.options = opts;

  // Attempt to create a SchemaSet from all schemas that can be detected in the options.
  FLETCHER_LOG(INFO, "Creating SchemaSet.");
  ret.schema_set = SchemaSet::Make(ret.options->kernel_name);
  // Add all schemas from the list of schema files
  for (const auto &arrow_schema : ret.options->schemas) {
    ret.schema_set->AppendSchema(arrow_schema);
  }
  // Add all schemas from the recordbatches and add all recordbatches.
  for (const auto &recordbatch : ret.options->recordbatches) {
    ret.schema_set->AppendSchema(recordbatch->schema());
  }

  ret.schema_set->Sort();

  // Now that we have every Schema, for every Schema, figure out if there is a RecordBatch in the input options.
  // If there is, add a description of the RecordBatch to this design.
  // If there isn't, create a virtual RecordBatch based on the schema.
  for (const auto &fletcher_schema : ret.schema_set->schemas()) {
    auto rb = GetRecordBatchWithName(ret.options->recordbatches, fletcher_schema->name());
    fletcher::RecordBatchDescription rbd;
    if (rb) {
      fletcher::RecordBatchAnalyzer rba(&rbd);
      rba.Analyze(**rb);
    } else {
      fletcher::SchemaAnalyzer sa(&rbd);
      sa.Analyze(*fletcher_schema->arrow_schema());
    }
    ret.batch_desc.push_back(rbd);
  }

  // Generate the hardware structure through Mantle and extract all subcomponents.
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
  for (const auto &r : readers) {
    OutputSpec oreader(r);
    oreader.meta["overwrite"] = "true";
    ret.push_back(oreader);
  }

  return ret;
}

} // namespace fletchgen
