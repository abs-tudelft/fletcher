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

#include "cerata/type.h"

#include <utility>
#include <string>
#include <iostream>

#include "cerata/utils.h"
#include "cerata/node.h"
#include "cerata/flattype.h"
#include "cerata/pool.h"

namespace cerata {

bool Type::Is(Type::ID type_id) const {
  return type_id == id_;
}

Type::Type(std::string name, Type::ID id) : Named(std::move(name)), id_(id) {}

std::string Type::ToString(bool show_meta, bool show_mappers) const {
  std::string ret;
  switch (id_) {
    case BIT    : ret = name() + ":Bit";
      break;
    case VECTOR : ret = name() + ":Vec";
      break;
    case INTEGER: ret = name() + ":Int";
      break;
    case STRING : ret = name() + ":Str";
      break;
    case BOOLEAN: ret = name() + ":Bo";
      break;
    case RECORD : ret = name() + ":Rec";
      break;
    default :throw std::runtime_error("Corrupted Type ID.");
  }

  if (show_meta || show_mappers) {
    ret += "[";
    // Append metadata
    ret += ::cerata::ToString(meta);
    if (show_mappers && !mappers_.empty()) {
      ret += " ";
    }

    // Append mappers
    if (show_mappers && !mappers_.empty()) {
      ret += "mappers={";
      size_t i = 0;
      for (const auto &m : mappers_) {
        ret += m->b()->ToString();
        if (i != mappers_.size() - 1) {
          ret += ", ";
        }
        i++;
      }
      ret += "}";
    }
    ret += "]";
  }
  return ret;
}

std::vector<std::shared_ptr<TypeMapper>> Type::mappers() const {
  return mappers_;
}

void Type::AddMapper(const std::shared_ptr<TypeMapper> &mapper, bool remove_existing) {
  Type *other = mapper->b();
  // Check if a mapper doesn't already exists
  if (GetMapper(other, false)) {
    if (!remove_existing) {
      CERATA_LOG(FATAL, "Mapper already exists to convert "
                        "from " + this->ToString(true, true) + " to " + other->ToString(true, true));
    } else {
      RemoveMappersTo(other);
    }
  }

  // Check if the supplied mapper does not convert from this type.
  if (mapper->a() != this) {
    CERATA_LOG(FATAL, "Type converter does not convert from " + name());
  }

  // Add the converter to this Type
  mappers_.push_back(mapper);

  // If the other type doesnt already have it, add the inverse map there as well.
  if (!other->GetMapper(this)) {
    other->AddMapper(mapper->Inverse());
  }
}

std::optional<std::shared_ptr<TypeMapper>> Type::GetMapper(const std::shared_ptr<Type> &other) {
  return GetMapper(other.get());
}

std::optional<std::shared_ptr<TypeMapper>> Type::GetMapper(Type *other, bool generate_implicit) {
  // Search for an existing type mapper.
  for (const auto &m : mappers_) {
    if (m->CanConvert(this, other)) {
      return m;
    }
  }

  if (generate_implicit) {
    // Implicit type mappers maybe be generated in three cases:

    // If it's exactly the same type object,
    if (other == this) {
      // Generate a type mapper to itself using the TypeMapper constructor.
      return TypeMapper::Make(this);
    }

    // If there is an explicit function in this Type to generate a mapper:
    if (CanGenerateMapper(*other)) {
      // Generate, add and return the new mapper.
      auto new_mapper = GenerateMapper(other);
      this->AddMapper(new_mapper);
      return new_mapper;
    }

    // Or if its an "equal" type, where each flattened type is equal.
    if (this->IsEqual(*other)) {
      // Generate an implicit type mapping.
      return TypeMapper::MakeImplicit(this, other);
    }
  }

  // There is no mapper
  return {};
}

int Type::RemoveMappersTo(Type *other) {
  int removed = 0;
  for (auto m = mappers_.begin(); m < mappers_.end(); m++) {
    if ((*m)->CanConvert(this, other)) {
      mappers_.erase(m);
      removed++;
    }
  }
  return removed;
}

bool Type::IsEqual(const Type &other) const {
  return other.id() == id_;
}

std::shared_ptr<Type> Type::operator()(std::vector<Node *> nodes) {
  auto generics = GetGenerics();

  if (nodes.size() != generics.size()) {
    CERATA_LOG(ERROR, "Type contains " + std::to_string(generics.size())
        + " generics, but only " + std::to_string(nodes.size())
        + " arguments were supplied.");
  }

  NodeMap map;
  for (size_t i = 0; i < generics.size(); i++) {
    map[generics[i]] = nodes[i];
  }

  return Copy(map);
}

std::shared_ptr<Type> Type::operator()(const std::vector<std::shared_ptr<Node>> &nodes) {
  return this->operator()(ToRawPointers(nodes));
}

Vector::Vector(std::string name, const std::shared_ptr<Node> &width)
    : Type(std::move(name), Type::VECTOR) {
  // Sanity check the width generic node.
  if (!(width->IsParameter() || width->IsLiteral() || width->IsExpression())) {
    CERATA_LOG(FATAL, "Vector width can only be Parameter, Literal or Expression node.");
  }
  width_ = width;
}

std::shared_ptr<Type> vector(const std::string &name, const std::shared_ptr<Node> &width) {
  return std::make_shared<Vector>(name, width);
}

std::shared_ptr<Type> vector(const std::shared_ptr<Node> &width) {
  return std::make_shared<Vector>("Vec_" + width->ToString(), width);
}

std::shared_ptr<Type> vector(unsigned int width) {
  return vector("vec_" + std::to_string(width), intl(static_cast<int>(width)));
}

std::shared_ptr<Type> vector(std::string name, unsigned int width) {
  auto ret = vector(width);
  ret->SetName(std::move(name));
  return ret;
}

std::optional<Node *> Vector::width() const {
  return width_.get();
}

bool Vector::IsEqual(const Type &other) const {
  // Must also be a vector
  if (other.Is(Type::VECTOR)) {
    // Must both have a width
    if (width_ && other.width()) {
      // TODO(johanpel): implement proper width checking..
      return true;
    }
  }
  return false;
}

std::vector<Node *> Vector::GetGenerics() const {
  if (!width_->IsLiteral()) {
    return {width_.get()};
  } else {
    return {};
  }
}

Type &Vector::SetWidth(std::shared_ptr<Node> width) {
  width_ = std::move(width);
  return *this;
}

std::shared_ptr<Type> bit(const std::string &name) {
  if (name == "bit") {
    // Return a static bit for the default bit.
    static std::shared_ptr<Type> result = std::make_shared<Bit>(name);
    return result;
  } else {
    std::shared_ptr<Type> result = std::make_shared<Bit>(name);
    return result;
  }
}

std::shared_ptr<Type> boolean() {
  static std::shared_ptr<Type> result = std::make_shared<Boolean>("boolean");
  return result;
}

std::shared_ptr<Type> integer() {
  static std::shared_ptr<Type> result = std::make_shared<Integer>("integer");
  return result;
}

std::shared_ptr<Type> string() {
  static std::shared_ptr<Type> result = std::make_shared<String>("string");
  return result;
}

std::optional<Node *> Bit::width() const {
  return rintl(1);
}

Field::Field(std::string name, std::shared_ptr<Type> type, bool invert, bool sep)
    : Named(std::move(name)), type_(std::move(type)), invert_(invert), sep_(sep) {}

std::shared_ptr<Field> field(const std::string &name, const std::shared_ptr<Type> &type, bool invert, bool sep) {
  return std::make_shared<Field>(name, type, invert, sep);
}

std::shared_ptr<Field> field(const std::shared_ptr<Type> &type, bool invert, bool sep) {
  return std::make_shared<Field>(type->name(), type, invert, sep);
}

std::shared_ptr<Field> NoSep(std::shared_ptr<Field> field) {
  field->NoSep();
  return field;
}

Record &Record::AddField(const std::shared_ptr<Field> &field, std::optional<size_t> index) {
  if (index) {
    auto it = fields_.begin() + *index;
    fields_.insert(it, field);
  } else {
    fields_.push_back(field);
  }
  return *this;
}

Record::Record(std::string name, std::vector<std::shared_ptr<Field>> fields)
    : Type(std::move(name), Type::RECORD), fields_(std::move(fields)) {
  // Check for duplicate field names.
  std::vector<std::string> names;
  for (const auto &field : fields_) {
    names.push_back(field->name());
  }
  if (Unique(names).size() != fields_.size()) {
    CERATA_LOG(ERROR, "Record field names must be unique.");
  }
}

std::shared_ptr<Record> record(const std::string &name, const std::vector<std::shared_ptr<Field>> &fields) {
  return std::make_shared<Record>(name, fields);
}

std::shared_ptr<Record> record(const std::string &name) {
  return record(name, std::vector<std::shared_ptr<Field>>());
}

std::shared_ptr<Record> record(const std::vector<std::shared_ptr<Field>> &fields) {
  return record(std::string(""), fields);
}

std::shared_ptr<Record> record(const std::initializer_list<std::shared_ptr<Field>> &fields) {
  return record(std::string(""), std::vector<std::shared_ptr<Field>>(fields.begin(), fields.end()));
}

bool Record::IsEqual(const Type &other) const {
  if (&other == this) {
    return true;
  }
  // Must also be a record
  if (!other.Is(Type::RECORD)) {
    return false;
  }
  // Must have same number of fields
  auto &other_record = dynamic_cast<const Record &>(other);
  if (other_record.num_fields() != this->num_fields()) {
    return false;
  }
  // Each field must also be of equal type
  for (size_t i = 0; i < this->num_fields(); i++) {
    auto a = this->at(i)->type();
    auto b = other_record.at(i)->type();
    if (!a->IsEqual(*b)) {
      return false;
    }
  }
  // If we didn't return already, the Record Types are the same
  return true;
}

std::vector<Node *> Record::GetGenerics() const {
  std::vector<Node *> result;
  for (const auto &field : fields_) {
    auto field_params = field->type()->GetGenerics();
    result.insert(result.end(), field_params.begin(), field_params.end());
  }
  return result;
}

std::vector<Type *> Record::GetNested() const {
  std::vector<Type *> result;
  for (const auto &field : fields_) {
    // Push back the field type itself.
    result.push_back(field->type().get());
    // Push back any nested types.
    auto nested = field->type()->GetNested();
    result.insert(result.end(), nested.begin(), nested.end());
  }
  return result;
}

bool Record::IsPhysical() const {
  for (const auto &f : fields_) {
    if (!f->type()->IsPhysical()) {
      return false;
    }
  }
  return true;
}

bool Record::IsGeneric() const {
  for (const auto &f : fields_) {
    if (f->type()->IsGeneric()) {
      return true;
    }
  }
  return false;
}

std::shared_ptr<Type> Bit::Copy(const NodeMap &rebinding) const {
  std::shared_ptr<Type> result;
  result = bit(name());

  result->meta = meta;

  for (const auto &mapper : mappers_) {
    auto new_mapper = mapper->Make(result.get(), mapper->b());
    new_mapper->SetMappingMatrix(mapper->map_matrix());
    result->AddMapper(new_mapper);
  }

  return result;
}

std::shared_ptr<Type> Vector::Copy(const NodeMap &rebinding) const {
  std::shared_ptr<Type> result;
  std::optional<std::shared_ptr<Node>> new_width = width_;
  if (rebinding.count(width_.get()) > 0) {
    new_width = rebinding.at(width_.get())->shared_from_this();
  }
  result = vector(name(), *new_width);

  result->meta = meta;

  for (const auto &mapper : mappers_) {
    auto new_mapper = mapper->Make(result.get(), mapper->b());
    new_mapper->SetMappingMatrix(mapper->map_matrix());
    result->AddMapper(new_mapper);
  }

  return result;
}

std::shared_ptr<Field> Field::Copy(const NodeMap &rebinding) const {
  std::shared_ptr<Field> result;
  auto type = type_;
  if (type_->IsGeneric()) {
    type = type_->Copy(rebinding);
  }
  result = field(name(), type, invert_, sep_);
  result->meta = meta;
  return result;
}

Field &Field::SetType(std::shared_ptr<Type> type) {
  type_ = std::move(type);
  return *this;
}

std::shared_ptr<Field> Field::Reverse() {
  invert_ = true;
  return shared_from_this();
}

std::shared_ptr<Type> Record::Copy(const NodeMap &rebinding) const {
  std::shared_ptr<Type> result;
  std::vector<std::shared_ptr<Field>> fields;
  for (const auto &f : fields_) {
    fields.push_back(f->Copy(rebinding));
  }
  result = record(name(), fields);

  result->meta = meta;

  for (const auto &mapper : mappers_) {
    auto new_mapper = mapper->Make(result.get(), mapper->b());
    new_mapper->SetMappingMatrix(mapper->map_matrix());
    result->AddMapper(new_mapper);
  }

  return result;
}

Field *Record::at(size_t i) const {
  if (i > fields_.size()) {
    CERATA_LOG(FATAL, "Field index out of bounds.");
  }
  return fields_[i].get();
}

Field *Record::operator[](size_t i) const { return at(i); }

bool Record::Has(const std::string &name) const {
  for (const auto &field : fields_) {
    if (field->name() == name) {
      return true;
    }
  }
  return false;
}

Field *Record::at(const std::string &name) const {
  for (auto &f : fields_) {
    if (f->name() == name) {
      return f.get();
    }
  }
  CERATA_LOG(ERROR, "Field with name " + name + " does not exist on Record type " + this->name()
      + " Must one of: " + ToStringFieldNames());
}

Field *Record::operator[](const std::string &name) const { return at(name); }

std::string Record::ToStringFieldNames() const {
  std::stringstream ss;
  for (const auto &f : fields_) {
    ss << f->name();
    if (f != fields_.back()) {
      ss << ", ";
    }
  }
  return ss.str();
}

}  // namespace cerata
