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

#include <optional>
#include <utility>
#include <memory>
#include <deque>
#include <string>

#include "./utils.h"
#include "./flattypes.h"

namespace fletchgen {

// Forward decl.
class Node;
struct Literal;

template<int T>
std::shared_ptr<Literal> intl();

/**
 * @brief A type
 *
 * Types can logically be classified as follows.
 * - Concrete.
 *      They can be immediately represented as bits in hardware.
 *
 * - Abstract.
 *      They can not implicitly be represented as bits in hardware without a more elaborate definition.
 *
 * - Primitive.
 *      These types contain no subtype.
 *
 * - Nested.
 *      These types contain some subtype.
 *
 */
class Type : public Named {
 public:
  enum ID {
    CLOCK,    ///< Concrete, primitive
    RESET,    ///< Concrete, primitive
    BIT,      ///< Concrete, primitive
    VECTOR,   ///< t.b.d.

    INTEGER,  ///< Abstract, primitive
    STRING,   ///< Abstract, primitive
    BOOLEAN,  ///< Abstract, primitive

    RECORD,   ///< Abstract, nested
    STREAM,   ///< Abstract, nested
  };
  /// @brief Construct a new type.
  explicit Type(std::string name, ID id);

  /// @brief Return true if the Type ID is type_id, false otherwise.
  bool Is(ID type_id) const;
  /// @brief Return true if the Type is a synthesizable primitive, false otherwise.
  bool IsSynthPrim() const;
  /// @brief Return true if the Type is an abstract type, false otherwise.
  bool IsAbstract() const;
  /// @brief Return the width of the type, if it is synthesizable.
  virtual std::optional<std::shared_ptr<Node>> width() const { return {}; }
  /// @brief Return true if type is nested (e.g. Stream or Record), false otherwise.
  bool IsNested() const;
  /// @brief Return the Type ID.
  inline ID id() const { return id_; }
  /// @brief Return the Type ID as a human-readable string.
  std::string ToString() const;
  /// @brief Return possible type mappers.
  std::deque<std::shared_ptr<TypeMapper>> mappers() const;
  /// @brief Add a type mapper.
  void AddMapper(std::shared_ptr<TypeMapper> mapper);
  /// @brief Get a mapper to another type, if it exists.
  std::optional<std::shared_ptr<TypeMapper>> GetMapper(const Type *other) const;

 private:
  ID id_;
  std::deque<std::shared_ptr<TypeMapper>> mappers_;
};

/**
 * @brief A clock domain
 *
 * Placeholder for automatically generated clock domain crossing support
 */
struct ClockDomain : public Named {
  explicit ClockDomain(std::string name);
  static std::shared_ptr<ClockDomain> Make(std::string name) { return std::make_shared<ClockDomain>(name); }
};

// Primitive types:

// Synthesizable types:

/// @brief Clock type.
struct Clock : public Type {
  std::shared_ptr<ClockDomain> domain;
  Clock(std::string name, std::shared_ptr<ClockDomain> domain);
  static std::shared_ptr<Clock> Make(std::string name, std::shared_ptr<ClockDomain> domain);
  std::optional<std::shared_ptr<Node>> width() const override;
};

/// @brief Reset type.
struct Reset : public Type {
  std::shared_ptr<ClockDomain> domain;
  explicit Reset(std::string name, std::shared_ptr<ClockDomain> domain);
  static std::shared_ptr<Reset> Make(std::string name, std::shared_ptr<ClockDomain> domain);
  std::optional<std::shared_ptr<Node>> width() const override;
};

/// @brief A bit type.
struct Bit : public Type {
  explicit Bit(std::string name);
  static std::shared_ptr<Bit> Make(std::string name);
  std::optional<std::shared_ptr<Node>> width() const override;
};
/// @brief Generic static Bit type.
std::shared_ptr<Type> bit();

// Abstract primitive types:

/// @brief Integer type.
struct Integer : public Type {
  explicit Integer(std::string name) : Type(std::move(name), Type::INTEGER) {}
  static std::shared_ptr<Type> Make(std::string name);
};
/// @brief Generic static Integer type.
std::shared_ptr<Type> integer();

/// @brief Boolean type.
struct Boolean : public Type {
  explicit Boolean(std::string name);
  static std::shared_ptr<Type> Make(std::string name);
};
/// @brief Generic static Boolean type.
std::shared_ptr<Type> boolean();

/// @brief String type.
struct String : public Type {
  explicit String(std::string name);
  static std::shared_ptr<Type> Make(std::string name);
};
/// @brief Generic static String type.
std::shared_ptr<Type> string();


// Nested types:

/// @brief Vector type.
class Vector : public Type {
 public:
  Vector(std::string name, std::shared_ptr<Type> element_type, std::optional<std::shared_ptr<Node>> width);

