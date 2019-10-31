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

#include <optional>
#include <utility>
#include <memory>
#include <vector>
#include <unordered_map>
#include <string>
#include <tuple>

#include "cerata/utils.h"
#include "cerata/flattype.h"
#include "cerata/domain.h"

namespace cerata {

// Forward decl.
class Object;
class Node;
class Literal;
class Graph;
std::shared_ptr<Literal> intl(int64_t);
typedef std::unordered_map<const Node *, Node *> NodeMap;

/**
 * @brief A Type
 *
 * Types can logically be classified as follows.
 *
 * Physical:
 * - Yes.
 *      They can be immediately represented as bits in hardware.
 * - No.
 *      They can not be represented as bits in hardware without a more elaborate definition.
 *
 * Generic:
 * - No.
 *      Not parametrized by some node.
 * - Yes.
 *      Parameterized by some node.
 *
 * Nested:
 * - No.
 *      These types contain no subtype.
 * - Yes.
 *      These types contain some subtype, and so other properties depend on the sub-types used.
 *
 */
class Type : public Named, public std::enable_shared_from_this<Type> {
 public:
  /// The Type ID. Used for convenient type checking.
  //
  //                Physical | Generic | Nested
  //                ---------|---------|-----------
  enum ID {
    BIT,      ///<  Yes      | No      | No
    VECTOR,   ///<  Yes      | Yes     | No

    INTEGER,  ///<  No       | No      | No
    STRING,   ///<  No       | No      | No
    BOOLEAN,  ///<  No       | No      | No

    RECORD    ///<  ?        | ?       | Yes
  };

  /**
   * @brief Type constructor.
   * @param name    The name of the Type.
   * @param id      The Type::ID.
   */
  explicit Type(std::string name, ID id);

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
  virtual bool IsPhysical() const = 0;
  /// @brief Return true if the Type is a nested, false otherwise.
  virtual bool IsNested() const = 0;
  /// @brief Return true if the Type is a generic type.
  virtual bool IsGeneric() const = 0;
  /// @brief Return the width of the type, if it is synthesizable.
  virtual std::optional<Node *> width() const { return std::nullopt; }
  /// @brief Return the Type ID as a human-readable string.
  std::string ToString(bool show_meta = false, bool show_mappers = false) const;

  /// @brief Return possible type mappers.
  std::vector<std::shared_ptr<TypeMapper>> mappers() const;
  /// @brief Add a type mapper.
  void AddMapper(const std::shared_ptr<TypeMapper> &mapper, bool remove_existing = true);
  /// @brief Get a mapper to another type, if it exists. Generates one, if possible, when generate_implicit = true.
  std::optional<std::shared_ptr<TypeMapper>> GetMapper(Type *other, bool generate_implicit = true);
  /// @brief Remove all mappers to a specific type
  int RemoveMappersTo(Type *other);
  /// @brief Get a mapper to another type, if it exists.
  std::optional<std::shared_ptr<TypeMapper>> GetMapper(const std::shared_ptr<Type> &other);
  /// @brief Check if a mapper can be generated to another specific type.
  virtual bool CanGenerateMapper(const Type &other) const { return false; }
  /// @brief Generate a new mapper to a specific other type. Should be checked with CanGenerateMapper first, or throws.
  virtual std::shared_ptr<TypeMapper> GenerateMapper(Type *other) { return nullptr; }

  /// @brief Obtain any nodes that this type uses as generics.
  virtual std::vector<Node *> GetGenerics() const { return {}; }
  /// @brief Obtain any nested types.
  virtual std::vector<Type *> GetNested() const { return {}; }

  /// @brief KV storage for metadata of tools or specific backend implementations
  std::unordered_map<std::string, std::string> meta;

  /**
  * @brief Make a copy of the type, and rebind any type generic nodes that are keys in the rebinding to their values.
  *
   * This is useful in case type generic nodes are on some instance graph and have to be copied over to a component
   * graph, or vice versa. In that case, the new graph has to copy over these nodes and rebind the type generic nodes.
  *
  * @return A copy of the type.
  */
  virtual std::shared_ptr<Type> Copy(const NodeMap &rebinding) const = 0;

  /**
   * @brief Make a copy of the type without rebinding.
   * @return A copy.
   */
  virtual std::shared_ptr<Type> Copy() const { return Copy({}); }

  /**
   * @brief Make a copy of the type, and rebind any type generic nodes in order of the GetGenerics call.
   * @param nodes The nodes to rebind the type to.
   * @return      The rebound type.
   */
  std::shared_ptr<Type> operator()(std::vector<Node *> nodes);

