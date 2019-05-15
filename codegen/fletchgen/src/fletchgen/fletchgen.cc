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

#include <fstream>
#include <cerata/api.h>
#include <fletcher/common/api.h>

#include "fletchgen/options.h"
#include "fletchgen/design.h"
#include "fletchgen/utils.h"
#include "fletchgen/srec/recordbatch.h"
#include "fletchgen/top/sim.h"

std::vector<uint64_t> GenerateSREC(const std::shared_ptr<fletchgen::Options> &options,
                                   const std::vector<std::shared_ptr<arrow::Schema>> &schemas,
                                   std::vector<std::pair<uint32_t, uint32_t>>* firstlastidx=nullptr) {
  if (options->recordbatch_paths.size() != schemas.size()) {
    throw std::runtime_error("Number of schemas does not correspond to number of RecordBatches.");
  }

  std::deque<std::shared_ptr<arrow::RecordBatch>> recordbatches;
  for (size_t i=0;i<schemas.size();i++) {
    auto rb = fletcher::readRecordBatchFromFile(options->recordbatch_paths[i], schemas[i]);
    recordbatches.push_back(rb);
  }

  auto srec_buffer_offsets = fletchgen::srec::WriteRecordBatchesToSREC(recordbatches, options->srec_out_path);

  if (firstlastidx != nullptr) {
    for (const auto& rb : recordbatches) {
      (*firstlastidx).emplace_back(0, rb->num_rows());
    }
  }
  return srec_buffer_offsets;
}

int main(int argc, char **argv) {
  // Start logging
  std::string program_name = GetProgramName(argv[0]);
  cerata::StartLogging(program_name, LOG_DEBUG, program_name + ".log");

  // Parse options
  auto options = std::make_shared<fletchgen::Options>();
  fletchgen::Options::Parse(options.get(), argc, argv);

  fletchgen::Design design;

  std::vector<uint64_t> srec_buf_offsets;
  std::vector<std::pair<uint32_t, uint32_t>> first_last_indices;

  // Generate designs in Cerata
  if (options->MustGenerateDesign()) {
    design = fletchgen::Design::GenerateFrom(options);
  } else {
    return -1;
  }

  // Generate SREC output
  if (options->MustGenerateSREC()) {
    LOG(INFO, "Generating SREC output.");
    srec_buf_offsets = GenerateSREC(design.options, design.schemas, &first_last_indices);
  }

  // Generate VHDL output
  if (options->MustGenerateVHDL()) {
    LOG(INFO, "Generating VHDL output.");
    auto vhdl = cerata::vhdl::VHDLOutputGenerator(options->output_dir, design.GetOutputSpec());
    vhdl.Generate();
  }

  // Generate DOT output
  if (options->MustGenerateDOT()) {
    LOG(INFO, "Generating DOT output.");
    auto dot = cerata::dot::DOTOutputGenerator(options->output_dir, design.GetOutputSpec());
    dot.Generate();
  }

  // Generate simulation top level
  if (options->sim_top) {
    auto sim_file = std::ofstream("vhdl/sim_top.vhd");
    fletchgen::top::GenerateSimTop(design.mantle,
                                   {&sim_file},
                                   options->srec_out_path,
                                   srec_buf_offsets,
                                   options->srec_sim_dump,
                                   first_last_indices);
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
