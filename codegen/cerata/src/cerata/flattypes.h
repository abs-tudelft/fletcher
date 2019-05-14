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

#include <optional>
#include <utility>
#include <memory>
#include <deque>
#include <vector>
#include <string>
#include <sstream>
#include <iomanip>

#include "cerata/utils.h"

namespace cerata {

class Type;
class Record;
class Stream;
class Node;

struct NamePart {
  NamePart()=default;
  explicit NamePart(std::string part, bool append_sep = true) : str(std::move(part)), sep(append_sep) {}
  std::string str = "";
  bool sep = false;
};

/**
 * @brief A flattened type.
 */
struct FlatType {
  FlatType() = default;
  FlatType(Type *t, std::deque<NamePart> prefix, const std::string &name, int level, bool invert);
  /// @brief A pointer to the original type.
  Type *type_;
  /// @brief Nesting level in a type hierarchy.
  int nesting_level_ = 0;
  /// @brief Name parts of this flattened type.
  std::deque<NamePart> name_parts_;
  /// @brief Whether to invert this flattened type if it would be on a terminator node.
  bool invert_ = false;
  /// @brief Return the name of this flattened type, constructed from the name parts.
  std::string name(const NamePart &root = NamePart(), const std::string &sep = "_") const;
};

bool operator<(const FlatType &a, const FlatType &b);

// Flattening functions for nested types:

/// @brief Flatten a Record.
void FlattenRecord(std::deque<FlatType> *list,
                   const Record *record,
                   const std::optional<FlatType> &parent,
                   bool invert);

/// @brief Flatten a Stream.
void FlattenStream(std::deque<FlatType> *list,
                   const Stream *stream,
                   const std::optional<FlatType> &parent,
                   bool invert);

/// @brief Flatten any Type.
void Flatten(std::deque<FlatType> *list,
             Type *type,
             const std::optional<FlatType> &parent,
             const std::string &name,
             bool invert,
             bool sep=true);

/// @brief Flatten and return a list of FlatTypes.
std::deque<FlatType> Flatten(Type *type);

/// @brief Return true if some Type is contained in a list of FlatTypes, false otherwise.
bool ContainsFlatType(const std::deque<FlatType> &flat_types_list, const Type *type);

/// @brief Return the index of some Type in a list of FlatTypes.
size_t IndexOfFlatType(const std::deque<FlatType> &flat_types_list, const Type *type);

/// @brief Convert a list of FlatTypes to a human-readable string.
std::string ToString(std::deque<FlatType> flat_type_list);

/**
 * @brief A matrix used for TypeMapper.
 * @tparam T The type of matrix elements.
 */
template<typename T>
class MappingMatrix {
 private:
  std::vector<T> elements_;
  size_t height_;
  size_t width_;

 public:
  MappingMatrix(size_t height, size_t width) : height_(height), width_(width) {
    elements_ = std::vector<T>(height_ * width_, static_cast<T>(0));
  }

  static MappingMatrix Identity(size_t dim) {
    MappingMatrix ret(dim, dim);
    for (size_t i = 0; i < dim; i++) {
      ret(i, i) = 1;
    }
  }

  size_t height() { return height_; }
  size_t width() { return width_; }

  T &get(size_t y, size_t x) {
    if (y >= height_ || x >= width_) {
      throw std::runtime_error("Indices exceed matrix dimensions.");
    }
    return elements_[width_ * y + x];
  }

  const T &get(size_t y, size_t x) const {
    if (y >= height_ || x >= width_) {
      throw std::runtime_error("Indices exceed matrix dimensions.");
    }
    return elements_[width_ * y + x];
  }

  T &operator()(size_t y, size_t x) {
    return get(y, x);
  }

  const T &operator()(size_t y, size_t x) const {
    return get(y, x);
  }

  T MaxOfColumn(size_t x) const {
    T max = 0;
    for (size_t y = 0; y < height_; y++) {
      if (get(y, x) > max) {
        max = get(y, x);
      }
    }
    return max;
  };

  T MaxOfRow(size_t y) const {
    T max = 0;
    for (size_t x = 0; x < width_; x++) {
      if (get(y, x) > max) {
        max = get(y, x);
      }
    }
    return max;
  };

  /// @brief Obtain non-zero element indices and value from column x, sorted by value.
  std::deque<std::pair<size_t, T>> mapping_column(size_t x) {
    std::deque<std::pair<size_t, T>> ret;
    for (size_t y = 0; y < height_; y++) {
      auto val = get(y, x);
      if (val > 0) {
        ret.emplace_back(y, val);
      }
    }
    std::sort(ret.begin(), ret.end(), [](const auto &x, const auto &y) -> bool {
      return x.second < y.second;
    });
    return ret;
  }