  /**
   * @brief Make a copy of the type, and rebind any type generic nodes in order of the GetGenerics call.
   * @param nodes The nodes to rebind the type to.
   * @return      The rebound type.
   */
  std::shared_ptr<Type> operator()(const std::vector<std::shared_ptr<Node>> &nodes);

 protected:
  /// Type ID
  ID id_;
  /// A list of mappers that can map this type to another type.
  std::vector<std::shared_ptr<TypeMapper>> mappers_;
};

/// @brief Return a static bit type.
std::shared_ptr<Type> bit(const std::string &name = "bit");
/// @brief A bit type.
struct Bit : public Type {
  bool IsPhysical() const override { return true; }
  bool IsGeneric() const override { return false; }
  bool IsNested() const override { return false; }
  /// @brief Bit type constructor.
  explicit Bit(std::string name) : Type(std::move(name), Type::BIT) {}
  /// @brief Bit width returns integer literal 1.
  std::optional<Node *> width() const override;

  std::shared_ptr<Type> Copy(const NodeMap &rebinding) const override;
};

/// @brief Return a static boolean type.
std::shared_ptr<Type> boolean();
/// Boolean type.
struct Boolean : public Type {
  /// @brief Boolean constructor.
  explicit Boolean(std::string name) : Type(std::move(name), Type::BOOLEAN) {}
  bool IsPhysical() const override { return false; }
  bool IsGeneric() const override { return false; }
  bool IsNested() const override { return false; }
  std::shared_ptr<Type> Copy(const NodeMap &rebinding) const override { return boolean(); }
};

/// @brief Return a static integer type.
std::shared_ptr<Type> integer();
/// Integer type.
struct Integer : public Type {
  /// @brief Integer constructor.
  explicit Integer(std::string name) : Type(std::move(name), Type::INTEGER) {}
  bool IsPhysical() const override { return false; }
  bool IsGeneric() const override { return false; }
  bool IsNested() const override { return false; }
  std::shared_ptr<Type> Copy(const NodeMap &rebinding) const override { return integer(); }
};

/// @brief Return a static string type.
std::shared_ptr<Type> string();
/// @brief String type.
struct String : public Type {
  /// @brief String constructor.
  explicit String(std::string name) : Type(std::move(name), Type::STRING) {}
  bool IsPhysical() const override { return false; }
  bool IsGeneric() const override { return false; }
  bool IsNested() const override { return false; }
  std::shared_ptr<Type> Copy(const NodeMap &rebinding) const override { return string(); }
};

/// @brief Vector type.
class Vector : public Type {
 public:
  bool IsPhysical() const override { return true; }
  bool IsGeneric() const override { return true; }
  bool IsNested() const override { return false; }

  /// @brief Vector constructor.
  Vector(std::string name, const std::shared_ptr<Node> &width);
  /// @brief Return a pointer to the node representing the width of this vector, if specified.
  std::optional<Node *> width() const override;
  /// @brief Set the width of this vector.
  Type &SetWidth(std::shared_ptr<Node> width);
  /// @brief Determine if this Type is exactly equal to an other Type.
  bool IsEqual(const Type &other) const override;
  /// @brief Returns the width parameter of this vector, if any. Otherwise an empty list;
  std::vector<Node *> GetGenerics() const override;

  std::shared_ptr<Type> Copy(const NodeMap &rebinding) const override;

 private:
  /// The vector width type generic.
  std::shared_ptr<Node> width_;
};

/// @brief Create a new vector type, and return a shared pointer to it.
std::shared_ptr<Type> vector(const std::string &name, const std::shared_ptr<Node> &width);
/// @brief Create a new vector type, and return a shared pointer to it.
std::shared_ptr<Type> vector(const std::shared_ptr<Node> &width);
/// @brief Create a new vector type with an integer literal as width.
std::shared_ptr<Type> vector(unsigned int width);
/// @brief Create a new vector type with an integer literal as width and a custom name.
std::shared_ptr<Type> vector(std::string name, unsigned int width);

/// @brief A Record field.
class Field : public Named, public std::enable_shared_from_this<Field> {
 public:
  /// @brief RecordField constructor.
  Field(std::string name, std::shared_ptr<Type> type, bool invert = false, bool sep = true);
  /// @brief Change the type of this field.
  Field &SetType(std::shared_ptr<Type> type);
  /// @brief Return the type of the RecordField.
  std::shared_ptr<Type> type() const { return type_; }
  /// @brief Return if this individual field should be reversed w.r.t. parent Record type itself on graph edges.
  bool reversed() const { return invert_; }
  /// @brief Reverse the direction of this field and return itself.
  std::shared_ptr<Field> Reverse();
  /// @brief Return true if in name generation of this field name for flattened types a separator should be placed.
  bool sep() const { return sep_; }
  /// @brief Disable the separator in name generation of this field.
  void NoSep() { sep_ = false; }
  /// @brief Enable the separator in name generation of this field.
  void UseSep() { sep_ = true; }
  /// @brief Metadata for back-end implementations
  std::unordered_map<std::string, std::string> meta;
  /// @brief Create a copy of the field.
  std::shared_ptr<Field> Copy(const NodeMap &rebinding) const;

