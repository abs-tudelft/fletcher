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
  /// @brief Construct a new Type.
  explicit Type(std::string name, ID id);
  /// @brief Virtual destructor for Type.
  virtual ~Type() = default;

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
  /// @brief Clock domain constructor
  explicit ClockDomain(std::string name);
  /// @brief Create a new clock domain and return a shared pointer to it.
  static std::shared_ptr<ClockDomain> Make(std::string name) { return std::make_shared<ClockDomain>(name); }
};

// Primitive types:

// Synthesizable types:

/// @brief Clock type.
struct Clock : public Type {
  /// @brief The clock domain of this clock.
  std::shared_ptr<ClockDomain> domain;
  /// @brief Clock constructor.
  Clock(std::string name, std::shared_ptr<ClockDomain> domain);
  /// @brief Create a new clock, and return a shared pointer to it.
  static std::shared_ptr<Clock> Make(std::string name, std::shared_ptr<ClockDomain> domain);
  /// @brief Clock width returns integer literal 1.
  std::optional<std::shared_ptr<Node>> width() const override;
};

/// @brief Reset type.
struct Reset : public Type {
  /// @brief The clock domain of this reset.
  std::shared_ptr<ClockDomain> domain;
  /// @brief Reset constructor.
  explicit Reset(std::string name, std::shared_ptr<ClockDomain> domain);
  /// @brief Create a new Reset, and return a shared pointer to it.
  static std::shared_ptr<Reset> Make(std::string name, std::shared_ptr<ClockDomain> domain);
  /// @brief Reset width returns integer literal 1.
  std::optional<std::shared_ptr<Node>> width() const override;
};

/// @brief A bit type.
struct Bit : public Type {
  /// @brief Bit type constructor.
  explicit Bit(std::string name);
  /// @brief Create a new Bit type, and return a shared pointer to it.
  static std::shared_ptr<Bit> Make(std::string name);
  /// @brief Bit width returns integer literal 1.
  std::optional<std::shared_ptr<Node>> width() const override;
};
/// @brief Return a generic static Bit type.
std::shared_ptr<Type> bit();

// Abstract primitive types:

/// @brief Integer type.
struct Integer : public Type {
  /// @brief Integer type constructor.
  explicit Integer(std::string name) : Type(std::move(name), Type::INTEGER) {}
  /// @brief Create a new Integer type, and return a shared pointer to it.
  static std::shared_ptr<Type> Make(std::string name);
};
/// @brief Return a generic static Integer type.
std::shared_ptr<Type> integer();

/// @brief Boolean type.
struct Boolean : public Type {
  /// @brief Boolean type constructor.
  explicit Boolean(std::string name);
  /// @brief Create a new Boolean type, and return a shared pointer to it.
  static std::shared_ptr<Type> Make(std::string name);
};
/// @brief Generic static Boolean type.
std::shared_ptr<Type> boolean();

/// @brief String type.
struct String : public Type {
  /// @brief String type constructor.
  explicit String(std::string name);
  /// @brief Create a new String type, and return a shared pointer to it.
  static std::shared_ptr<Type> Make(std::string name);
};
/// @brief Generic static String type.
std::shared_ptr<Type> string();


// Nested types:

/// @brief Vector type.
class Vector : public Type {
 private:
  std::optional<std::shared_ptr<Node>> width_;
  std::shared_ptr<Type> element_type_;
 public:
  /// @brief Vector constructor.
  Vector(std::string name, std::shared_ptr<Type> element_type, std::optional<std::shared_ptr<Node>> width);

  /// @brief Create a new Vector Type, and return a shared pointer to it.
  static std::shared_ptr<Type> Make(std::string name,
                                    std::shared_ptr<Type> element_type,
                                    std::optional<std::shared_ptr<Node>> width);

  /// @brief Create a new Vector Type, and return a shared pointer to it. The element type is the generic Bit type.
  static std::shared_ptr<Type> Make(std::string name, std::optional<std::shared_ptr<Node>> width);

  /// @brief Create a new Vector Type of width W and element type bit. Returns a shared pointer to it.
  template<int W>
  static std::shared_ptr<Type> Make(std::string name) {
    return std::make_shared<Vector>(name, bit(), intl<W>());
  }

