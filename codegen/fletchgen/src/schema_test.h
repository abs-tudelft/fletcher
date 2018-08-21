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

std::shared_ptr<arrow::Schema> getStringSchema();

std::shared_ptr<arrow::RecordBatch> getStringRB();

/// @brief Simplest example schema.
std::shared_ptr<arrow::Schema> genSimpleReadSchema();

/// @brief Simple example schema with both read and write.
std::shared_ptr<arrow::Schema> genSimpleWriteSchema();

/// @brief A simple example schema.
std::shared_ptr<arrow::Schema> genStringSchema();

/// @brief  A struct schema.
std::shared_ptr<arrow::Schema> genStructSchema();

/// @brief A big example schema containing all field types that Fletcher supports.
std::shared_ptr<arrow::Schema> genBigSchema();

/// @brief An example schema from a genomics pipeline application.
std::shared_ptr<arrow::Schema> genPairHMMSchema();