 private:
  /// The type of the field.
  std::shared_ptr<Type> type_;
  /// Whether this field should be inverted in directed use of the parent type.
  bool invert_;
  /// Whether this field should generate a separator for name/identifier generation in downstream tools.
  bool sep_;
};

/// @brief Create a new RecordField, and return a shared pointer to it.
std::shared_ptr<Field> field(const std::string &name,
                             const std::shared_ptr<Type> &type,
                             bool invert = false,
                             bool sep = true);

/// @brief Create a new RecordField, and return a shared pointer to it. The name will be taken from the type.
std::shared_ptr<Field> field(const std::shared_ptr<Type> &type, bool invert = false, bool sep = true);

/// @brief Convenience function to disable the separator for a record field.
std::shared_ptr<Field> NoSep(std::shared_ptr<Field> field);

/// @brief A Record type containing zero or more fields.
class Record : public Type {
 public:
  bool IsPhysical() const override;
  bool IsGeneric() const override;
  bool IsNested() const override { return true; }

  /// @brief Record constructor.
  explicit Record(std::string name, std::vector<std::shared_ptr<Field>> fields = {});
  /// @brief Add a field to this Record.
  Record &AddField(const std::shared_ptr<Field> &field, std::optional<size_t> index = std::nullopt);
  /// @brief Return true if record has field with name name.
  bool Has(const std::string &name) const;
  /// @brief Return the field with a specific name.
  Field *at(const std::string &name) const;
  /// @brief Return the field at index i contained by this record.
  Field *at(size_t i) const;
  /// @brief Return the field at index i contained by this record.
  Field *operator[](size_t i) const;
  /// @brief Return the field with name name contained by this record.
  Field *operator[](const std::string& name) const;
  /// @brief Return all fields contained by this record.
  std::vector<std::shared_ptr<Field>> fields() const { return fields_; }
  /// @brief Return the number of fields in this record.
  inline size_t num_fields() const { return fields_.size(); }
  /// @brief Determine if this Type is exactly equal to an other Type.
  bool IsEqual(const Type &other) const override;
  /// @brief Return all nodes that potentially parametrize the fields of this record.
  std::vector<Node *> GetGenerics() const override;
  /// @brief Obtain any nested types.
  std::vector<Type *> GetNested() const override;

  std::shared_ptr<Type> Copy(const NodeMap &rebinding) const override;

  /// @brief Return the names of the fields as a comma separated string.
  std::string ToStringFieldNames() const;

 protected:
  /// The fields of this Record.
  std::vector<std::shared_ptr<Field>> fields_;
};

/**
 * @brief Create a new, empty Record type, and return a shared pointer to it.
 * @param name    The name of the new Record type.
 * @return        A shared pointer to the Record Type.
 */
std::shared_ptr<Record> record(const std::string &name);

/**
 * @brief Create a new Record type, and return a shared pointer to it.
 * @param name    The name of the new Record type.
 * @param fields  The fields of the record type.
 * @return        A shared pointer to the Record Type.
 */
std::shared_ptr<Record> record(const std::string &name,
                               const std::vector<std::shared_ptr<Field>> &fields);

/**
 * @brief Create a new, anonymous Record type, and return a shared pointer to it.
 * @param fields  The fields of the record type.
 * @return        A shared pointer to the Record Type.
 */
std::shared_ptr<Record> record(const std::vector<std::shared_ptr<Field>> &fields);


/**
 * @brief Create a new, anonymous Record type, and return a shared pointer to it.
 * @param fields  The fields of the record type.
 * @return        A shared pointer to the Record Type.
 */
std::shared_ptr<Record> record(const std::initializer_list<std::shared_ptr<Field>> &fields);

}  // namespace cerata
