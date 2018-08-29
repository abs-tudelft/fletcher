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

#include <string>
#include <vector>
#include "../column-wrapper.h"

namespace top {

/// @brief Generate a simulation top level on supplied output streams from a ColumnWrapper
std::string generateSimTop(const std::shared_ptr<fletchgen::ColumnWrapper> &col_wrapper,
                           const std::vector<std::ostream *> &outputs,
                           std::string read_srec_path = "",
                           std::vector<uint64_t> buffers = {},
                           std::string write_srec_path = "");

}
