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

#include "cerata/node.h"

namespace cerata {
/**
 * @brief A Parameter node.
 *
 * Can be used as a type generic node or as input to signal or port nodes.
 */
class Parameter : public NormalNode {
 public:
  /// @brief Construct a new Parameter, optionally defining a default value Literal.
  Parameter(std::string name, const std::shared_ptr<Type> &type, std::shared_ptr<Literal> default_value);
  /// @brief Create a copy of this Parameter.
  std::shared_ptr<Object> Copy() const override;
  /// @brief Return the value node.
  Node *value() const;
  /// @brief Set the value of the parameter node. Can only be expression, parameter, or literal.
  Parameter *SetValue(const std::shared_ptr<Node> &value);
  /// @brief Append this node and nodes that source this node's value, until an expression or literal is encountered.
  void TraceValue(std::vector<Node *> *trace);
  /// @brief Return the default value node.
  Literal *default_value() { return default_value_.get(); }

  // TODO(johanpel): Work-around for parameters nodes that are size nodes of arrays.
  //  To prevent this, it requires a restructuring of node arrays.
  /// If this parametrizes a node array, this stores a pointer to the NodeArray.
  std::optional<NodeArray *> node_array_parent;

  /// Parameter value.
  std::shared_ptr<Literal> default_value_;
};

/**
 * @brief Create a new parameter.
 *
 * If no default value is supplied, a default value is implicitly created based on the type.
 *
 * @param name           The name of the parameter.
 * @param type           The type of the parameter.
 * @param default_value  The default value of the parameter.
 * @return               A shared pointer to a new parameter.
 */
std::shared_ptr<Parameter> parameter(const std::string &name,
                                     const std::shared_ptr<Type> &type,
                                     std::shared_ptr<Literal> default_value = nullptr);

/// @brief Create a new integer-type parameter.
std::shared_ptr<Parameter> parameter(const std::string &name, int default_value);

/// @brief Create a new integer-type parameter with default value 0.
std::shared_ptr<Parameter> parameter(const std::string &name);

/// @brief Create a new boolean-type parameter.
std::shared_ptr<Parameter> parameter(const std::string &name, bool default_value);

/// @brief Create a new string-type parameter.
std::shared_ptr<Parameter> parameter(const std::string &name, std::string default_value);

}  // namespace cerata
