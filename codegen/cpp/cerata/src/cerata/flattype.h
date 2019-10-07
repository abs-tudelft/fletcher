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

#include <algorithm>
#include <tuple>
#include <optional>
#include <utility>
#include <memory>
#include <deque>
#include <vector>
#include <string>
#include <sstream>
#include <iomanip>
#include <unordered_map>

#include "cerata/utils.h"
#include "cerata/logging.h"

namespace cerata {

class Type;
class Record;
class Stream;
class Node;

/// Convenience struct to generate names in parts.
struct NamePart {
  NamePart() = default;
  /// @brief Constuct a new NamePart.
  explicit NamePart(std::string part, bool append_sep = true) : str(std::move(part)), sep(append_sep) {}
  /// The string of this name part.
  std::string str = "";
  /// Whether we should insert a separator after this part.
  bool sep = false;
};

/// A flattened type.
struct FlatType {
  FlatType() = default;
  /// @brief Construct a FlatType.
  FlatType(Type *t, std::deque<NamePart> prefix, const std::string &name, int level, bool invert);
  /// @brief A pointer to the original type.
  Type *type_ = nullptr;
  /// @brief Nesting level in a type hierarchy.
  int nesting_level_ = 0;
  /// @brief Name parts of this flattened type.
  std::deque<NamePart> name_parts_;
  /// @brief Whether to invert this flattened type if it would be on a terminator node.
  bool invert_ = false;
  /// @brief Return the name of this flattened type, constructed from the name parts.
  std::string name(const NamePart &root = NamePart(), const std::string &sep = "_") const;
};

/// @brief Compares two FlatTypes first by name, then by nesting level. Useful for sorting.
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
             bool sep = true);

/// @brief Flatten and return a list of FlatTypes.
std::deque<FlatType> Flatten(Type *type);

/// @brief Return true if some Type is contained in a list of FlatTypes, false otherwise.
bool ContainsFlatType(const std::deque<FlatType> &flat_types_list, const Type *type);

/// @brief Return the index of some Type in a list of FlatTypes.
int64_t IndexOfFlatType(const std::deque<FlatType> &flat_types_list, const Type *type);

/// @brief Convert a list of FlatTypes to a human-readable string.
std::string ToString(std::deque<FlatType> flat_type_list);

/**
 * @brief A matrix used for TypeMapper.
 * @tparam T The type of matrix elements.
 */
template<typename T>
class MappingMatrix {
 public:
  /**
   * @brief Construct a mapping matrix.
   * @param height  The height of the matrix.
   * @param width   The width of the matrix.
   */
  MappingMatrix(int64_t height, int64_t width) : height_(height), width_(width) {
    elements_ = std::vector<T>(height_ * width_, static_cast<T>(0));
  }

  /// @brief Return a square identity matrix.
  static MappingMatrix Identity(int64_t dim) {
    MappingMatrix ret(dim, dim);
    for (int64_t i = 0; i < dim; i++) {
      ret(i, i) = 1;
    }
  }

  /// @brief Return the height of the matrix.
  int64_t height() { return height_; }
  /// @brief Return the width of the matrix.
  int64_t width() { return width_; }

  /// @brief Return a reference to a value in the matrix at some index.
  T &get(int64_t y, int64_t x) {
    if (y >= height_ || x >= width_) {
      CERATA_LOG(FATAL, "Indices exceed matrix dimensions.");
    }
    return elements_[width_ * y + x];
  }

  /// @brief Return a const references to a value in the matrix at some index.
  const T &get(int64_t y, int64_t x) const {
    if (y >= height_ || x >= width_) {
      CERATA_LOG(FATAL, "Indices exceed matrix dimensions.");
    }
    return elements_[width_ * y + x];
  }

  /// @brief Return a reference to a value in the matrix at some index.
  T &operator()(int64_t y, int64_t x) {
    return get(y, x);
  }

  /// @brief Return a const references to a value in the matrix at some index.
  const T &operator()(int64_t y, int64_t x) const {
    return get(y, x);
  }

  /// @brief Return the maximum of some column.
  T MaxOfColumn(int64_t x) const {
    T max = 0;
    for (int64_t y = 0; y < height_; y++) {
      if (get(y, x) > max) {
        max = get(y, x);
      }
    }
    return max;
  }

  /// @brief Return the maximum of some row.
  T MaxOfRow(int64_t y) const {
    T max = 0;
    for (int64_t x = 0; x < width_; x++) {
      if (get(y, x) > max) {
        max = get(y, x);
      }
    }
    return max;
  }

