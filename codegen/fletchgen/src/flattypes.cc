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
  for (const auto &p : name_parts_) {
    ret << "_" + p;
  }
  return ret.str();
}

FlatType::FlatType(const Type *t, std::deque<std::string> prefix, std::string name, int level) : type_(t) {
  name_parts_ = std::move(prefix);
  name_parts_.push_back(name);
}

bool operator<(const FlatType &a, const FlatType &b) {
  return a.nesting_level_ < b.nesting_level_;
}

void FlattenRecord(std::deque<FlatType> *list,
                   const Record *record,
                   const std::optional<FlatType> &parent) {
  for (const auto &f : record->fields()) {
    Flatten(list, f->type().get(), parent, f->name());
  }
}

void FlattenStream(std::deque<FlatType> *list,
                   const Stream* stream,
                   const std::optional<FlatType> &parent) {
  Flatten(list, stream->element_type().get(), parent, "");
}

void Flatten(std::deque<FlatType> *list,
             const Type *type,
             const std::optional<FlatType> &parent,
             std::string name) {
  FlatType result;
  if (parent) {
    result.nesting_level_ = (*parent).nesting_level_ + 1;
    result.name_parts_ = (*parent).name_parts_;
  }
  result.type_ = type;
  if (!name.empty()) {
    result.name_parts_.push_back(name);
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

std::deque<FlatType> Flatten(const Type *type) {
  std::deque<FlatType> result;
  Flatten(&result, type, {}, "");
  return result;
}

std::string ToString(std::deque<FlatType> flat_type_list) {
  std::stringstream ret;
  for (size_t i = 0; i < flat_type_list.size(); i++) {
    const auto &ft = flat_type_list[i];
    auto name = ft.name(ft.nesting_level_ == 0 ? "(root)" : "");
    ret << std::setw(3) << std::right << i << " :"
        << std::setw(32) << std::left
        << std::string(static_cast<unsigned long>(2 * ft.nesting_level_), ' ') + name << " | "
        << std::setw(24) << std::left << ft.type_->name() << " | "
        << std::setw(3) << std::right << ft.nesting_level_ << " | "
        << std::setw(8) << std::left << ft.type_->ToString() << std::endl;
  }
  return ret.str();
}

void Sort(std::deque<FlatType> *list) {
  std::sort(list->begin(), list->end());
}

bool WeaklyEqual(const Type *a, const Type *b) {
  bool equal = true;
  auto a_types = Flatten(a);
  auto b_types = Flatten(b);

  // Check if the lists have equal length.
  if (a_types.size() != b_types.size()) {
    equal = false;
  }

  // Check every type id to be the same.
  for (size_t i = 0; i < a_types.size(); i++) {
    if (a_types[i].type_->id() != b_types[i].type_->id()) {
      equal = false;
    }
    if (a_types[i].nesting_level_ != b_types[i].nesting_level_) {
      equal = false;
    }
  }

  // Try type conversions
  if (!equal) {
    auto convs = a->mappers();
    for (const auto &c : convs) {
      if (c->CanConvert(a, b)) {
        equal = true;
        break;
      }
    }
  }

  return equal;
}

bool contains(const std::deque<FlatType> &flat_types_list, const Type *type) {
  for (const auto &ft : flat_types_list) {
    if (ft.type_ == type) {
      return true;
    }
  }
  return false;
}

size_t index_of(const std::deque<FlatType> &flat_types_list, const Type *type) {
  for (size_t i = 0; i < flat_types_list.size(); i++) {
    if (flat_types_list[i].type_ == type) {
      return i;
    }
  }
  return static_cast<size_t>(-1);
}

TypeMapper::TypeMapper(const Type *a, const Type *b)
    : Named(a->name() + "_to_" + b->name()),
      fa_(Flatten(a)), fb_(Flatten(b)),
      a_(a), b_(b),
      matrix_(MappingMatrix<size_t>(fa_.size(), fb_.size())) {
  if (a_ == b_) {
    for (size_t i = 0; i < fa_.size(); i++) {
      matrix_(i, i) = 1;
    }
  }
}

TypeMapper &TypeMapper::Add(size_t a, size_t b) {
  matrix_.SetNext(a, b);
  return *this;
}

std::string TypeMapper::ToString() const {
  std::stringstream ret;
  for (size_t y = 0; y < fa_.size(); y++) {
    for (size_t x = 0; x < fb_.size(); x++) {
      auto val = matrix_(y, x);
      if (val > 0) {
        ret << std::setw(16) << std::right << fa_[y].name()
            << " " << std::setw(3) << y
            << " => "
            << std::setw(3) << x << " "
            << std::setw(16) << std::left << fb_[x].name() + "(" + std::to_string(val) + ")"
            << std::endl;
      }
    }
  }
  return ret.str();
}

MappingMatrix<size_t> TypeMapper::map_matrix() { return matrix_; }

std::deque<FlatType> TypeMapper::flat_a() const { return fa_; }

std::deque<FlatType> TypeMapper::flat_b() const { return fb_; }

bool TypeMapper::CanConvert(const Type *a, const Type *b) const {
  return ((a_ == a) && (b_ == b)) || ((a_ == b) && (b_ == a));
}

std::deque<FlatType> TypeMapper::GetBTypesFor(size_t a) const {
  std::deque<FlatType> ret;
  for (size_t i = 0; i < fb_.size(); i++) {
    if (matrix_(a, i)) {
      ret.push_back(fb_[i]);
    }
  }
  return ret;
}

std::deque<FlatType> TypeMapper::GetATypesFor(size_t b) const {
  std::deque<FlatType> ret;
  for (size_t i = 0; i < fa_.size(); i++) {
    if (matrix_(i, b)) {
      ret.push_back(fa_[i]);
    }
  }
  return ret;
}

std::shared_ptr<TypeMapper> TypeMapper::Inverse() const {
  auto ret = std::make_shared<TypeMapper>(b_, a_);
  ret->matrix_ = matrix_.Transpose();
  return ret;
}

}  // namespace fletchgen
