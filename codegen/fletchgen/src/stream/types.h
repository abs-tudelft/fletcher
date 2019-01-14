#include <utility>

#include <utility>

#include <utility>

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

#include "utils.h"

namespace fletchgen {
namespace stream {

struct Type : public Named {
  enum ID {
    CLOCK,
    RESET,
    BIT,
    VECTOR,
    SIGNED,
    UNSIGNED,
    NATURAL,
    RECORD,
    STREAM
  };
  ID id;
  explicit Type(std::string name, ID id)
      : Named(std::move(name)), id(id) {}
  virtual ~Type() = default;
};

class Natural : public Type {
 public:
  explicit Natural(std::string name) : Type(std::move(name), Type::NATURAL) {}

  static std::shared_ptr<Type> Make(std::string name) {
    return std::make_shared<Natural>(name);
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
  Vector(std::string name, int64_t low, int64_t high)
      : Type(std::move(name), Type::VECTOR), low_(low), high_(high) {}

  static std::shared_ptr<Type> Make(std::string name, int64_t low, int64_t high) {
    return std::make_shared<Vector>(name, low, high);
  }

  int64_t low() const { return low_; }
  int64_t high() const { return high_; }
 private:
  int64_t low_;
  int64_t high_;
};

class Unsigned : public Type {
 public:
  Unsigned(std::string name, int64_t low, int64_t high)
      : Type(std::move(name), Type::UNSIGNED), low_(low), high_(high) {}

  static std::shared_ptr<Type> Make(std::string name, int64_t low, int64_t high) {
    return std::make_shared<Unsigned>(name, low, high);
  }

  int64_t low() const { return low_; }
  int64_t high() const { return high_; }
 private:
  int64_t low_;
  int64_t high_;
};

class Signed : public Type {
 public:
  Signed(std::string name, int64_t low, int64_t high)
      : Type(std::move(name), Type::SIGNED), low_(low), high_(high) {}

  static std::shared_ptr<Type> Make(std::string name, int64_t low, int64_t high) {
    return std::make_shared<Signed>(name, low, high);
  }

  int64_t low() const { return low_; }
  int64_t high() const { return high_; }
 private:
  int64_t low_;
  int64_t high_;
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

  Record &AddField(const std::shared_ptr<RecordField> &field) {
    fields_.push_back(field);
    return *this;
  };
  std::shared_ptr<RecordField> field(size_t i) const { return fields_[i]; }
 private:
  std::deque<std::shared_ptr<RecordField>> fields_;
};

class Stream : public Type {
 public:
  Stream(const std::string &name, std::shared_ptr<Type> child)
      : Type(name, Type::STREAM), child_(std::move(child)) {}

  static std::shared_ptr<Type> Make(const std::string &name, std::shared_ptr<Type> child) {
    return std::make_shared<Stream>(name, child);
  }

 private:
  std::shared_ptr<Type> child_;
};

}  // namespace stream
}  // namespace fletchgen
