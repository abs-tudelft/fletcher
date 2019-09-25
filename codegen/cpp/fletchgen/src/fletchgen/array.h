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

#include <cerata/api.h>

#include <string>
#include <memory>

#include "fletchgen/basic_types.h"

namespace fletchgen {

using cerata::Component;
using cerata::Instance;
using cerata::intl;

/// @brief Return the width of the control data of this field.
std::shared_ptr<Node> ctrl_width(const arrow::Field &field);

/// @brief Return the tag width of this field. Settable through Arrow metadata. Default = 1.
std::shared_ptr<Node> tag_width(const arrow::Field &field);

// Default streams of ArrayReaders/ArrayWriters

/// @brief Return a Fletcher command stream type.
std::shared_ptr<Type> cmd(const std::shared_ptr<Node> &tag_width,
                          const std::optional<std::shared_ptr<Node>> &ctrl_width = std::nullopt);

/// @brief Fletcher unlock stream
std::shared_ptr<Type> unlock(const std::shared_ptr<Node> &tag_width = intl(1));
/// @brief Fletcher read data
std::shared_ptr<Type> read_data(const std::shared_ptr<Node> &data_width = intl(1));
/// @brief Fletcher write data
std::shared_ptr<Type> write_data(const std::shared_ptr<Node> &data_width = intl(1));

/// @brief Types for ArrayReader/Writer configuration string.
enum class ConfigType {
  ARB,        ///< Arbiter level.
  NUL,        ///< Null bitmap.
  PRIM,       ///< Primitive (fixed-width) fields.
  LIST,       ///< Variable length fields.
  LISTPRIM,   ///< List of primitives. Can have EPC > 1.
  STRUCT      ///< Structs, composed of multiple fields.
};

/**
 * @brief Return a node representing the width of a (flat) Arrow DataType.
 * @param type  The arrow::DataType.
 * @return      A Literal Node representing the width.
 */
std::shared_ptr<Node> GetWidth(const arrow::DataType *type);

/**
 * @brief Return the configuration string type version of an arrow::DataType.
 * @param type  The arrow::DataType.
 * @return      The equivalent ConfigType.
 */
ConfigType GetConfigType(const arrow::DataType *type);

/**
 * @brief Return the configuration string for a ArrayReader/Writer.
 * @param field The arrow::Field to derive the string from.
 * @param level Nesting level for recursive calls to this function.
 * @return      The string.
 */
std::string GenerateConfigString(const arrow::Field &field, int level = 0);

/**
 * @brief Get a type mapper for an Arrow::Field-based stream to an ArrayReader/Writer stream.
 *
 * These type mappers can be automatically deduced based on the generic Fletcher types being used.
 * @param stream_type   The type typically generated with GetStreamType()
 * @param other         The other type, typically some read_data() or write_data() generated type.
 * @return              A type mapper
 */
std::shared_ptr<TypeMapper> GetStreamTypeMapper(Type *stream_type, Type *other);

/**
 * @brief Convert an Arrow::Field into a stream type.
 * @param field The Arrow::Field to convert.
 * @param mode Whether this stream is used for reading or writing.
 * @param level Nesting level.
 * @return The Stream Type.
 */
std::shared_ptr<Type> GetStreamType(const arrow::Field &field, fletcher::Mode mode, int level = 0);

/**
 * @brief Return a parameterized Cerata instance of an Array(Reader/Writer)
 * @param name        Name of the instance.
 * @param mode        Whether the Array(Reader/Writer) instance must READ from memory or WRITE to memory.
 * @param data_width  Data bus width parameter.
 * @param ctrl_width  Command control signal width parameter.
 * @param tag_width   Command/unlock tag width parameter.
 * @return            A unique pointer holding the Array(Reader/Writer) instance.
 */
std::unique_ptr<Instance> ArrayInstance(const std::string &name,
                                        fletcher::Mode mode = fletcher::Mode::READ,
                                        const std::shared_ptr<Node> &data_width = intl(1),
                                        const std::shared_ptr<Node> &ctrl_width = intl(1),
                                        const std::shared_ptr<Node> &tag_width = intl(1));

}  // namespace fletchgen
