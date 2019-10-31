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

#include <cerata/api.h>
#include <fletcher/common.h>

#include <string>
#include <memory>
#include <utility>

#include "fletchgen/basic_types.h"

namespace fletchgen {

using cerata::Component;
using cerata::Instance;
using cerata::intl;
using cerata::Literal;

// ArrayReader/Writer parameters:
PARAM_DECL_FACTORY(index_width, 32)
PARAM_DECL_FACTORY(tag_width, 1)

/// @brief Return the number of buffers for the control field.
size_t GetCtrlBufferCount(const arrow::Field &field);
/// @brief Return the tag width of this field as a literal node. Settable through Arrow metadata. Default: 1.
uint32_t GetTagWidth(const arrow::Field &field);

// ArrayReader/Writer types:

/// @brief Return a Fletcher command stream type.
std::shared_ptr<Type> cmd_type(const std::shared_ptr<Node> &index_width,
                               const std::shared_ptr<Node> &tag_width,
                               const std::optional<std::shared_ptr<Node>> &ctrl_width = std::nullopt);
/// @brief Fletcher unlock stream
std::shared_ptr<Type> unlock_type(const std::shared_ptr<Node> &tag_width);

/// @brief Fletcher read data
std::shared_ptr<Type> array_reader_out(uint32_t num_streams = 0, uint32_t full_width = 0);
/// @brief Fletcher read data, where the pair contains {num_streams, full_width}.
std::shared_ptr<Type> array_reader_out(std::pair<uint32_t, uint32_t> spec);

/// @brief Fletcher write data
std::shared_ptr<Type> array_writer_in(uint32_t num_streams = 0, uint32_t full_width = 0);
/// @brief Fletcher write data, where the pair contains {num_streams, full_width}.
std::shared_ptr<Type> array_writer_in(std::pair<uint32_t, uint32_t> spec);

/// @brief Types for ArrayReader/Writer configuration string.
enum class ConfigType {
  ARB,        ///< Arbiter level.
  NUL,        ///< Null bitmap.
  PRIM,       ///< Primitive (fixed-width) fields.
  LIST,       ///< Variable length fields.
  LIST_PRIM,  ///< List of primitives. Can have EPC > 1.
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
 * @param arrow_field The Arrow::Field to convert.
 * @param mode Whether this stream is used for reading or writing.
 * @param level Nesting level.
 * @return The Stream Type.
 */
std::shared_ptr<Type> GetStreamType(const arrow::Field &arrow_field, fletcher::Mode mode, int level = 0);

/**
 * @brief Get the ArrayR/W number of streams and data width from an Arrow Field.
 * @param arrow_field   The field
 * @return              A tuple containing the {no. streams, full data width}.
 */
std::pair<uint32_t, uint32_t> GetArrayDataSpec(const arrow::Field &arrow_field);

/**
 * @brief Return a Cerata component model of an ArrayReader/Writers.
 * @param mode        Whether the Array(Reader/Writer) instance must READ from memory or WRITE to memory.
 * @return            A unique pointer holding the Array(Reader/Writer) instance.
 */
Component *array(fletcher::Mode mode);

}  // namespace fletchgen
