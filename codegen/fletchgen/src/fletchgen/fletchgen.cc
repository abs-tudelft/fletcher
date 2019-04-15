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

#include <cerata/graphs.h>
#include <cerata/vhdl/design.h>

#include <fletcher/common/arrow-utils.h>
#include <fletchgen/srec/recordbatch.h>

#include "./cli/CLI11.hpp"

#include "./logging.h"
#include "./options.h"
#include "./kernel.h"

void GenerateSREC(const std::_MakeUniq<Options>::__single_object &options,
                  const std::vector<std::shared_ptr<arrow::Schema>> &schemas) {
  // TODO(johanpel): allow multiple recordbatches
  auto recordbatch = fletcher::readRecordBatchFromFile(options->recordbatches[0], schemas[0]);
  auto srec_buffers = fletchgen::srec::writeRecordBatchToSREC(recordbatch.get(), options->srec_out);
}

std::shared_ptr<cerata::Component> GenerateKernel(const std::shared_ptr<fletchgen::SchemaSet>& schema_set) {
  return fletchgen::Kernel::Make(schema_set);
}

int main(int argc, char **argv) {
  std::string program_name = GetProgramName(argv[0]);
  // Start logging
  fletchgen::logging::StartLogging(program_name, fletchgen::logging::LOG_DEBUG, program_name + ".log");

  // Parse options
  auto options = std::make_unique<Options>();
  Options::Parse(options.get(), argc, argv);

  auto schemas = fletcher::readSchemasFromFiles(options->schemas);
  auto schemaSet = fletchgen::SchemaSet::Make(options->kernel_name, schemas);

  // Run generation

  // SREC output
  if (options->MustGenerateSREC()) {
    GenerateSREC(options, schemas);
  }

  // Kernel level
  LOG(INFO) << "Generating Kernel from SchemaSet";
  auto kernel = GenerateKernel(schemaSet);

  if (options->MustGenerateVHDL()) {
    LOG(INFO) << "Generating VHDL language outputs.";

    LOG(INFO) << "Writing VHDL Kernel file: " + options->kernel_name + ".vhd";
    auto design = cerata::vhdl::Design(kernel);
    auto kernel_source = std::ofstream(options->kernel_name + ".vhd");
    kernel_source << design.Generate().ToString();
    kernel_source.close();
  }


  LOG(INFO) << program_name + " completed.";

  // Shut down logging
  fletchgen::logging::StopLogging();
  return 0;
}