  /// @brief Obtain non-zero element indices and value from row y, sorted by value.
  std::deque<std::pair<size_t, T>> mapping_row(size_t y) {
    using pair = std::pair<size_t, T>;
    std::deque<pair> ret;
    for (size_t x = 0; x < width_; x++) {
      auto val = get(y, x);
      if (val > 0) {
        ret.emplace_back(x, val);
      }
    }
    std::sort(ret.begin(), ret.end(), [](const auto &x, const auto &y) -> bool {
      return x.second < y.second;
    });
    return ret;
  }

  MappingMatrix &SetNext(size_t y, size_t x) {
    get(y, x) = std::max(MaxOfColumn(x), MaxOfRow(y)) + 1;
    return *this;
  }

  MappingMatrix Transpose() const {
    MappingMatrix ret(width_, height_);
    for (size_t y = 0; y < height_; y++) {
      for (size_t x = 0; x < width_; x++) {
        ret(x, y) = get(y, x);
      }
    }
    return ret;
  }

  std::string ToString() {
    std::stringstream ret;
    for (size_t y = 0; y < height_; y++) {
      for (size_t x = 0; x < width_; x++) {
        ret << std::setw(3) << std::right << std::to_string(get(y, x)) << " ";
      }
      ret << "\n";
    }
    return ret.str();
  }

};

/**
 * @brief A structure representing a mapping pair for a type mapping.
 *
 * The mapping pair typically contains one FlatType on one side (a or b), and one or multiple FlatTypes on the other
 * side (a or b). If, for example, side a contains one FlatType and b contains two FlatTypes (b0 and b1), that means
 * that if this is a mapping pair of a mapping between two types A and B, when some node X of type A and a node Y of
 * type B connect to each other, then in hardware FlatType b0 and b1 are concatenated onto a.
 */
struct MappingPair {
  using index = size_t;
  using offset = size_t;
  using tuple = std::tuple<index, offset, FlatType>;
  std::deque<tuple> a;
  std::deque<tuple> b;
  size_t num_a() const { return a.size(); }
  size_t num_b() const { return b.size(); }
  index index_a(size_t i) const { return std::get<0>(a[i]); }
  index index_b(size_t i) const { return std::get<0>(b[i]); }
  offset offset_a(size_t i) const { return std::get<1>(a[i]); }
  offset offset_b(size_t i) const { return std::get<1>(b[i]); }
  FlatType flat_type_a(size_t i) const { return std::get<2>(a[i]); }
  FlatType flat_type_b(size_t i) const { return std::get<2>(b[i]); }
  /**
   * @brief Return the total width of the types on side A.
   * @param no_width_increment  In case some flat type doesn't have a width, increment it with this parameter.
   * @return                    The total width on side A.
   */
  std::shared_ptr<Node> width_a(const std::optional<std::shared_ptr<Node>> &no_width_increment = {}) const;
  /**
   * @brief Return the total width of the types on side B.
   * @param no_width_increment  In case some flat type doesn't have a width, increment it with this parameter.
   * @return                    The total width on side B.
   */
  std::shared_ptr<Node> width_b(const std::optional<std::shared_ptr<Node>> &no_width_increment = {}) const;

  /// @brief Generate a human-readable version of this MappingPair
  std::string ToString() const;
};

/**
 * @brief A structure to dynamically define type mappings between flattened types.
 *
 * Useful for ordered concatenation of N synthesizable types onto M synthesizable types in any way.
 */
class TypeMapper : public Named {
 private:
  std::deque<FlatType> fa_;
  std::deque<FlatType> fb_;
  Type *a_;
  Type *b_;
  MappingMatrix<size_t> matrix_;
 public:
  /// @brief TypeMapper constructor. Constructs an empty type mapping.
  TypeMapper(Type *a, Type *b);
  /// @brief Construct a new TypeMapper from some type to itself, and return a smart pointer to it.
  static std::shared_ptr<TypeMapper> Make(Type *a);
  /// @brief Construct a new TypeMapper from some type to another type, and automatically determine the type mapping.
  static std::shared_ptr<TypeMapper> MakeImplicit(Type *a, Type *b);
  /// @brief Construct a new, empty TypeMapper between two types.
  static std::shared_ptr<TypeMapper> Make(Type *a, Type *b);

  TypeMapper &Add(size_t a, size_t b);
  MappingMatrix<size_t> map_matrix();
  void SetMappingMatrix(MappingMatrix<size_t> map_matrix);

  std::deque<FlatType> flat_a() const;
  std::deque<FlatType> flat_b() const;
  Type *a() const { return a_; }
  Type *b() const { return b_; }

  /// @brief Return true if this TypeMapper can map type a to type b.
  bool CanConvert(const Type *a, const Type *b) const;

  /// @brief Return a new TypeMapper that is the inverse of this TypeMapper.
  std::shared_ptr<TypeMapper> Inverse() const;

  /// @brief Get a list of unique mapping pairs.
  std::deque<MappingPair> GetUniqueMappingPairs();

  /// @brief Return a human-readable string of this TypeMapper.
  std::string ToString() const;
};

}  // namespace cerata
