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

#include <vector>
#include <string>
#include <cerata/api.h>

namespace fletchgen {

struct Options {
  /// Paths to the schema files
  std::vector<std::string> schema_paths;

  /// Paths to RecordBatches
  std::vector<std::string> recordbatch_paths;

  /// Output directory
  std::string output_dir = ".";

  /// Output languages
  std::vector<std::string> languages = {"vhdl", "dot"};

  /// SREC output path
  std::string srec_out_path = "\"\"";
  std::string srec_sim_dump = "\"\"";

  /// Name of the Kernel
  std::string kernel_name = "Kernel";

  bool axi_top = false;
  bool sim_top = false;
  bool override_kernels = false;

  /// Vivado HLS template
  bool vivado_hls = false;

  bool quiet = false;
  bool verbose = false;

  /**
   * @brief Parse command line options and store the result
   * @param options A pointer to the Options object to parse into
   * @param argc    Argument count
   * @param argv    Argument values
   * @return        0 if successful, something else otherwise.
   */
  static int Parse(Options *options, int argc, char **argv);

  // Option checkers:

  /// @brief Return true if a design must be generated.
  bool MustGenerateDesign();
  /// @brief Return true if an SREC file must be generated.
  bool MustGenerateSREC();
  /// @brief Return true if the design must be outputted as VHDL.
  bool MustGenerateVHDL();
  /// @brief Return true if the design must be outputted as DOT.
  bool MustGenerateDOT();

};

} // namespace fletchgen
