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

#include <vector>
#include <string>
#include <memory>

#include "cerata/type.h"

namespace cerata {

/// @brief A Stream type.
class Stream : public Record {
 public:
  /// Return a 'valid' bit type.
  static std::shared_ptr<Type> valid();
  /// Return a 'ready' bit type.
  static std::shared_ptr<Type> ready();

  /// @brief Stream constructor.
  Stream(const std::string &name,
         const std::string &element_name,
         const std::shared_ptr<Type> &element_type,
         const std::vector<std::shared_ptr<Field>> &control);

  /// @brief Return the stream data field.
  Field *data() { return this->fields_.back().get(); }

  /// @brief Set the element type of this stream.
  Stream &SetElementType(std::shared_ptr<Type> type);
};

/**
 * @brief Construct a new Stream type and return a shared pointer to it.
 *
 * The Stream type is just a sugar coated version of a Record.
 *
 * @param name          The name of the Type.
 * @param element_name  The name of the elements.
 * @param element_type  The type of the elements on the stream.
 * @param control       Fields that should travel on the stream as control information.
 *                      This is a valid and ready signal by default.
 * @return              A shared pointer to the new Stream type.
 */
std::shared_ptr<Stream> stream(const std::string &name,
                               const std::string &element_name,
                               const std::shared_ptr<Type> &element_type,
                               const std::vector<std::shared_ptr<Field>> &control =
                                   {field(Stream::valid()),
                                    field(Stream::ready())->Reverse()});

/**
 * @brief Construct a new Stream type with valid/ready bit control fields, named after the elements.
 * @param element_name  The name of the elements.
 * @param element_type  The type of the elements on the stream.
 * @return              A shared pointer to the new Stream type.
 */
std::shared_ptr<Stream> stream(const std::string &element_name, const std::shared_ptr<Type> &element_type);

/**
 * @brief Construct a new Stream type with valid/ready bit control fields, named after the element type.
 * @param element_type  The type of the elements on the stream.
 * @return              A shared pointer to the new Stream type.
 */
std::shared_ptr<Stream> stream(const std::shared_ptr<Type> &element_type);

}  // namespace cerata
