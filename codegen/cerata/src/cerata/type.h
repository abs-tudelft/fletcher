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
#include <unordered_map>
#include <string>

#include "cerata/utils.h"
#include "cerata/flattype.h"

namespace cerata {

// Forward decl.
class Node;
class Literal;
Literal *rintl(int i);
std::shared_ptr<Literal> intl(int i);

/**
 * @brief A Type
 *
 * Types can logically be classified as follows.
 * - Physical.
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
class Type : public Named, public std::enable_shared_from_this<Type> {
  // TODO(johanpel): When this class is inherited by some custom type in front-end tools, there should be some way
  // to define how a back-end emits that custom type.
 public:
  /// @brief The Type ID. Used for convenient type checking.
  enum ID {
    CLOCK,    ///< Physical, primitive
    RESET,    ///< Physical, primitive
    BIT,      ///< Physical, primitive
    VECTOR,   ///< t.b.d.

    INTEGER,  ///< Abstract, primitive
    NATURAL,  ///< Abstract, primitive
    STRING,   ///< Abstract, primitive
    BOOLEAN,  ///< Abstract, primitive

    RECORD,   ///< Abstract, nested
    STREAM    ///< Abstract, nested
  };

  /**
   * @brief Type constructor.
   * @param name    The name of the Type.
   * @param id      The Type::ID.
   */
  explicit Type(std::string name, ID id);

  /// @brief Type virtual destructor.
  virtual ~Type() = default;

  /// @brief Return the Type ID.
  inline ID id() const { return id_; }

  /**
   * @brief Determine if this Type is exactly equal to an other Type.
   * @param other   The other type.
   * @return        True if exactly equal, false otherwise.
   */
  virtual bool IsEqual(const Type &other) const;

  /// @brief Return true if the Type ID is type_id, false otherwise.
  bool Is(ID type_id) const;
  /// @brief Return true if the Type has an immediate physical representation, false otherwise.
  bool IsPhysical() const;
  /// @brief Return true if the Type is an abstract type, false otherwise.
  bool IsAbstract() const;
  /// @brief Return the width of the type, if it is synthesizable.
  virtual std::optional<Node *> width() const { return {}; }
  /// @brief Return true if type is nested (e.g. Stream or Record), false otherwise.
  bool IsNested() const;
  /// @brief Return the Type ID as a human-readable string.
  std::string ToString(bool show_meta = false, bool show_mappers = false) const;

  /// @brief Return possible type mappers.
  std::deque<std::shared_ptr<TypeMapper>> mappers() const;
  /// @brief Add a type mapper.
  void AddMapper(const std::shared_ptr<TypeMapper> &mapper, bool remove_existing = true);
  /// @brief Get a mapper to another type, if it exists.
  std::optional<std::shared_ptr<TypeMapper>> GetMapper(Type *other);
  /// @brief Remove all mappers to a specific type
  int RemoveMappersTo(Type *other);
  /// @brief Get a mapper to another type, if it exists.
  std::optional<std::shared_ptr<TypeMapper>> GetMapper(const std::shared_ptr<Type> &other);

  /// @brief Obtain any Nodes that parametrize this type.
  virtual std::deque<Node *> GetParameters() const { return {}; }

  /// @brief KV storage for metadata of tools or specific backend implementations
  std::unordered_map<std::string, std::string> meta;

