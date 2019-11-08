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

#include <string>
#include <functional>
#include <utility>
#include <variant>
#include <memory>
#include <vector>

#pragma once

namespace dag {

enum class TypeID {
  PRIM,
  LIST,
  STRUCT
};

struct Prim;
struct List;
struct Struct;

struct Type : public std::enable_shared_from_this<Type> {
  explicit Type(TypeID id, std::string name) : id(id), name_(std::move(name)) {}
  virtual ~Type() = default;
  TypeID id;
  std::string name_;
  bool IsPrim() const { return id == TypeID::PRIM; }
  bool IsList() const { return id == TypeID::LIST; }
  bool IsStruct() const { return id == TypeID::STRUCT; }

  template<typename T>
  T &As() {
    return static_cast<T>(*this);
  }

  template<typename T>
  const T &As() const {
    return static_cast<const T &>(*this);
  }

  template<typename T>
  std::shared_ptr<T> AsRef() {
    return std::static_pointer_cast<T>(shared_from_this());
  }

  template<typename T>
  std::shared_ptr<const T> AsRef() const {
    return std::static_pointer_cast<const T>(shared_from_this());
  }
  std::string name() const;
  virtual std::string canonical_name() const = 0;

  virtual bool Equals(const Type &other) const = 0;
  virtual bool NestedEquals(const Prim &other) const = 0;
};

typedef std::shared_ptr<Type> TypeRef;

struct Prim : Type {
  Prim(std::string name, uint32_t width) : Type(TypeID::PRIM, std::move(name)), width(width) {}
  uint32_t width;
  bool Equals(const Type &other) const override;
  bool NestedEquals(const Prim &other) const override;
  std::string canonical_name() const override;
};
typedef std::shared_ptr<Prim> PrimRef;
PrimRef prim(const std::string &name, uint32_t width);
PrimRef prim(uint32_t width);

struct Field {
  Field(std::string name, TypeRef type) : name(std::move(name)), type(std::move(type)) {}
  std::string name;
  TypeRef type;
};
typedef std::shared_ptr<Field> FieldRef;
FieldRef field(const std::string &name, const TypeRef &type);

struct List : Type {
  List(std::string name, FieldRef item) : Type(TypeID::LIST, std::move(name)), item(std::move(item)) {}
  FieldRef item;
  bool Equals(const Type &other) const override;
  bool NestedEquals(const Prim &other) const override;
  std::string canonical_name() const override;
};
typedef std::shared_ptr<List> ListRef;
ListRef list(const std::string &name, const FieldRef &item);
ListRef list(const std::string &name, const TypeRef &item_type);
ListRef list(const TypeRef &item_type);

struct Struct : Type {
  Struct(std::string name, std::vector<FieldRef> fields)
      : Type(TypeID::STRUCT, std::move(name)), fields(std::move(fields)) {}
  std::vector<FieldRef> fields;
  bool Equals(const Type &other) const override;
  bool NestedEquals(const Prim &other) const override;
  std::string canonical_name() const override;
};
typedef std::shared_ptr<Struct> StructRef;
StructRef struct_(const std::string &name, const std::vector<FieldRef> &fields);
StructRef struct_(const std::vector<FieldRef> &fields);

#define PRIM_DECL_FACTORY(NAME) PrimRef NAME();

PRIM_DECL_FACTORY(bit)
PRIM_DECL_FACTORY(byte)
PRIM_DECL_FACTORY(i8)
PRIM_DECL_FACTORY(i16)
PRIM_DECL_FACTORY(i32)
PRIM_DECL_FACTORY(i64)
PRIM_DECL_FACTORY(u8)
PRIM_DECL_FACTORY(u16)
PRIM_DECL_FACTORY(u32)
PRIM_DECL_FACTORY(u64)
PRIM_DECL_FACTORY(f16)
PRIM_DECL_FACTORY(f32)
PRIM_DECL_FACTORY(f64)
PRIM_DECL_FACTORY(idx32)
PRIM_DECL_FACTORY(idx64)

PrimRef bool_();
ListRef utf8();
ListRef binary();

}  // namespace dag
