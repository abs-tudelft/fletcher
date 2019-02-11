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

#include "./flattypes.h"

#include <optional>
#include <utility>
#include <memory>
#include <deque>
#include <string>
#include <sstream>
#include <iomanip>
#include <iostream>

#include "./utils.h"
#include "./types.h"
#include "flattypes.h"

namespace fletchgen {

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

std::string ToString(std::deque<FlatType> flat_type_list) {
  std::stringstream ret;
  for (size_t i = 0; i < flat_type_list.size(); i++) {
    const auto &ft = flat_type_list[i];
    auto name = ft.name(ft.nesting_level == 0 ? "(root)" : "");
    ret << std::setw(3) << std::right << i << " :"
        << std::setw(32) << std::left
        << std::string(static_cast<unsigned long>(2 * ft.nesting_level), ' ') + name << " | "
        << std::setw(24) << std::left << ft.type->name() << " | "
        << std::setw(3) << std::right << ft.nesting_level << " | "
        << std::setw(8) << std::left << ft.type->ToString() << std::endl;
  }
  return ret.str();
}

void Sort(std::deque<FlatType> *list) {
  std::sort(list->begin(), list->end());
}

bool WeaklyEqual(const std::shared_ptr<Type> &a, const std::shared_ptr<Type> &b) {
  bool equal = true;
  auto a_types = Flatten(a);
  auto b_types = Flatten(b);

  // Check if the lists have equal length.
  if (a_types.size() != b_types.size()) {
    equal = false;
  }

  // Check every type id to be the same.
  for (size_t i = 0; i < a_types.size(); i++) {
    if (a_types[i].type->id() != b_types[i].type->id()) {
      equal = false;
    }
    if (a_types[i].nesting_level != b_types[i].nesting_level) {
      equal = false;
    }
  }

  // Try type conversions
  if (!equal) {
    auto convs = a->converters();
    for (const auto &c : convs) {
      if (c.CanConvert(a, b)) {
        equal = true;
        break;
      }
    }
  }

  if (!equal) {
    auto convs = b->converters();
    for (const auto &c : convs) {
      if (!c.CanConvert(a, b)) {
        equal = true;
        break;
      }
    }
  }

  return equal;
}

bool contains(const std::deque<FlatType> &flat_types_list, const std::shared_ptr<Type> &type) {
  for (const auto &ft : flat_types_list) {
    if (ft.type == type) {
      return true;
    }
  }
  return false;
}

size_t index_of(const std::deque<FlatType> &flat_types_list, const std::shared_ptr<Type> &type) {
  for (size_t i = 0; i < flat_types_list.size(); i++) {
    if (flat_types_list[i].type == type) {
      return i;
    }
  }
  return static_cast<size_t>(-1);
}

TypeConverter::TypeConverter(std::shared_ptr<Type>
                             from, std::shared_ptr<Type>
                             to)
    : from_(std::move(from)),
      to_(std::move(to)),
      flat_from_(Flatten(from_)),
      flat_to_(Flatten(to_)),
      conversion_map_(std::vector<std::optional<size_t>>(flat_from_.size())) {}

/*
FlatTypeConverter &FlatTypeConverter::operator()(const std::shared_ptr<Type> &from, const std::shared_ptr<Type> &to) {
  // Check for potential errors
  if ((from == nullptr) || (to == nullptr)) {
    throw std::runtime_error("Types contain nullptr.");
  }
  if (!contains(flat_from_, from)) {
    throw std::runtime_error("Type " + from->name() + " is not in the flattened type list of " + from_->name());
  }
  if (!contains(flat_to_, to_)) {
    throw std::runtime_error("Type " + to->name() + " is not in the flattened type list of " + to_->name());
  }

  // Set the mapping
  auto from_idx = index_of(flat_from_, from);
  auto to_idx = index_of(flat_to_, to);
  conversion_map_[from_idx] = to_idx;

  return *this;
}
*/

TypeConverter &TypeConverter::operator()(size_t from, size_t to) {
  if ((from < flat_from_.size()) && (to < flat_to_.size())) {
    conversion_map_[from] = to;
  }
  return *this;
}

std::string TypeConverter::ToString() const {
  std::stringstream ret;
  for (size_t i = 0; i < flat_from_.size(); i++) {
    std::string locstr = "-";
    if (conversion_map_[i]) {
      auto loc = *conversion_map_[i];
      locstr = std::to_string(loc) + " (" + flat_to_[loc].name() + ") ";
    }
    auto srcstr = " (" + flat_from_[i].name() + ") " + std::to_string(i);
    ret << std::setw(16) << std::right << srcstr
        << " => "
        << std::setw(16) << std::left << locstr
        << std::endl;
  }
  return ret.str();
}

std::vector<std::optional<size_t>> TypeConverter::conversion_map() { return conversion_map_; }

std::deque<FlatType> TypeConverter::flat_from() { return flat_from_; }

std::deque<FlatType> TypeConverter::flat_to() { return flat_to_; }

bool TypeConverter::CanConvert(std::shared_ptr<Type> from, std::shared_ptr<Type> to) const {
  return (from_ == from) && (to_ == to);
}

}  // namespace fletchgen