  /// @brief Create a new Vector Type of width W and element type bit and name "vec<W>". Returns a shared pointer to it.
  template<int W>
  static std::shared_ptr<Type> Make() {
    static auto result = std::make_shared<Vector>("vec" + std::to_string(W), bit(), intl<W>());
    return result;
  }

  /// @brief Return a pointer to the node representing the width of this vector, if specified.
  std::optional<std::shared_ptr<Node>> width() const override { return width_; }
};

/// @brief A Record field.
class RecordField : public Named {
 public:
  /// @brief RecordField constructor.
  RecordField(std::string name, std::shared_ptr<Type> type);
  /// @brief Create a new RecordField, and return a shared pointer to it.
  static std::shared_ptr<RecordField> Make(std::string name, std::shared_ptr<Type> type);
  /// @brief Create a new RecordField, and return a shared pointer to it. The name will be taken from the type.
  static std::shared_ptr<RecordField> Make(std::shared_ptr<Type> type);
  /// @brief Return the type of the RecordField.
  std::shared_ptr<Type> type() const { return type_; }
 private:
  std::shared_ptr<Type> type_;
};

/// @brief A Record type containing zero or more RecordFields.
class Record : public Type {
 public:
  /// @brief Record constructor.
  explicit Record(std::string name, std::deque<std::shared_ptr<RecordField>> fields = {});
  /// @brief Create a new Record Type, and return a shared pointer to it.
  static std::shared_ptr<Type> Make(const std::string &name, std::deque<std::shared_ptr<RecordField>> fields = {});
  /// @brief Add a RecordField to this Record.
  Record &AddField(const std::shared_ptr<RecordField> &field);;
  /// @brief Return the RecordField at index i contained by this record.
  std::shared_ptr<RecordField> field(size_t i) const { return fields_[i]; }
  /// @brief Return all fields contained by this record.
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

  /// @brief Create a smart pointer to a new Stream type. Stream name will be stream:\<type name\>, the elements "data".
  static std::shared_ptr<Type> Make(std::shared_ptr<Type> element_type, int epc = 1);

  /// @brief Shorthand to create a smart pointer to a new Stream type. The elements are named "data".
  static std::shared_ptr<Type> Make(std::string name, std::shared_ptr<Type> element_type, int epc = 1);

  /// @brief Shorthand to create a smart pointer to a new Stream type.
  static std::shared_ptr<Type> Make(std::string name,
                                    std::shared_ptr<Type> element_type,
                                    std::string element_name,
                                    int epc = 1);

  /// @brief Return the type of the elements of this stream.
  std::shared_ptr<Type> element_type() const { return element_type_; }

  /// @brief Return the name of the elements of this stream.
  std::string element_name() { return element_name_; }

  /// @brief Return the number of elements per cycle this stream should deliver.
  int epc() { return epc_; } // TODO(johanpel): this should probably become a node as well.

 private:
  /// @brief The type of the elements traveling over this stream.
  std::shared_ptr<Type> element_type_;
  /// @brief The name of the elements traveling over this stream.
  std::string element_name_;

  /// @brief Elements Per Cycle
  int epc_ = 1;
};

/// @brief Cast a pointer to a Type to a typically less abstract Type T.
template<typename T>
std::optional<std::shared_ptr<T>> Cast(const std::shared_ptr<Type> &type) {
  auto result = std::dynamic_pointer_cast<T>(type);
  if (result == nullptr) {
    return {};
  }
  return result;
}

/// @brief Cast a raw pointer to a Type to a typically less abstract Type T.
template<typename T>
std::optional<const T *> Cast(const Type *type) {
  auto result = dynamic_cast<const T *>(type);
  if (result == nullptr) {
    return {};
  }
  return result;
}

/// @brief Cast a raw reference to a Type to a typically less abstract Type T.
template<typename T>
std::optional<const T &> Cast(const Type &type) {
  auto result = dynamic_cast<T &>(type);
  if (&result == nullptr) {
    return {};
  }
  return result;
}

}  // namespace fletchgen
