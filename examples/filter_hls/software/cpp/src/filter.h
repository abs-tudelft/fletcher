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
#include <arrow/api.h>

#include "person.h"

std::shared_ptr<arrow::RecordBatch> getSimRB();
std::shared_ptr<arrow::RecordBatch> getOutputRB(int32_t num_entries, int32_t num_chars);

std::shared_ptr<std::vector<std::string>> filterVec(std::shared_ptr<std::vector<Person>> dataset,
                                                    const std::string &last_name,
                                                    zip_t zip);

std::shared_ptr<arrow::StringArray> filterArrow(std::shared_ptr<arrow::RecordBatch> dataset,
                                                const std::string &last_name,
                                                zip_t zip);