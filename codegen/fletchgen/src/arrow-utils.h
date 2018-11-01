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
#include <memory>
#include <string>

#include <arrow/type.h>

#include "vhdl/vhdl.h"
#include "common.h"

namespace fletchgen {

/// @brief Types for configuration string.
enum class ConfigType {
  ARB,        ///< Arbiter level
  NUL,        ///< Null bitmap
  PRIM,       ///< Primitive (fixed-width) fields
  LIST,       ///< Variable length fields
  LISTPRIM,   ///< List of primitives, can have epc>1
  STRUCT      ///< Structs, composed of multiple fields
};

/**
 * @brief Convert an Arrow DataType to a port Width.
 * @param type The type to convert.
 * @return Width corresponding to the Arrow DataType.
 */
vhdl::Value getWidth(arrow::DataType *type);

/**
 * @brief Obtain Elements-Per-Cycle metadata from field, if any.
 * @param field A field optionally holding the metadata about the Elements-Per-Cycle.
 * @return The Elements-Per-Cycle from the field metadata, if it exists. Returns 1 otherwise.
 */
int getEPC(arrow::Field *field);

/**
 * @brief Convert the Arrow type to a Fletcher configuration string type.
 * @param type The arrow::DataType to convert.
 * @return The Fletcher type for the configuration string
 */
ConfigType getConfigType(arrow::DataType *type);

/**
 * @brief Return the schema operational mode (read or write) from the metadata, if any.
 * @param schema The Arrow Schema to inspect.
 * @return The schema operational mode, if any. Default = READ.
 */
Mode getMode(arrow::Schema *schema);

/**
 * @brief Check if a field should be ignored in wrapper generation.
 * @param field The field to check the metadata for.
 * @return Return true if the value for the "ignore" metadata key is set to "true", else false.
 */
bool mustIgnore(arrow::Field *field);

/**
 * @brief Return a human readable version of a mode.
 * @param mode The mode
 * @return A string saying "read" or "write" depending on the mode.
 */
std::string getModeString(Mode mode);

/// @brief From the metadata of an Arrow Field, obtain the value of a specific key.
std::string getMeta(arrow::Field *field, const std::string &key);

/// @brief From the metadata of an Arrow Schema, obtain the value of a specific key.
std::string getMeta(arrow::Schema *schema, const std::string &key);

/**
 * Write a schema to a Flatbuffer file
 * @param schema The schema to write.
 * @param file_name File to write to.
 */
void writeSchemaToFile(const std::shared_ptr<arrow::Schema> &schema, const std::string &file_name);

/**
 * Reads schemas from multiple FlatBuffer files.
 * @param file_names Files to read from.
 * @return The schemas.
 */
std::vector<std::shared_ptr<arrow::Schema>> readSchemasFromFiles(const std::vector<std::string> &file_names);

/// @brief Generate Arrow key-value metadata to determine the mode (read/write) of a field.
std::shared_ptr<arrow::KeyValueMetadata> metaMode(Mode mode);

/**
 * @brief Generate Arrow key-value metadata to set the elements-per-cycle of a field
 *
 * This currently only works on lists of non-nullable primitives
 * @param epc The elements per cycle at peak throughput on the output of the stream generated from this field.
 * @return The key-value metadata
 */
std::shared_ptr<arrow::KeyValueMetadata> metaEPC(int epc);

/// @brief Generate key-value metadata that tells Fletcher to ignore a specific Arrow field.
std::shared_ptr<arrow::KeyValueMetadata> metaIgnore();

}  // namespace fletchgen
