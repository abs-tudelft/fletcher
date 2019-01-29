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

#include <string>

#include "nodes.h"

namespace fletchgen {

bool Type::Is(Type::ID type_id) {
  return type_id == id;
}

Type::Type(std::string name, Type::ID id)
    : Named(std::move(name)), id(id) {}

Vector::Vector(std::string name, std::shared_ptr<Node> width)
    : Type(std::move(name), Type::VECTOR) {
  // Check if width is parameter or literal node
  if (!(width->IsParameter() || width->IsLiteral())) {
    throw std::runtime_error("Vector width can only be parameter or literal node.");
  } else {
    width_ = std::move(width);
  }
}

std::shared_ptr<Type> Vector::Make(std::string name, std::shared_ptr<Node> width) {
  return std::make_shared<Vector>(name, width);
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

Stream::Stream(const std::string &type_name, std::shared_ptr<Type> element_type, std::string element_name, int epc)
    : Type(type_name, Type::STREAM),
      element_type_(std::move(element_type)),
      element_name_(std::move(element_name)),
      epc_(epc) {}

std::deque<std::shared_ptr<Type>> FlattenStreams(const std::shared_ptr<Type> &type) {
  std::deque<std::shared_ptr<Type>> ret;
  if (type->Is(Type::STREAM)) {
    ret.push_back(type);
    auto dt = Cast<Stream>(type)->element_type();
    auto children = FlattenStreams(dt);
    ret.insert(ret.end(), children.begin(), children.end());
  } else if (type->Is(Type::RECORD)) {
    auto rdt = Cast<Record>(type);
    for (const auto &rf : rdt->fields()) {
      auto children = FlattenStreams(rf->type());
      ret.insert(ret.end(), children.begin(), children.end());
    }
  }
  return ret;
}

bool IsNested(const std::shared_ptr<Type> &type) {
  return type->Is(Type::STREAM) || type->Is(Type::RECORD);
}

std::shared_ptr<Type> bit() {
  static std::shared_ptr<Type> result = std::make_shared<Bit>("bit");
  return result;
}

std::shared_ptr<Type> string() {
  static std::shared_ptr<Type> result = std::make_shared<String>("string");
  return result;
}

std::shared_ptr<Type> integer() {
  static std::shared_ptr<Type> result = std::make_shared<Natural>("integer");
  return result;
}

std::shared_ptr<Type> boolean() {
  static std::shared_ptr<Type> result = std::make_shared<Boolean>("boolean");
  return result;
}

#define TOSTRING_FACTORY(TYPE)     \
  template<>                       \
    std::string ToString<TYPE>() { \
    return #TYPE;                  \
  }

TOSTRING_FACTORY(Clock)
TOSTRING_FACTORY(Reset)
TOSTRING_FACTORY(Bit)
TOSTRING_FACTORY(Vector)
TOSTRING_FACTORY(Record)
TOSTRING_FACTORY(Stream)
TOSTRING_FACTORY(Natural)
TOSTRING_FACTORY(String)
TOSTRING_FACTORY(Boolean)

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
}  // namespace fletchgen
