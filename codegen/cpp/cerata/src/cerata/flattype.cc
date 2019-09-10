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

#include "cerata/flattype.h"

#include <optional>
#include <utility>
#include <memory>
#include <deque>
#include <string>
#include <iomanip>
#include <iostream>

#include "cerata/utils.h"
#include "cerata/type.h"
#include "cerata/node.h"
#include "cerata/expression.h"

namespace cerata {

std::string FlatType::name(const NamePart &root, const std::string &sep) const {
  std::stringstream ret;
  if (root.sep && !name_parts_.empty()) {
    ret << root.str + sep;
  } else {
    ret << root.str;
  }
  for (size_t p = 0; p < name_parts_.size(); p++) {
    if ((p != name_parts_.size() - 1) && name_parts_[p].sep) {
      ret << name_parts_[p].str + sep;
    } else {
      ret << name_parts_[p].str;
    }
  }
  return ret.str();
}

FlatType::FlatType(Type *t, std::deque<NamePart> prefix, const std::string &name, int level, bool invert)
    : type_(t), invert_(invert) {
  name_parts_ = std::move(prefix);
  name_parts_.emplace_back(name, true);
}

bool operator<(const FlatType &a, const FlatType &b) {
  if (a.nesting_level_ == b.nesting_level_) {
    return a.name() < b.name();
  } else {
    return a.nesting_level_ < b.nesting_level_;
  }
}

void FlattenRecord(std::deque<FlatType> *list,
                   const Record *record,
                   const std::optional<FlatType> &parent,
                   bool invert) {
  for (const auto &f : record->fields()) {
    Flatten(list, f->type().get(), parent, f->name(), invert != f->invert(), f->sep());
  }
}

void FlattenStream(std::deque<FlatType> *list,
                   const Stream *stream,
                   const std::optional<FlatType> &parent,
                   bool invert) {
  Flatten(list, stream->element_type().get(), parent, "", invert);
}

void Flatten(std::deque<FlatType> *list,
             Type *type,
             const std::optional<FlatType> &parent,
             const std::string &name,
             bool invert,
             bool sep) {
  FlatType result;
  result.invert_ = invert;
  if (parent) {
    result.nesting_level_ = (*parent).nesting_level_ + 1;
    result.name_parts_ = (*parent).name_parts_;
  }
  result.type_ = type;
  if (!name.empty()) {
    result.name_parts_.emplace_back(name, sep);
  }
  list->push_back(result);

  switch (type->id()) {
    case Type::STREAM:FlattenStream(list, dynamic_cast<Stream *>(type), result, invert);
      break;
    case Type::RECORD:FlattenRecord(list, dynamic_cast<Record *>(type), result, invert);
      break;
    default:break;
  }
}

std::deque<FlatType> Flatten(Type *type) {
  std::deque<FlatType> result;
  Flatten(&result, type, {}, "", false);
  return result;
}

std::string ToString(std::deque<FlatType> flat_type_list) {
  std::stringstream ret;
  for (size_t i = 0; i < flat_type_list.size(); i++) {
    const auto &ft = flat_type_list[i];
    auto name = ft.name(ft.nesting_level_ == 0 ? NamePart("(root)") : NamePart());
    ret << std::setw(3) << std::right << i << " :"
        << std::setw(32) << std::left
        << std::string(static_cast<int64_t>(2 * ft.nesting_level_), ' ') + name << " | "
        << std::setw(24) << std::left << ft.type_->name() << " | "
        << std::setw(3) << std::right << ft.nesting_level_ << " | "
        << std::setw(8) << std::left << ft.type_->ToString(true) << std::endl;
  }
  return ret.str();
}

bool ContainsFlatType(const std::deque<FlatType> &flat_types_list, const Type *type) {
  for (const auto &ft : flat_types_list) {
    if (ft.type_ == type) {
      return true;
    }
  }
  return false;
}

int64_t IndexOfFlatType(const std::deque<FlatType> &flat_types_list, const Type *type) {
  for (size_t i = 0; i < flat_types_list.size(); i++) {
    if (flat_types_list[i].type_ == type) {
      return i;
    }
  }
  return static_cast<int64_t>(-1);
}

TypeMapper::TypeMapper(Type *a, Type *b)
    : Named(a->name() + "_to_" + b->name()),
      fa_(Flatten(a)), fb_(Flatten(b)),
      a_(a), b_(b),
      matrix_(MappingMatrix<int64_t>(fa_.size(), fb_.size())) {
  // If the types are the same, the mapping is trivial and implicitly constructed.
  // The matrix will be the identity matrix.
  if (a_ == b_) {
    for (size_t i = 0; i < fa_.size(); i++) {
      matrix_(i, i) = 1;
    }
  }
}

std::shared_ptr<TypeMapper> TypeMapper::Make(Type *a, Type *b) {
  auto ret = std::make_shared<TypeMapper>(a, b);
  return ret;
}

std::shared_ptr<TypeMapper> TypeMapper::MakeImplicit(Type *a, Type *b) {
  auto ret = std::make_shared<TypeMapper>(a, b);
  if (a->IsEqual(*b)) {
    for (size_t i = 0; i < ret->flat_a().size(); i++) {
      ret->Add(i, i);
    }
  }
  return ret;
}

TypeMapper &TypeMapper::Add(int64_t a, int64_t b) {
  matrix_.SetNext(a, b);
  return *this;
}

std::string TypeMapper::ToString() const {
  constexpr int w = 20;
  std::stringstream ret;
  ret << "TypeMapper " << a()->ToString(true, true) + " => " + b()->ToString(true, true) + "\n";
  ret << "  Meta: " + ::cerata::ToString(meta) + "\n";
  ret << std::setw(w) << " " << " | ";

  for (const auto &x : fb_) {
    ret << std::setw(w) << x.name() << " | ";
  }
  ret << std::endl;
  ret << std::setw(w) << " " << " | ";
  for (const auto &x : fb_) {
    ret << std::setw(w) << x.type_->ToString() << " | ";
  }
  ret << "\n";

  // Separator
  for (size_t i = 0; i < fb_.size() + 1; i++) { ret << std::string(w, '-') << " | "; }
  ret << "\n";

  for (size_t y = 0; y < fa_.size(); y++) {
    ret << std::setw(w) << fa_[y].name() << " | ";
    for (size_t x = 0; x < fb_.size(); x++) {
      ret << std::setw(w) << " " << " | ";
    }
    ret << "\n";
    ret << std::setw(w) << fa_[y].type_->ToString() << " | ";
    for (size_t x = 0; x < fb_.size(); x++) {
      auto val = matrix_(y, x);
      ret << std::setw(w) << val << " | ";
    }
    ret << "\n";
    // Separator
    for (size_t i = 0; i < fb_.size() + 1; i++) { ret << std::string(w, '-') << " | "; }
    ret << "\n";
  }
  return ret.str();
}

MappingMatrix<int64_t> TypeMapper::map_matrix() { return matrix_; }

std::deque<FlatType> TypeMapper::flat_a() const { return fa_; }

std::deque<FlatType> TypeMapper::flat_b() const { return fb_; }

bool TypeMapper::CanConvert(const Type *a, const Type *b) const {
  return ((a_ == a) && (b_ == b));
}

std::shared_ptr<TypeMapper> TypeMapper::Inverse() const {
  auto result = std::make_shared<TypeMapper>(b_, a_);  // Create a new mapper.
  result->matrix_ = matrix_.Transpose();  // Copy over a transposed version of the mapping matrix.
  result->meta = this->meta;  // Copy over metadata.
  return result;
}

std::deque<MappingPair> TypeMapper::GetUniqueMappingPairs() {
  std::deque<MappingPair> pairs;
  // Find mappings that are one to one
  for (size_t ia = 0; ia < fa_.size(); ia++) {
    auto maps_a = matrix_.mapping_row(ia);
    if (maps_a.size() == 1) {
      auto ib = maps_a.front().first;
      auto maps_b = matrix_.mapping_column(ib);
      if (maps_b.size() == 1) {
        MappingPair mp;
        mp.a.emplace_back(ia, 0, fa_[ia]);
        mp.b.emplace_back(ib, 0, fb_[ib]);
        pairs.push_back(mp);
      }
    }
  }

  // B stuff that is concatenated on A
  for (size_t ia = 0; ia < fa_.size(); ia++) {
    auto maps = matrix_.mapping_row(ia);
    if (maps.size() > 1) {
      MappingPair mp;
      mp.a.emplace_back(ia, 0, fa_[ia]);
      for (const auto &m : maps) {
        mp.b.emplace_back(m.first, m.second, fb_[m.first]);
      }
      pairs.push_back(mp);
    }
  }

  // A stuff that is concatenated on B
  for (size_t ib = 0; ib < fb_.size(); ib++) {
    auto maps = matrix_.mapping_column(ib);
    if (maps.size() > 1) {
      MappingPair mp;
      mp.b.emplace_back(ib, 0, fb_[ib]);
      for (const auto &m : maps) {
        mp.a.emplace_back(m.first, m.second, fa_[m.first]);
      }
      pairs.push_back(mp);
    }
  }
  return pairs;
}

std::shared_ptr<TypeMapper> TypeMapper::Make(Type *a) {
  return std::make_shared<TypeMapper>(a, a);
}

void TypeMapper::SetMappingMatrix(MappingMatrix<int64_t> map_matrix) {
  matrix_ = std::move(map_matrix);
}

std::string MappingPair::ToString() const {
  std::stringstream ret;
  ret << "MappingPair: " << std::endl;
  for (size_t i = 0; i < std::max(a.size(), b.size()); i++) {
    if (i < a.size()) {
      ret << " idx: " << std::setw(3) << index_a(i);
      ret << " off: " << std::setw(3) << offset_a(i);
      ret << std::setw(30) << flat_type_a(i).name();
      ret << std::setw(30) << flat_type_a(i).type_->ToString();
    } else {
      ret << std::setw(74) << " ";
    }
    ret << " --> ";
    if (i < b.size()) {
      ret << " idx: " << std::setw(3) << index_b(i);
      ret << " off: " << std::setw(3) << offset_b(i);
      ret << std::setw(30) << flat_type_b(i).name();
      ret << std::setw(30) << flat_type_b(i).type_->ToString();
    } else {
      ret << std::setw(74) << " ";
    }
    ret << std::endl;
  }
  // output total width of both sides
  ret << " w: " << std::setw(74) << width_a()->ToString();
  ret << "     ";
  ret << " w: " << std::setw(74) << width_b()->ToString();
  ret << std::endl;
  return ret.str();
}

std::shared_ptr<Node> MappingPair::width_a(const std::optional<std::shared_ptr<Node>> &no_width_increment) const {
  std::shared_ptr<Node> w = intl(0);
  for (int64_t i = 0; i < num_a(); i++) {
    auto fw = flat_type_a(i).type_->width();
    if (fw) {
      w = w + fw.value();
    } else if (no_width_increment) {
      w = w + *no_width_increment;
    }
  }
  return w;
}

std::shared_ptr<Node> MappingPair::width_b(const std::optional<std::shared_ptr<Node>> &no_width_increment) const {
  std::shared_ptr<Node> w = intl(0);
  for (int64_t i = 0; i < num_b(); i++) {
    auto fw = flat_type_b(i).type_->width();
    if (fw) {
      w = w + fw.value();
    } else if (no_width_increment) {
      w = w + *no_width_increment;
    }
  }
  return w;
}

}  // namespace cerata
