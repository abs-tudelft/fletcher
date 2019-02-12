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

#include "./utils.h"

namespace fletchgen {

class Type;
class Record;
class Stream;

/**
 * @brief A flattened type.
 */
struct FlatType {
  FlatType() = default;
  FlatType(std::shared_ptr<Type> t, std::deque<std::string> prefix, std::string name, int level);
  int nesting_level = 0;
  std::deque<std::string> name_parts;
  std::shared_ptr<Type> type;
  std::string name(std::string root = "", std::string sep = ":") const;
  bool operator<(FlatType &a) {
    return nesting_level < a.nesting_level;
  }
};
// Flattening functions for nested types:

/// @brief Flatten a Record.
void FlattenRecord(std::deque<FlatType> *list,
                   const std::shared_ptr<Record> &record,
                   const std::optional<FlatType> &parent);

/// @brief Flatten a Stream.
void FlattenStream(std::deque<FlatType> *list,
                   const std::shared_ptr<Stream> &stream,
                   const std::optional<FlatType> &parent);

/// @brief Flatten any Type.
void Flatten(std::deque<FlatType> *list,
             const std::shared_ptr<Type> &type,
             const std::optional<FlatType> &parent,
             std::string name);

/// @brief Flatten and return a list of FlatTypes.
std::deque<FlatType> Flatten(const std::shared_ptr<Type> &type);

/// @brief Return true if some Type is contained in a list of FlatTypes, false otherwise.
bool contains(const std::deque<FlatType> &flat_types_list, const std::shared_ptr<Type> &type);

/// @brief Return the index of some Type in a list of FlatTypes.
size_t index_of(const std::deque<FlatType> &flat_types_list, const std::shared_ptr<Type> &type);

/**
 * @brief Sort a list of flattened types by nesting level
 * @param list
 */
void Sort(std::deque<FlatType> *list);

/// @brief Convert a list of FlatTypes to a human-readable string.
std::string ToString(std::deque<FlatType> flat_type_list);

/**
 * @brief Compare if two types are weakly-equal, that is if their flattened Type ID list has the same levels and ids.
 * @param a The first type.
 * @param b The second type.
 * @return True if flattened Type ID list is the same, false otherwise.
 */
bool WeaklyEqual(const std::shared_ptr<Type> &a, const std::shared_ptr<Type> &b);

template<typename T>
class ConversionMatrix {
 private:
  std::vector<T> elements_;
  size_t height_;
  size_t width_;

 public:
  ConversionMatrix(size_t height, size_t width) : height_(height), width_(width) {
    elements_ = std::vector<T>(height_ * width_, static_cast<T>(0));
  }

  static ConversionMatrix Identity(size_t dim) {
    ConversionMatrix ret(dim, dim);
    for (size_t i = 0; i < dim; i++) {
      ret(i, i) = 1;
    }
  }

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

  ConversionMatrix &SetNext(size_t y, size_t x) {
    get(y, x) = std::max(MaxOfColumn(x), MaxOfRow(y)) + 1;
    return *this;
  }

  ConversionMatrix Transpose() {
    ConversionMatrix ret(width_, height_);
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
    }
    return ret.str();
  }

};

/**
 * @brief A structure to dynamically define type conversions on flattened types.
 *
 * Useful for ordered concatenation of N synthesizable types onto M synthesizable types in any way.
 */
class TypeConverter {
 private:
  std::shared_ptr<Type> a_;
  std::shared_ptr<Type> b_;
  std::deque<FlatType> fa_;
  std::deque<FlatType> fb_;
  ConversionMatrix<size_t> matrix_;
 public:
  TypeConverter(std::shared_ptr<Type> a, std::shared_ptr<Type> b);
  TypeConverter &Add(size_t a, size_t b);
  ConversionMatrix<size_t> conversion_matrix();
  std::deque<FlatType> flat_a() const;
  std::deque<FlatType> flat_b() const;
  std::shared_ptr<Type> a() { return a_; }
  std::shared_ptr<Type> b() { return b_; }
  bool CanConvert(std::shared_ptr<Type> a, std::shared_ptr<Type> b) const;
  std::deque<FlatType> GetATypesFor(size_t b) const;
  std::deque<FlatType> GetBTypesFor(size_t a) const;
  TypeConverter Invert() const;
  std::string ToString() const;
};

}  // namespace fletchgen
