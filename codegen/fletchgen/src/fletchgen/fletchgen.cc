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
#include <fletcher/common/api.h>

#include "fletchgen/options.h"
#include "fletchgen/design.h"
#include "fletchgen/utils.h"
#include "fletchgen/srec/recordbatch.h"

void GenerateSREC(const std::shared_ptr<fletchgen::Options> &options,
                  const std::vector<std::shared_ptr<arrow::Schema>> &schemas) {
  // TODO(johanpel): allow multiple recordbatches
  auto recordbatch = fletcher::readRecordBatchFromFile(options->recordbatch_paths[0], schemas[0]);
  auto srec_buffers = fletchgen::srec::writeRecordBatchToSREC(recordbatch.get(), options->srec_out_path);
}

int main(int argc, char **argv) {
  // Start logging
  std::string program_name = GetProgramName(argv[0]);
  cerata::StartLogging(program_name, LOG_DEBUG, program_name + ".log");

  // Parse options
  auto options = std::make_shared<fletchgen::Options>();
  fletchgen::Options::Parse(options.get(), argc, argv);

  fletchgen::Design design;

  // Generate designs in Cerata
  if (options->MustGenerateDesign()) {
    design = fletchgen::Design::GenerateFrom(options);
  } else {
    return -1;
  }

  // Generate SREC output
  if (options->MustGenerateSREC()) {
    LOG(INFO, "Generating SREC output.");
    GenerateSREC(design.options, design.schemas);
  }

  // Generate VHDL output
  if (options->MustGenerateVHDL()) {
    LOG(INFO, "Generating VHDL output.");
    auto vhdl = cerata::vhdl::VHDLOutputGenerator(options->output_dir, design.GetAllComponents());
    vhdl.Generate();
  }

  // Generate DOT output
  if (options->MustGenerateDOT()) {
    LOG(INFO, "Generating DOT output.");
    auto dot = cerata::dot::DOTOutputGenerator(options->output_dir, design.GetAllComponents());
    dot.Generate();
  }

  // Generate simulation top level
  if (options->sim_top) {
    LOG(WARNING, "Generating simulation top-level not yet implemented.");
  }

  // Generate AXI top level
  if (options->axi_top) {
    LOG(WARNING, "Generating AXI top-level not yet implemented.");
  }

  LOG(INFO, program_name + " completed.");

  // Shut down logging
  cerata::StopLogging();

  return 0;
}
