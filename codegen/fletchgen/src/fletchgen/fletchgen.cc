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

#include <cstdlib> // system()

#include <cerata/logging.h>
#include <cerata/graphs.h>

#include <cerata/vhdl/vhdl.h>
#include <cerata/dot/dot.h>

#include <fletcher/common/arrow-utils.h>

#include "fletchgen/cli/CLI11.hpp"
#include "fletchgen/options.h"

#include "fletchgen/srec/recordbatch.h"
#include "fletchgen/kernel.h"
#include "fletchgen/mantle.h"
#include "fletchgen/bus.h"

void CreateDir(std::string dir_name) {
  // TODO(johanpel): Create directories in a portable manner
  system(("mkdir -p " + dir_name).c_str());
}

void GenerateSREC(const std::unique_ptr<Options> &options,
                  const std::vector<std::shared_ptr<arrow::Schema>> &schemas) {
  // TODO(johanpel): allow multiple recordbatches
  auto recordbatch = fletcher::readRecordBatchFromFile(options->recordbatches[0], schemas[0]);
  auto srec_buffers = fletchgen::srec::writeRecordBatchToSREC(recordbatch.get(), options->srec_out);
}

int main(int argc, char **argv) {
  std::string program_name = GetProgramName(argv[0]);
  // Start logging
  cerata::StartLogging(program_name, LOG_DEBUG, program_name + ".log");

  // Parse options
  auto options = std::make_unique<Options>();
  Options::Parse(options.get(), argc, argv);

  auto schemas = fletcher::readSchemasFromFiles(options->schemas);
  auto schema_set = fletchgen::SchemaSet::Make(options->kernel_name, schemas);

  // Run generation

  // SREC output
  if (options->MustGenerateSREC()) {
    GenerateSREC(options, schemas);
  }

  // Generate designs
  LOG(INFO) << "Generating Kernel from SchemaSet.";
  auto kernel = fletchgen::Kernel::Make(schema_set);
  auto mantle = fletchgen::Mantle::Make(schema_set);
  auto artery = fletchgen::Artery::Make(options->kernel_name, nullptr, nullptr, {});

  if (options->MustGenerateVHDL()) {
    // Create the VHDL output generator.
    auto vhdl = cerata::vhdl::VHDLOutputGenerator(options->output_dir, {kernel, mantle, artery});
    // Make sure the subdirectory exists.
    CreateDir(vhdl.subdir());
    // Generate the output files.
    vhdl.Generate();
  }

  if (options->MustGenerateDOT()) {
    auto dot = cerata::dot::DOTOutputGenerator(options->output_dir, {kernel, mantle, artery});
    CreateDir(dot.subdir());
    dot.Generate();
  }

  LOG(INFO) << program_name + " completed.";

  // Shut down logging
  cerata::StopLogging();
  return 0;
}
