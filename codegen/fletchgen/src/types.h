#include <utility>

#include <utility>

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

#include <memory>
#include <deque>

#include "./utils.h"

namespace fletchgen {

struct Node;
struct Literal;

template<int T> std::shared_ptr<Literal> lit();

struct Type : public Named {
  enum ID {
    CLOCK,
    RESET,
    BIT,
    VECTOR,
    RECORD,
    STREAM,
    NATURAL,
    STRING,
    BOOLEAN
  };

  ID id;

  explicit Type(std::string name, ID id)
      : Named(std::move(name)), id(id) {}
  bool Is(ID type_id);
  virtual ~Type() = default;
};

class Natural : public Type {
 public:
  explicit Natural(std::string name) : Type(std::move(name), Type::NATURAL) {}

  static std::shared_ptr<Type> Make(std::string name) {
    return std::make_shared<Natural>(name);
  }
};

class Boolean : public Type {
 public:
  explicit Boolean(std::string name) : Type(std::move(name), Type::BOOLEAN) {}

  static std::shared_ptr<Type> Make(std::string name) {
    return std::make_shared<Boolean>(name);
  }
};

class String : public Type {
 public:
  explicit String(std::string name) : Type(std::move(name), Type::STRING) {}

  static std::shared_ptr<Type> Make(std::string name) {
    return std::make_shared<String>(name);
  }
};

struct Clock : public Type {
  explicit Clock(std::string name, std::shared_ptr<ClockDomain> domain)
      : Type(std::move(name), Type::CLOCK), domain(std::move(domain)) {}
  static std::shared_ptr<Clock> Make(std::string name, std::shared_ptr<ClockDomain> domain) {
    return std::make_shared<Clock>(name, domain);
  }
  std::shared_ptr<ClockDomain> domain;
};

struct Reset : public Type {
  explicit Reset(std::string name, std::shared_ptr<ClockDomain> domain)
      : Type(std::move(name), Type::RESET), domain(std::move(domain)) {}
  static std::shared_ptr<Reset> Make(std::string name, std::shared_ptr<ClockDomain> domain) {
    return std::make_shared<Reset>(name, domain);
  }
  std::shared_ptr<ClockDomain> domain;
};

class Bit : public Type {
 public:
  explicit Bit(std::string name) : Type(std::move(name), Type::BIT) {}
  static std::shared_ptr<Bit> Make(std::string name) {
    return std::make_shared<Bit>(name);
  }
};

class Vector : public Type {
 public:
  Vector(std::string name, std::shared_ptr<Node> width);

  static std::shared_ptr<Type> Make(std::string name, std::shared_ptr<Node> width) {
    return std::make_shared<Vector>(name, width);
  }
  template<int T>
  static std::shared_ptr<Type> Make(std::string name) {
    return std::make_shared<Vector>(name, lit<T>());
  }

  static std::shared_ptr<Vector> Cast(const std::shared_ptr<Type> &data_type) {
    return std::dynamic_pointer_cast<Vector>(data_type);
  }

  std::shared_ptr<Node> width() const { return width_; }
 private:
  std::shared_ptr<Node> width_;
};

class RecordField : public Named {
 public:
  RecordField(std::string name, std::shared_ptr<Type> type)
      : Named(std::move(name)), type_(std::move(type)) {}

  static std::shared_ptr<RecordField> Make(std::string name, std::shared_ptr<Type> type) {
    return std::make_shared<RecordField>(name, type);
  }

  std::shared_ptr<Type> type() const { return type_; }
 private:
  std::shared_ptr<Type> type_;
};

class Record : public Type {
 public:
  explicit Record(const std::string &name, std::deque<std::shared_ptr<RecordField>> fields = {})
      : Type(name, Type::RECORD), fields_(std::move(fields)) {}

  static std::shared_ptr<Type> Make(const std::string &name, std::deque<std::shared_ptr<RecordField>> fields = {}) {
    return std::make_shared<Record>(name, fields);
  }

  static std::shared_ptr<Record> Cast(const std::shared_ptr<Type> &data_type) {
    return std::dynamic_pointer_cast<Record>(data_type);
  }

  Record &AddField(const std::shared_ptr<RecordField> &field) {
    fields_.push_back(field);
    return *this;
  };
  std::shared_ptr<RecordField> field(size_t i) const { return fields_[i]; }
  std::deque<std::shared_ptr<RecordField>> fields() { return fields_; }
 private:
  std::deque<std::shared_ptr<RecordField>> fields_;
};

class Stream : public Type {
 public:
  Stream(const std::string &name, std::shared_ptr<Type> child)
      : Type(name, Type::STREAM), child_(std::move(child)) {}

  static std::shared_ptr<Type> Make(std::shared_ptr<Type> child) {
    return std::make_shared<Stream>(child->name() + "_stream", child);
  }

  static std::shared_ptr<Type> Make(const std::string &name, std::shared_ptr<Type> child) {
    return std::make_shared<Stream>(name, child);
  }

  static std::shared_ptr<Stream> Cast(const std::shared_ptr<Type> &data_type) {
    return std::dynamic_pointer_cast<Stream>(data_type);
  }

  std::shared_ptr<Type> child() { return child_; }

 private:
  std::shared_ptr<Type> child_;
};

}  // namespace fletchgen
