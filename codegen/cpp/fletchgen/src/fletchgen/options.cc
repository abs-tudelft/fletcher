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

#include "fletchgen/options.h"

#include <fletcher/common.h>
#include <CLI/CLI.hpp>

namespace fletchgen {

bool Options::Parse(Options *options, int argc, char **argv) {
  CLI::App app{"Fletchgen - The Fletcher Design Generator"};

  app.get_formatter()->column_width(34);

  // Required options:
  app.add_option("-i,--input", options->schema_paths,
                 "List of files with Arrow Schemas to base design on."
                 "Example: --input file1.fbs file2.fbs file3.fbs")
      ->check(CLI::ExistingFile);

  // Naming options:
  app.add_option("-n,--kernel_name", options->kernel_name,
                 "Name of the accelerator kernel.");

  // Simulation options:
  app.add_option("-r,--recordbatch_input", options->recordbatch_paths,
                 "List of files with Arrow RecordBatches to base design on and use in simulation memory models."
                 "Schemas contained in these RecordBatches may be skipped for the --input option.");
  app.add_option("-s,--recordbatch_output", options->srec_out_path,
                 "Memory model contents output file (formatted as SREC).");
  app.add_option("-t,--srec_dump", options->srec_sim_dump,
                 "Path to dump memory model contents to after simulation (formatted as SREC).");

  // Output options:
  app.add_option("-o,--output_path", options->output_dir,
                 "Path to the output directory to place the generated files. (Default: . )");

  app.add_option("-l,--language", options->languages,
                 "Select the output languages for your design. Each type of output will be stored in a "
                 "seperate subfolder (e.g. <output folder>/vhdl/...). \n"
                 "Available languages:\n"
                 "  vhdl : Export as VHDL files (default).\n"
                 "  dot  : Export as DOT graphs.");

  app.add_flag("-b,--backup", options->backup,
               "Backup generated source code files if they exists already. If this flag is used and the source "
               "file exists already in the specified path, the output filename will be <filename>.bak. This "
               "file is always overwritten.");

  app.add_option("--regs", options->regs,
                 "Names of custom registers in the following format: \"<behavior>:<width>:<name>:<init>\", "
                 "where <behavior> is one character from the following options:\n"
                 "  c : (control) register content is controlled by host-side software.\n"
                 "  s : (status) register content is controlled by hardware kernel.\n"
                 "<init> is optional, and can be used to automatically write to the register in the initialization "
                 "step of the simulation. Init must be a hexadecimal value in the form of 0x01234ABCD.\n"
                 "Example: \"-reg32 c:32:myh2kreg:0xDEADBEEF s:64:mk2hreg\"");

  app.add_option("--bus_specs", options->bus_dims,
                 "Specify top-level bus parameters.\n"
                 "Value must be a tuple of the following form: \"aw,dw,lw,bs,bm\"\n"
                 "Where:\n"
                 "  aw : Bus address width.\n"
                 "  dw : Bus data width.\n"
                 "  lw : Bus burst length width.\n"
                 "  bs : Bus minimum burst size.\n"
                 "  bm : Bus maximum burst size.\n"
                 "Currently supports only one top-level bus specification. Default: \"64,512,64,8,1,16\"");

  app.add_flag("--axi", options->axi_top,
               "Generate AXI top-level template (VHDL only).");
  app.add_flag("--sim", options->sim_top,
               "Generate simulation top-level template (VHDL only).");
  app.add_flag("--vivado_hls", options->vivado_hls,
               "Generate a Vivado HLS kernel template.");

  // Other options:
  app.add_flag("-v,--version", options->version,
               "Show version.");

  // TODO(johanpel): implement the quiet and verbose options
  /*
  app.add_flag("-q,--quiet", options->quiet,
               "Surpress all stdout.");
  app.add_flag("-v,--verbose", options->verbose,
               "More detailed information on stdout.");
  */

  // Try to parse and quit if parsing failed.
  try {
    app.parse(argc, argv);
  } catch (CLI::CallForHelp &e) {
    std::cout << app.help() << std::endl;
    options->quit = true;
    return true;
  } catch (CLI::Error &e) {
    FLETCHER_LOG(ERROR, e.get_name() + ":\n" + e.what());
    return false;
  }

  // Also quit when version is called.
  if (options->version) {
    options->quit = true;
  }

  return true;
}

bool Options::MustGenerateSREC() const {
  if (!srec_out_path.empty()) {
    if (recordbatches.empty()) {
      FLETCHER_LOG(WARNING, "SREC output flag set, but no RecordBatches were supplied.");
      return false;
    }
    return true;
  }
  return false;
}

static bool HasLanguage(const std::vector<std::string> &languages, const std::string &lang) {
  for (const auto &l : languages) {
    if (l == lang) {
      return true;
    }
  }
  return false;
}

bool Options::MustGenerateVHDL() const {
  return HasLanguage(languages, "vhdl") && Options::MustGenerateDesign();
}

bool Options::MustGenerateDOT() const {
  return HasLanguage(languages, "dot") && Options::MustGenerateDesign();
}

bool Options::MustGenerateDesign() const {
  return !schema_paths.empty() || !recordbatch_paths.empty();
}

bool Options::LoadRecordBatches() {
  for (const auto &path : recordbatch_paths) {
    std::vector<std::shared_ptr<arrow::RecordBatch>> rbs;
    FLETCHER_LOG(INFO, "Loading RecordBatch(es) from " + path);
    if (!fletcher::ReadRecordBatchesFromFile(path, &rbs)) {
      return false;
    }
    recordbatches.insert(recordbatches.end(), rbs.begin(), rbs.end());
  }
  return true;
}

bool Options::LoadSchemas() {
  for (const auto &path : schema_paths) {
    std::shared_ptr<arrow::Schema> schema;
    FLETCHER_LOG(INFO, "Loading Schema from " + path);
    if (!fletcher::ReadSchemaFromFile(path, &schema)) {
      return false;
    }
    schemas.push_back(schema);
  }
  return true;
}

std::string Options::ToString() const {
  std::stringstream str;
  str << "Schema paths:\n";
  for (const auto &p : schema_paths) {
    str << "  " << p << "\n";
  }
  str << "RecordBatch paths:\n";
  for (const auto &p : schema_paths) {
    str << "  " << p << "\n";
  }
  return str.str();
}

}  // namespace fletchgen
