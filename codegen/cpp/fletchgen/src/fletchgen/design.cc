// Copyright 2018-2019 Delft University of Technology
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

#include <string>
#include <vector>
#include <regex>
#include <algorithm>
#include <thread>

#include "fletcher/common.h"
#include "fletchgen/design.h"
#include "fletchgen/recordbatch.h"
#include "fletchgen/mmio.h"
#include "fletchgen/profiler.h"
#include "fletchgen/bus.h"

namespace fletchgen {

using cerata::OutputSpec;

/// Short-hand for vector of RecordBatches.
using RBVector = std::vector<std::shared_ptr<arrow::RecordBatch>>;

static std::optional<std::shared_ptr<arrow::RecordBatch>> GetRecordBatchWithName(const RBVector &batches,
                                                                                 const std::string &name) {
  for (const auto &b :  batches) {
    if (fletcher::GetMeta(*b->schema(), fletcher::meta::NAME) == name) {
      return b;
    }
  }
  return std::nullopt;
}

void Design::AnalyzeSchemas() {
  // Attempt to create a SchemaSet from all schemas that can be detected in the options.
  schema_set = SchemaSet::Make(options->kernel_name);
  // Add all schemas from the list of schema files
  for (const auto &arrow_schema : options->schemas) {
    schema_set->AppendSchema(arrow_schema);
  }
  // Add all schemas from the recordbatches and add all recordbatches.
  for (const auto &recordbatch : options->recordbatches) {
    schema_set->AppendSchema(recordbatch->schema());
  }
  // Sort the schema set according to the recordbatch ordering specification.
  // Important for the control flow through MMIO / buffer addresses.
  // First we sort recordbatches by name, then by mode.
  schema_set->Sort();
}

void Design::AnalyzeRecordBatches() {
  // Now that we have every Schema, for every Schema, figure out if there is a RecordBatch in the input options.
  // If there is, add a description of the RecordBatch to this design.
  // If there isn't, create a virtual RecordBatch based on the schema.
  for (const auto &fletcher_schema : schema_set->schemas()) {
    auto rb = GetRecordBatchWithName(options->recordbatches, fletcher_schema->name());
    fletcher::RecordBatchDescription rbd;
    if (rb) {
      fletcher::RecordBatchAnalyzer rba(&rbd);
      rba.Analyze(**rb);
    } else {
      fletcher::SchemaAnalyzer sa(&rbd);
      sa.Analyze(*fletcher_schema->arrow_schema());
    }
    batch_desc.push_back(rbd);
  }
}

static std::vector<MmioReg> GetDefaultRegs() {
  std::vector<MmioReg> result;
  result.emplace_back(MmioFunction::DEFAULT, MmioBehavior::STROBE, "start", "Start the kernel.", 1, 0, 0);
  result.emplace_back(MmioFunction::DEFAULT, MmioBehavior::STROBE, "stop", "Stop the kernel.", 1, 1, 0);
  result.emplace_back(MmioFunction::DEFAULT, MmioBehavior::STROBE, "reset", "Reset the kernel.", 1, 2, 0);
  result.emplace_back(MmioFunction::DEFAULT, MmioBehavior::STATUS, "idle", "Kernel idle status.", 1, 0, 4);
  result.emplace_back(MmioFunction::DEFAULT, MmioBehavior::STATUS, "busy", "Kernel busy status.", 1, 1, 4);
  result.emplace_back(MmioFunction::DEFAULT, MmioBehavior::STATUS, "done", "Kernel done status.", 1, 2, 4);
  result.emplace_back(MmioFunction::DEFAULT, MmioBehavior::STATUS, "result", "Result.", 64, 0, 8);
  return result;
}

std::vector<MmioReg> Design::ParseCustomRegs(const std::vector<std::string> &regs) {
  constexpr char regex_str[] = R"(([cs]):(\d+):(\w+):?(0x[0-9a-fA-F]+)?)";
  std::vector<MmioReg> result;
  // Iterate and parse every string.
  for (const auto &text : regs) {
    std::regex regex(regex_str);
    std::smatch sub_match;
    if (std::regex_search(text, sub_match, regex)) {
      MmioReg reg;
      reg.function = MmioFunction::KERNEL;
      reg.behavior = sub_match[1].str() == "c" ? MmioBehavior::CONTROL : MmioBehavior::STATUS;
      reg.name = sub_match[3].str();
      reg.desc = "Custom register " + reg.name;
      reg.width = std::strtoul(sub_match[2].str().c_str(), nullptr, 10);
      reg.index = 0;
      if (sub_match.size() > 4) {
        reg.init = std::strtoul(sub_match[4].str().c_str(), nullptr, 10);
      }
      reg.meta["kernel"] = "true";
      result.push_back(reg);
    } else {
      FLETCHER_LOG(ERROR, "Custom register argument " + text + " invalid. Should match: " + regex_str);
    }
  }
  return result;
}

/// @brief Generate mmio registers from properly ordered RecordBatchDescriptions.
std::vector<MmioReg> Design::GetRecordBatchRegs(const std::vector<fletcher::RecordBatchDescription> &batch_desc) {
  std::vector<MmioReg> result;

  // Get first and last indices.
  for (const auto &r : batch_desc) {
    result.emplace_back(MmioFunction::BATCH,
                        MmioBehavior::CONTROL,
                        r.name + "_firstidx",
                        r.name + " first index.",
                        32);
    result.emplace_back(MmioFunction::BATCH,
                        MmioBehavior::CONTROL,
                        r.name + "_lastidx",
                        r.name + " last index (exclusive).",
                        32);
  }

  // Get all buffer addresses.
  for (const auto &r : batch_desc) {
    for (const auto &f : r.fields) {
      for (const auto &b : f.buffers) {
        auto buffer_port_name = r.name + "_" + fletcher::ToString(b.desc_);
        // buf_port_names->push_back(buffer_port_name);
        result.emplace_back(MmioFunction::BUFFER,
                            MmioBehavior::CONTROL,
                            buffer_port_name,
                            "Buffer address for " + r.name + " " + fletcher::ToString(b.desc_),
                            64);
      }
    }
  }
  return result;
}

Design::Design(const std::shared_ptr<Options> &opts) {
  options = opts;

  // Analyze schemas and recordbatches to get schema_set and batch_desc
  AnalyzeSchemas();
  AnalyzeRecordBatches();
  // Sanity check our design for equal number of schemas and recordbatch descriptions.
  if (schema_set->schemas().size() != batch_desc.size()) {
    FLETCHER_LOG(FATAL, "Number of Schemas and RecordBatchDescriptions does not match.");
  }

  // Now that we have parsed some of the options, generate the design from the bottom up.
  // The order in which to do this is from components that sink/source the kernel, to the kernel, and then to the
  // upper layers of the hierarchy.

  // Generate a RecordBatchReader/Writer component for every FletcherSchema / RecordBatchDesc.
  for (size_t i = 0; i < batch_desc.size(); i++) {
    auto schema = schema_set->schemas()[i];
    auto rb_desc = batch_desc[i];
    auto rb = record_batch(opts->kernel_name + "_" + schema->name(), schema, rb_desc);
    recordbatch_comps.push_back(rb);
  }

  // Generate the MMIO component model for this. This is based on four things;
  // 1. The default registers (like control, status, result).
  // 2. The RecordBatchDescriptions - for every recordbatch we need a first and last index, and every buffer address.
  // 3. The custom kernel registers, parsed from the command line arguments.
  // 4. The profiling registers, obtained from inspecting the generated recordbatches.
  default_regs = GetDefaultRegs();
  recordbatch_regs = GetRecordBatchRegs(batch_desc);
  kernel_regs = ParseCustomRegs(opts->regs);
  profiling_regs = GetProfilingRegs(recordbatch_comps);

  auto bus_spec = BusDim::FromString(opts->bus_dims[0], BusDim());

  // Generate the MMIO component.
  mmio_comp = mmio(batch_desc, cerata::Merge({default_regs, recordbatch_regs, kernel_regs, profiling_regs}));
  // Generate the kernel.
  kernel_comp = kernel(opts->kernel_name, recordbatch_comps, mmio_comp);
  // Generate the nucleus.
  nucleus_comp = nucleus(opts->kernel_name + "_Nucleus", recordbatch_comps, kernel_comp, mmio_comp);
  // Generate the mantle.
  mantle_comp = mantle(opts->kernel_name + "_Mantle", recordbatch_comps, nucleus_comp, bus_spec);
}

void Design::RunVhdmmio(const std::vector<std::vector<MmioReg>*>& regs) {
  // Generate a Yaml file for vhdmmio based on the recordbatch description
  auto ofs = std::ofstream("fletchgen.mmio.yaml");
  ofs << GenerateVhdmmioYaml(regs);
  ofs.close();

  // Run vhdmmio
  auto vhdmmio_result = system("python3 -m vhdmmio -V vhdl -H -P vhdl > vhdmmio.log");
  if (vhdmmio_result != 0) {
    FLETCHER_LOG(FATAL, "vhdmmio exited with status " << vhdmmio_result);
  }
}

std::vector<cerata::OutputSpec> Design::GetOutputSpec() {
  std::vector<OutputSpec> result;
  OutputSpec mantle, kernel, nucleus;

  // Mantle
  mantle.comp = mantle_comp.get();
  result.push_back(mantle);

  // Nucleus
  nucleus.comp = nucleus_comp.get();
  result.push_back(nucleus);

  // Kernel
  kernel.comp = kernel_comp.get();
  result.push_back(kernel);

  // RecordBatchReaders/Writers
  for (const auto &rb : recordbatch_comps) {
    OutputSpec recordbatch;
    recordbatch.comp = rb.get();
    result.push_back(recordbatch);
  }

  // Set backup mode for VHDL backend
  std::string backup = options->backup ? "true" : "false";
  for (auto &o : result) {
    o.meta[cerata::vhdl::meta::BACKUP_EXISTING] = backup;
  }

  return result;
}

}  // namespace fletchgen
