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

/// @brief Access mode for reads / writes to recordbatches, arrays, buffers, etc. as seen from accelerator kernel.
enum class Mode {
  READ,  ///< Read mode
  WRITE  ///< Write mode
};

/**
 * @brief Based on an Arrow field, append what buffers to expect when an arrow::Array based on this field is created.
 * @param buffers   The buffer names to append to.
 * @param field     The field to analyze
 */
void AppendExpectedBuffersFromField(std::vector<std::string> *buffers, const std::shared_ptr<arrow::Field> &field);

/**
 * @brief Append a vector of buffers with the buffers contained within an Arrow::array
 * @param buffers   The buffers to append to
 * @param array     The Arrow::array to append buffers from
 */
void FlattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::Array> &array);

/**
 * @brief Append a vector of buffers with the buffers contained within an Arrow::ArrayData
 * @param buffers   The buffers to append to
 * @param array     The Arrow::ArrayData to append buffers from
 */
void FlattenArrayBuffers(std::vector<arrow::Buffer *> *buffers, const std::shared_ptr<arrow::ArrayData> &array_data);

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
void FlattenArrayBuffers(std::vector<arrow::Buffer *> *buffers,
                         const std::shared_ptr<arrow::Array> &array,
                         const std::shared_ptr<arrow::Field> &field);

/**
 * @brief Given an arrow::Field, and corresponding arrow::ArrayData, append the buffers of the array.
 *
 * @param buffers   The buffers to append to
 * @param array     The Arrow::ArrayData to append buffers from
 * @param field     The arrow::Field from a schema.
 */
void FlattenArrayBuffers(std::vector<arrow::Buffer *> *buffers,
                         const std::shared_ptr<arrow::ArrayData> &array_data,
                         const std::shared_ptr<arrow::Field> &field);

/// @brief From the metadata of an Arrow Field, obtain the value of a specific key.
std::string GetMeta(const std::shared_ptr<arrow::Field> &field, const std::string &key);

/// @brief From the metadata of an Arrow Schema, obtain the value of a specific key.
std::string GetMeta(const std::shared_ptr<arrow::Schema> &schema, const std::string &key);

/**
 * @brief Return the schema operational mode (read or write) from the metadata, if any.
 * @param schema  The Arrow Schema to inspect.
 * @return        The schema operational mode, if any. Default = READ.
 */
Mode GetMode(const std::shared_ptr<arrow::Schema> &schema);

/**
 * @brief Obtain metadata and convert to integer.
 * @param field   A field
 * @return        The integer the field represents, if it exists. Returns default_to otherwise.
 */
int GetIntMeta(const std::shared_ptr<arrow::Field> &field, std::string key, int default_to);

/**
 * @brief Check if a field should be ignored in Fletcher.
 * @param field   The field to check the metadata for.
 * @return        Return true if the value for the "ignore" metadata key is set to "true", else false.
 */
bool MustIgnore(const std::shared_ptr<arrow::Field> &field);

/**
 * @brief Append the minimum required metadata for Fletcher to a schema. Returns a copy of the schema.
 * @param schema        The Schema to append to.
 * @param schema_name   The Schema name that will be used for hardware generation.
 * @param schema_mode   The Schema mode, i.e. whether to read or write from a RecordBatch as seen by
 *                      the accelerator kernel.
 * @return              A copy of the Schema with metadata appended.
 */
std::shared_ptr<arrow::Schema> AppendMetaRequired(const std::shared_ptr<arrow::Schema> &schema,
                                                  std::string schema_name,
                                                  Mode schema_mode);

/**
 * @brief Append Elements-Per-Cycle metadata to a field. Returns a copy of the field.
 *
 * This works only for primitive and list<primitive> fields.
 *
 * @param field   The field to append to.
 * @param epc     The elements-per-cycle.
 * @return        A copy of the field with metadata appended.
 */
std::shared_ptr<arrow::Field> AppendMetaEPC(const std::shared_ptr<arrow::Field> &field, int epc);

/**
 * @brief Append metadata to a field to signify Fletcher should ignore this field. Returns a copy of the field.
 * @param field   The field to append to.
 * @return        A copy of the field with metadata appended.
 */
std::shared_ptr<arrow::Field> AppendMetaIgnore(const std::shared_ptr<arrow::Field> &field);

/**
 * Write a schema to a Flatbuffer file
 * @param schema      The schema to write.
 * @param file_name   File to write to.
 * @return            The schema.
 */
void WriteSchemaToFile(const std::shared_ptr<arrow::Schema> &schema, const std::string &file_name);

/**
 * @brief Write the data buffers of an arrow::RecordBatch to a file.
 * @param recordbatch The RecordBatch
 * @param filename The output filename.
 */
void WriteRecordBatchToFile(const std::shared_ptr<arrow::RecordBatch> &recordbatch, const std::string &filename);

/**
 * @brief Read an arrow::RecordBatch from a file.
 * @param file_name The file to read from.
 * @param schema The expected schema of the data.
 * @return A smart pointer to the arrow::RecordBatch. Throws a runtime_error if something goes wrong.
 */
std::shared_ptr<arrow::RecordBatch> ReadRecordBatchFromFile(const std::string &file_name,
                                                            const std::shared_ptr<arrow::Schema> &schema);

/**
 * Reads schemas from multiple FlatBuffer files.
 * @param file_names Files to read from.
 * @return The schemas.
 */
std::vector<std::shared_ptr<arrow::Schema>> ReadSchemasFromFiles(const std::vector<std::string> &file_names);

}  // namespace fletcher