 protected:
  /// Type ID
  ID id_;
  /// A list of mappers that can map this type to another type.
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

// Physical Primitive types:

/// @brief Clock type.
struct Clock : public Type {
  /// @brief The clock domain of this clock.
  std::shared_ptr<ClockDomain> domain;
  /// @brief Clock constructor.
  Clock(std::string name, std::shared_ptr<ClockDomain> domain);
  /// @brief Create a new clock, and return a shared pointer to it.
  static std::shared_ptr<Clock> Make(std::string name, std::shared_ptr<ClockDomain> domain);
  /// @brief Clock width returns integer literal 1.
  std::optional<Node *> width() const override;
  /// @brief Determine if this Clock is exactly equal to an other Clock.
  bool IsEqual(const Type &other) const override;
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
  std::optional<Node *> width() const override;
  /// @brief Determine if this Reset is exactly equal to an other Reset.
  bool IsEqual(const Type &other) const override;
};

/// @brief A bit type.
struct Bit : public Type {
  /// @brief Bit type constructor.
  explicit Bit(std::string name);
  /// @brief Create a new Bit type, and return a shared pointer to it.
  static std::shared_ptr<Bit> Make(std::string name);
  /// @brief Bit width returns integer literal 1.
  std::optional<Node *> width() const override;
};
/// @brief Return a generic static Bit type.
std::shared_ptr<Type> bit();

// Abstract Primitive types:

/// @brief Integer type.
struct Integer : public Type {
  /// @brief Integer type constructor.
  explicit Integer(std::string name) : Type(std::move(name), Type::INTEGER) {}
  /// @brief Create a new Integer type, and return a shared pointer to it.
  static std::shared_ptr<Type> Make(std::string name);
};
/// @brief Return a generic static Integer type.
std::shared_ptr<Type> integer();

/// @brief Natural type.
struct Natural : public Type {
  /// @brief Integer type constructor.
  explicit Natural(std::string name) : Type(std::move(name), Type::NATURAL) {}
  /// @brief Create a new Integer type, and return a shared pointer to it.
  static std::shared_ptr<Type> Make(std::string name);
};
/// @brief Return a generic static Integer type.
std::shared_ptr<Type> natural();

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
 public:
  /// @brief Vector constructor.
  Vector(std::string name, std::shared_ptr<Type> element_type, const std::optional<std::shared_ptr<Node>> &width);

  /// @brief Create a new Vector Type, and return a shared pointer to it.
  static std::shared_ptr<Type> Make(std::string name,
                                    std::shared_ptr<Type> element_type,
                                    std::optional<std::shared_ptr<Node>> width);

  /// @brief Create a new Vector Type, and return a shared pointer to it. The element type is the generic Bit type.
  static std::shared_ptr<Type> Make(std::string name, std::optional<std::shared_ptr<Node>> width);

  /// @brief Create a new Vector Type of width W and element type bit. Returns a shared pointer to it.
  template<int W>
  static std::shared_ptr<Type> Make(std::string name) {
    return std::make_shared<Vector>(name, bit(), intl(W));
  }

  /// @brief Create a new Vector Type of width W and element type bit and name "vec<W>". Returns a shared pointer to it.
  template<int W>
  static std::shared_ptr<Type> Make() {
    auto result = std::make_shared<Vector>("vec" + std::to_string(W), bit(), intl(W));
    return result;
  }

  /// @brief Create a new Vector Type of some width.
  static std::shared_ptr<Type> Make(unsigned int width);

  /// @brief Create a new Vector Type of some width.
  static std::shared_ptr<Type> Make(std::string name, unsigned int width);

  /// @brief Return a pointer to the node representing the width of this vector, if specified.
  std::optional<Node *> width() const override;

  /// @brief Set the width of this vector.
  Type &SetWidth(std::shared_ptr<Node> width);

  /// @brief Determine if this Type is exactly equal to an other Type.
  bool IsEqual(const Type &other) const override;

  /// @brief Returns the width parameter of this vector, if any. Otherwise an empty list;
  std::deque<Node *> GetParameters() const override;

 private:
  /// The optional vector width.
  std::optional<std::shared_ptr<Node>> width_;
  /// The type of elements in this vector.
  std::shared_ptr<Type> element_type_;
};

