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

#pragma once

#include <arrow/api.h>

#include <vector>
#include <memory>
#include <string>

namespace fletchgen {

/// Fletcher program options.
struct Options {
  /// Paths to the schema files.
  std::vector<std::string> schema_paths;
  /// Loaded schemas.
  std::vector<std::shared_ptr<arrow::Schema>> schemas;
  /// Paths to RecordBatches.
  std::vector<std::string> recordbatch_paths;
  /// Loaded RecordBatches.
  std::vector<std::shared_ptr<arrow::RecordBatch>> recordbatches;
  /// Output directory.
  std::string output_dir = ".";
  /// Output languages.
  std::vector<std::string> languages = {"vhdl", "dot"};
  /// SREC output path. This is the path where an SREC file based on input RecordBatches will be placed.
  std::string srec_out_path;
  /// SREC simulation output path, where the simulation should dump the memory contents of written RecordBatches.
  std::string srec_sim_dump;
  /// Name of the Kernel.
  std::string kernel_name = "Kernel";
  /// Custom 32-bit registers.
  std::vector<std::string> regs;
  /// Bus dimensions strings.
  std::vector<std::string> bus_dims = {"64,512,8,1,16"};

  /// Whether to generate an AXI top level.
  bool axi_top = false;
  /// Whether to simulate an AXI top level.
  bool sim_top = false;
  /// Whether to backup any existing generated files.
  bool backup = false;

  /// Vivado HLS template. TODO(johanpel): not yet implemented.
  bool vivado_hls = false;

  /// Whether to quit the program without doing anything (useful for just showing help or version).
  bool quit = false;

  /// Make the output quiet. TODO(johanpel): not yet implemented.
  bool quiet = false;
  /// Make the output verbose. TODO(johanpel): not yet implemented.
  bool verbose = false;

  /// Show version information.
  bool version = false;

  /**
   * @brief Parse command line options and store the result
   * @param options A pointer to the Options object to parse into
   * @param argc    Argument count
   * @param argv    Argument values
   * @return        True if successful, false otherwise.
   */
  static bool Parse(Options *options, int argc, char **argv);

  // Option checkers:

  /// @brief Return true if a design must be generated.
  [[nodiscard]] bool MustGenerateDesign() const;
  /// @brief Return true if an SREC file must be generated.
  [[nodiscard]] bool MustGenerateSREC() const;
  /// @brief Return true if the design must be outputted as VHDL.
  [[nodiscard]] bool MustGenerateVHDL() const;
  /// @brief Return true if the design must be outputted as DOT.
  [[nodiscard]] bool MustGenerateDOT() const;

  /// @brief Load all specified RecordBatches. Returns true if successful, false otherwise.
  [[nodiscard]] bool LoadRecordBatches();
  /// @brief Load all specified Schemas.  Returns true if successful, false otherwise.
  [[nodiscard]] bool LoadSchemas();

  /// @brief Return human-readable options.
  [[nodiscard]] std::string ToString() const;
};

}  // namespace fletchgen
