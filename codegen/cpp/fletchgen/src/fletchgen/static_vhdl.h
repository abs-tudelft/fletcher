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

#include <string>

namespace fletchgen {

/**
 * @brief Writes Fletcher's static VHDL files to the given directory.
 * @param real_dir  The real directory to write to.
 * @param emb_dir   The embedded filesystem directory to read from, defaulting
 *                  to the toplevel resource directory ("hardware").
 */
void write_static_vhdl(const std::string &real_dir, const std::string &emb_dir = "hardware");

}  // namespace fletchgen
