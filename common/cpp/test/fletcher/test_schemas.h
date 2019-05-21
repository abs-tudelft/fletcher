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

#include <arrow/api.h>
#include <memory>

namespace fletcher {

/// @brief Generate a schema of a list with uint8 primitives.
std::shared_ptr<arrow::Schema> GetListUint8Schema();

/// @brief Simplest example schema to read a primitive.
std::shared_ptr<arrow::Schema> GetPrimReadSchema();

/// @brief Simple example schema to write a primitive.
std::shared_ptr<arrow::Schema> GetPrimWriteSchema();

/// @brief A schema to read strings.
std::shared_ptr<arrow::Schema> GetStringReadSchema();
/// @brief A schema to write strings.
std::shared_ptr<arrow::Schema> GetStringWriteSchema();

/// @brief  A struct schema.
std::shared_ptr<arrow::Schema> GetStructSchema();

/// @brief A big example schema containing all field types that Fletcher supports.
std::shared_ptr<arrow::Schema> GetBigSchema();

/// @brief An example schema from a genomics pipeline application.
std::shared_ptr<arrow::Schema> genPairHMMSchema();

/// @brief An example schema with lists of float(64) numbers
std::shared_ptr<arrow::Schema> GetListFloatSchema();

/// @brief An example schema with lists of int(64) numbers
std::shared_ptr<arrow::Schema> GetListIntSchema();

/// #brief An read schema for the filter example
std::shared_ptr<arrow::Schema> GetFilterReadSchema();

/// #brief An write schema for the filter example
std::shared_ptr<arrow::Schema> GetFilterWriteSchema();

} // namespace fletcher