/// @brief A Record field.
class RecField : public Named {
 public:
  /// @brief RecordField constructor.
  RecField(std::string name, std::shared_ptr<Type> type, bool invert = false);
  /// @brief Create a new RecordField, and return a shared pointer to it.
  static std::shared_ptr<RecField> Make(std::string name, std::shared_ptr<Type> type, bool invert = false);
  /// @brief Create a new RecordField, and return a shared pointer to it. The name will be taken from the type.
  static std::shared_ptr<RecField> Make(std::shared_ptr<Type> type, bool invert = false);
  /// @brief Return the type of the RecordField.
  std::shared_ptr<Type> type() const { return type_; }
  /// @brief Return if this individual field should be inverted w.r.t. parent Record type itself on graph edges.
  bool invert() const { return invert_; }
  /// @brief Return true if in name generation of this field name for flattened types a separator should be placed.
  bool sep() const { return sep_; }
  /// @brief Disable the seperator in name generation of this field.
  void NoSep() { sep_ = false; }
  /// @brief Enable the seperator in name generation of this field.
  void UseSep() { sep_ = true; }
  /// @brief Metadata for back-end implementations
  std::unordered_map<std::string, std::string> meta;

 private:
  /// The type of the field.
  std::shared_ptr<Type> type_;
  /// Whether this field should be inverted in directed use of the parent type.
  bool invert_;
  /// Whether this field should generate a seperator for name/identifier generation in downstream tools.
  bool sep_;
};

/// @brief Convenience function to disable the seperator for a record field.
std::shared_ptr<RecField> NoSep(std::shared_ptr<RecField> field);

/// @brief A Record type containing zero or more RecordFields.
class Record : public Type {
 public:
  /// @brief Record constructor.
  explicit Record(std::string name, std::deque<std::shared_ptr<RecField>> fields = {});
  /// @brief Create a new Record Type, and return a shared pointer to it.
  static std::shared_ptr<Record> Make(const std::string &name, std::deque<std::shared_ptr<RecField>> fields = {});
  /// @brief Add a RecordField to this Record.
  Record &AddField(const std::shared_ptr<RecField> &field);;
  /// @brief Return the RecordField at index i contained by this record.
  std::shared_ptr<RecField> field(size_t i) const { return fields_[i]; }
  /// @brief Return all fields contained by this record.
  std::deque<std::shared_ptr<RecField>> fields() const { return fields_; }
  /// @brief Return the number of fields in this record.
  inline size_t num_fields() const { return fields_.size(); }
  /// @brief Determine if this Type is exactly equal to an other Type.
  bool IsEqual(const Type &other) const override;
  /// @brief Return all nodes that potentially parametrize the fields of this record.
  std::deque<Node *> GetParameters() const override;
 private:
  std::deque<std::shared_ptr<RecField>> fields_;
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
  static std::shared_ptr<Stream> Make(std::shared_ptr<Type> element_type, int epc = 1);
  /// @brief Shorthand to create a smart pointer to a new Stream type. The elements are named "data".
  static std::shared_ptr<Stream> Make(std::string name, std::shared_ptr<Type> element_type, int epc = 1);
  /// @brief Shorthand to create a smart pointer to a new Stream type.
  static std::shared_ptr<Stream> Make(std::string name,
                                      std::shared_ptr<Type> element_type,
                                      std::string element_name,
                                      int epc = 1);

  /// @brief Set the type of the elements of this stream. Forgets any existing mappers.
  void SetElementType(std::shared_ptr<Type> type);
  /// @brief Return the type of the elements of this stream.
  std::shared_ptr<Type> element_type() const { return element_type_; }
  /// @brief Set the name of the elements of this stream.
  void SetElementName(std::string name) { element_name_ = std::move(name); }
  /// @brief Return the name of the elements of this stream.
  std::string element_name() { return element_name_; }

  /// @brief Return the maximum number of elements per cycle this stream can deliver.
  // TODO(johanpel): turn EPC into a parameter or literal node
  int epc() { return epc_; }

  /// @brief Determine if this Stream is exactly equal to another Stream.
  bool IsEqual(const Type &other) const override;

 private:
  /// @brief The type of the elements traveling over this stream.
  std::shared_ptr<Type> element_type_;
  /// @brief The name of the elements traveling over this stream.
  std::string element_name_;

  /// @brief Elements Per Cycle
  int epc_ = 1;
};

}  // namespace cerata
