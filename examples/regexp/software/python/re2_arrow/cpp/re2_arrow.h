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

#include <memory>
#include <vector>
#include <string>
#include <cstdint>

// Apache Arrow
#include <arrow/api.h>

/**
 * Match regular expression using Arrow table as a source
 */
void add_matches_arrow(const std::shared_ptr<arrow::Array> &array,
                       const std::vector<std::string> &regexes,
                       uint32_t* matches);

void add_matches_arrow_omp(const std::shared_ptr<arrow::Array> &array,
                       const std::vector<std::string> &regexes,
                       uint32_t* matches);