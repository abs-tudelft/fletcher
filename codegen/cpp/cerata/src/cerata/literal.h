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

#include <utility>
#include <optional>
#include <string>
#include <memory>
#include <deque>
#include <unordered_map>

#include "cerata/object.h"
#include "cerata/type.h"
#include "cerata/node.h"

namespace cerata {

/**
 * @brief A Literal Node
 *
 * A literal node can be used to store some literal value. A literal node can, for example, be used for Vector Type
 * widths or it can be connected to a Parameter Node, to give the Parameter its value.
 */
class Literal : public MultiOutputNode {
 public:
  /// The storage type of the literal value.
  enum class StorageType { INT, STRING, BOOL };
 protected:
  /// @brief Literal constructor.
  Literal(std::string name,
          const std::shared_ptr<Type> &type,
          StorageType st,
          std::string str_val,
          int int_val,
          bool bool_val)
      : MultiOutputNode(std::move(name), Node::NodeID::LITERAL, type),
        storage_type_(st),
        Bool_val_(bool_val),
        Int_val_(int_val),
        String_val_(std::move(str_val)) {}

  /// The raw storage type of the literal node.
  StorageType storage_type_;

  // Macros to generate Literal functions for different storage types.
#ifndef LITERAL_DECL_FACTORY
#define LITERAL_DECL_FACTORY(NAME, TYPENAME)                                                                        \
 public:                                                                                                            \
  explicit Literal(std::string name, const std::shared_ptr<Type> &type, TYPENAME value);                            \
  static std::shared_ptr<Literal> Make##NAME(TYPENAME value);                                                       \
  static std::shared_ptr<Literal> Make##NAME(const std::shared_ptr<Type> &type, TYPENAME value);                    \
  static std::shared_ptr<Literal> Make##NAME(std::string name, const std::shared_ptr<Type> &type, TYPENAME value);  \
  TYPENAME NAME##Value() const { return NAME##_val_; }                                                              \
                                                                                                                    \
 protected:                                                                                                         \
  TYPENAME NAME##_val_{};
#endif

  /// Bools
 LITERAL_DECL_FACTORY(Bool, bool) //NOLINT
  /// Ints
 LITERAL_DECL_FACTORY(Int, int) //NOLINT
  /// Strings
 LITERAL_DECL_FACTORY(String, std::string) //NOLINT

 public:
  /// @brief Create a boolean literal.
  static std::shared_ptr<Literal> Make(bool value) { return MakeBool(value); }
  /// @brief Create an integer literal.
  static std::shared_ptr<Literal> Make(int value) { return MakeInt(value); }
  /// @brief Create a string literal.
  static std::shared_ptr<Literal> Make(std::string value) { return MakeString(std::move(value)); }

  /// @brief Create a copy of this Literal.
  std::shared_ptr<Object> Copy() const override;
  /// @brief Add an input to this node.
  std::shared_ptr<Edge> AddSource(Node *source) override;

  /// @brief A literal node has no inputs. This function returns an empty list.
  inline std::deque<Edge *> sources() const override { return {}; }
  /// @brief Get the output edges of this Node.
  inline std::deque<Edge *> sinks() const override { return ToRawPointers(outputs_); }

  /// @brief Convert the Literal value to a human-readable string.
  std::string ToString() const override;

  /// @brief Return the storage type of the literal.
  StorageType storage_type() const { return storage_type_; }
};

/**
 * @brief Obtain the raw value of a literal node.
 * @tparam T    The compile-time return type.
 * @param node  The node to obtain the value from.
 * @return      The value of type T.
 */
template<typename T>
T RawValueOf(const Literal &node) { throw std::runtime_error("Can not obtain raw value for type."); }

/// @brief Template specialization for RawValueOf<bool>
template<>
inline bool RawValueOf(const Literal &node) { return node.BoolValue(); }

/// @brief Template specialization for RawValueOf<int>
template<>
inline int RawValueOf(const Literal &node) { return node.IntValue(); }

/// @brief Template specialization for RawValueOf<std::string>
template<>
inline std::string RawValueOf(const Literal &node) { return node.StringValue(); }

/// @brief Obtain the Literal::StorageType enum value of a C++ type T.
template<typename T>
Literal::StorageType StorageTypeOf() { throw std::runtime_error("Type has no known StorageType."); }

/// @brief Template specialization for StorageTypeOf<bool>
template<>
inline Literal::StorageType StorageTypeOf<bool>() { return Literal::StorageType::BOOL; }

/// @brief Template specialization for StorageTypeOf<int>
template<>
inline Literal::StorageType StorageTypeOf<int>() { return Literal::StorageType::INT; }

/// @brief Template specialization for StorageTypeOf<std::string>
template<>
inline Literal::StorageType StorageTypeOf<std::string>() { return Literal::StorageType::STRING; }

}  // namespace cerata
