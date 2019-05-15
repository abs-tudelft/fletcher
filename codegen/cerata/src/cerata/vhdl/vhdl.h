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

namespace cerata::vhdl {

class VHDLOutputGenerator : public OutputGenerator {
 public:
  explicit VHDLOutputGenerator(std::string root_dir, std::deque<OutputGenerator::OutputSpec> outputs = {})
      : OutputGenerator(std::move(root_dir), std::move(outputs)) {}
  void Generate() override;
  std::string subdir() override { return DEFAULT_SUBDIR; }
};

}  // namespace cerata::vhdl
