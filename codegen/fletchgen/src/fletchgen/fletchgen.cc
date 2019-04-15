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

#include <iostream>

#include <fletcher/common/arrow-utils.h>
#include <fletchgen/srec/recordbatch.h>

#include "./cli/CLI11.hpp"

#include "./logging.h"
#include "./options.h"

void GenerateSREC(const std::_MakeUniq<Options>::__single_object &options,
                  const std::vector<std::shared_ptr<arrow::Schema>> &schemas) {
  // TODO(johanpel): allow multiple recordbatches
  auto recordbatch = fletcher::readRecordBatchFromFile(options->recordbatches[0], schemas[0]);
  auto srec_buffers = fletchgen::srec::writeRecordBatchToSREC(recordbatch.get(), options->srec_out);
}

int main(int argc, char **argv) {
  // Start logging
  fletchgen::logging::StartLogging(argv[0], fletchgen::logging::LOG_DEBUG, std::string(argv[0]) + ".log");

  // Parse options
  auto options = std::make_unique<Options>();
  Options::Parse(options.get(), argc, argv);

  auto schemas = fletcher::readSchemasFromFiles(options->schemas);

  // Run generation
  if (options->MustGenerateSREC()) {
    GenerateSREC(options, schemas);
  }

  // Shut down logging
  fletchgen::logging::StopLogging();
  return 0;
}
