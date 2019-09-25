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

Type::Type(std::string name, Type::ID id)
    : Named(std::move(name)), id_(id) {}

bool Type::IsAbstract() const {
  return Is(STRING) || Is(BOOLEAN) || Is(RECORD) || Is(STREAM) || Is(NUL);
}

bool Type::IsPhysical() const {
  return Is(CLOCK) || Is(RESET) || Is(BIT) || Is(VECTOR);
}

bool Type::IsNested() const {
  return (id_ == Type::STREAM) || (id_ == Type::RECORD);
}

std::string Type::ToString(bool show_meta, bool show_mappers) const {
  std::string ret;
  switch (id_) {
    case CLOCK  : ret = name() + ":Clk";
      break;
    case RESET  : ret = name() + ":Rec";
      break;
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
    case STREAM : ret = name() + ":Stm";
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

std::deque<std::shared_ptr<TypeMapper>> Type::mappers() const {
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
    if (IsEqual(*other)) {
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

Vector::Vector(std::string name, std::shared_ptr<Type> element_type, const std::optional<std::shared_ptr<Node>> &width)
    : Type(std::move(name), Type::VECTOR), element_type_(std::move(element_type)) {
  // Check if width is parameter or literal node
  if (width) {
    if (!(width.value()->IsParameter() || width.value()->IsLiteral() || width.value()->IsExpression())) {
      CERATA_LOG(FATAL, "Vector width can only be Parameter, Literal or Expression node.");
    }
  }
  width_ = width;
}

std::shared_ptr<Type> Vector::Make(std::string name,
                                   std::shared_ptr<Type> element_type,
                                   std::optional<std::shared_ptr<Node>> width) {
  return std::make_shared<Vector>(name, element_type, width);
}

std::shared_ptr<Type> Vector::Make(std::string name, std::optional<std::shared_ptr<Node>> width) {
  return std::make_shared<Vector>(name, bit(), width);
}

std::shared_ptr<Type> Vector::Make(unsigned int width) {
  return Make("vec_" + std::to_string(width), intl(width));
}

std::shared_ptr<Type> Vector::Make(std::string name, unsigned int width) {
  auto ret = Make(width);
  ret->SetName(std::move(name));
  return ret;
}

std::optional<Node *> Vector::width() const {
  if (width_) {
    return width_->get();
  } else {
    return std::nullopt;
  }
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

std::deque<Node *> Vector::GetParameters() const {
  if (width_) {
    return std::deque({width_.value().get()});
  } else {
    return {};
  }
}

Type &Vector::SetWidth(std::shared_ptr<Node> width) {
  width_ = width;
  return *this;
}

std::shared_ptr<Stream> Stream::Make(std::string name, std::shared_ptr<Type> element_type, int epc) {
  return std::make_shared<Stream>(name, element_type, "", epc);
}

std::shared_ptr<Stream> Stream::Make(std::string name,
                                     std::shared_ptr<Type> element_type,
                                     std::string element_name,
                                     int epc) {
  return std::make_shared<Stream>(name, element_type, element_name, epc);
}

std::shared_ptr<Stream> Stream::Make(std::shared_ptr<Type> element_type, int epc) {
  return std::make_shared<Stream>("stream-" + element_type->name(), element_type, "", epc);
}

Stream::Stream(const std::string &type_name, std::shared_ptr<Type> element_type, std::string element_name, int epc)
    : Type(type_name, Type::STREAM),
      element_type_(std::move(element_type)),
      element_name_(std::move(element_name)),
      epc_(epc) {
  if (element_type_ == nullptr) {
    throw std::runtime_error("Stream element type cannot be nullptr.");
  }
}

std::shared_ptr<Type> bit() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("bit");
  return result;
}

std::shared_ptr<Type> nul() {
  static std::shared_ptr<Type> result = std::make_shared<Nul>("nul");
  return result;
}

std::shared_ptr<Type> string() {
  static std::shared_ptr<Type> result = std::make_shared<String>("string");
  return result;
}

std::shared_ptr<Type> integer() {
  static std::shared_ptr<Type> result = std::make_shared<Integer>("integer");
  return result;
}

std::shared_ptr<Type> natural() {
  static std::shared_ptr<Type> result = std::make_shared<Natural>("natural");
  return result;
}

std::shared_ptr<Type> boolean() {
  static std::shared_ptr<Type> result = std::make_shared<Boolean>("boolean");
  return result;
}

std::shared_ptr<Type> Integer::Make(std::string name) {
  return std::make_shared<Integer>(name);
}

std::shared_ptr<Type> Natural::Make(std::string name) {
  return std::make_shared<Natural>(name);
}

Boolean::Boolean(std::string name) : Type(std::move(name), Type::BOOLEAN) {}

std::shared_ptr<Type> Boolean::Make(std::string name) {
  return std::make_shared<Boolean>(name);
}

String::String(std::string name) : Type(std::move(name), Type::STRING) {}

std::shared_ptr<Type> String::Make(std::string name) {
  return std::make_shared<String>(name);
}

Bit::Bit(std::string name) : Type(std::move(name), Type::BIT) {}

std::shared_ptr<Bit> Bit::Make(std::string name) {
  return std::make_shared<Bit>(name);
}

std::optional<Node *> Bit::width() const {
  return rintl(1);
}

RecField::RecField(std::string name, std::shared_ptr<Type> type, bool invert)
    : Named(std::move(name)), type_(std::move(type)), invert_(invert), sep_(true) {}

std::shared_ptr<RecField> RecField::Make(std::string name, std::shared_ptr<Type> type, bool invert) {
  return std::make_shared<RecField>(name, type, invert);
}

std::shared_ptr<RecField> RecField::Make(std::shared_ptr<Type> type, bool invert) {
  return std::make_shared<RecField>(type->name(), type, invert);
}

std::shared_ptr<RecField> NoSep(std::shared_ptr<RecField> field) {
  field->NoSep();
  return field;
}

std::shared_ptr<Record> Record::Make(const std::string &name, const std::deque<std::shared_ptr<RecField>> &fields) {
  return std::make_shared<Record>(name, fields);
}

Record &Record::AddField(const std::shared_ptr<RecField> &field, std::optional<size_t> index) {
  if (index) {
    auto it = fields_.begin() + *index;
    fields_.insert(it, field);
  } else {
    fields_.push_back(field);
  }
  return *this;
}

Record::Record(std::string name, std::deque<std::shared_ptr<RecField>> fields)
    : Type(std::move(name), Type::RECORD), fields_(std::move(fields)) {}

bool Stream::IsEqual(const Type &other) const {
  if (other.Is(Type::STREAM)) {
    auto &other_stream = dynamic_cast<const Stream &>(other);
    bool eq = element_type()->IsEqual(*other_stream.element_type());
    return eq;
  }
  return false;
}

void Stream::SetElementType(std::shared_ptr<Type> type) {
  // Invalidate mappers that point to this type from the other side
  for (auto &mapper : mappers_) {
    mapper->b()->RemoveMappersTo(this);
  }
  // Invalidate all mappers from this type
  mappers_ = {};
  // Set the new element type
  element_type_ = std::move(type);
}

bool Stream::CanGenerateMapper(const Type &other) const {
  switch (other.id()) {
    case Type::STREAM:
      // If this and the other streams are "equal", a mapper can be generated
      if (IsEqual(other)) {
        return true;
      } else {
        // We can also map an empty stream, without mapping the elements. In practise, a back-end might emit e.g.
        // additional ready/valid/count wires, connect those, but not any data elements.
        if ((this->element_type() == nul()) || (dynamic_cast<const Stream &>(other).element_type() == nul())) {
          return true;
        }
      }
    default:return false;
  }
}

std::shared_ptr<TypeMapper> Stream::GenerateMapper(Type *other) {
  // Check if we can even do this:
  if (!CanGenerateMapper(*other)) {
    CERATA_LOG(FATAL, "No mapper generator known from Stream to " + other->name() + ToString(other->id()));
  }
  if (IsEqual(*other)) {
    return TypeMapper::MakeImplicit(this, other);
  } else {
    // If this or the other stream has a no element type:
    if ((this->element_type() == nul()) || (dynamic_cast<Stream *>(other)->element_type() == nul())) {
      auto mapper = TypeMapper::Make(this, other);
      // Only connect the two stream flat types.
      auto matrix = mapper->map_matrix();
      matrix(0, 0) = 1;
      mapper->SetMappingMatrix(matrix);
      return mapper;
    }
  }
  return nullptr;
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
    auto a = this->field(i)->type();
    auto b = other_record.field(i)->type();
    if (!a->IsEqual(*b)) {
      return false;
    }
  }
  // If we didn't return already, the Record Types are the same
  return true;
}

std::deque<Node *> Record::GetParameters() const {
  std::deque<Node *> result;
  for (const auto &field : fields_) {
    auto field_params = field->type()->GetParameters();
    result.insert(result.end(), field_params.begin(), field_params.end());
  }
  return result;
}

}  // namespace cerata
