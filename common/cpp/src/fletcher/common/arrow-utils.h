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

#include <arrow/buffer.h>
#include <arrow/array.h>

namespace fletcher {

/// @brief Access mode for reads / writes to recordbatches, arrays, buffers, etc...
enum class Mode {
  READ, ///< Read mode
  WRITE ///< Write mode
};

/**
 * @brief Based on an Arrow field, append what buffers to expect when an arrow::Array based on this field is created.
 * @param buffers   The buffer names to append to.
 * @param field     The field to analyze
 */
void appendExpectedBuffersFromField(std::vector<std::string>* buffers, const std::shared_ptr<arrow::Field>& field);

/**
 * @brief Append a vector of buffers with the buffers contained within an Arrow::array
 * @param buffers   The buffers to append to
 * @param array     The Arrow::array to append buffers from
 */
void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::Array> &array);

/**
 * @brief Append a vector of buffers with the buffers contained within an Arrow::ArrayData
 * @param buffers   The buffers to append to
 * @param array     The Arrow::ArrayData to append buffers from
 */
void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::ArrayData> &array_data);

/**
 * @brief Given an arrow::Field, and corresponding arrow::Array, append the buffers of the array.
 *
 * This is useful in case the Arrow implementation allocated a validity bitmap buffer even though the field (or any
 * child) was defined to be non-nullable. In this case, the flattened buffers will not contain a validity bitmap buffer.
 *
 * @param buffers   The buffers to append to
 * @param array     The Arrow::Array to append buffers from
 * @param field     The arrow::Field from a schema.
 */
void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers,
                         const std::shared_ptr<arrow::Array> &array,
                         const std::shared_ptr<arrow::Field> &field);

/**
 * @brief Given an arrow::Field, and corresponding arrow::ArrayData, append the buffers of the array.
 *
 * @param buffers   The buffers to append to
 * @param array     The Arrow::ArrayData to append buffers from
 * @param field     The arrow::Field from a schema.
 */
void flattenArrayBuffers(std::vector<arrow::Buffer *> *buffers,
                         const std::shared_ptr<arrow::ArrayData> &array_data,
                         const std::shared_ptr<arrow::Field> &field);

/// @brief From the metadata of an Arrow Field, obtain the value of a specific key.
std::string getMeta(const std::shared_ptr<arrow::Field> &field, const std::string &key);

/// @brief From the metadata of an Arrow Schema, obtain the value of a specific key.
std::string getMeta(const std::shared_ptr<arrow::Schema> &schema, const std::string &key);

/**
 * @brief Return the schema operational mode (read or write) from the metadata, if any.
 * @param schema The Arrow Schema to inspect.
 * @return The schema operational mode, if any. Default = READ.
 */
Mode getMode(const std::shared_ptr<arrow::Schema> &schema);

/**
 * @brief Obtain Elements-Per-Cycle metadata from field, if any.
 * @param field A field optionally holding the metadata about the Elements-Per-Cycle.
 * @return The Elements-Per-Cycle from the field metadata, if it exists. Returns 1 otherwise.
 */
int getEPC(const std::shared_ptr<arrow::Field> &field);

/**
 * @brief Check if a field should be ignored in Fletcher.
 * @param field The field to check the metadata for.
 * @return Return true if the value for the "ignore" metadata key is set to "true", else false.
 */
bool mustIgnore(const std::shared_ptr<arrow::Field>& field);

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

/**
 * Write a schema to a Flatbuffer file
 * @param schema The schema to write.
 * @param file_name File to write to.
 */
void writeSchemaToFile(const std::shared_ptr<arrow::Schema> &schema, const std::string &file_name);

/**
 * @brief Write the data buffers of an arrow::RecordBatch to a file.
 * @param recordbatch The RecordBatch
 * @param filename The output filename.
 */
void writeRecordBatchToFile(const std::shared_ptr<arrow::RecordBatch> &recordbatch, const std::string &filename);

/**
 * @brief Read an arrow::RecordBatch from a file.
 * @param file_name The file to read from.
 * @param schema The expected schema of the data.
 * @return A smart pointer to the arrow::RecordBatch. Throws a runtime_error if something goes wrong.
 */
std::shared_ptr<arrow::RecordBatch> readRecordBatchFromFile(const std::string &file_name,
                                                            const std::shared_ptr<arrow::Schema> &schema);

/**
 * Reads schemas from multiple FlatBuffer files.
 * @param file_names Files to read from.
 * @return The schemas.
 */
std::vector<std::shared_ptr<arrow::Schema>> readSchemasFromFiles(const std::vector<std::string> &file_names);


}  // namespace fletcher
