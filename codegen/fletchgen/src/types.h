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
#include <string>
#include <utility>

#include "./utils.h"

namespace fletchgen {

// Forward decl.
class Node;
struct Literal;

template<int T>
std::shared_ptr<Literal> litint();

/**
 * @brief A type
 */
class Type : public Named {
 public:
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
  inline ID id() const { return id_; }
  explicit Type(std::string name, ID id);
  virtual ~Type() = default;
  bool Is(ID type_id);
 private:
  ID id_;
};

/**
 * @brief A clock domain
 *
 * Placeholder for automatically generated clock domain crossing support
 */
struct ClockDomain : public Named {
  explicit ClockDomain(std::string name);
  static std::shared_ptr<ClockDomain> Make(std::string name) { return std::make_shared<ClockDomain>(name); }
};

struct Natural : public Type {
  explicit Natural(std::string name) : Type(std::move(name), Type::NATURAL) {}
  static std::shared_ptr<Type> Make(std::string name);
};

struct Boolean : public Type {
  explicit Boolean(std::string name);
  static std::shared_ptr<Type> Make(std::string name);
};

struct String : public Type {
  explicit String(std::string name);
  static std::shared_ptr<Type> Make(std::string name);
};

struct Clock : public Type {
  std::shared_ptr<ClockDomain> domain;
  Clock(std::string name, std::shared_ptr<ClockDomain> domain);
  static std::shared_ptr<Clock> Make(std::string name, std::shared_ptr<ClockDomain> domain);
};

struct Reset : public Type {
  std::shared_ptr<ClockDomain> domain;
  explicit Reset(std::string name, std::shared_ptr<ClockDomain> domain);
  static std::shared_ptr<Reset> Make(std::string name, std::shared_ptr<ClockDomain> domain);
};

struct Bit : public Type {
  explicit Bit(std::string name);
  static std::shared_ptr<Bit> Make(std::string name);
};

class Vector : public Type {
 public:
  Vector(std::string name, std::shared_ptr<Node> width);
  static std::shared_ptr<Type> Make(std::string name, std::shared_ptr<Node> width);
  std::shared_ptr<Node> width() const { return width_; }
  template<int T>
  static std::shared_ptr<Type> Make(std::string name) {
    return std::make_shared<Vector>(name, litint<T>());
  }
 private:
  std::shared_ptr<Node> width_;
};

class RecordField : public Named {
 public:
  RecordField(std::string name, std::shared_ptr<Type> type);
  static std::shared_ptr<RecordField> Make(std::string name, std::shared_ptr<Type> type);
  static std::shared_ptr<RecordField> Make(std::shared_ptr<Type> type);
  std::shared_ptr<Type> type() const { return type_; }
 private:
  std::shared_ptr<Type> type_;
};

class Record : public Type {
 public:
  explicit Record(const std::string &name, std::deque<std::shared_ptr<RecordField>> fields = {});
  static std::shared_ptr<Type> Make(const std::string &name, std::deque<std::shared_ptr<RecordField>> fields = {});
  Record &AddField(const std::shared_ptr<RecordField> &field);;
  std::shared_ptr<RecordField> field(size_t i) const { return fields_[i]; }
  std::deque<std::shared_ptr<RecordField>> fields() { return fields_; }
 private:
  std::deque<std::shared_ptr<RecordField>> fields_;
};

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

  /// @brief Create a smart pointer to a new Stream type. Stream name will be stream:<type name>, the elements "data".
  static std::shared_ptr<Type> Make(std::shared_ptr<Type> element_type, int epc = 1);

  /// @brief Shorthand to create a smart pointer to a new Stream type. The elements are named "data".
  static std::shared_ptr<Type> Make(std::string name, std::shared_ptr<Type> element_type, int epc = 1);

  /// @brief Shorthand to create a smart pointer to a new Stream type.
  static std::shared_ptr<Type> Make(std::string name,
                                    std::shared_ptr<Type> element_type,
                                    std::string element_name,
                                    int epc = 1);

  std::shared_ptr<Type> element_type() { return element_type_; }
  std::string element_name() { return element_name_; }
  int epc() { return epc_; }

 private:
  std::shared_ptr<Type> element_type_;
  std::string element_name_;

  /// @brief Elements Per Cycle
  int epc_ = 1;
};

/// @brief Return true if type is nested (e.g. Stream or Record), false otherwise.
bool IsNested(const std::shared_ptr<Type> &type);

/// @brief Flatten all potential underlying Streams of a Type.
std::deque<std::shared_ptr<Type>> FlattenStreams(const std::shared_ptr<Type> &type);

template<typename T>
std::string ToString() {
  return "UNKNOWN TYPE";
}

template<typename T>
std::shared_ptr<T> Cast(const std::shared_ptr<Type> &type) {
  auto result = std::dynamic_pointer_cast<T>(type);
  if (result == nullptr) {
    throw std::runtime_error("Could not cast type " + type->name() + " to " + ToString<T>());
  }
  return result;
}

// Some common types:

/// @brief A bit type.
std::shared_ptr<Type> bit();

/// @brief String type.
std::shared_ptr<Type> string();

/// @brief Integer type.
std::shared_ptr<Type> integer();

/// @brief Boolean type.
std::shared_ptr<Type> boolean();

}  // namespace fletchgen
