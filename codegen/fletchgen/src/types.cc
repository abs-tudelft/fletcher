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

#include "./types.h"

#include <utility>
#include <string>
#include <iostream>
#include <sstream>
#include <iomanip>

#include "./nodes.h"

namespace fletchgen {

bool Type::Is(Type::ID type_id) const {
  return type_id == id_;
}

Type::Type(std::string name, Type::ID id)
    : Named(std::move(name)), id_(id) {}

bool Type::IsAbstract() const {
  return Is(STRING) || Is(BOOLEAN) || Is(RECORD) || Is(STREAM);
}

bool Type::IsSynthPrim() const {
  return Is(CLOCK) || Is(RESET) || Is(BIT) || Is(VECTOR);
}

bool Type::IsNested() {
  return (id_ == Type::STREAM) || (id_ == Type::RECORD);
}

std::string Type::ToString() {
  switch (id_) {
    case CLOCK  : return "Clock";
    case RESET  : return "Reset";
    case BIT    : return "Bit";
    case VECTOR : return "Vector";
    case INTEGER: return "Natural";
    case STRING : return "String";
    case BOOLEAN: return "Boolean";
    case RECORD : return "Record";
    case STREAM : return "Stream";
    default :throw std::runtime_error("Cannot return unknown Type ID as string.");
  }
}

Vector::Vector(std::string name, std::shared_ptr<Type> element_type, std::optional<std::shared_ptr<Node>> width)
    : Type(std::move(name), Type::VECTOR), element_type_(std::move(element_type)) {
  // Check if width is parameter or literal node
  if (width) {
    if (!((*width)->IsParameter() || (*width)->IsLiteral() || (*width)->IsExpression())) {
      throw std::runtime_error("Vector width can only be Parameter, Literal or Expression node.");
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

std::shared_ptr<Type> Stream::Make(std::string name, std::shared_ptr<Type> element_type, int epc) {
  return std::make_shared<Stream>(name, element_type, "data", epc);
}

std::shared_ptr<Type> Stream::Make(std::string name,
                                   std::shared_ptr<Type> element_type,
                                   std::string element_name,
                                   int epc) {
  return std::make_shared<Stream>(name, element_type, element_name, epc);
}

std::shared_ptr<Type> Stream::Make(std::shared_ptr<Type> element_type, int epc) {
  return std::make_shared<Stream>("stream-" + element_type->name(), element_type, "data", epc);
}

Stream::Stream(const std::string &type_name, std::shared_ptr<Type> element_type, std::string element_name, int epc)
    : Type(type_name, Type::STREAM),
      element_type_(std::move(element_type)),
      element_name_(std::move(element_name)),
      epc_(epc) {}

std::shared_ptr<Type> bit() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("bit");
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

std::shared_ptr<Type> boolean() {
  static std::shared_ptr<Type> result = std::make_shared<Boolean>("boolean");
  return result;
}

void FlattenRecord(std::deque<FlatType> *list,
                   const std::shared_ptr<Record> &record,
                   const std::optional<FlatType> &parent) {
  for (const auto &f : record->fields()) {
    Flatten(list, f->type(), parent, f->name());
  }
}

void FlattenStream(std::deque<FlatType> *list,
                   const std::shared_ptr<Stream> &stream,
                   const std::optional<FlatType> &parent) {
  Flatten(list, stream->element_type(), parent, "");
}

void Flatten(std::deque<FlatType> *list,
             const std::shared_ptr<Type> &type,
             const std::optional<FlatType> &parent,
             std::string name) {
  FlatType result;
  if (parent) {
    result.nesting_level = (*parent).nesting_level + 1;
    result.name_parts = (*parent).name_parts;
  }
  result.type = type;
  if (!name.empty()) {
    result.name_parts.push_back(name);
  }
  list->push_back(result);

  switch (type->id()) {
    case Type::STREAM:FlattenStream(list, *Cast<Stream>(type), result);
      break;
    case Type::RECORD:FlattenRecord(list, *Cast<Record>(type), result);
      break;
    default:break;
  }
}

std::deque<FlatType> Flatten(const std::shared_ptr<Type> &type) {
  std::deque<FlatType> result;
  Flatten(&result, type, {}, "");
  return result;
}

bool WeaklyEqual(const std::shared_ptr<Type> &a, const std::shared_ptr<Type> &b) {
  auto a_types = Flatten(a);
  auto b_types = Flatten(b);

  // Check if the lists have equal length.
  if (a_types.size() != b_types.size()) {
    return false;
  }

  // Check every type id to be the same.
  for (size_t i = 0; i < a_types.size(); i++) {
    if (a_types[i].type->id() != b_types[i].type->id()) {
      return false;
    }
    if (a_types[i].nesting_level != b_types[i].nesting_level) {
      return false;
    }
  }

  return true;
}

std::string ToString(std::deque<FlatType> flat_type_list) {
  std::stringstream ret;
  for (const auto &ft : flat_type_list) {
    ret << std::setw(32) << std::left
        << std::string(static_cast<unsigned long>(2 * ft.nesting_level), ' ') + ft.name(ft.nesting_level == 0 ? "(root)" : "") << " : "
        << std::setw(24) << std::left << ft.type->name() << " : "
        << std::setw(2) << std::left << ft.nesting_level << " : "
        << std::setw(8) << std::left << ft.type->ToString() << std::endl;
  }
  return ret.str();
}

void Sort(std::deque<FlatType> *list) {
  std::sort(list->begin(), list->end());
}

std::shared_ptr<Type> Integer::Make(std::string name) {
  return std::make_shared<Integer>(name);
}

Boolean::Boolean(std::string name) : Type(std::move(name), Type::BOOLEAN) {}

std::shared_ptr<Type> Boolean::Make(std::string name) {
  return std::make_shared<Boolean>(name);
}

String::String(std::string name) : Type(std::move(name), Type::STRING) {}

std::shared_ptr<Type> String::Make(std::string name) {
  return std::make_shared<String>(name);
}

Clock::Clock(std::string name, std::shared_ptr<ClockDomain> domain)
    : Type(std::move(name), Type::CLOCK), domain(std::move(domain)) {}

std::shared_ptr<Clock> Clock::Make(std::string name, std::shared_ptr<ClockDomain> domain) {
  return std::make_shared<Clock>(name, domain);
}

Reset::Reset(std::string name, std::shared_ptr<ClockDomain> domain)
    : Type(std::move(name), Type::RESET), domain(std::move(domain)) {}

std::shared_ptr<Reset> Reset::Make(std::string name, std::shared_ptr<ClockDomain> domain) {
  return std::make_shared<Reset>(name, domain);
}

Bit::Bit(std::string name) : Type(std::move(name), Type::BIT) {}

std::shared_ptr<Bit> Bit::Make(std::string name) {
  return std::make_shared<Bit>(name);
}

RecordField::RecordField(std::string name, std::shared_ptr<Type> type)
    : Named(std::move(name)), type_(std::move(type)) {}

std::shared_ptr<RecordField> RecordField::Make(std::string name, std::shared_ptr<Type> type) {
  return std::make_shared<RecordField>(name, type);
}

std::shared_ptr<RecordField> RecordField::Make(std::shared_ptr<Type> type) {
  return std::make_shared<RecordField>(type->name(), type);
}

Record::Record(const std::string &name, std::deque<std::shared_ptr<RecordField>> fields)
    : Type(name, Type::RECORD), fields_(std::move(fields)) {}

std::shared_ptr<Type> Record::Make(const std::string &name, std::deque<std::shared_ptr<RecordField>> fields) {
  return std::make_shared<Record>(name, fields);
}

Record &Record::AddField(const std::shared_ptr<RecordField> &field) {
  fields_.push_back(field);
  return *this;
}

ClockDomain::ClockDomain(std::string name) : Named(std::move(name)) {}

std::string FlatType::name(std::string root, std::string sep) const {
  std::stringstream ret;
  ret << root;
  for (const auto &p : name_parts) {
    ret << "_" + p;
  }
  return ret.str();
}

FlatType::FlatType(std::shared_ptr<Type> t, std::deque<std::string> prefix, std::string name, int level) {
  name_parts = std::move(prefix);
  name_parts.push_back(name);
  type = std::move(t);
}

}  // namespace fletchgen