  /// @brief Obtain non-zero element indices and value from column x, sorted by value.
  std::deque<std::pair<int64_t, T>> mapping_column(int64_t x) {
    std::deque<std::pair<int64_t, T>> ret;
    for (int64_t y = 0; y < height_; y++) {
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
  std::deque<std::pair<int64_t, T>> mapping_row(int64_t y) {
    using pair = std::pair<int64_t, T>;
    std::deque<pair> ret;
    for (int64_t x = 0; x < width_; x++) {
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

  /// @brief Set the next (existing maximum + 1) value in a matrix at some position.
  MappingMatrix &SetNext(int64_t y, int64_t x) {
    get(y, x) = std::max(MaxOfColumn(x), MaxOfRow(y)) + 1;
    return *this;
  }

  /// @brief Transpose the matrix.
  MappingMatrix Transpose() const {
    MappingMatrix ret(width_, height_);
    for (int64_t y = 0; y < height_; y++) {
      for (int64_t x = 0; x < width_; x++) {
        ret(x, y) = get(y, x);
      }
    }
    return ret;
  }

  /// @brief Create an empty matrix of the same size.
  MappingMatrix Empty() const {
    MappingMatrix ret(height_, width_);
    return ret;
  }

  /// @return Return a human-readable representation of the matrix.
  std::string ToString() {
    std::stringstream ret;
    for (int64_t y = 0; y < height_; y++) {
      for (int64_t x = 0; x < width_; x++) {
        ret << std::setw(3) << std::right << std::to_string(get(y, x)) << " ";
      }
      ret << "\n";
    }
    return ret.str();
  }

 private:
  /// Elements of the matrix.
  std::vector<T> elements_;
  /// Height of the matrix.
  int64_t height_;
  /// Width of the matrix.
  int64_t width_;
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
  using index = int64_t;  ///< Index type.
  using offset = int64_t;  ///< Offset type.
  /// Tuple that stores all information required by a mapping pair on one side.
  using tuple = std::tuple<index, offset, FlatType>;
  /// Flattype and its index in a mapping matrix on the "a"-side.
  std::deque<tuple> a;
  /// Flattype and its index in a mapping matrix on the "b"-side.
  std::deque<tuple> b;
  /// @brief Return the number of FlatTypes on the "a"-side.
  int64_t num_a() const { return a.size(); }
  /// @brief Return the number of FlatTypes on the "b"-side.
  int64_t num_b() const { return b.size(); }
  /// @brief Return the index of the i-th FlatType on the "a"-side in the mapping matrix.
  index index_a(int64_t i) const { return std::get<0>(a[i]); }
  /// @brief Return the index of the i-th FlatType on the "b"-side in the mapping matrix.
  index index_b(int64_t i) const { return std::get<0>(b[i]); }
  /// @brief Return the offset of the i-th FlatType on the "a"-side in the mapping matrix.
  offset offset_a(int64_t i) const { return std::get<1>(a[i]); }
  /// @brief Return the offset of the i-th FlatType on the "b"-side in the mapping matrix.
  offset offset_b(int64_t i) const { return std::get<1>(b[i]); }
  /// @brief Return the i-th FlatType on the "a"-side in the mapping matrix.
  FlatType flat_type_a(int64_t i) const { return std::get<2>(a[i]); }
  /// @brief Return the i-th FlatType on the "b"-side in the mapping matrix.
  FlatType flat_type_b(int64_t i) const { return std::get<2>(b[i]); }

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
 public:
  /// @brief TypeMapper constructor. Constructs an empty type mapping.
  TypeMapper(Type *a, Type *b);
  /// @brief Construct a new TypeMapper from some type to itself, and return a smart pointer to it.
  static std::shared_ptr<TypeMapper> Make(Type *a);
  /// @brief Construct a new TypeMapper from some type to another type, and automatically determine the type mapping.
  static std::shared_ptr<TypeMapper> MakeImplicit(Type *a, Type *b);
  /// @brief Construct a new, empty TypeMapper between two types.
  static std::shared_ptr<TypeMapper> Make(Type *a, Type *b);

  /// @brief Add a mapping between two FlatTypes to the mapper.
  TypeMapper &Add(int64_t a, int64_t b);
  /// @brief Return the mapping matrix of this TypeMapper.
  MappingMatrix<int64_t> map_matrix();
  /// @brief Set the mapping matrix of this TypeMapper.
  void SetMappingMatrix(MappingMatrix<int64_t> map_matrix);

  /// @brief Return the list of flattened types on the "a"-side.
  std::deque<FlatType> flat_a() const;
  /// @brief Return the list of flattened types on the "b"-side.
  std::deque<FlatType> flat_b() const;
  /// @brief Return the type on the "a"-side.
  Type *a() const { return a_; }
  /// @brief Return the type on the "b"-side.
  Type *b() const { return b_; }

  /// @brief Return true if this TypeMapper can map type a to type b.
  bool CanConvert(const Type *a, const Type *b) const;

  /// @brief Return a new TypeMapper that is the inverse of this TypeMapper.
  std::shared_ptr<TypeMapper> Inverse() const;

  /// @brief Get a list of unique mapping pairs.
  std::deque<MappingPair> GetUniqueMappingPairs();

  /// @brief Return a human-readable string of this TypeMapper.
  std::string ToString() const;

  /// @brief KV storage for metadata of tools or specific backend implementations
  std::unordered_map<std::string, std::string> meta;

 protected:
  /// The list of flattened types on the "a"-side.
  std::deque<FlatType> fa_;
  /// The list of flattened types on the "b"-side.
  std::deque<FlatType> fb_;
  /// Type of the "a"-side.
  Type *a_;
  /// Type of the "b"-side.
  Type *b_;
  /// The mapping matrix.
  MappingMatrix<int64_t> matrix_;
};

}  // namespace cerata
