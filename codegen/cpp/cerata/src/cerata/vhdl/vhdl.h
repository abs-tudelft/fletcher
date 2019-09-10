#include <utility>

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

#include <deque>
#include <string>

#include "cerata/vhdl/architecture.h"
#include "cerata/vhdl/block.h"
#include "cerata/vhdl/declaration.h"
#include "cerata/vhdl/design.h"
#include "cerata/vhdl/instantiation.h"
#include "cerata/vhdl/resolve.h"
#include "cerata/vhdl/defaults.h"
#include "cerata/vhdl/template.h"

#include "cerata/output.h"
#include "cerata/logging.h"

/// Contains everything related to the VHDL back-end.
namespace cerata::vhdl {

// Metadata that this back-end understands
namespace metakeys {
/// Setting PRIMITIVE = "true" signifies that a component is a primitive (e.g. has no Cerata internal graph).
constexpr char PRIMITIVE[] = "vhdl_primitive";
/// The VHDL library in which the primitive resides. E.g. LIBRARY = "work"
constexpr char LIBRARY[] = "vhdl_library";
/// The VHDL package in which the primitive resides. E.g. PACKAGE = "MyPackage_pkg"
constexpr char PACKAGE[] = "vhdl_package";
/// Node name to use for VHDL generation
constexpr char NAME[] = "vhdl_name";
/// Forces a signal to be declared as an std_logic_vector, even if its width is only 1.
constexpr char FORCE_VECTOR[] = "vhdl_force_vector";

/// Forces overwriting of generated files.
constexpr char OVERWRITE_FILE[] = "overwrite";

/// Reserved metadata key for stream expansion.
constexpr char WAS_EXPANDED[] = "vhdl_expanded_stream_done";
/// Reserved metadata key for stream expansion.
constexpr char EXPAND_TYPE[] = "vhdl_expand_stream";
}  // namespace metakeys

/// VHDL Output Generator.
class VHDLOutputGenerator : public OutputGenerator {
 public:
  /// Copyright notice to place on top of a file.
  std::string notice_;

  /// @brief Construct a new VHDLOutputGenerator.
  explicit VHDLOutputGenerator(std::string root_dir,
                               std::deque<OutputSpec> outputs = {},
                               std::string notice = "")
      : OutputGenerator(std::move(root_dir), std::move(outputs)), notice_(std::move(notice)) {}

  /// @brief Generate the output.
  void Generate() override;

  /// @brief Return that the VHDLOutputGenerator will place the files in.
  std::string subdir() override { return DEFAULT_SUBDIR; }
};

}  // namespace cerata::vhdl