  static std::shared_ptr<Type> Make(std::string name,
                                    std::shared_ptr<Type> element_type,
                                    std::optional<std::shared_ptr<Node>> width);

  static std::shared_ptr<Type> Make(std::string name, std::optional<std::shared_ptr<Node>> width);

  template<int W>
  static std::shared_ptr<Type> Make(std::string name) {
    return std::make_shared<Vector>(name, bit(), intl<W>());
  }

  template<int W>
  static std::shared_ptr<Type> Make() {
    static auto result = std::make_shared<Vector>("vec" + std::to_string(W), bit(), intl<W>());
    return result;
  }

  std::optional<std::shared_ptr<Node>> width() const override { return width_; }

 private:
  std::optional<std::shared_ptr<Node>> width_;
  std::shared_ptr<Type> element_type_;
};

/// @brief A Record field type.
class RecordField : public Named {
 public:
  RecordField(std::string name, std::shared_ptr<Type> type);
  static std::shared_ptr<RecordField> Make(std::string name, std::shared_ptr<Type> type);
  static std::shared_ptr<RecordField> Make(std::shared_ptr<Type> type);
  std::shared_ptr<Type> type() const { return type_; }
 private:
  std::shared_ptr<Type> type_;
};

/// @brief A Record type containing zero or more RecordFields.
class Record : public Type {
 public:
  explicit Record(const std::string &name, std::deque<std::shared_ptr<RecordField>> fields = {});
  static std::shared_ptr<Type> Make(const std::string &name, std::deque<std::shared_ptr<RecordField>> fields = {});
  Record &AddField(const std::shared_ptr<RecordField> &field);;
  std::shared_ptr<RecordField> field(size_t i) const { return fields_[i]; }
  std::deque<std::shared_ptr<RecordField>> fields() const { return fields_; }
 private:
  std::deque<std::shared_ptr<RecordField>> fields_;
};

/// @brief A Stream type.
class Stream : public Type {
 public:
  /**
   * @brief                 Construct a Stream type
   * @param type_name       The name of the Stream type.
   * @param element_type    The type of the elements transported by the stream
   * @param element_name    The name of the elements transported by the stream
   * @param epc             Maximum elements per cycle
   */
  Stream(const std::string &type_name, std::shared_ptr<Type> element_type, std::string element_name, int epc = 1);

  /// @brief Create a smart pointer to a new Stream type. Stream name will be stream:<type name>, the elements "data".
  static std::shared_ptr<Type> Make(std::shared_ptr<Type> element_type, int epc = 1);

  /// @brief Shorthand to create a smart pointer to a new Stream type. The elements are named "data".
  static std::shared_ptr<Type> Make(std::string name, std::shared_ptr<Type> element_type, int epc = 1);

  /// @brief Shorthand to create a smart pointer to a new Stream type.
  static std::shared_ptr<Type> Make(std::string name,
                                    std::shared_ptr<Type> element_type,
                                    std::string element_name,
                                    int epc = 1);

  std::shared_ptr<Type> element_type() const { return element_type_; }
  // TODO(johanpel): potentially remove element names
  std::string element_name() { return element_name_; }
  int epc() { return epc_; }

 private:
  std::shared_ptr<Type> element_type_;
  std::string element_name_;

  /// @brief Elements Per Cycle
  int epc_ = 1;
};

/// @brief Cast a pointer to a Type to a typically less abstract Type T. Returns no value if the cast was unsuccessful.
template<typename T>
std::optional<std::shared_ptr<T>> Cast(const std::shared_ptr<Type> &type) {
  auto result = std::dynamic_pointer_cast<T>(type);
  if (result == nullptr) {
    return {};
  }
  return result;
}

template<typename T>
std::optional<const T *> Cast(const Type *type) {
  auto result = dynamic_cast<const T *>(type);
  if (result == nullptr) {
    return {};
  }
  return result;
}

template<typename T>
std::optional<const T &> Cast(const Type &type) {
  auto result = dynamic_cast<T &>(type);
  if (&result == nullptr) {
    return {};
  }
  return result;
}

}  // namespace fletchgen
